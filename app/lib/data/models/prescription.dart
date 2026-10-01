class Prescription {
  final String id;
  final String profileId;
  final String name;
  final String dosage;

  /// Ordered, formatted like `8:00 AM` -- one or more reminders a day,
  /// computed from the label's frequency text when periodic (see
  /// `core/scheduling/reminder_scheduler.dart`), otherwise just the single
  /// time the user picked.
  final List<String> reminderTimes;

  /// Which of today's [reminderTimes] have been marked taken. A set (not a
  /// single bool) because a prescription can now have several reminders a
  /// day, each independently taken or not.
  final Set<String> takenTimes;
  final int remaining;
  final int daysSupply;

  /// Per-medication override: let this one's reminders fire even after the
  /// assigned profile's bedtime cutoff.
  final bool allowAfterBedtime;

  const Prescription({
    required this.id,
    required this.profileId,
    required this.name,
    required this.dosage,
    required this.reminderTimes,
    required this.remaining,
    required this.daysSupply,
    this.takenTimes = const {},
    this.allowAfterBedtime = false,
  });

  Prescription copyWith({
    String? id,
    String? profileId,
    String? name,
    String? dosage,
    List<String>? reminderTimes,
    Set<String>? takenTimes,
    int? remaining,
    int? daysSupply,
    bool? allowAfterBedtime,
  }) {
    return Prescription(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      takenTimes: takenTimes ?? this.takenTimes,
      remaining: remaining ?? this.remaining,
      daysSupply: daysSupply ?? this.daysSupply,
      allowAfterBedtime: allowAfterBedtime ?? this.allowAfterBedtime,
    );
  }
}
