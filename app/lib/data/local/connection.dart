import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'encryption_key.dart';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pillpal.sqlite'));
    final key = await EncryptionKeyStore().getOrCreateKey();

    if (file.existsSync() && _isPlaintext(file)) {
      _migrateToEncrypted(file, key);
    }

    return NativeDatabase(
      file,
      setup: (db) {
        db.execute("PRAGMA key = '${_escapeSqlString(key)}';");
        // SQLite3MultipleCiphers-specific pragma -- fails loudly here if the
        // pubspec `hooks` build swap didn't actually take (e.g. a stale
        // cached build), rather than silently running on plain, unencrypted
        // SQLite while believing it's protected.
        assert(db.select('PRAGMA cipher;').isNotEmpty);

        // Android has no writable system temp directory sqlite3 can use by
        // default, which breaks any query needing a temp b-tree (e.g. a
        // sizeable ORDER BY/GROUP BY) -- a real, documented drift/sqlite3
        // gotcha, not a hypothetical. Keeping sqlite's temp store in memory
        // sidesteps it entirely.
        db.execute('PRAGMA temp_store = MEMORY;');
      },
    );
  });
}

String _escapeSqlString(String source) => source.replaceAll("'", "''");

/// Whether [file] is a pre-encryption, plain-SQLite database: openable and
/// readable without a key. An already-encrypted file throws on the trial
/// read instead (its pages are unparseable without the right key).
bool _isPlaintext(File file) {
  try {
    final db = sqlite3.sqlite3.open(file.path, mode: sqlite3.OpenMode.readOnly);
    try {
      db.select('SELECT count(*) FROM sqlite_master;');
      return true;
    } finally {
      db.close();
    }
  } catch (_) {
    return false;
  }
}

/// One-time upgrade path for a database created before encryption existed.
/// `PRAGMA key` only applies to a database that's already encrypted (or
/// brand new) -- it can't encrypt an existing plaintext file in place. The
/// documented workaround (https://drift.simonbinder.eu/platforms/encryption/)
/// is `VACUUM INTO` a fresh copy, `PRAGMA rekey` that copy to actually
/// encrypt it, then swap it in -- preserving whatever data was already on
/// disk instead of silently dropping it.
void _migrateToEncrypted(File file, String key) {
  final tempFile = File('${file.path}.encrypting');
  if (tempFile.existsSync()) tempFile.deleteSync();

  final plain = sqlite3.sqlite3.open(file.path);
  try {
    plain.execute("VACUUM INTO '${_escapeSqlString(tempFile.path)}';");
  } finally {
    plain.close();
  }

  final copy = sqlite3.sqlite3.open(tempFile.path);
  try {
    copy.execute("PRAGMA rekey = '${_escapeSqlString(key)}';");
  } finally {
    copy.close();
  }

  file.deleteSync();
  tempFile.renameSync(file.path);
}
