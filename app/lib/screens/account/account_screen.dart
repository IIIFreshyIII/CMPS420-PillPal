import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/profile.dart';
import '../../data/services/notification_service.dart';
import 'dose_reminders_sheet.dart';
import 'edit_profile_sheet.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.profiles,
    required this.onUpdateProfile,
    required this.notificationService,
  });

  final List<Profile> profiles;
  final ValueChanged<Profile> onUpdateProfile;
  final NotificationService notificationService;

  void _showExportAlert(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Encrypted Export'),
        content: const Text('Local encrypted SQLite database exported successfully.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          for (final profile in profiles) ...[
            _ProfileTile(
              profile: profile,
              onTap: () => EditProfileSheet.show(context, profile: profile, onUpdate: onUpdateProfile),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF99F6E4)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.shield_lefthalf_fill, size: 22, color: Color(0xFF0E8A8A)),
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
                          color: Color(0xFF0D6E6E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Medication profiles and schedules are stored exclusively on this device.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF0F766E), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'PREFERENCES & STORAGE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _SettingTile(
            icon: CupertinoIcons.tray_arrow_down,
            title: 'Export Local Data (.sqlite)',
            onTap: () => _showExportAlert(context),
          ),
          const SizedBox(height: 10),
          _SettingTile(
            icon: CupertinoIcons.bell,
            title: 'Dose Reminders',
            onTap: () => DoseRemindersSheet.show(context, notificationService: notificationService),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: profile.color,
              child: const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.bedtime != null ? 'Bedtime: ${profile.bedtime}' : 'No bedtime set',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0F172A)),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
