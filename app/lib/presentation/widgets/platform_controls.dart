import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Platform-native toggle switch: [CupertinoSwitch] on iOS and Material
/// [Switch] on Android (and other non-iOS platforms).
///
/// Wraps Material [Switch] in a transparent [Material] so it renders safely
/// even inside widgets/tests that don't have a [Scaffold] ancestor.
class PlatformSwitch extends StatelessWidget {
  const PlatformSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.activeThumbColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeTrackColor;
  final Color? activeThumbColor;

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS) {
      return CupertinoSwitch(
        value: value,
        activeTrackColor: activeTrackColor,
        onChanged: onChanged,
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Switch(
        value: value,
        activeThumbColor: activeThumbColor,
        activeTrackColor: activeTrackColor,
        onChanged: onChanged,
      ),
    );
  }
}

/// Platform-native loading spinner: [CupertinoActivityIndicator] on iOS and
/// Material [CircularProgressIndicator] on Android.
class PlatformLoadingIndicator extends StatelessWidget {
  const PlatformLoadingIndicator({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.5,
    this.color,
  });

  /// Overall diameter of the indicator (Cupertino radius is `size / 2`).
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS) {
      return CupertinoActivityIndicator(
        radius: size / 2,
        color: color,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
      ),
    );
  }
}
