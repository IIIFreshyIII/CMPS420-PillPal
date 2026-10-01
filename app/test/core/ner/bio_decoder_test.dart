import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/ner/bio_decoder.dart';

/// Per-token predicted label ids come straight from a real forward pass of
/// the shipped ONNX model (see distill/_dart_port_fixtures.py) -- this tests
/// the decoder against real model output, not hand-picked BIO sequences.
/// flutter_onnxruntime can't run inside `flutter test` (native plugin, needs
/// a real device), so this is the correct level to verify decoding logic at.
void main() {
  final fixtures = jsonDecode(File('test/fixtures/ner_fixtures.json').readAsStringSync())
      as Map<String, dynamic>;
  final id2label = (fixtures['id2label'] as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as String));
  final cases = fixtures['tokenizer_cases'] as List<dynamic>;

  for (var i = 0; i < cases.length; i++) {
    final c = cases[i] as Map<String, dynamic>;
    final text = c['text'] as String;
    if ((c['token_label_ids'] as List<dynamic>).isEmpty) continue; // nothing to decode

    final label = text.isEmpty ? 'empty' : text.substring(0, text.length.clamp(0, 30));

    test('case $i decodes to the real pipeline spans: $label', () {
      final tokens = (c['tokens'] as List<dynamic>).cast<String>();
      final offsets = (c['offset_mapping'] as List<dynamic>)
          .map((o) => ((o as List<dynamic>)[0] as int, o[1] as int))
          .toList();
      final labelIds = (c['token_label_ids'] as List<dynamic>).cast<int>();
      final labels = labelIds.map((id) => id2label[id.toString()]!).toList();

      final spans = decodeBioSpans(tokens: tokens, offsets: offsets, labels: labels);

      final expected = (c['raw_spans'] as List<dynamic>)
          .map((s) => ((s as List<dynamic>)[0] as int, s[1] as int, s[2] as String))
          .toList();

      expect(spans, expected);
    });
  }

  test('a B- tag always starts a new span, even same type as the running one', () {
    // "atom" B-DRUG, "##ox" I-DRUG (continues), then a fresh "aspirin" also
    // tagged B-DRUG must NOT merge with the first span -- two spans, not one.
    final spans = decodeBioSpans(
      tokens: ['atom', '##ox', 'aspirin'],
      offsets: [(0, 4), (4, 6), (10, 17)],
      labels: ['B-DRUG', 'I-DRUG', 'B-DRUG'],
    );
    expect(spans, [(0, 6, 'DRUG'), (10, 17, 'DRUG')]);
  });

  test('a glued subword suffix with a different type vanishes into the first word\'s label', () {
    // Same shape as the real ATOMOXETINE25M case: "##25"/"##m" predict
    // STRENGTH but are subtokens of the same word as "atom" (DRUG) -- the
    // whole word takes only the first subtoken's label.
    final spans = decodeBioSpans(
      tokens: ['atom', '##25', '##m'],
      offsets: [(0, 4), (4, 6), (6, 7)],
      labels: ['B-DRUG', 'B-STRENGTH', 'I-STRENGTH'],
    );
    expect(spans, [(0, 7, 'DRUG')]);
  });

  test('special tokens (zero-width offsets) are always skipped', () {
    final spans = decodeBioSpans(
      tokens: ['[CLS]', 'aspirin', '[SEP]'],
      offsets: [(0, 0), (0, 7), (0, 0)],
      labels: ['O', 'B-DRUG', 'B-DURATION'], // [SEP]'s stray prediction must not leak
    );
    expect(spans, [(0, 7, 'DRUG')]);
  });
}
