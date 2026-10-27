import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/dose_event.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/data_retention_service.dart';
import '../../presentation/widgets/profile_chip.dart';
import '../../services/walkthrough_service.dart';
import '../../ui/widgets/walkthrough_overlay.dart';
import 'dose_history_screen.dart';
import 'widgets/adherence_graph_card.dart';
import 'widgets/saved_medication_card.dart';

/// The "Meds" tab: displays the user's logging consistency graph (on-time,
/// late, and skipped adherence rates over time), an entry into the full
/// historical dose timeline sub-page, and the full inventory of saved
/// medications below the graph with tap-to-edit capability.
class ProfilesScreen extends StatefulWidget {
  final List<Profile> profiles;
  final List<Prescription> prescriptions;
  final List<DoseEvent> doseEvents;
  final ValueChanged<Prescription> onEditMedication;
  final DataRetentionService? retentionService;
  final AppDatabase? database;
  final WalkthroughService? walkthroughService;

  const ProfilesScreen({
    super.key,
    required this.profiles,
    required this.prescriptions,
    required this.doseEvents,
    required this.onEditMedication,
    this.retentionService,
    this.database,
    this.walkthroughService,
  });

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  String _selectedProfileId = 'all';
  bool _dismissedPurgeBanner = false;

  final GlobalKey _adherenceGraphKey =
      GlobalKey(debugLabel: 'walkthrough_meds_graph');
  final GlobalKey _medsListKey = GlobalKey(debugLabel: 'walkthrough_meds_list');
  final GlobalKey _firstMedCardKey =
      GlobalKey(debugLabel: 'walkthrough_meds_first_card');

  bool _isShowingWalkthrough = false;
  OverlayEntry? _walkthroughOverlayEntry;

  @override
  void initState() {
    super.initState();
    widget.walkthroughService?.addListener(_onWalkthroughServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLaunchMedsWalkthrough();
    });
  }

  @override
  void didUpdateWidget(ProfilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.walkthroughService != oldWidget.walkthroughService) {
      oldWidget.walkthroughService
          ?.removeListener(_onWalkthroughServiceChanged);
      widget.walkthroughService?.addListener(_onWalkthroughServiceChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLaunchMedsWalkthrough();
    });
  }

  @override
  void dispose() {
    widget.walkthroughService?.removeListener(_onWalkthroughServiceChanged);
    if (_walkthroughOverlayEntry?.mounted ?? false) {
      _walkthroughOverlayEntry?.remove();
    }
    _walkthroughOverlayEntry = null;
    super.dispose();
  }

  void _onWalkthroughServiceChanged() {
    if (!mounted) return;
    _maybeLaunchMedsWalkthrough();
  }

  void _maybeLaunchMedsWalkthrough() {
    if (!mounted || _isShowingWalkthrough) return;
    final service = widget.walkthroughService;
    if (service == null) return;
    if (service.hasSeenHistoryHint) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _isShowingWalkthrough = true;

    final steps = <WalkthroughStep>[
      WalkthroughStep(
        targetKey: _adherenceGraphKey,
        title: 'Adherence & Consistency',
        description:
            'Track your 7-day on-time, late, and skipped logging consistency across all active medications.',
        icon: CupertinoIcons.chart_bar_alt_fill,
        borderRadius: 24.0,
      ),
      WalkthroughStep(
        targetKey: _medsListKey,
        title: 'Saved Medications',
        description:
            'Review your active prescriptions, dosage amounts, and schedules grouped by care recipient.',
        icon: CupertinoIcons.capsule_fill,
        borderRadius: 20.0,
      ),
      WalkthroughStep(
        targetKey:
            widget.prescriptions.isNotEmpty ? _firstMedCardKey : _medsListKey,
        title: 'Tap to Edit Schedules',
        description:
            'Tap any medication card anytime to adjust reminder times, supply counts, or refill thresholds.',
        icon: CupertinoIcons.pencil_ellipsis_rectangle,
        borderRadius: 18.0,
      ),
    ];

    _walkthroughOverlayEntry = WalkthroughOverlay.show(
      context: context,
      steps: steps,
      onComplete: () {
        _isShowingWalkthrough = false;
        _walkthroughOverlayEntry = null;
        unawaited(service.markHistoryHintSeen());
      },
      onSkip: () {
        _isShowingWalkthrough = false;
        _walkthroughOverlayEntry = null;
        unawaited(service.markHistoryHintSeen());
      },
    );
  }

  Profile _profileFor(String id) {
    return widget.profiles.firstWhere(
      (p) => p.id == id,
      orElse: () => const Profile(id: '0', name: 'General', color: Colors.grey),
    );
  }

  void _openDoseHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoseHistoryScreen(
          profiles: widget.profiles,
          prescriptions: widget.prescriptions,
          doseEvents: widget.doseEvents,
          onEditMedication: widget.onEditMedication,
          retentionService: widget.retentionService,
        ),
      ),
    );
  }

  Future<void> _handlePurgeExpired(List<DoseEvent> expired) async {
    if (widget.database == null) return;
    final service = widget.retentionService ?? DataRetentionService();

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Purge Expired Dose Logs?'),
        content: Text(
          'This will permanently delete ${expired.length} dose logs older than 1 year to reclaim device storage.',
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

    final count = await service.purgeExpired(widget.database!);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Purged $count expired dose logs.')),
    );
    setState(() => _dismissedPurgeBanner = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final retentionService = widget.retentionService ?? DataRetentionService();
    final expiredEvents = retentionService.getExpiredEvents(widget.doseEvents);

    final showPurgeBanner =
        expiredEvents.isNotEmpty && !_dismissedPurgeBanner;

    // Filter prescriptions if specific profile is selected
    final visiblePrescriptions = _selectedProfileId == 'all'
        ? widget.prescriptions
        : widget.prescriptions
            .where((p) => p.profileId == _selectedProfileId)
            .toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          // Header Row: Title & Active Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meds',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: c.tint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.capsule_fill,
                      size: 13,
                      color: c.tealDeep,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${widget.prescriptions.length} Active',
                      style: TextStyle(
                        color: c.tealDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Profile Filter if multiple profiles exist
          if (widget.profiles.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ProfileChip(
                    label: 'All',
                    isSelected: _selectedProfileId == 'all',
                    selectedColor: c.teal,
                    onTap: () => setState(() => _selectedProfileId = 'all'),
                  ),
                  for (final profile in widget.profiles)
                    ProfileChip(
                      label: profile.isPrimary
                          ? (profile.name.toLowerCase() == 'me'
                              ? 'Me'
                              : '${profile.name} (Me)')
                          : profile.name,
                      isSelected: _selectedProfileId == profile.id,
                      selectedColor: profile.color,
                      onTap: () =>
                          setState(() => _selectedProfileId = profile.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Purge notification banner if data older than 1 year exists
          if (showPurgeBanner) ...[
            _buildPurgeBanner(context, expiredEvents),
            const SizedBox(height: 14),
          ],

          // 1. Logging Consistency & Adherence Graph Card
          AdherenceGraphCard(
            targetKey: _adherenceGraphKey,
            doseEvents: widget.doseEvents,
            selectedProfileId: _selectedProfileId,
          ),

          // 2. Full Dose History Log Entry Tile
          GestureDetector(
            onTap: _openDoseHistory,
            child: Container(
              margin: const EdgeInsets.only(bottom: 22),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
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
                      color: c.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.clock_fill,
                        color: c.tealDeep,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dose History Log',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'View complete day-by-day record of doses',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.doseEvents.length} Logged',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: c.inkMuted,
                  ),
                ],
              ),
            ),
          ),

          // 3. Saved Medications Section Header + List
          KeyedSubtree(
            key: _medsListKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SAVED MEDICATIONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: c.inkMuted,
                      ),
                    ),
                    Text(
                      '${visiblePrescriptions.length} Meds',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visiblePrescriptions.isEmpty)
                  _buildEmptyMeds(c)
                else
                  for (int i = 0; i < visiblePrescriptions.length; i++)
                    SavedMedicationCard(
                      targetKey: i == 0 ? _firstMedCardKey : null,
                      prescription: visiblePrescriptions[i],
                      profile: _profileFor(visiblePrescriptions[i].profileId),
                      showProfileBadge: widget.profiles.length > 1,
                      onTap: () =>
                          widget.onEditMedication(visiblePrescriptions[i]),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPurgeBanner(BuildContext context, List<DoseEvent> expired) {
    final c = context.colors;
    final service = widget.retentionService ?? DataRetentionService();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.alertTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.alert.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.archivebox_fill, size: 20, color: c.alert),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '1-Year History Cleanup Notice',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.alert,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _dismissedPurgeBanner = true),
                child: Icon(CupertinoIcons.xmark, size: 16, color: c.alert),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You have ${expired.length} dose logs older than 1 year ready for cleanup. You can export a backup or purge to free storage.',
            style: TextStyle(fontSize: 12, color: c.ink, height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => service.exportAndShareCsv(
                  events: widget.doseEvents,
                  prescriptions: widget.prescriptions,
                  profiles: widget.profiles,
                ),
                icon: const Icon(CupertinoIcons.share, size: 14),
                label: const Text('Export Backup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.surface,
                  foregroundColor: c.ink,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: c.borderLight),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _handlePurgeExpired(expired),
                child: Text(
                  'Purge Logs',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.alert,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMeds(PillPalColors c) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.borderLight),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(CupertinoIcons.capsule,
                size: 36, color: c.inkMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(
              'No medications saved yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan a prescription label or add a dose from Schedule.',
              style: TextStyle(fontSize: 12, color: c.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
