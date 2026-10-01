/// Refill-date arithmetic -- plain math, never predicted by a model (spec
/// rule: `med-tracker-spec.md` §1). Extracted as standalone functions so
/// they're usable before the rest of the NER pipeline (regex date/days-supply
/// extraction) lands in this same `core/ner/` module.
library;

/// Fill date + days supply. `null` unless both inputs are present.
DateTime? computeRefillDate({DateTime? fillDate, int? daysSupply}) {
  if (fillDate == null || daysSupply == null) return null;
  return fillDate.add(Duration(days: daysSupply));
}

/// First of the two-stage refill warnings: 7 days before running out.
DateTime? computeRefillWarnDate({DateTime? fillDate, int? daysSupply}) {
  final refill = computeRefillDate(fillDate: fillDate, daysSupply: daysSupply);
  return refill?.subtract(const Duration(days: 7));
}
