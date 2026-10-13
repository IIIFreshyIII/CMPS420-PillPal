import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/data/models/dose_event.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/data/services/data_retention_service.dart';
import 'package:pillpal/screens/account/dose_log_retention_sheet.dart';

void main() {
  const me = Profile(id: '1', name: 'Me', color: Colors.blue, isPrimary: true);
  const allegra = Prescription(
    id: 'rx1',
    profileId: '1',
    name: 'Allegra',
    dosage: '10mg',
    reminderTimes: ['8:00 AM'],
    remaining: 14,
    daysSupply: 14,
  );

  final events = [
    DoseEvent(
      id: 'd1',
      prescriptionId: 'rx1',
      profileId: '1',
      occurredAt: DateTime.now(),
      action: DoseAction.taken,
    ),
  ];

  testWidgets('renders DoseLogRetentionSheet with preset options and stats',
      (tester) async {
    final service = DataRetentionService();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: DoseLogRetentionSheet(
          retentionService: service,
          doseEvents: events,
          prescriptions: const [allegra],
          profiles: const [me],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Dose Log Retention'), findsOneWidget);
    expect(find.text('1 Year (Default)'), findsOneWidget);
    expect(find.text('30 Days (1 Month)'), findsOneWidget);
    expect(find.text('90 Days (3 Months)'), findsOneWidget);
    expect(find.text('180 Days (6 Months)'), findsOneWidget);
    expect(find.text('Keep All (Never Purge)'), findsOneWidget);
    expect(find.text('Total Logs'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Export (.csv)'), findsOneWidget);
  });
}
