import '../../core/ner/ner_engine.dart';
import '../../core/ner/postprocess.dart' show formatDrugName;
import 'extractor.dart';

/// The real [Extractor]: on-device NER (distilled from Med7, run via ONNX)
/// for drug/strength/dose/form/route/frequency/duration, plus regex for
/// fill date and days-supply.
class OnnxExtractor implements Extractor {
  OnnxExtractor(this._engine);

  final NerEngine _engine;

  static Future<OnnxExtractor> load() async => OnnxExtractor(await NerEngine.load());

  @override
  Future<Extraction> extract(String labelText) async {
    final result = await _engine.extract(labelText);

    final rawDrug = result.fields['drug'];
    final extraction = Extraction(rawText: labelText)
      ..drug = rawDrug != null ? formatDrugName(rawDrug) : null
      ..strength = result.fields['strength']
      ..dose = result.fields['dose']
      ..form = result.fields['form']
      ..route = result.fields['route']
      ..frequency = result.fields['frequency']
      ..duration = result.fields['duration']
      ..fillDate = result.fillDate
      ..daysSupply = result.daysSupply
      ..quantity = result.quantity
      ..refills = result.refills;
    extraction.fieldRecognized.addAll(result.recognized);
    return extraction;
  }

  Future<void> dispose() => _engine.dispose();
}
