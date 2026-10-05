import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../core/theme/theme_controller.dart';

/// Profile → Preferences & Storage → Appearance: a tile holding a System /
/// Light / Dark segmented switch. The choice applies and saves immediately;
/// the haptic lives in [ThemeController.select].
class AppearanceSetting extends StatelessWidget {
  const AppearanceSetting({super.key, required this.controller});

  final ThemeController controller;

  static String _label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, mode, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderLight),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.circle_lefthalf_fill,
                    size: 20, color: c.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  _label(mode),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppearanceSwitch(mode: mode, onChanged: controller.select),
          ],
        ),
      ),
    );
  }
}

class AppearanceSwitch extends StatelessWidget {
  const AppearanceSwitch(
      {super.key, required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = [
    (ThemeMode.system, Icons.smartphone_rounded, 'System'),
    (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
    (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
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
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / _options.length;
        return Stack(children: [
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
                      offset: const Offset(0, 2)),
                ],
              ),
            ),
          ),
          // Transparent Material so the InkWell ripple draws above the track.
          // Positioned.fill + stretch: each segment fills the thumb's full
          // height, so its icon and label sit centred in it rather than
          // shrinking to the text and sticking to the top of the Stack.
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
                            key: ValueKey('appearance_${m.name}'),
                            borderRadius: BorderRadius.circular(8),
                            splashColor: c.tealRipple,
                            highlightColor: Colors.transparent,
                            onTap: m == mode ? null : () => onChanged(m),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon,
                                    size: 16,
                                    color: m == mode ? c.ink : c.inkMuted),
                                const SizedBox(width: 6),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
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
                  ]),
            ),
          ),
        ]);
      }),
    );
  }
}
