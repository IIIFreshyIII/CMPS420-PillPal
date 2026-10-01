import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';

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
  });

  final Prescription prescription;
  final List<Profile> profiles;
  final VoidCallback onEdit;

  static Future<void> show(
    BuildContext context, {
    required Prescription prescription,
    required List<Profile> profiles,
    required VoidCallback onEdit,
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
              color: isPrimary
                  ? AppTheme.interactiveTeal.withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.70),
              shape: BoxShape.circle,
              border: Border.all(
                color: isPrimary
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
              child: Icon(icon,
                  size: 18,
                  color: isPrimary ? Colors.white : AppTheme.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = profiles.firstWhere(
      (p) => p.id == prescription.profileId,
      orElse: () => const Profile(id: '0', name: 'General', color: Colors.grey),
    );
    final isLow = prescription.remaining <= 5;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    context,
                    icon: CupertinoIcons.xmark,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Medication',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
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
            const Divider(height: 1, color: AppTheme.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Container(
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
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    prescription.dosage,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Prescribed to ${profile.name}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (isLow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.lowStockAlert.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Low Stock',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.lowStockAlert,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppTheme.borderLight),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickStat(
                            icon: CupertinoIcons.clock,
                            label: prescription.reminderTimes.length > 1 ? 'Reminder Times' : 'Reminder Time',
                            value: prescription.reminderTimes.join(', '),
                          ),
                        ),
                        Container(
                            width: 1, height: 36, color: AppTheme.borderLight),
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
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.interactiveTeal),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
