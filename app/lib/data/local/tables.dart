import 'dart:convert';

import 'package:drift/drift.dart';

/// Drift has no native list column type -- stores a `List<String>` as a
/// JSON-encoded text column. Used for both `reminderTimes` (ordered) and
/// `takenTimes` (a set at the Dart model layer, converted to/from a list at
/// the `AppDatabase` mapping boundary so this one converter covers both).
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) => (jsonDecode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Mirrors `Profile` (data/models/profile.dart) field-for-field, including
/// the string id, so the app layer can keep using plain model classes
/// unchanged -- this table is purely storage.
///
/// `@DataClassName('ProfileRow')`: drift's default generated row-class name
/// would be `Profile`, colliding with the plain model class of the same
/// name that `app_database.dart` maps rows into.
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()(); // Color.toARGB32()
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get bedtime => text().nullable()(); // formatted like "10:00 PM"

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors `Prescription` (data/models/prescription.dart) field-for-field.
@DataClassName('PrescriptionRow')
class Prescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text()();
  TextColumn get dosage => text()();
  TextColumn get reminderTimes => text().map(const StringListConverter())();
  TextColumn get takenTimes => text().map(const StringListConverter())();
  IntColumn get remaining => integer()();
  IntColumn get daysSupply => integer()();
  BoolColumn get allowAfterBedtime => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only dose history log -- see `data/models/dose_event.dart`.
@DataClassName('DoseEventRow')
class DoseEvents extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId => text().references(Prescriptions, #id)();
  TextColumn get profileId => text().references(Profiles, #id)();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get action => text()(); // 'taken' | 'skipped' -- see DoseAction

  @override
  Set<Column> get primaryKey => {id};
}
