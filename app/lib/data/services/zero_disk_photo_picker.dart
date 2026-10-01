import 'package:flutter/services.dart';

/// Dart side of the native `MainActivity.kt` platform channel that reads a
/// picked photo's bytes straight into memory, bypassing `image_picker`'s
/// cache-file behavior entirely -- see the Kotlin side for why this exists
/// instead of just using `image_picker` directly.
class ZeroDiskPhotoPicker {
  static const _channel = MethodChannel('pillpal/zero_disk_photo_picker');

  /// Launches the system photo picker and returns the picked image's raw
  /// bytes, or `null` if the user cancelled. Nothing is written to disk at
  /// any point on the Android side.
  static Future<Uint8List?> pickImage() async {
    final result = await _channel.invokeMethod<Uint8List>('pickImage');
    return result;
  }
}
