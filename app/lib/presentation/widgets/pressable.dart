import 'dart:async' show Timer;

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
///
/// Optionally supports immediate press-and-hold via [onHold] (firing after
/// [holdDuration] while the finger is still down, with `mediumImpact` haptic,
/// slop cancellation on drag/scroll, and suppression of the trailing tap).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onHold,
    this.holdDuration = const Duration(milliseconds: 375),
    this.canTriggerHold,
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
  final VoidCallback? onHold;
  final Duration holdDuration;
  final bool Function()? canTriggerHold;

  /// 0.98 for cards, 0.94 for small buttons and chips.
  final double scale;
  final PressHaptic haptic;
  final BorderRadius? borderRadius;
  final Color? rippleColor;
  final Decoration? decoration;
  final EdgeInsetsGeometry? padding;
  final Widget? foreground;

  @override
  State<Pressable> createState() => PressableState();
}

class PressableState extends State<Pressable> {
  static const double _kHoldMoveSlop = 10.0;

  bool _down = false;
  Timer? _holdTimer;
  int? _activePointer;
  Offset? _downPosition;
  bool _holdFired = false;

  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  /// Externally cancels any in-flight press-and-hold timer (e.g. when a parent
  /// `Slidable` begins sliding horizontally).
  void cancelPendingHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _activePointer = null;
    _downPosition = null;
    _set(false);
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

  void _handlePointerDown(PointerDownEvent event) {
    _holdFired = false;
    _holdTimer?.cancel();
    _holdTimer = null;
    if (widget.onHold == null) return;
    if (widget.canTriggerHold != null && !widget.canTriggerHold!()) return;

    _activePointer = event.pointer;
    _downPosition = event.position;
    _holdTimer = Timer(widget.holdDuration, _fireHold);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_holdTimer == null || event.pointer != _activePointer) return;
    final start = _downPosition;
    if (start != null && (event.position - start).distance > _kHoldMoveSlop) {
      cancelPendingHold();
    }
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _activePointer = null;
    _downPosition = null;
    _set(false);
  }

  void _fireHold() {
    _holdTimer = null;
    if (!mounted || widget.onHold == null) return;
    if (widget.canTriggerHold != null && !widget.canTriggerHold!()) return;

    _holdFired = true;
    _set(false);
    HapticFeedback.mediumImpact();
    widget.onHold!.call();
  }

  void _handleTap() {
    if (_holdFired) {
      _holdFired = false;
      return;
    }
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onHold != null;
    final instant = MediaQuery.of(context).disableAnimations;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final ripple = !isIOS && widget.borderRadius != null;

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
          onTap: enabled ? _handleTap : null,
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
        onTap: enabled ? _handleTap : null,
        child: surface,
      );
    }

    if (widget.onHold != null) {
      surface = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUpOrCancel,
        onPointerCancel: _handlePointerUpOrCancel,
        child: surface,
      );
    }

    // The foreground sits above the tap & hold listeners in the Stack, so a
    // touch on it (e.g. the dose checkmark) never triggers this surface's
    // tap or press-and-hold.
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
