import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../core/scheduling/reminder_scheduler.dart'
    show batchIdForTimeSlot, isSameTimeSlot;
import '../../core/theme/pillpal_colors.dart';
import '../../presentation/widgets/pressable.dart';
import '../../presentation/widgets/profile_chip.dart';
import '../../presentation/widgets/scan_bottle_button.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../ui/widgets/walkthrough_overlay.dart';
import '../account/widgets/bedtime_schedule_editor.dart' show kAppleSpring;
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
  final void Function(String prescriptionId, String time)? onSnoozeDose;
  final ValueChanged<String>? onCancelSnooze;
  final void Function(String prescriptionId, String time)? onSkipDose;
  final void Function(List<(String, String)> targets)? onSkipAllInSection;
  final Set<String> skippedSlotKeys;
  final Map<String, DateTime> activeSnoozeEnds;
  final ValueChanged<Prescription> onViewMedication;
  final void Function(Prescription prescription, String time)? onViewSlot;
  final ValueChanged<Prescription>? onEditMedication;
  final ValueChanged<String>? onDeleteMedication;
  final void Function(List<(String, String)> targets, bool shouldMarkTaken)
      onToggleAllCompleted;
  final VoidCallback onOpenScan;
  final bool isScanning;
  final bool isActive;
  final GlobalKey? firstMedCardKey;
  final GlobalKey? profileSwitcherKey;
  final List<GlobalKey>? profileChipKeys;
  final GlobalKey? scanButtonKey;
  final GlobalKey? emptyScheduleKey;

  const ScheduleScreen({
    super.key,
    required this.prescriptions,
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelectProfile,
    required this.onTakeDose,
    this.onSnoozeDose,
    this.onCancelSnooze,
    this.onSkipDose,
    this.onSkipAllInSection,
    this.skippedSlotKeys = const {},
    this.activeSnoozeEnds = const {},
    required this.onViewMedication,
    this.onViewSlot,
    this.onEditMedication,
    this.onDeleteMedication,
    required this.onToggleAllCompleted,
    required this.onOpenScan,
    required this.isScanning,
    this.isActive = true,
    this.firstMedCardKey,
    this.profileSwitcherKey,
    this.profileChipKeys,
    this.scanButtonKey,
    this.emptyScheduleKey,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final allSlots = prescriptions
        .expand((m) => m.reminderTimes.map((t) => (prescription: m, time: t)))
        .toList()
      ..sort((a, b) {
        final ta = parseTimeOfDayLabel(a.time);
        final tb = parseTimeOfDayLabel(b.time);
        if (ta == null || tb == null) return 0;
        return (ta.hour * 60 + ta.minute).compareTo(tb.hour * 60 + tb.minute);
      });

    final morningSlots = <ScheduleSlot>[];
    final afternoonSlots = <ScheduleSlot>[];
    final eveningSlots = <ScheduleSlot>[];
    final nightSlots = <ScheduleSlot>[];

    for (final slot in allSlots) {
      final tod = parseTimeOfDayLabel(slot.time);
      if (tod != null) {
        final hour = tod.hour;
        if (hour >= 4 && hour < 12) {
          morningSlots.add(slot);
        } else if (hour >= 12 && hour < 17) {
          afternoonSlots.add(slot);
        } else if (hour >= 17 && hour < 21) {
          eveningSlots.add(slot);
        } else {
          nightSlots.add(slot);
        }
      } else {
        final upper = slot.time.toUpperCase();
        if (upper.contains('AM')) {
          morningSlots.add(slot);
        } else {
          afternoonSlots.add(slot);
        }
      }
    }

    final sections = [
      (title: 'MORNING', slots: morningSlots),
      (title: 'AFTERNOON', slots: afternoonSlots),
      (title: 'EVENING', slots: eveningSlots),
      (title: 'NIGHT', slots: nightSlots),
    ].where((s) => s.slots.isNotEmpty).toList();

    final topSafeArea = MediaQuery.viewPaddingOf(context).top;
    final headerApproxHeight = profiles.length > 1 ? 228.0 : 180.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        final remainingEstimate =
            (viewportHeight - headerApproxHeight).clamp(0.0, viewportHeight);
        final maxBottomOffset =
            (remainingEstimate - 210.0).clamp(0.0, double.infinity);
        final emptyBottomOffset =
            (topSafeArea + headerApproxHeight).clamp(0.0, maxBottomOffset);

        return CustomScrollView(
          slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.fromLTRB(16, Platform.isIOS ? 4 : 8, 16, 8),
            padding: const EdgeInsets.fromLTRB(20, 20, 18, 22),
            decoration: BoxDecoration(
              color: c.headerTeal,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: c.teal.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  key: profiles.length <= 1 ? profileSwitcherKey : null,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${timeOfDayGreeting()},',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      profiles
                          .firstWhere(
                            (p) => p.isPrimary,
                            orElse: () => const Profile(
                                id: '0', name: 'there', color: Colors.grey),
                          )
                          .name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatFullDate(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ScanBottleButton(
                        key: scanButtonKey,
                        onTap: onOpenScan,
                        isLoading: isScanning,
                      ),
                      _AddMedsNudgeArrow(
                        shouldNudge: prescriptions.isEmpty && isActive,
                      ),
                    ],
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
                Text(
                  "Today's Schedule",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                if (profiles.length > 1) ...[
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      key: profileSwitcherKey,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ProfileChip(
                          contentKey: profileChipKeys != null &&
                                  profileChipKeys!.isNotEmpty
                              ? profileChipKeys![0]
                              : null,
                          label: 'All',
                          isSelected: selectedProfileId == 'all',
                          onTap: () => onSelectProfile('all'),
                        ),
                        ...profiles.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final p = entry.value;
                          final isSelected = selectedProfileId == p.id;
                          return _ProfileChip(
                            contentKey: profileChipKeys != null &&
                                    idx < profileChipKeys!.length
                                ? profileChipKeys![idx]
                                : null,
                            label: '${p.name}${p.isPrimary ? ' (Me)' : ''}',
                            isSelected: isSelected,
                            selectedColor: p.color,
                            onTap: () => onSelectProfile(p.id),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (sections.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: emptyBottomOffset),
                child: KeyedSubtree(
                  key: emptyScheduleKey,
                  child: _EmptySchedule(
                    hasAnyPrescriptions: prescriptions.isNotEmpty,
                  ),
                ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: _buildScheduleContent(context, sections, allSlots),
          ),
      ],
    );
      },
    );
  }

  Widget _buildScheduleContent(
    BuildContext context,
    List<({String title, List<ScheduleSlot> slots})> sections,
    List<ScheduleSlot> allSlots,
  ) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS ||
        (!kIsWeb && Platform.isIOS);

    if (isIOS) {
      return _buildIOSScheduleContent(context, sections, allSlots);
    }

    return _buildAndroidScheduleContent(context, sections, allSlots);
  }

  Widget _buildIOSScheduleContent(
    BuildContext context,
    List<({String title, List<ScheduleSlot> slots})> sections,
    List<ScheduleSlot> allSlots,
  ) {
    return _IOSScheduleContent(
      sections: sections,
      allSlots: allSlots,
      selectedProfileId: selectedProfileId,
      hasAnyPrescriptions: prescriptions.isNotEmpty,
      emptyScheduleKey: emptyScheduleKey,
      buildSectionHeader: (ctx, section,
              {required bool isFirst, List<ScheduleSlot>? visibleSlotsOverride}) =>
          _buildSectionHeader(
        ctx,
        section,
        isFirst: isFirst,
        visibleSlotsOverride: visibleSlotsOverride,
      ),
      buildSlotCard: _slotCard,
    );
  }

  Widget _buildAndroidScheduleContent(
    BuildContext context,
    List<({String title, List<ScheduleSlot> slots})> sections,
    List<ScheduleSlot> allSlots,
  ) {
    final hasAnyVisible = allSlots.any((s) =>
        selectedProfileId == 'all' ||
        s.prescription.profileId == selectedProfileId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var idx = 0; idx < sections.length; idx++) ...[
          _buildAndroidAnimatedSection(context, sections[idx], isFirst: idx == 0),
        ],
        _AndroidAnimatedCollapseItem(
          key: const ValueKey('anim_empty_schedule_android'),
          isVisible: !hasAnyVisible,
          child: Column(
            children: [
              KeyedSubtree(
                key: emptyScheduleKey,
                child: _EmptySchedule(
                  hasAnyPrescriptions: prescriptions.isNotEmpty,
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildAndroidAnimatedSection(
    BuildContext context,
    ({String title, List<ScheduleSlot> slots}) section, {
    required bool isFirst,
  }) {
    final visibleSlots = section.slots
        .where((s) =>
            selectedProfileId == 'all' ||
            s.prescription.profileId == selectedProfileId)
        .toList();
    final isSectionVisible = visibleSlots.isNotEmpty;
    final firstSlot = section.slots.isNotEmpty ? section.slots.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AndroidAnimatedCollapseItem(
          key: ValueKey('anim_sec_${section.title}'),
          isVisible: isSectionVisible,
          child: _buildSectionHeader(context, section, isFirst: isFirst),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final slot in section.slots)
                _AndroidAnimatedCollapseItem(
                  key: ValueKey('anim_slot_${slot.prescription.id}_${slot.time}'),
                  isVisible: selectedProfileId == 'all' ||
                      slot.prescription.profileId == selectedProfileId,
                  child: _slotCard(
                    slot,
                    isTargetCard: isFirst &&
                        selectedProfileId == 'all' &&
                        firstSlot != null &&
                        slot.prescription.id == firstSlot.prescription.id &&
                        slot.time == firstSlot.time,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    ({String title, List<ScheduleSlot> slots}) section, {
    required bool isFirst,
    List<ScheduleSlot>? visibleSlotsOverride,
  }) {
    final c = context.colors;
    final visibleSlots = visibleSlotsOverride ??
        section.slots
            .where((s) =>
                selectedProfileId == 'all' ||
                s.prescription.profileId == selectedProfileId)
            .toList();
    final sectionTotal = visibleSlots.length;
    final sectionTaken = visibleSlots
        .where((s) => s.prescription.takenTimes.contains(s.time))
        .length;
    final sectionResolved = visibleSlots
        .where((s) {
          final slotKey = '${s.prescription.id}_${s.time}';
          return s.prescription.takenTimes.contains(s.time) ||
              skippedSlotKeys.contains(slotKey);
        })
        .length;
    final sectionAllDone = sectionTotal > 0 && sectionResolved == sectionTotal;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, isFirst ? 20 : 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            section.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.inkMuted,
              letterSpacing: 0.6,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 5, horizontal: 10),
                decoration: BoxDecoration(
                  color: c.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$sectionTaken of $sectionTotal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.tealDeep,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _MarkAllSectionButton(
                key: ValueKey('mark_all_${section.title.toLowerCase()}'),
                sectionTitle: section.title,
                sectionAllDone: sectionAllDone,
                hasAnyResolved: sectionResolved > 0,
                onTap: () {
                  final targets = visibleSlots
                      .map((s) => (s.prescription.id, s.time))
                      .toList();
                  onToggleAllCompleted(targets, !sectionAllDone);
                },
                onMarkAllTaken: () {
                  final targets = visibleSlots
                      .map((s) => (s.prescription.id, s.time))
                      .toList();
                  onToggleAllCompleted(targets, true);
                },
                onMarkAllSkipped: onSkipAllInSection != null
                    ? () {
                        final targets = visibleSlots
                            .map((s) => (s.prescription.id, s.time))
                            .toList();
                        onSkipAllInSection!(targets);
                      }
                    : null,
                onResetAll: () {
                  final targets = visibleSlots
                      .map((s) => (s.prescription.id, s.time))
                      .toList();
                  onToggleAllCompleted(targets, false);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _batchHasUntakenUnskipped(String timeSlot) {
    for (final p in prescriptions) {
      for (final t in p.reminderTimes) {
        if (!isSameTimeSlot(t, timeSlot)) continue;
        final taken = p.takenTimes.any((tk) => isSameTimeSlot(tk, t));
        final skipped = skippedSlotKeys.contains('${p.id}_$t');
        if (!taken && !skipped) return true;
      }
    }
    return false;
  }

  Widget _slotCard(ScheduleSlot slot, {bool isTargetCard = false}) {
    final slotKey = '${slot.prescription.id}_${slot.time}';
    final isSkipped = skippedSlotKeys.contains(slotKey);
    final batchId = batchIdForTimeSlot(slot.time);
    final rawSnoozeEnd = activeSnoozeEnds[batchId];
    final isSnoozeActive = rawSnoozeEnd != null &&
        DateTime.now().isBefore(rawSnoozeEnd) &&
        _batchHasUntakenUnskipped(slot.time);

    return MedicationCard(
      key: ValueKey('med_${slot.prescription.id}_${slot.time}'),
      targetKey: isTargetCard ? firstMedCardKey : null,
      item: slot.prescription,
      time: slot.time,
      isTaken: slot.prescription.takenTimes.contains(slot.time),
      isSkipped: isSkipped,
      isSnoozeActive: isSnoozeActive,
      snoozeEndTime: isSnoozeActive ? rawSnoozeEnd : null,
      profile: profiles.length > 1
          ? profiles.cast<Profile?>().firstWhere(
                (p) => p?.id == slot.prescription.profileId,
                orElse: () => null,
              )
          : null,
      onTakeDose: () => onTakeDose(slot.prescription.id, slot.time),
      onSnooze: onSnoozeDose != null
          ? () => onSnoozeDose!(slot.prescription.id, slot.time)
          : null,
      onCancelSnooze: onCancelSnooze != null
          ? () => onCancelSnooze!(slot.time)
          : null,
      onSkip: onSkipDose != null
          ? () => onSkipDose!(slot.prescription.id, slot.time)
          : null,
      onViewDetails: () => onViewSlot != null
          ? onViewSlot!(slot.prescription, slot.time)
          : onViewMedication(slot.prescription),
      onEdit: onEditMedication != null ? () => onEditMedication!(slot.prescription) : null,
      onDelete: onDeleteMedication != null ? () => onDeleteMedication!(slot.prescription.id) : null,
    );
  }
}

enum _MarkAllMenuAction { markAllTaken, markAllSkipped, resetAll }

/// Section-level `Mark All` / `Reset` pill button.
/// - Quick tap toggles Mark All Taken / Reset as before.
/// - Press-and-hold (~375ms) opens a frosted iOS-style popover submenu offering
///   **Mark All Taken**, **Mark All Skipped**, and (when applicable) **Reset All**.
class _MarkAllSectionButton extends StatelessWidget {
  const _MarkAllSectionButton({
    super.key,
    required this.sectionTitle,
    required this.sectionAllDone,
    required this.hasAnyResolved,
    required this.onTap,
    required this.onMarkAllTaken,
    this.onMarkAllSkipped,
    required this.onResetAll,
  });

  final String sectionTitle;
  final bool sectionAllDone;
  final bool hasAnyResolved;
  final VoidCallback onTap;
  final VoidCallback onMarkAllTaken;
  final VoidCallback? onMarkAllSkipped;
  final VoidCallback onResetAll;

  Future<void> _showSubmenu(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final buttonOffset = renderBox?.localToGlobal(Offset.zero);
    final buttonSize = renderBox?.size;

    final action = await showGeneralDialog<_MarkAllMenuAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss $sectionTitle actions',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogCtx, _, __) {
        final c = context.colors;
        final screenSize = MediaQuery.of(dialogCtx).size;
        final double top = buttonOffset != null
            ? (buttonOffset.dy + (buttonSize?.height ?? 28) + 8)
                .clamp(60.0, screenSize.height - 200.0)
            : 180.0;
        final double right = buttonOffset != null
            ? (screenSize.width -
                    (buttonOffset.dx + (buttonSize?.width ?? 88)))
                .clamp(16.0, screenSize.width - 236.0)
            : 20.0;

        return Stack(
          children: [
            Positioned(
              top: top,
              right: right,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      key: Key('mark_all_submenu_${sectionTitle.toLowerCase()}'),
                      width: 220,
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: c.borderLight.withValues(alpha: 0.6),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 24,
                            spreadRadius: -2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _submenuRow(
                            key: const Key('mark_all_menu_taken'),
                            label: 'Mark All Taken',
                            icon: CupertinoIcons.checkmark_circle_fill,
                            iconColor: c.teal,
                            c: c,
                            onTap: () => Navigator.pop(
                              dialogCtx,
                              _MarkAllMenuAction.markAllTaken,
                            ),
                          ),
                          if (onMarkAllSkipped != null) ...[
                            Divider(
                              height: 0.5,
                              thickness: 0.5,
                              color: c.borderLight.withValues(alpha: 0.6),
                            ),
                            _submenuRow(
                              key: const Key('mark_all_menu_skipped'),
                              label: 'Mark All Skipped',
                              icon: CupertinoIcons.forward_fill,
                              iconColor: c.inkMuted,
                              c: c,
                              onTap: () => Navigator.pop(
                                dialogCtx,
                                _MarkAllMenuAction.markAllSkipped,
                              ),
                            ),
                          ],
                          if (hasAnyResolved) ...[
                            Divider(
                              height: 0.5,
                              thickness: 0.5,
                              color: c.borderLight.withValues(alpha: 0.6),
                            ),
                            _submenuRow(
                              key: const Key('mark_all_menu_reset'),
                              label: 'Reset All',
                              icon: CupertinoIcons.arrow_counterclockwise,
                              iconColor: c.ink,
                              c: c,
                              onTap: () => Navigator.pop(
                                dialogCtx,
                                _MarkAllMenuAction.resetAll,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );

    if (action == null) return;
    switch (action) {
      case _MarkAllMenuAction.markAllTaken:
        onMarkAllTaken();
      case _MarkAllMenuAction.markAllSkipped:
        onMarkAllSkipped?.call();
      case _MarkAllMenuAction.resetAll:
        onResetAll();
    }
  }

  Widget _submenuRow({
    Key? key,
    required String label,
    required IconData icon,
    required Color iconColor,
    required PillPalColors c,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: c.ink.withValues(alpha: 0.06),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      scale: 0.94,
      onTap: onTap,
      onHold: () => _showSubmenu(context),
      holdDuration: const Duration(milliseconds: 375),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        decoration: BoxDecoration(
          color: sectionAllDone ? c.neutralChip : c.tealDeep,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sectionAllDone
                  ? CupertinoIcons.arrow_counterclockwise
                  : CupertinoIcons.checkmark_alt,
              size: 13,
              color: sectionAllDone ? c.neutralInk : c.onTeal,
            ),
            const SizedBox(width: 4),
            Text(
              sectionAllDone ? 'Reset' : 'Mark All',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: sectionAllDone ? c.neutralInk : c.onTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS Schedule list coordinator supporting two complementary native motion
/// patterns (scalable to any number of profiles, medications, and sections):
///
/// 1. **Subset / superset transitions (`All ↔ Profile`)**: Uses real slot
///    identities so cards shared with `All` stay untouched and glide smoothly
///    up or down while non-matching cards/sections spring open or closed.
/// 2. **Disjoint profile swaps (`Profile A ↔ Profile B`)**: Pairs overlapping
///    card slots by position (`0 → 0`, `1 → 1`, …) so overlapping cards stay
///    anchored and cross-dissolve cleanly in place (never collapsing the list
///    to empty and re-spawning), while only the length difference springs open
///    or closed underneath.
class _IOSScheduleContent extends StatefulWidget {
  const _IOSScheduleContent({
    required this.sections,
    required this.allSlots,
    required this.selectedProfileId,
    required this.hasAnyPrescriptions,
    required this.emptyScheduleKey,
    required this.buildSectionHeader,
    required this.buildSlotCard,
  });

  final List<({String title, List<ScheduleSlot> slots})> sections;
  final List<ScheduleSlot> allSlots;
  final String selectedProfileId;
  final bool hasAnyPrescriptions;
  final GlobalKey? emptyScheduleKey;
  final Widget Function(
    BuildContext context,
    ({String title, List<ScheduleSlot> slots}) section, {
    required bool isFirst,
    List<ScheduleSlot>? visibleSlotsOverride,
  }) buildSectionHeader;
  final Widget Function(ScheduleSlot slot, {bool isTargetCard}) buildSlotCard;

  @override
  State<_IOSScheduleContent> createState() => _IOSScheduleContentState();
}

class _IOSScheduleContentState extends State<_IOSScheduleContent> {
  late String _previousProfileId;
  bool _positionalMode = false;
  bool _justEnteredPositional = false;
  bool _justExitedPositional = false;

  @override
  void initState() {
    super.initState();
    _previousProfileId = widget.selectedProfileId;
  }

  @override
  void didUpdateWidget(covariant _IOSScheduleContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedProfileId != oldWidget.selectedProfileId) {
      _previousProfileId = oldWidget.selectedProfileId;
      final isDisjointSwap =
          oldWidget.selectedProfileId != 'all' &&
          widget.selectedProfileId != 'all';
      if (isDisjointSwap) {
        _justEnteredPositional = !_positionalMode;
        _justExitedPositional = false;
        _positionalMode = true;
      } else {
        _justExitedPositional = _positionalMode;
        _justEnteredPositional = false;
        _positionalMode = false;
      }
    } else {
      _justEnteredPositional = false;
      _justExitedPositional = false;
    }
  }

  bool _matchesProfile(ScheduleSlot slot, String profileId) =>
      profileId == 'all' || slot.prescription.profileId == profileId;

  String _slotId(ScheduleSlot slot) => '${slot.prescription.id}_${slot.time}';

  int _maxSingleProfileCount(List<ScheduleSlot> slots) {
    final counts = <String, int>{};
    var maxCount = 0;
    for (final s in slots) {
      final next = (counts[s.prescription.profileId] ?? 0) + 1;
      counts[s.prescription.profileId] = next;
      if (next > maxCount) maxCount = next;
    }
    return maxCount;
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyVisible = widget.allSlots
        .any((s) => _matchesProfile(s, widget.selectedProfileId));
    final prevHadAny = widget.allSlots
        .any((s) => _matchesProfile(s, _previousProfileId));

    if (!_positionalMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var idx = 0; idx < widget.sections.length; idx++)
            _buildIdentitySection(context, widget.sections[idx], isFirst: idx == 0),
          IOSListRowReveal(
            key: const ValueKey('ios_empty_schedule'),
            initialVisible: _justExitedPositional ? !prevHadAny : !hasAnyVisible,
            visible: !hasAnyVisible,
            child: KeyedSubtree(
              key: widget.emptyScheduleKey,
              child: _EmptySchedule(
                hasAnyPrescriptions: widget.hasAnyPrescriptions,
              ),
            ),
          ),
          const SizedBox(height: 120),
        ],
      );
    }

    return _buildPositionalSchedule(
      context,
      hasAnyVisible: hasAnyVisible,
      prevHadAny: prevHadAny,
    );
  }

  Widget _buildIdentitySection(
    BuildContext context,
    ({String title, List<ScheduleSlot> slots}) section, {
    required bool isFirst,
  }) {
    final isSectionVisible =
        section.slots.any((s) => _matchesProfile(s, widget.selectedProfileId));
    final wasSectionVisible = _justExitedPositional
        ? section.slots.any((s) => _matchesProfile(s, _previousProfileId))
        : isSectionVisible;
    final firstSlot = section.slots.isNotEmpty ? section.slots.first : null;

    return IOSListRowReveal(
      key: ValueKey('ios_sec_${section.title}'),
      initialVisible: wasSectionVisible,
      visible: isSectionVisible,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.buildSectionHeader(context, section, isFirst: isFirst),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (final slot in section.slots)
                  IOSListRowReveal(
                    key: ValueKey('ios_slot_${_slotId(slot)}'),
                    initialVisible: _justExitedPositional
                        ? _matchesProfile(slot, _previousProfileId)
                        : (!isSectionVisible ||
                            _matchesProfile(slot, widget.selectedProfileId)),
                    visible: !isSectionVisible ||
                        _matchesProfile(slot, widget.selectedProfileId),
                    child: widget.buildSlotCard(
                      slot,
                      isTargetCard: isFirst &&
                          widget.selectedProfileId == 'all' &&
                          firstSlot != null &&
                          slot.prescription.id == firstSlot.prescription.id &&
                          slot.time == firstSlot.time,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionalSchedule(
    BuildContext context, {
    required bool hasAnyVisible,
    required bool prevHadAny,
  }) {
    final currActiveSections = [
      for (final s in widget.sections)
        if (s.slots.any((slot) => _matchesProfile(slot, widget.selectedProfileId)))
          (
            title: s.title,
            slots: s.slots
                .where((slot) => _matchesProfile(slot, widget.selectedProfileId))
                .toList(),
            sourceSection: s,
          ),
    ];
    final prevActiveSections = [
      for (final s in widget.sections)
        if (s.slots.any((slot) => _matchesProfile(slot, _previousProfileId)))
          (
            title: s.title,
            slots: s.slots
                .where((slot) => _matchesProfile(slot, _previousProfileId))
                .toList(),
            sourceSection: s,
          ),
    ];

    final currTitles = currActiveSections.map((s) => s.title).toSet();
    final prevTitles = prevActiveSections.map((s) => s.title).toSet();
    final hasOverlappingSection = currTitles.intersection(prevTitles).isNotEmpty;

    // When both profiles have meds but share zero time-of-day sections (e.g.,
    // Me only has Evening while Mom only has Morning), anchor section slot 0
    // and cross-dissolve in place so the list never collapses to empty.
    if (!hasOverlappingSection && hasAnyVisible && prevHadAny) {
      final totalSectionSlots =
          math.max(currActiveSections.length, prevActiveSections.length);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var secIdx = 0; secIdx < totalSectionSlots; secIdx++)
            _buildPairedDisjointSection(
              context,
              sectionIndex: secIdx,
              curr: secIdx < currActiveSections.length
                  ? currActiveSections[secIdx]
                  : null,
              prev: secIdx < prevActiveSections.length
                  ? prevActiveSections[secIdx]
                  : null,
            ),
          IOSListRowReveal(
            key: const ValueKey('ios_empty_schedule'),
            initialVisible: false,
            visible: false,
            child: KeyedSubtree(
              key: widget.emptyScheduleKey,
              child: _EmptySchedule(
                hasAnyPrescriptions: widget.hasAnyPrescriptions,
              ),
            ),
          ),
          const SizedBox(height: 120),
        ],
      );
    }

    // Standard positional mode: shared section headers stay rock-steady,
    // overlapping card indices cross-dissolve in place, and extra cards or
    // sections spring smoothly open/closed.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var idx = 0; idx < widget.sections.length; idx++)
          _buildPositionalNamedSection(
            context,
            widget.sections[idx],
            isFirst: idx == 0,
          ),
        IOSListRowReveal(
          key: const ValueKey('ios_empty_schedule'),
          initialVisible: _justEnteredPositional ? !prevHadAny : !hasAnyVisible,
          visible: !hasAnyVisible,
          child: KeyedSubtree(
            key: widget.emptyScheduleKey,
            child: _EmptySchedule(
              hasAnyPrescriptions: widget.hasAnyPrescriptions,
            ),
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildPositionalNamedSection(
    BuildContext context,
    ({String title, List<ScheduleSlot> slots}) section, {
    required bool isFirst,
  }) {
    final currSlots = section.slots
        .where((s) => _matchesProfile(s, widget.selectedProfileId))
        .toList();
    final prevSlots = section.slots
        .where((s) => _matchesProfile(s, _previousProfileId))
        .toList();

    final isSectionVisible = currSlots.isNotEmpty;
    final wasSectionVisible =
        _justEnteredPositional ? prevSlots.isNotEmpty : isSectionVisible;

    final maxSlots = math.max(
      _maxSingleProfileCount(section.slots),
      math.max(currSlots.length, prevSlots.length),
    );
    final headerSlots = isSectionVisible ? currSlots : prevSlots;

    return IOSListRowReveal(
      key: ValueKey('ios_pos_sec_${section.title}'),
      initialVisible: wasSectionVisible,
      visible: isSectionVisible,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.buildSectionHeader(
            context,
            section,
            isFirst: isFirst,
            visibleSlotsOverride: headerSlots,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (var i = 0; i < maxSlots; i++)
                  _buildPositionalSlotRow(
                    sectionKey: section.title,
                    slotIndex: i,
                    isSectionVisible: isSectionVisible,
                    currSlot: i < currSlots.length ? currSlots[i] : null,
                    prevSlot: i < prevSlots.length ? prevSlots[i] : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairedDisjointSection(
    BuildContext context, {
    required int sectionIndex,
    required ({
      String title,
      List<ScheduleSlot> slots,
      ({String title, List<ScheduleSlot> slots}) sourceSection,
    })? curr,
    required ({
      String title,
      List<ScheduleSlot> slots,
      ({String title, List<ScheduleSlot> slots}) sourceSection,
    })? prev,
  }) {
    final currSlots = curr?.slots ?? const <ScheduleSlot>[];
    final prevSlots = prev?.slots ?? const <ScheduleSlot>[];
    final isSectionVisible = curr != null;
    final wasSectionVisible = prev != null;
    final maxSlots = math.max(currSlots.length, prevSlots.length);

    final activeHeader = curr != null
        ? widget.buildSectionHeader(
            context,
            curr.sourceSection,
            isFirst: sectionIndex == 0,
            visibleSlotsOverride: curr.slots,
          )
        : widget.buildSectionHeader(
            context,
            prev!.sourceSection,
            isFirst: sectionIndex == 0,
            visibleSlotsOverride: prev.slots,
          );
    final prevHeader = (curr != null && prev != null && curr.title != prev.title)
        ? widget.buildSectionHeader(
            context,
            prev.sourceSection,
            isFirst: sectionIndex == 0,
            visibleSlotsOverride: prev.slots,
          )
        : null;

    return IOSListRowReveal(
      key: ValueKey('ios_disjoint_sec_$sectionIndex'),
      initialVisible: wasSectionVisible,
      visible: isSectionVisible,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InPlaceCardSwap(
            key: ValueKey('ios_disjoint_hdr_$sectionIndex'),
            contentId: curr?.title ?? prev?.title ?? '',
            initialOutgoingChild: _justEnteredPositional ? prevHeader : null,
            child: activeHeader,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (var i = 0; i < maxSlots; i++)
                  _buildPositionalSlotRow(
                    sectionKey: 'disjoint_$sectionIndex',
                    slotIndex: i,
                    isSectionVisible: isSectionVisible,
                    currSlot: i < currSlots.length ? currSlots[i] : null,
                    prevSlot: i < prevSlots.length ? prevSlots[i] : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionalSlotRow({
    required String sectionKey,
    required int slotIndex,
    required bool isSectionVisible,
    required ScheduleSlot? currSlot,
    required ScheduleSlot? prevSlot,
  }) {
    final displaySlot = currSlot ?? prevSlot;
    if (displaySlot == null) {
      return SizedBox(
        key: ValueKey('ios_pos_slot_${sectionKey}_$slotIndex'),
        width: double.infinity,
        height: 0,
      );
    }

    // If the entire section is collapsing, keep inner slots open so the outer
    // section reveal glides the whole section away as one solid piece.
    final slotVisible = !isSectionVisible || currSlot != null;
    final slotInitialVisible = _justEnteredPositional
        ? (!isSectionVisible || prevSlot != null)
        : slotVisible;

    final shouldCrossDissolveOnMount = _justEnteredPositional &&
        currSlot != null &&
        prevSlot != null &&
        _slotId(currSlot) != _slotId(prevSlot);

    return IOSListRowReveal(
      key: ValueKey('ios_pos_slot_${sectionKey}_$slotIndex'),
      initialVisible: slotInitialVisible,
      visible: slotVisible,
      child: _InPlaceCardSwap(
        key: ValueKey('ios_pos_swap_${sectionKey}_$slotIndex'),
        contentId: _slotId(displaySlot),
        initialOutgoingChild: shouldCrossDissolveOnMount
            ? widget.buildSlotCard(prevSlot, isTargetCard: false)
            : null,
        child: widget.buildSlotCard(displaySlot, isTargetCard: false),
      ),
    );
  }
}

/// Clean, single-controller in-place cross-dissolve for overlapping card slots
/// during a disjoint profile swap (`Profile A ↔ Profile B`).
///
/// Holds at most 2 children (outgoing + incoming) with monotonically sequenced
/// keys so rapid mid-flight taps can never produce duplicate keys, and wraps
/// the outgoing child in [ExcludeSemantics] + [IgnorePointer].
class _InPlaceCardSwap extends StatefulWidget {
  const _InPlaceCardSwap({
    super.key,
    required this.contentId,
    required this.child,
    this.initialOutgoingChild,
  });

  final String contentId;
  final Widget child;
  final Widget? initialOutgoingChild;

  @override
  State<_InPlaceCardSwap> createState() => _InPlaceCardSwapState();
}

class _InPlaceCardSwapState extends State<_InPlaceCardSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _outgoingChild;
  int _swapSeq = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            _outgoingChild != null &&
            mounted) {
          setState(() => _outgoingChild = null);
        }
      });

    if (widget.initialOutgoingChild != null) {
      _outgoingChild = widget.initialOutgoingChild;
      _swapSeq++;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant _InPlaceCardSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.contentId != oldWidget.contentId) {
      final disableAnim =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disableAnim) {
        _outgoingChild = null;
        _controller.value = 1.0;
      } else {
        _outgoingChild = oldWidget.child;
        _swapSeq++;
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outgoing = _outgoingChild;
    if (outgoing == null) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value.clamp(0.0, 1.0);
        // Fast sequential-leaning dissolve so text from the two cards doesn't
        // muddy together while the card frame stays anchored in place.
        final outOpacity =
            1.0 - Curves.easeIn.transform((t / 0.50).clamp(0.0, 1.0));
        final inOpacity =
            Curves.easeOut.transform(((t - 0.30) / 0.70).clamp(0.0, 1.0));
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ExcludeSemantics(
              child: IgnorePointer(
                child: Opacity(
                  opacity: outOpacity,
                  child: KeyedSubtree(
                    key: ValueKey('swap_out_$_swapSeq'),
                    child: outgoing,
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: inOpacity,
              child: KeyedSubtree(
                key: ValueKey('swap_in_$_swapSeq'),
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// iOS-only row insertion/deletion animation, modelled on UITableView /
/// SwiftUI `List` row updates and matching `AppleDisclosureReveal` on the
/// Bedtime screen:
///
/// * **Insert** -- driven by an interruptible critically damped iOS spring
///   ([kAppleSpring]), the row's height opens from 0 while its content, pinned
///   to the bottom edge and clipped only at the top, descends out from under
///   the row above and fades in.
/// * **Delete** -- the reverse: the content fades out slightly ahead of
///   collapse while ascending smoothly behind the row above, and the rows
///   below glide up in lock-step.
///
/// Once fully collapsed the child is unmounted (no hit-testing, no semantics).
class IOSListRowReveal extends StatefulWidget {
  final bool visible;
  final bool? initialVisible;
  final Widget child;

  const IOSListRowReveal({
    super.key,
    required this.visible,
    this.initialVisible,
    required this.child,
  });

  @override
  State<IOSListRowReveal> createState() => _IOSListRowRevealState();
}

class _IOSListRowRevealState extends State<IOSListRowReveal>
    with SingleTickerProviderStateMixin {
  static const Tolerance _springTolerance = Tolerance(
    distance: 0.001,
    velocity: 0.001,
  );

  late final AnimationController _controller;
  late bool _isOpening;
  bool _hasStartedInitialTransition = false;

  @override
  void initState() {
    super.initState();
    final startVisible = widget.initialVisible ?? widget.visible;
    _isOpening = widget.visible;
    _controller = AnimationController.unbounded(
      vsync: this,
      value: startVisible ? 1.0 : 0.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStartedInitialTransition) {
      _hasStartedInitialTransition = true;
      final startVisible = widget.initialVisible ?? widget.visible;
      if (startVisible != widget.visible) {
        _animateTo(widget.visible ? 1.0 : 0.0);
      }
    }
  }

  void _animateTo(double target) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _controller.value = target;
      if (!widget.visible && mounted) setState(() {});
      return;
    }
    final sim = SpringSimulation(
      kAppleSpring,
      _controller.value,
      target,
      _controller.velocity,
      tolerance: _springTolerance,
    );
    _controller.animateWith(sim).whenComplete(() {
      if (!mounted) return;
      if (!_controller.isAnimating && widget.visible == (target == 1.0)) {
        _controller.value = target;
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant IOSListRowReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      _isOpening = widget.visible;
      _animateTo(widget.visible ? 1.0 : 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _controller.value.clamp(0.0, 1.0);
    if (!widget.visible && !_controller.isAnimating && current <= 0.001) {
      return const SizedBox(width: double.infinity, height: 0);
    }

    return ExcludeSemantics(
      excluding: !widget.visible,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final v = _controller.value.clamp(0.0, 1.0);
            if (!widget.visible && !_controller.isAnimating && v <= 0.001) {
              return const SizedBox(width: double.infinity, height: 0);
            }
            final double opacity;
            if (_isOpening) {
              opacity =
                  Curves.easeOut.transform(((v - 0.10) / 0.90).clamp(0.0, 1.0));
            } else {
              opacity =
                  Curves.easeIn.transform(((v - 0.22) / 0.78).clamp(0.0, 1.0));
            }
            return Opacity(
              opacity: opacity,
              child: ClipRect(
                clipper: const _TopEdgeClipper(),
                clipBehavior: v < 0.999 ? Clip.hardEdge : Clip.none,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: v,
                  child: child,
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Clips only the top edge (the "under the row above" line). Sides and bottom
/// are left generous so card drop shadows aren't shaved off mid-animation.
class _TopEdgeClipper extends CustomClipper<Rect> {
  const _TopEdgeClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-40, 0, size.width + 40, size.height + 40);

  @override
  bool shouldReclip(covariant _TopEdgeClipper oldClipper) => false;
}

class _AndroidAnimatedCollapseItem extends StatelessWidget {
  final bool isVisible;
  final Widget child;

  const _AndroidAnimatedCollapseItem({
    super.key,
    required this.isVisible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: child,
      secondChild: const SizedBox(width: double.infinity, height: 0),
      crossFadeState:
          isVisible ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: const Duration(milliseconds: 280),
      firstCurve: Curves.fastOutSlowIn,
      secondCurve: Curves.fastOutSlowIn,
      sizeCurve: Curves.fastOutSlowIn,
      alignment: Alignment.topCenter,
    );
  }
}

typedef _ProfileChip = ProfileChip;

class _EmptySchedule extends StatelessWidget {
  final bool hasAnyPrescriptions;

  const _EmptySchedule({required this.hasAnyPrescriptions});

  @override
  Widget build(BuildContext context) {
    if (hasAnyPrescriptions) {
      return const AnimatedEmptyFeedState(
        icon: CupertinoIcons.checkmark_seal,
        title: 'Nothing scheduled',
        subtitle: 'No reminders are set for this profile.',
      );
    }

    return const AnimatedEmptyFeedState(
      icon: CupertinoIcons.calendar_badge_plus,
      title: 'No medications yet',
      subtitle:
          'Tap + Add Meds in the top right to scan a label, upload a photo, or enter one manually.',
    );
  }
}

/// Subtle, non-intrusive animated upward arrow tucked beneath "+ Add Meds"
/// when the user has zero medications registered and remains on the Schedule
/// tab for a short moment.
class _AddMedsNudgeArrow extends StatefulWidget {
  final bool shouldNudge;

  const _AddMedsNudgeArrow({required this.shouldNudge});

  @override
  State<_AddMedsNudgeArrow> createState() => _AddMedsNudgeArrowState();
}

class _AddMedsNudgeArrowState extends State<_AddMedsNudgeArrow>
    with SingleTickerProviderStateMixin {
  static const _initialDelay = Duration(milliseconds: 2500);
  static const _visibleDuration = Duration(milliseconds: 3500);
  static const _hiddenPause = Duration(milliseconds: 2500);
  static const _fadeDuration = Duration(milliseconds: 600);

  late final AnimationController _bobController;
  late final Animation<double> _bobAnimation;
  Timer? _cycleTimer;
  bool _showArrow = false;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bobAnimation = CurvedAnimation(
      parent: _bobController,
      curve: Curves.easeInOutSine,
    );
    if (widget.shouldNudge) {
      _scheduleReveal(_initialDelay);
    }
  }

  @override
  void didUpdateWidget(covariant _AddMedsNudgeArrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldNudge && !oldWidget.shouldNudge) {
      _scheduleReveal(_initialDelay);
    } else if (!widget.shouldNudge && oldWidget.shouldNudge) {
      _cancelNudge();
    }
  }

  void _scheduleReveal(Duration delay) {
    _cycleTimer?.cancel();
    _cycleTimer = Timer(delay, () {
      if (!mounted || !widget.shouldNudge) return;
      setState(() => _showArrow = true);
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (!disableAnimations && !_bobController.isAnimating) {
        _bobController.repeat(reverse: true);
      }
      _cycleTimer = Timer(_visibleDuration, _hideAndReschedule);
    });
  }

  void _hideAndReschedule() {
    if (!mounted || !widget.shouldNudge) return;
    setState(() => _showArrow = false);
    // Keep bobbing smoothly through the fade-out, then pause before fading in again.
    _cycleTimer = Timer(_fadeDuration, () {
      if (!mounted || !widget.shouldNudge) return;
      _bobController.stop();
      _bobController.reset();
      _scheduleReveal(_hiddenPause);
    });
  }

  void _cancelNudge() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
    _bobController.stop();
    _bobController.reset();
    if (_showArrow) {
      setState(() => _showArrow = false);
    }
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return IgnorePointer(
      child: SizedBox(
        height: 32,
        child: Center(
          child: AnimatedOpacity(
            key: const Key('add_meds_nudge_arrow'),
            opacity: _showArrow ? 1.0 : 0.0,
            duration: _fadeDuration,
            curve: Curves.easeInOut,
            child: AnimatedBuilder(
              animation: _bobAnimation,
              builder: (context, child) {
                final dy = disableAnimations
                    ? 0.0
                    : -4.0 * _bobAnimation.value;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: child,
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(
                  CupertinoIcons.arrow_up,
                  size: 25,
                  color: c.tealDeep.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
