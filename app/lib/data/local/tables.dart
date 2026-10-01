import 'package:drift/drift.dart';

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
  TextColumn get time => text()();
  IntColumn get remaining => integer()();
  IntColumn get daysSupply => integer()();
  BoolColumn get takenToday => boolean().withDefault(const Constant(false))();

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
