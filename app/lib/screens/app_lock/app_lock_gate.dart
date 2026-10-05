import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/services/app_lock_service.dart';

/// Covers the whole app (including any open sheet: this sits above the
/// Navigator, in `MaterialApp.builder`) while it's locked, and asks for the
/// device's own unlock. The app stays mounted underneath, so unlocking
/// doesn't reset where you were.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.service, required this.child});

  final AppLockService service;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late bool _locked = widget.service.isEnabled; // cold start: locked if on
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = widget.service;
    if (!service.isEnabled || _locked) return;
    // Only time spent while *unlocked* counts: the device-credential prompt
    // itself pauses the app, and that must not start the clock.
    if (state == AppLifecycleState.paused) {
      service.recordBackgrounded();
    } else if (state == AppLifecycleState.resumed &&
        service.shouldRelockOnResume()) {
      setState(() => _locked = true);
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    setState(() => _prompting = true);
    var ok = await widget.service.authenticate();
    // The phone's own lock was removed after App Lock was turned on: there's
    // nothing left to check against, and staying locked would shut the
    // person out of their own data. Anyone can already open the phone.
    if (!ok && !await widget.service.isDeviceSupported()) {
      await widget.service.setEnabled(false);
      ok = true;
    }
    if (!mounted) return;
    setState(() {
      _prompting = false;
      if (ok) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: _locked,
          child: TickerMode(enabled: !_locked, child: widget.child),
        ),
        if (_locked)
          Positioned.fill(
            child: LockScreen(onUnlock: _unlock, busy: _prompting),
          ),
      ],
    );
  }
}

class LockScreen extends StatelessWidget {
  const LockScreen({super.key, required this.onUnlock, required this.busy});

  final VoidCallback onUnlock;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration:
                    BoxDecoration(color: c.tint, shape: BoxShape.circle),
                child:
                    Icon(CupertinoIcons.lock_fill, size: 32, color: c.tealDeep),
              ),
              const SizedBox(height: 20),
              Text(
                'PillPal is Locked',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Use your phone's PIN, pattern or fingerprint to open it.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.inkMuted, height: 1.4),
              ),
              const SizedBox(height: 28),
              FilledButton(
                key: const Key('unlock_button'),
                onPressed: busy ? null : onUnlock,
                style: FilledButton.styleFrom(
                  backgroundColor: c.teal,
                  foregroundColor: c.onTeal,
                  minimumSize: const Size(160, 48),
                ),
                child: const Text('Unlock',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
