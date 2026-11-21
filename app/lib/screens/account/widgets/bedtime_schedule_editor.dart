import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/pillpal_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../presentation/widgets/platform_controls.dart';
import '../../../services/bedtime_service.dart';
import '../../confirm/widgets/rotary_time_picker.dart';

/// Critically damped iOS spring matching UIKit / SwiftUI `.spring(duration: 0.35, bounce: 0)`.
/// Starts immediately on frame 1 with zero sluggish ramp-up and settles smoothly
/// without overshoot.
final SpringDescription kAppleSpring = SpringDescription.withDampingRatio(
  mass: 1.0,
  stiffness: 320.0,
  ratio: 1.0,
);

/// Slightly snappier critically damped spring for compact controls like
/// `UISegmentedControl` thumb movement.
final SpringDescription kAppleSnappySpring = SpringDescription.withDampingRatio(
  mass: 1.0,
  stiffness: 460.0,
  ratio: 1.0,
);

const Tolerance _kSpringTolerance = Tolerance(
  distance: 0.001,
  velocity: 0.001,
);

/// Stock iOS Settings-style disclosure transition (`UITableView` `.top` insert/delete):
/// - Anchors to `Alignment.bottomCenter` inside a `ClipRect`, so the revealing
///   block physically descends out from underneath the toggle card above it
///   as one solid piece (no bottom-edge cropping) and ascends back up behind it
///   while fading away when toggled off.
/// - Driven by a true interruptible critically damped [SpringSimulation].
/// - Unmounts [child] once fully collapsed and respects Reduce Motion.
class AppleDisclosureReveal extends StatefulWidget {
  const AppleDisclosureReveal({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<AppleDisclosureReveal> createState() => _AppleDisclosureRevealState();
}

class _AppleDisclosureRevealState extends State<AppleDisclosureReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _isOpening;

  @override
  void initState() {
    super.initState();
    _isOpening = widget.visible;
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.visible ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant AppleDisclosureReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      _isOpening = widget.visible;
      final target = widget.visible ? 1.0 : 0.0;
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disableAnimations) {
        _controller.value = target;
      } else {
        final sim = SpringSimulation(
          kAppleSpring,
          _controller.value,
          target,
          _controller.velocity,
          tolerance: _kSpringTolerance,
        );
        _controller.animateWith(sim).whenComplete(() {
          if (!mounted) return;
          if (!_controller.isAnimating && widget.visible == (target == 1.0)) {
            _controller.value = target;
            setState(() {});
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final v = _controller.value.clamp(0.0, 1.0);
        if (!widget.visible && !_controller.isAnimating && v <= 0.001) {
          return const SizedBox.shrink();
        }
        // On exit, fade out cleanly slightly ahead of reaching 0 height so
        // nothing looks clipped while ascending; on entry, fade in smoothly
        // right as the drawer emerges.
        final double opacity;
        if (_isOpening) {
          opacity = Curves.easeOut.transform(((v - 0.10) / 0.90).clamp(0.0, 1.0));
        } else {
          opacity = Curves.easeIn.transform(((v - 0.22) / 0.78).clamp(0.0, 1.0));
        }

        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: v,
            child: Opacity(
              opacity: opacity,
              child: IgnorePointer(
                ignoring: !widget.visible,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Stock iOS Health / Settings segmented-content transition:
/// performs a fast, non-overlapping sequential dissolve (outgoing fades cleanly
/// before incoming appears, avoiding double-bordered card ghosting) paired with
/// smooth spring-like height adjustment.
class _AppleSegmentedContentSwitcher extends StatelessWidget {
  const _AppleSegmentedContentSwitcher({
    required this.activeKey,
    required this.child,
  });

  final Object activeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final instant = MediaQuery.of(context).disableAnimations;
    return AnimatedSize(
      duration: instant ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: instant ? Duration.zero : const Duration(milliseconds: 240),
        reverseDuration:
            instant ? Duration.zero : const Duration(milliseconds: 240),
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          if (instant) return child;
          final isIncoming = child.key == activeKey;
          // Outgoing finishes fading out in the first 35% of the transition;
          // incoming begins fading in immediately after (35% -> 100%) so two
          // bordered cards never ghost over each other.
          final CurvedAnimation curvedOpacity = CurvedAnimation(
            parent: animation,
            curve: isIncoming
                ? const Interval(0.35, 1.0, curve: Curves.easeOut)
                : const Interval(0.65, 1.0, curve: Curves.easeIn),
          );
          return FadeTransition(
            opacity: curvedOpacity,
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

/// Shared 7-day Bedtime & Wake Time schedule editor used in both
/// `BedtimeScreen` (Settings → Bedtime) and `Step5Bedtime` (Onboarding).
class BedtimeScheduleEditor extends StatefulWidget {
  const BedtimeScheduleEditor({
    super.key,
    required this.schedule,
    required this.onChanged,
    this.initialSelectedWeekday,
  });

  final BedtimeSchedule schedule;
  final ValueChanged<BedtimeSchedule> onChanged;
  final int? initialSelectedWeekday;

  @override
  State<BedtimeScheduleEditor> createState() => _BedtimeScheduleEditorState();
}

class _BedtimeScheduleEditorState extends State<BedtimeScheduleEditor> {
  late int _selectedWeekday;
  late BedtimeScheduleMode _lastMode;
  int _modeTransitionSeq = 0;
  int _dayHeaderSeq = 0;

  /// Calendar order: S M T W T F S (Sunday = 7, Monday = 1 .. Saturday = 6).
  static const List<({int weekday, String letter, String name})> _calendarDays =
      [
    (weekday: DateTime.sunday, letter: 'S', name: 'Sunday'),
    (weekday: DateTime.monday, letter: 'M', name: 'Monday'),
    (weekday: DateTime.tuesday, letter: 'T', name: 'Tuesday'),
    (weekday: DateTime.wednesday, letter: 'W', name: 'Wednesday'),
    (weekday: DateTime.thursday, letter: 'T', name: 'Thursday'),
    (weekday: DateTime.friday, letter: 'F', name: 'Friday'),
    (weekday: DateTime.saturday, letter: 'S', name: 'Saturday'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedWeekday = widget.initialSelectedWeekday ?? DateTime.now().weekday;
    _lastMode = widget.schedule.mode;
  }

  @override
  void didUpdateWidget(covariant BedtimeScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schedule.mode != _lastMode) {
      _lastMode = widget.schedule.mode;
      _modeTransitionSeq++;
    }
  }

  int get _selectedCalendarIndex {
    final idx = _calendarDays.indexWhere((d) => d.weekday == _selectedWeekday);
    return idx >= 0 ? idx : 0;
  }

  void _stepDay(int delta) {
    HapticFeedback.selectionClick();
    final nextIdx = (_selectedCalendarIndex + delta + _calendarDays.length) %
        _calendarDays.length;
    setState(() {
      _selectedWeekday = _calendarDays[nextIdx].weekday;
      _dayHeaderSeq++;
    });
  }

  void _selectCalendarDay(int targetWeekday) {
    if (targetWeekday == _selectedWeekday) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedWeekday = targetWeekday;
      _dayHeaderSeq++;
    });
  }

  Future<void> _pickTime({
    required String currentLabel,
    required ValueChanged<String> onPicked,
  }) async {
    final initial = parseTimeOfDayLabel(currentLabel);
    final picked = await showRotaryTimePicker(context, initialTime: initial);
    if (picked != null && mounted) {
      onPicked(formatTimeOfDayLabel(picked));
    }
  }

  String _formatDuration(DayBedtimeWindow window) {
    final mins = window.durationMinutes;
    if (mins == null) return 'Quiet window disabled (start and end match)';
    final hours = mins ~/ 60;
    final rem = mins % 60;
    if (rem == 0) {
      return '$hours ${hours == 1 ? 'hr' : 'hrs'} quiet window';
    }
    if (hours == 0) {
      return '$rem min quiet window';
    }
    return '${hours}h ${rem}m quiet window';
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final modeKey = ValueKey<String>(
      '${schedule.mode.name}_$_modeTransitionSeq',
    );

    final Widget modeContent = KeyedSubtree(
      key: modeKey,
      child: switch (schedule.mode) {
        BedtimeScheduleMode.everyDay => _buildEveryDayCard(context, schedule),
        BedtimeScheduleMode.weekdaysAndWeekends =>
          _buildWeekdaysAndWeekends(context, schedule),
        BedtimeScheduleMode.custom => _buildCustomDays(context, schedule),
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeSegmentedControl(
          mode: schedule.mode,
          onChanged: (nextMode) {
            if (nextMode == schedule.mode) return;
            HapticFeedback.selectionClick();
            widget.onChanged(schedule.switchedToMode(nextMode));
          },
        ),
        const SizedBox(height: 16),
        _AppleSegmentedContentSwitcher(
          activeKey: modeKey,
          child: modeContent,
        ),
      ],
    );
  }

  Widget _buildEveryDayCard(BuildContext context, BedtimeSchedule schedule) {
    final c = context.colors;
    final window = schedule.windowForWeekday(DateTime.monday);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        children: [
          _TimePickerRow(
            key: const Key('bedtime_picker_every_day'),
            icon: CupertinoIcons.moon_fill,
            title: 'Bedtime',
            subtitle: 'Quiet hours begin',
            timeLabel: window.bedtime,
            onTap: () => _pickTime(
              currentLabel: window.bedtime,
              onPicked: (val) => widget.onChanged(
                schedule.withEveryDayWindow(
                  window.copyWith(enabled: true, bedtime: val),
                ),
              ),
            ),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: c.borderLight),
          _TimePickerRow(
            key: const Key('waketime_picker_every_day'),
            icon: CupertinoIcons.sunrise_fill,
            title: 'Wake Time',
            subtitle: 'Reminders resume',
            timeLabel: window.wakeTime,
            onTap: () => _pickTime(
              currentLabel: window.wakeTime,
              onPicked: (val) => widget.onChanged(
                schedule.withEveryDayWindow(
                  window.copyWith(enabled: true, wakeTime: val),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: c.borderLight),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(CupertinoIcons.clock, size: 14, color: c.inkMuted),
                const SizedBox(width: 6),
                Text(
                  '${_formatDuration(window)} every night',
                  style: TextStyle(fontSize: 12, color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaysAndWeekends(
    BuildContext context,
    BedtimeSchedule schedule,
  ) {
    final weekdayWindow = schedule.windowForWeekday(DateTime.monday);
    final weekendWindow = schedule.windowForWeekday(DateTime.saturday);

    return Column(
      children: [
        _DayGroupCard(
          title: 'Weekdays',
          subtitle: 'Mon – Fri',
          window: weekdayWindow,
          toggleKey: const Key('bedtime_weekdays_toggle'),
          bedtimeKey: const Key('bedtime_picker_weekdays'),
          wakeTimeKey: const Key('waketime_picker_weekdays'),
          durationText: _formatDuration(weekdayWindow),
          onToggle: (enabled) => widget.onChanged(
            schedule.withWeekdaysWindow(
              weekdayWindow.copyWith(enabled: enabled),
            ),
          ),
          onPickBedtime: () => _pickTime(
            currentLabel: weekdayWindow.bedtime,
            onPicked: (val) => widget.onChanged(
              schedule.withWeekdaysWindow(
                weekdayWindow.copyWith(bedtime: val),
              ),
            ),
          ),
          onPickWakeTime: () => _pickTime(
            currentLabel: weekdayWindow.wakeTime,
            onPicked: (val) => widget.onChanged(
              schedule.withWeekdaysWindow(
                weekdayWindow.copyWith(wakeTime: val),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DayGroupCard(
          title: 'Weekends',
          subtitle: 'Sat – Sun',
          window: weekendWindow,
          toggleKey: const Key('bedtime_weekends_toggle'),
          bedtimeKey: const Key('bedtime_picker_weekends'),
          wakeTimeKey: const Key('waketime_picker_weekends'),
          durationText: _formatDuration(weekendWindow),
          onToggle: (enabled) => widget.onChanged(
            schedule.withWeekendsWindow(
              weekendWindow.copyWith(enabled: enabled),
            ),
          ),
          onPickBedtime: () => _pickTime(
            currentLabel: weekendWindow.bedtime,
            onPicked: (val) => widget.onChanged(
              schedule.withWeekendsWindow(
                weekendWindow.copyWith(bedtime: val),
              ),
            ),
          ),
          onPickWakeTime: () => _pickTime(
            currentLabel: weekendWindow.wakeTime,
            onPicked: (val) => widget.onChanged(
              schedule.withWeekendsWindow(
                weekendWindow.copyWith(wakeTime: val),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDays(BuildContext context, BedtimeSchedule schedule) {
    final c = context.colors;
    final instant = MediaQuery.of(context).disableAnimations;
    final currentDay = _calendarDays[_selectedCalendarIndex];
    final window = schedule.windowForWeekday(currentDay.weekday);
    final headerKey = ValueKey<String>(
      '${currentDay.weekday}_${window.enabled}_${window.bedtime}_${window.wakeTime}_$_dayHeaderSeq',
    );

    return Column(
      children: [
        // Row of 7 circular S M T W T F S day pills
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final day in _calendarDays)
              _DayPillCircle(
                key: ValueKey('bedtime_day_pill_${day.weekday}'),
                letter: day.letter,
                semanticDayName: day.name,
                isSelected: day.weekday == _selectedWeekday,
                isActive: schedule.windowForWeekday(day.weekday).enabled,
                onTap: () => _selectCalendarDay(day.weekday),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Selected day editor card with < Day Name > header directly under pills
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.borderLight),
          ),
          child: Column(
            children: [
              // Prev / Day Name / Next header bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                child: Row(
                  children: [
                    _DayStepButton(
                      key: const Key('bedtime_prev_day_button'),
                      icon: CupertinoIcons.chevron_left,
                      tooltip: 'Previous day',
                      onTap: () => _stepDay(-1),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: instant
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) {
                          if (instant) return child;
                          final isIncoming = child.key == headerKey;
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: isIncoming
                                  ? const Interval(0.35, 1.0,
                                      curve: Curves.easeOut)
                                  : const Interval(0.65, 1.0,
                                      curve: Curves.easeIn),
                            ),
                            child: child,
                          );
                        },
                        child: Column(
                          key: headerKey,
                          children: [
                            Text(
                              currentDay.name,
                              key: const ValueKey('bedtime_selected_day_label'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              window.enabled
                                  ? '${window.bedtime} – ${window.wakeTime}'
                                  : 'Quiet hours off',
                              style: TextStyle(
                                fontSize: 12,
                                color: window.enabled ? c.teal : c.inkMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _DayStepButton(
                      key: const Key('bedtime_next_day_button'),
                      icon: CupertinoIcons.chevron_right,
                      tooltip: 'Next day',
                      onTap: () => _stepDay(1),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.borderLight),

              // Active switch for this specific day
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bedtime active on ${currentDay.name}s',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ),
                    PlatformSwitch(
                      key: const Key('bedtime_custom_day_toggle'),
                      value: window.enabled,
                      activeThumbColor: c.onTeal,
                      activeTrackColor: c.teal,
                      onChanged: (enabled) {
                        HapticFeedback.selectionClick();
                        widget.onChanged(
                          schedule.withDay(
                            currentDay.weekday,
                            window.copyWith(enabled: enabled),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              AppleDisclosureReveal(
                visible: window.enabled,
                child: Column(
                  children: [
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: c.borderLight),
                    _TimePickerRow(
                      key: const Key('bedtime_picker_custom'),
                      icon: CupertinoIcons.moon_fill,
                      title: 'Bedtime',
                      subtitle: 'Quiet hours begin',
                      timeLabel: window.bedtime,
                      onTap: () => _pickTime(
                        currentLabel: window.bedtime,
                        onPicked: (val) => widget.onChanged(
                          schedule.withDay(
                            currentDay.weekday,
                            window.copyWith(bedtime: val),
                          ),
                        ),
                      ),
                    ),
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: c.borderLight),
                    _TimePickerRow(
                      key: const Key('waketime_picker_custom'),
                      icon: CupertinoIcons.sunrise_fill,
                      title: 'Wake Time',
                      subtitle: 'Reminders resume',
                      timeLabel: window.wakeTime,
                      onTap: () => _pickTime(
                        currentLabel: window.wakeTime,
                        onPicked: (val) => widget.onChanged(
                          schedule.withDay(
                            currentDay.weekday,
                            window.copyWith(wakeTime: val),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: c.borderLight),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.clock,
                              size: 14, color: c.inkMuted),
                          const SizedBox(width: 6),
                          Text(
                            _formatDuration(window),
                            style: TextStyle(fontSize: 12, color: c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppleDisclosureReveal(
                visible: !window.enabled,
                child: Column(
                  children: [
                    Divider(height: 1, color: c.borderLight),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Quiet hours are off on ${currentDay.name}s — reminders will notify normally.',
                        style: TextStyle(
                          fontSize: 13,
                          color: c.inkMuted,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Stock iOS `UISegmentedControl`-style mode switcher with a critically damped
/// spring thumb and fading hairline dividers between unselected segments.
class _ModeSegmentedControl extends StatefulWidget {
  const _ModeSegmentedControl({
    required this.mode,
    required this.onChanged,
  });

  final BedtimeScheduleMode mode;
  final ValueChanged<BedtimeScheduleMode> onChanged;

  @override
  State<_ModeSegmentedControl> createState() => _ModeSegmentedControlState();
}

class _ModeSegmentedControlState extends State<_ModeSegmentedControl>
    with TickerProviderStateMixin {
  static const _segments = [
    (mode: BedtimeScheduleMode.everyDay, label: 'Every Day', flex: 2),
    (
      mode: BedtimeScheduleMode.weekdaysAndWeekends,
      label: 'Weekdays & Weekends',
      flex: 3,
    ),
    (mode: BedtimeScheduleMode.custom, label: 'Custom', flex: 2),
  ];

  late final AnimationController _leftController;
  late final AnimationController _widthController;

  static (double left, double width) _fractionsFor(BedtimeScheduleMode mode) {
    final totalFlex = _segments.fold<int>(0, (sum, s) => sum + s.flex);
    final idx = _segments.indexWhere((s) => s.mode == mode);
    double offset = 0;
    for (var i = 0; i < idx; i++) {
      offset += _segments[i].flex / totalFlex;
    }
    final width = idx >= 0 ? _segments[idx].flex / totalFlex : 1 / 3;
    return (offset, width);
  }

  @override
  void initState() {
    super.initState();
    final (left, width) = _fractionsFor(widget.mode);
    _leftController = AnimationController.unbounded(vsync: this, value: left);
    _widthController = AnimationController.unbounded(vsync: this, value: width);
  }

  @override
  void didUpdateWidget(covariant _ModeSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode) {
      final (targetLeft, targetWidth) = _fractionsFor(widget.mode);
      final instant = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (instant) {
        _leftController.value = targetLeft;
        _widthController.value = targetWidth;
      } else {
        _leftController.animateWith(
          SpringSimulation(
            kAppleSnappySpring,
            _leftController.value,
            targetLeft,
            _leftController.velocity,
            tolerance: _kSpringTolerance,
          ),
        );
        _widthController.animateWith(
          SpringSimulation(
            kAppleSnappySpring,
            _widthController.value,
            targetWidth,
            _widthController.velocity,
            tolerance: _kSpringTolerance,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _leftController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final instant = MediaQuery.of(context).disableAnimations;
    final selectedIdx = _segments.indexWhere((s) => s.mode == widget.mode);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: c.segmentTrack,
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalW = constraints.maxWidth;
          final totalFlex = _segments.fold<int>(0, (sum, s) => sum + s.flex);

          // Divider positions between segment 0|1 and segment 1|2
          final divider1X = (_segments[0].flex / totalFlex) * totalW;
          final divider2X =
              ((_segments[0].flex + _segments[1].flex) / totalFlex) * totalW;

          return Stack(
            children: [
              // Native UISegmentedControl hairline dividers that fade out when adjacent to the thumb
              Positioned(
                left: divider1X - 0.35,
                top: 7,
                bottom: 7,
                child: AnimatedOpacity(
                  duration: instant
                      ? Duration.zero
                      : const Duration(milliseconds: 140),
                  opacity: (selectedIdx == 0 || selectedIdx == 1) ? 0.0 : 1.0,
                  child: Container(
                    width: 0.7,
                    color: c.inkMuted.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Positioned(
                left: divider2X - 0.35,
                top: 7,
                bottom: 7,
                child: AnimatedOpacity(
                  duration: instant
                      ? Duration.zero
                      : const Duration(milliseconds: 140),
                  opacity: (selectedIdx == 1 || selectedIdx == 2) ? 0.0 : 1.0,
                  child: Container(
                    width: 0.7,
                    color: c.inkMuted.withValues(alpha: 0.28),
                  ),
                ),
              ),

              // Critically damped spring thumb
              AnimatedBuilder(
                animation: Listenable.merge([_leftController, _widthController]),
                builder: (context, child) {
                  return Positioned(
                    left: (_leftController.value * totalW).clamp(0.0, totalW),
                    top: 0,
                    bottom: 0,
                    width: (_widthController.value * totalW).clamp(0.0, totalW),
                    child: child!,
                  );
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.segmentThumb,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.04),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.liftShadow,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              Row(
                children: [
                  for (final seg in _segments)
                    Expanded(
                      flex: seg.flex,
                      child: GestureDetector(
                        key: ValueKey('bedtime_mode_${seg.mode.name}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onChanged(seg.mode),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                seg.label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: seg.mode == widget.mode
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: seg.mode == widget.mode
                                      ? c.ink
                                      : c.inkMuted,
                                  letterSpacing: -0.15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayPillCircle extends StatelessWidget {
  const _DayPillCircle({
    super.key,
    required this.letter,
    required this.semanticDayName,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
  });

  final String letter;
  final String semanticDayName;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final Color bgColor;
    final Color textColor;
    final Border? border;
    final List<BoxShadow>? shadows;

    if (isSelected && isActive) {
      bgColor = c.teal;
      textColor = c.onTeal;
      border = null;
      shadows = [
        BoxShadow(
          color: c.teal.withValues(alpha: 0.28),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isActive) {
      bgColor = c.tint;
      textColor = c.tealDeep;
      border = Border.all(
        color: c.teal.withValues(alpha: 0.45),
        width: 1.5,
      );
      shadows = null;
    } else if (isSelected) {
      bgColor = c.segmentTrack;
      textColor = c.inkMuted;
      border = Border.all(color: c.inkMuted, width: 2.0);
      shadows = null;
    } else {
      bgColor = c.segmentTrack.withValues(alpha: 0.7);
      textColor = c.inkMuted.withValues(alpha: 0.45);
      border = Border.all(
        color: c.borderLight.withValues(alpha: 0.7),
        width: 1.0,
      );
      shadows = null;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$semanticDayName, ${isActive ? 'active' : 'off'}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: border,
            boxShadow: shadows,
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayStepButton extends StatelessWidget {
  const _DayStepButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.segmentTrack.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: c.ink),
        ),
      ),
    );
  }
}

class _DayGroupCard extends StatelessWidget {
  const _DayGroupCard({
    required this.title,
    required this.subtitle,
    required this.window,
    required this.toggleKey,
    required this.bedtimeKey,
    required this.wakeTimeKey,
    required this.durationText,
    required this.onToggle,
    required this.onPickBedtime,
    required this.onPickWakeTime,
  });

  final String title;
  final String subtitle;
  final DayBedtimeWindow window;
  final Key toggleKey;
  final Key bedtimeKey;
  final Key wakeTimeKey;
  final String durationText;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickBedtime;
  final VoidCallback onPickWakeTime;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                PlatformSwitch(
                  key: toggleKey,
                  value: window.enabled,
                  activeThumbColor: c.onTeal,
                  activeTrackColor: c.teal,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),
          AppleDisclosureReveal(
            visible: window.enabled,
            child: Column(
              children: [
                Divider(height: 1, color: c.borderLight),
                _TimePickerRow(
                  key: bedtimeKey,
                  icon: CupertinoIcons.moon_fill,
                  title: 'Bedtime',
                  subtitle: 'Quiet hours begin',
                  timeLabel: window.bedtime,
                  onTap: onPickBedtime,
                ),
                Divider(
                    height: 1, indent: 16, endIndent: 16, color: c.borderLight),
                _TimePickerRow(
                  key: wakeTimeKey,
                  icon: CupertinoIcons.sunrise_fill,
                  title: 'Wake Time',
                  subtitle: 'Reminders resume',
                  timeLabel: window.wakeTime,
                  onTap: onPickWakeTime,
                ),
                Divider(height: 1, color: c.borderLight),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.clock, size: 13, color: c.inkMuted),
                      const SizedBox(width: 6),
                      Text(
                        durationText,
                        style: TextStyle(fontSize: 12, color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppleDisclosureReveal(
            visible: !window.enabled,
            child: Column(
              children: [
                Divider(height: 1, color: c.borderLight),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Quiet hours off on ${title.toLowerCase()}.',
                      style: TextStyle(fontSize: 12.5, color: c.inkMuted),
                    ),
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

class _TimePickerRow extends StatelessWidget {
  const _TimePickerRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final instant = MediaQuery.of(context).disableAnimations;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: c.tealDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: c.inkMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.tint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.teal.withValues(alpha: 0.25)),
              ),
              child: AnimatedSwitcher(
                duration: instant
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                child: Text(
                  timeLabel,
                  key: ValueKey<String>(timeLabel),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: c.tealDeep,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
