import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../presentation/widgets/pressable.dart';
import '../../confirm/widgets/rotary_time_picker.dart';

/// Step 5: Dedicated Bedtime Setup.
/// Prompts the user to set their typical sleep schedule so evening doses,
/// pre-bedtime final calls, and reminder scheduling can automatically fit
/// their lifestyle.
class Step5Bedtime extends StatefulWidget {
  const Step5Bedtime({
    super.key,
    required this.onBedtimeConfirmed,
    required this.onNext,
    this.initialBedtime,
  });

  final Future<void> Function(String? bedtime) onBedtimeConfirmed;
  final VoidCallback onNext;
  final String? initialBedtime;

  @override
  State<Step5Bedtime> createState() => _Step5BedtimeState();
}

class _Step5BedtimeState extends State<Step5Bedtime> {
  late TimeOfDay _bedtime;

  @override
  void initState() {
    super.initState();
    if (widget.initialBedtime != null) {
      _bedtime = parseTimeOfDayLabel(widget.initialBedtime!) ??
          const TimeOfDay(hour: 22, minute: 0);
    } else {
      _bedtime = const TimeOfDay(hour: 22, minute: 0); // 10:00 PM default
    }
  }

  Future<void> _pickBedtime() async {
    final picked = await showRotaryTimePicker(
      context,
      initialTime: _bedtime,
    );
    if (picked != null && mounted) {
      setState(() => _bedtime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final formattedTime = formatTimeOfDayLabel(_bedtime);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Hero Sleep Illustration Container
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: c.tint,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c.teal.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.moon_stars_fill,
                          size: 44,
                          color: c.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    Text(
                      'When do you head to bed?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        letterSpacing: -0.6,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      'PillPal uses your bedtime to schedule evening reminders, prevent late-night alarms, and send a final call before sleep.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.inkMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Bedtime Picker Row
                    Pressable(
                      onTap: _pickBedtime,
                      scale: 0.98,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: c.cardShadow,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: c.tint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                CupertinoIcons.clock_fill,
                                size: 22,
                                color: c.tealDeep,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bedtime',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap to change time',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: c.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: c.tint,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: c.teal.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: c.tealDeep,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),
                  ],
                ),
              ),

              // Bottom Actions: Primary Continue + Secondary Set Later
              Column(
                children: [
                  Pressable(
                    onTap: () async {
                      await widget.onBedtimeConfirmed(formattedTime);
                      widget.onNext();
                    },
                    scale: 0.97,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: c.teal,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: c.teal.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Save & Continue',
                          style: TextStyle(
                            color: c.onTeal,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Pressable(
                    onTap: () async {
                      await widget.onBedtimeConfirmed(null);
                      widget.onNext();
                    },
                    scale: 0.97,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: c.borderLight.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Set later in Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
