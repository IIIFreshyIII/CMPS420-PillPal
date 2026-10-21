import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/permissions/camera_permission.dart';
import 'package:pillpal/core/state/app_state_manager.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/data/local/app_database.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/data/services/extractor.dart';
import 'package:pillpal/data/services/notification_service.dart';
import 'package:pillpal/screens/onboarding/onboarding_flow.dart';
import 'package:pillpal/screens/onboarding/steps/step6_scan.dart';
import 'package:pillpal/screens/onboarding/steps/step7_verification.dart';
import 'package:pillpal/screens/onboarding/widgets/onboarding_progress_bar.dart';
import 'package:pillpal/screens/onboarding/widgets/prescription_scan_guide_animation.dart';

class MockStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

class FakeNotificationService extends NotificationService {
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> areNotificationsEnabled() async => true;
}

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    );
  }

  group('PrescriptionScanGuideAnimation Widget Tests', () {
    testWidgets('Renders and loops bottle and box vector phases without error',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Center(
          child: PrescriptionScanGuideAnimation(
            width: 200,
            height: 100,
            duration: Duration(milliseconds: 1000),
          ),
        ),
      ));

      expect(find.byType(PrescriptionScanGuideAnimation), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Phase 1: Bottle (0% to 50% of timeline)
      await tester.pump(const Duration(milliseconds: 250));
      // Phase 2: Box (50% to 100% of timeline)
      await tester.pump(const Duration(milliseconds: 500));
      // Loop back to Phase 1
      await tester.pump(const Duration(milliseconds: 350));
    });
  });

  group('Step 6 Full-Screen Scanner Tests', () {
    testWidgets(
        'Step 6 renders cutout scrim, guide animation, instructional text, and handles fallback',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Extraction? extracted;
      var backTapped = false;

      await tester.pumpWidget(wrap(
        Step6Scan(
          autoStartCamera: false,
          onScanExtracted: (ext) => extracted = ext,
          onBack: () => backTapped = true,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Title & Instructional Text
      expect(find.text('Scan Prescription'), findsOneWidget);
      expect(
        find.textContaining('Align the far-left edge of your label inside'),
        findsOneWidget,
      );

      // Verify Looping Guide Animation
      expect(find.byType(PrescriptionScanGuideAnimation), findsOneWidget);

      // Verify Back button
      final backBtn = find.byKey(const Key('scan_back_button'));
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      expect(backTapped, isTrue);

      // Verify Simulate Scan button is visible in simulator/test mode
      final simBtn = find.byKey(const Key('simulate_scan_button'));
      expect(simBtn, findsOneWidget);

      // Tap Simulate Scan to verify OCR/NER handoff
      await tester.tap(simBtn);
      await tester.pump();

      expect(extracted, isNotNull);
      expect(extracted!.drug, 'Metformin HCl');
      expect(extracted!.strength, '500 mg');
      expect(extracted!.frequency, 'twice daily');
    });
  });

  group('Step 7 Verification & Confirmation Tests', () {
    testWidgets(
        'Step 7 pre-populates extracted fields, allows editing, and confirms celebratory state',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final extraction = Extraction(
        rawText: 'METFORMIN HCL 500 MG TABLET\nTAKE WITH MEALS TWICE DAILY',
      )
        ..drug = 'Metformin HCl'
        ..strength = '500 mg'
        ..dose = '1 tablet'
        ..form = 'tablet'
        ..frequency = 'twice daily'
        ..daysSupply = 30;

      Prescription? savedPrescription;
      Profile? savedProfile;

      await tester.pumpWidget(wrap(
        Step7Verification(
          extraction: extraction,
          primaryUserName: 'Cade',
          onBack: () {},
          onConfirmAndSave: (rx, prof) async {
            savedPrescription = rx;
            savedProfile = prof;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Verify pre-populated fields and progress bar
      expect(find.byType(OnboardingProgressBar), findsOneWidget);
      expect(find.text('Verify Details'), findsOneWidget);
      expect(find.text('Metformin HCl'), findsOneWidget);
      expect(find.text('500 mg'), findsWidgets);
      expect(find.text('With food'), findsOneWidget);
      expect(find.text('Once daily'), findsOneWidget);
      expect(find.text('Twice daily'), findsWidgets);
      expect(find.text('3x daily'), findsOneWidget);
      expect(find.text('4x daily'), findsOneWidget);
      expect(find.text('As needed'), findsNothing);
      expect(find.text('8:00 AM'), findsOneWidget);
      expect(find.text('8:00 PM'), findsOneWidget);
      expect(find.text('Me (Cade)'), findsOneWidget);

      // Test "Someone Else" Caretaker flow
      await tester.tap(find.byKey(const Key('assignee_someone_else')));
      await tester.pumpAndSettle();

      // Recipient name field appears
      expect(find.byKey(const Key('recipient_name_field')), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('recipient_name_field')), 'Mom');
      await tester.pumpAndSettle();

      // Tap bottom confirm button
      final confirmBtn = find.byKey(const Key('verify_bottom_confirm_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      // Confetti runs for 650ms
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Celebratory Confirmation State
      expect(find.text("You're All Set!"), findsOneWidget);
      expect(find.text('Awesome!'), findsOneWidget);
      expect(find.text('For Mom'), findsOneWidget);

      // Tap "Awesome!" to save and finish
      await tester.tap(find.byKey(const Key('verification_awesome_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(savedPrescription, isNotNull);
      expect(savedPrescription!.name, 'Metformin HCl');
      expect(savedProfile, isNotNull);
      expect(savedProfile!.name, 'Mom');
      expect(savedProfile!.isPrimary, isFalse);
    });

    testWidgets(
        'Step 7 primary user flow saves prescription with primary profile ID',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final extraction = Extraction(rawText: 'AMOXICILLIN 250 MG')
        ..drug = 'Amoxicillin'
        ..strength = '250 mg'
        ..frequency = 'once daily'
        ..daysSupply = 10;

      Prescription? savedPrescription;
      Profile? savedProfile;

      await tester.pumpWidget(wrap(
        Step7Verification(
          extraction: extraction,
          primaryUserName: 'Sarah',
          onBack: () {},
          onConfirmAndSave: (rx, prof) async {
            savedPrescription = rx;
            savedProfile = prof;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Amoxicillin'), findsOneWidget);
      expect(find.text('Me (Sarah)'), findsOneWidget);

      // Tap top checkmark button
      await tester.tap(find.byKey(const Key('verify_confirm_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text("You're All Set!"), findsOneWidget);
      expect(find.text('For Sarah'), findsOneWidget);

      await tester.tap(find.byKey(const Key('verification_awesome_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(savedPrescription, isNotNull);
      expect(savedPrescription!.name, 'Amoxicillin');
      expect(savedPrescription!.profileId, '1');
      expect(savedProfile, isNull);
    });
  });

  group('OnboardingFlow End-to-End Stage 2 Integration Tests', () {
    testWidgets(
        'OnboardingFlow advances through Step 5 to Step 6 scan and Step 7 verification, persisting to database',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final storage = MockStorage();
      final appStateManager = AppStateManager(storage: storage);
      await appStateManager.load();

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final notifs = FakeNotificationService();
      var onboardingCompleted = false;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: OnboardingFlow(
          appStateManager: appStateManager,
          database: db,
          notificationService: notifs,
          onComplete: () => onboardingCompleted = true,
          requestCamera: () async => CameraPermissionResult.granted,
          checkCamera: () async => CameraPermissionResult.denied,
        ),
      ));
      await tester.pump();

      // Step 1: Splash -> tap to advance
      await tester.tap(find.byKey(const Key('step1_splash_tap_area')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Step 2: Legal -> agree
      expect(find.textContaining('Important Information'), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('I Understand & Agree'), findsOneWidget);
      await tester.tap(find.text('I Understand & Agree'));
      await tester.pumpAndSettle();

      // Step 3: Name -> enter 'Alex' -> done -> 1600ms morph sequence -> Next
      await tester.enterText(find.byType(TextField), 'Alex');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Next'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 4: Permissions -> toggle required switches -> next
      expect(find.text('Permissions & Local Setup'), findsOneWidget);
      final switches = find.byType(CupertinoSwitch);
      expect(switches, findsWidgets);
      // Toggle Camera permission
      await tester.tap(switches.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Toggle Notification permission
      await tester.tap(switches.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final nextBtn = find.text('Next');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Step 5: First Reminder Prompt -> tap "Add New Prescription"
      expect(find.text("Thanks! Now, let's set up your first reminder!"),
          findsOneWidget);
      await tester.tap(find.text('Add New Prescription'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Step 6: Full-Screen Camera Scanner appears!
      expect(find.text('Scan Prescription'), findsOneWidget);
      expect(find.byKey(const Key('simulate_scan_button')), findsOneWidget);

      // Tap Simulate Scan to simulate bottle scan
      await tester.tap(find.byKey(const Key('simulate_scan_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Step 7: Verification screen appears!
      expect(find.text('Verify Details'), findsOneWidget);
      expect(find.text('Metformin HCl'), findsOneWidget);

      // Confirm details
      await tester.tap(find.byKey(const Key('verify_bottom_confirm_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Celebratory screen appears
      expect(find.text("You're All Set!"), findsOneWidget);

      // Tap "Awesome!"
      await tester.tap(find.byKey(const Key('verification_awesome_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify completion state
      expect(onboardingCompleted, isTrue);
      expect(appStateManager.hasCompletedOnboarding, isTrue);
      expect(appStateManager.isSeededTestingMode, isFalse);

      final rows = await db.select(db.prescriptions).get();
      expect(rows.length, 1);
      expect(rows.first.name, 'Metformin HCl');
      expect(rows.first.profileId, '1');

      // Unmount tree cleanly to stop all tickers and active controllers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });
}
