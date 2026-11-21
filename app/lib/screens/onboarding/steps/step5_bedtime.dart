import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../presentation/widgets/pressable.dart';
import '../../../services/bedtime_service.dart';
import '../../account/widgets/bedtime_schedule_editor.dart';

/// Step 5: Dedicated Device-Level Bedtime & Wake Time Setup.
/// Uses the shared [BedtimeScheduleEditor] so the user can quickly set
/// Every Day bedtime & wake time or customize by Weekdays/Weekends or Custom
/// days (with S M T W T F S circles and prev/next day navigation).
class Step5Bedtime extends StatefulWidget {
  const Step5Bedtime({
    super.key,
    required this.onBedtimeConfirmed,
    required this.onNext,
    this.initialSchedule,
  });

  final Future<void> Function(BedtimeSchedule? schedule) onBedtimeConfirmed;
  final VoidCallback onNext;
  final BedtimeSchedule? initialSchedule;

  @override
  State<Step5Bedtime> createState() => _Step5BedtimeState();
}

class _Step5BedtimeState extends State<Step5Bedtime> {
  late BedtimeSchedule _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = widget.initialSchedule ??
        BedtimeSchedule.everyDay(
          isEnabled: true,
          bedtime: DayBedtimeWindow.defaultBedtimeLabel,
          wakeTime: DayBedtimeWindow.defaultWakeTimeLabel,
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 44, bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Hero Sleep Illustration Container
                      Container(
                        width: 76,
                        height: 76,
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
                            size: 38,
                            color: c.teal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Set your sleep schedule',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                          letterSpacing: -0.6,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        'Choose the hours you don\'t want to be disturbed. PillPal pauses reminders during sleep and sends a final call beforehand.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: c.inkMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Shared 7-day Bedtime & Wake Time Editor
                      BedtimeScheduleEditor(
                        schedule: _schedule,
                        onChanged: (updated) {
                          setState(() => _schedule = updated);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions: Primary Continue + Secondary Set Later
              Column(
                children: [
                  const SizedBox(height: 8),
                  Pressable(
                    onTap: () async {
                      await widget.onBedtimeConfirmed(
                        _schedule.copyWith(isEnabled: true),
                      );
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
                          'Set later in Settings',
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
