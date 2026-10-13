import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/date_formatter.dart';
import '../local/app_database.dart';
import '../models/dose_event.dart';
import '../models/prescription.dart';
import '../models/profile.dart';

/// Manages how long historical dose tracking logs (taken on-time, late, and
/// skipped records) are retained on the device.
///
/// By default, PillPal stores logs for up to 1 year (365 days). When records
/// exceed the retention duration, the user is notified so they can export
/// their history for personal records or purge them to free device space.
/// Users can also configure a shorter window (e.g., 30, 90, 180 days) or keep
/// all logs indefinitely in Settings.
class DataRetentionService extends ChangeNotifier {
  DataRetentionService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'dose_log_retention_days';
  static const defaultRetentionDays = 365;

  static const presetOptions = [30, 90, 180, 365, 0];

  int _retentionDays = defaultRetentionDays;
  int get retentionDays => _retentionDays;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  static String retentionLabel(int days) {
    switch (days) {
      case 30:
        return '30 Days (1 Month)';
      case 90:
        return '90 Days (3 Months)';
      case 180:
        return '180 Days (6 Months)';
      case 365:
        return '1 Year (Default)';
      case 0:
        return 'Keep All (Never Purge)';
      default:
        return '$days Days';
    }
  }

  Future<void> load() async {
    final raw = await _storage.read(key: _key);
    if (raw != null) {
      final parsed = int.tryParse(raw);
      if (parsed != null && presetOptions.contains(parsed)) {
        _retentionDays = parsed;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setRetentionDays(int days) async {
    if (_retentionDays == days) return;
    _retentionDays = days;
    await _storage.write(key: _key, value: days.toString());
    notifyListeners();
  }

  DateTime? getCutoffDate({int? customDays, DateTime? now}) {
    final days = customDays ?? _retentionDays;
    if (days <= 0) return null;
    final current = now ?? DateTime.now();
    return current.subtract(Duration(days: days));
  }

  List<DoseEvent> getExpiredEvents(
    List<DoseEvent> events, {
    int? customDays,
    DateTime? now,
  }) {
    final cutoff = getCutoffDate(customDays: customDays, now: now);
    if (cutoff == null) return const [];
    return events.where((e) => e.occurredAt.isBefore(cutoff)).toList();
  }

  Future<int> purgeExpired(
    AppDatabase db, {
    int? customDays,
    DateTime? now,
  }) async {
    final cutoff = getCutoffDate(customDays: customDays, now: now);
    if (cutoff == null) return 0;
    final deleted = await db.deleteDoseEventsBefore(cutoff);
    notifyListeners();
    return deleted;
  }

  /// Builds a human-readable CSV formatted log string for user export.
  static String buildCsv({
    required List<DoseEvent> events,
    required List<Prescription> prescriptions,
    required List<Profile> profiles,
  }) {
    final medMap = {for (final p in prescriptions) p.id: p};
    final profileMap = {for (final p in profiles) p.id: p};

    final buffer = StringBuffer();
    buffer.writeln('Date,Time,Status,Medication,Dosage,Profile');

    for (final event in events) {
      final med = medMap[event.prescriptionId];
      final profile = profileMap[event.profileId];

      final dateStr =
          '${event.occurredAt.year}-${event.occurredAt.month.toString().padLeft(2, '0')}-${event.occurredAt.day.toString().padLeft(2, '0')}';
      final timeStr = formatTimeOfDay(event.occurredAt);

      final statusStr = switch (event.action) {
        DoseAction.taken => 'On Time',
        DoseAction.late => 'Late',
        DoseAction.skipped => 'Skipped',
      };

      final medName = (med?.name ?? 'Unknown Medication').replaceAll(',', ' ');
      final dosage = (med?.dosage ?? '').replaceAll(',', ' ');
      final profileName = (profile?.name ?? 'General').replaceAll(',', ' ');

      buffer.writeln('$dateStr,$timeStr,$statusStr,$medName,$dosage,$profileName');
    }

    return buffer.toString();
  }

  /// Exports dose history logs to a CSV file and opens the native OS share sheet.
  Future<void> exportAndShareCsv({
    required List<DoseEvent> events,
    required List<Prescription> prescriptions,
    required List<Profile> profiles,
  }) async {
    final csvContent = buildCsv(
      events: events,
      prescriptions: prescriptions,
      profiles: profiles,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pillpal_dose_history.csv');
    await file.writeAsString(csvContent);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, name: 'pillpal_dose_history.csv')],
      subject: 'PillPal Medication Dose History',
    ));
  }
}
