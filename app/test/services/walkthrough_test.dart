import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/state/app_state_manager.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/core/theme/theme_controller.dart';
import 'package:pillpal/data/local/app_database.dart';
import 'package:pillpal/data/models/prescription.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/data/services/notification_service.dart';
import 'package:pillpal/screens/account/account_screen.dart';
import 'package:pillpal/screens/home/home_scaffold.dart';
import 'package:pillpal/screens/profiles/profiles_screen.dart';
import 'package:pillpal/services/walkthrough_service.dart';
import 'package:pillpal/ui/widgets/walkthrough_overlay.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

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
      _store[key];

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
      _store.remove(key);
    } else {
      _store[key] = value;
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
    _store.remove(key);
  }
}

void main() {
  group('WalkthroughService Unit Tests', () {
    late FakeSecureStorage storage;
    late WalkthroughService service;

    setUp(() {
      storage = FakeSecureStorage();
      service = WalkthroughService(storage: storage);
    });

    test('defaults all discovery flags to false and loads cleanly', () async {
      await service.load();
      expect(service.isLoaded, isTrue);
      expect(service.hasSeenMainFeedTour, isFalse);
      expect(service.hasSeenScannerTip, isFalse);
      expect(service.hasSeenProfileSwitchHint, isFalse);
      expect(service.hasSeenHistoryHint, isFalse);
      expect(service.hasSeenCaregiverHint, isFalse);
      expect(service.shouldTriggerPostOnboardingTour, isFalse);
    });

    test('armPostOnboardingTour arms trigger only when main feed tour not seen',
        () async {
      await service.load();
      service.armPostOnboardingTour();
      expect(service.shouldTriggerPostOnboardingTour, isTrue);

      service.consumePostOnboardingTrigger();
      expect(service.shouldTriggerPostOnboardingTour, isFalse);

      await service.markMainFeedTourSeen();
      expect(service.hasSeenMainFeedTour, isTrue);
      expect(service.hasSeenScannerTip, isTrue);
      expect(service.hasSeenProfileSwitchHint, isTrue);

      // Should not re-arm once seen
      service.armPostOnboardingTour();
      expect(service.shouldTriggerPostOnboardingTour, isFalse);
    });

    test('resetAllFlags clears all persisted keys and optionally arms trigger',
        () async {
      await service.markAllSeen();
      expect(service.hasSeenMainFeedTour, isTrue);
      expect(service.hasSeenHistoryHint, isTrue);
      expect(service.hasSeenCaregiverHint, isTrue);

      await service.resetAllFlags(armTrigger: true);
      expect(service.hasSeenMainFeedTour, isFalse);
      expect(service.hasSeenScannerTip, isFalse);
      expect(service.hasSeenProfileSwitchHint, isFalse);
      expect(service.hasSeenHistoryHint, isFalse);
      expect(service.hasSeenCaregiverHint, isFalse);
      expect(service.shouldTriggerPostOnboardingTour, isTrue);
    });
  });

  group('WalkthroughOverlay & Spotlight Sequence Widget Tests', () {
    testWidgets(
        'WalkthroughOverlay steps through 1 of 3 -> 2 of 3 -> 3 of 3 and completes',
        (tester) async {
      final key1 = GlobalKey();
      final key2 = GlobalKey();
      final key3 = GlobalKey();
      var completed = false;
      final visitedSteps = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Stack(
              children: [
                Column(
                  children: [
                    Container(key: key1, width: 200, height: 60, color: Colors.teal),
                    const SizedBox(height: 20),
                    Container(key: key2, width: 120, height: 40, color: Colors.blue),
                    const SizedBox(height: 20),
                    Container(key: key3, width: 140, height: 44, color: Colors.green),
                  ],
                ),
                WalkthroughOverlay(
                  steps: [
                    WalkthroughStep(
                      targetKey: key1,
                      title: 'Your Daily Timeline',
                      description: 'Tap to expand or swipe to log.',
                      icon: CupertinoIcons.calendar_today,
                    ),
                    WalkthroughStep(
                      targetKey: key2,
                      title: 'CareRecipient Switcher',
                      description: 'Filter between family members.',
                      icon: CupertinoIcons.person_2_fill,
                    ),
                    WalkthroughStep(
                      targetKey: key3,
                      title: 'Quick-Scan More Bottles',
                      description: 'Scan subsequent bottles anytime.',
                      icon: CupertinoIcons.camera_fill,
                      pulseTarget: true,
                    ),
                  ],
                  onStepChanged: visitedSteps.add,
                  onComplete: () => completed = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Step 1 of 3
      expect(find.text('Your Daily Timeline'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip Tour'), findsOneWidget);

      // Advance to Step 2 of 3
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('CareRecipient Switcher'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(visitedSteps, [1]);

      // Advance to Step 3 of 3
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Quick-Scan More Bottles'), findsOneWidget);
      expect(find.text('3 of 3'), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);
      expect(visitedSteps, [1, 2]);

      // Complete tour
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(completed, isTrue);
    });

    testWidgets('WalkthroughOverlay Skip Tour button dismisses immediately',
        (tester) async {
      final key1 = GlobalKey();
      var skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Stack(
              children: [
                SizedBox(key: key1, width: 100, height: 50),
                WalkthroughOverlay(
                  steps: [
                    WalkthroughStep(
                      targetKey: key1,
                      title: 'Step 1',
                      description: 'Description 1',
                      icon: CupertinoIcons.sparkles,
                    ),
                  ],
                  onComplete: () {},
                  onSkip: () => skipped = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('walkthrough_skip_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(skipped, isTrue);
    });
  });

  group('Contextual Micro-Hints & HomeScaffold Integration Tests', () {
    testWidgets(
        'ProfilesScreen shows 3-step spotlight walkthrough and AccountScreen shows contextual hint on first visit',
        (tester) async {
      final storage = FakeSecureStorage();
      final walkthroughService = WalkthroughService(storage: storage);
      await walkthroughService.load();

      const me = Profile(id: '1', name: 'Me', color: Colors.teal, isPrimary: true);
      const testRx = Prescription(
        id: 'rx_test',
        name: 'Metformin HCl',
        dosage: '500 mg',
        reminderTimes: ['8:00 AM'],
        daysSupply: 30,
        remaining: 30,
        profileId: '1',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ProfilesScreen(
              profiles: const [me],
              prescriptions: const [testRx],
              doseEvents: const [],
              onEditMedication: (_) {},
              walkthroughService: walkthroughService,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Meds walkthrough Step 1: Adherence Graph
      expect(find.text('Adherence & Consistency'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);

      // Step 2: Saved Medications List
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Saved Medications'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);

      // Step 3: Tap to Edit Schedules
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Tap to Edit Schedules'), findsOneWidget);
      expect(find.text('3 of 3'), findsOneWidget);

      // Complete tour
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(walkthroughService.hasSeenHistoryHint, isTrue);

      // Now verify AccountScreen spotlight walkthrough
      final themeController = ThemeController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AccountScreen(
              profiles: const [me],
              prescriptions: const [],
              onUpdateProfile: (_) {},
              onDeleteProfile: (_) {},
              notificationService: NotificationService(),
              walkthroughService: walkthroughService,
              themeController: themeController,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Account Walkthrough Step 1: Caregiver & Family Profiles
      expect(find.text('Caregiver & Family Profiles'), findsOneWidget);

      // Step 2: Custom Snooze Intervals
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Custom Snooze Intervals'), findsOneWidget);

      // Step 3: Appearance & Dark Mode
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Appearance & Dark Mode'), findsOneWidget);

      // Complete tour
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(walkthroughService.hasSeenCaregiverHint, isTrue);
    });

    testWidgets(
        'HomeScaffold triggers 3-step walkthrough strictly once when armed after Phase 2 medication save',
        (tester) async {
      final storage = FakeSecureStorage();
      final appState = AppStateManager(storage: storage);
      await appState.load();
      await appState.setUserName('Cade');
      await appState.setSeededTestingMode(false);
      await appState.setHasCompletedOnboarding(true);
      appState.walkthroughService.armPostOnboardingTour();

      final db = AppDatabase(NativeDatabase.memory());
      await db.upsertProfile(
        const Profile(id: '1', name: 'Cade', color: Color(0xFF168B87), isPrimary: true),
      );
      await db.upsertPrescription(
        const Prescription(
          id: 'rx_initial',
          name: 'Metformin HCl',
          dosage: '500 mg',
          reminderTimes: ['8:00 AM'],
          daysSupply: 30,
          remaining: 30,
          profileId: '1',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScaffold(
            database: db,
            appStateManager: appState,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify walkthrough overlay triggered on the main feed
      expect(find.text('Your Daily Timeline'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);

      // Skip tour and verify it marks main feed tour as seen
      await tester.tap(find.byKey(const Key('walkthrough_skip_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appState.hasSeenMainFeedTour, isTrue);
      expect(find.text('Your Daily Timeline'), findsNothing);

      // Unmount cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
      await db.close();
    });

    testWidgets(
        'Replaying tab tutorials arms only the active tab walkthrough and never stacks across tabs',
        (tester) async {
      final storage = FakeSecureStorage();
      final appState = AppStateManager(storage: storage);
      await appState.load();
      await appState.setUserName('Cade');
      await appState.setSeededTestingMode(false);
      await appState.setHasCompletedOnboarding(true);

      final db = AppDatabase(NativeDatabase.memory());
      await db.upsertProfile(
        const Profile(id: '1', name: 'Cade', color: Color(0xFF168B87), isPrimary: true),
      );
      await db.upsertPrescription(
        const Prescription(
          id: 'rx_initial',
          name: 'Metformin HCl',
          dosage: '500 mg',
          reminderTimes: ['8:00 AM'],
          daysSupply: 30,
          remaining: 30,
          profileId: '1',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScaffold(
            database: db,
            appStateManager: appState,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Reset all flags via debug helper replayTabTutorials
      await appState.replayTabTutorials();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Only Schedule walkthrough is active
      expect(find.text('Your Daily Timeline'), findsOneWidget);
      expect(find.text('Adherence & Consistency'), findsNothing);
      expect(find.text('Caregiver & Family Profiles'), findsNothing);

      // Skip Schedule tour
      await tester.tap(find.byKey(const Key('walkthrough_skip_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Your Daily Timeline'), findsNothing);

      // 2. Switch to Meds tab
      await tester.tap(find.text('Meds'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Only Meds walkthrough is active
      expect(find.text('Adherence & Consistency'), findsOneWidget);
      expect(find.text('Your Daily Timeline'), findsNothing);
      expect(find.text('Caregiver & Family Profiles'), findsNothing);

      // Skip Meds tour
      await tester.tap(find.byKey(const Key('walkthrough_skip_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Adherence & Consistency'), findsNothing);

      // 3. Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Only Profile walkthrough is active
      expect(find.text('Caregiver & Family Profiles'), findsOneWidget);
      expect(find.text('Your Daily Timeline'), findsNothing);
      expect(find.text('Adherence & Consistency'), findsNothing);

      // Skip Profile tour
      await tester.tap(find.byKey(const Key('walkthrough_skip_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Caregiver & Family Profiles'), findsNothing);

      // Unmount cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
      await db.close();
    });
  });
}
