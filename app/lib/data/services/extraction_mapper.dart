import '../models/prescription.dart';
import 'extractor.dart';

/// The one place an [Extraction] (untrusted, from scanning) becomes a
/// [Prescription] (the app's real, persisted schedule model). Called once,
/// at confirm-time, after the user has reviewed every field.
///
/// [time] and [remaining] are required with no default -- [Extraction] has
/// no equivalent field for either, so the Confirm screen must always collect
/// them from the user rather than this function inventing a value.
Prescription mapExtractionToPrescription(
  Extraction extraction, {
  required String id,
  required String profileId,
  required String time,
  required int remaining,
  String? nameOverride,
  String? dosageOverride,
  int? daysSupplyOverride,
}) {
  return Prescription(
    id: id,
    profileId: profileId,
    name: nameOverride ?? extraction.drug ?? 'Unnamed medication',
    dosage: dosageOverride ?? _composeDosage(extraction),
    time: time,
    remaining: remaining,
    daysSupply: daysSupplyOverride ?? extraction.daysSupply ?? 0,
  );
}

/// `"500 mg, 1 tablet"`-style display string from the structured fields --
/// [Prescription.dosage] is a single free-text field, [Extraction] keeps
/// strength/dose/form separate.
String _composeDosage(Extraction extraction) {
  final parts = [extraction.strength, extraction.dose, extraction.form]
      .where((p) => p != null && p.isNotEmpty)
      .toList();
  return parts.join(', ');
}
