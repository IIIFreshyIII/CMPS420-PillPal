import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../theme/liquid_glass_controller.dart';
import '../theme/liquid_glass_mode.dart';
import '../theme/theme_controller.dart';
import '../../data/services/app_lock_service.dart';
import '../../data/services/data_retention_service.dart';
import '../../services/walkthrough_service.dart';

/// Central observable state manager for persistent settings, onboarding lifecycle,
/// interactive tab coach-mark walkthrough flags, and developer debug presets.
class AppStateManager extends ChangeNotifier {
  AppStateManager({
    FlutterSecureStorage? storage,
    ThemeController? themeController,
    LiquidGlassController? liquidGlassController,
    DataRetentionService? retentionService,
    AppLockService? appLockService,
    WalkthroughService? walkthroughService,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            ),
        _themeController = themeController,
        _liquidGlassController = liquidGlassController,
        _retentionService = retentionService,
        _appLockService = appLockService ??
            AppLockService(
              storage: storage ??
                  const FlutterSecureStorage(
                    iOptions: IOSOptions(
                        accessibility: KeychainAccessibility.first_unlock),
                  ),
            ),
        _walkthroughService = walkthroughService ??
            WalkthroughService(
              storage: storage ??
                  const FlutterSecureStorage(
                    iOptions: IOSOptions(
                        accessibility: KeychainAccessibility.first_unlock),
                  ),
            ) {
    _walkthroughService.addListener(notifyListeners);
  }

  final FlutterSecureStorage _storage;
  final ThemeController? _themeController;
  final LiquidGlassController? _liquidGlassController;
  final DataRetentionService? _retentionService;
  final AppLockService? _appLockService;
  final WalkthroughService _walkthroughService;

  // Storage Keys
  static const _keyOnboardingCompleted = 'has_completed_onboarding';
  static const _keyTourSchedule = 'tour_schedule_seen';
  static const _keyTourMeds = 'tour_meds_seen';
  static const _keyTourAccount = 'tour_account_seen';
  static const _keyUserName = 'user_name';
  static const _keySeededTestingMode = 'seeded_testing_mode';

  // Internal State
  bool _hasCompletedOnboarding = false;
  bool _hasSeenScheduleTour = false;
  bool _hasSeenMedsTour = false;
  bool _hasSeenAccountTour = false;
  String _userName = '';
  bool _isSeededTestingMode = true;
  int _retentionDays = DataRetentionService.defaultRetentionDays;
  ThemeMode _appearanceMode = ThemeMode.system;

  // Getters
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get hasSeenScheduleTour =>
      _hasSeenScheduleTour || _walkthroughService.hasSeenMainFeedTour;
  bool get hasSeenMedsTour =>
      _hasSeenMedsTour || _walkthroughService.hasSeenHistoryHint;
  bool get hasSeenAccountTour =>
      _hasSeenAccountTour || _walkthroughService.hasSeenCaregiverHint;
  bool get hasSeenMainFeedTour => _walkthroughService.hasSeenMainFeedTour;
  bool get hasSeenScannerTip => _walkthroughService.hasSeenScannerTip;
  bool get hasSeenProfileSwitchHint =>
      _walkthroughService.hasSeenProfileSwitchHint;
  String get userName => _userName;
  bool get isSeededTestingMode => _isSeededTestingMode;
  WalkthroughService get walkthroughService => _walkthroughService;

  ThemeMode get appearanceMode => _themeController?.value ?? _appearanceMode;
  bool get liquidGlassEnabled =>
      _liquidGlassController?.value != LiquidGlassMode.opaque;
  int get retentionDays =>
      _retentionService?.retentionDays ?? _retentionDays;
  bool get biometricsEnabled => _appLockService?.isEnabled ?? false;
  AppLockService? get appLockService => _appLockService;

  /// Loads all persistent flags from secure storage.
  Future<void> load() async {
    try {
      if (_appLockService != null) {
        await _appLockService.load();
      }
      await _walkthroughService.load();
      _hasCompletedOnboarding =
          (await _storage.read(key: _keyOnboardingCompleted)) == 'true';
      _hasSeenScheduleTour =
          (await _storage.read(key: _keyTourSchedule)) == 'true' ||
              _walkthroughService.hasSeenMainFeedTour;
      _hasSeenMedsTour =
          (await _storage.read(key: _keyTourMeds)) == 'true' ||
              _walkthroughService.hasSeenHistoryHint;
      _hasSeenAccountTour =
          (await _storage.read(key: _keyTourAccount)) == 'true' ||
              _walkthroughService.hasSeenCaregiverHint;
      _userName = await _storage.read(key: _keyUserName) ?? '';

      final retRaw = await _storage.read(key: 'dose_log_retention_days');
      if (retRaw != null) {
        final parsed = int.tryParse(retRaw);
        if (parsed != null && DataRetentionService.presetOptions.contains(parsed)) {
          _retentionDays = parsed;
        }
      }

      final appRaw = await _storage.read(key: 'appearance');
      if (appRaw != null) {
        _appearanceMode = ThemeMode.values.firstWhere(
          (m) => m.name == appRaw,
          orElse: () => ThemeMode.system,
        );
      }

      final seededRaw = await _storage.read(key: _keySeededTestingMode);
      // Default to true if not set
      _isSeededTestingMode = seededRaw == null || seededRaw == 'true';

      // True Clean-Slate Reset: On launch prior to completing onboarding,
      // explicitly wipe lingering iOS Keychain ghost data from previous installs
      if (!_hasCompletedOnboarding) {
        _userName = '';
        _appearanceMode = ThemeMode.system;
        _retentionDays = DataRetentionService.defaultRetentionDays;
        try {
          await _storage.delete(key: _keyUserName);
          await _storage.delete(key: 'appearance');
          await _storage.delete(key: 'app_lock_enabled');
          await _storage.delete(key: 'dose_log_retention_days');
        } catch (_) {}
        await _appLockService?.setEnabled(false);
        await _themeController?.resetToSystem();
        await _retentionService?.setRetentionDays(
          DataRetentionService.defaultRetentionDays,
        );
      }
    } catch (_) {
      // Best effort on test or restricted platforms
    }
    notifyListeners();
  }

  Future<void> setHasCompletedOnboarding(bool value) async {
    _hasCompletedOnboarding = value;
    await _writeBool(_keyOnboardingCompleted, value);
    notifyListeners();
  }

  Future<void> setTourSeen({bool? schedule, bool? meds, bool? account}) async {
    if (schedule != null) {
      _hasSeenScheduleTour = schedule;
      await _writeBool(_keyTourSchedule, schedule);
      if (schedule) {
        await _walkthroughService.markMainFeedTourSeen();
      }
    }
    if (meds != null) {
      _hasSeenMedsTour = meds;
      await _writeBool(_keyTourMeds, meds);
      if (meds) {
        await _walkthroughService.markHistoryHintSeen();
      }
    }
    if (account != null) {
      _hasSeenAccountTour = account;
      await _writeBool(_keyTourAccount, account);
      if (account) {
        await _walkthroughService.markCaregiverHintSeen();
      }
    }
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    try {
      await _storage.write(key: _keyUserName, value: _userName);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setAppearanceMode(ThemeMode mode) async {
    _appearanceMode = mode;
    try {
      await _storage.write(key: 'appearance', value: mode.name);
    } catch (_) {}
    if (_themeController != null) {
      await _themeController.select(mode);
    }
    notifyListeners();
  }

  Future<void> setLiquidGlassEnabled(bool enabled) async {
    if (_liquidGlassController != null) {
      await _liquidGlassController
          .select(enabled ? LiquidGlassMode.liquid : LiquidGlassMode.opaque);
    }
    notifyListeners();
  }

  Future<void> setRetentionDays(int days) async {
    _retentionDays = days;
    try {
      await _storage.write(key: 'dose_log_retention_days', value: '$days');
    } catch (_) {}
    if (_retentionService != null) {
      await _retentionService.setRetentionDays(days);
    }
    notifyListeners();
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    if (_appLockService != null) {
      await _appLockService.setEnabled(enabled);
    }
    await _writeBool('app_lock_enabled', enabled);
    notifyListeners();
  }

  Future<void> setSeededTestingMode(bool enabled) async {
    _isSeededTestingMode = enabled;
    await _writeBool(_keySeededTestingMode, enabled);
    notifyListeners();
  }

  // --- DEBUG SWITCHER PRESETS ---

  /// Preset 1: Fresh A-to-Z Onboarding
  /// Resets `hasCompletedOnboarding = false`, resets all 3 tab tour flags to `false`,
  /// clears active user profile/name, and hides seeded data.
  Future<void> resetToFreshOnboarding() async {
    _hasCompletedOnboarding = false;
    _hasSeenScheduleTour = false;
    _hasSeenMedsTour = false;
    _hasSeenAccountTour = false;
    _isSeededTestingMode = false;
    _userName = '';
    _appearanceMode = ThemeMode.system;

    _retentionDays = DataRetentionService.defaultRetentionDays;

    await _writeBool(_keyOnboardingCompleted, false);
    await _writeBool(_keyTourSchedule, false);
    await _writeBool(_keyTourMeds, false);
    await _writeBool(_keyTourAccount, false);
    await _writeBool(_keySeededTestingMode, false);
    await _walkthroughService.resetAllFlags(armTrigger: false);
    try {
      await _storage.delete(key: _keyUserName);
      await _storage.delete(key: 'appearance');
      await _storage.delete(key: 'app_lock_enabled');
      await _storage.delete(key: 'dose_log_retention_days');
    } catch (_) {}
    await _themeController?.resetToSystem();
    await _appLockService?.setEnabled(false);
    await _retentionService?.setRetentionDays(
      DataRetentionService.defaultRetentionDays,
    );

    notifyListeners();
  }

  /// Preset 2: Seeded UI Testing
  /// Sets `hasCompletedOnboarding = true`, sets all tab tour flags to `true`,
  /// and enables full seeded test medication data visibility on the Home Screen.
  Future<void> setSeededUiTesting() async {
    _hasCompletedOnboarding = true;
    _hasSeenScheduleTour = true;
    _hasSeenMedsTour = true;
    _hasSeenAccountTour = true;
    _isSeededTestingMode = true;
    if (_userName.isEmpty) {
      _userName = 'Me';
      try {
        await _storage.write(key: _keyUserName, value: 'Me');
      } catch (_) {}
    }

    await _writeBool(_keyOnboardingCompleted, true);
    await _writeBool(_keyTourSchedule, true);
    await _writeBool(_keyTourMeds, true);
    await _writeBool(_keyTourAccount, true);
    await _writeBool(_keySeededTestingMode, true);
    await _walkthroughService.markAllSeen();

    notifyListeners();
  }

  /// Preset 3: Replay Tab Tutorials
  /// Keeps current onboarded state but resets `hasSeenScheduleTour`, `hasSeenMedsTour`,
  /// and `hasSeenAccountTour` to `false`.
  Future<void> replayTabTutorials() async {
    _hasSeenScheduleTour = false;
    _hasSeenMedsTour = false;
    _hasSeenAccountTour = false;

    await _writeBool(_keyTourSchedule, false);
    await _writeBool(_keyTourMeds, false);
    await _writeBool(_keyTourAccount, false);
    await _walkthroughService.resetAllFlags(armTrigger: true);

    notifyListeners();
  }

  Future<void> _writeBool(String key, bool value) async {
    try {
      await _storage.write(key: key, value: value ? 'true' : 'false');
    } catch (_) {}
  }
}
