import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/services/app_lock_service.dart';

/// Profile → Preferences & Storage → App Lock. Turning it on asks for the
/// device unlock once first, so nobody can turn on a lock their phone can't
/// satisfy. Turning it off needs no prompt (you're already inside).
class AppLockSetting extends StatefulWidget {
  const AppLockSetting({super.key, required this.service});

  final AppLockService service;

  @override
  State<AppLockSetting> createState() => _AppLockSettingState();
}

class _AppLockSettingState extends State<AppLockSetting> {
  bool? _supported;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.service.isDeviceSupported().then((v) {
      if (mounted) setState(() => _supported = v);
    });
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    if (!on || await widget.service.authenticate()) {
      await widget.service.setEnabled(on);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final supported = _supported ?? false;

    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderLight),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.lock, size: 20, color: c.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Lock',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _supported == false
                        ? 'Set a PIN, pattern or fingerprint on this phone first.'
                        : "Use your phone's lock to open PillPal.",
                    style: TextStyle(fontSize: 12, color: c.inkMuted),
                  ),
                ],
              ),
            ),
            Switch(
              key: const Key('app_lock_switch'),
              value: widget.service.isEnabled,
              activeThumbColor: c.onTeal,
              activeTrackColor: c.teal,
              onChanged: (!supported || _busy) ? null : _toggle,
            ),
          ],
        ),
      ),
    );
  }
}
