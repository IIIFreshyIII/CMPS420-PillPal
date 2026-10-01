import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/local/app_database.dart';
import '../../data/models/dose_event.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/extractor.dart';
import '../../presentation/widgets/floating_tab_bar.dart';
import '../account/account_screen.dart';
import '../confirm/confirm_screen.dart';
import '../profiles/profiles_screen.dart';
import '../scan/live_scan_screen.dart';
import '../scan/upload_scan_screen.dart';
import '../schedule/schedule_screen.dart';
import '../medication_detail/medication_detail_sheet.dart';
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
      time: '8:00 AM',
      daysSupply: 14,
      remaining: 14,
      profileId: '1',
    ),
    Prescription(
      id: '2',
      name: 'Lisinopril',
      dosage: '20mg',
      time: '8:00 AM',
      daysSupply: 4,
      remaining: 4,
      profileId: '2',
    ),
    Prescription(
      id: '3',
      name: 'Metformin',
      dosage: '500mg',
      time: '12:00 PM',
      daysSupply: 28,
      remaining: 28,
      profileId: '2',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? AppDatabase();
    _db.seedIfEmpty(_seedProfiles, _seedPrescriptions);
    _profilesSub = _db.watchProfiles().listen((rows) {
      if (mounted) setState(() => _profiles = rows);
    });
    _prescriptionsSub = _db.watchPrescriptions().listen((rows) {
      if (mounted) setState(() => _prescriptions = rows);
    });
    _doseEventsSub = _db.watchDoseEvents().listen((rows) {
      if (mounted) setState(() => _doseEvents = rows);
    });
  }

  void _handleUpdateMedication(Prescription updated) {
    _db.upsertPrescription(updated);
  }

  /// Writes a `DoseEvent` only when a dose actually gets marked taken --
  /// toggling it back off is treated as undoing a mis-tap, not a loggable
  /// "skipped" event, so the history feed reflects real doses taken.
  void _handleTakeDose(String id) {
    final item = _prescriptions.firstWhere((p) => p.id == id);
    final willBeTaken = !item.takenToday;

    final Prescription updated;
    if (willBeTaken) {
      final newRemaining = (item.remaining - 1).clamp(0, 9999);
      final newDays = (item.daysSupply - 1).clamp(0, 9999);
      updated = item.copyWith(takenToday: true, remaining: newRemaining, daysSupply: newDays);
      if (newRemaining <= 1) {
        _showRefillDialog(item.name);
      }
    } else {
      updated = item.copyWith(
        takenToday: false,
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
              child: const Text('OK', style: TextStyle(color: Color(0xFF168B87))),
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

  void _handleToggleAllCompleted(List<String> targetIds, bool shouldMarkTaken) {
    for (final item in _prescriptions) {
      if (!targetIds.contains(item.id)) continue;

      if (shouldMarkTaken && !item.takenToday) {
        final newRemaining = (item.remaining - 1).clamp(0, 9999);
        final newDays = (item.daysSupply - 1).clamp(0, 9999);
        _db.upsertPrescription(item.copyWith(
          takenToday: true,
          remaining: newRemaining,
          daysSupply: newDays,
        ));
        _db.insertDoseEvent(DoseEvent(
          id: '${item.id}_${DateTime.now().microsecondsSinceEpoch}',
          prescriptionId: item.id,
          profileId: item.profileId,
          occurredAt: DateTime.now(),
          action: DoseAction.taken,
        ));
      } else if (!shouldMarkTaken && item.takenToday) {
        _db.upsertPrescription(item.copyWith(
          takenToday: false,
          remaining: (item.remaining + 1).clamp(0, 9999),
          daysSupply: (item.daysSupply + 1).clamp(0, 9999),
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
        builder: (_) => mode == _ScanMode.live ? const LiveScanScreen() : const UploadScanScreen(),
      ),
    );
    if (!mounted) return;

    if (extraction == null) {
      setState(() => _isScanning = false);
      return;
    }

    final prescription = await ConfirmScreen.show(context, extraction: extraction, profiles: _profiles);
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
            onDeleteMedication: _handleDeleteMedication,
            onEditMedication: _handleEditMedication,
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
        return const KeyedSubtree(
          key: ValueKey('screen_profile'),
          child: AccountScreen(),
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