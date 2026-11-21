import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/pillpal_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/services/app_lock_service.dart';
import '../../data/local/app_database.dart';
import '../../data/models/dose_event.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/extractor.dart';
import '../../data/services/notification_service.dart';
import '../../presentation/widgets/floating_tab_bar.dart';
import '../account/account_screen.dart';
import '../confirm/confirm_screen.dart';
import '../profiles/profiles_screen.dart';
import '../scan/live_scan_screen.dart';
import '../scan/upload_scan_screen.dart';
import '../schedule/schedule_screen.dart';
import '../medication_detail/medication_detail_sheet.dart';
import '../medication_detail/medication_quick_view_sheet.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/services/data_retention_service.dart';
import '../../presentation/widgets/android_sliding_bottom_bar.dart';
import '../../presentation/widgets/classic_ios_tab_bar.dart';
import '../../presentation/widgets/keep_alive_tab_stack.dart';
import '../../core/services/ios_accessibility_service.dart';
import '../../core/state/app_state_manager.dart';
import '../../core/theme/liquid_glass_controller.dart';
import '../../core/utils/ios_design_era.dart';
import '../../services/bedtime_service.dart';
import '../../services/live_reminder_service.dart';
import '../../services/walkthrough_service.dart';
import '../../ui/widgets/walkthrough_overlay.dart';

enum _AddMedsMode { live, upload, manual }

enum _BedtimeSnoozeChoice { cancel, clampToBedtime, pauseTonight }

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({
    super.key,
    this.database,
    this.themeController,
    this.liquidGlassController,
    this.appLock,
    this.appStateManager,
    this.walkthroughService,
    this.snoozeSettingsService,
    this.bedtimeService,
    this.liveReminderService,
    this.initialTab = AppTab.schedule,
  });

  /// Injectable for tests (an in-memory `AppDatabase`); production always
  /// uses the default on-disk database created in `initState`.
  final AppDatabase? database;
  final ThemeController? themeController;
  final LiquidGlassController? liquidGlassController;
  final AppLockService? appLock;
  final AppStateManager? appStateManager;
  final WalkthroughService? walkthroughService;
  final SnoozeSettingsService? snoozeSettingsService;
  final BedtimeService? bedtimeService;
  final LiveReminderService? liveReminderService;
  final AppTab initialTab;


  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold>
    with WidgetsBindingObserver {
  late AppTab _activeTab;
  String _selectedProfileId = 'all';
  bool _isScanning = false;
  bool _isProcessingPhoto = false;
  bool _isShowingWalkthrough = false;
  OverlayEntry? _walkthroughOverlayEntry;

  final GlobalKey _firstMedCardKey =
      GlobalKey(debugLabel: 'walkthrough_first_med_card');
  final GlobalKey _profileSwitcherKey =
      GlobalKey(debugLabel: 'walkthrough_profile_switcher');
  final List<GlobalKey> _profileChipKeys = List.generate(
    8,
    (i) => GlobalKey(debugLabel: 'walkthrough_profile_chip_$i'),
  );
  final GlobalKey _scanButtonKey =
      GlobalKey(debugLabel: 'walkthrough_scan_button');
  final GlobalKey _emptyScheduleKey =
      GlobalKey(debugLabel: 'walkthrough_empty_schedule');

  late final AppDatabase _db;
  late final NotificationService _notifications;
  late final DataRetentionService _retentionService;
  late final LiquidGlassController _liquidGlassController;
  late final WalkthroughService _walkthroughService;
  late final SnoozeSettingsService _snoozeSettingsService;
  late final BedtimeService _bedtimeService;
  late final bool _ownsBedtimeService;
  late final LiveReminderService _liveReminderService;
  bool _notificationPermissionsRequested = false;
  bool _hasReceivedPrescriptionStream = false;
  StreamSubscription<List<Profile>>? _profilesSub;
  StreamSubscription<List<Prescription>>? _prescriptionsSub;
  StreamSubscription<List<DoseEvent>>? _doseEventsSub;

  List<Profile> _profiles = const [];
  List<Prescription> _prescriptions = const [];
  List<DoseEvent> _doseEvents = const [];
  final Set<String> _skippedSlotKeys = <String>{};
  String _skippedDateKey = '';


  static const _seedProfiles = [
    Profile(id: '1', name: 'Me', color: Color(0xFF3B82F6), isPrimary: true),
    Profile(id: '2', name: 'Mom', color: Color(0xFF8B5CF6)),
  ];

  static const _seedPrescriptions = [
    Prescription(
      id: '1',
      name: 'Allegra',
      dosage: '10mg',
      reminderTimes: ['8:00 AM'],
      daysSupply: 14,
      remaining: 14,
      profileId: '1',
    ),
    Prescription(
      id: '2',
      name: 'Lisinopril',
      dosage: '20mg',
      reminderTimes: ['8:00 AM'],
      daysSupply: 4,
      remaining: 4,
      profileId: '2',
    ),
    Prescription(
      id: '3',
      name: 'Metformin',
      dosage: '500mg',
      reminderTimes: ['12:00 PM'],
      daysSupply: 28,
      remaining: 28,
      profileId: '2',
    ),
  ];

  static List<DoseEvent> _seedDoseEvents() {
    final now = DateTime.now();
    final events = <DoseEvent>[];
    for (int i = 6; i >= 0; i--) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      // Allegra: 8:05 AM (on time)
      events.add(DoseEvent(
        id: 'seed_allegra_$i',
        prescriptionId: '1',
        profileId: '1',
        occurredAt: DateTime(day.year, day.month, day.day, 8, 5),
        action: DoseAction.taken,
      ));
      // Lisinopril: on time, except i == 2 (late at 11:30 AM), i == 4 (skipped)
      if (i == 4) {
        events.add(DoseEvent(
          id: 'seed_lisinopril_$i',
          prescriptionId: '2',
          profileId: '2',
          occurredAt: DateTime(day.year, day.month, day.day, 8, 0),
          action: DoseAction.skipped,
        ));
      } else {
        events.add(DoseEvent(
          id: 'seed_lisinopril_$i',
          prescriptionId: '2',
          profileId: '2',
          occurredAt: i == 2
              ? DateTime(day.year, day.month, day.day, 11, 30)
              : DateTime(day.year, day.month, day.day, 8, 12),
          action: i == 2 ? DoseAction.late : DoseAction.taken,
        ));
      }
      // Metformin: 12:15 PM (on time), except i == 1 (late at 3:15 PM)
      events.add(DoseEvent(
        id: 'seed_metformin_$i',
        prescriptionId: '3',
        profileId: '2',
        occurredAt: i == 1
            ? DateTime(day.year, day.month, day.day, 15, 15)
            : DateTime(day.year, day.month, day.day, 12, 15),
        action: i == 1 ? DoseAction.late : DoseAction.taken,
      ));
    }
    return events;
  }

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _db = widget.database ?? AppDatabase();
    _retentionService =
        widget.appStateManager?.retentionService ?? DataRetentionService();
    _liquidGlassController =
        widget.liquidGlassController ?? LiquidGlassController();
    _walkthroughService = widget.walkthroughService ??
        widget.appStateManager?.walkthroughService ??
        WalkthroughService();
    _snoozeSettingsService =
        widget.snoozeSettingsService ?? SnoozeSettingsService();
    _snoozeSettingsService.addListener(_onSnoozeSettingsChanged);
    _ownsBedtimeService =
        widget.bedtimeService == null && widget.appStateManager == null;
    _bedtimeService = widget.bedtimeService ??
        widget.appStateManager?.bedtimeService ??
        BedtimeService();
    _bedtimeService.addListener(_onBedtimeSettingsChanged);
    _liveReminderService = widget.liveReminderService ??
        LiveReminderService(
          snoozeSettings: _snoozeSettingsService,
          bedtimeService: _bedtimeService,
        );
    _notifications = NotificationService(
      liveReminderService: _liveReminderService,
      bedtimeService: _bedtimeService,
    );
    _liveReminderService.onNativeAction = _handleNativeReminderAction;
    _liveReminderService.registerNativeCallbackHandler();
    NotificationService.onLogAllTaken = _handleLogAllTakenForTimeSlot;
    if (!_walkthroughService.isLoaded) {
      unawaited(_walkthroughService.load());
    }
    if (!_snoozeSettingsService.isLoaded) {
      unawaited(_snoozeSettingsService.load());
    }
    if (!_bedtimeService.isLoaded) {
      unawaited(_bedtimeService.load());
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(_retentionService.load());
    unawaited(IOSAccessibilityService.instance.updateAccessibilitySettings());
    unawaited(_loadSkippedSlotKeys());

    // Pre-populate _profiles with user's name to eliminate the 1-second
    // "Good afternoon, there" / blank schedule flash.
    final initialUserName = widget.appStateManager?.userName.trim();
    if (initialUserName != null && initialUserName.isNotEmpty) {
      _profiles = [
        Profile(
          id: '1',
          name: initialUserName,
          color: const Color(0xFF168B87),
          isPrimary: true,
        ),
      ];
    }

    final isSeeded = widget.appStateManager?.isSeededTestingMode ?? true;
    if (isSeeded) {
      _db
          .seedIfEmpty(_seedProfiles, _seedPrescriptions, _seedDoseEvents())
          .catchError((e) {
        debugPrint('Error seeding database: $e');
      });
    }

    _profilesSub = _db.watchProfiles().listen((rows) {
      final filtered = _applySeedFilterProfiles(rows);
      if (mounted) {
        setState(() => _profiles = filtered);
        _maybeLaunchPostOnboardingWalkthrough();
      }
      unawaited(_bedtimeService.migrateFromProfilesIfNeeded(filtered));
      _syncNotifications();
    }, onError: (e) {
      debugPrint('Error watching profiles: $e');
    });
    _prescriptionsSub = _db.watchPrescriptions().listen((rows) {
      if (mounted) {
        _hasReceivedPrescriptionStream = true;
        setState(() => _prescriptions = _applySeedFilterPrescriptions(rows));
        _maybeLaunchPostOnboardingWalkthrough();
        unawaited(_drainPendingNotificationActions());
      }
      _syncNotifications();
    }, onError: (e) {
      debugPrint('Error watching prescriptions: $e');
    });
    _doseEventsSub = _db.watchDoseEvents().listen((rows) {
      if (mounted) {
        final filtered = _applySeedFilterDoseEvents(rows);
        setState(() {
          _doseEvents = filtered;
        });
      }
    }, onError: (e) {
      debugPrint('Error watching dose events: $e');
    });

    widget.appStateManager?.addListener(_onAppStateChanged);
    _walkthroughService.addListener(_onWalkthroughStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLaunchPostOnboardingWalkthrough();
    });
  }

  List<Profile> _applySeedFilterProfiles(List<Profile> rows) {
    if (widget.appStateManager?.isSeededTestingMode == false) {
      return rows.where((p) => p.id != '2').toList();
    }
    return rows;
  }

  List<Prescription> _applySeedFilterPrescriptions(List<Prescription> rows) {
    if (widget.appStateManager?.isSeededTestingMode == false) {
      return rows.where((p) => p.id != '1' && p.id != '2' && p.id != '3').toList();
    }
    return rows;
  }

  List<DoseEvent> _applySeedFilterDoseEvents(List<DoseEvent> rows) {
    if (widget.appStateManager?.isSeededTestingMode == false) {
      return rows.where((e) => !e.id.startsWith('seed_')).toList();
    }
    return rows;
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final isSeeded = widget.appStateManager?.isSeededTestingMode ?? true;
    if (isSeeded) {
      _db
          .seedIfEmpty(_seedProfiles, _seedPrescriptions, _seedDoseEvents())
          .catchError((e) {
        debugPrint('Error seeding database: $e');
      });
    }
    setState(() {});
  }

  bool _syncingNotifications = false;
  bool _notificationSyncQueued = false;

  /// Reconciles every scheduled reminder against current state -- called
  /// whenever prescriptions or profiles change (their stream listeners,
  /// above), which also covers app startup (the first emission) and so
  /// doesn't need a separate reboot-recovery path. Failures here (a missing
  /// plugin in a test environment, a real device without the permission
  /// granted yet) are swallowed, not rethrown -- notification delivery must
  /// never be able to crash the medication-tracking UI around it.
  ///
  /// `_syncingNotifications`/`_notificationSyncQueued` serialize calls:
  /// `NotificationService.syncAll` cancels everything then reschedules from
  /// scratch, and the profiles/prescriptions streams can each fire their own
  /// call within milliseconds of each other on startup -- two overlapping
  /// calls raced here before this guard (confirmed via `adb shell dumpsys
  /// alarm`: one call's `cancelAll()` wiped an alarm the other had already
  /// scheduled seconds earlier, silently dropping a reminder). Only one call
  /// runs at a time now; anything that arrives mid-sync is coalesced into a
  /// single trailing re-run against whatever state is current by then.
  Future<void> _syncNotifications() async {
    if (_syncingNotifications) {
      _notificationSyncQueued = true;
      return;
    }
    _syncingNotifications = true;
    try {
      if (!_notificationPermissionsRequested &&
          _prescriptions.any((p) => p.reminderTimes.isNotEmpty)) {
        _notificationPermissionsRequested = true;
        await _notifications.requestPermissions();
      }
      await _notifications.syncAll(
        _prescriptions,
        _profiles,
        skippedSlotKeys: _skippedSlotKeys,
        activeSnoozeEnds: _liveReminderService.activeSnoozeEnds,
        bypassBedtime: _bedtimeService.isPausedAt(),
        bedtimeSchedule: _bedtimeService.schedule,
      );
    } catch (e) {
      debugPrint('Notification sync failed: $e');
    } finally {
      _syncingNotifications = false;
      if (_notificationSyncQueued) {
        _notificationSyncQueued = false;
        unawaited(_syncNotifications());
      }
    }
  }

  Future<void> _drainPendingNotificationActions() async {
    final actions = await _notifications.drainPendingActions();
    if (actions.isEmpty || !mounted) return;
    for (final entry in actions) {
      if (entry.actionId == NotificationService.logAllTakenActionId) {
        await _handleLogAllTakenForTimeSlot(entry.timeSlot);
      } else if (entry.actionId == NotificationService.snoozeActionId) {
        await _notifications.handleReminderSnooze(
          entry.timeSlot,
          prescriptions: _prescriptions,
          profiles: _profiles,
          snoozeDurationMinutes: _snoozeSettingsService.snoozeDurationMinutes,
          bypassBedtime: _bedtimeService.isPausedAt(),
        );
        unawaited(_syncNotifications());
      }
    }
  }

  Future<void> _handleLogAllTakenForTimeSlot(String timeSlot) async {
    if (!mounted) return;
    for (final prescription in _prescriptions) {
      for (final candidate in prescription.reminderTimes) {
        if (!isSameTimeSlot(candidate, timeSlot)) continue;
        final allowed = _bedtimeService.shouldScheduleReminder(
          timeSlot: candidate,
          allowAfterBedtime: prescription.allowAfterBedtime,
        );
        if (!allowed) continue;
        final isTaken = prescription.takenTimes.any(
          (t) => isSameTimeSlot(t, candidate),
        );
        final isSkipped =
            _skippedSlotKeys.contains('${prescription.id}_$candidate');
        if (!isTaken && !isSkipped) {
          _handleTakeDose(prescription.id, candidate);
        }
      }
    }
    await _liveReminderService.dismissActivity(
      batchId: batchIdForTimeSlot(timeSlot),
    );
    await _notifications.cancelSnoozeNotification(timeSlot);
  }

  void _onSnoozeSettingsChanged() {
    if (!mounted) return;
    unawaited(_syncNotifications());
  }

  void _onBedtimeSettingsChanged() {
    if (!mounted) return;
    unawaited(_syncNotifications());
  }

  Future<void> _syncTimeSlotLiveReminder(
    String timeSlot,
    List<Prescription> prescriptions,
  ) async {
    final batch = await _liveReminderService.syncTimeSlotDoses(
      timeSlot: timeSlot,
      prescriptions: prescriptions,
      profiles: _profiles,
      skippedSlotKeys: _skippedSlotKeys,
    );
    if (batch.remainingDosesCount <= 0) {
      await _notifications.cancelSnoozeNotification(timeSlot);
    }
  }

  void _handleUpdateMedication(Prescription updated) {
    _db.upsertPrescription(updated);
  }

  void _handleUpdateProfile(Profile updated) {
    _db.upsertProfile(updated);
  }

  void _handleDeleteProfile(String id) {
    _db.deleteProfile(id);
  }

  Future<void> _handleNativeReminderAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (action == 'openSchedule') {
      if (mounted) {
        setState(() {
          _activeTab = AppTab.schedule;
        });
      }
      return;
    }

    final batchId = (payload['batchId'] as String?)?.trim() ?? '';
    String? matchedTimeSlot;
    Prescription? firstUntakenPrescription;

    for (final prescription in _prescriptions) {
      for (final time in prescription.reminderTimes) {
        final slotBatchId = batchIdForTimeSlot(time);
        if (batchId.isEmpty || slotBatchId == batchId) {
          matchedTimeSlot ??= time;
          final alreadyTaken = prescription.takenTimes.any(
            (t) => isSameTimeSlot(t, time),
          );
          final isSkipped =
              _skippedSlotKeys.contains('${prescription.id}_$time');
          if (!alreadyTaken && !isSkipped && firstUntakenPrescription == null) {
            firstUntakenPrescription = prescription;
            matchedTimeSlot = time;
          }
        }
      }
    }

    if (action == 'cancelSnooze') {
      final targetBatchId = batchId.isNotEmpty
          ? batchId
          : (matchedTimeSlot != null ? batchIdForTimeSlot(matchedTimeSlot) : '');
      if (targetBatchId.isNotEmpty) {
        await _liveReminderService.dismissActivity(batchId: targetBatchId);
      }
      if (matchedTimeSlot != null) {
        await _notifications.cancelSnoozeNotification(matchedTimeSlot);
      }
      unawaited(_syncNotifications());
      return;
    }

    if (action == 'logTaken') {
      if (firstUntakenPrescription != null && matchedTimeSlot != null) {
        _handleTakeDose(firstUntakenPrescription.id, matchedTimeSlot);
      } else if (batchId.isNotEmpty) {
        await _liveReminderService.dismissActivity(batchId: batchId);
      }
    } else if (action == 'snooze' && matchedTimeSlot != null) {
      if (payload['alreadyActive'] == true) {
        // Snooze acknowledged while an active countdown is already running;
        // let the existing countdown continue running undisturbed.
        return;
      }
      await _notifications.handleReminderSnooze(
        matchedTimeSlot,
        prescriptions: _prescriptions,
        profiles: _profiles,
        snoozeDurationMinutes: _snoozeSettingsService.snoozeDurationMinutes,
        bypassBedtime: _bedtimeService.isPausedAt(),
      );
      unawaited(_syncNotifications());
    }
  }

  String _todaySkippedKey() {
    final now = DateTime.now();
    return 'pillpal_skipped_${now.year}_${now.month}_${now.day}';
  }

  void _rolloverSkippedIfNewDay() {
    final todayKey = _todaySkippedKey();
    if (_skippedDateKey.isNotEmpty && _skippedDateKey != todayKey) {
      setState(() {
        _skippedSlotKeys.clear();
        _skippedDateKey = todayKey;
      });
      unawaited(_syncNotifications());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _rolloverSkippedIfNewDay();
      unawaited(_bedtimeService.clearExpiredPause());
      unawaited(_snoozeSettingsService.clearExpiredBedtimeBypass());
    }
  }

  Future<void> _loadSkippedSlotKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _todaySkippedKey();
      _skippedDateKey = todayKey;
      final list = prefs.getStringList(todayKey) ?? [];
      if (mounted && list.isNotEmpty) {
        setState(() {
          _skippedSlotKeys.addAll(list);
        });
        unawaited(_syncNotifications());
      }
    } catch (_) {}
  }

  Future<void> _persistSkippedSlotKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _todaySkippedKey();
      _skippedDateKey = todayKey;
      await prefs.setStringList(todayKey, _skippedSlotKeys.toList());
    } catch (_) {}
  }

  /// Writes a `DoseEvent` only when a dose actually gets marked taken --
  /// toggling it back off is treated as undoing a mis-tap, not a loggable
  /// "skipped" event, so the history feed reflects real doses taken.
  /// [time] is which of the prescription's (possibly several) reminder
  /// times was acted on.
  void _handleTakeDose(String id, String time) {
    final slotKey = '${id}_$time';
    if (_skippedSlotKeys.contains(slotKey)) {
      setState(() {
        _skippedSlotKeys.remove(slotKey);
      });
      unawaited(_persistSkippedSlotKeys());
    }

    final item = _prescriptions.firstWhere((p) => p.id == id);
    final willBeTaken = !item.takenTimes.contains(time);

    final Prescription updated;
    if (willBeTaken) {
      final newRemaining = (item.remaining - 1).clamp(0, 9999);
      final newDays = (item.daysSupply - 1).clamp(0, 9999);
      updated = item.copyWith(
        takenTimes: {...item.takenTimes, time},
        remaining: newRemaining,
        daysSupply: newDays,
      );
      if (newRemaining <= 1) {
        _showRefillDialog(item.name);
      }
    } else {
      updated = item.copyWith(
        takenTimes: item.takenTimes.difference({time}),
        remaining: (item.remaining + 1).clamp(0, 9999),
        daysSupply: (item.daysSupply + 1).clamp(0, 9999),
      );
    }

    _db.upsertPrescription(updated);
    final updatedList = [
      for (final p in _prescriptions) p.id == updated.id ? updated : p,
    ];
    unawaited(_syncTimeSlotLiveReminder(time, updatedList));
    if (willBeTaken) {
      final now = DateTime.now();
      final scheduledTod = parseTimeOfDayLabel(time);
      var action = DoseAction.taken;
      if (scheduledTod != null) {
        final scheduledToday = DateTime(
          now.year,
          now.month,
          now.day,
          scheduledTod.hour,
          scheduledTod.minute,
        );
        if (now.isAfter(scheduledToday.add(const Duration(hours: 2)))) {
          action = DoseAction.late;
        }
      }

      if (_retentionService.retentionDays > 0) {
        _db.insertDoseEvent(DoseEvent(
          id: '${id}_${now.microsecondsSinceEpoch}',
          prescriptionId: id,
          profileId: item.profileId,
          occurredAt: now,
          action: action,
        ));
      }
    }
  }

  Future<void> _handleSkipDose(String id, String time) async {
    HapticFeedback.lightImpact();
    final item = _prescriptions.firstWhere((p) => p.id == id);
    final slotKey = '${id}_$time';
    final wasSkipped = _skippedSlotKeys.contains(slotKey);

    if (wasSkipped) {
      setState(() {
        _skippedSlotKeys.remove(slotKey);
      });
      await _persistSkippedSlotKeys();
      unawaited(_syncTimeSlotLiveReminder(time, _prescriptions));
      unawaited(_syncNotifications());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored ${item.name} for $time'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _rolloverSkippedIfNewDay();
    setState(() {
      _skippedSlotKeys.add(slotKey);
    });
    await _persistSkippedSlotKeys();

    final now = DateTime.now();
    if (_retentionService.retentionDays > 0) {
      await _db.insertDoseEvent(DoseEvent(
        id: '${id}_${now.microsecondsSinceEpoch}',
        prescriptionId: id,
        profileId: item.profileId,
        occurredAt: now,
        action: DoseAction.skipped,
      ));
    }

    if (item.takenTimes.contains(time)) {
      final updated = item.copyWith(
        takenTimes: item.takenTimes.difference({time}),
        remaining: (item.remaining + 1).clamp(0, 9999),
        daysSupply: (item.daysSupply + 1).clamp(0, 9999),
      );
      await _db.upsertPrescription(updated);
    }

    unawaited(_syncTimeSlotLiveReminder(time, _prescriptions));
    unawaited(_syncNotifications());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Skipped ${item.name} for $time'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<T?> _showPlatformActionDialog<T>({
    Key? key,
    required String title,
    required String content,
    required List<({String label, T value, bool isDefault})> actions,
  }) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS) {
      return showCupertinoDialog<T>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          key: key,
          title: Text(title),
          content: Text(content),
          actions: [
            for (final action in actions)
              CupertinoDialogAction(
                isDefaultAction: action.isDefault,
                onPressed: () => Navigator.pop(ctx, action.value),
                child: Text(action.label),
              ),
          ],
        ),
      );
    }

    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: key,
        title: Text(title),
        content: Text(content),
        actions: [
          for (final action in actions)
            TextButton(
              onPressed: () => Navigator.pop(ctx, action.value),
              child: Text(
                action.label,
                style: TextStyle(
                  fontWeight:
                      action.isDefault ? FontWeight.w700 : FontWeight.w500,
                  color: action.isDefault ? context.colors.teal : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleSnoozeDose(String id, String time) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final mins = _snoozeSettingsService.snoozeDurationMinutes;

    // 1. Guard premature snooze if the scheduled slot is still > 30 min away.
    final leadTime = timeUntilScheduledSlot(now: now, timeSlot: time);
    if (leadTime != null && leadTime > const Duration(minutes: 30)) {
      final proceed = await _showPlatformActionDialog<bool>(
        key: const Key('early_snooze_dialog'),
        title: 'Not Due Yet',
        content: 'Your $time dose isn\'t scheduled for another '
            '${formatLeadTimeDuration(leadTime)}. Start a $mins-minute '
            'reminder countdown now anyway?',
        actions: [
          (label: 'Cancel', value: false, isDefault: false),
          (label: 'Start ${mins}m Countdown', value: true, isDefault: true),
        ],
      );
      if (proceed != true || !mounted) return;
    }

    // 2. Contextual bedtime quiet-hours prompt when snoozing near or during quiet hours.
    var bypassForThisSnooze = _bedtimeService.isPausedAt(now);
    final activeQuietWindow = _bedtimeService.activeQuietWindow(now: now);
    final nextQuietWindow = _bedtimeService.nextQuietWindow(now: now);
    final bedtimeLabel =
        activeQuietWindow?.window.bedtime ?? nextQuietWindow?.window.bedtime;

    if (!bypassForThisSnooze && _bedtimeService.isEnabled) {
      final clamped = _bedtimeService.clampSnoozeMinutes(
        now: now,
        requestedMinutes: mins,
      );
      if (clamped <= 0) {
        final pauseTonight = await _showPlatformActionDialog<bool>(
          key: const Key('bedtime_snooze_dialog'),
          title: 'Bedtime Quiet Hours Active',
          content:
              'Bedtime quiet hours are active right now. Pause quiet hours for '
              'tonight (auto-resumes at your next bedtime) to start a '
              '$mins-minute snooze?',
          actions: [
            (label: 'Cancel', value: false, isDefault: false),
            (label: 'Pause Tonight', value: true, isDefault: true),
          ],
        );
        if (pauseTonight != true || !mounted) return;
        await _bedtimeService.pauseTonight(now: now);
        bypassForThisSnooze = true;
      } else if (clamped < mins && bedtimeLabel != null) {
        final choice = await _showPlatformActionDialog<_BedtimeSnoozeChoice>(
          key: const Key('bedtime_snooze_dialog'),
          title: 'Reaches Bedtime ($bedtimeLabel)',
          content: 'A $mins-minute snooze goes past your $bedtimeLabel '
              'bedtime. You can end the timer at bedtime (when Final Call '
              'takes over) or pause quiet hours for tonight.',
          actions: [
            (
              label: 'Pause Tonight',
              value: _BedtimeSnoozeChoice.pauseTonight,
              isDefault: true,
            ),
            (
              label: 'End at $bedtimeLabel (${clamped}m)',
              value: _BedtimeSnoozeChoice.clampToBedtime,
              isDefault: false,
            ),
            (
              label: 'Cancel',
              value: _BedtimeSnoozeChoice.cancel,
              isDefault: false,
            ),
          ],
        );
        if (choice == null ||
            choice == _BedtimeSnoozeChoice.cancel ||
            !mounted) {
          return;
        }
        if (choice == _BedtimeSnoozeChoice.pauseTonight) {
          await _bedtimeService.pauseTonight(now: now);
          bypassForThisSnooze = true;
        }
      }
    }

    // 3. Start two-phase Live Activity and schedule the dedicated Snooze push alert.
    final batch = await _liveReminderService.startSnoozeForTimeSlot(
      timeSlot: time,
      prescriptions: _prescriptions,
      profiles: _profiles,
      skippedSlotKeys: _skippedSlotKeys,
      bypassBedtime: bypassForThisSnooze,
    );
    final outcome = _liveReminderService.lastStartOutcome;

    if (outcome?.snoozeEndTime != null &&
        batch.remainingDosesCount > 0 &&
        (outcome!.status == SnoozeStartStatus.started ||
            outcome.status == SnoozeStartStatus.liveActivitiesDisabled ||
            outcome.status == SnoozeStartStatus.failed)) {
      await _notifications.scheduleSnoozeNotification(
        timeSlot: time,
        fireAt: outcome.snoozeEndTime!,
        remainingCount: batch.remainingDosesCount,
        profileName: batch.profileName,
      );
      unawaited(_syncNotifications());
    }

    if (!mounted) return;
    final effectiveMins =
        (outcome != null && outcome.effectiveDurationMinutes > 0)
            ? outcome.effectiveDurationMinutes
            : mins;
    final unit = effectiveMins == 1 ? 'minute' : 'minutes';

    final String message;
    switch (outcome?.status) {
      case SnoozeStartStatus.liveActivitiesDisabled:
        message =
            'Snoozed for $effectiveMins $unit — enable Live Activities in iOS Settings for Dynamic Island.';
      case SnoozeStartStatus.failed:
        message =
            'Snooze reminder set for $effectiveMins $unit (Live Activity unavailable).';
      case SnoozeStartStatus.blockedByBedtime:
        message =
            'Past bedtime quiet hours — Final Call handles evening reminders.';
      case SnoozeStartStatus.noPendingDoses:
        message = 'All doses for $time are already handled.';
      case SnoozeStartStatus.started:
      case null:
        message = (outcome?.clampedToBedtime ?? false) && bedtimeLabel != null
            ? 'Snoozed $time reminder until $bedtimeLabel'
            : 'Snoozed $time reminder for $effectiveMins $unit';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRefillDialog(String medName) {
    if (Platform.isAndroid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Refill Required'),
          content: Text('You just took the last dose of $medName!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: TextStyle(color: context.colors.teal)),
            ),
          ],
        ),
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Refill Required'),
        content: Text('You just took the last dose of $medName!'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _handleDeleteMedication(String id) {
    final deleted = _prescriptions.where((p) => p.id == id).toList();
    final remaining = _prescriptions.where((p) => p.id != id).toList();
    _db.deletePrescription(id);
    for (final med in deleted) {
      for (final slot in med.reminderTimes) {
        unawaited(_syncTimeSlotLiveReminder(slot, remaining));
      }
    }
  }

  /// [targets] is (prescriptionId, time) pairs -- a prescription with
  /// several reminder times can have some targeted and others left alone.
  void _handleToggleAllCompleted(
      List<(String, String)> targets, bool shouldMarkTaken) {
    for (final item in _prescriptions) {
      final times =
          targets.where((t) => t.$1 == item.id).map((t) => t.$2).toSet();
      if (times.isEmpty) continue;

      final toMark = shouldMarkTaken
          ? times.difference(item.takenTimes)
          : times.intersection(item.takenTimes);
      if (toMark.isEmpty) continue;

      if (shouldMarkTaken) {
        final newRemaining = (item.remaining - toMark.length).clamp(0, 9999);
        final newDays = (item.daysSupply - toMark.length).clamp(0, 9999);
        _db.upsertPrescription(item.copyWith(
          takenTimes: {...item.takenTimes, ...toMark},
          remaining: newRemaining,
          daysSupply: newDays,
        ));
        for (final time in toMark) {
          final now = DateTime.now();
          final scheduledTod = parseTimeOfDayLabel(time);
          var action = DoseAction.taken;
          if (scheduledTod != null) {
            final scheduledToday = DateTime(
              now.year,
              now.month,
              now.day,
              scheduledTod.hour,
              scheduledTod.minute,
            );
            if (now.isAfter(scheduledToday.add(const Duration(hours: 2)))) {
              action = DoseAction.late;
            }
          }
          if (_retentionService.retentionDays > 0) {
            _db.insertDoseEvent(DoseEvent(
              id: '${item.id}_${time}_${now.microsecondsSinceEpoch}',
              prescriptionId: item.id,
              profileId: item.profileId,
              occurredAt: now,
              action: action,
            ));
          }
        }
      } else {
        _db.upsertPrescription(item.copyWith(
          takenTimes: item.takenTimes.difference(toMark),
          remaining: (item.remaining + toMark.length).clamp(0, 9999),
          daysSupply: (item.daysSupply + toMark.length).clamp(0, 9999),
        ));
      }
    }

    final affectedTimeSlots = targets.map((t) => t.$2).toSet();
    final updatedPrescriptions = _prescriptions.map((item) {
      final times =
          targets.where((t) => t.$1 == item.id).map((t) => t.$2).toSet();
      if (times.isEmpty) return item;
      return item.copyWith(
        takenTimes: shouldMarkTaken
            ? {...item.takenTimes, ...times}
            : item.takenTimes.difference(times),
      );
    }).toList();
    for (final slot in affectedTimeSlots) {
      unawaited(_syncTimeSlotLiveReminder(slot, updatedPrescriptions));
    }
  }

  Future<void> _openScan() async {
    final mode = await _showAddMedsPopover();
    if (mode == null || !mounted) return;

    if (mode == _AddMedsMode.manual) {
      final prescription = await ConfirmScreen.show(
        context,
        extraction: null,
        profiles: _profiles,
        isManual: true,
      );
      if (prescription != null && mounted) {
        await _db.upsertPrescription(prescription);
      }
      return;
    }

    setState(() => _isScanning = true);
    Extraction? extraction;
    if (mode == _AddMedsMode.live) {
      extraction = await Navigator.of(context).push<Extraction>(
        MaterialPageRoute(
          builder: (_) => const LiveScanScreen(),
        ),
      );
    } else {
      try {
        extraction = await pickAndExtractFromPhoto(
          context,
          onProcessingChanged: (processing) {
            if (mounted) {
              setState(() => _isProcessingPhoto = processing);
            }
          },
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isProcessingPhoto = false;
            _isScanning = false;
          });
          await showCupertinoDialog<void>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Photo Scan Failed'),
              content: Text(e.toString()),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;

    if (extraction == null) {
      setState(() {
        _isProcessingPhoto = false;
        _isScanning = false;
      });
      return;
    }

    final isManual = extraction.rawText.isEmpty && extraction.drug == null;
    final prescription = await ConfirmScreen.show(
      context,
      extraction: isManual ? null : extraction,
      profiles: _profiles,
      isManual: isManual,
    );
    if (!mounted) return;
    setState(() {
      _isProcessingPhoto = false;
      _isScanning = false;
    });

    if (prescription != null) {
      await _db.upsertPrescription(prescription);
    }
  }

  Future<_AddMedsMode?> _showAddMedsPopover() async {
    final RenderBox? buttonBox =
        _scanButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final buttonOffset = buttonBox?.localToGlobal(Offset.zero);
    final buttonSize = buttonBox?.size;

    return showGeneralDialog<_AddMedsMode>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Add Meds',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final c = context.colors;
        final screenSize = MediaQuery.of(dialogContext).size;

        final double top = buttonOffset != null
            ? (buttonOffset.dy + (buttonSize?.height ?? 34) + 8)
            : 110.0;
        final double right = buttonOffset != null
            ? (screenSize.width - (buttonOffset.dx + (buttonSize?.width ?? 110)))
            : 20.0;

        return Stack(
          children: [
            Positioned(
              top: top,
              right: right.clamp(16.0, screenSize.width - 240.0),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      width: 240,
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: c.borderLight.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 28,
                            spreadRadius: -2,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPopoverItem(
                            context: dialogContext,
                            icon: CupertinoIcons.camera,
                            label: 'Scan Bottle',
                            onTap: () => Navigator.pop(dialogContext, _AddMedsMode.live),
                          ),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: c.borderLight.withValues(alpha: 0.6),
                          ),
                          _buildPopoverItem(
                            context: dialogContext,
                            icon: CupertinoIcons.photo_on_rectangle,
                            label: 'Import from Photos',
                            onTap: () => Navigator.pop(dialogContext, _AddMedsMode.upload),
                          ),
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: c.borderLight.withValues(alpha: 0.6),
                          ),
                          _buildPopoverItem(
                            context: dialogContext,
                            icon: CupertinoIcons.square_pencil,
                            label: 'Enter Manually',
                            onTap: () => Navigator.pop(dialogContext, _AddMedsMode.manual),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildPopoverItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: c.ink.withValues(alpha: 0.06),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: c.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                icon,
                size: 20,
                color: c.ink.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleEditMedication(Prescription prescription) {
    MedicationDetailSheet.show(
      context,
      prescription: prescription,
      profiles: _profiles,
      onUpdate: _handleUpdateMedication,
      onDelete: () => _handleDeleteMedication(prescription.id),
    );
  }

  /// Schedule-tab tap target: a low, read-only quick look, not the full
  /// editable sheet -- its own edit button hands off to
  /// [_handleEditMedication] for that.
  void _handleViewMedication(Prescription prescription) {
    MedicationQuickViewSheet.show(
      context,
      prescription: prescription,
      profiles: _profiles,
      onEdit: () => _handleEditMedication(prescription),
    );
  }

  void _handleViewMedicationSlot(Prescription prescription, String time) {
    final slotKey = '${prescription.id}_$time';
    MedicationQuickViewSheet.show(
      context,
      prescription: prescription,
      profiles: _profiles,
      timeSlot: time,
      isTaken: prescription.takenTimes.contains(time),
      isSkipped: _skippedSlotKeys.contains(slotKey),
      onEdit: () => _handleEditMedication(prescription),
      onSnooze: () => _handleSnoozeDose(prescription.id, time),
      onSkip: () => _handleSkipDose(prescription.id, time),
    );
  }

  void _onWalkthroughStateChanged() {
    if (!mounted) return;
    _maybeLaunchPostOnboardingWalkthrough();
    setState(() {});
  }

  void _maybeLaunchPostOnboardingWalkthrough() {
    if (!mounted || _isShowingWalkthrough) return;
    if (_activeTab != AppTab.schedule) return;
    if (_walkthroughService.hasSeenMainFeedTour) return;
    if (!_walkthroughService.shouldTriggerPostOnboardingTour) return;
    if (!_hasReceivedPrescriptionStream && _prescriptions.isEmpty) return;

    _isShowingWalkthrough = true;
    _walkthroughService.consumePostOnboardingTrigger();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isShowingWalkthrough = false;
        return;
      }
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) {
        _isShowingWalkthrough = false;
        return;
      }

      final List<WalkthroughStep> steps;
      if (_prescriptions.isNotEmpty) {
        steps = <WalkthroughStep>[
          WalkthroughStep(
            targetKey: _firstMedCardKey,
            title: 'Your Daily Timeline',
            description:
                'Tap any medication card to expand dose details, or use the check ring and swipe actions to log or edit routines.',
            icon: CupertinoIcons.calendar_today,
            borderRadius: 18.0,
          ),
          WalkthroughStep(
            targetKey: _profileSwitcherKey,
            targetKeys: _profileChipKeys,
            title: 'CareRecipient Switcher',
            description:
                'Switch views or filter daily schedules between yourself and family care recipients in one tap.',
            icon: CupertinoIcons.person_2_fill,
            borderRadius: 20.0,
          ),
          WalkthroughStep(
            targetKey: _scanButtonKey,
            title: 'Quick-Scan More Bottles',
            description:
                'Tap + Scan Bottle anytime to scan additional prescription labels with live on-device OCR.',
            icon: CupertinoIcons.camera_fill,
            borderRadius: 20.0,
          ),
        ];
      } else {
        steps = <WalkthroughStep>[
          WalkthroughStep(
            targetKey: _scanButtonKey,
            title: 'Add Your First Medication',
            description:
                'Tap + Scan Bottle anytime to scan your prescription label with instant on-device OCR.',
            icon: CupertinoIcons.camera_fill,
            borderRadius: 20.0,
          ),
          WalkthroughStep(
            targetKey: _profileSwitcherKey,
            targetKeys: _profileChipKeys,
            title: 'CareRecipient Switcher',
            description:
                'Switch views or filter daily schedules between yourself and family care recipients in one tap.',
            icon: CupertinoIcons.person_2_fill,
            borderRadius: 20.0,
          ),
          WalkthroughStep(
            targetKey: _emptyScheduleKey,
            title: 'Your Daily Timeline',
            description:
                'Once you add medications, your doses, scheduled times, and daily check-ins will appear right here.',
            icon: CupertinoIcons.calendar_today,
            borderRadius: 24.0,
          ),
        ];
      }

      _walkthroughOverlayEntry = WalkthroughOverlay.show(
        context: context,
        steps: steps,
        onStepChanged: (idx) {
          if (idx == 1) {
            unawaited(_walkthroughService.markProfileSwitchHintSeen());
          } else if (idx == 2) {
            unawaited(_walkthroughService.markScannerTipSeen());
          }
        },
        onComplete: () {
          _isShowingWalkthrough = false;
          _walkthroughOverlayEntry = null;
          unawaited(_walkthroughService.markMainFeedTourSeen());
          unawaited(widget.appStateManager?.setTourSeen(schedule: true));
        },
        onSkip: () {
          _isShowingWalkthrough = false;
          _walkthroughOverlayEntry = null;
          unawaited(_walkthroughService.markMainFeedTourSeen());
          unawaited(widget.appStateManager?.setTourSeen(schedule: true));
        },
      );
    });
  }

  List<WidgetBuilder> get _tabBuilders => [
    (context) => KeyedSubtree(
      key: const ValueKey('screen_schedule'),
      child: ScheduleScreen(
        prescriptions: _prescriptions,
        profiles: _profiles,
        selectedProfileId: _selectedProfileId,
        onSelectProfile: (id) => setState(() => _selectedProfileId = id),
        onTakeDose: _handleTakeDose,
        onSnoozeDose: _handleSnoozeDose,
        onSkipDose: _handleSkipDose,
        skippedSlotKeys: _skippedSlotKeys,
        onViewMedication: _handleViewMedication,
        onViewSlot: _handleViewMedicationSlot,
        onEditMedication: _handleEditMedication,
        onDeleteMedication: _handleDeleteMedication,
        onToggleAllCompleted: _handleToggleAllCompleted,
        onOpenScan: _openScan,
        isScanning: _isScanning,
        isActive: _activeTab == AppTab.schedule && !_isShowingWalkthrough,
        firstMedCardKey: _firstMedCardKey,
        profileSwitcherKey: _profileSwitcherKey,
        profileChipKeys: _profileChipKeys,
        scanButtonKey: _scanButtonKey,
        emptyScheduleKey: _emptyScheduleKey,
      ),
    ),
    (context) => KeyedSubtree(
      key: const ValueKey('screen_meds'),
      child: ProfilesScreen(
        isActive: _activeTab == AppTab.meds,
        profiles: _profiles,
        prescriptions: _prescriptions,
        doseEvents: _doseEvents,
        onEditMedication: _handleEditMedication,
        retentionService: _retentionService,
        database: _db,
        walkthroughService: _walkthroughService,
      ),
    ),
    (context) => KeyedSubtree(
      key: const ValueKey('screen_profile'),
      child: AccountScreen(
        isActive: _activeTab == AppTab.profile,
        profiles: _profiles,
        prescriptions: _prescriptions,
        onUpdateProfile: _handleUpdateProfile,
        onDeleteProfile: _handleDeleteProfile,
        notificationService: _notifications,
        themeController: widget.themeController,
        liquidGlassController: _liquidGlassController,
        appLock: widget.appLock ?? widget.appStateManager?.appLockService,
        doseEvents: _doseEvents,
        retentionService: _retentionService,
        snoozeSettingsService: _snoozeSettingsService,
        bedtimeService: _bedtimeService,
        database: _db,
        walkthroughService: _walkthroughService,
      ),
    ),
  ];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_walkthroughOverlayEntry?.mounted ?? false) {
      _walkthroughOverlayEntry?.remove();
    }
    _walkthroughOverlayEntry = null;
    _walkthroughService.removeListener(_onWalkthroughStateChanged);
    _snoozeSettingsService.removeListener(_onSnoozeSettingsChanged);
    _bedtimeService.removeListener(_onBedtimeSettingsChanged);
    if (_ownsBedtimeService) {
      _bedtimeService.dispose();
    }
    widget.appStateManager?.removeListener(_onAppStateChanged);
    if (NotificationService.onLogAllTaken == _handleLogAllTakenForTimeSlot) {
      NotificationService.onLogAllTaken = null;
    }
    _profilesSub?.cancel();
    _prescriptionsSub?.cancel();
    _doseEventsSub?.cancel();
    if (widget.database == null) {
      _db.close();
    }
    super.dispose();
  }

  int get _activeTabIndex {
    switch (_activeTab) {
      case AppTab.schedule:
        return 0;
      case AppTab.meds:
        return 1;
      case AppTab.profile:
        return 2;
    }
  }

  void _handleTabPress(AppTab tab) {
    if (_activeTab == tab) return;
    if (_isShowingWalkthrough && _walkthroughOverlayEntry != null) {
      if (_walkthroughOverlayEntry?.mounted ?? false) {
        _walkthroughOverlayEntry?.remove();
      }
      _walkthroughOverlayEntry = null;
      _isShowingWalkthrough = false;
    }
    setState(() => _activeTab = tab);
  }

  void _onAndroidNavDestinationSelected(int index) {
    switch (index) {
      case 0:
        _handleTabPress(AppTab.schedule);
        break;
      case 1:
        _handleTabPress(AppTab.meds);
        break;
      case 2:
        _handleTabPress(AppTab.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBarsStyle(Theme.of(context).brightness),
      child: Stack(
        children: [
          _buildShell(context),
          if (_isProcessingPhoto) const ReadingLabelOverlay(),
        ],
      ),
    );
  }

  /// Status-bar icons follow the theme (dark icons in Light, light icons in
  /// Dark); the hidden nav bar keeps its scrim + light icons in both. Set
  /// here per theme rather than once in main(), which left dark icons on a
  /// dark screen.
  SystemUiOverlayStyle _systemBarsStyle(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: context.colors.navScrim,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: true,
    );
  }

  Widget _buildShell(BuildContext context) {
    final activeBody = KeepAliveTabStack(
      selectedIndex: _activeTabIndex,
      builders: _tabBuilders,
    );

    // Native Full-Width Sliding Bar on Android
    if (Platform.isAndroid) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          bottom: false,
          child: activeBody,
        ),
        bottomNavigationBar: AndroidSlidingBottomBar(
          selectedIndex: _activeTabIndex,
          onTabSelected: _onAndroidNavDestinationSelected,
        ),
      );
    }

    // Pre-iOS 26 or home-button iPhones (no Liquid Glass): classic docked iOS tab bar.
    // Content scrolls underneath it, as with a stock UITabBar; each tab's
    // existing bottom padding already clears the bar.
    if (currentIOSDesignEra(context) == IOSDesignEra.classic) {
      return Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: activeBody,
        ),
        bottomNavigationBar: ClassicIOSTabBar(
          activeTab: _activeTab,
          onTabPress: _handleTabPress,
        ),
      );
    }

    // Default iOS Floating Frosted Pill Dock (iOS 26+ Liquid Glass)
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: activeBody,
          ),
          FloatingTabBar(
            activeTab: _activeTab,
            onTabPress: _handleTabPress,
            controller: _liquidGlassController,
          ),

        ],
      ),
    );
  }
}
