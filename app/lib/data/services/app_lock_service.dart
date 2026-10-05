import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// App lock via the device's own unlock (PIN, pattern, password, fingerprint,
/// face). The OS runs the whole check and only reports pass/fail: PillPal
/// never sees or stores a credential. The two values kept here (on/off and
/// when the app was last backgrounded) are bookkeeping, not secrets.
class AppLockService extends ChangeNotifier {
  AppLockService({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const _enabledKey = 'app_lock_enabled';
  static const _channel = MethodChannel('pillpal/app_lock');

  /// How long the app can sit in the background before it locks again.
  static const gracePeriod = Duration(minutes: 1);

  bool _enabled = false;
  bool get isEnabled => _enabled;

  /// In memory only. A cold start is locked by the gate directly; this only
  /// decides whether a *resume* should lock again.
  DateTime? _backgroundedAt;

  Future<void> load() async {
    _enabled = await _storage.read(key: _enabledKey) == 'true';
    await _syncRecentsPreview();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _storage.write(key: _enabledKey, value: '$value');
    await _syncRecentsPreview();
    notifyListeners();
  }

  /// Blank recent-apps card while the lock is on (Android 13+; see
  /// MainActivity). Missing channel (tests, other platforms) is ignored.
  Future<void> _syncRecentsPreview() async {
    try {
      await _channel.invokeMethod<bool>('setHideInRecents', _enabled);
    } on MissingPluginException {
      // no native side here
    } on PlatformException {
      // best effort: never block the lock itself on this
    }
  }

  void recordBackgrounded([DateTime? now]) {
    _backgroundedAt = now ?? DateTime.now();
  }

  /// On resume: true if the app was away longer than [gracePeriod]. Consumes
  /// the recorded time, so one backgrounding is only judged once.
  bool shouldRelockOnResume([DateTime? now]) {
    final at = _backgroundedAt;
    _backgroundedAt = null;
    if (at == null) return false;
    return (now ?? DateTime.now()).difference(at) > gracePeriod;
  }

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Shows the system unlock prompt. Cancelling, timing out, or any other
  /// failure all come back as false (local_auth throws for these).
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock PillPal to see your medications',
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
