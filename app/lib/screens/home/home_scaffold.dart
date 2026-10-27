import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../services/live_reminder_service.dart';
import '../../services/walkthrough_service.dart';
import '../../ui/widgets/walkthrough_overlay.dart';

enum _ScanMode { live, upload }

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
  final LiveReminderService? liveReminderService;
  final AppTab initialTab;


  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  late AppTab _activeTab;
  String _selectedProfileId = 'all';
  bool _isScanning = false;
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

  late final AppDatabase _db;
  late final NotificationService _notifications;
  late final DataRetentionService _retentionService;
  late final LiquidGlassController _liquidGlassController;
  late final WalkthroughService _walkthroughService;
  late final SnoozeSettingsService _snoozeSettingsService;
  late final LiveReminderService _liveReminderService;
  bool _notificationPermissionsRequested = false;
  StreamSubscription<List<Profile>>? _profilesSub;
  StreamSubscription<List<Prescription>>? _prescriptionsSub;
  StreamSubscription<List<DoseEvent>>? _doseEventsSub;

  List<Profile> _profiles = const [];
  List<Prescription> _prescriptions = const [];
  List<DoseEvent> _doseEvents = const [];


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
    _notifications = NotificationService();
    _retentionService = DataRetentionService();
    _liquidGlassController =
        widget.liquidGlassController ?? LiquidGlassController();
    _walkthroughService = widget.walkthroughService ??
        widget.appStateManager?.walkthroughService ??
        WalkthroughService();
    _snoozeSettingsService =
        widget.snoozeSettingsService ?? SnoozeSettingsService();
    _liveReminderService = widget.liveReminderService ??
        LiveReminderService(snoozeSettings: _snoozeSettingsService);
    _liveReminderService.onNativeAction = _handleNativeReminderAction;
    _liveReminderService.registerNativeCallbackHandler();
    if (!_walkthroughService.isLoaded) {
      unawaited(_walkthroughService.load());
    }
    if (!_snoozeSettingsService.isLoaded) {
      unawaited(_snoozeSettingsService.load());
    }
    unawaited(_retentionService.load());
    unawaited(IOSAccessibilityService.instance.updateAccessibilitySettings());

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
      if (mounted) {
        setState(() => _profiles = _applySeedFilterProfiles(rows));
        _maybeLaunchPostOnboardingWalkthrough();
      }
      _syncNotifications();
    }, onError: (e) {
      debugPrint('Error watching profiles: $e');
    });
    _prescriptionsSub = _db.watchPrescriptions().listen((rows) {
      if (mounted) {
        setState(() => _prescriptions = _applySeedFilterPrescriptions(rows));
        _maybeLaunchPostOnboardingWalkthrough();
      }
      _syncNotifications();
    }, onError: (e) {
      debugPrint('Error watching prescriptions: $e');
    });
    _doseEventsSub = _db.watchDoseEvents().listen((rows) {
      if (mounted) setState(() => _doseEvents = _applySeedFilterDoseEvents(rows));
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
      await _notifications.syncAll(_prescriptions, _profiles);
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
          if (!alreadyTaken && firstUntakenPrescription == null) {
            firstUntakenPrescription = prescription;
            matchedTimeSlot = time;
          }
        }
      }
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
      await _liveReminderService.startSnoozeForTimeSlot(
        timeSlot: matchedTimeSlot,
        prescriptions: _prescriptions,
        profiles: _profiles,
      );
    }
  }

  /// Writes a `DoseEvent` only when a dose actually gets marked taken --
  /// toggling it back off is treated as undoing a mis-tap, not a loggable
  /// "skipped" event, so the history feed reflects real doses taken.
  /// [time] is which of the prescription's (possibly several) reminder
  /// times was acted on.
  void _handleTakeDose(String id, String time) {
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
    unawaited(_liveReminderService.syncTimeSlotDoses(
      timeSlot: time,
      prescriptions: updatedList,
      profiles: _profiles,
    ));
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
    _db.deletePrescription(id);
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
      unawaited(_liveReminderService.syncTimeSlotDoses(
        timeSlot: slot,
        prescriptions: updatedPrescriptions,
        profiles: _profiles,
      ));
    }
  }

  Future<void> _openScan() async {
    final mode = await showModalBottomSheet<_ScanMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Scan Live'),
              subtitle: const Text('Pan the camera over the label'),
              onTap: () => Navigator.pop(ctx, _ScanMode.live),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Enter from a Photo'),
              subtitle: const Text("If you don't have the bottle in hand"),
              onTap: () => Navigator.pop(ctx, _ScanMode.upload),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;

    setState(() => _isScanning = true);
    final extraction = await Navigator.of(context).push<Extraction>(
      MaterialPageRoute(
        builder: (_) => mode == _ScanMode.live
            ? const LiveScanScreen()
            : const UploadScanScreen(),
      ),
    );
    if (!mounted) return;

    if (extraction == null) {
      setState(() => _isScanning = false);
      return;
    }

    final prescription = await ConfirmScreen.show(context,
        extraction: extraction, profiles: _profiles);
    if (!mounted) return;
    setState(() => _isScanning = false);

    if (prescription != null) {
      _db.upsertPrescription(prescription);
    }
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
    if (_prescriptions.isEmpty) return;

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

      final steps = <WalkthroughStep>[
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
        onViewMedication: _handleViewMedication,
        onEditMedication: _handleEditMedication,
        onDeleteMedication: _handleDeleteMedication,
        onToggleAllCompleted: _handleToggleAllCompleted,
        onOpenScan: _openScan,
        isScanning: _isScanning,
        firstMedCardKey: _firstMedCardKey,
        profileSwitcherKey: _profileSwitcherKey,
        profileChipKeys: _profileChipKeys,
        scanButtonKey: _scanButtonKey,
      ),
    ),
    (context) => KeyedSubtree(
      key: const ValueKey('screen_meds'),
      child: ProfilesScreen(
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
        database: _db,
        walkthroughService: _walkthroughService,
      ),
    ),
  ];

  @override
  void dispose() {
    if (_walkthroughOverlayEntry?.mounted ?? false) {
      _walkthroughOverlayEntry?.remove();
    }
    _walkthroughOverlayEntry = null;
    _walkthroughService.removeListener(_onWalkthroughStateChanged);
    widget.appStateManager?.removeListener(_onAppStateChanged);
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

  void _onAndroidNavDestinationSelected(int index) {
    setState(() {
      switch (index) {
        case 0:
          _activeTab = AppTab.schedule;
          break;
        case 1:
          _activeTab = AppTab.meds;
          break;
        case 2:
          _activeTab = AppTab.profile;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBarsStyle(Theme.of(context).brightness),
      child: _buildShell(context),
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
          onTabPress: (tab) => setState(() => _activeTab = tab),
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
            onTabPress: (tab) => setState(() => _activeTab = tab),
            controller: _liquidGlassController,
          ),

        ],
      ),
    );
  }
}
