/// Draft fields pulled from a label's text.
///
/// NOTHING here is trusted. The user confirms every field on the ConfirmScreen
/// before a [Prescription] is created (see `extraction_mapper.dart`). This
/// object is just the starting point for that screen.
class Extraction {
  Extraction({this.rawText = ''});

  final String rawText;
  String? drug;
  String? strength;
  String? dose;
  String? form;
  String? route;
  String? frequency;
  String? duration;
  DateTime? fillDate;
  int? daysSupply;

  /// Per-field name (`'drug'`, `'strength'`, etc. -- matching the property
  /// names above) -> whether the validation layer could confidently match
  /// it. A field absent from this map has no flag info (treated as
  /// recognized) rather than being falsely flagged -- see [isRecognized].
  /// This is deliberately a bool, never a confidence score: the model
  /// doesn't produce one, and the Confirm screen must never invent one.
  final Map<String, bool> fieldRecognized = {};

  bool isRecognized(String field) => fieldRecognized[field] ?? true;
}

/// Turns label text into a draft [Extraction].
///
/// The real implementation will be: on-device NER model (distilled from Med7,
/// run via ONNX) for drug/strength/dose/form/route/frequency/duration, plus
/// plain regex for the fill date and days-supply. The screens depend only on
/// this interface, so that swap won't touch the UI.
abstract class Extractor {
  Future<Extraction> extract(String labelText);
}
