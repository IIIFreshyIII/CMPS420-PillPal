import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/dose_event.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/data_retention_service.dart';
import '../../presentation/widgets/profile_chip.dart';

/// Dedicated sub-page displaying the complete day-by-day history log of all
/// taken and skipped medication doses, filterable by profile with CSV export.
class DoseHistoryScreen extends StatefulWidget {
  final List<Profile> profiles;
  final List<Prescription> prescriptions;
  final List<DoseEvent> doseEvents;
  final ValueChanged<Prescription> onEditMedication;
  final DataRetentionService? retentionService;

  const DoseHistoryScreen({
    super.key,
    required this.profiles,
    required this.prescriptions,
    required this.doseEvents,
    required this.onEditMedication,
    this.retentionService,
  });

  @override
  State<DoseHistoryScreen> createState() => _DoseHistoryScreenState();
}

class _DoseHistoryScreenState extends State<DoseHistoryScreen> {
  String _selectedProfileId = 'all';

  Profile _profileFor(String id) {
    return widget.profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => const Profile(id: '0', name: 'General', color: Colors.grey),
    );
  }

  Prescription? _prescriptionFor(String id) {
    for (final p in widget.prescriptions) {
      if (p.id == id) return p;
    }
    return null;
  }

  Map<String, List<DoseEvent>> _groupByDay(List<DoseEvent> events) {
    final grouped = <String, List<DoseEvent>>{};
    for (final event in events) {
      final label = formatDayLabel(event.occurredAt);
      grouped.putIfAbsent(label, () => []).add(event);
    }
    return grouped;
  }

  void _exportHistory() {
    final service = widget.retentionService ?? DataRetentionService();
    service.exportAndShareCsv(
      events: widget.doseEvents,
      prescriptions: widget.prescriptions,
      profiles: widget.profiles,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final filteredEvents = _selectedProfileId == 'all'
        ? widget.doseEvents
        : widget.doseEvents
            .where((e) => e.profileId == _selectedProfileId)
            .toList();

    final grouped = _groupByDay(filteredEvents);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Platform.isIOS ? CupertinoIcons.chevron_back : Icons.arrow_back,
            color: c.ink,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Dose History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        actions: [
          if (widget.doseEvents.isNotEmpty)
            IconButton(
              icon: Icon(
                Platform.isIOS
                    ? CupertinoIcons.share
                    : Icons.share_outlined,
                color: c.tealDeep,
              ),
              tooltip: 'Export CSV',
              onPressed: _exportHistory,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Profile filter pills if multiple profiles exist
            if (widget.profiles.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    ProfileChip(
                      label: 'All Profiles',
                      isSelected: _selectedProfileId == 'all',
                      selectedColor: c.teal,
                      onTap: () => setState(() => _selectedProfileId = 'all'),
                    ),
                    for (final profile in widget.profiles)
                      ProfileChip(
                        label: profile.name,
                        isSelected: _selectedProfileId == profile.id,
                        selectedColor: profile.color,
                        onTap: () =>
                            setState(() => _selectedProfileId = profile.id),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Content list
            Expanded(
              child: filteredEvents.isEmpty
                  ? _buildEmptyState(c)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                      children: [
                        for (final dayLabel in grouped.keys) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 12),
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
                            _buildHistoryRow(
                              context,
                              event: event,
                              prescription:
                                  _prescriptionFor(event.prescriptionId),
                              profile: _profileFor(event.profileId),
                            ),
                        ],
                        const SizedBox(height: 24),
                        // Storage retention info footer
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.borderLight),
                          ),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.archivebox,
                                  size: 20, color: c.inkMuted),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Logs are kept on your device for up to 1 year by default. You can adjust retention in Settings.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.inkMuted,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(
    BuildContext context, {
    required DoseEvent event,
    required Prescription? prescription,
    required Profile profile,
  }) {
    final c = context.colors;
    final medName = prescription?.name ?? 'Deleted medication';

    final String verb;
    final IconData statusIcon;
    final Color iconColor;

    switch (event.action) {
      case DoseAction.taken:
        verb = 'Took';
        statusIcon = CupertinoIcons.checkmark_alt;
        iconColor = profile.color;
        break;
      case DoseAction.late:
        verb = 'Took Late';
        statusIcon = CupertinoIcons.clock_fill;
        iconColor = c.profileAmber;
        break;
      case DoseAction.skipped:
        verb = 'Skipped';
        statusIcon = CupertinoIcons.xmark;
        iconColor = c.alert;
        break;
    }

    return GestureDetector(
      onTap: () {
        if (prescription != null) {
          widget.onEditMedication(prescription);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: iconColor, size: 20),
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
                      if (prescription != null) ...[
                        Text(
                          prescription.dosage,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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

  Widget _buildEmptyState(PillPalColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.clock,
                color: c.inkMuted.withValues(alpha: 0.4), size: 48),
            const SizedBox(height: 16),
            Text(
              'No dose logs found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mark scheduled doses taken or skipped from Schedule to build your history.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.inkMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
