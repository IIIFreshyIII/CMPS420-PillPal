import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'liquid_glass_mode.dart';

/// Manages the user's Liquid Glass preference (Auto / Liquid / Frosted / Opaque),
/// persisting it on device with [FlutterSecureStorage].
class LiquidGlassController extends ValueNotifier<LiquidGlassMode> {
  LiquidGlassController([super.value = LiquidGlassMode.auto]);

  static const _key = 'liquid_glass_mode';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Loads the persisted glass mode, defaulting to [LiquidGlassMode.auto].
  static Future<LiquidGlassController> load() async {
    try {
      final saved = await _storage.read(key: _key);
      final mode = LiquidGlassMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => LiquidGlassMode.auto,
      );
      return LiquidGlassController(mode);
    } catch (_) {
      return LiquidGlassController(LiquidGlassMode.auto);
    }
  }

  /// Sets and persists a new glass mode preference with selection haptic feedback.
  Future<void> select(LiquidGlassMode mode) async {
    if (mode == value) return;
    HapticFeedback.selectionClick();
    value = mode;
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {
      // Ignore storage write issues during tests/sandboxing
    }
  }
}
