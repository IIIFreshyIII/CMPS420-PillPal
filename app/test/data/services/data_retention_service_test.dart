import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/data/models/dose_event.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/data/services/data_retention_service.dart';

void main() {
  final refDate = DateTime(2026, 10, 10, 12, 0);

  test('retentionLabel formats labels properly', () {
    expect(DataRetentionService.retentionLabel(30), '30 Days (1 Month)');
    expect(DataRetentionService.retentionLabel(90), '90 Days (3 Months)');
    expect(DataRetentionService.retentionLabel(180), '180 Days (6 Months)');
    expect(DataRetentionService.retentionLabel(365), '1 Year (Default)');
    expect(DataRetentionService.retentionLabel(0), 'Keep All (Never Purge)');
  });

  test('getCutoffDate computes cutoff correctly', () {
    final service = DataRetentionService();
    final cutoff1Y = service.getCutoffDate(customDays: 365, now: refDate);
    expect(cutoff1Y, refDate.subtract(const Duration(days: 365)));

    final cutoffForever = service.getCutoffDate(customDays: 0, now: refDate);
    expect(cutoffForever, isNull);
  });

  test('getExpiredEvents correctly identifies events older than cutoff', () {
    final service = DataRetentionService();
    final events = [
      // 10 days old
      DoseEvent(
        id: '1',
        prescriptionId: 'rx1',
        profileId: 'p1',
        occurredAt: refDate.subtract(const Duration(days: 10)),
        action: DoseAction.taken,
      ),
      // 400 days old (expired under 365 days)
      DoseEvent(
        id: '2',
        prescriptionId: 'rx1',
        profileId: 'p1',
        occurredAt: refDate.subtract(const Duration(days: 400)),
        action: DoseAction.taken,
      ),
    ];

    final expired = service.getExpiredEvents(events, customDays: 365, now: refDate);
    expect(expired.length, 1);
    expect(expired.first.id, '2');

    final expiredKeepAll =
        service.getExpiredEvents(events, customDays: 0, now: refDate);
    expect(expiredKeepAll.isEmpty, isTrue);
  });

  test('buildCsv formats logs into CSV structure', () {
    const profile = Profile(id: 'p1', name: 'Me', color: Color(0xFF3B82F6));
    const prescription = Prescription(
      id: 'rx1',
      profileId: 'p1',
      name: 'Allegra',
      dosage: '10mg',
      reminderTimes: ['8:00 AM'],
      remaining: 14,
      daysSupply: 14,
    );
    final event = DoseEvent(
      id: '1',
      prescriptionId: 'rx1',
      profileId: 'p1',
      occurredAt: DateTime(2026, 10, 10, 8, 0),
      action: DoseAction.taken,
    );

    final csv = DataRetentionService.buildCsv(
      events: [event],
      prescriptions: const [prescription],
      profiles: const [profile],
    );

    expect(csv.contains('Date,Time,Status,Medication,Dosage,Profile'), isTrue);
    expect(csv.contains('2026-10-10'), isTrue);
    expect(csv.contains('On Time'), isTrue);
    expect(csv.contains('Allegra'), isTrue);
    expect(csv.contains('10mg'), isTrue);
    expect(csv.contains('Me'), isTrue);
  });
}
