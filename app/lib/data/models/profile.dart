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

  Color get badgeColor => color;
  bool get isPrimaryUser => isPrimary;

  /// Returns 1 or 2 uppercase initials for avatar badges (e.g. "JD", "M").
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length.clamp(1, 2)).toUpperCase();
    }
    final first = parts[0].isNotEmpty ? parts[0][0] : '';
    final second = parts[1].isNotEmpty ? parts[1][0] : '';
    return '$first$second'.toUpperCase();
  }

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

/// Person model for multi-person medication scheduling and profile assignment.
typedef CareRecipient = Profile;
