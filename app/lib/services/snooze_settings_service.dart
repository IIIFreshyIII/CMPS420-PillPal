import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and manages the user's "Default Snooze Duration" setting via
/// local key-value storage (`shared_preferences`).
///
/// Supports the standard presets (`5m`, `9m` default, `15m`, `30m`) as well
/// as a user-defined custom snooze duration in minutes.
class SnoozeSettingsService extends ChangeNotifier {
  SnoozeSettingsService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static const String keyDefaultSnoozeDuration =
      'default_snooze_duration_minutes';
  static const String keyCustomSnoozeDuration =
      'custom_snooze_duration_minutes';

  static const int defaultSnoozeDurationMinutes = 9;
  static const List<int> presetOptions = [5, 9, 15, 30];

  int _snoozeDurationMinutes = defaultSnoozeDurationMinutes;
  int? _customSnoozeDurationMinutes;
  bool _isLoaded = false;

  /// The currently active default snooze duration in minutes (defaults to 9).
  int get snoozeDurationMinutes => _snoozeDurationMinutes;

  /// The user's saved custom snooze duration in minutes, if one has been set.
  int? get customSnoozeDurationMinutes => _customSnoozeDurationMinutes;

  /// True when the active snooze duration is not one of the four standard presets.
  bool get isCustomSelected => !presetOptions.contains(_snoozeDurationMinutes);

  bool get isLoaded => _isLoaded;

  /// Formats a minute duration as a concise preset label (e.g., `9m`).
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

  /// Resets the snooze duration to the 9m default and clears custom preferences.
  Future<void> resetToDefault() async {
    _snoozeDurationMinutes = defaultSnoozeDurationMinutes;
    _customSnoozeDurationMinutes = null;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.remove(keyDefaultSnoozeDuration);
      await prefs.remove(keyCustomSnoozeDuration);
    } catch (_) {}
    notifyListeners();
  }
}
