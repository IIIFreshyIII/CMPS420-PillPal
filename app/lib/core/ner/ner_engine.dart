import 'bio_decoder.dart';
import 'ner_assets.dart';
import 'onnx_ner_runner.dart';
import 'postprocess.dart';
import 'regex_fields.dart';

/// NER entity type -> Extraction field name, matching
/// `distill/infer.py`'s `FIELD` map exactly (`app/lib/data/services/extractor.dart`
/// is the Dart side of that same contract).
const Map<String, String> nerFieldNames = {
  'DRUG': 'drug', 'STRENGTH': 'strength', 'DOSAGE': 'dose', 'FORM': 'form',
  'ROUTE': 'route', 'FREQUENCY': 'frequency', 'DURATION': 'duration',
};

class NerEngineResult {
  NerEngineResult({required this.fields, required this.recognized, this.fillDate, this.daysSupply});

  /// Field name (per [nerFieldNames]'s values) -> canonical extracted value.
  /// A field absent here means the model found nothing for it.
  final Map<String, String> fields;

  /// Field name -> whether the validation layer could confidently match it.
  final Map<String, bool> recognized;

  final DateTime? fillDate;
  final int? daysSupply;
}

/// Glues the tokenizer, ONNX model, BIO decoder, and validation layer into
/// one call -- mirrors `distill/infer.py`'s `extract()` pipeline order
/// exactly: NER -> refine -> first-per-type -> regex fields. Refill-date
/// math is deliberately NOT done here -- it happens once, at confirm-time,
/// via `refill_math.dart`, on whatever fill date/days-supply the user has
/// actually confirmed (which may differ from what OCR found).
class NerEngine {
  NerEngine({required NerAssetBundle assets, required OnnxNerRunner runner})
      : _assets = assets,
        _runner = runner;

  final NerAssetBundle _assets;
  final OnnxNerRunner _runner;

  static Future<NerEngine> load() async {
    final assets = await NerAssetBundle.load();
    final runner = await OnnxNerRunner.load(idToLabel: assets.idToLabel);
    return NerEngine(assets: assets, runner: runner);
  }

  Future<NerEngineResult> extract(String text) async {
    final encoding = _assets.tokenizer.encode(text);
    final labels = await _runner.predictLabels(encoding);
    final rawSpans = decodeBioSpans(tokens: encoding.tokens, offsets: encoding.offsets, labels: labels);

    final refined = refine(rawSpans, text, _assets.drugMatcher);
    final picked = firstPerType(refined);

    final fields = <String, String>{};
    final recognized = <String, bool>{};
    for (final entry in picked.entries) {
      final fieldName = nerFieldNames[entry.key];
      if (fieldName == null) continue;
      fields[fieldName] = entry.value.canonical;
      recognized[fieldName] = entry.value.recognized;
    }

    final regexResult = extractRegexFields(text);

    return NerEngineResult(
      fields: fields,
      recognized: recognized,
      fillDate: regexResult.fillDate,
      daysSupply: regexResult.daysSupply,
    );
  }

  Future<void> dispose() => _runner.close();
}
