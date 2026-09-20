class Prescription {
  final String id;
  final String profileId;
  final String name;
  final String dosage;
  final String time;
  final int remaining;
  final int daysSupply;
  final bool takenToday;

  const Prescription({
    required this.id,
    required this.profileId,
    required this.name,
    required this.dosage,
    required this.time,
    required this.remaining,
    required this.daysSupply,
    this.takenToday = false,
  });

  Prescription copyWith({
    String? id,
    String? profileId,
    String? name,
    String? dosage,
    String? time,
    int? remaining,
    int? daysSupply,
    bool? takenToday,
  }) {
    return Prescription(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      remaining: remaining ?? this.remaining,
      daysSupply: daysSupply ?? this.daysSupply,
      takenToday: takenToday ?? this.takenToday,
    );
  }
}