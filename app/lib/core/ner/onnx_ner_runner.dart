import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'wordpiece_tokenizer.dart';

/// Thin wrapper around the `flutter_onnxruntime` plugin, running the shipped
/// `assets/ner/model.quant.onnx`. This is the one piece of the pipeline that
/// cannot be unit-tested with `flutter test` -- it's a native plugin and
/// needs a real device -- so it's verified manually once the live-scan
/// screen (Stage E) is wired up, not here.
///
/// Real model I/O (confirmed via `onnxruntime.InferenceSession` directly
/// against the shipped file, not assumed): inputs `input_ids` +
/// `attention_mask` (int64, `[1, seq_len]`, no `token_type_ids` --
/// DistilBERT doesn't use them, same as the Python reference strips them);
/// output `logits` (float, `[1, seq_len, 15]`, one score per BIO label).
class OnnxNerRunner {
  OnnxNerRunner._(this._session, this._idToLabel);

  final OrtSession _session;
  final Map<int, String> _idToLabel;

  static Future<OnnxNerRunner> load({
    required Map<int, String> idToLabel,
    String assetKey = 'assets/ner/model.quant.onnx',
  }) async {
    final session = await OnnxRuntime().createSessionFromAsset(assetKey);
    return OnnxNerRunner._(session, idToLabel);
  }

  /// One BIO label per token in [encoding], in order.
  Future<List<String>> predictLabels(Encoding encoding) async {
    final seqLen = encoding.inputIds.length;
    final inputIds = Int64List.fromList(encoding.inputIds);
    final attentionMask = Int64List.fromList(List.filled(seqLen, 1));

    final inputIdsValue = await OrtValue.fromList(inputIds, [1, seqLen]);
    final attentionMaskValue = await OrtValue.fromList(attentionMask, [1, seqLen]);

    final outputs = await _session.run({
      'input_ids': inputIdsValue,
      'attention_mask': attentionMaskValue,
    });

    final logitsFlat = (await outputs['logits']!.asFlattenedList()).cast<num>();
    final numLabels = _idToLabel.length;

    final labels = <String>[];
    for (var i = 0; i < seqLen; i++) {
      var bestIdx = 0;
      var bestScore = double.negativeInfinity;
      for (var j = 0; j < numLabels; j++) {
        final score = logitsFlat[i * numLabels + j].toDouble();
        if (score > bestScore) {
          bestScore = score;
          bestIdx = j;
        }
      }
      labels.add(_idToLabel[bestIdx] ?? 'O');
    }
    return labels;
  }

  Future<void> close() => _session.close();
}
