import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/pillpal_colors.dart';
import '../../presentation/widgets/pressable.dart';
import '../../presentation/widgets/profile_chip.dart';
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
  final ValueChanged<Prescription>? onEditMedication;
  final ValueChanged<String>? onDeleteMedication;
  final void Function(List<(String, String)> targets, bool shouldMarkTaken)
      onToggleAllCompleted;
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
    this.onEditMedication,
    this.onDeleteMedication,
    required this.onToggleAllCompleted,
    required this.onOpenScan,
    required this.isScanning,
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
                Pressable(
                  onTap: isScanning ? null : onOpenScan,
                  scale: 0.94,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 15),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: c.liftShadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isScanning
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.teal,
                            ),
                          )
                        : Row(
                            children: [
                              Icon(CupertinoIcons.camera,
                                  size: 16, color: c.tealDeep),
                              const SizedBox(width: 6),
                              Text(
                                '+ Scan Bottle',
                                style: TextStyle(
                                  color: c.tealDeep,
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
                Text(
                  "Today's Schedule",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                    letterSpacing: -0.4,
                  ),
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
                          selectedColor: p.color,
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
        SliverToBoxAdapter(
          child: _buildScheduleContent(context, sections, allSlots),
        ),
      ],
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

  bool _isSlotVisible(ScheduleSlot slot) =>
      selectedProfileId == 'all' ||
      slot.prescription.profileId == selectedProfileId;

  /// iOS: mirrors how UITableView / SwiftUI `List` animate row insertions and
  /// deletions (e.g. the device list in Settings > Bluetooth). Every section
  /// and row stays in a persistent slot; rows that remain visible are never
  /// touched -- they simply glide to their new position as neighbours open or
  /// close. A whole section appearing/disappearing animates as one block, and
  /// individual rows inside a section that stays on screen animate on their own.
  Widget _buildIOSScheduleContent(
    BuildContext context,
    List<({String title, List<ScheduleSlot> slots})> sections,
    List<ScheduleSlot> allSlots,
  ) {
    final hasAnyVisible = allSlots.any(_isSlotVisible);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var idx = 0; idx < sections.length; idx++)
          IOSListRowReveal(
            key: ValueKey('ios_sec_${sections[idx].title}'),
            visible: sections[idx].slots.any(_isSlotVisible),
            child: _buildIOSSection(context, sections[idx], isFirst: idx == 0),
          ),
        IOSListRowReveal(
          key: const ValueKey('ios_empty_schedule'),
          visible: !hasAnyVisible,
          child: const _EmptySchedule(),
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildIOSSection(
    BuildContext context,
    ({String title, List<ScheduleSlot> slots}) section, {
    required bool isFirst,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, section, isFirst: isFirst),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final slot in section.slots)
                IOSListRowReveal(
                  key: ValueKey('ios_slot_${slot.prescription.id}_${slot.time}'),
                  visible: _isSlotVisible(slot),
                  child: _slotCard(slot),
                ),
            ],
          ),
        ),
      ],
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
          child: const Column(
            children: [
              _EmptySchedule(),
              SizedBox(height: 120),
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
    final isSectionVisible = section.slots.any((s) =>
        selectedProfileId == 'all' ||
        s.prescription.profileId == selectedProfileId);

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
                  child: _slotCard(slot),
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
  }) {
    final c = context.colors;
    final visibleSlots = section.slots
        .where((s) =>
            selectedProfileId == 'all' ||
            s.prescription.profileId == selectedProfileId)
        .toList();
    final sectionTotal = visibleSlots.length;
    final sectionTaken = visibleSlots
        .where((s) => s.prescription.takenTimes.contains(s.time))
        .length;
    final sectionAllDone = sectionTotal > 0 && sectionTaken == sectionTotal;

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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '$sectionTaken of $sectionTotal',
                    key: ValueKey('$sectionTaken of $sectionTotal'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.tealDeep,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                key: ValueKey('mark_all_${section.title.toLowerCase()}'),
                scale: 0.94,
                onTap: () {
                  final targets = visibleSlots
                      .map((s) => (s.prescription.id, s.time))
                      .toList();
                  onToggleAllCompleted(targets, !sectionAllDone);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOutCubic,
                  padding:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  decoration: BoxDecoration(
                    color: sectionAllDone ? c.neutralChip : c.tealDeep,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      key: ValueKey(sectionAllDone),
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotCard(ScheduleSlot slot) {
    return MedicationCard(
      key: ValueKey('med_${slot.prescription.id}_${slot.time}'),
      item: slot.prescription,
      time: slot.time,
      isTaken: slot.prescription.takenTimes.contains(slot.time),
      profile: profiles.cast<Profile?>().firstWhere(
            (p) => p?.id == slot.prescription.profileId,
            orElse: () => null,
          ),
      onTakeDose: () => onTakeDose(slot.prescription.id, slot.time),
      onViewDetails: () => onViewMedication(slot.prescription),
      onEdit: onEditMedication != null ? () => onEditMedication!(slot.prescription) : null,
      onDelete: onDeleteMedication != null ? () => onDeleteMedication!(slot.prescription.id) : null,
    );
  }
}

/// iOS-only row insertion/deletion animation, modelled on UITableView /
/// SwiftUI `List` row updates (e.g. Settings > Bluetooth when toggled):
///
/// * **Insert** -- the row's height opens from 0 while its content, pinned to
///   the bottom edge and clipped at the top, slides down out from "under" the
///   row above and fades in. Everything below is pushed down in lock-step.
/// * **Delete** -- the reverse: the content fades out quickly while sliding
///   back up underneath the row above, and the rows below glide up to close
///   the gap.
///
/// While a row is closing it keeps rendering the last content it was given,
/// so nothing inside it changes mid-exit. Once fully closed the child is
/// unmounted (no hit-testing, no semantics, no stale state).
class IOSListRowReveal extends StatefulWidget {
  final bool visible;
  final Widget child;
  final Duration duration;

  const IOSListRowReveal({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
  });

  @override
  State<IOSListRowReveal> createState() => _IOSListRowRevealState();
}

class _IOSListRowRevealState extends State<IOSListRowReveal>
    with SingleTickerProviderStateMixin {
  // UIKit's default UIView animation curve (kCAMediaTimingFunctionEaseInEaseOut),
  // which is what table row updates ride on. Symmetric, so it feels identical
  // whether a row is opening or closing.
  static const Curve _sizeCurve = Cubic(0.42, 0.0, 0.58, 1.0);

  late final AnimationController _controller;
  late final CurvedAnimation _size;
  late final CurvedAnimation _opacity;
  late Widget _lastVisibleChild;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.visible ? 1.0 : 0.0,
    )..addStatusListener(_onStatus);
    _size = CurvedAnimation(parent: _controller, curve: _sizeCurve);
    _opacity = CurvedAnimation(
      parent: _controller,
      // Entering: let the row open a touch before the content fades up.
      curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
      // Leaving: content is fully faded by ~60% of the collapse, so it reads
      // as fading away as it tucks back up rather than being clipped.
      reverseCurve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );
    _lastVisibleChild = widget.child;
  }

  void _onStatus(AnimationStatus status) {
    // Rebuild once fully collapsed so the child gets unmounted.
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant IOSListRowReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.visible) _lastVisibleChild = widget.child;
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible && _controller.isDismissed) {
      return const SizedBox(width: double.infinity, height: 0);
    }

    // Tree shape stays constant across animating/resting so child state
    // (swipe actions, pressed states) is never torn down mid-flight.
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final heightFactor = _size.value.clamp(0.0, 1.0);
          final animating = heightFactor < 1.0;
          return Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0),
            child: ClipRect(
              clipper: const _TopEdgeClipper(),
              clipBehavior: animating ? Clip.hardEdge : Clip.none,
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: heightFactor,
                child: child,
              ),
            ),
          );
        },
        child: widget.visible ? widget.child : _lastVisibleChild,
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
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.checkmark_seal,
                color: c.inkMuted.withValues(alpha: 0.4), size: 40),
            const SizedBox(height: 12),
            Text(
              'Nothing due right now',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: c.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan a bottle to add a medication.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
