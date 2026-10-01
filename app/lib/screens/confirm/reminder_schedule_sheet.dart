import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/scheduling/reminder_scheduler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import 'widgets/rotary_time_picker.dart';

/// Step 2 of the scan-to-save flow: once the medication's identity is
/// confirmed (`ConfirmScreen`), this works out *when* to be reminded --
/// a single start time, expanded into a full day's worth of reminders when
/// the label's frequency describes a fixed interval (e.g. "every 4 hours"),
/// capped at the assigned profile's bedtime so nothing is scheduled
/// overnight. See `core/scheduling/reminder_scheduler.dart` for the
/// parsing/calculation logic this screen is a thin UI over.
///
/// Pops with the final ordered list of formatted reminder-time strings
/// (`["8:00 AM", "12:00 PM", ...]`), or `null` if the user backs out --
/// `ConfirmScreen` is the one that turns that into a saved [Prescription].
class ReminderScheduleSheet extends StatefulWidget {
  const ReminderScheduleSheet({super.key, required this.frequency, required this.bedtime});

  /// Raw OCR frequency text (e.g. "every 4 hours"), or null if none was read.
  final String? frequency;

  /// The assigned profile's bedtime, formatted like `formatTimeOfDayLabel`
  /// produces (e.g. "10:00 PM"), or null if they haven't set one.
  final String? bedtime;

  static Future<List<String>?> show(
    BuildContext context, {
    required String? frequency,
    required String? bedtime,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReminderScheduleSheet(frequency: frequency, bedtime: bedtime),
    );
  }

  @override
  State<ReminderScheduleSheet> createState() => _ReminderScheduleSheetState();
}

class _ReminderScheduleSheetState extends State<ReminderScheduleSheet> {
  TimeOfDay? _startTime;
  late final int? _intervalHours = parseFrequencyIntervalHours(widget.frequency);

  bool get _canSave => _startTime != null;

  Future<void> _pickStartTime() async {
    final picked = await showRotaryTimePicker(context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  String _intervalLabel(int hours) => hours == 24 ? 'Once a day' : 'Every $hours hours';

  void _save() {
    HapticFeedback.lightImpact();
    final start = _startTime!;
    final times = buildReminderTimes(
      startTime: start,
      intervalHours: _intervalHours,
      bedtime: parseTimeOfDayLabel(widget.bedtime),
    );
    Navigator.of(context).pop(times.map(formatTimeOfDayLabel).toList());
  }

  Widget _buildGlassCircleButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool enabled = true,
  }) {
    return GestureDetector(
      key: key,
      onTap: enabled ? onTap : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: !enabled
                  ? Colors.white.withValues(alpha: 0.5)
                  : isPrimary
                      ? AppTheme.interactiveTeal.withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.70),
              shape: BoxShape.circle,
              border: Border.all(
                color: !enabled
                    ? Colors.white.withValues(alpha: 0.6)
                    : isPrimary
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
              child: Icon(
                icon,
                size: 18,
                color: !enabled
                    ? AppTheme.textSecondary.withValues(alpha: 0.5)
                    : isPrimary
                        ? Colors.white
                        : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interval = _intervalHours;
    final computedTimes = _startTime == null || interval == null
        ? const <TimeOfDay>[]
        : buildReminderTimes(
            startTime: _startTime!,
            intervalHours: interval,
            bedtime: parseTimeOfDayLabel(widget.bedtime),
          );

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
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
                    icon: CupertinoIcons.xmark,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Reminder Schedule',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  _buildGlassCircleButton(
                    key: const Key('reminder_schedule_save_button'),
                    icon: CupertinoIcons.checkmark,
                    isPrimary: true,
                    enabled: _canSave,
                    onTap: _save,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderLight),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  const Text(
                    'START TIME',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: InkWell(
                      key: const Key('field_start_time'),
                      onTap: _pickStartTime,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('First dose (required)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              Text(
                                _startTime != null ? formatTimeOfDayLabel(_startTime!) : 'Tap to set',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _startTime != null
                                      ? AppTheme.interactiveTeal
                                      : AppTheme.lowStockAlert,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(CupertinoIcons.chevron_right, size: 14, color: AppTheme.textSecondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.frequency != null) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'FREQUENCY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OCR read frequency as: "${widget.frequency}"',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          if (interval != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _intervalLabel(interval),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (_startTime != null) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: computedTimes
                                    .map((t) => Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.lightPillTint,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Text(
                                            formatTimeOfDayLabel(t),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.interactiveTeal,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                              if (computedTimes.length > 1) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.bedtime != null
                                      ? 'Stops before your ${widget.bedtime} bedtime.'
                                      : 'No bedtime set for this profile yet -- stops at end of day.',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ],
                          ] else ...[
                            const SizedBox(height: 6),
                            const Text(
                              "We couldn't turn this into a repeating schedule -- only the time above will be used.",
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
