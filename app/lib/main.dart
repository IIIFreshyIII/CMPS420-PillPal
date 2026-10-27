import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/navigation/navigator_key.dart';
import 'core/state/app_state_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/liquid_glass_controller.dart';
import 'core/theme/theme_controller.dart';
import 'data/local/app_database.dart';
import 'data/services/app_lock_service.dart';
import 'data/services/data_retention_service.dart';
import 'data/services/notification_service.dart';
import 'presentation/widgets/debug_floating_switcher.dart';
import 'screens/app_lock/app_lock_gate.dart';
import 'screens/home/home_scaffold.dart';
import 'screens/onboarding/onboarding_flow.dart';

export 'core/navigation/navigator_key.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hide the bottom navigation bar entirely (kept persistently visible by
  // edgeToEdge, just made translucent) -- only the top status bar stays.
  // The bar reappears temporarily if the user swipes up from the bottom
  // edge, standard Android gesture-nav behavior; PillPal's own back/tab
  // controls don't depend on it being visible.
  _hideBottomNavBar();
  // SystemUiMode.manual has no auto-hide timer of its own -- once a swipe
  // reveals the bar it stays until something re-hides it. This callback
  // fires on every such reveal and re-hides it after a couple seconds,
  // matching the auto-dismiss behavior of Android's "sticky immersive" bars
  // while still keeping the status bar always visible (which a plain
  // SystemUiMode.immersiveSticky switch can't do -- it hides both bars
  // together).
  SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
    if (!systemOverlaysAreVisible) return;
    await Future.delayed(const Duration(seconds: 2));
    _hideBottomNavBar();
  });
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      // A fully transparent bar left the icons hard to spot during the
      // brief swipe-reveal (contrast depended entirely on whatever app
      // content happened to be behind them). A ~40% black scrim gives a
      // consistent dark band to read the icons against, so they're switched
      // to light/white to actually show up on it.
      systemNavigationBarColor: Color(0x66000000), // black @ 40% alpha
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: true,
    ),
  );

  // Clean-Slate Check: If onboarding hasn't been completed, purge any
  // leftover iOS Keychain ghost data from earlier test builds so startup
  // never triggers Face ID, never flashes light mode, and defaults correctly.
  const storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  try {
    final onboardedRaw = await storage.read(key: 'has_completed_onboarding');
    if (onboardedRaw != 'true') {
      await storage.delete(key: 'user_name');
      await storage.delete(key: 'appearance');
      await storage.delete(key: 'app_lock_enabled');
      await storage.delete(key: 'dose_log_retention_days');
      await storage.delete(key: 'tour_schedule_seen');
      await storage.delete(key: 'tour_meds_seen');
      await storage.delete(key: 'tour_account_seen');
      await storage.delete(key: 'has_seen_main_feed_tour');
      await storage.delete(key: 'has_seen_scanner_tip');
      await storage.delete(key: 'has_seen_profile_switch_hint');
      await storage.delete(key: 'has_seen_history_hint');
      await storage.delete(key: 'has_seen_caregiver_hint');
      await storage.delete(key: 'seeded_testing_mode');
    }
  } catch (_) {}

  // Read before runApp so a saved Dark choice is applied on the very first
  // frame, with no light flash.
  final themeController = await ThemeController.load();
  final liquidGlassController = await LiquidGlassController.load();
  // Also before runApp: if App Lock is on, the very first frame is the lock
  // screen, never a glimpse of the schedule.
  final appLock = AppLockService();
  await appLock.load();
  final retentionService = DataRetentionService();
  await retentionService.load();

  final appStateManager = AppStateManager(
    themeController: themeController,
    liquidGlassController: liquidGlassController,
    retentionService: retentionService,
    appLockService: appLock,
  );
  await appStateManager.load();

  runApp(PillPalApp(
    themeController: themeController,
    liquidGlassController: liquidGlassController,
    appLock: appLock,
    appStateManager: appStateManager,
  ));
}

void _hideBottomNavBar() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.top]);
}

class PillPalApp extends StatefulWidget {
  const PillPalApp({
    super.key,
    required this.themeController,
    required this.liquidGlassController,
    required this.appLock,
    this.appStateManager,
    this.database,
    this.notificationService,
    this.navigatorKey,
  });

  final ThemeController themeController;
  final LiquidGlassController liquidGlassController;
  final AppLockService appLock;
  final AppStateManager? appStateManager;
  final AppDatabase? database;
  final NotificationService? notificationService;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<PillPalApp> createState() => _PillPalAppState();
}

class _PillPalAppState extends State<PillPalApp> {
  late final AppStateManager _appStateManager;
  late final AppDatabase _database;
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _appStateManager = widget.appStateManager ??
        AppStateManager(
          themeController: widget.themeController,
          liquidGlassController: widget.liquidGlassController,
          retentionService: DataRetentionService(),
          appLockService: widget.appLock,
        );
    _database = widget.database ?? AppDatabase();
    _notificationService = widget.notificationService ?? NotificationService();
  }

  @override
  Widget build(BuildContext context) {
    final navKey = widget.navigatorKey ?? rootNavigatorKey;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themeController,
      builder: (context, mode, _) => MaterialApp(
        navigatorKey: navKey,
        title: 'PillPal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        themeAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        ),
        // Android keeps the system nav bar persistently hidden and only lets
        // it transiently reveal via an edge swipe (re-hidden after ~2s, above).
        // That transient reveal briefly reports a non-zero bottom
        // padding/viewPadding through MediaQuery, and anything that reacts to
        // it -- a bottom bar, a bottom-anchored panel, any SafeArea -- visibly
        // jumps for that instant. Stripping the bottom inset here, once, for
        // the whole app means nothing in the tree can react to it, instead of
        // chasing down every current and future widget that touches it.
        // iOS is untouched: its home-indicator inset is a real, static safe
        // area, not a transient one, and FloatingTabBar depends on it.
        builder: (context, child) => ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: [
              AppLockGate(
                service: widget.appLock,
                enabled: _appStateManager.hasCompletedOnboarding,
                child: Platform.isAndroid
                    ? MediaQuery.removeViewPadding(
                        context: context,
                        removeBottom: true,
                        child: MediaQuery.removePadding(
                          context: context,
                          removeBottom: true,
                          child: child!,
                        ),
                      )
                    : child!,
              ),
              if (kDebugMode || kProfileMode)
                DebugFloatingSwitcher(
                  appStateManager: _appStateManager,
                  database: _database,
                  navigatorKey: navKey,
                ),
            ],
          ),
        ),
        home: ListenableBuilder(
          listenable: _appStateManager,
          builder: (context, _) {
            if (!_appStateManager.hasCompletedOnboarding) {
              return OnboardingFlow(
                appStateManager: _appStateManager,
                database: _database,
                notificationService: _notificationService,
                onComplete: () {
                  _appStateManager.setHasCompletedOnboarding(true);
                },
              );
            }
            return HomeScaffold(
              database: _database,
              themeController: widget.themeController,
              liquidGlassController: widget.liquidGlassController,
              appLock: widget.appLock,
              appStateManager: _appStateManager,
            );
          },
        ),
      ),
    );
  }
}
