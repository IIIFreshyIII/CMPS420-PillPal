import 'package:flutter/cupertino.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/profile.dart';
import '../../../presentation/widgets/pressable.dart';

class SavedMedicationCard extends StatelessWidget {
  final Prescription prescription;
  final Profile? profile;
  final VoidCallback onTap;

  const SavedMedicationCard({
    super.key,
    required this.prescription,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isLow = prescription.remaining <= 5;
    final profileColor = profile?.color ?? c.teal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        rippleColor: c.tealRipple,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.borderLight),
          boxShadow: [
            BoxShadow(
              color: c.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left icon container with profile color accent
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: profileColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.capsule_fill,
                  color: profileColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Med details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and dosage
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          prescription.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (prescription.dosage.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          prescription.dosage,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Profile tag & stock info
                  Row(
                    children: [
                      if (profile != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 6),
                          decoration: BoxDecoration(
                            color: profile!.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            profile!.name,
                            style: TextStyle(
                              color: c.tagText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${prescription.remaining} left ${isLow ? '• Refill Soon' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isLow ? FontWeight.w700 : FontWeight.w500,
                          color: isLow ? c.alert : c.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Scheduled reminder times
                  if (prescription.reminderTimes.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: prescription.reminderTimes.map((time) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.tint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: c.tealDeep,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Edit icon button indicating tap to edit
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.tint.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.pencil,
                  size: 16,
                  color: c.tealDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
