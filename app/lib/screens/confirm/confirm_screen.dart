import 'package:flutter/material.dart';

import '../../core/ner/postprocess.dart' show formOptions;
import '../../core/theme/app_theme.dart';
import '../../data/models/profile.dart';
import '../../data/models/prescription.dart';
import '../../data/services/extraction_mapper.dart';
import '../../data/services/extractor.dart';
import 'widgets/rotary_time_picker.dart';

/// Every field editable, low-confidence fields flagged with the raw matched
/// text -- never a fabricated confidence score (Phase 2 wireframe §Confirm,
/// `med-tracker-spec.md` §1: "no confidence-based shortcuts"). Nothing is
/// saved until the user taps Confirm & Save; that tap is the only place an
/// [Extraction] becomes a real [Prescription] (`extraction_mapper.dart`).
///
/// Pops with the built [Prescription], or `null` if the user backs out.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.extraction, required this.profiles});

  final Extraction extraction;
  final List<Profile> profiles;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final TextEditingController _drug;
  late final TextEditingController _strength;
  late final TextEditingController _dose;
  late final TextEditingController _daysSupply;
  String? _formValue;
  TimeOfDay? _selectedTime;
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

  bool get _canSave =>
      _drug.text.trim().isNotEmpty && _selectedTime != null && _profileId.isNotEmpty;

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime() async {
    final picked = await showRotaryTimePicker(context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _save() {
    final days = int.tryParse(_daysSupply.text.trim()) ?? 0;
    final prescription = mapExtractionToPrescription(
      widget.extraction,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      profileId: _profileId,
      time: _formatTime(_selectedTime!),
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

  @override
  Widget build(BuildContext context) {
    final e = widget.extraction;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Confirm Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field('DRUG', _drug, recognized: e.isRecognized('drug'), rawIfFlagged: e.drug, fieldKey: const Key('field_drug')),
          _field('STRENGTH', _strength, recognized: e.isRecognized('strength'), rawIfFlagged: e.strength, fieldKey: const Key('field_strength')),
          _field('DOSE', _dose, recognized: e.isRecognized('dose'), rawIfFlagged: e.dose, fieldKey: const Key('field_dose')),
          _formDropdown(recognized: e.isRecognized('form'), rawIfFlagged: e.form),
          if (e.frequency != null) ...[
            const SizedBox(height: 4),
            Text('OCR read frequency as: "${e.frequency}" -- set the exact reminder time below.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          _timePickerField(),
          const SizedBox(height: 16),
          _plainField('DAYS SUPPLY', _daysSupply, keyboardType: TextInputType.number, fieldKey: const Key('field_days_supply')),
          const SizedBox(height: 16),
          _profileDropdown(),
          const SizedBox(height: 32),
          FilledButton(
            key: const Key('confirm_save_button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.interactiveTeal,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _canSave ? _save : null,
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {required bool recognized, String? rawIfFlagged, Key? fieldKey}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recognized ? label : '$label · verify this',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              color: recognized ? AppTheme.textSecondary : AppTheme.lowStockAlert,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            key: fieldKey,
            controller: controller,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.cardWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: recognized
                    ? BorderSide(color: AppTheme.borderLight)
                    : BorderSide(color: AppTheme.lowStockAlert, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          if (!recognized && rawIfFlagged != null) ...[
            const SizedBox(height: 4),
            Text('matched text: "$rawIfFlagged"',
                style: const TextStyle(fontSize: 11, color: AppTheme.lowStockAlert)),
          ],
        ],
      ),
    );
  }

  Widget _formDropdown({required bool recognized, String? rawIfFlagged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recognized ? 'FORM' : 'FORM · verify this',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              color: recognized ? AppTheme.textSecondary : AppTheme.lowStockAlert,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            key: const Key('field_form'),
            initialValue: _formValue,
            hint: const Text('Select a form'),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.cardWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: recognized
                    ? BorderSide(color: AppTheme.borderLight)
                    : BorderSide(color: AppTheme.lowStockAlert, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: formOptions
                .map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1))))
                .toList(),
            onChanged: (value) => setState(() => _formValue = value),
          ),
          if (!recognized && rawIfFlagged != null) ...[
            const SizedBox(height: 4),
            Text('matched text: "$rawIfFlagged"',
                style: const TextStyle(fontSize: 11, color: AppTheme.lowStockAlert)),
          ],
        ],
      ),
    );
  }

  Widget _timePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REMINDER TIME (required)',
            style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        InkWell(
          key: const Key('field_time'),
          borderRadius: BorderRadius.circular(10),
          onTap: _pickTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  _selectedTime != null ? _formatTime(_selectedTime!) : 'Tap to set a time',
                  style: TextStyle(
                    color: _selectedTime != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _plainField(String label, TextEditingController controller, {TextInputType? keyboardType, Key? fieldKey}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, letterSpacing: 0.5, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.cardWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.borderLight),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _profileDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PROFILE', style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: _profileId.isEmpty ? null : _profileId,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.cardWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.borderLight),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: widget.profiles
              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
              .toList(),
          onChanged: (id) => setState(() => _profileId = id ?? _profileId),
        ),
      ],
    );
  }
}
