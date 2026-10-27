import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/pillpal_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/services/app_lock_service.dart';
import '../../data/local/connection.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import '../../data/local/app_database.dart';
import '../../data/models/dose_event.dart';
import '../../data/services/data_retention_service.dart';
import '../../data/services/notification_service.dart';
import '../../core/theme/liquid_glass_controller.dart';
import '../../core/utils/ios_design_era.dart';
import '../../services/snooze_settings_service.dart';
import '../../services/walkthrough_service.dart';
import '../../ui/widgets/walkthrough_overlay.dart';
import 'add_profile_sheet.dart';
import 'app_lock_setting.dart';
import 'appearance_setting.dart';
import 'default_snooze_setting.dart';
import 'dose_log_retention_sheet.dart';
import 'dose_reminders_sheet.dart';
import 'edit_profile_sheet.dart';
import 'liquid_glass_setting.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.profiles,
    required this.prescriptions,
    required this.onUpdateProfile,
    required this.onDeleteProfile,
    required this.notificationService,
    this.themeController,
    this.liquidGlassController,
    this.appLock,
    this.doseEvents = const [],
    this.retentionService,
    this.snoozeSettingsService,
    this.database,
    this.walkthroughService,
    this.isActive = true,
  });

  final List<Profile> profiles;
  final List<Prescription> prescriptions;
  final List<DoseEvent> doseEvents;
  final ValueChanged<Profile> onUpdateProfile;
  final ValueChanged<String> onDeleteProfile;
  final NotificationService notificationService;
  final DataRetentionService? retentionService;
  final SnoozeSettingsService? snoozeSettingsService;
  final AppDatabase? database;
  final WalkthroughService? walkthroughService;
  final bool isActive;

  /// Null in widget tests that build this screen without the app root; the
  /// Appearance tile is simply omitted then.
  final ThemeController? themeController;
  final LiquidGlassController? liquidGlassController;
  final AppLockService? appLock;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final GlobalKey _profilesKey =
      GlobalKey(debugLabel: 'walkthrough_account_profiles');
  final GlobalKey _snoozeKey =
      GlobalKey(debugLabel: 'walkthrough_account_snooze');
  final GlobalKey _appearanceKey =
      GlobalKey(debugLabel: 'walkthrough_account_appearance');
  final GlobalKey _appLockKey =
      GlobalKey(debugLabel: 'walkthrough_account_app_lock');

  bool _isShowingWalkthrough = false;
  OverlayEntry? _walkthroughOverlayEntry;

  @override
  void initState() {
    super.initState();
    widget.walkthroughService?.addListener(_onWalkthroughServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLaunchAccountWalkthrough();
    });
  }

  @override
  void didUpdateWidget(AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.walkthroughService != oldWidget.walkthroughService) {
      oldWidget.walkthroughService
          ?.removeListener(_onWalkthroughServiceChanged);
      widget.walkthroughService?.addListener(_onWalkthroughServiceChanged);
    }
    if (!widget.isActive && _isShowingWalkthrough) {
      _closeWalkthrough();
    } else if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeLaunchAccountWalkthrough();
      });
    }
  }

  @override
  void dispose() {
    widget.walkthroughService?.removeListener(_onWalkthroughServiceChanged);
    _closeWalkthrough();
    super.dispose();
  }

  void _closeWalkthrough() {
    if (_walkthroughOverlayEntry?.mounted ?? false) {
      _walkthroughOverlayEntry?.remove();
    }
    _walkthroughOverlayEntry = null;
    _isShowingWalkthrough = false;
  }

  void _onWalkthroughServiceChanged() {
    if (!mounted || !widget.isActive) return;
    _maybeLaunchAccountWalkthrough();
  }

  void _maybeLaunchAccountWalkthrough() {
    if (!mounted || !widget.isActive || _isShowingWalkthrough) return;
    final service = widget.walkthroughService;
    if (service == null) return;
    if (service.hasSeenCaregiverHint) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _isShowingWalkthrough = true;

    final steps = <WalkthroughStep>[
      WalkthroughStep(
        targetKey: _profilesKey,
        title: 'Caregiver & Family Profiles',
        description:
            'Add family members or care recipients to manage their schedules, color-code badges, and set custom bedtimes.',
        icon: CupertinoIcons.person_2_fill,
        borderRadius: 20.0,
      ),
      WalkthroughStep(
        targetKey: _snoozeKey,
        title: 'Custom Snooze Intervals',
        description:
            'Choose your preferred reminder snooze interval (5m, 9m, 15m, 30m) or enter a custom duration that suits your routine.',
        icon: CupertinoIcons.timer,
        borderRadius: 16.0,
      ),
      if (widget.themeController != null)
        WalkthroughStep(
          targetKey: _appearanceKey,
          title: 'Appearance & Dark Mode',
          description:
              'Seamlessly switch between Light, Dark, or System mode to match your lighting preferences day or night.',
          icon: CupertinoIcons.circle_lefthalf_fill,
          borderRadius: 16.0,
        ),
      if (widget.appLock != null)
        WalkthroughStep(
          targetKey: _appLockKey,
          title: 'Biometric Privacy & App Lock',
          description:
              'Secure your sensitive health data and prescription logs with Face ID, Touch ID, or device passcode authentication.',
          icon: CupertinoIcons.lock_shield_fill,
          borderRadius: 16.0,
        ),
    ];

    _walkthroughOverlayEntry = WalkthroughOverlay.show(
      context: context,
      steps: steps,
      onComplete: () {
        _isShowingWalkthrough = false;
        _walkthroughOverlayEntry = null;
        unawaited(service.markCaregiverHintSeen());
      },
      onSkip: () {
        _isShowingWalkthrough = false;
        _walkthroughOverlayEntry = null;
        unawaited(service.markCaregiverHintSeen());
      },
    );
  }

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
          for (int i = 0; i < widget.profiles.length; i++) ...[
            KeyedSubtree(
              key: i == 0 ? _profilesKey : null,
              child: _ProfileTile(
                profile: widget.profiles[i],
                onTap: () => EditProfileSheet.show(
                  context,
                  profile: widget.profiles[i],
                  onUpdate: widget.onUpdateProfile,
                  onDelete: () => widget.onDeleteProfile(widget.profiles[i].id),
                  hasPrescriptions: widget.prescriptions
                      .any((p) => p.profileId == widget.profiles[i].id),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          KeyedSubtree(
            key: widget.profiles.isEmpty ? _profilesKey : null,
            child: _AddProfileTile(
              onTap: () =>
                  AddProfileSheet.show(context, onAdd: widget.onUpdateProfile),
            ),
          ),
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
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
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
          KeyedSubtree(
            key: _snoozeKey,
            child: DefaultSnoozeSetting(service: widget.snoozeSettingsService),
          ),
          const SizedBox(height: 10),
          if (widget.themeController != null) ...[
            KeyedSubtree(
              key: _appearanceKey,
              child: AppearanceSetting(controller: widget.themeController!),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.liquidGlassController != null &&
              isLiquidGlassSupported(context)) ...[
            LiquidGlassSetting(controller: widget.liquidGlassController!),
            const SizedBox(height: 10),
          ],
          _SettingTile(
            icon: CupertinoIcons.tray_arrow_down,
            title: 'Export Local Data (.sqlite)',
            onTap: () => _exportData(context),
          ),
          const SizedBox(height: 10),
          _SettingTile(
            icon: CupertinoIcons.archivebox,
            title: 'Dose Log Retention',
            onTap: () => DoseLogRetentionSheet.show(
              context,
              retentionService: widget.retentionService ?? DataRetentionService(),
              doseEvents: widget.doseEvents,
              prescriptions: widget.prescriptions,
              profiles: widget.profiles,
              database: widget.database,
            ),
          ),
          const SizedBox(height: 10),
          if (widget.appLock != null) ...[
            KeyedSubtree(
              key: _appLockKey,
              child: AppLockSetting(service: widget.appLock!),
            ),
            const SizedBox(height: 10),
          ],
          _SettingTile(
            icon: CupertinoIcons.bell,
            title: 'Dose Reminders',
            onTap: () => DoseRemindersSheet.show(context,
                notificationService: widget.notificationService),
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
