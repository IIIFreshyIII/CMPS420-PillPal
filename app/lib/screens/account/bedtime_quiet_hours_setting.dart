import 'package:flutter/cupertino.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../services/bedtime_service.dart';
import 'bedtime_screen.dart';

/// Settings → Reminders & Sleep → Bedtime row.
/// Displays a concise live preview of the device-level Bedtime Quiet Hours
/// status (Off, Paused tonight, or active schedule summary) and pushes the
/// dedicated [BedtimeScreen] via a right-to-left [CupertinoPageRoute].
class BedtimeSettingRow extends StatefulWidget {
  const BedtimeSettingRow({
    super.key,
    this.service,
  });

  final BedtimeService? service;

  @override
  State<BedtimeSettingRow> createState() => _BedtimeSettingRowState();
}

class _BedtimeSettingRowState extends State<BedtimeSettingRow> {
  late BedtimeService _service;
  bool _ownsService = false;

  @override
  void initState() {
    super.initState();
    _bindService(widget.service);
  }

  @override
  void didUpdateWidget(covariant BedtimeSettingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.service != oldWidget.service) {
      if (_ownsService) {
        _service.dispose();
        _ownsService = false;
      }
      _bindService(widget.service);
    }
  }

  void _bindService(BedtimeService? provided) {
    if (provided != null) {
      _service = provided;
      if (!_service.isLoaded) {
        _service.load();
      }
    } else {
      _service = BedtimeService();
      _ownsService = true;
      _service.load();
    }
  }

  @override
  void dispose() {
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final isEnabled = _service.isEnabled && _service.schedule.hasAnyActiveDay;
        final isPaused = isEnabled && _service.isPausedAt();
        final summary = _service.summaryLabel();

        return GestureDetector(
          key: const Key('bedtime_settings_row'),
          onTap: () => BedtimeScreen.push(context, service: _service),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPaused
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                  : c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPaused
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                    : c.borderLight,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPaused
                      ? CupertinoIcons.moon_zzz
                      : (isEnabled
                          ? CupertinoIcons.moon_stars_fill
                          : CupertinoIcons.moon_stars),
                  size: 20,
                  color: isPaused
                      ? const Color(0xFFD97706)
                      : (isEnabled ? c.teal : c.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bedtime',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        key: const ValueKey('bedtime_settings_subtitle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isPaused
                              ? const Color(0xFFD97706)
                              : c.inkMuted,
                          fontWeight:
                              isPaused ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: isPaused ? const Color(0xFFD97706) : c.inkMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
