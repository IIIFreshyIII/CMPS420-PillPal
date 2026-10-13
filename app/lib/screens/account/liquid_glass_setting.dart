import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/liquid_glass_controller.dart';
import '../../core/theme/liquid_glass_mode.dart';
import '../../core/theme/pillpal_colors.dart';

/// Profile → Preferences & Storage → Liquid Glass Effect:
/// Allows iOS 26+ users to configure the translucency and blur of the floating
/// hotbar, or leave it in [LiquidGlassMode.auto] which dynamically respects iOS
/// Reduce Transparency, Increase Contrast, and Reduce Motion accessibility settings.
class LiquidGlassSetting extends StatelessWidget {
  const LiquidGlassSetting({super.key, required this.controller});

  final LiquidGlassController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<LiquidGlassMode>(
      valueListenable: controller,
      builder: (context, mode, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.sparkles, size: 20, color: c.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Liquid Glass Effect',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LiquidGlassSwitch(mode: mode, onChanged: controller.select),
            const SizedBox(height: 10),
            Text(
              mode.description,
              style: TextStyle(
                fontSize: 12,
                color: c.inkMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiquidGlassSwitch extends StatelessWidget {
  const LiquidGlassSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final LiquidGlassMode mode;
  final ValueChanged<LiquidGlassMode> onChanged;

  static const _options = [
    (LiquidGlassMode.auto, Icons.tune_rounded, 'Auto'),
    (LiquidGlassMode.liquid, Icons.water_drop_rounded, 'Liquid'),
    (LiquidGlassMode.frosted, Icons.blur_on_rounded, 'Frosted'),
    (LiquidGlassMode.opaque, Icons.crop_square_rounded, 'Opaque'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = _options.indexWhere((o) => o.$1 == mode);
    final instant = MediaQuery.of(context).disableAnimations;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.segmentTrack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / _options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration:
                    instant ? Duration.zero : const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                left: selected * w,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.segmentThumb,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: c.liftShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (m, icon, label) in _options)
                        Expanded(
                          child: Semantics(
                            selected: m == mode,
                            button: true,
                            child: InkWell(
                              key: ValueKey('liquid_glass_${m.name}'),
                              borderRadius: BorderRadius.circular(8),
                              splashColor: c.tealRipple,
                              highlightColor: Colors.transparent,
                              onTap: m == mode ? null : () => onChanged(m),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    icon,
                                    size: 15,
                                    color: m == mode ? c.ink : c.inkMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: m == mode
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: m == mode ? c.ink : c.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
