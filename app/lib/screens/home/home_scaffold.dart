import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../presentation/widgets/floating_tab_bar.dart';
import '../account/account_screen.dart';
import '../profiles/profiles_screen.dart';
import '../schedule/schedule_screen.dart';
import '../medication_detail/medication_detail_sheet.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  AppTab _activeTab = AppTab.schedule;
  String _selectedProfileId = 'all';
  bool _isScanning = false;

  void _handleUpdateMedication(Prescription updated) {
    setState(() {
      _prescriptions = _prescriptions.map((m) => m.id == updated.id ? updated : m).toList();
    });
  }

  final List<Profile> _profiles = const [
    Profile(id: '1', name: 'Me', color: Color(0xFF3B82F6), isPrimary: true),
    Profile(id: '2', name: 'Mom', color: Color(0xFF8B5CF6)),
  ];

  List<Prescription> _prescriptions = [
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

  void _handleTakeDose(String id) {
    setState(() {
      _prescriptions = _prescriptions.map((item) {
        if (item.id == id) {
          final willBeTaken = !item.takenToday;

          if (willBeTaken) {
            final newRemaining = (item.remaining - 1).clamp(0, 9999);
            final newDays = (item.daysSupply - 1).clamp(0, 9999);

            if (newRemaining <= 1) {
              _showRefillDialog(item.name);
            }

            return item.copyWith(
              takenToday: true,
              remaining: newRemaining,
              daysSupply: newDays,
            );
          } else {
            return item.copyWith(
              takenToday: false,
              remaining: (item.remaining + 1).clamp(0, 9999),
              daysSupply: (item.daysSupply + 1).clamp(0, 9999),
            );
          }
        }
        return item;
      }).toList();
    });
  }

  void _showRefillDialog(String medName) {
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
    setState(() {
      _prescriptions = _prescriptions.where((m) => m.id != id).toList();
    });
  }

  void _handleToggleAllCompleted(List<String> targetIds, bool shouldMarkTaken) {
    setState(() {
      _prescriptions = _prescriptions.map((item) {
        if (targetIds.contains(item.id)) {
          if (shouldMarkTaken && !item.takenToday) {
            final newRemaining = (item.remaining - 1).clamp(0, 9999);
            final newDays = (item.daysSupply - 1).clamp(0, 9999);
            return item.copyWith(
              takenToday: true,
              remaining: newRemaining,
              daysSupply: newDays,
            );
          } else if (!shouldMarkTaken && item.takenToday) {
            return item.copyWith(
              takenToday: false,
              remaining: (item.remaining + 1).clamp(0, 9999),
              daysSupply: (item.daysSupply + 1).clamp(0, 9999),
            );
          }
        }
        return item;
      }).toList();
    });
  }

  Future<void> _simulateScan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _isScanning = false);

    final newMed = Prescription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Amoxicillin',
      dosage: '500mg',
      time: '8:00 AM',
      daysSupply: 10,
      remaining: 10,
      profileId: '1',
    );

    setState(() {
      _prescriptions.insert(0, newMed);
    });
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
            onOpenScan: _simulateScan,
            isScanning: _isScanning,
          ),
        );
      case AppTab.meds:
        return KeyedSubtree(
          key: const ValueKey('screen_meds'),
          child: ProfilesScreen(
            profiles: _profiles,
            prescriptions: _prescriptions,
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: _buildActiveScreen(),
            ),
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