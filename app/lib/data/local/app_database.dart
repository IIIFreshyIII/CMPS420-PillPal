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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Additive, safe.
            await m.addColumn(profiles, profiles.bedtime);
            // Prescriptions' time/takenToday columns became
            // reminderTimes/takenTimes (a schema-shape change, not just an
            // added column) -- this is active-dev test data, not real user
            // data, so a one-time reset of saved prescriptions is
            // acceptable. DoseEvents rows survive and just show "Deleted
            // medication" for any wiped prescription id.
            await m.deleteTable('prescriptions');
            await m.createTable(prescriptions);
          }
        },
      );

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
      bedtime: Value(profile.bedtime),
    ));
  }

  Future<void> upsertPrescription(Prescription prescription) {
    return into(prescriptions).insertOnConflictUpdate(PrescriptionsCompanion.insert(
      id: prescription.id,
      profileId: prescription.profileId,
      name: prescription.name,
      dosage: prescription.dosage,
      reminderTimes: prescription.reminderTimes,
      takenTimes: prescription.takenTimes.toList(),
      remaining: prescription.remaining,
      daysSupply: prescription.daysSupply,
      allowAfterBedtime: Value(prescription.allowAfterBedtime),
    ));
  }

  Future<void> deletePrescription(String id) {
    return (delete(prescriptions)..where((t) => t.id.equals(id))).go();
  }

  /// No cascade to that profile's prescriptions/dose history -- the caller
  /// (AccountScreen/EditProfileSheet) is expected to have already blocked
  /// this when the profile still has prescriptions assigned. Silently
  /// wiping someone's medication history as a side effect of removing their
  /// profile card is the wrong default for a health-tracking app.
  Future<void> deleteProfile(String id) {
    return (delete(profiles)..where((t) => t.id.equals(id))).go();
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
    // Checked independently (not "seed everything if profiles is empty"):
    // a schema migration that only reshapes Prescriptions (e.g. v1 -> v2's
    // time -> reminderTimes change) can leave Profiles populated but
    // Prescriptions empty, and that should still get demo data back rather
    // than leaving Schedule silently blank.
    final hasProfiles = await select(profiles).get();
    final hasPrescriptions = await select(prescriptions).get();

    await batch((b) {
      if (hasProfiles.isEmpty) {
        b.insertAll(
          profiles,
          seedProfiles.map((p) => ProfilesCompanion.insert(
                id: p.id,
                name: p.name,
                colorValue: p.color.toARGB32(),
                isPrimary: Value(p.isPrimary),
                bedtime: Value(p.bedtime),
              )),
        );
      }
      if (hasPrescriptions.isEmpty) {
        b.insertAll(
          prescriptions,
          seedPrescriptions.map((m) => PrescriptionsCompanion.insert(
                id: m.id,
                profileId: m.profileId,
                name: m.name,
                dosage: m.dosage,
                reminderTimes: m.reminderTimes,
                takenTimes: m.takenTimes.toList(),
                remaining: m.remaining,
                daysSupply: m.daysSupply,
                allowAfterBedtime: Value(m.allowAfterBedtime),
              )),
        );
      }
    });
  }

  Profile _toProfile(ProfileRow row) {
    return Profile(
      id: row.id,
      name: row.name,
      color: Color(row.colorValue),
      isPrimary: row.isPrimary,
      bedtime: row.bedtime,
    );
  }

  Prescription _toPrescription(PrescriptionRow row) {
    return Prescription(
      id: row.id,
      profileId: row.profileId,
      name: row.name,
      dosage: row.dosage,
      reminderTimes: row.reminderTimes,
      takenTimes: row.takenTimes.toSet(),
      remaining: row.remaining,
      daysSupply: row.daysSupply,
      allowAfterBedtime: row.allowAfterBedtime,
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
