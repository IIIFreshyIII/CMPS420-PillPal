import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/pillpal_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/services/app_lock_service.dart';
import '../../data/local/connection.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/services/notification_service.dart';
import 'add_profile_sheet.dart';
import 'app_lock_setting.dart';
import 'appearance_setting.dart';
import 'dose_reminders_sheet.dart';
import 'edit_profile_sheet.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.profiles,
    required this.prescriptions,
    required this.onUpdateProfile,
    required this.onDeleteProfile,
    required this.notificationService,
    this.themeController,
    this.appLock,
  });

  final List<Profile> profiles;
  final List<Prescription> prescriptions;
  final ValueChanged<Profile> onUpdateProfile;
  final ValueChanged<String> onDeleteProfile;
  final NotificationService notificationService;

  /// Null in widget tests that build this screen without the app root; the
  /// Appearance tile is simply omitted then.
  final ThemeController? themeController;
  final AppLockService? appLock;

  Future<void> _exportData(BuildContext context) async {
    final file = await databaseFile();
    if (!context.mounted) return;
    if (!file.existsSync()) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Nothing to Export'),
          content: const Text('No local data has been saved yet.'),
          actions: [
            CupertinoDialogAction(
                child: const Text('OK'), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      );
      return;
    }
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, name: 'pillpal.sqlite')],
      subject: 'PillPal encrypted local data export',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: c.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          for (final profile in profiles) ...[
            _ProfileTile(
              profile: profile,
              onTap: () => EditProfileSheet.show(
                context,
                profile: profile,
                onUpdate: onUpdateProfile,
                onDelete: () => onDeleteProfile(profile.id),
                hasPrescriptions:
                    prescriptions.any((p) => p.profileId == profile.id),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _AddProfileTile(
              onTap: () =>
                  AddProfileSheet.show(context, onAdd: onUpdateProfile)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.privacyBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.privacyBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.shield_lefthalf_fill,
                    size: 22, color: c.privacyIcon),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zero-Knowledge Architecture',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.privacyTitle,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Medication profiles and schedules are stored exclusively on this device.',
                        style: TextStyle(
                            fontSize: 12, color: c.privacyBody, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PREFERENCES & STORAGE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.inkMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (themeController != null) ...[
            AppearanceSetting(controller: themeController!),
            const SizedBox(height: 10),
          ],
          _SettingTile(
            icon: CupertinoIcons.tray_arrow_down,
            title: 'Export Local Data (.sqlite)',
            onTap: () => _exportData(context),
          ),
          const SizedBox(height: 10),
          if (appLock != null) ...[
            AppLockSetting(service: appLock!),
            const SizedBox(height: 10),
          ],
          _SettingTile(
            icon: CupertinoIcons.bell,
            title: 'Dose Reminders',
            onTap: () => DoseRemindersSheet.show(context,
                notificationService: notificationService),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile, required this.onTap});

  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.borderLight),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: profile.color,
              child:
                  Icon(CupertinoIcons.person_fill, color: c.tagText, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.bedtime != null
                        ? 'Bedtime: ${profile.bedtime}'
                        : 'No bedtime set',
                    style: TextStyle(fontSize: 13, color: c.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 16, color: c.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _AddProfileTile extends StatelessWidget {
  const _AddProfileTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: c.inkMuted.withValues(alpha: 0.4)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.add,
                  size: 18, color: c.inkMuted.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                'Add Family Member',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.inkMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashed rounded-rect border -- distinguishes "Add Family Member" from
/// the solid-bordered `_ProfileTile`s above it (there's nothing to tap
/// *into*, it starts a new flow instead).
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;
  static const _radius = 20.0;
  static const _dashWidth = 6.0;
  static const _gapWidth = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
            metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + _gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderLight),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.ink),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.ink,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
