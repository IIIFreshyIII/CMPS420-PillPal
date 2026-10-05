import 'dart:math';

import 'package:flutter/material.dart';

/// A tiny one-shot confetti burst at a point on screen (e.g. a dose check
/// that was just marked taken). Drawn in the [Overlay] so it isn't clipped by
/// the card it came from; ignores touches, and removes itself when done.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    required this.origin,
    required this.colors,
    required this.onDone,
  });

  static const duration = Duration(milliseconds: 650);
  static const _count = 12;

  /// Global position the burst starts from.
  final Offset origin;
  final List<Color> colors;
  final VoidCallback onDone;

  /// Plays one burst at [origin]. Does nothing with "Remove animations" on.
  static void show(
    BuildContext context, {
    required Offset origin,
    required List<Color> colors,
  }) {
    if (MediaQuery.of(context).disableAnimations || colors.isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => ConfettiBurst(
        origin: origin,
        colors: colors,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Piece {
  _Piece(Random r, this.color)
      : angle = -pi / 2 + (r.nextDouble() - 0.5) * pi * 1.4,
        speed = 70 + r.nextDouble() * 50,
        spin = (r.nextDouble() - 0.5) * 10,
        isDot = r.nextDouble() < 0.35;

  final double angle; // radians, mostly upward
  final double speed; // total outward travel, px
  final double spin; // radians per second
  final bool isDot;
  final Color color;
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: ConfettiBurst.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  late final List<_Piece> _pieces = () {
    final r = Random(widget.origin.hashCode);
    return [
      for (var i = 0; i < ConfettiBurst._count; i++)
        _Piece(r, widget.colors[i % widget.colors.length]),
    ];
  }();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(
          progress: _controller,
          origin: widget.origin,
          pieces: _pieces,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.progress,
    required this.origin,
    required this.pieces,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Offset origin;
  final List<_Piece> pieces;

  static const _gravity = 200.0; // px/s^2

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    final t = p * ConfettiBurst.duration.inMilliseconds / 1000;
    final opacity = p < 0.6 ? 1.0 : (1 - (p - 0.6) / 0.4).clamp(0.0, 1.0);
    final paint = Paint();

    for (final piece in pieces) {
      // Outward travel eases out (a pop, then drift); gravity pulls down.
      final out = piece.speed * Curves.easeOutCubic.transform(p);
      final dx = cos(piece.angle) * out;
      final dy = sin(piece.angle) * out + 0.5 * _gravity * t * t;
      paint.color = piece.color.withValues(alpha: piece.color.a * opacity);

      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      if (piece.isDot) {
        canvas.drawCircle(Offset.zero, 2.2, paint);
      } else {
        canvas.rotate(piece.spin * t);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2, -3.5, 4, 7),
            const Radius.circular(1.2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.origin != origin || old.pieces != pieces;
}
