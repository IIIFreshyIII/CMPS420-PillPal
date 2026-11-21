import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/profile.dart';
import '../../../data/services/extractor.dart';
import '../../../presentation/widgets/confetti_burst.dart';
import '../../../presentation/widgets/pressable.dart';
import '../../medication_form/medication_form.dart';
import '../widgets/onboarding_progress_bar.dart';

/// Step 7: Editable OCR/NER Verification & Celebratory Confirmation.
///
/// Uses the shared [MedicationForm] widget for all medication fields, paired
/// with Onboarding's inline "Me vs. Someone Else" care-recipient creator and
/// post-confirm confetti summary.
class Step7Verification extends StatefulWidget {
  const Step7Verification({
    super.key,
    required this.extraction,
    required this.primaryUserName,
    required this.onBack,
    required this.onConfirmAndSave,
    this.showProgressBar = true,
  });

  final Extraction extraction;
  final String primaryUserName;
  final VoidCallback onBack;
  final Future<void> Function(Prescription prescription, Profile? newProfile)
      onConfirmAndSave;
  final bool showProgressBar;

  @override
  State<Step7Verification> createState() => _Step7VerificationState();
}

class _Step7VerificationState extends State<Step7Verification> {
  late final MedicationFormController _formController;
  late final TextEditingController _recipientNameController;

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
    final isManual = widget.extraction.rawText.trim().isEmpty &&
        (widget.extraction.drug == null ||
            widget.extraction.drug!.trim().isEmpty);

    _formController = MedicationFormController.fromExtraction(
      extraction: widget.extraction,
      defaultProfileId: '1',
      isManual: isManual,
      useOnboardingFallbackDefaults: true,
    )..addListener(_onFormChanged);

    _recipientNameController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _formController.removeListener(_onFormChanged);
    _formController.dispose();
    _recipientNameController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  void _handleConfirm() {
    if (!_formController.canSave) {
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
      var assignedProfileId = '1';

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

      final prescription = _formController.buildPrescription(
        profileIdOverride: assignedProfileId,
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
      return parts.first
          .substring(0, parts.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_isConfirmed) {
      return _buildCelebratoryConfirmation(c);
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (widget.showProgressBar) ...[
                      const SizedBox(height: 12),
                      const OnboardingProgressBar(
                        currentStep: 5,
                        totalSteps: 6,
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 32),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MedicationFormGlassButton(
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
                    MedicationFormGlassButton(
                      key: const Key('verify_confirm_button'),
                      icon: CupertinoIcons.checkmark,
                      isPrimary: true,
                      enabled: _formController.canSave,
                      onTap: _handleConfirm,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.borderLight),
              Expanded(
                child: MedicationForm(
                  controller: _formController,
                  showProfilePicker: false,
                  showQuickRefillButtons: false,
                  extraBottomChildren: [
                    _buildAssigneeSection(c),
                    const SizedBox(height: 28),
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

  Widget _buildAssigneeSection(PillPalColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'WHO IS THIS FOR?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.inkMuted,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
                      onTap: () => setState(() => _assignee = 'someone_else'),
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
                          return Pressable(
                            scale: 0.94,
                            onTap: () {
                              setState(() {
                                if (!isSelected) {
                                  _recipientNameController.text = role;
                                } else {
                                  _recipientNameController.clear();
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _recipientColor.withValues(alpha: 0.2)
                                    : c.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? _recipientColor
                                      : c.borderLight,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  color: isSelected ? _recipientColor : c.ink,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
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
                            onTap: () =>
                                setState(() => _recipientColor = swatch),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: swatch,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      isSelected ? c.ink : Colors.transparent,
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
      ],
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

  Widget _buildCelebratoryConfirmation(PillPalColors c) {
    final assignedName = _assignee == 'someone_else'
        ? (_recipientNameController.text.trim().isNotEmpty
            ? _recipientNameController.text.trim()
            : 'Care Recipient')
        : (widget.primaryUserName.isNotEmpty
            ? widget.primaryUserName
            : 'Me');

    final assignedColor =
        _assignee == 'someone_else' ? _recipientColor : c.teal;

    final preview = _formController.buildPrescription();
    final scheduleSummary = preview.isAsNeeded
        ? 'As Needed'
        : preview.reminderTimes.join(', ');

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
                                preview.name,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: c.ink,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              if (preview.dosage.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  preview.dosage,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.inkMuted,
                                  ),
                                ),
                              ],
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
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.clock_fill,
                                  size: 15, color: c.teal),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  scheduleSummary,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: c.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
}
