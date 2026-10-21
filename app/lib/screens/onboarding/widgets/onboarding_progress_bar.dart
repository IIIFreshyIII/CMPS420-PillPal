import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';

/// Segmented horizontal onboarding progress indicator.
///
/// Renders [totalSteps] thin segmented bars where steps 0 through [currentStep]
/// are filled with [activeColor] (default PillPal teal), and subsequent steps
/// remain unfilled with [inactiveColor] (default PillPal borderLight).
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 6,
    this.activeColor,
    this.inactiveColor,
  });

  /// 0-indexed current active step (e.g. 0 to 5 for 6 total steps).
  final int currentStep;

  /// Total number of segmented indicator bars.
  final int totalSteps;

  /// Color for completed or active segment bars.
  final Color? activeColor;

  /// Color for future, unreached segment bars.
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = activeColor ?? c.teal;
    final inactive = inactiveColor ?? c.borderLight;

    return Row(
      children: List.generate(totalSteps, (index) {
        final isDoneOrCurrent = index <= currentStep;
        return Expanded(
          child: Container(
            height: 3.5,
            margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: isDoneOrCurrent ? active : inactive,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
