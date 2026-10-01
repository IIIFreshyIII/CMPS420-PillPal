import 'package:flutter/material.dart';

class Profile {
  final String id;
  final String name;
  final Color color;
  final bool isPrimary;

  /// Formatted like `10:00 PM`, same convention as `Prescription.reminderTimes`.
  /// Null means not set yet -- the reminder-time calculator then falls back
  /// to end-of-day rather than refusing to compute a schedule.
  final String? bedtime;

  const Profile({
    required this.id,
    required this.name,
    required this.color,
    this.isPrimary = false,
    this.bedtime,
  });

  Profile copyWith({
    String? id,
    String? name,
    Color? color,
    bool? isPrimary,
    String? bedtime,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isPrimary: isPrimary ?? this.isPrimary,
      bedtime: bedtime ?? this.bedtime,
    );
  }
}
