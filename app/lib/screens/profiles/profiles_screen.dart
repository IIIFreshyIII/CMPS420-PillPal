import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/pillpal_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/dose_event.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';

/// The "Meds" tab: a reverse-chronological log of doses actually taken,
/// grouped by day -- distinct from Schedule (today's doses, with actions)
/// rather than duplicating it with a second inventory list.
class ProfilesScreen extends StatelessWidget {
  final List<Profile> profiles;
  final List<Prescription> prescriptions;
  final List<DoseEvent> doseEvents;
  final ValueChanged<Prescription> onEditMedication;

  const ProfilesScreen({
    super.key,
    required this.profiles,
    required this.prescriptions,
    required this.doseEvents,
    required this.onEditMedication,
  });

  Profile _profileFor(String id) {
    return profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => const Profile(id: '0', name: 'General', color: Colors.grey),
    );
  }

  Prescription? _prescriptionFor(String id) {
    for (final p in prescriptions) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Groups events by calendar day, preserving the reverse-chronological
  /// order the database stream already provides.
  Map<String, List<DoseEvent>> _groupByDay() {
    final grouped = <String, List<DoseEvent>>{};
    for (final event in doseEvents) {
      final label = formatDayLabel(event.occurredAt);
      grouped.putIfAbsent(label, () => []).add(event);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final todayCount = doseEvents
        .where((e) => isToday(e.occurredAt) && e.action == DoseAction.taken)
        .length;
    final grouped = _groupByDay();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  decoration: BoxDecoration(
                    color: c.tint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$todayCount Today',
                    style: TextStyle(
                      color: c.tealDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: doseEvents.isEmpty
                  ? _EmptyHistory()
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 120),
                      children: [
                        for (final dayLabel in grouped.keys) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: Text(
                              dayLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: c.inkMuted,
                              ),
                            ),
                          ),
                          for (final event in grouped[dayLabel]!)
                            _DoseHistoryRow(
                              event: event,
                              prescription:
                                  _prescriptionFor(event.prescriptionId),
                              profile: _profileFor(event.profileId),
                              onTap: () {
                                final med =
                                    _prescriptionFor(event.prescriptionId);
                                if (med != null) onEditMedication(med);
                              },
                            ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.clock,
                color: c.inkMuted.withValues(alpha: 0.4), size: 40),
            const SizedBox(height: 12),
            Text(
              'No doses logged yet',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: c.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Mark a dose taken from Schedule and it will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseHistoryRow extends StatelessWidget {
  const _DoseHistoryRow({
    required this.event,
    required this.prescription,
    required this.profile,
    required this.onTap,
  });

  final DoseEvent event;
  final Prescription? prescription;
  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final medName = prescription?.name ?? 'Deleted medication';
    final verb = event.action == DoseAction.taken ? 'Took' : 'Skipped';

    return GestureDetector(
      onTap: prescription == null ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.borderLight),
          boxShadow: [
            BoxShadow(
              color: c.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: profile.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                event.action == DoseAction.taken
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.xmark,
                color: profile.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$verb $medName',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (prescription != null)
                        Text(
                          prescription!.dosage,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.inkMuted,
                          ),
                        ),
                      if (prescription != null) const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 6),
                        decoration: BoxDecoration(
                          color: profile.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          profile.name,
                          style: TextStyle(
                            color: c.tagText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              formatTimeOfDay(event.occurredAt),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
