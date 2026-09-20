import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/profile.dart';

class MedicationCard extends StatefulWidget {
  final Prescription item;
  final Profile? profile;
  final VoidCallback onTakeDose;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const MedicationCard({
    super.key,
    required this.item,
    required this.profile,
    required this.onTakeDose,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<MedicationCard> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final bool isLow = widget.item.remaining <= 5;
    final parts = widget.item.time.split(' ');
    final timeDigit = parts.isNotEmpty ? parts[0] : '';
    final timePeriod = parts.length > 1 ? parts[1] : '';

    return AnimatedBuilder(
      animation: _slidableController.animation,
      builder: (context, child) {
        final ratio = _slidableController.animation.value;
        final isOverswiping = ratio > 0.32;

        return Slidable(
          key: ValueKey('slidable_${widget.item.id}'),
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
              onDismissed: widget.onDelete,
            ),
            children: [
              CustomSlidableAction(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                onPressed: (_) {},
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;

                    return Container(
                      height: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      alignment: Alignment.centerRight,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Container(
                                height: 44,
                                width: isOverswiping
                                    ? (44 + (ratio - 0.32) * availableWidth * 3.2).clamp(44.0, availableWidth)
                                    : 44,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.destructiveRed,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 52,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Opacity(
                                opacity: (1.0 - ((ratio - 0.32) * 6)).clamp(0.0, 1.0),
                                child: GestureDetector(
                                  onTap: () {
                                    _slidableController.close();
                                    widget.onEdit();
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF64748B),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.textPrimary.withValues(alpha: 0.08),
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
                          Positioned(
                            right: isOverswiping
                                ? ((ratio - 0.32) * availableWidth * 3.2).clamp(0.0, availableWidth - 44)
                                : 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  final confirmed = await _showDeleteActionSheet(context);
                                  if (confirmed) {
                                    widget.onDelete();
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
          child: child!,
        );
      },
      child: Opacity(
        opacity: widget.item.takenToday ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.item.takenToday ? AppTheme.background : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderLight),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textPrimary.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.lightPillTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeDigit,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.interactiveTeal,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      timePeriod,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.interactiveTeal.withValues(alpha: 0.8),
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
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.item.dosage,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (widget.profile != null)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: widget.profile!.color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.profile!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Text(
                          '${widget.item.remaining} left ${isLow ? '• Refill Soon' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isLow ? FontWeight.w700 : FontWeight.w500,
                            color: isLow ? AppTheme.lowStockAlert : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onTakeDose,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.item.takenToday ? AppTheme.interactiveTeal : Colors.transparent,
                    border: Border.all(
                      color: widget.item.takenToday ? AppTheme.interactiveTeal : const Color(0xFFC7D8D7),
                      width: 2,
                    ),
                  ),
                  child: widget.item.takenToday
                      ? const Icon(CupertinoIcons.checkmark, size: 20, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}