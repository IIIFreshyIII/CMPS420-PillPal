import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The database's encryption key: generated once, then read back from
/// platform secure storage (Android Keystore-backed, iOS Keychain-backed) on
/// every later run. No user-facing passphrase -- the key is device-bound and
/// automatic, matching the app's "stored exclusively on this device" framing
/// rather than a password-vault feature. If secure storage is ever cleared
/// (e.g. app data wiped), the key is gone and so is the data -- by design,
/// not a bug to work around.
class EncryptionKeyStore {
  EncryptionKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;
  static const _storageKey = 'pillpal_db_key';

  Future<String> getOrCreateKey() async {
    try {
      final existing = await _storage.read(key: _storageKey);
      if (existing != null) return existing;

      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      final key = base64UrlEncode(bytes);
      await _storage.write(key: _storageKey, value: key);
      return key;
    } catch (_) {
      // In simulator environments or when iOS Keychain returns errSecMissingEntitlement (-34018),
      // fallback to reading/writing the key in the application's private documents directory.
      return _getOrCreateFallbackKey();
    }
  }

  Future<String> _getOrCreateFallbackKey() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '.pillpal_db_key.fallback'));
    if (file.existsSync()) {
      return file.readAsStringSync().trim();
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await file.writeAsString(key);
    return key;
  }
}
