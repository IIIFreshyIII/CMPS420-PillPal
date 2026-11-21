class Prescription {
  final String id;
  final String profileId;
  final String name;
  final String dosage;

  /// Amount per pill/unit (e.g. `"500 mg"`). Optional for legacy rows where
  /// only the combined [dosage] string was stored.
  final String? strength;

  /// Human-readable dose per intake (e.g. `"2 tablets"`, `"1 capsule"`).
  final String? doseAmount;

  /// Numeric count deducted from [remaining] each time a single dose is marked
  /// taken (e.g. `2` when taking 2 tablets per dose). Defaults to `1`.
  final int doseQuantity;

  /// Medication form/type (e.g. `"Pill / Oral"`, `"Liquid"`, `"Inhaler"`).
  final String? form;

  /// Food requirement: `'with_food'`, `'without_food'`, or `'anytime'`.
  final String? foodInstruction;

  /// Ordered, formatted like `8:00 AM` -- one or more reminders a day,
  /// computed from the label's frequency text when periodic (see
  /// `core/scheduling/reminder_scheduler.dart`), otherwise just the single
  /// time the user picked. Empty for As-Needed medications.
  final List<String> reminderTimes;

  /// Which of today's [reminderTimes] have been marked taken. A set (not a
  /// single bool) because a prescription can now have several reminders a
  /// day, each independently taken or not.
  final Set<String> takenTimes;
  final int remaining;
  final int daysSupply;
  final int refillsRemaining;

  /// Per-medication override: let this one's reminders fire even after the
  /// device's bedtime cutoff.
  final bool allowAfterBedtime;

  /// True for PRN / As-Needed medications (no fixed daily reminder times;
  /// uses [cooldownMinutes] instead — full Schedule UI lands in Chunk 3).
  final bool isAsNeeded;

  /// Optional minimum interval (in minutes) between As-Needed doses.
  final int? cooldownMinutes;

  const Prescription({
    required this.id,
    required this.profileId,
    required this.name,
    required this.dosage,
    this.strength,
    this.doseAmount,
    this.doseQuantity = 1,
    this.form,
    this.foodInstruction,
    required this.reminderTimes,
    required this.remaining,
    required this.daysSupply,
    this.refillsRemaining = 0,
    this.takenTimes = const {},
    this.allowAfterBedtime = false,
    this.isAsNeeded = false,
    this.cooldownMinutes,
  });

  /// Extracts a positive integer unit count from a free-text dose string such
  /// as `"2 tablets"`, `"Take two capsules"`, or `"3 puffs"`. Defaults to `1`.
  static int parseDoseQuantity(String? rawDose) {
    if (rawDose == null) return 1;
    final trimmed = rawDose.trim().toLowerCase();
    if (trimmed.isEmpty) return 1;

    final numMatch = RegExp(r'\b(\d+)\b').firstMatch(trimmed);
    if (numMatch != null) {
      final parsed = int.tryParse(numMatch.group(1)!);
      if (parsed != null && parsed >= 1) {
        return parsed.clamp(1, 99);
      }
    }

    const wordMap = <String, int>{
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
    };
    for (final entry in wordMap.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(trimmed)) {
        return entry.value;
      }
    }
    return 1;
  }

  /// Composes a clean display [dosage] string from separate [strength],
  /// [doseAmount], and [form] fields.
  static String composeDosage({
    String? strength,
    String? doseAmount,
    String? form,
  }) {
    final parts = <String>[];
    final s = strength?.trim() ?? '';
    final d = doseAmount?.trim() ?? '';
    final f = form?.trim() ?? '';
    if (s.isNotEmpty) parts.add(s);
    if (d.isNotEmpty) parts.add(d);
    if (f.isNotEmpty &&
        f.toLowerCase() != 'pill / oral' &&
        !d.toLowerCase().contains(f.toLowerCase())) {
      parts.add(f);
    }
    return parts.join(', ');
  }

  /// Effective units taken per dose (always at least 1).
  int get effectiveDoseQuantity => doseQuantity < 1 ? 1 : doseQuantity;

  /// Effective daily consumption in bottle units for scheduled medications.
  int get dailyDoseUnits {
    if (isAsNeeded || reminderTimes.isEmpty) return effectiveDoseQuantity;
    return effectiveDoseQuantity * reminderTimes.length;
  }

  /// Computes updated `daysSupply` when [newRemaining] changes after taking or
  /// undoing [deltaDoses] doses (+1 when undoing, -1 when taking).
  int adjustedDaysSupply({
    required int newRemaining,
    required int deltaDoses,
  }) {
    final daily = dailyDoseUnits;
    if (daily <= 1) {
      return (daysSupply + deltaDoses).clamp(0, 9999);
    }
    if (newRemaining <= 0) return 0;
    return (newRemaining / daily).ceil().clamp(0, 9999);
  }

  static const Object _unset = Object();

  Prescription copyWith({
    String? id,
    String? profileId,
    String? name,
    String? dosage,
    Object? strength = _unset,
    Object? doseAmount = _unset,
    int? doseQuantity,
    Object? form = _unset,
    Object? foodInstruction = _unset,
    List<String>? reminderTimes,
    Set<String>? takenTimes,
    int? remaining,
    int? daysSupply,
    int? refillsRemaining,
    bool? allowAfterBedtime,
    bool? isAsNeeded,
    Object? cooldownMinutes = _unset,
  }) {
    return Prescription(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      strength: identical(strength, _unset) ? this.strength : strength as String?,
      doseAmount:
          identical(doseAmount, _unset) ? this.doseAmount : doseAmount as String?,
      doseQuantity: doseQuantity ?? this.doseQuantity,
      form: identical(form, _unset) ? this.form : form as String?,
      foodInstruction: identical(foodInstruction, _unset)
          ? this.foodInstruction
          : foodInstruction as String?,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      takenTimes: takenTimes ?? this.takenTimes,
      remaining: remaining ?? this.remaining,
      daysSupply: daysSupply ?? this.daysSupply,
      refillsRemaining: refillsRemaining ?? this.refillsRemaining,
      allowAfterBedtime: allowAfterBedtime ?? this.allowAfterBedtime,
      isAsNeeded: isAsNeeded ?? this.isAsNeeded,
      cooldownMinutes: identical(cooldownMinutes, _unset)
          ? this.cooldownMinutes
          : cooldownMinutes as int?,
    );
  }
}
