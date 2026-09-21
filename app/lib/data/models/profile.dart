import 'package:flutter/material.dart';

class Profile {
  final String id;
  final String name;
  final Color color;
  final bool isPrimary;

  const Profile({
    required this.id,
    required this.name,
    required this.color,
    this.isPrimary = false,
  });
}