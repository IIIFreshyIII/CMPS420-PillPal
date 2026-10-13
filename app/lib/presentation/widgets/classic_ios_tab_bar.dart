import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../core/utils/ios_design_era.dart';
import 'floating_tab_bar.dart' show AppTab;

/// The classic, docked iOS tab bar (UITabBar as it looked from iOS 7 through
/// iOS 18), used on iPhones that predate -- or never updated to -- iOS 26's
/// Liquid Glass. Android and iOS 26+ never see this.
///
/// Mirrors stock UIKit metrics and behaviour:
/// * Full width, flush to the bottom edge; 49pt tall plus the home-indicator
///   inset on Face ID iPhones (0 on home-button iPhones like the 8 / SE).
/// * 1-physical-pixel hairline along the top edge.
/// * Portrait: glyph stacked over a 10pt medium label. Landscape on iPhone
///   (compact height) shrinks to the 32pt bar with glyph and label side by
///   side, and wide layouts (iPad / regular width) sit them side by side in
///   the 49pt bar -- same as UIKit since iOS 11.
/// * Selection is an instant tint swap (outline -> filled glyph), with no
///   pill, bounce, or haptic -- stock tab bars never had them.
/// * Labels ignore Dynamic Type like system tab bars do (so large text can't
///   break the bar on small screens), but follow the Bold Text setting.
/// * Translucent chrome + blur only where the hardware handles it cheaply
///   (iOS 17+, i.e. A12-and-newer iPhones); older phones get an opaque bar
///   with no blur cost at all. Increase Contrast also forces opaque.
class ClassicIOSTabBar extends StatelessWidget {
  final AppTab activeTab;
  final ValueChanged<AppTab> onTabPress;

  /// Overrides the automatic translucency choice (used by tests).
  final bool? translucent;

  const ClassicIOSTabBar({
    super.key,
    required this.activeTab,
    required this.onTabPress,
    this.translucent,
  });

  /// UIKit tab bar heights.
  static const double regularHeight = 49.0;
  static const double compactHeight = 32.0;

  static const _items = [
    (
      tab: AppTab.schedule,
      label: 'Schedule',
      icon: CupertinoIcons.calendar_today,
      activeIcon: CupertinoIcons.calendar,
    ),
    (
      tab: AppTab.meds,
      label: 'Meds',
      icon: CupertinoIcons.capsule,
      activeIcon: CupertinoIcons.capsule_fill,
    ),
    (
      tab: AppTab.profile,
      label: 'Profile',
      icon: CupertinoIcons.person_crop_circle,
      activeIcon: CupertinoIcons.person_crop_circle_fill,
    ),
  ];

  static bool _defaultTranslucent() {
    final major = iosMajorVersion();
    return major != null && major >= 17;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final boldText = MediaQuery.boldTextOf(context);

    // iPhone landscape => compact-height bar; iPad/regular width => inline.
    final isCompactHeight = size.height < 500;
    final isInline = isCompactHeight || size.width >= 600;
    final barHeight = isCompactHeight ? compactHeight : regularHeight;

    final useTranslucency = (translucent ?? _defaultTranslucent()) &&
        !MediaQuery.highContrastOf(context);

    // Stock system-chrome tones, nudged a hair toward PillPal's palette.
    final opaqueBg = isDark ? const Color(0xFF141C1B) : const Color(0xFFF9F9F9);
    final background =
        useTranslucency ? opaqueBg.withValues(alpha: 0.88) : opaqueBg;
    final hairline =
        isDark ? const Color(0x33FFFFFF) : const Color(0x4D000000);
    const inactive = Color(0xFF8E8E93); // UIKit systemGray
    final active = c.teal;

    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        // width 0 => a true 1-physical-pixel hairline, like UIKit's shadowImage.
        border: Border(top: BorderSide(color: hairline, width: 0.0)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: [
              for (final item in _items)
                Expanded(
                  child: _ClassicTabItem(
                    label: item.label,
                    icon: activeTab == item.tab ? item.activeIcon : item.icon,
                    color: activeTab == item.tab ? active : inactive,
                    isSelected: activeTab == item.tab,
                    inline: isInline,
                    compact: isCompactHeight,
                    bold: boldText,
                    onTap: () => onTabPress(item.tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (useTranslucency) {
      bar = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: bar,
        ),
      );
    }

    return bar;
  }
}

class _ClassicTabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool inline;
  final bool compact;
  final bool bold;
  final VoidCallback onTap;

  const _ClassicTabItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.inline,
    required this.compact,
    required this.bold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // System tab bar labels don't grow with Dynamic Type.
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: inline ? 13 : 10,
        height: 1.2,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: inline ? -0.1 : 0.1,
        color: color,
      ),
    );

    final glyph = Icon(icon, size: compact ? 21 : (inline ? 24 : 26), color: color);

    final content = inline
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              glyph,
              const SizedBox(width: 6),
              Flexible(child: text),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              glyph,
              const SizedBox(height: 2),
              text,
            ],
          );

    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(child: content),
        ),
      ),
    );
  }
}
