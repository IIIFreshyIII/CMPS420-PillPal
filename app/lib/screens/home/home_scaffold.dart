import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import '../../presentation/widgets/android_sliding_bottom_bar.dart';

enum _ScanMode { live, upload }

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key, this.database});

  /// Injectable for tests (an in-memory `AppDatabase`); production always
  /// uses the default on-disk database created in `initState`.
  final AppDatabase? database;

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  AppTab _activeTab = AppTab.schedule;
  String _selectedProfileId = 'all';
  bool _isScanning = false;

  late final AppDatabase _db;
  late final NotificationService _notifications;
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

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? AppDatabase();
    _notifications = NotificationService();
    _db.seedIfEmpty(_seedProfiles, _seedPrescriptions);
    _profilesSub = _db.watchProfiles().listen((rows) {
      if (mounted) setState(() => _profiles = rows);
      _syncNotifications();
    });
    _prescriptionsSub = _db.watchPrescriptions().listen((rows) {
      if (mounted) setState(() => _prescriptions = rows);
      _syncNotifications();
    });
    _doseEventsSub = _db.watchDoseEvents().listen((rows) {
      if (mounted) setState(() => _doseEvents = rows);
    });
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
    if (willBeTaken) {
      _db.insertDoseEvent(DoseEvent(
        id: '${id}_${DateTime.now().microsecondsSinceEpoch}',
        prescriptionId: id,
        profileId: item.profileId,
        occurredAt: DateTime.now(),
        action: DoseAction.taken,
      ));
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
              child:
                  const Text('OK', style: TextStyle(color: Color(0xFF168B87))),
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
  void _handleToggleAllCompleted(List<(String, String)> targets, bool shouldMarkTaken) {
    for (final item in _prescriptions) {
      final times = targets.where((t) => t.$1 == item.id).map((t) => t.$2).toSet();
      if (times.isEmpty) continue;

      final toMark = shouldMarkTaken ? times.difference(item.takenTimes) : times.intersection(item.takenTimes);
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
          _db.insertDoseEvent(DoseEvent(
            id: '${item.id}_${time}_${DateTime.now().microsecondsSinceEpoch}',
            prescriptionId: item.id,
            profileId: item.profileId,
            occurredAt: DateTime.now(),
            action: DoseAction.taken,
          ));
        }
      } else {
        _db.upsertPrescription(item.copyWith(
          takenTimes: item.takenTimes.difference(toMark),
          remaining: (item.remaining + toMark.length).clamp(0, 9999),
          daysSupply: (item.daysSupply + toMark.length).clamp(0, 9999),
        ));
      }
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

  Widget _buildActiveScreen() {
    switch (_activeTab) {
      case AppTab.schedule:
        return KeyedSubtree(
          key: const ValueKey('screen_schedule'),
          child: ScheduleScreen(
            prescriptions: _prescriptions,
            profiles: _profiles,
            selectedProfileId: _selectedProfileId,
            onSelectProfile: (id) => setState(() => _selectedProfileId = id),
            onTakeDose: _handleTakeDose,
            onViewMedication: _handleViewMedication,
            onToggleAllCompleted: _handleToggleAllCompleted,
            onOpenScan: _openScan,
            isScanning: _isScanning,
          ),
        );
      case AppTab.meds:
        return KeyedSubtree(
          key: const ValueKey('screen_meds'),
          child: ProfilesScreen(
            profiles: _profiles,
            prescriptions: _prescriptions,
            doseEvents: _doseEvents,
            onEditMedication: _handleEditMedication,
          ),
        );
      case AppTab.profile:
        return KeyedSubtree(
          key: const ValueKey('screen_profile'),
          child: AccountScreen(
            profiles: _profiles,
            prescriptions: _prescriptions,
            onUpdateProfile: _handleUpdateProfile,
            onDeleteProfile: _handleDeleteProfile,
            notificationService: _notifications,
          ),
        );
    }
  }

  @override
  void dispose() {
    _profilesSub?.cancel();
    _prescriptionsSub?.cancel();
    _doseEventsSub?.cancel();
    _db.close();
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
    final activeBody = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildActiveScreen(),
    );

    // Native Full-Width Sliding Bar on Android
    if (Platform.isAndroid) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFA),
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

    // Default iOS Floating Frosted Pill Dock
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
          ),
        ],
      ),
    );
  }
}
