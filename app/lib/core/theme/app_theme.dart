import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFFF8FAFA);
  static const Color headerTeal = Color(0xFF92D6D3);
  static const Color textPrimary = Color(0xFF102A29);
  static const Color textSecondary = Color(0xFF526A69);
  static const Color interactiveTeal = Color(0xFF168B87);
  static const Color lightPillTint = Color(0xFFE4F6F4);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color lowStockAlert = Color(0xFFE11D48);
  static const Color borderLight = Color(0xFFEFF5F4);

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: background,
      primaryColor: interactiveTeal,
      fontFamily: '.SF Pro Text', // Native iOS fallback
      colorScheme: const ColorScheme.light(
        primary: interactiveTeal,
        surface: cardWhite,
        onSurface: textPrimary,
      ),
    );
  }
}