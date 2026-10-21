import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/theme/pillpal_colors.dart';
import '../../../presentation/widgets/confetti_burst.dart';
import '../../../presentation/widgets/pressable.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/profile.dart';

/// Individual medication schedule slot card.
/// On iOS, supports swipe-to-reveal edit (pencil) and delete (trash with
/// expanding overswipe oval and Cupertino confirmation action sheet).
/// On Android, remains a non-slidable card where tapping opens the detail sheet.
class MedicationCard extends StatefulWidget {
  final Prescription item;
  final String time;
  final bool isTaken;
  final Profile? profile;
  final VoidCallback onTakeDose;
  final VoidCallback onViewDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MedicationCard({
    super.key,
    required this.item,
    required this.time,
    required this.isTaken,
    required this.profile,
    required this.onTakeDose,
    required this.onViewDetails,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<MedicationCard>
    with SingleTickerProviderStateMixin {
  late final SlidableController _slidableController;

  @override
  void initState() {
    super.initState();
    _slidableController = SlidableController(this);
  }

  @override
  void dispose() {
    _slidableController.dispose();
    super.dispose();
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

  Widget _buildCardContent(BuildContext context) {
    final c = context.colors;
    final bool isLow = widget.item.remaining <= 5;
    final parts = widget.time.split(' ');
    final timeDigit = parts.isNotEmpty ? parts[0] : '';
    final timePeriod = parts.length > 1 ? parts[1] : '';

    final instant = MediaQuery.of(context).disableAnimations;
    final radius = BorderRadius.circular(18);

    return AnimatedOpacity(
      opacity: widget.isTaken ? 0.45 : 1.0,
      duration: instant ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Pressable(
        onTap: widget.onViewDetails,
        borderRadius: radius,
        rippleColor: c.tealRipple,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isTaken ? c.background : c.surface,
          borderRadius: radius,
          border: Border.all(color: c.borderLight),
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
              profileColor: widget.profile?.color,
              onTap: widget.onTakeDose,
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
  }

  @override
  Widget build(BuildContext context) {
    final cardContent = _buildCardContent(context);

    // On non-iOS platforms or if no delete action is provided, render plain card.
    if (!Platform.isIOS || widget.onDelete == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: cardContent,
      );
    }

    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedBuilder(
        animation: _slidableController.animation,
        builder: (context, child) {
          final ratio = _slidableController.animation.value;
          final isOverswiping = ratio > 0.32;

          return Slidable(
            key: ValueKey('slidable_${widget.item.id}_${widget.time}'),
            controller: _slidableController,
            groupTag: 'medication_cards',
            endActionPane: ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.32,
              dismissible: DismissiblePane(
                dismissThreshold: 0.65,
                closeOnCancel: true,
                confirmDismiss: () async {
                  final confirmed = await _showDeleteActionSheet(context);
                  if (!confirmed && mounted) {
                    _slidableController.close();
                  }
                  return confirmed;
                },
                onDismissed: () => widget.onDelete?.call(),
              ),
              children: [
                CustomSlidableAction(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  onPressed: (_) {},
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final overswipeOffset = isOverswiping
                          ? (ratio - 0.32) * availableWidth * 3.2
                          : 0.0;
                      final ovalWidth = isOverswiping
                          ? (44.0 + overswipeOffset).clamp(44.0, availableWidth)
                          : 44.0;
                      final editRight = isOverswiping ? (ovalWidth + 8.0) : 52.0;
                      final editOpacity = isOverswiping
                          ? (1.0 - (ratio - 0.42) * 4.0).clamp(0.0, 1.0)
                          : 1.0;

                      return Container(
                        height: double.infinity,
                        alignment: Alignment.centerRight,
                        child: Stack(
                          alignment: Alignment.centerRight,
                          clipBehavior: Clip.none,
                          children: [
                            // Expanding red background oval
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Container(
                                  height: 44,
                                  width: ovalWidth,
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.destructiveRed,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                              ),
                            ),
                            // Grey pencil edit button moving in tandem with card
                            if (widget.onEdit != null)
                              Positioned(
                                right: editRight,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Opacity(
                                    opacity: editOpacity,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        _slidableController.close();
                                        widget.onEdit?.call();
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
                                        child: const Icon(
                                          CupertinoIcons.pencil,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Red trash icon tracking leading edge of oval
                            Positioned(
                              right: isOverswiping
                                  ? (ovalWidth - 44.0)
                                      .clamp(0.0, availableWidth - 44.0)
                                  : 0,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    final confirmed =
                                        await _showDeleteActionSheet(context);
                                    if (confirmed) {
                                      widget.onDelete?.call();
                                    } else if (mounted) {
                                      _slidableController.close();
                                    }
                                  },
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Center(
                                      child: Icon(
                                        CupertinoIcons.trash_fill,
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
                  ),
                ),
              ],
            ),
            child: cardContent,
          );
        },
      ),
    );
  }
}

/// The 34px dose check, with a 48x48 touch target (Material minimum). Marking
/// taken pops the check in with a medium haptic; un-marking just ticks.
class _DoseCheck extends StatelessWidget {
  const _DoseCheck({
    required this.isTaken,
    required this.profileColor,
    required this.onTap,
    required this.instant,
  });

  final bool isTaken;
  final Color? profileColor;
  final VoidCallback onTap;
  final bool instant;

  /// A tiny burst from the check's centre, in theme colours plus this
  /// dose's profile colour. ConfettiBurst skips it under "Remove animations".
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
        color: isTaken ? c.teal : Colors.transparent,
        border: Border.all(
          color: isTaken ? c.teal : c.inkMuted,
          width: 2,
        ),
      ),
      child: isTaken
          ? Icon(CupertinoIcons.checkmark, size: 20, color: c.onTeal)
          : null,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isTaken) {
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
