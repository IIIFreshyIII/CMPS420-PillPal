import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pillpal.sqlite'));
    return NativeDatabase(
      file,
      setup: (db) {
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
