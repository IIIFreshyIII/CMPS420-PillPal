import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PressHaptic { light, selection, none }

/// Press feedback for any tappable card or button: shrinks slightly under the
/// finger, fires a haptic on touch-down, and springs back on release.
///
/// With a [borderRadius] it also draws an Android ripple in [rippleColor],
/// clipped to those corners. Give the fill as [decoration] (not on a widget
/// inside [child]), so the ripple paints over the fill instead of under it.
///
/// [foreground] is laid over the whole surface and scales with it, but
/// receives its own taps first: a control there (e.g. a dose check) never
/// also triggers this surface's press.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.98,
    this.haptic = PressHaptic.light,
    this.borderRadius,
    this.rippleColor,
    this.decoration,
    this.padding,
    this.foreground,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// 0.98 for cards, 0.94 for small buttons and chips.
  final double scale;
  final PressHaptic haptic;
  final BorderRadius? borderRadius;
  final Color? rippleColor;
  final Decoration? decoration;
  final EdgeInsetsGeometry? padding;
  final Widget? foreground;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  void _onDown() {
    switch (widget.haptic) {
      case PressHaptic.light:
        HapticFeedback.lightImpact();
      case PressHaptic.selection:
        HapticFeedback.selectionClick();
      case PressHaptic.none:
        break;
    }
    _set(true);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final instant = MediaQuery.of(context).disableAnimations;
    final ripple = widget.borderRadius != null;

    Widget surface = widget.padding != null
        ? Padding(padding: widget.padding!, child: widget.child)
        : widget.child;

    if (ripple) {
      surface = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: widget.borderRadius,
          splashColor: widget.rippleColor,
          highlightColor: widget.rippleColor,
          onTapDown: enabled ? (_) => _onDown() : null,
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: widget.onTap,
          child: surface,
        ),
      );
    }

    if (widget.decoration != null) {
      surface = AnimatedContainer(
        duration: instant ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: widget.decoration,
        child: surface,
      );
    }

    if (!ripple) {
      surface = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _onDown() : null,
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: surface,
      );
    }

    // The foreground sits above the tap handler in the Stack, so a touch on
    // it never reaches this surface's handler at all.
    if (widget.foreground != null) {
      surface = Stack(children: [
        surface,
        Positioned.fill(child: widget.foreground!),
      ]);
    }

    return AnimatedScale(
      scale: _down ? widget.scale : 1.0,
      duration: instant ? Duration.zero : const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: surface,
    );
  }
}
