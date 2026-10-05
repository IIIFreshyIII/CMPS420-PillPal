import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/data/services/notification_service.dart';
import 'package:pillpal/screens/account/account_screen.dart';

void main() {
  const me = Profile(id: '1', name: 'Me', color: Colors.blue, isPrimary: true);
  const mom = Profile(id: '2', name: 'Mom', color: Colors.purple);
  const momsRx = Prescription(
    id: 'rx1',
    profileId: '2',
    name: 'Metformin',
    dosage: '500mg',
    reminderTimes: ['12:00 PM'],
    remaining: 28,
    daysSupply: 28,
  );

  Widget buildApp({
    required List<Profile> profiles,
    required List<Prescription> prescriptions,
    required ValueChanged<Profile> onUpdateProfile,
    required ValueChanged<String> onDeleteProfile,
  }) {
    return MaterialApp(
      home: AccountScreen(
        profiles: profiles,
        prescriptions: prescriptions,
        onUpdateProfile: onUpdateProfile,
        onDeleteProfile: onDeleteProfile,
        notificationService: NotificationService(),
      ),
    );
  }

  testWidgets('Add Family Member creates a non-primary profile with the entered name', (tester) async {
    Profile? added;
    await tester.pumpWidget(buildApp(
      profiles: const [me],
      prescriptions: const [],
      onUpdateProfile: (p) => added = p,
      onDeleteProfile: (_) {},
    ));

    await tester.tap(find.text('Add Family Member'));
    await tester.pumpAndSettle();

    expect(find.text('Add'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field_new_profile_name')), 'Dad');
    await tester.pump();
    await tester.tap(find.byKey(const Key('add_profile_save_button')));
    await tester.pumpAndSettle();

    expect(added, isNotNull);
    expect(added!.name, 'Dad');
    expect(added!.isPrimary, isFalse);
  });

  testWidgets('Add is disabled until a name is entered', (tester) async {
    await tester.pumpWidget(buildApp(
      profiles: const [me],
      prescriptions: const [],
      onUpdateProfile: (_) {},
      onDeleteProfile: (_) {},
    ));

    await tester.tap(find.text('Add Family Member'));
    await tester.pumpAndSettle();

    final addButton = tester.widget<TextButton>(find.byKey(const Key('add_profile_save_button')));
    expect(addButton.onPressed, isNull);
  });

  testWidgets('a non-primary profile with no prescriptions can be deleted', (tester) async {
    String? deletedId;
    await tester.pumpWidget(buildApp(
      profiles: const [me, mom],
      prescriptions: const [],
      onUpdateProfile: (_) {},
      onDeleteProfile: (id) => deletedId = id,
    ));

    await tester.tap(find.text('Mom'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Profile'), findsOneWidget);
    await tester.tap(find.text('Delete Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Profile').last); // confirm in the action sheet
    await tester.pumpAndSettle();

    expect(deletedId, '2');
  });

  testWidgets('a profile with prescriptions shows a blocking message instead of delete', (tester) async {
    await tester.pumpWidget(buildApp(
      profiles: const [me, mom],
      prescriptions: const [momsRx],
      onUpdateProfile: (_) {},
      onDeleteProfile: (_) {},
    ));

    await tester.tap(find.text('Mom'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Profile'), findsNothing);
    expect(find.text('Reassign or delete their medications first to delete this profile.'), findsOneWidget);
  });

  testWidgets('the primary profile has no delete option at all', (tester) async {
    await tester.pumpWidget(buildApp(
      profiles: const [me, mom],
      prescriptions: const [],
      onUpdateProfile: (_) {},
      onDeleteProfile: (_) {},
    ));

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Profile'), findsNothing);
    expect(find.text('Reassign or delete their medications first to delete this profile.'), findsNothing);
  });
}
