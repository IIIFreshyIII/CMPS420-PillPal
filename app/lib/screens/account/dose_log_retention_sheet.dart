import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/dose_event.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/data_retention_service.dart';

class DoseLogRetentionSheet extends StatefulWidget {
  final DataRetentionService retentionService;
  final List<DoseEvent> doseEvents;
  final List<Prescription> prescriptions;
  final List<Profile> profiles;
  final AppDatabase? database;

  const DoseLogRetentionSheet({
    super.key,
    required this.retentionService,
    required this.doseEvents,
    required this.prescriptions,
    required this.profiles,
    this.database,
  });

  static Future<void> show(
    BuildContext context, {
    required DataRetentionService retentionService,
    required List<DoseEvent> doseEvents,
    required List<Prescription> prescriptions,
    required List<Profile> profiles,
    AppDatabase? database,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DoseLogRetentionSheet(
        retentionService: retentionService,
        doseEvents: doseEvents,
        prescriptions: prescriptions,
        profiles: profiles,
        database: database,
      ),
    );
  }

  @override
  State<DoseLogRetentionSheet> createState() => _DoseLogRetentionSheetState();
}

class _DoseLogRetentionSheetState extends State<DoseLogRetentionSheet> {
  late int _selectedDays;
  bool _isPurging = false;

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.retentionService.retentionDays;
  }

  Future<void> _handleSelectDays(int days) async {
    setState(() => _selectedDays = days);
    await widget.retentionService.setRetentionDays(days);
  }

  Future<void> _handleExport() async {
    await widget.retentionService.exportAndShareCsv(
      events: widget.doseEvents,
      prescriptions: widget.prescriptions,
      profiles: widget.profiles,
    );
  }

  Future<void> _handlePurgeExpired() async {
    if (widget.database == null) return;

    final expired = widget.retentionService.getExpiredEvents(
      widget.doseEvents,
      customDays: _selectedDays,
    );

    if (expired.isEmpty) return;

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Purge Expired Dose Logs?'),
        content: Text(
          'This will permanently delete ${expired.length} dose logs older than ${DataRetentionService.retentionLabel(_selectedDays)} from this device.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Purge Now'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isPurging = true);
    final count = await widget.retentionService.purgeExpired(
      widget.database!,
      customDays: _selectedDays,
    );
    if (!mounted) return;
    setState(() => _isPurging = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Purged $count expired dose logs.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final expired = widget.retentionService.getExpiredEvents(
      widget.doseEvents,
      customDays: _selectedDays,
    );

    DateTime? oldestDate;
    if (widget.doseEvents.isNotEmpty) {
      oldestDate = widget.doseEvents.last.occurredAt;
      for (final e in widget.doseEvents) {
        if (e.occurredAt.isBefore(oldestDate!)) {
          oldestDate = e.occurredAt;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: c.grabber,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dose Log Retention',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.4,
                ),
              ),
              IconButton(
                icon: Icon(CupertinoIcons.xmark_circle_fill,
                    color: c.inkMuted.withValues(alpha: 0.5)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'PillPal stores dose tracking logs locally on your device for up to a year by default. After 1 year, records can be exported or purged to reclaim device storage.',
            style: TextStyle(
              fontSize: 13,
              color: c.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Retention options
          Text(
            'KEEP LOGS FOR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: c.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.borderLight),
            ),
            child: Column(
              children: DataRetentionService.presetOptions.map((days) {
                final isSelected = _selectedDays == days;
                final label = DataRetentionService.retentionLabel(days);
                return InkWell(
                  onTap: () => _handleSelectDays(days),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? c.tealDeep : c.ink,
                          ),
                        ),
                        if (isSelected)
                          Icon(CupertinoIcons.checkmark_alt,
                              color: c.tealDeep, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Storage stats card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.tint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.mint.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  c,
                  title: 'Total Logs',
                  value: '${widget.doseEvents.length}',
                ),
                _buildStatItem(
                  c,
                  title: 'Oldest Log',
                  value: oldestDate != null
                      ? '${oldestDate.month}/${oldestDate.day}/${oldestDate.year.toString().substring(2)}'
                      : 'None',
                ),
                _buildStatItem(
                  c,
                  title: 'Expired Logs',
                  value: '${expired.length}',
                  alert: expired.isNotEmpty,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Actions: Export & Purge
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      widget.doseEvents.isEmpty ? null : _handleExport,
                  icon: const Icon(CupertinoIcons.share, size: 16),
                  label: const Text('Export (.csv)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.tealDeep,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: c.teal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (expired.isNotEmpty && widget.database != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPurging ? null : _handlePurgeExpired,
                    icon: _isPurging
                        ? const CupertinoActivityIndicator()
                        : const Icon(CupertinoIcons.trash, size: 16),
                    label: const Text('Purge Expired'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.alert,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildStatItem(
    PillPalColors c, {
    required String title,
    required String value,
    bool alert = false,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: alert ? c.alert : c.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(fontSize: 11, color: c.inkMuted),
        ),
      ],
    );
  }
}
