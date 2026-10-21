import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../presentation/widgets/pressable.dart';

/// Step 2: Legal Disclaimer & Terms of Use.
/// Fades in smoothly and provides full disclosures covering HIPAA D2C privacy,
/// FDA SaMD boundaries, OCR verification duty, patient responsibility for Rx and OTC,
/// emergency 911 notices, and notification reliability limits.
///
/// The "I Understand & Agree" button remains disabled until the user scrolls to
/// the bottom of the disclosure content.
class Step2Legal extends StatefulWidget {
  const Step2Legal({
    super.key,
    required this.onAgree,
  });

  final VoidCallback onAgree;

  @override
  State<Step2Legal> createState() => _Step2LegalState();
}

class _Step2LegalState extends State<Step2Legal> {
  late final ScrollController _scrollController;
  bool _canAgree = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 24) {
      if (!_canAgree) {
        setState(() => _canAgree = true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.tint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.shield_lefthalf_fill,
                          color: c.tealDeep,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Important Information\n& Legal Disclosures',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        letterSpacing: -0.6,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please review how PillPal works and your responsibilities before proceeding.',
                      style: TextStyle(
                        fontSize: 14,
                        color: c.inkMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 1. TOP WARNING: MEDICAL EMERGENCIES (911)
                    _buildSectionCard(
                      context,
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                      title: 'Medical Emergencies (911)',
                      body:
                          'DO NOT use PillPal for medical emergencies. If you are experiencing an adverse drug reaction, suspected poisoning, or medical crisis, immediately call 911 (or local emergency services) or Poison Control at 1-800-222-1222.',
                      isAlert: true,
                    ),
                    const SizedBox(height: 12),

                    // 2. Not a Doctor or Pharmacist
                    _buildSectionCard(
                      context,
                      icon: CupertinoIcons.person_badge_minus,
                      title: 'Not a Doctor or Pharmacist',
                      body:
                          'PillPal is an independent consumer tracking tool. It is not a pharmacy, clinic, or medical provider, and is not a HIPAA-covered entity. All health data you input is stored locally on your device with hardware-backed encryption.',
                    ),
                    const SizedBox(height: 12),

                    // 3. Informational & Reminder Tool Only
                    _buildSectionCard(
                      context,
                      icon: CupertinoIcons.sparkles,
                      title: 'Informational & Reminder Tool Only',
                      body:
                          'PillPal provides mechanical reminders and organizational assistance. It does not provide medical advice, diagnosis, treatment, or clinical decision support, and does not check for drug interactions or contraindications.',
                    ),
                    const SizedBox(height: 12),

                    // 4. OCR Label Verification Duty
                    _buildSectionCard(
                      context,
                      icon: CupertinoIcons.viewfinder,
                      title: 'OCR Label Verification Duty',
                      body:
                          'Camera label scanning uses automated optical character recognition (OCR) and machine learning. Automated systems can misread numbers, decimal points, or instructions. You are strictly responsible for verifying all scanned fields against your physical prescription bottle.',
                    ),
                    const SizedBox(height: 12),

                    // 5. Responsible Medication Taking (Rx & OTC)
                    _buildSectionCard(
                      context,
                      icon: CupertinoIcons.capsule,
                      title: 'Responsible Medication Taking (Rx & OTC)',
                      body:
                          'You are solely responsible for taking all medications—both prescriptions and over-the-counter medications such as acetaminophen (Tylenol) or ibuprofen—strictly as prescribed by your physician or directed on the product packaging.',
                    ),
                    const SizedBox(height: 12),

                    // 6. Notification Technical Limitations
                    _buildSectionCard(
                      context,
                      icon: CupertinoIcons.bell_slash_fill,
                      title: 'Notification Technical Limitations',
                      body:
                          'Scheduled notifications are supplementary aids. Device battery optimization, Focus modes, or OS reboots can delay or silence alerts. Do not rely solely on notifications for life-critical medications.',
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Agree Button (Unlocked only when scrolled to bottom)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _canAgree ? 1.0 : 0.6,
                child: Pressable(
                  onTap: _canAgree ? widget.onAgree : null,
                  scale: _canAgree ? 0.97 : 1.0,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _canAgree ? c.teal : c.neutralChip,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _canAgree
                          ? [
                              BoxShadow(
                                color: c.teal.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        _canAgree
                            ? 'I Understand & Agree'
                            : 'Scroll to bottom to agree',
                        style: TextStyle(
                          color: _canAgree ? c.onTeal : c.neutralInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    bool isAlert = false,
  }) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAlert ? c.alertTint : c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAlert ? c.alert.withValues(alpha: 0.3) : c.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: c.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isAlert ? c.alert : c.tealDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isAlert ? c.alert : c.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: c.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
