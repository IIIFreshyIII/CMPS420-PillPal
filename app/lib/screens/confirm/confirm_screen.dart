import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/ner/postprocess.dart' show formOptions;
import '../../core/theme/app_theme.dart';
import '../../data/models/profile.dart';
import '../../data/models/prescription.dart';
import '../../data/services/extraction_mapper.dart';
import '../../data/services/extractor.dart';
import 'reminder_schedule_sheet.dart';

/// Step 1 of the scan-to-save flow: confirm *what* the medication is. Every
/// field editable, low-confidence fields flagged with the raw matched text
/// -- never a fabricated confidence score (Phase 2 wireframe §Confirm,
/// `med-tracker-spec.md` §1: "no confidence-based shortcuts"). The hero
/// pill's name and profile are directly editable here; *when* to be
/// reminded is step 2, handled by `ReminderScheduleSheet` (pushed from the
/// checkmark below) -- that's the only place an [Extraction] finally
/// becomes a real [Prescription] (`extraction_mapper.dart`).
///
/// Styled to match `MedicationDetailSheet` -- same modal-sheet chrome, hero
/// card, and grouped section cards -- so scanning a label and editing an
/// existing medication feel like the same screen family.
///
/// Pops with the built [Prescription], or `null` if the user backs out at
/// either step.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.extraction, required this.profiles});

  final Extraction extraction;
  final List<Profile> profiles;

  static Future<Prescription?> show(
    BuildContext context, {
    required Extraction extraction,
    required List<Profile> profiles,
  }) {
    return showModalBottomSheet<Prescription>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConfirmScreen(extraction: extraction, profiles: profiles),
    );
  }

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final TextEditingController _drug;
  late final TextEditingController _strength;
  late final TextEditingController _dose;
  late final TextEditingController _daysSupply;
  String? _formValue;
  late String _profileId;

  @override
  void initState() {
    super.initState();
    final e = widget.extraction;
    _drug = TextEditingController(text: e.drug ?? '');
    _strength = TextEditingController(text: e.strength ?? '');
    _dose = TextEditingController(text: e.dose ?? '');
    _daysSupply = TextEditingController(text: e.daysSupply?.toString() ?? '');
    // Only pre-select if OCR's value is already one of the canonical forms --
    // an unrecognized raw value (e.g. a garbled read) must never silently
    // become a different, wrong dropdown choice.
    _formValue = (e.form != null && formOptions.contains(e.form)) ? e.form : null;
    _profileId = widget.profiles.isNotEmpty ? widget.profiles.first.id : '';
  }

  @override
  void dispose() {
    _drug.dispose();
    _strength.dispose();
    _dose.dispose();
    _daysSupply.dispose();
    super.dispose();
  }

  bool get _canContinue => _drug.text.trim().isNotEmpty && _profileId.isNotEmpty;

  /// A flagged field's error message -- the raw OCR text, never a fabricated
  /// confidence score. `null` (no error shown) when the field is recognized.
  String? _flagText(bool recognized, String? rawIfFlagged) {
    if (recognized || rawIfFlagged == null) return null;
    return 'Verify -- OCR matched: "$rawIfFlagged"';
  }

  Profile get _selectedProfile => widget.profiles.firstWhere(
        (p) => p.id == _profileId,
        orElse: () => const Profile(id: '0', name: 'General', color: Colors.grey),
      );

  Future<void> _confirmAndContinue() async {
    final reminderTimes = await ReminderScheduleSheet.show(
      context,
      frequency: widget.extraction.frequency,
      bedtime: _selectedProfile.bedtime,
    );
    if (reminderTimes == null || !mounted) return;

    final days = int.tryParse(_daysSupply.text.trim()) ?? 0;
    final prescription = mapExtractionToPrescription(
      widget.extraction,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      profileId: _profileId,
      reminderTimes: reminderTimes,
      remaining: days,
      nameOverride: _drug.text.trim(),
      dosageOverride: [_strength.text, _dose.text, _formValue ?? '']
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(', '),
      daysSupplyOverride: days,
    );
    Navigator.of(context).pop(prescription);
  }

  Widget _buildGlassCircleButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool enabled = true,
  }) {
    return GestureDetector(
      key: key,
      onTap: enabled ? onTap : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: !enabled
                  ? Colors.white.withValues(alpha: 0.5)
                  : isPrimary
                      ? AppTheme.interactiveTeal.withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.70),
              shape: BoxShape.circle,
              border: Border.all(
                color: !enabled
                    ? Colors.white.withValues(alpha: 0.6)
                    : isPrimary
                        ? AppTheme.interactiveTeal
                        : Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: !enabled
                    ? AppTheme.textSecondary.withValues(alpha: 0.5)
                    : isPrimary
                        ? Colors.white
                        : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.extraction;
    final profile = _selectedProfile;

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGlassCircleButton(
                    icon: CupertinoIcons.xmark,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Confirm Details',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  _buildGlassCircleButton(
                    key: const Key('confirm_save_button'),
                    icon: CupertinoIcons.checkmark,
                    isPrimary: true,
                    enabled: _canContinue,
                    onTap: _confirmAndContinue,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderLight),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  // Hero card -- name and profile are edited directly here
                  // (not duplicated as separate fields below).
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: profile.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.capsule_fill, color: profile.color, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                key: const Key('field_drug'),
                                controller: _drug,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.4,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Medication name',
                                  errorText: _flagText(e.isRecognized('drug'), e.drug),
                                  errorStyle: const TextStyle(fontSize: 11),
                                ),
                              ),
                              const SizedBox(height: 2),
                              DropdownButton<String>(
                                key: const Key('field_profile'),
                                value: _profileId.isEmpty ? null : _profileId,
                                isDense: true,
                                underline: const SizedBox(),
                                icon: const Icon(CupertinoIcons.chevron_down,
                                    size: 12, color: AppTheme.textSecondary),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                                items: widget.profiles
                                    .map((p) => DropdownMenuItem(value: p.id, child: Text('For ${p.name}')))
                                    .toList(),
                                onChanged: (id) => setState(() => _profileId = id ?? _profileId),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'MEDICATION INFORMATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          key: const Key('field_strength'),
                          controller: _strength,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Strength',
                            border: const UnderlineInputBorder(),
                            errorText: _flagText(e.isRecognized('strength'), e.strength),
                            errorMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('field_dose'),
                          controller: _dose,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Dose',
                            border: const UnderlineInputBorder(),
                            errorText: _flagText(e.isRecognized('dose'), e.dose),
                            errorMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: const Key('field_form'),
                          initialValue: _formValue,
                          isExpanded: true,
                          hint: const Text('Select a form'),
                          decoration: InputDecoration(
                            labelText: 'Form',
                            border: const UnderlineInputBorder(),
                            errorText: _flagText(e.isRecognized('form'), e.form),
                            errorMaxLines: 2,
                          ),
                          items: formOptions
                              .map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1))))
                              .toList(),
                          onChanged: (value) => setState(() => _formValue = value),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('field_days_supply'),
                          controller: _daysSupply,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Days Supply',
                            border: UnderlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
