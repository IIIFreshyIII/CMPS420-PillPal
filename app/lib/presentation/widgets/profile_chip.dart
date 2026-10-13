import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import 'pressable.dart';

/// Pill-shaped filter chip used to switch between profiles across Schedule,
/// Meds, and Dose History screens with physics press bounce and haptic response.
class ProfileChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const ProfileChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeColor = selectedColor ?? c.ink;
    final isDark =
        ThemeData.estimateBrightnessForColor(activeColor) == Brightness.dark;
    final textColor = isSelected
        ? (isDark ? Colors.white : c.ink)
        : c.inkMuted;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        haptic: isSelected ? PressHaptic.none : PressHaptic.selection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : c.borderChip,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: textColor,
              letterSpacing: -0.2,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
