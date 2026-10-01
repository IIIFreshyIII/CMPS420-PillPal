enum DoseAction { taken, skipped }

/// A single historical record of a dose being marked taken or skipped --
/// what the Meds tab's history feed is built from. Unlike
/// [Prescription.takenToday] (a single boolean that resets daily), this is
/// an append-only log, so "when did I last take this" is real data instead
/// of a UI guess.
class DoseEvent {
  final String id;
  final String prescriptionId;
  final String profileId;
  final DateTime occurredAt;
  final DoseAction action;

  const DoseEvent({
    required this.id,
    required this.prescriptionId,
    required this.profileId,
    required this.occurredAt,
    required this.action,
  });
}
