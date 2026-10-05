import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/pillpal_colors.dart';

class AndroidSlidingBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const AndroidSlidingBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const _tabs = [
    _TabItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      label: 'Schedule',
    ),
    _TabItem(
      icon: Icons.medication_outlined,
      activeIcon: Icons.medication_rounded,
      label: 'Meds',
    ),
    _TabItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Deliberately NOT MediaQuery.viewPadding.bottom: the system nav bar is
    // kept persistently hidden (main.dart), and that inset only ever becomes
    // non-zero for the brief moment a user's edge-swipe transiently reveals
    // it -- reacting to it made this bar visibly jump up and back down on
    // every such swipe. Fixed at 0 so this bar never moves.
    const double bottomInset = 0.0;
    const double barHeight = 80.0;
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        // Crisp, distinct container surface
        color: c.navSurface,
        border: Border(
          top: BorderSide(
            color: c.navBorder,
            width: 1.0,
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      height: barHeight + bottomInset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / _tabs.length;
          const double pillWidth = 64.0;
          const double pillHeight = 32.0;
          final pillLeft =
              (selectedIndex * tabWidth) + (tabWidth - pillWidth) / 2;

          return Stack(
            children: [
              // Smooth gliding Pill indicator behind active icon
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                left: pillLeft,
                top: 12,
                width: pillWidth,
                height: pillHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.mint,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
              ),

              // Interactive buttons. A transparent Material of its own, so the
              // ripple draws above the bar's fill and pill rather than on the
              // Scaffold's Material underneath them, where it was invisible.
              Material(
                type: MaterialType.transparency,
                child: Row(
                  children: List.generate(_tabs.length, (index) {
                    final isSelected = selectedIndex == index;
                    final item = _tabs[index];

                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          if (!isSelected) HapticFeedback.selectionClick();
                          onTabSelected(index);
                        },
                        splashColor: c.tealRipple,
                        highlightColor: Colors.transparent,
                        radius: 32,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: pillHeight,
                                child: Center(
                                  child: Icon(
                                    isSelected ? item.activeIcon : item.icon,
                                    size: 22,
                                    color: isSelected ? c.tealDeep : c.inkMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected ? c.tealDeep : c.inkMuted,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
