import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The person's System / Light / Dark choice, saved on the device. Loaded
/// before `runApp` so a Dark user never sees a white flash on launch.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._(super.value);

  static const _key = 'appearance';
  static const _storage = FlutterSecureStorage();

  static Future<ThemeController> load() async {
    final saved = await _storage.read(key: _key);
    return ThemeController._(
      ThemeMode.values
          .firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system),
    );
  }

  Future<void> select(ThemeMode mode) async {
    if (mode == value) return;
    HapticFeedback.selectionClick();
    value = mode;
    await _storage.write(key: _key, value: mode.name);
  }
}
