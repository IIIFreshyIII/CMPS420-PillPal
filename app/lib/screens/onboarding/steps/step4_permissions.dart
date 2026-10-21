import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/permissions/camera_permission.dart';
import '../../../core/state/app_state_manager.dart';
import '../../../core/theme/pillpal_colors.dart';
import '../../../core/utils/ios_design_era.dart';
import '../../../data/services/notification_service.dart';
import '../../../presentation/widgets/pressable.dart';

/// Step 4: Permissions & Local Settings ("Illusion of Choice").
/// Requires Camera and Notifications permissions before advancing to Step 5,
/// while providing in-place controls for Theme, Liquid Glass, Retention, and Biometrics.
class Step4Permissions extends StatefulWidget {
  const Step4Permissions({
    super.key,
    required this.appStateManager,
    required this.notificationService,
    required this.onNext,
    this.requestCamera,
    this.checkCamera,
  });

  final AppStateManager appStateManager;
  final NotificationService notificationService;
  final VoidCallback onNext;
  final Future<CameraPermissionResult> Function()? requestCamera;
  final Future<CameraPermissionResult> Function()? checkCamera;

  @override
  State<Step4Permissions> createState() => _Step4PermissionsState();
}

class _Step4PermissionsState extends State<Step4Permissions>
    with WidgetsBindingObserver {
  // Required switches ALWAYS start switched OFF (grey) when entering Step 4
  bool _cameraGranted = false;
  bool _notificationsGranted = false;
  bool _biometricsEnabled = false;
  late int _retentionDays;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraGranted = false;
    _notificationsGranted = false;
    _biometricsEnabled = widget.appStateManager.biometricsEnabled;
    _retentionDays = widget.appStateManager.retentionDays;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsOnResume();
    }
  }

  Future<void> _checkPermissionsOnResume() async {
    final result = widget.checkCamera != null
        ? await widget.checkCamera!()
        : await checkCameraPermission();
    if (mounted && result == CameraPermissionResult.granted) {
      setState(() => _cameraGranted = true);
    }
  }

  Future<void> _toggleCamera(bool value) async {
    if (!value) {
      setState(() => _cameraGranted = false);
      return;
    }

    // 1. If already authorized in iOS Settings, flip switch immediately
    final checkResult = widget.checkCamera != null
        ? await widget.checkCamera!()
        : await checkCameraPermission();

    if (checkResult == CameraPermissionResult.granted) {
      if (mounted) setState(() => _cameraGranted = true);
      return;
    }

    // 2. Otherwise prompt for authorization
    final result = widget.requestCamera != null
        ? await widget.requestCamera!()
        : await requestCameraPermission();

    if (!mounted) return;
    if (result == CameraPermissionResult.granted) {
      setState(() => _cameraGranted = true);
    } else if (result == CameraPermissionResult.permanentlyDenied) {
      setState(() => _cameraGranted = false);
      _showCameraDeniedDialog();
    } else {
      setState(() => _cameraGranted = false);
    }
  }

  void _showCameraDeniedDialog() {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Camera Access Needed'),
        content: const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text(
            'PillPal needs camera access to scan prescription bottle labels. You can enable it in iOS Settings.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.of(ctx).pop();
              openCameraPermissionSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    if (!value) {
      setState(() => _notificationsGranted = false);
      return;
    }
    final granted = await widget.notificationService.requestPermissions();
    setState(() => _notificationsGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = widget.appStateManager;
    final bothRequiredGranted = _cameraGranted && _notificationsGranted;

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
                    Text(
                      'Permissions & Local Setup',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Reassurance note
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.tint,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: c.teal.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.info_circle_fill,
                            size: 18,
                            color: c.tealDeep,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You can change your theme, data retention window, or security settings anytime in the Account tab.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: c.tealDeep,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SECTION 1: REQUIRED PERMISSIONS
                    Row(
                      children: [
                        Text(
                          'REQUIRED PERMISSIONS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: c.tealDeep,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: bothRequiredGranted
                                ? c.tint
                                : c.alertTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            bothRequiredGranted
                                ? 'All Granted'
                                : 'Action Required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: bothRequiredGranted
                                  ? c.tealDeep
                                  : c.alert,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.borderChip),
                        boxShadow: [
                          BoxShadow(
                            color: c.cardShadow,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Camera Switch (with long-press debug bypass)
                          _buildSwitchRow(
                            icon: CupertinoIcons.camera_fill,
                            title: 'On-Device Camera Access',
                            subtitle:
                                'Used for live prescription label scanning (no photos are ever saved)',
                            value: _cameraGranted,
                            onChanged: _toggleCamera,
                            context: context,
                            onLongPress: kDebugMode
                                ? () {
                                    setState(() => _cameraGranted = true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Debug: Camera access force-granted',
                                        ),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                          Divider(height: 1, color: c.borderLight),
                          // Notifications Switch
                          _buildSwitchRow(
                            icon: CupertinoIcons.bell_fill,
                            title: 'Dose & Refill Notifications',
                            subtitle:
                                'Delivers scheduled alarms and discreet refill reminders',
                            value: _notificationsGranted,
                            onChanged: _toggleNotifications,
                            context: context,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // SECTION 2: OPTIONAL LOCAL PREFERENCES
                    Text(
                      'OPTIONAL LOCAL PREFERENCES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: c.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.borderChip),
                        boxShadow: [
                          BoxShadow(
                            color: c.cardShadow,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 1. Theme Override (Stacked full-width pill selector to prevent horizontal crush)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: c.tint,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.circle_lefthalf_fill,
                                        size: 18,
                                        color: c.tealDeep,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Appearance Theme',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: c.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Choose Light, Dark, or System mode',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: c.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Full-width custom pill bar
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: c.borderLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildThemeOption(
                                        context,
                                        mode: ThemeMode.system,
                                        label: 'Auto',
                                        isSelected: state.appearanceMode ==
                                            ThemeMode.system,
                                        onTap: () {
                                          state.setAppearanceMode(
                                            ThemeMode.system,
                                          );
                                          setState(() {});
                                        },
                                      ),
                                      _buildThemeOption(
                                        context,
                                        mode: ThemeMode.light,
                                        label: 'Light',
                                        isSelected: state.appearanceMode ==
                                            ThemeMode.light,
                                        onTap: () {
                                          state.setAppearanceMode(
                                            ThemeMode.light,
                                          );
                                          setState(() {});
                                        },
                                      ),
                                      _buildThemeOption(
                                        context,
                                        mode: ThemeMode.dark,
                                        label: 'Dark',
                                        isSelected: state.appearanceMode ==
                                            ThemeMode.dark,
                                        onTap: () {
                                          state.setAppearanceMode(
                                            ThemeMode.dark,
                                          );
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: c.borderLight),

                          // 2. Liquid Glass (only on iOS 26+ devices supporting Liquid Glass)
                          if (isLiquidGlassSupported(context)) ...[
                            _buildSwitchRow(
                              icon: CupertinoIcons.sparkles,
                              title: 'Liquid Glass Styling',
                              subtitle: 'Frosted translucent UI aesthetics',
                              value: state.liquidGlassEnabled,
                              onChanged: (val) {
                                state.setLiquidGlassEnabled(val);
                                setState(() {});
                              },
                              context: context,
                            ),
                            Divider(height: 1, color: c.borderLight),
                          ],

                          // 3. History Retention (Clean modal picker sheet)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: c.borderLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.clock_fill,
                                    size: 18,
                                    color: c.tealDeep,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'History Retention',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: c.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Dose log purge window',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: c.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _IosRetentionMenu(
                                  currentDays: _retentionDays,
                                  onChanged: (days) async {
                                    setState(() => _retentionDays = days);
                                    await state.setRetentionDays(days);
                                  },
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: c.borderLight),

                          // 4. Biometric / Passcode Lock
                          _buildSwitchRow(
                            icon: CupertinoIcons.lock_shield_fill,
                            title: 'Biometric / App Lock',
                            subtitle:
                                'Requires Face ID, fingerprint, or device passcode to open',
                            value: _biometricsEnabled,
                            onChanged: (val) async {
                              setState(() => _biometricsEnabled = val);
                              await state.setBiometricsEnabled(val);
                            },
                            context: context,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // BOTTOM ACTION: NEXT BUTTON (ANIMATED ENTRY)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: bothRequiredGranted ? 1.0 : 0.45,
                child: Pressable(
                  onTap: bothRequiredGranted
                      ? () async {
                          await widget.appStateManager
                              .setBiometricsEnabled(_biometricsEnabled);
                          await widget.appStateManager
                              .setRetentionDays(_retentionDays);
                          widget.onNext();
                        }
                      : null,
                  scale: 0.97,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: bothRequiredGranted ? c.teal : c.neutralChip,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: bothRequiredGranted
                          ? [
                              BoxShadow(
                                color: c.teal.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        bothRequiredGranted
                            ? 'Next'
                            : 'Enable Camera & Notifications to Continue',
                        style: TextStyle(
                          color: bothRequiredGranted ? c.onTeal : c.neutralInk,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
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

  Widget _buildThemeOption(
    BuildContext context, {
    required ThemeMode mode,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final c = context.colors;

    return Expanded(
      child: Pressable(
        onTap: onTap,
        scale: 0.96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: c.cardShadow,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? c.tealDeep : c.inkMuted,
              ),
            ),
          ),
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
    VoidCallback? onLongPress,
  }) {
    final c = context.colors;

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value ? c.tint : c.borderLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
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
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.inkMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CupertinoSwitch(
              value: value,
              activeTrackColor: c.teal,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _IosRetentionMenu extends StatefulWidget {
  const _IosRetentionMenu({
    required this.currentDays,
    required this.onChanged,
  });

  final int currentDays;
  final ValueChanged<int> onChanged;

  @override
  State<_IosRetentionMenu> createState() => _IosRetentionMenuState();
}

class _IosRetentionMenuState extends State<_IosRetentionMenu>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  static const options = [
    (days: 90, label: '3 Months'),
    (days: 180, label: '6 Months'),
    (days: 270, label: '9 Months'),
    (days: 365, label: '12 Months'),
    (days: 0, label: 'Not at all'),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showMenu() {
    _overlayController.show();
    _animController.forward(from: 0.0);
  }

  void _hideMenu() {
    _animController.reverse().then((_) {
      if (mounted) {
        _overlayController.hide();
      }
    });
  }

  String _labelFor(int days) {
    return options
        .firstWhere((o) => o.days == days, orElse: () => options.first)
        .label;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          return Stack(
            children: [
              // Full-screen barrier dismiss
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _hideMenu,
                ),
              ),
              // Anchored follower menu
              CompositedTransformFollower(
                link: _layerLink,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 6),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    alignment: Alignment.topRight,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            width: 175,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xE6252932)
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.black.withValues(alpha: 0.08),
                                width: 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0; i < options.length; i++) ...[
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onChanged(options[i].days);
                                      _hideMenu();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 11,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            options[i].label,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  widget.currentDays ==
                                                          options[i].days
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                              color: widget.currentDays ==
                                                      options[i].days
                                                  ? c.teal
                                                  : c.ink,
                                            ),
                                          ),
                                          if (widget.currentDays == options[i].days)
                                            Icon(
                                              CupertinoIcons.checkmark,
                                              size: 15,
                                              color: c.teal,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (i < options.length - 1)
                                    Divider(
                                      height: 0.5,
                                      thickness: 0.5,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.08),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            if (_overlayController.isShowing) {
              _hideMenu();
            } else {
              _showMenu();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.tint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.teal.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _labelFor(widget.currentDays),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.tealDeep,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 12,
                  color: c.tealDeep,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

