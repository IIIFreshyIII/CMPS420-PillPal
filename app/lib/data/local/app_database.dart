import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color;

import '../models/dose_event.dart';
import '../models/profile.dart';
import '../models/prescription.dart';
import 'connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Profiles, Prescriptions, DoseEvents])
class AppDatabase extends _$AppDatabase {
  /// [executor] is injectable for tests (e.g. `NativeDatabase.memory()`) --
  /// production code always uses the default, which opens the real on-disk
  /// database via `openConnection()`.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 1;

  Stream<List<Profile>> watchProfiles() {
    return select(profiles).watch().map((rows) => rows.map(_toProfile).toList());
  }

  Stream<List<Prescription>> watchPrescriptions() {
    return select(prescriptions).watch().map((rows) => rows.map(_toPrescription).toList());
  }

  /// Reverse-chronological, as the Meds-tab history feed (Step 3) needs it.
  Stream<List<DoseEvent>> watchDoseEvents() {
    final query = select(doseEvents)..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return query.watch().map((rows) => rows.map(_toDoseEvent).toList());
  }

  Future<void> upsertProfile(Profile profile) {
    return into(profiles).insertOnConflictUpdate(ProfilesCompanion.insert(
      id: profile.id,
      name: profile.name,
      colorValue: profile.color.toARGB32(),
      isPrimary: Value(profile.isPrimary),
    ));
  }

  Future<void> upsertPrescription(Prescription prescription) {
    return into(prescriptions).insertOnConflictUpdate(PrescriptionsCompanion.insert(
      id: prescription.id,
      profileId: prescription.profileId,
      name: prescription.name,
      dosage: prescription.dosage,
      time: prescription.time,
      remaining: prescription.remaining,
      daysSupply: prescription.daysSupply,
      takenToday: Value(prescription.takenToday),
    ));
  }

  Future<void> deletePrescription(String id) {
    return (delete(prescriptions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> insertDoseEvent(DoseEvent event) {
    return into(doseEvents).insert(DoseEventsCompanion.insert(
      id: event.id,
      prescriptionId: event.prescriptionId,
      profileId: event.profileId,
      occurredAt: event.occurredAt,
      action: event.action.name,
    ));
  }

  /// Inserts the given profiles/prescriptions only if the tables are
  /// currently empty -- first-launch demo data, not a reset-on-every-run.
  Future<void> seedIfEmpty(List<Profile> seedProfiles, List<Prescription> seedPrescriptions) async {
    final hasProfiles = await select(profiles).get();
    if (hasProfiles.isNotEmpty) return;

    await batch((b) {
      b.insertAll(
        profiles,
        seedProfiles.map((p) => ProfilesCompanion.insert(
              id: p.id,
              name: p.name,
              colorValue: p.color.toARGB32(),
              isPrimary: Value(p.isPrimary),
            )),
      );
      b.insertAll(
        prescriptions,
        seedPrescriptions.map((m) => PrescriptionsCompanion.insert(
              id: m.id,
              profileId: m.profileId,
              name: m.name,
              dosage: m.dosage,
              time: m.time,
              remaining: m.remaining,
              daysSupply: m.daysSupply,
              takenToday: Value(m.takenToday),
            )),
      );
    });
  }

  Profile _toProfile(ProfileRow row) {
    return Profile(id: row.id, name: row.name, color: Color(row.colorValue), isPrimary: row.isPrimary);
  }

  Prescription _toPrescription(PrescriptionRow row) {
    return Prescription(
      id: row.id,
      profileId: row.profileId,
      name: row.name,
      dosage: row.dosage,
      time: row.time,
      remaining: row.remaining,
      daysSupply: row.daysSupply,
      takenToday: row.takenToday,
    );
  }

  DoseEvent _toDoseEvent(DoseEventRow row) {
    return DoseEvent(
      id: row.id,
      prescriptionId: row.prescriptionId,
      profileId: row.profileId,
      occurredAt: row.occurredAt,
      action: DoseAction.values.byName(row.action),
    );
  }
}
