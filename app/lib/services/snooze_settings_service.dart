import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/scheduling/reminder_scheduler.dart'
    show calculateNextMorningReset;

/// Persists and manages the user's "Default Snooze Duration" setting and
/// temporary "Pause Bedtime Quiet Hours Until 6:00 AM" override via local
/// key-value storage (`shared_preferences`).
///
/// Supports the standard presets (`5m`, `10m`, `15m` default, `30m`) as well
/// as a user-defined custom snooze duration in minutes.
class SnoozeSettingsService extends ChangeNotifier {
  SnoozeSettingsService({
    SharedPreferences? prefs,
    DateTime Function()? clock,
  })  : _prefs = prefs,
        _clock = clock ?? DateTime.now;

  SharedPreferences? _prefs;
  final DateTime Function() _clock;

  static const String keyDefaultSnoozeDuration =
      'default_snooze_duration_minutes';
  static const String keyCustomSnoozeDuration =
      'custom_snooze_duration_minutes';
  static const String keyBedtimeBypassUntilMs = 'bedtime_bypass_until_ms';

  static const int defaultSnoozeDurationMinutes = 15;
  static const List<int> presetOptions = [5, 10, 15, 30];

  int _snoozeDurationMinutes = defaultSnoozeDurationMinutes;
  int? _customSnoozeDurationMinutes;
  DateTime? _bedtimeBypassUntil;
  bool _isLoaded = false;

  /// The currently active default snooze duration in minutes (defaults to 15).
  int get snoozeDurationMinutes => _snoozeDurationMinutes;

  /// The user's saved custom snooze duration in minutes, if one has been set.
  int? get customSnoozeDurationMinutes => _customSnoozeDurationMinutes;

  /// Timestamp until which bedtime quiet hours are temporarily paused (6:00 AM).
  DateTime? get bedtimeBypassUntil => _bedtimeBypassUntil;

  /// True when bedtime quiet hours are temporarily paused right now.
  bool isBedtimeBypassed({DateTime? now}) {
    final until = _bedtimeBypassUntil;
    if (until == null) return false;
    return (now ?? _clock()).isBefore(until);
  }

  /// True when the active snooze duration is not one of the four standard presets.
  bool get isCustomSelected => !presetOptions.contains(_snoozeDurationMinutes);

  bool get isLoaded => _isLoaded;

  /// Formats a minute duration as a concise preset label (e.g., `15m`).
  static String formatPresetLabel(int minutes) => '${minutes}m';

  /// Formats a descriptive label for display in settings headers.
  static String formatDetailLabel(int minutes) {
    if (minutes == defaultSnoozeDurationMinutes) {
      return '${minutes}m (Default)';
    }
    if (presetOptions.contains(minutes)) {
      return '${minutes}m';
    }
    return '${minutes}m (Custom)';
  }

  /// Loads persisted snooze settings from [SharedPreferences].
  Future<void> load() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;

      final savedCustom = prefs.getInt(keyCustomSnoozeDuration);
      if (savedCustom != null && savedCustom > 0) {
        _customSnoozeDurationMinutes = savedCustom;
      }

      final savedDuration = prefs.getInt(keyDefaultSnoozeDuration);
      if (savedDuration != null && savedDuration > 0) {
        _snoozeDurationMinutes = savedDuration;
        if (!presetOptions.contains(savedDuration)) {
          _customSnoozeDurationMinutes ??= savedDuration;
        }
      } else {
        _snoozeDurationMinutes = defaultSnoozeDurationMinutes;
      }

      final savedBypassMs = prefs.getInt(keyBedtimeBypassUntilMs);
      if (savedBypassMs != null && savedBypassMs > 0) {
        final candidate = DateTime.fromMillisecondsSinceEpoch(savedBypassMs);
        if (_clock().isBefore(candidate)) {
          _bedtimeBypassUntil = candidate;
        } else {
          _bedtimeBypassUntil = null;
          await prefs.remove(keyBedtimeBypassUntilMs);
        }
      } else {
        _bedtimeBypassUntil = null;
      }
    } catch (_) {
      // Fall back to in-memory default if SharedPreferences is unavailable
      // in an unmocked test context.
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// Selects and persists a snooze duration in minutes.
  /// Ignores non-positive values.
  Future<void> setSnoozeDurationMinutes(int minutes) async {
    if (minutes <= 0) return;
    final changed = _snoozeDurationMinutes != minutes;
    _snoozeDurationMinutes = minutes;
    if (!presetOptions.contains(minutes)) {
      _customSnoozeDurationMinutes = minutes;
    }
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setInt(keyDefaultSnoozeDuration, minutes);
      if (!presetOptions.contains(minutes)) {
        await prefs.setInt(keyCustomSnoozeDuration, minutes);
      }
    } catch (_) {}
    if (changed || !_isLoaded) {
      notifyListeners();
    }
  }

  /// Saves and activates a custom snooze duration in minutes.
  Future<void> setCustomSnoozeDurationMinutes(int minutes) async {
    if (minutes <= 0) return;
    _customSnoozeDurationMinutes = minutes;
    _snoozeDurationMinutes = minutes;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setInt(keyCustomSnoozeDuration, minutes);
      await prefs.setInt(keyDefaultSnoozeDuration, minutes);
    } catch (_) {}
    notifyListeners();
  }

  /// Temporarily pauses bedtime quiet hours until the next 6:00 AM reset.
  Future<DateTime> pauseBedtimeUntilMorning({DateTime? now}) async {
    final resetTime = calculateNextMorningReset(now ?? _clock());
    _bedtimeBypassUntil = resetTime;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setInt(
        keyBedtimeBypassUntilMs,
        resetTime.millisecondsSinceEpoch,
      );
    } catch (_) {}
    notifyListeners();
    return resetTime;
  }

  /// Re-enables bedtime quiet hours immediately.
  Future<void> resumeBedtimeQuietHours() async {
    final wasSet = _bedtimeBypassUntil != null;
    _bedtimeBypassUntil = null;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.remove(keyBedtimeBypassUntilMs);
    } catch (_) {}
    if (wasSet) {
      notifyListeners();
    }
  }

  /// Clears a persisted bedtime bypass if its 6:00 AM reset time has passed.
  /// Returns `true` if an expired bypass was cleared.
  Future<bool> clearExpiredBedtimeBypass({DateTime? now}) async {
    final until = _bedtimeBypassUntil;
    if (until == null) return false;
    if ((now ?? _clock()).isBefore(until)) return false;
    await resumeBedtimeQuietHours();
    return true;
  }

  /// Resets the snooze duration to the 15m default and clears custom preferences.
  Future<void> resetToDefault() async {
    _snoozeDurationMinutes = defaultSnoozeDurationMinutes;
    _customSnoozeDurationMinutes = null;
    _bedtimeBypassUntil = null;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.remove(keyDefaultSnoozeDuration);
      await prefs.remove(keyCustomSnoozeDuration);
      await prefs.remove(keyBedtimeBypassUntilMs);
    } catch (_) {}
    notifyListeners();
  }
}
