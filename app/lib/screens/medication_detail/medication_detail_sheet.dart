import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../presentation/widgets/morphing_sheet_grabber.dart';
import '../account/widgets/bedtime_schedule_editor.dart' show kAppleSpring;
import '../medication_form/medication_form.dart';

/// Full-featured Edit sheet powered by the shared [MedicationForm].
/// Supports downward swipe-to-dismiss with a morphing downward chevron grabber
/// while still guarding unsaved edits with a Discard Changes confirmation.
class MedicationDetailSheet extends StatefulWidget {
  final Prescription prescription;
  final List<Profile> profiles;
  final ValueChanged<Prescription> onUpdate;
  final VoidCallback onDelete;

  const MedicationDetailSheet({
    super.key,
    required this.prescription,
    required this.profiles,
    required this.onUpdate,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required Prescription prescription,
    required List<Profile> profiles,
    required ValueChanged<Prescription> onUpdate,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Custom drag handling below runs our morphing chevron animation and
      // unsaved-changes discard check cleanly on swipe-down.
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => MedicationDetailSheet(
        prescription: prescription,
        profiles: profiles,
        onUpdate: onUpdate,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<MedicationDetailSheet> createState() => _MedicationDetailSheetState();
}

class _MedicationDetailSheetState extends State<MedicationDetailSheet>
    with SingleTickerProviderStateMixin {
  late final MedicationFormController _formController;
  late final AnimationController _dragOffsetController;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _formController =
        MedicationFormController.fromPrescription(widget.prescription)
          ..addListener(_onFormChanged);
    _dragOffsetController = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _formController.removeListener(_onFormChanged);
    _formController.dispose();
    _dragOffsetController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasUnsavedChanges => _formController.hasUnsavedChanges;

  void _handleClose() {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Discard changes?'),
        message:
            const Text('Your edits to this medication have not been saved.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Discard Changes'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep Editing'),
        ),
      ),
    );
  }

  void _saveChanges() {
    if (!_formController.canSave) return;
    HapticFeedback.lightImpact();
    final updated = _formController.buildPrescription(
      idOverride: widget.prescription.id,
    );
    widget.onUpdate(updated);
    Navigator.pop(context);
  }

  void _confirmDelete() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Delete "${widget.prescription.name}"?'),
        message: const Text(
            'This will remove the medication and its tracking history.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete Prescription'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _handleHeaderDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    final next = (_dragOffsetController.value + details.delta.dy)
        .clamp(0.0, double.infinity);
    _dragOffsetController.value = next;
  }

  void _handleHeaderDragEnd(DragEndDetails details) {
    if (_dismissing) return;
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffsetController.value > 85.0 || velocity > 500.0) {
      if (!_hasUnsavedChanges) {
        _dismissing = true;
        HapticFeedback.selectionClick();
        Navigator.pop(context);
      } else {
        _springBack();
        _handleClose();
      }
      return;
    }
    _springBack();
  }

  void _springBack() {
    final instant = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (instant) {
      _dragOffsetController.value = 0.0;
      return;
    }
    final sim = SpringSimulation(
      kAppleSpring,
      _dragOffsetController.value,
      0.0,
      0.0,
    );
    _dragOffsetController.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleClose();
      },
      child: AnimatedBuilder(
        animation: _dragOffsetController,
        builder: (context, _) {
          final dy = _dragOffsetController.value.clamp(0.0, double.infinity);
          final grabberBend = (dy / 65.0).clamp(0.0, 1.0);

          return Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: c.background,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    GestureDetector(
                      key: const Key('detail_sheet_drag_header'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _handleHeaderDragUpdate,
                      onVerticalDragEnd: _handleHeaderDragEnd,
                      onVerticalDragCancel: _springBack,
                      child: Column(
                        children: [
                          MorphingSheetGrabber(
                            key: const Key('detail_sheet_grabber'),
                            bend: grabberBend,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                MedicationFormGlassButton(
                                  key: const Key('detail_close_button'),
                                  icon: CupertinoIcons.xmark,
                                  onTap: _handleClose,
                                ),
                                Text(
                                  'Prescription Details',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: c.ink,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                MedicationFormGlassButton(
                                  key: const Key('detail_save_button'),
                                  icon: CupertinoIcons.checkmark,
                                  isPrimary: true,
                                  enabled: _formController.canSave,
                                  onTap: _saveChanges,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: c.borderLight),
                    Expanded(
                      child: MedicationForm(
                        controller: _formController,
                        profiles: widget.profiles,
                        showProfilePicker: true,
                        showQuickRefillButtons: true,
                        extraBottomChildren: [
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              key: const Key('detail_delete_button'),
                              color: c.surface,
                              borderRadius: BorderRadius.circular(16),
                              onPressed: _confirmDelete,
                              child: const Text(
                                'Delete Prescription',
                                style: TextStyle(
                                  color: CupertinoColors.destructiveRed,
                                  fontWeight: FontWeight.w700,
                                ),
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
