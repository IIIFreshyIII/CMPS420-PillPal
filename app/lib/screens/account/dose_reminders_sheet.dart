import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pillpal_colors.dart';
import '../../data/services/notification_service.dart';

/// Status + grant UI for the two Android permissions dose reminders need --
/// `POST_NOTIFICATIONS` (show anything at all) and the exact-alarm grant
/// (precise timing; see `notification_service.dart` for why exact was
/// chosen over approximate delivery). Reads live status from the plugin
/// rather than assuming, since the user can also grant/revoke these from
/// system settings outside the app.
class DoseRemindersSheet extends StatefulWidget {
  const DoseRemindersSheet({super.key, required this.notificationService});

  final NotificationService notificationService;

  static Future<void> show(
    BuildContext context, {
    required NotificationService notificationService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          DoseRemindersSheet(notificationService: notificationService),
    );
  }

  @override
  State<DoseRemindersSheet> createState() => _DoseRemindersSheetState();
}

class _DoseRemindersSheetState extends State<DoseRemindersSheet> {
  bool _loading = true;
  bool _notificationsEnabled = false;
  bool _exactAlarmsGranted = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    final notifications =
        await widget.notificationService.areNotificationsEnabled();
    final exactAlarms =
        await widget.notificationService.hasExactAlarmPermission();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notifications;
      _exactAlarmsGranted = exactAlarms;
      _loading = false;
    });
  }

  Future<void> _grantMissing() async {
    await widget.notificationService.requestPermissions();
    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final allGranted = _notificationsEnabled && _exactAlarmsGranted;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4.5,
                decoration: BoxDecoration(
                  color: c.grabber,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  Text(
                    'Dose Reminders',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.ink),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            Divider(height: 1, color: c.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.borderLight),
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Column(
                            children: [
                              _StatusRow(
                                  label: 'Notifications',
                                  granted: _notificationsEnabled),
                              Divider(height: 20, color: c.borderLight),
                              _StatusRow(
                                  label: 'Exact Timing',
                                  granted: _exactAlarmsGranted),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  if (!_loading && !allGranted)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('grant_reminder_permissions_button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: c.teal,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _grantMissing,
                        child: const Text('Grant Permissions'),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    "Both are needed for a medication's reminders to actually fire at the right "
                    "time. Exact timing requires a one-time grant on a system settings screen -- "
                    "Android shows this separately from the usual notification prompt.",
                    style: TextStyle(fontSize: 11, color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        Row(
          children: [
            Icon(
              granted
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: granted ? c.teal : c.alert,
            ),
            const SizedBox(width: 6),
            Text(
              granted ? 'Granted' : 'Not granted',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: granted ? c.tealDeep : c.alert,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
