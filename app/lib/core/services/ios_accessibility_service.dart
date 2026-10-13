import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges native iOS accessibility preferences that Flutter does not expose
/// directly via [MediaQueryData], notably Apple's "Reduce Transparency"
/// setting (`UIAccessibility.isReduceTransparencyEnabled`).
class IOSAccessibilityService extends ChangeNotifier {
  IOSAccessibilityService._();

  static final IOSAccessibilityService instance = IOSAccessibilityService._();

  static const MethodChannel _channel =
      MethodChannel('com.pillpal.app/accessibility');

  bool _isReduceTransparency = false;

  /// Whether the user has enabled "Reduce Transparency" in iOS Settings.
  bool get isReduceTransparency =>
      _debugReduceTransparencyOverride ?? _isReduceTransparency;

  static bool? _debugReduceTransparencyOverride;

  @visibleForTesting
  static void setDebugReduceTransparencyOverride(bool? override) {

    _debugReduceTransparencyOverride = override;
    instance.notifyListeners();
  }

  /// Queries native iOS for the current Reduce Transparency setting.
  Future<bool> updateAccessibilitySettings() async {
    if (!kIsWeb && !Platform.isIOS) {
      _isReduceTransparency = false;
      return false;
    }

    try {
      final result =
          await _channel.invokeMethod<bool>('isReduceTransparencyEnabled');
      final newValue = result ?? false;
      if (_isReduceTransparency != newValue) {
        _isReduceTransparency = newValue;
        notifyListeners();
      }
      return newValue;
    } catch (_) {
      // Platform channel not available (e.g. during headless unit/widget tests)
      return _isReduceTransparency;
    }
  }
}
