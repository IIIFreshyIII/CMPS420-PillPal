import 'package:flutter/material.dart';
import '../../core/theme/pillpal_colors.dart';

/// Inline brand logo component for PillPal.
///
/// Currently renders styled brand typography with a signature teal gradient and
/// micro pill symbol. Designed as an isolated component so a custom SVG/vector asset
/// can be dropped in later without affecting surrounding layout or typography metrics.
class PillPalInlineLogo extends StatelessWidget {
  const PillPalInlineLogo({
    super.key,
    this.fontSize = 28,
    this.fontWeight = FontWeight.w900,
    this.letterSpacing = -0.8,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [c.tealDeep, c.teal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'PillPal',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
              fontFamily: '.SF Pro Display',
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: fontSize * 0.28,
          height: fontSize * 0.28,
          decoration: BoxDecoration(
            color: c.teal,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.teal.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
