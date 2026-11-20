import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/state/app_state_manager.dart';
import '../../../core/theme/pillpal_colors.dart';
import '../../../data/services/notification_service.dart';
import '../../../presentation/widgets/platform_controls.dart';
import '../../../presentation/widgets/pressable.dart';

/// Step 4: Privacy & Protection.
/// Replaces the legacy "Permissions & Local Setup" wall with a reassuring,
/// user-centric security screen:
/// - Clear, plain-English App Lock (Face ID / Passcode)
/// - Dose Reminder Alerts toggle (Notifications)
/// - Reassurance that health data is strictly local, encrypted, and never phoned home.
class Step4Permissions extends StatefulWidget {
  const Step4Permissions({
    super.key,
    required this.appStateManager,
    required this.notificationService,
    required this.onNext,
  });

  final AppStateManager appStateManager;
  final NotificationService notificationService;
  final VoidCallback onNext;

  @override
  State<Step4Permissions> createState() => _Step4PermissionsState();
}

class _Step4PermissionsState extends State<Step4Permissions>
    with WidgetsBindingObserver {
  bool _notificationsGranted = false;
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _biometricsEnabled = widget.appStateManager.biometricsEnabled;
    _checkInitialNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInitialNotifications();
    }
  }

  Future<void> _checkInitialNotifications() async {
    final granted = await widget.notificationService.areNotificationsEnabled();
    if (mounted) {
      setState(() => _notificationsGranted = granted);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (!value) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Notifications Enabled'),
          content: const Text(
            'To turn off Dose Reminder Alerts, update PillPal notifications in your device Settings.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final granted = await widget.notificationService.requestPermissions();
    if (mounted) {
      setState(() => _notificationsGranted = granted);
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    setState(() => _biometricsEnabled = value);
    await widget.appStateManager.setBiometricsEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Privacy & Security',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Privacy Reassurance Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.tint,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.teal.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.shield_fill,
                            size: 22,
                            color: c.tealDeep,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Data Stays on Your Device',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: c.tealDeep,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PillPal has no cloud servers, no user accounts, and zero tracking. Your medical history is encrypted locally and never leaves your device.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: c.tealDeep.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'APP PROTECTION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: c.tealDeep,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Card 1: Face ID / Passcode Lock
                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: c.cardShadow,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildSwitchRow(
                        context: context,
                        icon: CupertinoIcons.lock_shield_fill,
                        title: 'Lock with Face ID / Passcode',
                        subtitle:
                            'Keep your medications private. Uses the same Face ID or passcode you use to unlock your phone, so nobody else holding your phone can peek into your prescriptions.',
                        value: _biometricsEnabled,
                        onChanged: _toggleBiometrics,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'DOSE REMINDERS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: c.tealDeep,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Card 2: Notifications Alert Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: c.cardShadow,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildSwitchRow(
                        context: context,
                        icon: CupertinoIcons.bell_fill,
                        title: 'Dose Reminder Alerts',
                        subtitle:
                            'Allow notifications so PillPal can remind you when it\'s time to take your doses.',
                        value: _notificationsGranted,
                        onChanged: _toggleNotifications,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // BOTTOM ACTION: CONTINUE BUTTON
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Pressable(
                onTap: () async {
                  await widget.appStateManager
                      .setBiometricsEnabled(_biometricsEnabled);
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
                      'Continue',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value ? c.tint : c.borderLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: value ? c.tealDeep : c.inkMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PlatformSwitch(
            value: value,
            activeThumbColor: c.onTeal,
            activeTrackColor: c.teal,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
