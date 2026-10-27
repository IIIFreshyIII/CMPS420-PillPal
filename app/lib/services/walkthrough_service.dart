import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service responsible for persisting and coordinating first-run feature
/// discovery and contextual guidance flags across the app.
///
/// Uses [FlutterSecureStorage] to match the rest of PillPal's zero-disk-leak
/// local key-value architecture.
class WalkthroughService extends ChangeNotifier {
  WalkthroughService({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  // Storage keys for feature-discovery and contextual guidance
  static const String keyHasSeenMainFeedTour = 'has_seen_main_feed_tour';
  static const String keyHasSeenScannerTip = 'has_seen_scanner_tip';
  static const String keyHasSeenProfileSwitchHint =
      'has_seen_profile_switch_hint';
  static const String keyHasSeenHistoryHint = 'has_seen_history_hint';
  static const String keyHasSeenCaregiverHint = 'has_seen_caregiver_hint';

  // Legacy/companion keys from AppStateManager for seamless compatibility
  static const String keyLegacyTourSchedule = 'tour_schedule_seen';
  static const String keyLegacyTourMeds = 'tour_meds_seen';
  static const String keyLegacyTourAccount = 'tour_account_seen';

  bool _hasSeenMainFeedTour = false;
  bool _hasSeenScannerTip = false;
  bool _hasSeenProfileSwitchHint = false;
  bool _hasSeenHistoryHint = false;
  bool _hasSeenCaregiverHint = false;
  bool _shouldTriggerPostOnboardingTour = false;
  bool _isLoaded = false;

  bool get hasSeenMainFeedTour => _hasSeenMainFeedTour;
  bool get hasSeenScannerTip => _hasSeenScannerTip;
  bool get hasSeenProfileSwitchHint => _hasSeenProfileSwitchHint;
  bool get hasSeenHistoryHint => _hasSeenHistoryHint;
  bool get hasSeenCaregiverHint => _hasSeenCaregiverHint;
  bool get shouldTriggerPostOnboardingTour => _shouldTriggerPostOnboardingTour;
  bool get isLoaded => _isLoaded;

  /// Loads all feature-discovery flags from local storage.
  Future<void> load() async {
    try {
      final mainFeedRaw = await _storage.read(key: keyHasSeenMainFeedTour);
      final legacyScheduleRaw = await _storage.read(key: keyLegacyTourSchedule);
      _hasSeenMainFeedTour =
          mainFeedRaw == 'true' || legacyScheduleRaw == 'true';

      final scannerRaw = await _storage.read(key: keyHasSeenScannerTip);
      _hasSeenScannerTip = scannerRaw == 'true';

      final profileHintRaw =
          await _storage.read(key: keyHasSeenProfileSwitchHint);
      _hasSeenProfileSwitchHint = profileHintRaw == 'true';

      final historyRaw = await _storage.read(key: keyHasSeenHistoryHint);
      final legacyMedsRaw = await _storage.read(key: keyLegacyTourMeds);
      _hasSeenHistoryHint = historyRaw == 'true' || legacyMedsRaw == 'true';

      final caregiverRaw = await _storage.read(key: keyHasSeenCaregiverHint);
      final legacyAccountRaw = await _storage.read(key: keyLegacyTourAccount);
      _hasSeenCaregiverHint =
          caregiverRaw == 'true' || legacyAccountRaw == 'true';
    } catch (_) {
      // Best-effort in restricted or widget test environments
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// Arms the interactive walkthrough so it triggers strictly once when the
  /// user arrives on the unified daily feed immediately following the Phase 2
  /// initial medication save (or when explicitly replayed from Developer Settings).
  void armPostOnboardingTour() {
    if (!_hasSeenMainFeedTour) {
      _shouldTriggerPostOnboardingTour = true;
      notifyListeners();
    }
  }

  /// Consumes the pending trigger when the overlay starts displaying.
  void consumePostOnboardingTrigger() {
    if (_shouldTriggerPostOnboardingTour) {
      _shouldTriggerPostOnboardingTour = false;
      notifyListeners();
    }
  }

  /// Marks the 3-step main feed spotlight tour (and its component steps) as seen.
  Future<void> markMainFeedTourSeen() async {
    _hasSeenMainFeedTour = true;
    _hasSeenScannerTip = true;
    _hasSeenProfileSwitchHint = true;
    _shouldTriggerPostOnboardingTour = false;
    await _writeBool(keyHasSeenMainFeedTour, true);
    await _writeBool(keyHasSeenScannerTip, true);
    await _writeBool(keyHasSeenProfileSwitchHint, true);
    await _writeBool(keyLegacyTourSchedule, true);
    notifyListeners();
  }

  Future<void> markScannerTipSeen() async {
    _hasSeenScannerTip = true;
    await _writeBool(keyHasSeenScannerTip, true);
    notifyListeners();
  }

  Future<void> markProfileSwitchHintSeen() async {
    _hasSeenProfileSwitchHint = true;
    await _writeBool(keyHasSeenProfileSwitchHint, true);
    notifyListeners();
  }

  Future<void> markHistoryHintSeen() async {
    _hasSeenHistoryHint = true;
    await _writeBool(keyHasSeenHistoryHint, true);
    await _writeBool(keyLegacyTourMeds, true);
    notifyListeners();
  }

  Future<void> markCaregiverHintSeen() async {
    _hasSeenCaregiverHint = true;
    await _writeBool(keyHasSeenCaregiverHint, true);
    await _writeBool(keyLegacyTourAccount, true);
    notifyListeners();
  }

  /// Marks all walkthrough and contextual guidance flags as completed (e.g., for
  /// Seeded UI Testing preset).
  Future<void> markAllSeen() async {
    _hasSeenMainFeedTour = true;
    _hasSeenScannerTip = true;
    _hasSeenProfileSwitchHint = true;
    _hasSeenHistoryHint = true;
    _hasSeenCaregiverHint = true;
    _shouldTriggerPostOnboardingTour = false;

    await _writeBool(keyHasSeenMainFeedTour, true);
    await _writeBool(keyHasSeenScannerTip, true);
    await _writeBool(keyHasSeenProfileSwitchHint, true);
    await _writeBool(keyHasSeenHistoryHint, true);
    await _writeBool(keyHasSeenCaregiverHint, true);
    await _writeBool(keyLegacyTourSchedule, true);
    await _writeBool(keyLegacyTourMeds, true);
    await _writeBool(keyLegacyTourAccount, true);
    notifyListeners();
  }

  /// Silent debug reset for Developer Settings to clear all walkthrough flags
  /// for testing, optionally arming the main feed tour immediately.
  Future<void> resetAllFlags({bool armTrigger = false}) async {
    _hasSeenMainFeedTour = false;
    _hasSeenScannerTip = false;
    _hasSeenProfileSwitchHint = false;
    _hasSeenHistoryHint = false;
    _hasSeenCaregiverHint = false;
    _shouldTriggerPostOnboardingTour = armTrigger;

    await _writeBool(keyHasSeenMainFeedTour, false);
    await _writeBool(keyHasSeenScannerTip, false);
    await _writeBool(keyHasSeenProfileSwitchHint, false);
    await _writeBool(keyHasSeenHistoryHint, false);
    await _writeBool(keyHasSeenCaregiverHint, false);
    await _writeBool(keyLegacyTourSchedule, false);
    await _writeBool(keyLegacyTourMeds, false);
    await _writeBool(keyLegacyTourAccount, false);
    notifyListeners();
  }

  Future<void> _writeBool(String key, bool value) async {
    try {
      await _storage.write(key: key, value: value ? 'true' : 'false');
    } catch (_) {}
  }
}
