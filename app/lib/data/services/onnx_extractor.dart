import '../../core/ner/ner_engine.dart';
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

    final extraction = Extraction(rawText: labelText)
      ..drug = result.fields['drug']
      ..strength = result.fields['strength']
      ..dose = result.fields['dose']
      ..form = result.fields['form']
      ..route = result.fields['route']
      ..frequency = result.fields['frequency']
      ..duration = result.fields['duration']
      ..fillDate = result.fillDate
      ..daysSupply = result.daysSupply;
    extraction.fieldRecognized.addAll(result.recognized);
    return extraction;
  }
}
