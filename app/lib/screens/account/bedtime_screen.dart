import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../presentation/widgets/platform_controls.dart';
import '../../services/bedtime_service.dart';
import 'widgets/bedtime_schedule_editor.dart';

/// Dedicated device-level 7-day Bedtime Quiet Hours screen, pushed from
/// Settings via `CupertinoPageRoute` (right-to-left swoop).
class BedtimeScreen extends StatelessWidget {
  const BedtimeScreen({
    super.key,
    required this.service,
  });

  final BedtimeService service;

  static Future<void> push(
    BuildContext context, {
    required BedtimeService service,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => BedtimeScreen(service: service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final instant = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: c.background,
      appBar: CupertinoNavigationBar(
        backgroundColor: c.background.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: c.borderLight, width: 0.5),
        ),
        previousPageTitle: 'Settings',
        middle: Text(
          'Bedtime',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final schedule = service.schedule;
          final isEnabled = schedule.isEnabled;
          final hasActiveDays = schedule.hasAnyActiveDay;
          final isPaused = isEnabled && service.isPausedAt();
          final resumeLabel = service.pausedResumeLabel();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            children: [
              // 1. Master On/Off switch for the entire Bedtime feature
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.borderLight),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: instant
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isEnabled ? c.tint : c.segmentTrack,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        CupertinoIcons.moon_stars_fill,
                        size: 20,
                        color: isEnabled ? c.tealDeep : c.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bedtime Quiet Hours',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedSwitcher(
                            duration: instant
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                ...previous,
                                if (current != null) current,
                              ],
                            ),
                            child: Text(
                              isEnabled
                                  ? 'Silences reminders & snoozes during sleep'
                                  : 'Off — all reminders notify normally',
                              key: ValueKey<bool>(isEnabled),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PlatformSwitch(
                      key: const Key('bedtime_master_switch'),
                      value: isEnabled,
                      activeThumbColor: c.onTeal,
                      activeTrackColor: c.teal,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        service.setEnabled(val);
                      },
                    ),
                  ],
                ),
              ),

              // 2. Descending / ascending Apple disclosure for Pause Tonight & Schedule
              AppleDisclosureReveal(
                visible: isEnabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppleDisclosureReveal(
                      visible: hasActiveDays,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AnimatedContainer(
                          duration: instant
                              ? Duration.zero
                              : const Duration(milliseconds: 240),
                          curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                          decoration: BoxDecoration(
                            color: isPaused
                                ? const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.10)
                                : c.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isPaused
                                  ? const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.45)
                                  : c.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: instant
                                    ? Duration.zero
                                    : const Duration(milliseconds: 240),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isPaused
                                      ? const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.18)
                                      : c.segmentTrack.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  isPaused
                                      ? CupertinoIcons.moon_zzz_fill
                                      : CupertinoIcons.moon_zzz,
                                  size: 20,
                                  color: isPaused
                                      ? const Color(0xFFD97706)
                                      : c.inkMuted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPaused
                                          ? 'Paused for Tonight'
                                          : 'Pause Tonight',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: c.ink,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPaused && resumeLabel != null
                                          ? 'Auto-resumes $resumeLabel'
                                          : 'Allow reminders & snoozes tonight — resumes next bedtime',
                                      key: const ValueKey(
                                          'bedtime_pause_subtitle'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isPaused
                                            ? const Color(0xFFD97706)
                                            : c.inkMuted,
                                        fontWeight: isPaused
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PlatformSwitch(
                                key: const Key('bedtime_pause_tonight_switch'),
                                value: isPaused,
                                activeThumbColor: Colors.white,
                                activeTrackColor: const Color(0xFFF59E0B),
                                onChanged: (pause) async {
                                  HapticFeedback.selectionClick();
                                  if (pause) {
                                    await service.pauseTonight();
                                  } else {
                                    await service.resumeNow();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SLEEP SCHEDULE',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.inkMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    BedtimeScheduleEditor(
                      schedule: schedule,
                      onChanged: (updated) {
                        service.updateSchedule(updated);
                      },
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'A consolidated Pre-Bedtime Final Call fires 10 minutes before bedtime if you have pending doses. Medications with "Send reminders after bedtime" enabled will still notify.',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
