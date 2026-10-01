import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A bottom sheet combining a small live analog-clock preview with a
/// scrolling wheel picker for the actual input -- the clock is feedback
/// only, never tappable; every time change comes from the wheel.
Future<TimeOfDay?> showRotaryTimePicker(BuildContext context, {TimeOfDay? initialTime}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: AppTheme.cardWhite,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _RotaryTimePickerSheet(initialTime: initialTime ?? TimeOfDay.now()),
  );
}

class _RotaryTimePickerSheet extends StatefulWidget {
  const _RotaryTimePickerSheet({required this.initialTime});
  final TimeOfDay initialTime;

  @override
  State<_RotaryTimePickerSheet> createState() => _RotaryTimePickerSheetState();
}

class _RotaryTimePickerSheetState extends State<_RotaryTimePickerSheet> {
  late TimeOfDay _time = widget.initialTime;

  DateTime get _asDateTime {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Text('Reminder Time', style: TextStyle(fontWeight: FontWeight.w600)),
                TextButton(
                  key: const Key('rotary_time_done'),
                  onPressed: () => Navigator.of(context).pop(_time),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _AnalogClockPreview(time: _time, size: 84),
            SizedBox(
              height: 180,
              child: CupertinoDatePicker(
                key: const Key('rotary_time_wheel'),
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _asDateTime,
                use24hFormat: false,
                onDateTimeChanged: (dt) => setState(() => _time = TimeOfDay(hour: dt.hour, minute: dt.minute)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small, read-only clock face -- decorative feedback for the wheel above,
/// never an input target itself.
class _AnalogClockPreview extends StatelessWidget {
  const _AnalogClockPreview({required this.time, required this.size});
  final TimeOfDay time;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _ClockPainter(time)));
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.time);
  final TimeOfDay time;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius - 1, Paint()..color = AppTheme.background);
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = AppTheme.borderLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (var i = 0; i < 12; i++) {
      final angle = i * (math.pi / 6);
      final isMajor = i % 3 == 0;
      final outer = Offset(center.dx + (radius - 4) * math.sin(angle), center.dy - (radius - 4) * math.cos(angle));
      final inner = Offset(
        center.dx + (radius - (isMajor ? 10 : 6)) * math.sin(angle),
        center.dy - (radius - (isMajor ? 10 : 6)) * math.cos(angle),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = AppTheme.textSecondary
          ..strokeWidth = isMajor ? 2 : 1,
      );
    }

    final hourAngle = ((time.hourOfPeriod % 12) + time.minute / 60) * (math.pi / 6);
    final minuteAngle = time.minute * (math.pi / 30);

    canvas.drawLine(
      center,
      Offset(center.dx + radius * 0.45 * math.sin(hourAngle), center.dy - radius * 0.45 * math.cos(hourAngle)),
      Paint()
        ..color = AppTheme.textPrimary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      center,
      Offset(center.dx + radius * 0.7 * math.sin(minuteAngle), center.dy - radius * 0.7 * math.cos(minuteAngle)),
      Paint()
        ..color = AppTheme.interactiveTeal
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, 3, Paint()..color = AppTheme.interactiveTeal);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) => oldDelegate.time != time;
}
