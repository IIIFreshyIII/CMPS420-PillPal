import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';

/// iOS-style sheet grabber handle that rests as a horizontal rounded pill and
/// smoothly morphs into an upward-pointing chevron (`^`) when dragged upward
/// (`bend < 0`) or a downward-pointing chevron (`v`) when dragged downward
/// (`bend > 0`).
class MorphingSheetGrabber extends StatelessWidget {
  const MorphingSheetGrabber({
    super.key,
    this.bend = 0.0,
    this.width = 36.0,
    this.strokeWidth = 4.5,
    this.color,
    this.padding = const EdgeInsets.only(top: 10, bottom: 6),
  });

  /// Normalized morph factor in `[-1.0, 1.0]`:
  /// - `-1.0`: full upward-pointing chevron (`^`)
  /// - `0.0`: resting flat pill bar (`—`)
  /// - `+1.0`: full downward-pointing chevron (`v`)
  final double bend;
  final double width;
  final double strokeWidth;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.colors.grabber;
    final clampedBend = bend.clamp(-1.0, 1.0);

    return Center(
      child: Padding(
        padding: padding,
        child: SizedBox(
          width: width + 8,
          height: 14,
          child: CustomPaint(
            painter: _MorphingGrabberPainter(
              bend: clampedBend,
              width: width,
              strokeWidth: strokeWidth,
              color: effectiveColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphingGrabberPainter extends CustomPainter {
  const _MorphingGrabberPainter({
    required this.bend,
    required this.width,
    required this.strokeWidth,
    required this.color,
  });

  final double bend;
  final double width;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final halfWidth = (width / 2) + (bend.abs() * 1.5);
    final cx = size.width / 2;

    // Positive bend dips center downward (`v`); negative bend lifts center upward (`^`).
    final centerY = cy + (bend * 4.2);
    final edgeY = cy - (bend * 2.2);

    final path = Path()
      ..moveTo(cx - halfWidth, edgeY)
      ..lineTo(cx, centerY)
      ..lineTo(cx + halfWidth, edgeY);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MorphingGrabberPainter oldDelegate) {
    return oldDelegate.bend != bend ||
        oldDelegate.width != width ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}
