import 'package:flutter/material.dart';

/// Compact glass-pill zoom selector (`1x`, `2x`, `3x`) for the camera scanner
/// overlays so users can zoom one-handed while holding a pill bottle.
class CameraZoomBar extends StatelessWidget {
  const CameraZoomBar({
    super.key,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onSelectZoom,
  });

  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onSelectZoom;

  @override
  Widget build(BuildContext context) {
    final presets = <double>[1.0, 2.0, 3.0]
        .where((z) => z >= minZoom && z <= maxZoom + 0.05)
        .toList();
    if (presets.length < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: presets.map((z) {
          final isSelected = (currentZoom - z).abs() < 0.35;
          final label = '${z.toInt()}x';
          return GestureDetector(
            key: Key('camera_zoom_${z.toInt()}x'),
            onTap: () => onSelectZoom(z.clamp(minZoom, maxZoom)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFFFD600)
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
