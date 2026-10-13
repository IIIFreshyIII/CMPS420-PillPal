import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Which generation of Apple's design language PillPal should mirror on iOS.
///
/// * [liquidGlass] -- iOS 26+: floating, translucent "Liquid Glass" chrome
///   (`FloatingTabBar`). Exclusive to modern iPhones without a physical home button.
/// * [classic] -- iOS 25 and earlier (iOS 7 through iOS 18 era), OR any iPhone
///   with a physical home button (iPhone SE 2nd & 3rd gen, iPhone 8, etc.):
///   the docked, full-width tab bar every iPhone app had before Liquid Glass
///   (`ClassicIOSTabBar`).
enum IOSDesignEra { liquidGlass, classic }

/// First iOS release that shipped Liquid Glass.
const int kLiquidGlassMinIOSMajor = 26;

/// Dev/preview switch: `flutter run --dart-define=PILLPAL_FORCE_CLASSIC_TABBAR=true`
/// renders the classic (pre-iOS 26) chrome on any iOS device/simulator.
const bool _kForceClassic =
    bool.fromEnvironment('PILLPAL_FORCE_CLASSIC_TABBAR');

/// Test hook: overrides the detected iOS major version.
@visibleForTesting
int? debugIOSMajorVersionOverride;

/// Test hook: overrides whether the device is treated as having a home button.
@visibleForTesting
bool? debugIsHomeButtonOverride;

/// Known Apple machine model identifiers for iPhones with physical home buttons.
const _kHomeButtonModelIdentifiers = {
  // iPhone SE (1st, 2nd, 3rd gen)
  'iPhone8,4',
  'iPhone12,8',
  'iPhone14,6',
  // iPhone 8, 8 Plus
  'iPhone10,1',
  'iPhone10,4',
  'iPhone10,2',
  'iPhone10,5',
  // iPhone 7, 7 Plus
  'iPhone9,1',
  'iPhone9,3',
  'iPhone9,2',
  'iPhone9,4',
  // iPhone 6s, 6s Plus, 6, 6 Plus
  'iPhone8,1',
  'iPhone8,2',
  'iPhone7,2',
  'iPhone7,1',
};

/// Parses the iOS major version out of `Platform.operatingSystemVersion`.
///
/// On iOS, Dart returns `NSProcessInfo.operatingSystemVersionString`, e.g.
/// `"Version 18.6 (Build 22G86)"`. Returns null if nothing parseable is found.
@visibleForTesting
int? parseIOSMajorVersion(String versionString) {
  final match = RegExp(r'(\d+)(?:\.\d+)*').firstMatch(versionString);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// The running iOS major version, or null when not on iOS / unparseable.
int? iosMajorVersion() {
  if (debugIOSMajorVersionOverride != null) return debugIOSMajorVersionOverride;
  if (kIsWeb || !Platform.isIOS) return null;
  return parseIOSMajorVersion(Platform.operatingSystemVersion);
}

/// Checks whether the screen metrics correspond to a home-button iPhone.
///
/// Home-button iPhones (iPhone 6/7/8/SE series) have a 16:9 display with no
/// bottom home-indicator safe area inset (`bottom == 0`).
/// Non-home-button iPhones (iPhone X through iPhone 17 and newer) feature Face ID /
/// gesture navigation and have a bottom safe area inset (34pt portrait / 21pt landscape)
/// for the home indicator bar.
bool isHomeButtonDeviceMetrics({
  required double bottomInset,
  required Size size,
}) {
  // If there is a bottom home-indicator inset (> 0), it is a gesture-bar device.
  if (bottomInset > 0) return false;
  if (size.width <= 0 || size.height <= 0) return false;

  final longSide = math.max(size.width, size.height);
  final shortSide = math.min(size.width, size.height);

  // Home-button iPhones have a max logical length of 736pt (iPhone 8 Plus),
  // max logical width of 414pt, and 0 bottom home indicator inset.
  // Modern gesture-navigation iPhones have a length >= 812pt and bottom inset >= 21pt.
  return bottomInset == 0 && longSide <= 750.0 && shortSide <= 430.0;
}

/// Whether the current device is an iPhone with a physical home button.
bool isHomeButtonIPhone([BuildContext? context]) {
  if (debugIsHomeButtonOverride != null) {
    return debugIsHomeButtonOverride!;
  }
  if (kIsWeb) return false;

  // Simulator environment variables check (instant & precise on macOS simulators)
  if (!kIsWeb && Platform.isIOS) {
    final simModel = Platform.environment['SIMULATOR_MODEL_IDENTIFIER'];
    if (simModel != null && _kHomeButtonModelIdentifiers.contains(simModel)) {
      return true;
    }
    final simDeviceName = Platform.environment['SIMULATOR_DEVICE_NAME'];
    if (simDeviceName != null) {
      final lower = simDeviceName.toLowerCase();
      if (lower.contains('se') ||
          lower.contains('iphone 8') ||
          lower.contains('iphone 7') ||
          lower.contains('iphone 6')) {
        return true;
      }
    }
  }

  // MediaQuery metrics check
  if (context != null) {
    final media = MediaQuery.maybeOf(context);
    if (media != null) {
      return isHomeButtonDeviceMetrics(
        bottomInset: media.viewPadding.bottom,
        size: media.size,
      );
    }
  }

  // PlatformDispatcher view metrics check
  try {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) {
      final view = views.first;
      final dpr = view.devicePixelRatio > 0 ? view.devicePixelRatio : 1.0;
      return isHomeButtonDeviceMetrics(
        bottomInset: view.viewPadding.bottom / dpr,
        size: view.physicalSize / dpr,
      );
    }
  } catch (_) {}

  return false;
}

/// The design era to mirror on iOS. Defaults to [IOSDesignEra.liquidGlass]
/// for non-home-button iPhones on iOS 26+, or when the version can't be
/// determined on modern non-home-button hardware.
///
/// Returns [IOSDesignEra.classic] if:
/// - Explicitly forced via `--dart-define=PILLPAL_FORCE_CLASSIC_TABBAR=true`
/// - The device has a physical home button (iPhone SE 2/3, iPhone 8, etc.)
/// - The iOS version is prior to iOS 26 (iOS 15 through iOS 18)
IOSDesignEra currentIOSDesignEra([BuildContext? context]) {
  if (_kForceClassic) return IOSDesignEra.classic;
  if (isHomeButtonIPhone(context)) return IOSDesignEra.classic;
  final major = iosMajorVersion();
  if (major == null) return IOSDesignEra.liquidGlass;
  return major >= kLiquidGlassMinIOSMajor
      ? IOSDesignEra.liquidGlass
      : IOSDesignEra.classic;
}
