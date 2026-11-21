import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../presentation/widgets/morphing_sheet_grabber.dart';
import '../../presentation/widgets/pressable.dart';
import '../account/widgets/bedtime_schedule_editor.dart' show kAppleSpring;

/// A small, read-only "quick look" at a medication -- tapping or holding a med
/// on the Schedule page opens this instead of jumping straight into the full
/// editable [MedicationDetailSheet].
///
/// Supports interactive vertical gestures:
/// - **Swipe down** morphs the grabber into a downward chevron (`v`) and
///   dismisses the sheet.
/// - **Swipe up** (past ~50px) morphs the grabber into an upward chevron (`^`),
///   closes Quick View, and immediately opens `MedicationDetailSheet` (Edit).
class MedicationQuickViewSheet extends StatefulWidget {
  const MedicationQuickViewSheet({
    super.key,
    required this.prescription,
    required this.profiles,
    required this.onEdit,
    this.timeSlot,
    this.isTaken = false,
    this.isSkipped = false,
    this.isSnoozeActive = false,
    this.snoozeEndTime,
    this.onSnooze,
    this.onCancelSnooze,
    this.onSkip,
  });

  final Prescription prescription;
  final List<Profile> profiles;
  final VoidCallback onEdit;
  final String? timeSlot;
  final bool isTaken;
  final bool isSkipped;
  final bool isSnoozeActive;
  final DateTime? snoozeEndTime;
  final VoidCallback? onSnooze;
  final VoidCallback? onCancelSnooze;
  final VoidCallback? onSkip;

  static Future<void> show(
    BuildContext context, {
    required Prescription prescription,
    required List<Profile> profiles,
    required VoidCallback onEdit,
    String? timeSlot,
    bool isTaken = false,
    bool isSkipped = false,
    bool isSnoozeActive = false,
    DateTime? snoozeEndTime,
    VoidCallback? onSnooze,
    VoidCallback? onCancelSnooze,
    VoidCallback? onSkip,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicationQuickViewSheet(
        prescription: prescription,
        profiles: profiles,
        onEdit: onEdit,
        timeSlot: timeSlot,
        isTaken: isTaken,
        isSkipped: isSkipped,
        isSnoozeActive: isSnoozeActive,
        snoozeEndTime: snoozeEndTime,
        onSnooze: onSnooze,
        onCancelSnooze: onCancelSnooze,
        onSkip: onSkip,
      ),
    );
  }

  @override
  State<MedicationQuickViewSheet> createState() =>
      _MedicationQuickViewSheetState();
}

class _MedicationQuickViewSheetState extends State<MedicationQuickViewSheet>
    with SingleTickerProviderStateMixin {
  static const double _kSwipeUpEditThreshold = 50.0;
  static const double _kSwipeDownDismissThreshold = 80.0;

  /// Raw vertical drag offset: negative = dragging upward, positive = dragging downward.
  late final AnimationController _dragController;
  bool _actionTriggered = false;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_actionTriggered) return;
    final next = _dragController.value + details.delta.dy;
    _dragController.value = next;

    // Snappy swipe-up escalation: the moment the user drags upward past ~50px,
    // immediately close Quick View and open the full Edit sheet.
    if (next <= -_kSwipeUpEditThreshold) {
      _actionTriggered = true;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      widget.onEdit();
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_actionTriggered) return;
    final velocity = details.primaryVelocity ?? 0.0;
    final offset = _dragController.value;

    // Quick upward flick also escalates cleanly into Edit.
    if (velocity < -650.0 && offset < -12.0) {
      _actionTriggered = true;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      widget.onEdit();
      return;
    }

    // Downward drag or flick dismisses Quick View.
    if (offset > _kSwipeDownDismissThreshold || velocity > 500.0) {
      _actionTriggered = true;
      Navigator.of(context).pop();
      return;
    }

    _springBack();
  }

  void _springBack() {
    if (_actionTriggered) return;
    final instant = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (instant) {
      _dragController.value = 0.0;
      return;
    }
    final sim = SpringSimulation(
      kAppleSpring,
      _dragController.value,
      0.0,
      0.0,
    );
    _dragController.animateWith(sim);
  }

  Widget _buildGlassCircleButton(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final c = context.colors;
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPrimary ? c.teal.withValues(alpha: 0.90) : c.glass,
              shape: BoxShape.circle,
              border: Border.all(
                color: isPrimary ? c.teal : c.glassRim,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.liftShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 18, color: isPrimary ? c.onTeal : c.ink),
            ),
          ),
        ),
      ),
    );
  }

  String? _foodLabel(String? foodInstruction) {
    return switch (foodInstruction) {
      'with_food' => 'Take with food',
      'without_food' => 'Take without food',
      _ => null,
    };
  }

  String _snoozeBannerText() {
    if (widget.snoozeEndTime != null) {
      final tod = TimeOfDay(
        hour: widget.snoozeEndTime!.hour,
        minute: widget.snoozeEndTime!.minute,
      );
      return 'Snoozed until ${formatTimeOfDayLabel(tod)}';
    }
    return 'Snooze active';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final prescription = widget.prescription;
    final profile = widget.profiles.firstWhere(
      (p) => p.id == prescription.profileId,
      orElse: () => const Profile(id: '0', name: 'General', color: Colors.grey),
    );
    final isLow = prescription.remaining <= 5;
    final foodLabel = _foodLabel(prescription.foodInstruction);

    final showSnoozeButton = !widget.isTaken &&
        !widget.isSkipped &&
        ((widget.isSnoozeActive && widget.onCancelSnooze != null) ||
            (!widget.isSnoozeActive && widget.onSnooze != null));
    final showSkipButton = !widget.isTaken && widget.onSkip != null;
    final showSnoozeBanner =
        widget.isSnoozeActive && !widget.isTaken && !widget.isSkipped;

    return GestureDetector(
      key: const Key('quick_view_drag_surface'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: _handleVerticalDragEnd,
      onVerticalDragCancel: _springBack,
      child: AnimatedBuilder(
        animation: _dragController,
        builder: (context, _) {
          final rawDy = _dragController.value;
          // 1:1 follow downward; gentle rubber-band lift upward.
          final visualDy = rawDy >= 0
              ? rawDy
              : -((-rawDy) * 0.42).clamp(0.0, 26.0);
          final double grabberBend;
          if (rawDy < 0) {
            grabberBend = -((-rawDy) / _kSwipeUpEditThreshold).clamp(0.0, 1.0);
          } else {
            grabberBend = (rawDy / 65.0).clamp(0.0, 1.0);
          }

          return Transform.translate(
            offset: Offset(0, visualDy),
            child: Container(
              decoration: BoxDecoration(
                color: c.background,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MorphingSheetGrabber(
                      key: const Key('quick_view_grabber'),
                      bend: grabberBend,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGlassCircleButton(
                            context,
                            icon: CupertinoIcons.xmark,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          Text(
                            'Medication',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          _buildGlassCircleButton(
                            context,
                            key: const Key('quick_view_edit_button'),
                            icon: CupertinoIcons.pencil,
                            isPrimary: true,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onEdit();
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: c.borderLight),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: c.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: c.cardShadow,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color:
                                        profile.color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(CupertinoIcons.capsule_fill,
                                      color: profile.color, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              prescription.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: c.ink,
                                                letterSpacing: -0.4,
                                              ),
                                            ),
                                          ),
                                          if (prescription
                                              .dosage.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                prescription.dosage,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: c.inkMuted),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        foodLabel != null
                                            ? 'Prescribed to ${profile.name} • $foodLabel'
                                            : 'Prescribed to ${profile.name}',
                                        style: TextStyle(
                                            fontSize: 13, color: c.inkMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isLow)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: c.alertTint,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Low Stock',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: c.alert,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (showSnoozeBanner) ...[
                              const SizedBox(height: 12),
                              Container(
                                key: const Key('quick_view_snooze_banner'),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.clock_fill,
                                      size: 14,
                                      color: Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _snoozeBannerText(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Divider(height: 1, color: c.borderLight),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickStat(
                                    icon: CupertinoIcons.clock,
                                    label: prescription.isAsNeeded
                                        ? 'Schedule'
                                        : (prescription.reminderTimes.length > 1
                                            ? 'Reminder Times'
                                            : 'Reminder Time'),
                                    value: prescription.isAsNeeded
                                        ? 'As Needed'
                                        : prescription.reminderTimes.join(', '),
                                  ),
                                ),
                                Container(
                                    width: 1, height: 36, color: c.borderLight),
                                Expanded(
                                  child: _QuickStat(
                                    icon: CupertinoIcons.calendar,
                                    label: 'Days Supply Left',
                                    value: '${prescription.daysSupply} days',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showSnoozeButton || showSkipButton)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Row(
                          children: [
                            if (showSnoozeButton)
                              Expanded(
                                child: widget.isSnoozeActive
                                    ? Pressable(
                                        key: const Key(
                                            'quick_view_cancel_snooze_button'),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          widget.onCancelSnooze!();
                                        },
                                        scale: 0.96,
                                        borderRadius: BorderRadius.circular(16),
                                        rippleColor: CupertinoColors
                                            .destructiveRed
                                            .withValues(alpha: 0.14),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 13),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.destructiveRed
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: CupertinoColors
                                                .destructiveRed
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              CupertinoIcons.bell_slash_fill,
                                              size: 17,
                                              color: CupertinoColors
                                                  .destructiveRed,
                                            ),
                                            SizedBox(width: 7),
                                            Text(
                                              'Cancel Snooze',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: CupertinoColors
                                                    .destructiveRed,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Pressable(
                                        key: const Key(
                                            'quick_view_snooze_button'),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          widget.onSnooze!();
                                        },
                                        scale: 0.96,
                                        borderRadius: BorderRadius.circular(16),
                                        rippleColor: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.16),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 13),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.32),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              CupertinoIcons.clock_fill,
                                              size: 17,
                                              color: Color(0xFFD97706),
                                            ),
                                            SizedBox(width: 7),
                                            Text(
                                              'Snooze',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            if (showSnoozeButton && showSkipButton)
                              const SizedBox(width: 12),
                            if (showSkipButton)
                              Expanded(
                                child: Pressable(
                                  key: const Key('quick_view_skip_button'),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onSkip!();
                                  },
                                  scale: 0.96,
                                  borderRadius: BorderRadius.circular(16),
                                  rippleColor: c.ink.withValues(alpha: 0.08),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: c.borderLight),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        widget.isSkipped
                                            ? CupertinoIcons
                                                .arrow_counterclockwise
                                            : CupertinoIcons.forward_fill,
                                        size: 17,
                                        color: c.ink,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        widget.isSkipped
                                            ? 'Undo Skip'
                                            : 'Skip Dose',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: c.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Icon(icon, size: 18, color: c.teal),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: c.ink),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted),
        ),
      ],
    );
  }
}
