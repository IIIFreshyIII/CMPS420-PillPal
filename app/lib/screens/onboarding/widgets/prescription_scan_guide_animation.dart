import 'dart:math';

import 'package:flutter/material.dart';

/// A dedicated, continuously looping 2-phase vector animation widget displayed
/// above the scanner cutout window.
///
/// Phase 1 (Pill Bottle):
///   - Renders a clean white pill bottle graphic
///   - Animates a bright yellow vertical line appearing on the far-left edge of the label
///   - Animates a circular clockwise arrow above the bottle while illustrating clockwise rotation
///   - Slides the bottle slightly upward while fading it out (Opacity -> 0.0)
///
/// Phase 2 (Medication Box):
///   - Fades in a white medication box graphic in its place
///   - Animates the bright yellow vertical alignment line on the far-left edge of the box label
///   - Animates the circular clockwise arrow above it while the box rotates clockwise
///   - Slides the box slightly upward and fades out, looping seamlessly back to Phase 1.
class PrescriptionScanGuideAnimation extends StatefulWidget {
  const PrescriptionScanGuideAnimation({
    super.key,
    this.width = 180,
    this.height = 100,
    this.duration = const Duration(milliseconds: 5200),
  });

  final double width;
  final double height;
  final Duration duration;

  @override
  State<PrescriptionScanGuideAnimation> createState() =>
      _PrescriptionScanGuideAnimationState();
}

class _PrescriptionScanGuideAnimationState
    extends State<PrescriptionScanGuideAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _ScanGuidePainter(progress: _controller.value),
          );
        },
      ),
    );
  }
}

class _ScanGuidePainter extends CustomPainter {
  _ScanGuidePainter({required this.progress});

  /// 0.0 to 1.0 total loop progress
  final double progress;

  static const Color yellowLineColor = Color(0xFFFFD600);
  static const Color whiteGraphicColor = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2 + 6;

    if (progress < 0.5) {
      // Phase 1: Bottle (0.00 -> 0.50)
      final p1 = progress / 0.5;
      _paintBottlePhase(canvas, centerX, centerY, p1);
    } else {
      // Phase 2: Box (0.50 -> 1.00)
      final p2 = (progress - 0.5) / 0.5;
      _paintBoxPhase(canvas, centerX, centerY, p2);
    }
  }

  void _paintBottlePhase(
      Canvas canvas, double cx, double cy, double t) {
    // Timing breakdown:
    // 0.00..0.15: Fade & slide in
    // 0.15..0.35: Yellow line draws on far-left edge
    // 0.25..0.75: Clockwise arrow spins + bottle illustrates rotation
    // 0.80..1.00: Slide up & fade out
    double opacity = 1.0;
    double yOffset = 0.0;

    if (t < 0.15) {
      final inT = t / 0.15;
      opacity = inT;
      yOffset = (1.0 - inT) * 8.0;
    } else if (t > 0.80) {
      final outT = (t - 0.80) / 0.20;
      opacity = (1.0 - outT).clamp(0.0, 1.0);
      yOffset = -outT * 18.0;
    }

    // Yellow line draw progress
    double lineProgress = 0.0;
    if (t >= 0.15 && t <= 0.38) {
      lineProgress = ((t - 0.15) / 0.23).clamp(0.0, 1.0);
    } else if (t > 0.38) {
      lineProgress = 1.0;
    }

    // Rotation & arrow
    double arrowOpacity = 0.0;
    double arrowAngle = 0.0;
    double spinProgress = 0.0;

    if (t >= 0.25 && t <= 0.80) {
      final spinT = (t - 0.25) / 0.55;
      arrowOpacity = sin(spinT * pi).clamp(0.0, 1.0);
      arrowAngle = spinT * 2.5 * pi;
      spinProgress = Curves.easeInOutCubic.transform(spinT);
    }

    canvas.save();
    canvas.translate(cx, cy + yOffset);

    // 3D Perspective Matrix for Pill Bottle
    if (spinProgress > 0) {
      final m = Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateY(sin(spinProgress * pi) * 0.28);
      canvas.transform(m.storage);
    }

    final bottlePaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.10)
      ..style = PaintingStyle.fill;

    // Dimensions for Pill Bottle
    const capWidth = 24.0;
    const capHeight = 7.0;
    const neckWidth = 18.0;
    const neckHeight = 4.0;
    const bodyWidth = 36.0;
    const bodyHeight = 44.0;
    const totalHalfHeight = (capHeight + neckHeight + bodyHeight) / 2;

    const topY = -totalHalfHeight;

    // 1. Cap
    final capRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(0, topY + capHeight / 2),
        width: capWidth,
        height: capHeight,
      ),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(capRect, fillPaint);
    canvas.drawRRect(capRect, bottlePaint);

    // Vertical ribs on cap that shift as the bottle rotates
    final ribPaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.35)
      ..strokeWidth = 1.0;
    for (int r = -2; r <= 2; r++) {
      final ribBaseX = r * 4.0;
      final ribX = ribBaseX + (spinProgress * 6.0) % 8.0 - 4.0;
      if (ribX.abs() < capWidth / 2 - 2) {
        canvas.drawLine(
          Offset(ribX, topY + 1.5),
          Offset(ribX, topY + capHeight - 1.5),
          ribPaint,
        );
      }
    }

    // 2. Neck
    final neckRect = Rect.fromCenter(
      center: const Offset(0, topY + capHeight + neckHeight / 2),
      width: neckWidth,
      height: neckHeight,
    );
    canvas.drawRect(neckRect, fillPaint);
    canvas.drawRect(neckRect, bottlePaint);

    // 3. Body
    const bodyCenterY = topY + capHeight + neckHeight + bodyHeight / 2;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(0, bodyCenterY),
        width: bodyWidth,
        height: bodyHeight,
      ),
      const Radius.circular(6.0),
    );
    canvas.drawRRect(bodyRect, fillPaint);
    canvas.drawRRect(bodyRect, bottlePaint);

    // 4. Bottle Label - Illustrates 3D horizontal wrap around the cylinder
    const labelBaseWidth = 28.0;
    const labelHeight = 30.0;
    // As the bottle rotates clockwise, the label and its yellow alignment line sweep across
    final labelSweepX = spinProgress * 18.0;
    final labelWidth = (labelBaseWidth - spinProgress * 6.0).clamp(16.0, 28.0);
    final labelCenterX = -2.0 + labelSweepX;

    final labelRect = Rect.fromCenter(
      center: Offset(labelCenterX, bodyCenterY),
      width: labelWidth,
      height: labelHeight,
    );
    final labelBorderPaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(3.0)),
      labelBorderPaint,
    );

    // Label faint text lines sweeping across
    final linePaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    if (labelRect.width > 12) {
      canvas.drawLine(
        Offset(labelRect.left + 5, labelRect.top + 7),
        Offset(labelRect.right - 4, labelRect.top + 7),
        linePaint,
      );
      canvas.drawLine(
        Offset(labelRect.left + 5, labelRect.top + 14),
        Offset(labelRect.right - 8, labelRect.top + 14),
        linePaint,
      );
      canvas.drawLine(
        Offset(labelRect.left + 5, labelRect.top + 21),
        Offset(labelRect.right - 5, labelRect.top + 21),
        linePaint,
      );
    }

    // 5. Bright Yellow Vertical Line on Far-Left Edge of Label
    // Sweeps horizontally across cylinder as user rotates the bottle
    if (lineProgress > 0) {
      final yellowStartY = labelRect.top;
      final yellowEndY = labelRect.top + labelHeight * lineProgress;
      final yellowX = labelRect.left + 0.5;

      // Glow behind
      final glowPaint = Paint()
        ..color = yellowLineColor.withValues(alpha: opacity * 0.5)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawLine(
        Offset(yellowX, yellowStartY),
        Offset(yellowX, yellowEndY),
        glowPaint,
      );

      // Core crisp line
      final yellowPaint = Paint()
        ..color = yellowLineColor.withValues(alpha: opacity)
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(yellowX, yellowStartY),
        Offset(yellowX, yellowEndY),
        yellowPaint,
      );
    }

    // 6. Spinning Clockwise Circular Arrow above the bottle
    if (arrowOpacity > 0) {
      _paintClockwiseArrow(canvas, 0, topY - 14, arrowAngle, arrowOpacity * opacity);
    }

    canvas.restore();
  }

  void _paintBoxPhase(
      Canvas canvas, double cx, double cy, double t) {
    // Timing breakdown:
    // 0.00..0.15: Fade & slide in
    // 0.15..0.35: Yellow line draws on far-left edge of box label
    // 0.25..0.75: Clockwise arrow spins + box illustrates rotation
    // 0.80..1.00: Slide up & fade out
    double opacity = 1.0;
    double yOffset = 0.0;

    if (t < 0.15) {
      final inT = t / 0.15;
      opacity = inT;
      yOffset = (1.0 - inT) * 8.0;
    } else if (t > 0.80) {
      final outT = (t - 0.80) / 0.20;
      opacity = (1.0 - outT).clamp(0.0, 1.0);
      yOffset = -outT * 18.0;
    }

    // Yellow line draw progress
    double lineProgress = 0.0;
    if (t >= 0.15 && t <= 0.38) {
      lineProgress = ((t - 0.15) / 0.23).clamp(0.0, 1.0);
    } else if (t > 0.38) {
      lineProgress = 1.0;
    }

    // Rotation & arrow
    double arrowOpacity = 0.0;
    double arrowAngle = 0.0;
    double spinProgress = 0.0;

    if (t >= 0.25 && t <= 0.80) {
      final spinT = (t - 0.25) / 0.55;
      arrowOpacity = sin(spinT * pi).clamp(0.0, 1.0);
      arrowAngle = spinT * 2.5 * pi;
      spinProgress = Curves.easeInOutCubic.transform(spinT);
    }

    canvas.save();
    canvas.translate(cx, cy + yOffset);

    // 3D Perspective Matrix for Medication Box
    if (spinProgress > 0) {
      final m = Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateY(sin(spinProgress * pi) * 0.38);
      canvas.transform(m.storage);
    }

    final boxPaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.10)
      ..style = PaintingStyle.fill;

    // Dimensions for Medication Box
    const boxWidth = 44.0;
    const boxHeight = 44.0;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(0, 0),
        width: boxWidth,
        height: boxHeight,
      ),
      const Radius.circular(5.0),
    );

    // Box body
    canvas.drawRRect(boxRect, fillPaint);
    canvas.drawRRect(boxRect, boxPaint);

    // Top box crease flap
    final flapPaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
      const Offset(-boxWidth / 2, -boxHeight / 2 + 7),
      const Offset(boxWidth / 2, -boxHeight / 2 + 7),
      flapPaint,
    );

    // Rx Cross or emblem in top-right
    final crossPaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      const Offset(boxWidth / 2 - 10, -boxHeight / 2 + 13),
      const Offset(boxWidth / 2 - 4, -boxHeight / 2 + 13),
      crossPaint,
    );
    canvas.drawLine(
      const Offset(boxWidth / 2 - 7, -boxHeight / 2 + 10),
      const Offset(boxWidth / 2 - 7, -boxHeight / 2 + 16),
      crossPaint,
    );

    // Box Label panel - Sweeps horizontally as box illustrates 3D clockwise rotation
    const labelBaseWidth = 34.0;
    const labelHeight = 22.0;
    final labelSweepX = spinProgress * 14.0;
    final labelWidth = (labelBaseWidth - spinProgress * 8.0).clamp(18.0, 34.0);
    final labelCenterX = labelSweepX;

    final labelRect = Rect.fromCenter(
      center: Offset(labelCenterX, 8),
      width: labelWidth,
      height: labelHeight,
    );

    final labelBorderPaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(2.5)),
      labelBorderPaint,
    );

    // Faint label lines
    final linePaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: opacity * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    if (labelRect.width > 12) {
      canvas.drawLine(
        Offset(labelRect.left + 6, labelRect.top + 6),
        Offset(labelRect.right - 5, labelRect.top + 6),
        linePaint,
      );
      canvas.drawLine(
        Offset(labelRect.left + 6, labelRect.top + 12),
        Offset(labelRect.right - 8, labelRect.top + 12),
        linePaint,
      );
      canvas.drawLine(
        Offset(labelRect.left + 6, labelRect.top + 17),
        Offset(labelRect.right - 5, labelRect.top + 17),
        linePaint,
      );
    }

    // Bright Yellow Vertical Alignment Line on Far-Left Edge of Box Label
    // Sweeps horizontally illustrating 3D clockwise face rotation
    if (lineProgress > 0) {
      final yellowStartY = labelRect.top;
      final yellowEndY = labelRect.top + labelHeight * lineProgress;
      final yellowX = labelRect.left + 0.5;

      // Glow
      final glowPaint = Paint()
        ..color = yellowLineColor.withValues(alpha: opacity * 0.5)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawLine(
        Offset(yellowX, yellowStartY),
        Offset(yellowX, yellowEndY),
        glowPaint,
      );

      // Core
      final yellowPaint = Paint()
        ..color = yellowLineColor.withValues(alpha: opacity)
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(yellowX, yellowStartY),
        Offset(yellowX, yellowEndY),
        yellowPaint,
      );
    }

    // Spinning Clockwise Circular Arrow above the box
    if (arrowOpacity > 0) {
      _paintClockwiseArrow(
          canvas, 0, -boxHeight / 2 - 13, arrowAngle, arrowOpacity * opacity);
    }

    canvas.restore();
  }

  void _paintClockwiseArrow(
      Canvas canvas, double cx, double cy, double rotationAngle, double alpha) {
    if (alpha <= 0) return;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationAngle);

    final arrowPaint = Paint()
      ..color = whiteGraphicColor.withValues(alpha: alpha * 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    const radius = 8.5;
    // Draw ~260 degree arc
    const startAngle = -pi * 0.8;
    const sweepAngle = pi * 1.45;
    final arcRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, arrowPaint);

    // Arrowhead at the end of arc
    const endAngle = startAngle + sweepAngle;
    final endX = radius * cos(endAngle);
    final endY = radius * sin(endAngle);

    // Tangent direction + normal for arrowhead points
    final tangentX = -sin(endAngle);
    final tangentY = cos(endAngle);
    final normalX = -tangentY;
    final normalY = tangentX;

    const arrowHeadLen = 3.5;
    const arrowHeadWidth = 2.5;

    final path = Path()
      ..moveTo(endX + tangentX * arrowHeadLen, endY + tangentY * arrowHeadLen)
      ..lineTo(endX + normalX * arrowHeadWidth, endY + normalY * arrowHeadWidth)
      ..lineTo(endX - normalX * arrowHeadWidth, endY - normalY * arrowHeadWidth)
      ..close();

    final headFill = Paint()
      ..color = whiteGraphicColor.withValues(alpha: alpha * 0.90)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, headFill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScanGuidePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
