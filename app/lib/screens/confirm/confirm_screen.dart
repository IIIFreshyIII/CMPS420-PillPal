import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/extractor.dart';
import '../../presentation/widgets/morphing_sheet_grabber.dart';
import '../account/widgets/bedtime_schedule_editor.dart' show kAppleSpring;
import '../medication_form/medication_form.dart';

/// In-app add / OCR verification sheet powered by the shared [MedicationForm].
/// Pops directly with the confirmed [Prescription], or `null` if cancelled.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({
    super.key,
    this.extraction,
    required this.profiles,
    this.isManual = false,
  });

  final Extraction? extraction;
  final List<Profile> profiles;
  final bool isManual;

  static Future<Prescription?> show(
    BuildContext context, {
    Extraction? extraction,
    required List<Profile> profiles,
    bool isManual = false,
  }) {
    return showModalBottomSheet<Prescription>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConfirmScreen(
        extraction: extraction,
        profiles: profiles,
        isManual: isManual,
      ),
    );
  }

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen>
    with SingleTickerProviderStateMixin {
  late final MedicationFormController _formController;
  late final AnimationController _dragOffsetController;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    final defaultProfileId =
        widget.profiles.isNotEmpty ? widget.profiles.first.id : '1';
    _formController = MedicationFormController.fromExtraction(
      extraction: widget.extraction,
      defaultProfileId: defaultProfileId,
      isManual: widget.isManual,
    )..addListener(_onFormChanged);

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

  void _savePrescription() {
    if (!_formController.canSave) return;
    Navigator.of(context).pop(_formController.buildPrescription());
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
      _dismissing = true;
      Navigator.of(context).pop();
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

    return AnimatedBuilder(
      animation: _dragOffsetController,
      builder: (context, child) {
        final dy = _dragOffsetController.value.clamp(0.0, double.infinity);
        final grabberBend = (dy / 65.0).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.94,
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
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _handleHeaderDragUpdate,
                    onVerticalDragEnd: _handleHeaderDragEnd,
                    onVerticalDragCancel: _springBack,
                    child: Column(
                      children: [
                        MorphingSheetGrabber(bend: grabberBend),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              MedicationFormGlassButton(
                                tapKey: const Key('confirm_cancel_button'),
                                icon: CupertinoIcons.xmark,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                              Text(
                                widget.isManual
                                    ? 'Add Medication'
                                    : 'Verify Details',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              MedicationFormGlassButton(
                                tapKey: const Key('confirm_save_button'),
                                icon: CupertinoIcons.checkmark,
                                isPrimary: true,
                                enabled: _formController.canSave,
                                onTap: _savePrescription,
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
                      showQuickRefillButtons: false,
                      autofocusName: widget.isManual,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
