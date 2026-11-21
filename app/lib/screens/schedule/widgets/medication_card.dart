import 'dart:async' show Timer;
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/profile.dart';
import '../../../presentation/widgets/confetti_burst.dart';
import '../../../presentation/widgets/pressable.dart';

/// Individual medication schedule slot card.
///
/// Supports press-and-hold (~375ms) on both iOS and Android to peek into
/// `MedicationQuickViewSheet` immediately while the finger is still down
/// (cancelled immediately on scroll/swipe and blocked while swipe actions are
/// open). On iOS, supports swipe-right for Snooze/Cancel Snooze & Skip and
/// swipe-left for Edit & Delete; tapping any part of a slid card dismisses the
/// open action buttons without marking taken or opening Quick View.
class MedicationCard extends StatefulWidget {
  final Prescription item;
  final String time;
  final bool isTaken;
  final bool isSkipped;
  final bool isSnoozeActive;
  final DateTime? snoozeEndTime;
  final Profile? profile;
  final VoidCallback onTakeDose;
  final VoidCallback onViewDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSnooze;
  final VoidCallback? onCancelSnooze;
  final VoidCallback? onSkip;
  final GlobalKey? targetKey;

  const MedicationCard({
    super.key,
    required this.item,
    required this.time,
    required this.isTaken,
    this.isSkipped = false,
    this.isSnoozeActive = false,
    this.snoozeEndTime,
    required this.profile,
    required this.onTakeDose,
    required this.onViewDetails,
    this.onEdit,
    this.onDelete,
    this.onSnooze,
    this.onCancelSnooze,
    this.onSkip,
    this.targetKey,
  });

  @override
  State<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<MedicationCard>
    with SingleTickerProviderStateMixin {
  late final SlidableController _slidableController;
  final GlobalKey<PressableState> _pressableKey = GlobalKey<PressableState>();
  Timer? _openGuardTimer;
  bool _openGuardActive = false;

  @override
  void initState() {
    super.initState();
    _slidableController = SlidableController(this);
    _slidableController.animation.addListener(_onSlidableAnimationChanged);
  }

  @override
  void didUpdateWidget(covariant MedicationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTaken && !oldWidget.isTaken && _isActionPaneOpen) {
      _slidableController.close();
    }
  }

  @override
  void dispose() {
    _openGuardTimer?.cancel();
    _slidableController.animation.removeListener(_onSlidableAnimationChanged);
    _slidableController.dispose();
    super.dispose();
  }

  bool get _isActionPaneOpen => _slidableController.animation.value > 0.01;

  void _onSlidableAnimationChanged() {
    if (_slidableController.animation.value > 0.005) {
      _pressableKey.currentState?.cancelPendingHold();
    }
  }

  void _triggerViewDetailsGuarded() {
    if (_openGuardActive) return;
    _openGuardActive = true;
    _openGuardTimer?.cancel();
    _openGuardTimer = Timer(const Duration(milliseconds: 350), () {
      _openGuardActive = false;
    });
    widget.onViewDetails();
  }

  void _handleCardTap() {
    if (_isActionPaneOpen) {
      _slidableController.close();
      return;
    }
    _triggerViewDetailsGuarded();
  }

  void _handleCardHold() {
    if (_isActionPaneOpen) return;
    _triggerViewDetailsGuarded();
  }

  void _handleCheckTap() {
    if (_isActionPaneOpen) {
      _slidableController.close();
      return;
    }
    widget.onTakeDose();
  }

  Future<bool> _showDeleteActionSheet(BuildContext context) async {
    final result = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: Text(
          'Delete "${widget.item.name}"?',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        message: const Text(
          'This action cannot be undone and will remove all remaining dose tracking.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Prescription'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _handleDeleteButtonTap(BuildContext context) async {
    final confirmed = await _showDeleteActionSheet(context);
    if (!mounted) return;
    if (confirmed) {
      await _slidableController.openTo(-1.0);
      if (mounted) {
        widget.onDelete?.call();
      }
    } else {
      await _slidableController.close();
    }
  }

  String _snoozeUntilLabel(DateTime endTime) {
    final tod = TimeOfDay(hour: endTime.hour, minute: endTime.minute);
    return 'Snoozed • ${formatTimeOfDayLabel(tod)}';
  }

  Widget _buildCardContent(BuildContext context) {
    final c = context.colors;
    final bool isLow = widget.item.remaining <= 5;
    final parts = widget.time.split(' ');
    final timeDigit = parts.isNotEmpty ? parts[0] : '';
    final timePeriod = parts.length > 1 ? parts[1] : '';

    final instant = MediaQuery.of(context).disableAnimations;
    final radius = BorderRadius.circular(18);
    final bool isDimmed = widget.isTaken || widget.isSkipped;
    final bool showSnoozeBadge =
        widget.isSnoozeActive && !widget.isTaken && !widget.isSkipped;

    final content = AnimatedOpacity(
      opacity: isDimmed ? 0.45 : 1.0,
      duration: instant ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Pressable(
        key: _pressableKey,
        onTap: _handleCardTap,
        onHold: _handleCardHold,
        holdDuration: const Duration(milliseconds: 375),
        canTriggerHold: () => !_isActionPaneOpen,
        borderRadius: radius,
        rippleColor: c.tealRipple,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDimmed ? c.background : c.surface,
          borderRadius: radius,
          border: Border.all(
            color: showSnoozeBadge
                ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                : c.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: c.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // The check lives above the card's own tap handler, so pressing it
        // never also shrinks/ripples the card or opens the quick view.
        foreground: Padding(
          padding: const EdgeInsets.only(right: 16 - (48 - 34) / 2),
          child: Align(
            alignment: Alignment.centerRight,
            child: _DoseCheck(
              isTaken: widget.isTaken,
              isSkipped: widget.isSkipped,
              profileColor: widget.profile?.color,
              shouldDismissOnly: () => _isActionPaneOpen,
              onTap: _handleCheckTap,
              instant: instant,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: c.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeDigit,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.tealDeep,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    timePeriod,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.tealDeep,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          widget.item.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.item.dosage,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.isSkipped)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 1.5, horizontal: 6),
                        decoration: BoxDecoration(
                          color: c.neutralChip,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Skipped',
                          style: TextStyle(
                            color: c.neutralInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    )
                  else if (showSnoozeBadge)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        key: ValueKey('snooze_badge_${widget.item.id}_${widget.time}'),
                        padding: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.clock_fill,
                              size: 10,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.snoozeEndTime != null
                                  ? _snoozeUntilLabel(widget.snoozeEndTime!)
                                  : 'Snoozed',
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (widget.profile != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 7),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: widget.profile!.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.profile!.name,
                            style: TextStyle(
                              color: c.tagText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Text(
                        '${widget.item.remaining} left ${isLow ? '• Refill Soon' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isLow ? FontWeight.w700 : FontWeight.w500,
                          color: isLow ? c.alert : c.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Room for the check, which is drawn by `foreground` above.
            const SizedBox(width: 10 + 34),
          ],
        ),
      ),
    );

    if (widget.targetKey != null) {
      return KeyedSubtree(
        key: widget.targetKey,
        child: content,
      );
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final cardContent = _buildCardContent(context);

    final showSnoozeAction = !widget.isTaken &&
        !widget.isSkipped &&
        ((widget.isSnoozeActive && widget.onCancelSnooze != null) ||
            (!widget.isSnoozeActive && widget.onSnooze != null));
    final showSkipAction = !widget.isTaken && widget.onSkip != null;
    final hasStartActions = showSnoozeAction || showSkipAction;
    final hasEndActions = widget.onDelete != null || widget.onEdit != null;
    final isIOS =
        Theme.of(context).platform == TargetPlatform.iOS || Platform.isIOS;

    // On non-iOS platforms or if no actions are provided, render plain card.
    if (!isIOS || (!hasStartActions && !hasEndActions)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: cardContent,
      );
    }

    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, cardConstraints) {
          final cardWidth = cardConstraints.maxWidth.isFinite
              ? cardConstraints.maxWidth
              : 353.0;

          return Slidable(
            key: ValueKey('slidable_${widget.item.id}_${widget.time}'),
            controller: _slidableController,
            groupTag: 'medication_cards',
            // Swipe Right (startActionPane): Adherence Actions (Snooze / Cancel Snooze, Skip)
            startActionPane: hasStartActions
                ? ActionPane(
                    motion: const BehindMotion(),
                    extentRatio: 0.32,
                    children: [
                      CustomSlidableAction(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        onPressed: (_) {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (showSnoozeAction)
                              GestureDetector(
                                key: widget.isSnoozeActive
                                    ? const Key('card_swipe_cancel_snooze')
                                    : const Key('card_swipe_snooze'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _slidableController.close();
                                  if (widget.isSnoozeActive) {
                                    widget.onCancelSnooze?.call();
                                  } else {
                                    widget.onSnooze?.call();
                                  }
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: widget.isSnoozeActive
                                        ? CupertinoColors.destructiveRed
                                        : const Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (widget.isSnoozeActive
                                                ? CupertinoColors.destructiveRed
                                                : const Color(0xFFF59E0B))
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      widget.isSnoozeActive
                                          ? CupertinoIcons.bell_slash_fill
                                          : CupertinoIcons.clock_fill,
                                      color: CupertinoColors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            if (showSnoozeAction && showSkipAction)
                              const SizedBox(width: 8),
                            if (showSkipAction)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _slidableController.close();
                                  widget.onSkip?.call();
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF64748B),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: c.ink.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      widget.isSkipped
                                          ? CupertinoIcons
                                              .arrow_counterclockwise
                                          : CupertinoIcons.forward_fill,
                                      color: CupertinoColors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                : null,
            // Swipe Left (endActionPane): Prescription Management (Edit, Delete with lengthening capsule oval)
            endActionPane: hasEndActions
                ? ActionPane(
                    motion: const BehindMotion(),
                    extentRatio: 0.32,
                    dismissible: widget.onDelete != null
                        ? DismissiblePane(
                            dismissThreshold: 0.65,
                            closeOnCancel: true,
                            confirmDismiss: () async {
                              if (!context.mounted) return false;
                              final confirmed =
                                  await _showDeleteActionSheet(context);
                              if (!confirmed && mounted) {
                                _slidableController.close();
                              }
                              return confirmed;
                            },
                            onDismissed: () => widget.onDelete?.call(),
                            motion: _EndActionPaneContent(
                              controller: _slidableController,
                              cardWidth: cardWidth,
                              onEdit: widget.onEdit != null
                                  ? () {
                                      _slidableController.close();
                                      widget.onEdit?.call();
                                    }
                                  : null,
                              onDelete: () => _handleDeleteButtonTap(context),
                            ),
                          )
                        : null,
                    children: [
                      Expanded(
                        child: _EndActionPaneContent(
                          controller: _slidableController,
                          cardWidth: cardWidth,
                          onEdit: widget.onEdit != null
                              ? () {
                                  _slidableController.close();
                                  widget.onEdit?.call();
                                }
                              : null,
                          onDelete: widget.onDelete != null
                              ? () => _handleDeleteButtonTap(context)
                              : null,
                        ),
                      ),
                    ],
                  )
                : null,
            child: cardContent,
          );
        },
      ),
    );
  }
}

/// Dynamic motion rendered inside [ActionPane] and [DismissiblePane] when swiping left.
/// The red Delete circle keeps a constant 44px capsule height and lengthens leftward
/// into an oval with the trash icon anchored at its leading edge, while the Edit
/// button and medication card maintain constant spacing in front of it.
class _EndActionPaneContent extends StatelessWidget {
  final SlidableController controller;
  final double cardWidth;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _EndActionPaneContent({
    required this.controller,
    required this.cardWidth,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: controller.animation,
      builder: (context, _) {
        final progress = controller.animation.value;
        final overswipeExtra =
            ((progress - 0.32) * cardWidth).clamp(0.0, cardWidth);
        final ovalWidth = 44.0 + overswipeExtra;
        final editRight = 52.0 + overswipeExtra;

        return SizedBox.expand(
          child: Stack(
            alignment: Alignment.centerRight,
            clipBehavior: Clip.none,
            children: [
              // 1. Fixed-height red capsule oval with trash icon anchored at the front
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDelete,
                    child: Container(
                      height: 44.0,
                      width: ovalWidth,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 12.0),
                      decoration: BoxDecoration(
                        color: CupertinoColors.destructiveRed,
                        borderRadius: BorderRadius.circular(22.0),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.destructiveRed
                                .withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.trash_fill,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              // 2. Slate circular Edit button staying in front of the expanding oval
              if (onEdit != null)
                Positioned(
                  right: editRight,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onEdit,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF64748B),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: c.ink.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.pencil,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The 34px dose check, with a 48x48 touch target (Material minimum). Marking
/// taken pops the check in with a medium haptic; un-marking just ticks.
/// When [shouldDismissOnly] returns true (open swipe action buttons), tapping
/// delegates to [onTap] without haptic celebration so the card simply closes.
class _DoseCheck extends StatelessWidget {
  const _DoseCheck({
    required this.isTaken,
    this.isSkipped = false,
    required this.profileColor,
    required this.shouldDismissOnly,
    required this.onTap,
    required this.instant,
  });

  final bool isTaken;
  final bool isSkipped;
  final Color? profileColor;
  final bool Function() shouldDismissOnly;
  final VoidCallback onTap;
  final bool instant;

  void _celebrate(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final c = context.colors;
    ConfettiBurst.show(
      context,
      origin: box.localToGlobal(box.size.center(Offset.zero)),
      colors: [
        c.teal,
        c.tealDeep,
        c.mint,
        c.headerTeal,
        if (profileColor != null) profileColor!,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final circle = AnimatedContainer(
      duration: instant ? Duration.zero : const Duration(milliseconds: 180),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isTaken
            ? c.teal
            : isSkipped
                ? c.neutralChip
                : Colors.transparent,
        border: Border.all(
          color: isTaken
              ? c.teal
              : isSkipped
                  ? c.neutralInk.withValues(alpha: 0.3)
                  : c.inkMuted,
          width: 2,
        ),
      ),
      child: isTaken
          ? Icon(CupertinoIcons.checkmark, size: 20, color: c.onTeal)
          : isSkipped
              ? Icon(CupertinoIcons.forward, size: 16, color: c.neutralInk)
              : null,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (shouldDismissOnly()) {
          onTap();
          return;
        }
        if (isTaken || isSkipped) {
          HapticFeedback.selectionClick();
        } else {
          HapticFeedback.mediumImpact();
          _celebrate(context);
        }
        onTap();
      },
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: TweenAnimationBuilder<double>(
            // Keyed on isTaken so the pop replays each time it's taken.
            key: ValueKey(isTaken),
            tween: Tween(begin: isTaken && !instant ? 0.6 : 1.0, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: circle,
          ),
        ),
      ),
    );
  }
}
