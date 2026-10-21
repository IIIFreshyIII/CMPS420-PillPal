import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/profile.dart';
import '../../../data/services/extractor.dart';
import '../../../presentation/widgets/confetti_burst.dart';
import '../../../presentation/widgets/pressable.dart';
import '../widgets/onboarding_progress_bar.dart';

/// Step 7: Editable OCR/NER Verification & Celebratory Confirmation.
///
/// Features:
/// - Pre-populates scanned label extraction fields into clean, editable inputs:
///   * Medication Name & Dosage Amount
///   * Intake Instructions (With food, route, frequency)
///   * Reminder Schedule (Native iOS-style Cupertino time pickers)
///   * Who Is This For? (Me vs. Someone Else / Caretaker support)
/// - Interactive Profile Creator for "Someone Else" with dynamic initials and badge color.
/// - Once verified, transitions into a celebratory confirmation state with confetti
///   and an "Awesome!" button.
/// - "Awesome!" persists the data, sets `hasCompletedOnboarding = true`, and
///   hands off directly to the Schedule screen displaying ONLY this medication.
class Step7Verification extends StatefulWidget {
  const Step7Verification({
    super.key,
    required this.extraction,
    required this.primaryUserName,
    required this.onBack,
    required this.onConfirmAndSave,
  });

  final Extraction extraction;
  final String primaryUserName;
  final VoidCallback onBack;
  final Future<void> Function(Prescription prescription, Profile? newProfile)
      onConfirmAndSave;

  @override
  State<Step7Verification> createState() => _Step7VerificationState();
}

enum _FoodInstruction { withFood, withoutFood, anytime }

class _Step7VerificationState extends State<Step7Verification> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _recipientNameController;

  String _route = 'By mouth';
  _FoodInstruction _food = _FoodInstruction.anytime;
  String _frequency = 'Once daily';
  List<String> _reminderTimes = ['8:00 AM'];

  // Who is this for: 'me' vs 'someone_else'
  String _assignee = 'me';
  Color _recipientColor = const Color(0xFF8B5CF6); // Default Purple

  static const List<Color> _presetRecipientColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
  ];

  static const List<String> _relationshipRoles = [
    'Mom',
    'Dad',
    'Partner',
    'Child',
    'Grandparent',
    'Pet',
  ];

  bool _isConfirmed = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.extraction;

    // Pre-populate medication name
    _nameController = TextEditingController(
      text: e.drug?.trim().isNotEmpty == true ? e.drug! : 'Metformin HCl',
    );

    // Pre-populate dosage strictly as strength/dose (e.g. "500 mg")
    final strength = e.strength?.trim();
    final dose = e.dose?.trim();
    final initialDosage = (strength != null && strength.isNotEmpty)
        ? strength
        : ((dose != null && dose.isNotEmpty) ? dose : '500 mg');

    _dosageController = TextEditingController(text: initialDosage);

    _recipientNameController = TextEditingController(text: '');

    // Pre-populate frequency & reminder times
    final rawFreq = (e.frequency ?? '').toLowerCase();
    if (rawFreq.contains('twice') || rawFreq.contains('2 times') || rawFreq.contains('bid')) {
      _frequency = 'Twice daily';
      _reminderTimes = ['8:00 AM', '8:00 PM'];
    } else if (rawFreq.contains('three') || rawFreq.contains('tid') || rawFreq.contains('3')) {
      _frequency = '3x daily';
      _reminderTimes = ['8:00 AM', '2:00 PM', '8:00 PM'];
    } else {
      _frequency = 'Once daily';
      _reminderTimes = ['8:00 AM'];
    }

    // Check food instruction in raw text
    final rawText = e.rawText.toLowerCase();
    if (rawText.contains('with food') || rawText.contains('with meals')) {
      _food = _FoodInstruction.withFood;
    } else if (rawText.contains('empty stomach') || rawText.contains('without food')) {
      _food = _FoodInstruction.withoutFood;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _recipientNameController.dispose();
    super.dispose();
  }

  String _formatDateTimeToTimeOfDay(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMin = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMin $period';
  }

  DateTime _parseTimeToDate(String timeStr) {
    final now = DateTime.now();
    final tod = parseTimeOfDayLabel(timeStr);
    if (tod != null) {
      return DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    }
    return DateTime(now.year, now.month, now.day, 8, 0);
  }

  void _showNativeTimePicker(int index) {
    final initialDate = _parseTimeToDate(_reminderTimes[index]);
    DateTime selected = initialDate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerTextColor =
        isDark ? Colors.white : CupertinoColors.label.resolveFrom(context);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      Text(
                        'Reminder Time',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: headerTextColor,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          setState(() {
                            _reminderTimes[index] =
                                _formatDateTimeToTimeOfDay(selected);
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
                    onDateTimeChanged: (dt) {
                      selected = dt;
                    },
                  ),
                ),
              ],
            ),
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

  void _handleConfirm() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medication name.')),
      );
      return;
    }

    if (_assignee == 'someone_else' &&
        _recipientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please enter the care recipient's name.")),
      );
      return;
    }

    // Trigger celebratory confetti burst
    ConfettiBurst.show(
      context,
      origin: Offset(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height * 0.35,
      ),
      colors: const [
        Color(0xFF168B87), // Teal
        Color(0xFFFFD600), // Gold
        Color(0xFF8B5CF6), // Purple
        Color(0xFF3B82F6), // Blue
        Color(0xFF10B981), // Emerald
      ],
    );

    setState(() {
      _isConfirmed = true;
    });
  }

  Future<void> _handleAwesomeTap() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      Profile? secondaryProfile;
      String assignedProfileId = '1';

      if (_assignee == 'someone_else') {
        final recName = _recipientNameController.text.trim();
        secondaryProfile = Profile(
          id: 'recipient_${DateTime.now().millisecondsSinceEpoch}',
          name: recName.isNotEmpty ? recName : 'Care Recipient',
          color: _recipientColor,
          isPrimary: false,
        );
        assignedProfileId = secondaryProfile.id;
      }

      final dosageText = _dosageController.text.trim();

      final prescription = Prescription(
        id: 'rx_${DateTime.now().millisecondsSinceEpoch}',
        profileId: assignedProfileId,
        name: _nameController.text.trim(),
        dosage: dosageText.isNotEmpty ? dosageText : '500 mg',
        reminderTimes:
            _reminderTimes.isNotEmpty ? List.from(_reminderTimes) : ['8:00 AM'],
        remaining: widget.extraction.daysSupply ?? 30,
        daysSupply: widget.extraction.daysSupply ?? 30,
      );

      await widget.onConfirmAndSave(prescription, secondaryProfile);
    } catch (e) {
      debugPrint('Error saving first reminder: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isConfirmed) {
      return _buildCelebratoryConfirmation(c, isDark);
    }

    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SizedBox(height: 12),
                    OnboardingProgressBar(
                      currentStep: 5,
                      totalSteps: 6,
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassCircleButton(
                      key: const Key('verify_back_button'),
                      icon: CupertinoIcons.chevron_left,
                      onTap: widget.onBack,
                    ),
                    Text(
                      'Verify Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    _buildGlassCircleButton(
                      key: const Key('verify_confirm_button'),
                      icon: CupertinoIcons.checkmark,
                      isPrimary: true,
                      onTap: _handleConfirm,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.borderLight),

            // Form List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  // Section: Medication Information
                  _buildSectionHeader('MEDICATION DETAILS', c),
                  const SizedBox(height: 8),
                  _buildCard(
                    c: c,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField(
                          key: const Key('verify_drug_name'),
                          controller: _nameController,
                          label: 'Medication Name',
                          hint: 'e.g. Metformin, Lisinopril',
                          c: c,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          key: const Key('verify_dosage'),
                          controller: _dosageController,
                          label: 'Dosage Amount',
                          hint: 'e.g. 500 mg, 1 tablet',
                          c: c,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Section: Intake Instructions
                  _buildSectionHeader('INTAKE INSTRUCTIONS', c),
                  const SizedBox(height: 8),
                  _buildCard(
                    c: c,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route & Method',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _HorizontalChevronScrollRow(
                          children: [
                            'By mouth',
                            'Topical',
                            'Inhalation',
                            'Injection',
                          ].map((opt) {
                            final isSelected = _route == opt;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _AdaptiveChoiceChip(
                                label: opt,
                                selected: isSelected,
                                onSelected: (_) => setState(() => _route = opt),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Food Requirement',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildFoodOption(
                              'With food',
                              _FoodInstruction.withFood,
                              CupertinoIcons.circle_grid_hex_fill,
                              c,
                            ),
                            const SizedBox(width: 8),
                            _buildFoodOption(
                              'Without food',
                              _FoodInstruction.withoutFood,
                              CupertinoIcons.clear_circled_solid,
                              c,
                            ),
                            const SizedBox(width: 8),
                            _buildFoodOption(
                              'Anytime',
                              _FoodInstruction.anytime,
                              CupertinoIcons.clock_fill,
                              c,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Frequency',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _HorizontalChevronScrollRow(
                          children: [
                            'Once daily',
                            'Twice daily',
                            '3x daily',
                            '4x daily',
                          ].map((freq) {
                            final isSelected = _frequency == freq;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _AdaptiveChoiceChip(
                                label: freq,
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _frequency = freq;
                                    if (freq == 'Twice daily' &&
                                        _reminderTimes.length < 2) {
                                      _reminderTimes = ['8:00 AM', '8:00 PM'];
                                    } else if (freq == '3x daily' &&
                                        _reminderTimes.length < 3) {
                                      _reminderTimes = [
                                        '8:00 AM',
                                        '2:00 PM',
                                        '8:00 PM'
                                      ];
                                    } else if (freq == '4x daily' &&
                                        _reminderTimes.length < 4) {
                                      _reminderTimes = [
                                        '8:00 AM',
                                        '12:00 PM',
                                        '4:00 PM',
                                        '8:00 PM'
                                      ];
                                    } else if (freq == 'Once daily') {
                                      _reminderTimes = [_reminderTimes.first];
                                    }
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Section: Reminder Schedule (Native iOS Time Picker)
                  _buildSectionHeader('REMINDER SCHEDULE', c),
                  const SizedBox(height: 8),
                  _buildCard(
                    c: c,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select alert time(s) for your daily doses:',
                          style: TextStyle(
                            fontSize: 13,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (int i = 0; i < _reminderTimes.length; i++)
                              _buildTimePill(
                                time: _reminderTimes[i],
                                index: i,
                                c: c,
                              ),
                            _AdaptiveActionChip(
                              key: const Key('verify_add_time_button'),
                              icon: CupertinoIcons.plus,
                              label: 'Add Time',
                              onPressed: _addReminderTime,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Section: Who Is This For? (Multi-Person Caretaker Support)
                  _buildSectionHeader('WHO IS THIS FOR?', c),
                  const SizedBox(height: 8),
                  _buildCard(
                    c: c,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildAssigneeOption(
                                key: const Key('assignee_me'),
                                title:
                                    'Me (${widget.primaryUserName.isNotEmpty ? widget.primaryUserName : 'Primary'})',
                                isSelected: _assignee == 'me',
                                color: c.teal,
                                onTap: () => setState(() => _assignee = 'me'),
                                c: c,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildAssigneeOption(
                                key: const Key('assignee_someone_else'),
                                title: 'Someone Else',
                                isSelected: _assignee == 'someone_else',
                                color: _recipientColor,
                                onTap: () => setState(
                                    () => _assignee = 'someone_else'),
                                c: c,
                              ),
                            ),
                          ],
                        ),
                        if (_assignee == 'someone_else') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _recipientColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _recipientColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Live Initials Badge & Name Field
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: _recipientColor,
                                      child: Text(
                                        _getInitials(_recipientNameController.text),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: TextField(
                                        key: const Key('recipient_name_field'),
                                        controller: _recipientNameController,
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          labelText: "Care Recipient's Name",
                                          hintText: 'e.g. Mom, Dad, Emma',
                                          border: const UnderlineInputBorder(),
                                          labelStyle: TextStyle(
                                            color: _recipientColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: c.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Quick Roles
                                Text(
                                  'Quick Roles',
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
                                  children: _relationshipRoles.map((role) {
                                    final isSelected =
                                        _recipientNameController.text.trim() == role;
                                    return _AdaptiveChoiceChip(
                                      label: role,
                                      selected: isSelected,
                                      selectedColor: _recipientColor.withValues(alpha: 0.2),
                                      activeTextColor: _recipientColor,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _recipientNameController.text = role;
                                          } else if (_recipientNameController.text == role) {
                                            _recipientNameController.clear();
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 16),

                                // Badge Color Swatches
                                Text(
                                  'Badge Color',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: c.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  children: _presetRecipientColors.map((swatch) {
                                    final isSelected =
                                        swatch.toARGB32() == _recipientColor.toARGB32();
                                    return Pressable(
                                      scale: 0.9,
                                      onTap: () => setState(() => _recipientColor = swatch),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: swatch,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? c.ink : Colors.transparent,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: swatch.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check,
                                                size: 16, color: Colors.white)
                                            : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Big Bottom Confirm Button
                  Pressable(
                    key: const Key('verify_bottom_confirm_button'),
                    onTap: _handleConfirm,
                    scale: 0.97,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: c.teal,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: c.teal.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.checkmark_alt,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Confirm & Set Reminder',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
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
  }

  // --- CELEBRATORY CONFIRMATION VIEW ---

  Widget _buildCelebratoryConfirmation(PillPalColors c, bool isDark) {
    final assignedName = _assignee == 'someone_else'
        ? (_recipientNameController.text.trim().isNotEmpty
            ? _recipientNameController.text.trim()
            : 'Care Recipient')
        : (widget.primaryUserName.isNotEmpty
            ? widget.primaryUserName
            : 'Me');

    final assignedColor =
        _assignee == 'someone_else' ? _recipientColor : c.teal;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Celebratory Seal Icon with Pulsing Glow
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: c.tint,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.teal.withValues(alpha: 0.3),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    size: 56,
                    color: c.teal,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title
              Text(
                "You're All Set!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                'Your first medication reminder has been configured and is ready to keep you on track.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: c.inkMuted,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              // Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: c.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: c.cardShadow,
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: assignedColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.capsule_fill,
                            color: assignedColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text.trim(),
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: c.ink,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dosageController.text.trim(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: c.borderLight),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(CupertinoIcons.clock_fill,
                                size: 15, color: c.teal),
                            const SizedBox(width: 6),
                            Text(
                              _reminderTimes.join(', '),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: assignedColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: assignedColor,
                                child: Text(
                                  _getInitials(assignedName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'For $assignedName',
                                style: TextStyle(
                                  color: assignedColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // The Prominent "Awesome!" Button
              Pressable(
                key: const Key('verification_awesome_button'),
                onTap: _isSaving ? null : _handleAwesomeTap,
                scale: 0.97,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.teal,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: c.teal.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSaving
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text(
                            'Awesome!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildSectionHeader(String title, PillPalColors c) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: c.inkMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCard({required PillPalColors c, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.borderLight),
        boxShadow: [
          BoxShadow(
            color: c.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInputField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required PillPalColors c,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.inkMuted,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          key: key,
          controller: controller,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(color: c.inkMuted.withValues(alpha: 0.5)),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: c.borderLight),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.teal, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodOption(
      String label, _FoodInstruction val, IconData icon, PillPalColors c) {
    final isSelected = _food == val;
    return Expanded(
      child: Pressable(
        onTap: () => setState(() => _food = val),
        scale: 0.95,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? c.teal.withValues(alpha: 0.12) : c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? c.teal : c.borderLight,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? c.teal : c.inkMuted),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? c.teal : c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePill({
    required String time,
    required int index,
    required PillPalColors c,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.teal.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            key: Key('verify_time_pill_$index'),
            onTap: () => _showNativeTimePicker(index),
            scale: 0.95,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.clock_fill, size: 14, color: c.teal),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_reminderTimes.length > 1)
            Pressable(
              key: Key('verify_remove_time_$index'),
              onTap: () => _removeReminderTime(index),
              scale: 0.85,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 16,
                  color: c.inkMuted.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssigneeOption({
    Key? key,
    required String title,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required PillPalColors c,
  }) {
    return Pressable(
      key: key,
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : c.borderLight,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 16,
              color: isSelected ? color : c.inkMuted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : c.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCircleButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final c = context.colors;
    return Pressable(
      key: key,
      onTap: onTap,
      scale: 0.92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isPrimary ? c.teal : c.glass,
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
              child: Icon(
                icon,
                size: 18,
                color: isPrimary ? c.onTeal : c.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Freely-scrollable horizontal row with Apple-style animated chevrons.
class _HorizontalChevronScrollRow extends StatefulWidget {
  const _HorizontalChevronScrollRow({
    required this.children,
  });

  final List<Widget> children;

  @override
  State<_HorizontalChevronScrollRow> createState() =>
      _HorizontalChevronScrollRowState();
}

class _HorizontalChevronScrollRowState
    extends State<_HorizontalChevronScrollRow> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final canLeft = pos.pixels > 4.0;
    final canRight = pos.pixels < (pos.maxScrollExtent - 4.0);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Stack(
      alignment: Alignment.center,
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: widget.children),
        ),
        if (_canScrollLeft)
          Positioned(
            left: 0,
            child: Pressable(
              scale: 0.85,
              onTap: () => _scroll(-130),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  size: 14,
                  color: c.ink,
                ),
              ),
            ),
          ),
        if (_canScrollRight)
          Positioned(
            right: 0,
            child: Pressable(
              scale: 0.85,
              onTap: () => _scroll(130),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(-1, 1),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: c.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Native iOS-feeling choice chip with spring feedback and zero Material ripple.
class _AdaptiveChoiceChip extends StatelessWidget {
  const _AdaptiveChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
    this.activeTextColor,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? selectedColor;
  final Color? activeTextColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeBg = selectedColor ?? c.teal.withValues(alpha: 0.16);
    final activeText = activeTextColor ?? c.teal;
    final borderCol = selected ? (activeTextColor ?? c.teal) : c.borderLight;

    return Pressable(
      scale: 0.94,
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeBg : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderCol,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? activeText : c.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Native iOS-feeling action chip with spring feedback.
class _AdaptiveActionChip extends StatelessWidget {
  const _AdaptiveActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      key: key,
      scale: 0.94,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.tint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.teal.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c.teal),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: c.teal,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
