import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/pillpal_colors.dart';
import '../../../presentation/widgets/confetti_burst.dart';
import '../../../presentation/widgets/pressable.dart';
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
    final c = context.colors;
    final bool isLow = item.remaining <= 5;
    final parts = time.split(' ');
    final timeDigit = parts.isNotEmpty ? parts[0] : '';
    final timePeriod = parts.length > 1 ? parts[1] : '';

    final instant = MediaQuery.of(context).disableAnimations;
    final radius = BorderRadius.circular(18);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedOpacity(
        opacity: isTaken ? 0.45 : 1.0,
        duration: instant ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Pressable(
          onTap: onViewDetails,
          borderRadius: radius,
          rippleColor: c.tealRipple,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isTaken ? c.background : c.surface,
            borderRadius: radius,
            border: Border.all(color: c.borderLight),
            boxShadow: [
              BoxShadow(
                color: c.cardShadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // The check lives above the card's own tap handler, so pressing it
          // never also shrinks/ripples the card or opens the quick view.
          foreground: Padding(
            padding: const EdgeInsets.only(right: 16 - (48 - 34) / 2),
            child: Align(
              alignment: Alignment.centerRight,
              child: _DoseCheck(
                isTaken: isTaken,
                profileColor: profile?.color,
                onTap: onTakeDose,
                instant: instant,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: c.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeDigit,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.tealDeep,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      timePeriod,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.tealDeep,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.dosage,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (profile != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 2, horizontal: 7),
                            margin: const EdgeInsets.only(right: 8),
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
                        Text(
                          '${item.remaining} left ${isLow ? '• Refill Soon' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isLow ? FontWeight.w700 : FontWeight.w500,
                            color: isLow ? c.alert : c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Room for the check, which is drawn by `foreground` above.
              const SizedBox(width: 10 + 34),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 34px dose check, with a 48x48 touch target (Material minimum). Marking
/// taken pops the check in with a medium haptic; un-marking just ticks.
class _DoseCheck extends StatelessWidget {
  const _DoseCheck({
    required this.isTaken,
    required this.profileColor,
    required this.onTap,
    required this.instant,
  });

  final bool isTaken;
  final Color? profileColor;
  final VoidCallback onTap;
  final bool instant;

  /// A tiny burst from the check's centre, in theme colours plus this
  /// dose's profile colour. ConfettiBurst skips it under "Remove animations".
  void _celebrate(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final c = context.colors;
    ConfettiBurst.show(
      context,
      origin: box.localToGlobal(box.size.center(Offset.zero)),
      colors: [
        c.teal,
        c.tealDeep,
        c.mint,
        c.headerTeal,
        if (profileColor != null) profileColor!,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final circle = AnimatedContainer(
      duration: instant ? Duration.zero : const Duration(milliseconds: 180),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isTaken ? c.teal : Colors.transparent,
        border: Border.all(
          color: isTaken ? c.teal : c.inkMuted,
          width: 2,
        ),
      ),
      child: isTaken
          ? Icon(CupertinoIcons.checkmark, size: 20, color: c.onTeal)
          : null,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isTaken) {
          HapticFeedback.selectionClick();
        } else {
          HapticFeedback.mediumImpact();
          _celebrate(context);
        }
        onTap();
      },
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: TweenAnimationBuilder<double>(
            // Keyed on isTaken so the pop replays each time it's taken.
            key: ValueKey(isTaken),
            tween: Tween(begin: isTaken && !instant ? 0.6 : 1.0, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: circle,
          ),
        ),
      ),
    );
  }
}
