import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

enum AppTab { schedule, meds, profile }

class FloatingTabBar extends StatefulWidget {
  final AppTab activeTab;
  final ValueChanged<AppTab> onTabPress;

  const FloatingTabBar({
    super.key,
    required this.activeTab,
    required this.onTabPress,
  });

  @override
  State<FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends State<FloatingTabBar> {
  bool _isDragging = false;
  double _dragRatio = 0.0;

  @override
  void didUpdateWidget(FloatingTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _dragRatio = widget.activeTab.index.toDouble();
    }
  }

  @override
  void initState() {
    super.initState();
    _dragRatio = widget.activeTab.index.toDouble();
  }

  void _handleDragStart(DragStartDetails details) {
    HapticFeedback.mediumImpact();
    setState(() => _isDragging = true);
  }

  void _handleDragUpdate(DragUpdateDetails details, double totalWidth) {
    final tabWidth = totalWidth / AppTab.values.length;
    final newRatio = (details.localPosition.dx / tabWidth - 0.5).clamp(0.0, 2.0);

    final previousTarget = _dragRatio.round();
    final newTarget = newRatio.round();
    if (previousTarget != newTarget) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _dragRatio = newRatio;
    });
  }

  void _handleDragEnd() {
    final targetIndex = _dragRatio.round().clamp(0, AppTab.values.length - 1);
    setState(() {
      _isDragging = false;
      _dragRatio = targetIndex.toDouble();
    });
    HapticFeedback.lightImpact();
    widget.onTabPress(AppTab.values[targetIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _isDragging ? _dragRatio.round() : widget.activeTab.index;

    return Positioned(
      bottom: 28,
      left: 24,
      right: 24,
      child: Center(
        child: AnimatedScale(
          scale: _isDragging ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: _isDragging ? 0.15 : 0.08),
                  blurRadius: _isDragging ? 28 : 20,
                  offset: Offset(0, _isDragging ? 12 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(38),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: 1.5,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final tabWidth = totalWidth / AppTab.values.length;
                      final currentRatio = _isDragging ? _dragRatio : widget.activeTab.index.toDouble();
                      final pillLeft = currentRatio * tabWidth;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: _handleDragStart,
                        onHorizontalDragUpdate: (d) => _handleDragUpdate(d, totalWidth),
                        onHorizontalDragEnd: (d) => _handleDragEnd(),
                        onHorizontalDragCancel: () => setState(() {
                          _isDragging = false;
                          _dragRatio = widget.activeTab.index.toDouble();
                        }),
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: _isDragging
                                  ? const Duration(milliseconds: 20)
                                  : const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              left: pillLeft,
                              top: 0,
                              bottom: 0,
                              width: tabWidth,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                margin: EdgeInsets.symmetric(
                                  horizontal: _isDragging ? 1 : 2,
                                  vertical: _isDragging ? 0 : 1,
                                ),
                                decoration: BoxDecoration(
                                  color: _isDragging
                                      ? AppTheme.headerTeal.withValues(alpha: 0.55)
                                      : AppTheme.headerTeal.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: _isDragging
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.interactiveTeal.withValues(alpha: 0.20),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                _buildTabItem(
                                  label: 'Schedule',
                                  icon: CupertinoIcons.calendar_today,
                                  activeIcon: CupertinoIcons.calendar,
                                  isActive: activeIndex == 0,
                                  onTap: () => widget.onTabPress(AppTab.schedule),
                                ),
                                _buildTabItem(
                                  label: 'Meds',
                                  icon: CupertinoIcons.capsule,
                                  activeIcon: CupertinoIcons.capsule_fill,
                                  isActive: activeIndex == 1,
                                  onTap: () => widget.onTabPress(AppTab.meds),
                                ),
                                _buildTabItem(
                                  label: 'Profile',
                                  icon: CupertinoIcons.person_crop_circle,
                                  activeIcon: CupertinoIcons.person_crop_circle_fill,
                                  isActive: activeIndex == 2,
                                  onTap: () => widget.onTabPress(AppTab.profile),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 19,
                color: isActive ? AppTheme.interactiveTeal : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? AppTheme.interactiveTeal : AppTheme.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}