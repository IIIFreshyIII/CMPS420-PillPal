/// A confirmed medication profile.
///
/// Per the project spec: no confidence-based shortcuts — a Medication only comes
/// into existence after a human has checked every field on the ConfirmScreen.
class Medication {
  Medication({
    required this.id,
    this.drug,
    this.strength,
    this.dose,
    this.form,
    this.route,
    this.frequency,
    this.duration,
    this.fillDate,
    this.daysSupply,
  });

  final String id;
  final String? drug;
  final String? strength;
  final String? dose;
  final String? form;
  final String? route;
  final String? frequency;
  final String? duration;
  final DateTime? fillDate;
  final int? daysSupply;

  /// Plain arithmetic — never predicted by a model (spec rule).
  DateTime? get refillDate => (fillDate != null && daysSupply != null)
      ? fillDate!.add(Duration(days: daysSupply!))
      : null;

  /// First of the two-stage refill warnings: 7 days before running out.
  DateTime? get refillWarnDate =>
      refillDate?.subtract(const Duration(days: 7));

  String get displayName =>
      (drug?.trim().isNotEmpty ?? false) ? drug!.trim() : 'Unnamed medication';
}
