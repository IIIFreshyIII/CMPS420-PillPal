import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/theme/app_theme.dart';
import 'package:pillpal/data/models/profile.dart';
import 'package:pillpal/data/services/notification_service.dart';
import 'package:pillpal/screens/account/account_screen.dart';
import 'package:pillpal/screens/account/default_snooze_setting.dart';
import 'package:pillpal/services/snooze_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'DefaultSnoozeSetting defaults to 9m and persists preset selections via shared_preferences',
      (tester) async {
    final service = SnoozeSettingsService();
    await service.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DefaultSnoozeSetting(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Default Snooze Duration'), findsOneWidget);
    expect(find.text('9m (Default)'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
    expect(find.text('9m'), findsOneWidget);
    expect(find.text('15m'), findsOneWidget);
    expect(find.text('30m'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(service.snoozeDurationMinutes, 9);

    // Select 15m preset
    await tester.tap(find.byKey(const ValueKey('snooze_preset_15m')));
    await tester.pumpAndSettle();

    expect(service.snoozeDurationMinutes, 15);
    expect(find.text('15m'), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(SnoozeSettingsService.keyDefaultSnoozeDuration),
      15,
    );

    // Select 5m preset
    await tester.tap(find.byKey(const ValueKey('snooze_preset_5m')));
    await tester.pumpAndSettle();
    expect(service.snoozeDurationMinutes, 5);
    expect(
      prefs.getInt(SnoozeSettingsService.keyDefaultSnoozeDuration),
      5,
    );

    // Select 30m preset
    await tester.tap(find.byKey(const ValueKey('snooze_preset_30m')));
    await tester.pumpAndSettle();
    expect(service.snoozeDurationMinutes, 30);
    expect(
      prefs.getInt(SnoozeSettingsService.keyDefaultSnoozeDuration),
      30,
    );
  });

  testWidgets(
      'Custom button opens dialog, saves custom snooze duration to shared_preferences, and restores on reload',
      (tester) async {
    final service = SnoozeSettingsService();
    await service.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DefaultSnoozeSetting(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('snooze_preset_custom')));
    await tester.pumpAndSettle();

    expect(find.text('Custom Snooze Duration'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('custom_snooze_input')), '22');
    await tester.tap(find.byKey(const Key('custom_snooze_save_button')));
    await tester.pumpAndSettle();

    expect(service.snoozeDurationMinutes, 22);
    expect(service.isCustomSelected, isTrue);
    expect(find.text('22m (Custom)'), findsOneWidget);

    // Reload from SharedPreferences in a fresh service instance
    final reloadedService = SnoozeSettingsService();
    await reloadedService.load();
    expect(reloadedService.snoozeDurationMinutes, 22);
    expect(reloadedService.customSnoozeDurationMinutes, 22);
    expect(reloadedService.isCustomSelected, isTrue);
  });

  testWidgets('AccountScreen displays Default Snooze Duration setting',
      (tester) async {
    const me = Profile(id: '1', name: 'Me', color: Colors.blue, isPrimary: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AccountScreen(
          profiles: const [me],
          prescriptions: const [],
          onUpdateProfile: (_) {},
          onDeleteProfile: (_) {},
          notificationService: NotificationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Default Snooze Duration'), findsOneWidget);
    expect(find.text('9m (Default)'), findsOneWidget);
  });
}
