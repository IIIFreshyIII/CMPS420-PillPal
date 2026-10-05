import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import 'widgets/medication_card.dart';

/// One reminder-time instance of a prescription -- a prescription with
/// several `reminderTimes` (e.g. "every 4 hours") shows up as one slot per
/// time, each independently markable taken.
typedef ScheduleSlot = ({Prescription prescription, String time});

class ScheduleScreen extends StatelessWidget {
  final List<Prescription> prescriptions;
  final List<Profile> profiles;
  final String selectedProfileId;
  final ValueChanged<String> onSelectProfile;
  final void Function(String prescriptionId, String time) onTakeDose;
  final ValueChanged<Prescription> onViewMedication;
  final void Function(List<(String, String)> targets, bool shouldMarkTaken) onToggleAllCompleted;
  final VoidCallback onOpenScan;
  final bool isScanning;

  const ScheduleScreen({
    super.key,
    required this.prescriptions,
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelectProfile,
    required this.onTakeDose,
    required this.onViewMedication,
    required this.onToggleAllCompleted,
    required this.onOpenScan,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    final filteredMeds = selectedProfileId == 'all'
        ? prescriptions
        : prescriptions.where((m) => m.profileId == selectedProfileId).toList();

    final slots = filteredMeds
        .expand((m) => m.reminderTimes.map((t) => (prescription: m, time: t)))
        .toList()
      ..sort((a, b) {
        final ta = parseTimeOfDayLabel(a.time);
        final tb = parseTimeOfDayLabel(b.time);
        if (ta == null || tb == null) return 0;
        return (ta.hour * 60 + ta.minute).compareTo(tb.hour * 60 + tb.minute);
      });

    final morningSlots = slots.where((s) => s.time.contains('AM')).toList();
    final eveningSlots = slots.where((s) => s.time.contains('PM')).toList();

    final totalDoses = slots.length;
    final takenDoses = slots.where((s) => s.prescription.takenTimes.contains(s.time)).length;
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${timeOfDayGreeting()},',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      profiles
                          .firstWhere(
                            (p) => p.isPrimary,
                            orElse: () => const Profile(id: '0', name: 'there', color: Colors.grey),
                          )
                          .name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatFullDate(),
                      style: const TextStyle(
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
                              final targets = slots.map((s) => (s.prescription.id, s.time)).toList();
                              onToggleAllCompleted(targets, !allDone);
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
        if (morningSlots.isNotEmpty) ...[
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
                (context, i) => _slotCard(morningSlots[i]),
                childCount: morningSlots.length,
              ),
            ),
          ),
        ],
        if (eveningSlots.isNotEmpty) ...[
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
                (context, i) => _slotCard(eveningSlots[i]),
                childCount: eveningSlots.length,
              ),
            ),
          ),
        ],
        if (slots.isEmpty) const SliverToBoxAdapter(child: _EmptySchedule()),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _slotCard(ScheduleSlot slot) {
    return MedicationCard(
      key: ValueKey('med_${slot.prescription.id}_${slot.time}'),
      item: slot.prescription,
      time: slot.time,
      isTaken: slot.prescription.takenTimes.contains(slot.time),
      profile: profiles.firstWhere((p) => p.id == slot.prescription.profileId),
      onTakeDose: () => onTakeDose(slot.prescription.id, slot.time),
      onViewDetails: () => onViewMedication(slot.prescription),
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

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.checkmark_seal, color: AppTheme.textSecondary.withValues(alpha: 0.4), size: 40),
            const SizedBox(height: 12),
            const Text(
              'Nothing due right now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Scan a bottle to add a medication.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
