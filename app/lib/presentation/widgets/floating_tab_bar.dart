import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/liquid_glass_controller.dart';
import '../../core/theme/liquid_glass_mode.dart';
import '../../core/theme/liquid_glass_style.dart';

enum AppTab { schedule, meds, profile }

class FloatingTabBar extends StatefulWidget {
  final AppTab activeTab;
  final ValueChanged<AppTab> onTabPress;
  final LiquidGlassController? controller;
  final LiquidGlassMode? debugModeOverride;

  const FloatingTabBar({
    super.key,
    required this.activeTab,
    required this.onTabPress,
    this.controller,
    this.debugModeOverride,
  });

  @override
  State<FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends State<FloatingTabBar> {
  bool _isLifted = false;
  double _dragRatio = 0.0;
  double _downDx = 0.0;
  bool _hasDragged = false;
  Timer? _holdTimer;

  @override
  void didUpdateWidget(FloatingTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isLifted) {
      _dragRatio = widget.activeTab.index.toDouble();
    }
  }

  @override
  void initState() {
    super.initState();
    _dragRatio = widget.activeTab.index.toDouble();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _handlePanDown(DragDownDetails details, double totalWidth) {
    _downDx = details.localPosition.dx;
    _hasDragged = false;
    _holdTimer?.cancel();
    // Only lift if held down for a true press-and-hold (> 160ms), preventing
    // quick taps/clicks from causing an accidental scale pop.
    _holdTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isLifted = true;
        });
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, double totalWidth) {
    final tabWidth = totalWidth / AppTab.values.length;
    final delta = (details.localPosition.dx - _downDx).abs();
    if (delta > 4.0) {
      _hasDragged = true;
      _holdTimer?.cancel();
      if (!_isLifted) {
        HapticFeedback.mediumImpact();
        _isLifted = true;
      }
    }

    final newRatio =
        (details.localPosition.dx / tabWidth - 0.5).clamp(0.0, (AppTab.values.length - 1).toDouble());

    final previousTarget = _dragRatio.round();
    final newTarget = newRatio.round();
    if (previousTarget != newTarget) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _dragRatio = newRatio;
    });
  }

  void _handlePanEnd(DragEndDetails details, double totalWidth) {
    _holdTimer?.cancel();
    final tabWidth = totalWidth / AppTab.values.length;
    final int targetIndex;
    if (_hasDragged) {
      targetIndex = _dragRatio.round().clamp(0, AppTab.values.length - 1);
    } else {
      // Tap in place without drag
      targetIndex = (_downDx / tabWidth).floor().clamp(0, AppTab.values.length - 1);
    }

    final wasLifted = _isLifted;
    setState(() {
      _isLifted = false;
      _hasDragged = false;
      _dragRatio = targetIndex.toDouble();
    });

    if (wasLifted) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    widget.onTabPress(AppTab.values[targetIndex]);
  }

  void _handlePanCancel() {
    _holdTimer?.cancel();
    setState(() {
      _isLifted = false;
      _hasDragged = false;
      _dragRatio = widget.activeTab.index.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller != null) {
      return ValueListenableBuilder<LiquidGlassMode>(
        valueListenable: widget.controller!,
        builder: (context, _, __) => _buildBar(context),
      );
    }
    return _buildBar(context);
  }

  Widget _buildBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeIndex = _isLifted
        ? _dragRatio.round().clamp(0, AppTab.values.length - 1)
        : widget.activeTab.index;

    final selectedMode = widget.debugModeOverride ??
        widget.controller?.value ??
        LiquidGlassMode.auto;

    final style = LiquidGlassStyle.resolve(
      context,
      isDark: isDark,
      isLifted: _isLifted,
      mode: selectedMode,
    );

    Widget barContent = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        gradient: style.backgroundGradient,
        color: style.solidBackgroundColor,
        border: style.border,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final tabWidth = totalWidth / AppTab.values.length;
          final currentRatio =
              _isLifted ? _dragRatio : widget.activeTab.index.toDouble();
          final pillLeft = currentRatio * tabWidth;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _handlePanDown(d, totalWidth),
            onPanUpdate: (d) => _handlePanUpdate(d, totalWidth),
            onPanEnd: (d) => _handlePanEnd(d, totalWidth),
            onPanCancel: _handlePanCancel,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: style.disableAnimations
                      ? Duration.zero
                      : (_isLifted
                          ? const Duration(milliseconds: 30)
                          : const Duration(milliseconds: 260)),
                  curve: Curves.easeOutCubic,
                  left: pillLeft,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: AnimatedContainer(
                    duration: style.disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.symmetric(
                      horizontal: _isLifted ? 2 : 3,
                      vertical: _isLifted ? 1 : 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: style.activePillGradient,
                      color: style.activePillColor,
                      border: style.activePillBorder,
                      boxShadow: style.activePillShadows,
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
                      isDark: isDark,
                      disableAnimations: style.disableAnimations,
                    ),
                    _buildTabItem(
                      label: 'Meds',
                      icon: CupertinoIcons.capsule,
                      activeIcon: CupertinoIcons.capsule_fill,
                      isActive: activeIndex == 1,
                      isDark: isDark,
                      disableAnimations: style.disableAnimations,
                    ),
                    _buildTabItem(
                      label: 'Profile',
                      icon: CupertinoIcons.person_crop_circle,
                      activeIcon: CupertinoIcons.person_crop_circle_fill,
                      isActive: activeIndex == 2,
                      isDark: isDark,
                      disableAnimations: style.disableAnimations,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // If blur is enabled, wrap with BackdropFilter.
    // If blur is false (opaque mode / high-contrast / reduce transparency),
    // skip BackdropFilter entirely to eliminate off-screen render pass.
    if (style.hasBlur) {
      barContent = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: style.blurSigma,
          sigmaY: style.blurSigma,
        ),
        child: barContent,
      );
    }

    return Positioned(
      bottom: 28.0,
      left: 24.0,
      right: 24.0,
      child: Center(
        child: AnimatedScale(
          scale: style.liftScale,
          duration: style.disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: style.disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              boxShadow: style.shadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              clipBehavior: Clip.antiAlias,
              child: barContent,
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
    required bool isDark,
    required bool disableAnimations,
  }) {
    return Expanded(
      child: Center(
        child: AnimatedScale(
          scale: isActive ? 1.04 : 1.0,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 19,
                color: isActive
                    ? AppTheme.interactiveTeal
                    : (isDark ? Colors.white60 : AppTheme.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive
                      ? AppTheme.interactiveTeal
                      : (isDark ? Colors.white70 : AppTheme.textSecondary),
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