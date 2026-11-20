import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../presentation/widgets/pressable.dart';

/// A small, read-only "quick look" at a medication -- tapping a med on the
/// Schedule page opens this instead of jumping straight into the full
/// editable [MedicationDetailSheet]. Shows just what the Schedule card
/// already hints at (name, who it's for, when, how much supply is left),
/// with the pencil button (in the same top-bar slot the full sheet uses for
/// its checkmark) taking the user into the full edit sheet when they
/// actually want to change something.
///
/// Deliberately NOT full height (`mainAxisSize: MainAxisSize.min`) -- a low
/// pull-up tab, not a second full-screen page.
class MedicationQuickViewSheet extends StatelessWidget {
  const MedicationQuickViewSheet({
    super.key,
    required this.prescription,
    required this.profiles,
    required this.onEdit,
    this.timeSlot,
    this.isTaken = false,
    this.isSkipped = false,
    this.onSnooze,
    this.onSkip,
  });

  final Prescription prescription;
  final List<Profile> profiles;
  final VoidCallback onEdit;
  final String? timeSlot;
  final bool isTaken;
  final bool isSkipped;
  final VoidCallback? onSnooze;
  final VoidCallback? onSkip;

  static Future<void> show(
    BuildContext context, {
    required Prescription prescription,
    required List<Profile> profiles,
    required VoidCallback onEdit,
    String? timeSlot,
    bool isTaken = false,
    bool isSkipped = false,
    VoidCallback? onSnooze,
    VoidCallback? onSkip,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicationQuickViewSheet(
        prescription: prescription,
        profiles: profiles,
        onEdit: onEdit,
        timeSlot: timeSlot,
        isTaken: isTaken,
        isSkipped: isSkipped,
        onSnooze: onSnooze,
        onSkip: onSkip,
      ),
    );
  }

  Widget _buildGlassCircleButton(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final c = context.colors;
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPrimary ? c.teal.withValues(alpha: 0.90) : c.glass,
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
              child: Icon(icon, size: 18, color: isPrimary ? c.onTeal : c.ink),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = profiles.firstWhere(
      (p) => p.id == prescription.profileId,
      orElse: () => const Profile(id: '0', name: 'General', color: Colors.grey),
    );
    final isLow = prescription.remaining <= 5;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    context,
                    icon: CupertinoIcons.xmark,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Medication',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  _buildGlassCircleButton(
                    context,
                    key: const Key('quick_view_edit_button'),
                    icon: CupertinoIcons.pencil,
                    isPrimary: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      onEdit();
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: c.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: c.cardShadow,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: profile.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.capsule_fill,
                              color: profile.color, size: 28),
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
                                      prescription.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: c.ink,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    prescription.dosage,
                                    style: TextStyle(
                                        fontSize: 13, color: c.inkMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Prescribed to ${profile.name}',
                                style:
                                    TextStyle(fontSize: 13, color: c.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        if (isLow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: c.alertTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Low Stock',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.alert,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: c.borderLight),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickStat(
                            icon: CupertinoIcons.clock,
                            label: prescription.reminderTimes.length > 1
                                ? 'Reminder Times'
                                : 'Reminder Time',
                            value: prescription.reminderTimes.join(', '),
                          ),
                        ),
                        Container(width: 1, height: 36, color: c.borderLight),
                        Expanded(
                          child: _QuickStat(
                            icon: CupertinoIcons.calendar,
                            label: 'Days Supply Left',
                            value: '${prescription.daysSupply} days',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!isTaken && (onSnooze != null || onSkip != null))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    if (onSnooze != null)
                      Expanded(
                        child: Pressable(
                          key: const Key('quick_view_snooze_button'),
                          onTap: () {
                            Navigator.of(context).pop();
                            onSnooze!();
                          },
                          scale: 0.96,
                          borderRadius: BorderRadius.circular(16),
                          rippleColor:
                              const Color(0xFFF59E0B).withValues(alpha: 0.16),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.32),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.clock_fill,
                                size: 17,
                                color: Color(0xFFD97706),
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Snooze',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (onSnooze != null && onSkip != null)
                      const SizedBox(width: 12),
                    if (onSkip != null)
                      Expanded(
                        child: Pressable(
                          key: const Key('quick_view_skip_button'),
                          onTap: () {
                            Navigator.of(context).pop();
                            onSkip!();
                          },
                          scale: 0.96,
                          borderRadius: BorderRadius.circular(16),
                          rippleColor: c.ink.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.borderLight),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSkipped
                                    ? CupertinoIcons.arrow_counterclockwise
                                    : CupertinoIcons.forward_fill,
                                size: 17,
                                color: c.ink,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                isSkipped ? 'Undo Skip' : 'Skip Dose',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                ),
                              ),
                            ],
                          ),
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

class _QuickStat extends StatelessWidget {
  const _QuickStat(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Icon(icon, size: 18, color: c.teal),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: c.ink),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted),
        ),
      ],
    );
  }
}
