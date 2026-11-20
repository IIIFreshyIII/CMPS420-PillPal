import 'package:flutter/cupertino.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/models/profile.dart';
import '../../presentation/widgets/platform_controls.dart';
import '../../services/snooze_settings_service.dart';

/// Account → Preferences & Storage → Bedtime Quiet Hours.
/// Lets the user temporarily pause bedtime quiet hours until 6:00 AM (e.g.,
/// for a late night) without permanently changing any profile's bedtime.
class BedtimeQuietHoursSetting extends StatefulWidget {
  const BedtimeQuietHoursSetting({
    super.key,
    this.service,
    required this.profiles,
  });

  final SnoozeSettingsService? service;
  final List<Profile> profiles;

  @override
  State<BedtimeQuietHoursSetting> createState() =>
      _BedtimeQuietHoursSettingState();
}

class _BedtimeQuietHoursSettingState extends State<BedtimeQuietHoursSetting> {
  late final SnoozeSettingsService _service;
  late final bool _ownsService;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _service = widget.service ?? SnoozeSettingsService();
    if (!_service.isLoaded) {
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

  String? _primaryBedtime() {
    if (widget.profiles.isEmpty) return null;
    final primary = widget.profiles.firstWhere(
      (p) => p.isPrimary,
      orElse: () => widget.profiles.first,
    );
    if (primary.bedtime != null && primary.bedtime!.trim().isNotEmpty) {
      return primary.bedtime!.trim();
    }
    for (final p in widget.profiles) {
      if (p.bedtime != null && p.bedtime!.trim().isNotEmpty) {
        return p.bedtime!.trim();
      }
    }
    return null;
  }

  Future<void> _onToggle(bool active) async {
    if (active) {
      await _service.resumeBedtimeQuietHours();
    } else {
      await _service.pauseBedtimeUntilMorning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bedtime = _primaryBedtime();
    final hasBedtime = bedtime != null;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final isPaused = hasBedtime && _service.isBedtimeBypassed();
        final subtitle = !hasBedtime
            ? 'Set a bedtime on a profile to enable quiet hours.'
            : isPaused
                ? 'Paused until 6:00 AM — reminders & snoozes allowed tonight.'
                : 'Active — pauses reminders after $bedtime.';

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borderLight),
          ),
          child: Row(
            children: [
              Icon(
                isPaused ? CupertinoIcons.moon_zzz : CupertinoIcons.moon_stars,
                size: 20,
                color: isPaused ? const Color(0xFFF59E0B) : c.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bedtime Quiet Hours',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      key: const ValueKey('bedtime_quiet_hours_subtitle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPaused ? const Color(0xFFD97706) : c.inkMuted,
                        fontWeight:
                            isPaused ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              PlatformSwitch(
                key: const Key('bedtime_quiet_hours_switch'),
                value: hasBedtime && !isPaused,
                activeThumbColor: c.onTeal,
                activeTrackColor: c.teal,
                onChanged: hasBedtime ? _onToggle : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
