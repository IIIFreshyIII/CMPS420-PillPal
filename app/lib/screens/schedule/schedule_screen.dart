import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import 'widgets/medication_card.dart';

class ScheduleScreen extends StatelessWidget {
  final List<Prescription> prescriptions;
  final List<Profile> profiles;
  final String selectedProfileId;
  final ValueChanged<String> onSelectProfile;
  final ValueChanged<String> onTakeDose;
  final ValueChanged<String> onDeleteMedication;
  final ValueChanged<Prescription> onEditMedication;
  final void Function(List<String> targetIds, bool shouldMarkTaken) onToggleAllCompleted;
  final VoidCallback onOpenScan;
  final bool isScanning;

  const ScheduleScreen({
    super.key,
    required this.prescriptions,
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelectProfile,
    required this.onTakeDose,
    required this.onDeleteMedication,
    required this.onEditMedication,
    required this.onToggleAllCompleted,
    required this.onOpenScan,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    final filteredMeds = selectedProfileId == 'all'
        ? prescriptions
        : prescriptions.where((m) => m.profileId == selectedProfileId).toList();

    final morningMeds = filteredMeds.where((m) => m.time.contains('AM')).toList();
    final eveningMeds = filteredMeds.where((m) => m.time.contains('PM')).toList();

    final totalDoses = filteredMeds.length;
    final takenDoses = filteredMeds.where((m) => m.takenToday).length;
    final allDone = totalDoses > 0 && takenDoses == totalDoses;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            decoration: const BoxDecoration(
              color: AppTheme.headerTeal,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning,',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Cade',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Wednesday, September 2',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: isScanning ? null : onOpenScan,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 15),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textPrimary.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.interactiveTeal,
                            ),
                          )
                        : const Row(
                            children: [
                              Icon(CupertinoIcons.camera, size: 16, color: AppTheme.interactiveTeal),
                              SizedBox(width: 6),
                              Text(
                                '+ Scan Bottle',
                                style: TextStyle(
                                  color: AppTheme.interactiveTeal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Schedule",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Row(
                      children: [
                        if (totalDoses > 0)
                          GestureDetector(
                            onTap: () {
                              final ids = filteredMeds.map((m) => m.id).toList();
                              onToggleAllCompleted(ids, !allDone);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              decoration: BoxDecoration(
                                color: allDone ? const Color(0xFFE2E8F0) : AppTheme.interactiveTeal,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    allDone ? CupertinoIcons.arrow_counterclockwise : CupertinoIcons.checkmark_alt,
                                    size: 13,
                                    color: allDone ? const Color(0xFF475569) : Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    allDone ? 'Reset' : 'Mark All',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: allDone ? const Color(0xFF475569) : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.lightPillTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '$takenDoses of $totalDoses',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.interactiveTeal,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ProfileChip(
                        label: 'All',
                        isSelected: selectedProfileId == 'all',
                        onTap: () => onSelectProfile('all'),
                      ),
                      ...profiles.map((p) {
                        final isSelected = selectedProfileId == p.id;
                        return _ProfileChip(
                          label: '${p.name}${p.isPrimary ? ' (Me)' : ''}',
                          isSelected: isSelected,
                          onTap: () => onSelectProfile(p.id),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (morningMeds.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'MORNING',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => MedicationCard(
                  key: ValueKey('med_${morningMeds[i].id}'),
                  item: morningMeds[i],
                  profile: profiles.firstWhere((p) => p.id == morningMeds[i].profileId),
                  onTakeDose: () => onTakeDose(morningMeds[i].id),
                  onDelete: () => onDeleteMedication(morningMeds[i].id),
                  onEdit: () => onEditMedication(morningMeds[i]),
                ),
                childCount: morningMeds.length,
              ),
            ),
          ),
        ],
        if (eveningMeds.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                'AFTERNOON & EVENING',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => MedicationCard(
                  key: ValueKey('med_${eveningMeds[i].id}'),
                  item: eveningMeds[i],
                  profile: profiles.firstWhere((p) => p.id == eveningMeds[i].profileId),
                  onTakeDose: () => onTakeDose(eveningMeds[i].id),
                  onDelete: () => onDeleteMedication(eveningMeds[i].id),
                  onEdit: () => onEditMedication(eveningMeds[i]),
                ),
                childCount: eveningMeds.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.textPrimary : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppTheme.textPrimary : const Color(0xFFE2ECEB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}