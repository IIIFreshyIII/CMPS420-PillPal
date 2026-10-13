enum DoseAction {
  taken,
  late,
  skipped;

  bool get isTaken => this == DoseAction.taken || this == DoseAction.late;
  bool get isOnTime => this == DoseAction.taken;
  bool get isLate => this == DoseAction.late;
  bool get isSkipped => this == DoseAction.skipped;
}

/// A single historical record of a dose being marked taken (on time or late)
/// or skipped -- what the Meds tab's adherence graph and history feed are built from.
/// Unlike [Prescription.takenToday] (a single boolean that resets daily), this is
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
