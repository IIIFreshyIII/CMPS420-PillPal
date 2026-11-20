import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/ner/postprocess.dart' show formOptions;
import '../../core/theme/pillpal_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/extractor.dart';
import '../../ui/widgets/medication_type_selector.dart';

/// All-in-one verification & manual entry screen (Option B):
/// - Unified single-sheet experience matching the Onboarding verification model.
/// - Pre-populates all extracted fields (name, strength, dosage, form, days supply,
///   frequency, reminder schedule, food instructions, and care recipient profile).
/// - Dynamic amber/honey highlighting on unparsed or low-confidence fields so
///   users instantly spot what needs verification.
/// - Supports "Enter Manually" mode with auto-focus on medication name and
///   clean, neutral styling.
/// - Pops directly with the confirmed [Prescription], or `null` if cancelled.
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

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final TextEditingController _drug;
  late final TextEditingController _strength;
  late final TextEditingController _dose;
  late final TextEditingController _quantity;
  late final TextEditingController _daysSupply;
  late final TextEditingController _refills;
  String? _formValue;
  late String _profileId;

  String _foodInstruction = 'Anytime';
  String _frequency = 'Once daily';
  List<String> _reminderTimes = ['8:00 AM'];

  static const Color _amberWarning = Color(0xFFF59E0B);
  static const Color _amberText = Color(0xFFB45309);

  @override
  void initState() {
    super.initState();
    final e = widget.extraction;

    _drug = TextEditingController(text: e?.drug ?? '');
    _strength = TextEditingController(text: e?.strength ?? '');
    _dose = TextEditingController(text: e?.dose ?? '');
    final initialDaysSupply = e?.daysSupply ?? 30;
    final initialQuantity = e?.quantity ?? initialDaysSupply;
    _quantity = TextEditingController(text: '$initialQuantity');
    _daysSupply = TextEditingController(text: '$initialDaysSupply');
    _refills = TextEditingController(text: '${e?.refills ?? 0}');

    if (e?.form != null && formOptions.contains(e!.form)) {
      _formValue = e.form;
    } else {
      _formValue = null;
    }

    _profileId = widget.profiles.isNotEmpty ? widget.profiles.first.id : '1';

    if (e != null) {
      final rawFreq = (e.frequency ?? '').toLowerCase();
      if (rawFreq.contains('twice') || rawFreq.contains('2 times') || rawFreq.contains('bid')) {
        _frequency = 'Twice daily';
        _reminderTimes = ['8:00 AM', '8:00 PM'];
      } else if (rawFreq.contains('three') || rawFreq.contains('tid') || rawFreq.contains('3')) {
        _frequency = '3x daily';
        _reminderTimes = ['8:00 AM', '2:00 PM', '8:00 PM'];
      } else if (rawFreq.contains('four') || rawFreq.contains('qid') || rawFreq.contains('4')) {
        _frequency = '4x daily';
        _reminderTimes = ['8:00 AM', '12:00 PM', '4:00 PM', '8:00 PM'];
      } else {
        _frequency = 'Once daily';
        _reminderTimes = ['8:00 AM'];
      }

      final rawText = e.rawText.toLowerCase();
      if (rawText.contains('with food') || rawText.contains('with meals')) {
        _foodInstruction = 'With food';
      } else if (rawText.contains('empty stomach') || rawText.contains('without food')) {
        _foodInstruction = 'Without food';
      }
    }
  }

  @override
  void dispose() {
    _drug.dispose();
    _strength.dispose();
    _dose.dispose();
    _quantity.dispose();
    _daysSupply.dispose();
    _refills.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _drug.text.trim().isNotEmpty && _profileId.isNotEmpty;

  Profile get _selectedProfile => widget.profiles.firstWhere(
        (p) => p.id == _profileId,
        orElse: () =>
            const Profile(id: '1', name: 'Primary', color: Color(0xFF168B87)),
      );

  bool _isFieldFlagged(String field) {
    if (widget.isManual) return false;
    final e = widget.extraction;
    if (e == null) return false;

    switch (field) {
      case 'drug':
        return !e.isRecognized('drug') || _drug.text.trim().isEmpty;
      case 'strength':
        return !e.isRecognized('strength') || _strength.text.trim().isEmpty;
      case 'dose':
        return !e.isRecognized('dose') || _dose.text.trim().isEmpty;
      case 'form':
        return _formValue == null || !e.isRecognized('form');
      case 'frequency':
        return !e.isRecognized('frequency');
      case 'quantity':
        return e.quantity == null;
      case 'daysSupply':
        return e.daysSupply == null;
      case 'refills':
        // Always prompt to verify refills on scanned/photo labels.
        return e.rawText.trim().isNotEmpty;
      default:
        return false;
    }
  }

  String _flagMessage(String field, String? rawText) {
    if (rawText != null && rawText.trim().isNotEmpty) {
      return 'Verify -- OCR matched "$rawText"';
    }
    return 'Not detected -- please verify';
  }

  void _savePrescription() {
    if (!_canContinue) return;

    final days = (int.tryParse(_daysSupply.text.trim()) ?? 30).clamp(1, 9999);
    final qty = (int.tryParse(_quantity.text.trim()) ?? days).clamp(0, 9999);
    final refills = (int.tryParse(_refills.text.trim()) ?? 0).clamp(0, 99);
    final dosageParts = [_strength.text, _dose.text, _formValue ?? '']
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');

    final prescription = Prescription(
      id: 'rx_${DateTime.now().millisecondsSinceEpoch}',
      profileId: _profileId,
      name: _drug.text.trim(),
      dosage: dosageParts.isNotEmpty ? dosageParts : '500 mg',
      reminderTimes: List.from(_reminderTimes),
      remaining: qty,
      daysSupply: days,
      refillsRemaining: refills,
    );

    Navigator.of(context).pop(prescription);
  }

  void _showNativeTimePicker(int index) {
    final now = DateTime.now();
    final initialDate = parseTimeOfDayLabel(_reminderTimes[index]) != null
        ? DateTime(now.year, now.month, now.day,
            parseTimeOfDayLabel(_reminderTimes[index])!.hour,
            parseTimeOfDayLabel(_reminderTimes[index])!.minute)
        : DateTime(now.year, now.month, now.day, 8, 0);

    var selected = initialDate;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          final hour = selected.hour;
                          final minute = selected.minute;
                          final period = hour >= 12 ? 'PM' : 'AM';
                          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                          final displayMin = minute.toString().padLeft(2, '0');
                          _reminderTimes[index] = '$displayHour:$displayMin $period';
                        });
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initialDate,
                  use24hFormat: false,
                  onDateTimeChanged: (dt) => selected = dt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addReminderTime() {
    setState(() {
      _reminderTimes.add('12:00 PM');
    });
    _showNativeTimePicker(_reminderTimes.length - 1);
  }

  void _removeReminderTime(int index) {
    if (_reminderTimes.length <= 1) return;
    setState(() {
      _reminderTimes.removeAt(index);
    });
  }

  Widget _buildGlassCircleButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool enabled = true,
  }) {
    final c = context.colors;
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
                  ? c.glass.withValues(alpha: c.glass.a * (0.5 / 0.7))
                  : isPrimary
                      ? c.teal.withValues(alpha: 0.90)
                      : c.glass,
              shape: BoxShape.circle,
              border: Border.all(
                color: !enabled
                    ? c.glassRim.withValues(alpha: c.glassRim.a * (0.6 / 0.9))
                    : isPrimary
                        ? c.teal
                        : c.glassRim,
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
              child: Icon(
                icon,
                size: 18,
                color: !enabled
                    ? c.inkMuted.withValues(alpha: 0.5)
                    : isPrimary
                        ? c.onTeal
                        : c.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _amberWarning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _amberWarning.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 11,
            color: _amberWarning,
          ),
          const SizedBox(width: 5),
          Text(
            message,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _amberText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = _selectedProfile;
    final isDrugFlagged = _isFieldFlagged('drug');

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: c.grabber,
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
                    key: const Key('confirm_cancel_button'),
                    icon: CupertinoIcons.xmark,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    widget.isManual ? 'Add Medication' : 'Verify Details',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  _buildGlassCircleButton(
                    key: const Key('confirm_save_button'),
                    icon: CupertinoIcons.checkmark,
                    isPrimary: true,
                    enabled: _canContinue,
                    onTap: _savePrescription,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.borderLight),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  // 1. Hero Card: Name & Profile
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDrugFlagged
                          ? _amberWarning.withValues(alpha: 0.05)
                          : c.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDrugFlagged ? _amberWarning : c.borderLight,
                        width: isDrugFlagged ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.cardShadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: profile.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.capsule_fill,
                                color: profile.color,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    key: const Key('field_drug'),
                                    controller: _drug,
                                    autofocus: widget.isManual,
                                    onChanged: (_) => setState(() {}),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: c.ink,
                                      letterSpacing: -0.4,
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: 'Medication name',
                                      hintStyle: TextStyle(
                                        color: c.inkMuted.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  DropdownButton<String>(
                                    key: const Key('field_profile'),
                                    value: _profileId.isEmpty ? null : _profileId,
                                    isDense: true,
                                    underline: const SizedBox(),
                                    icon: Icon(
                                      CupertinoIcons.chevron_down,
                                      size: 12,
                                      color: c.inkMuted,
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: c.inkMuted,
                                    ),
                                    items: widget.profiles
                                        .map((p) => DropdownMenuItem(
                                              value: p.id,
                                              child: Text('For ${p.name}'),
                                            ))
                                        .toList(),
                                    onChanged: (id) => setState(
                                      () => _profileId = id ?? _profileId,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isDrugFlagged) ...[
                          const SizedBox(height: 8),
                          _buildConfidenceBadge(
                            _flagMessage('drug', widget.extraction?.drug),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 2. Medication Details Card
                  Text(
                    'PRESCRIPTION DETAILS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.inkMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Strength
                        TextField(
                          key: const Key('field_strength'),
                          controller: _strength,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Strength (e.g. 500 mg)',
                            border: const UnderlineInputBorder(),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: c.teal, width: 2),
                            ),
                          ),
                        ),
                        if (_isFieldFlagged('strength'))
                          _buildConfidenceBadge(
                            _flagMessage('strength', widget.extraction?.strength),
                          ),

                        const SizedBox(height: 12),

                        // Dose
                        TextField(
                          key: const Key('field_dose'),
                          controller: _dose,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Dose Amount (e.g. 1 tablet)',
                            border: const UnderlineInputBorder(),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: c.teal, width: 2),
                            ),
                          ),
                        ),
                        if (_isFieldFlagged('dose'))
                          _buildConfidenceBadge(
                            _flagMessage('dose', widget.extraction?.dose),
                          ),

                        const SizedBox(height: 12),

                        // Form / Medication Type
                        Text(
                          'Form / Type',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MedicationTypeSelector(
                          key: const Key('field_form'),
                          selectedType: _formValue,
                          onSelected: (val) => setState(() => _formValue = val),
                        ),
                        if (_isFieldFlagged('form'))
                          _buildConfidenceBadge(
                            _flagMessage('form', widget.extraction?.form),
                          ),

                        const SizedBox(height: 12),

                        // Quantity in Bottle & Days Supply
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('field_quantity'),
                                controller: _quantity,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Quantity in Bottle',
                                  border: const UnderlineInputBorder(),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: c.teal, width: 2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                key: const Key('field_days_supply'),
                                controller: _daysSupply,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Days Supply',
                                  border: const UnderlineInputBorder(),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: c.teal, width: 2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isFieldFlagged('quantity') ||
                            _isFieldFlagged('daysSupply'))
                          _buildConfidenceBadge(
                            'Verify quantity & days supply',
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('field_refills'),
                          controller: _refills,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Refills Remaining',
                            border: const UnderlineInputBorder(),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: c.teal, width: 2),
                            ),
                          ),
                        ),
                        if (_isFieldFlagged('refills'))
                          _buildConfidenceBadge(
                            _flagMessage('refills', widget.extraction?.refills?.toString()),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 3. Schedule & Reminder Times Section
                  Text(
                    'SCHEDULE & REMINDERS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.inkMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frequency',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              'Once daily',
                              'Twice daily',
                              '3x daily',
                              '4x daily',
                            ].map((freq) {
                              final isSelected = _frequency == freq;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(freq),
                                  selected: isSelected,
                                  selectedColor: c.teal.withValues(alpha: 0.18),
                                  backgroundColor: c.background,
                                  labelStyle: TextStyle(
                                    color: isSelected ? c.tealDeep : c.ink,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  side: BorderSide(
                                    color: isSelected ? c.teal : c.borderLight,
                                  ),
                                  onSelected: (_) {
                                    setState(() {
                                      _frequency = freq;
                                      if (freq == 'Twice daily' && _reminderTimes.length < 2) {
                                        _reminderTimes = ['8:00 AM', '8:00 PM'];
                                      } else if (freq == '3x daily' && _reminderTimes.length < 3) {
                                        _reminderTimes = ['8:00 AM', '2:00 PM', '8:00 PM'];
                                      } else if (freq == '4x daily' && _reminderTimes.length < 4) {
                                        _reminderTimes = ['8:00 AM', '12:00 PM', '4:00 PM', '8:00 PM'];
                                      } else if (freq == 'Once daily') {
                                        _reminderTimes = [_reminderTimes.first];
                                      }
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (_isFieldFlagged('frequency'))
                          _buildConfidenceBadge(
                            _flagMessage('frequency', widget.extraction?.frequency),
                          ),

                        const SizedBox(height: 16),

                        Text(
                          'Dose Reminder Times',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (int i = 0; i < _reminderTimes.length; i++)
                              GestureDetector(
                                key: i == 0 ? const Key('field_start_time') : null,
                                onTap: () => _showNativeTimePicker(i),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: c.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: c.borderLight),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.clock, size: 14, color: c.teal),
                                      const SizedBox(width: 6),
                                      Text(
                                        _reminderTimes[i],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: c.ink,
                                        ),
                                      ),
                                      if (_reminderTimes.length > 1) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _removeReminderTime(i),
                                          child: Icon(
                                            CupertinoIcons.xmark_circle_fill,
                                            size: 14,
                                            color: c.inkMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: _addReminderTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: c.teal.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: c.teal.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.plus, size: 14, color: c.tealDeep),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Add Time',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: c.tealDeep,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Food Instructions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            'Anytime',
                            'With food',
                            'Without food',
                          ].map((inst) {
                            final isSelected = _foodInstruction == inst;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: GestureDetector(
                                  onTap: () => setState(() => _foodInstruction = inst),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? c.teal.withValues(alpha: 0.15)
                                          : c.background,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? c.teal : c.borderLight,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        inst,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? c.tealDeep : c.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
