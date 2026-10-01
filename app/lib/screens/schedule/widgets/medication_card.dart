import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/prescription.dart';
import '../../../data/models/profile.dart';

/// Tapping the card opens the low read-only quick-view sheet
/// (`onViewDetails`); edit and delete both live behind that sheet's edit
/// button now, not a swipe gesture here.
class MedicationCard extends StatelessWidget {
  final Prescription item;
  final String time;
  final bool isTaken;
  final Profile? profile;
  final VoidCallback onTakeDose;
  final VoidCallback onViewDetails;

  const MedicationCard({
    super.key,
    required this.item,
    required this.time,
    required this.isTaken,
    required this.profile,
    required this.onTakeDose,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLow = item.remaining <= 5;
    final parts = time.split(' ');
    final timeDigit = parts.isNotEmpty ? parts[0] : '';
    final timePeriod = parts.length > 1 ? parts[1] : '';

    return GestureDetector(
      onTap: onViewDetails,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isTaken ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isTaken ? AppTheme.background : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(18),
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
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.lightPillTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeDigit,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.interactiveTeal,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      timePeriod,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.interactiveTeal.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
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
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.dosage,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (profile != null)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: profile!.color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              profile!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Text(
                          '${item.remaining} left ${isLow ? '• Refill Soon' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isLow ? FontWeight.w700 : FontWeight.w500,
                            color: isLow ? AppTheme.lowStockAlert : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTakeDose,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isTaken ? AppTheme.interactiveTeal : Colors.transparent,
                    border: Border.all(
                      color: isTaken ? AppTheme.interactiveTeal : const Color(0xFFC7D8D7),
                      width: 2,
                    ),
                  ),
                  child: isTaken
                      ? const Icon(CupertinoIcons.checkmark, size: 20, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
