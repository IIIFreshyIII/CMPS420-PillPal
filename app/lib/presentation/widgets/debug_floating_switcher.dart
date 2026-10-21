import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/navigation/navigator_key.dart';
import '../../core/state/app_state_manager.dart';
import '../../core/theme/pillpal_colors.dart';
import '../../data/local/app_database.dart';
import '../../data/models/prescription.dart';
import '../../data/models/profile.dart';
import 'pressable.dart';

/// Small floating developer pill button accessible anywhere in debug builds (kDebugMode).
/// Provides 3 instant environment presets:
/// 1. "Fresh A-to-Z Onboarding"
/// 2. "Seeded UI Testing"
/// 3. "Replay Tab Tutorials"
class DebugFloatingSwitcher extends StatefulWidget {
  const DebugFloatingSwitcher({
    super.key,
    required this.appStateManager,
    this.database,
    this.navigatorKey,
  });

  final AppStateManager appStateManager;
  final AppDatabase? database;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<DebugFloatingSwitcher> createState() => _DebugFloatingSwitcherState();
}

class _DebugFloatingSwitcherState extends State<DebugFloatingSwitcher> {
  // Draggable offset position (defaults to bottom-right above standard tab bar)
  Offset _offset = const Offset(16, 120);

  static const _seedProfiles = [
    Profile(id: '1', name: 'Me', color: Color(0xFF3B82F6), isPrimary: true),
    Profile(id: '2', name: 'Mom', color: Color(0xFF8B5CF6)),
  ];

  static const _seedPrescriptions = [
    Prescription(
      id: '1',
      name: 'Allegra',
      dosage: '10mg',
      reminderTimes: ['8:00 AM'],
      daysSupply: 14,
      remaining: 14,
      profileId: '1',
    ),
    Prescription(
      id: '2',
      name: 'Lisinopril',
      dosage: '20mg',
      reminderTimes: ['8:00 AM'],
      daysSupply: 4,
      remaining: 4,
      profileId: '2',
    ),
    Prescription(
      id: '3',
      name: 'Metformin',
      dosage: '500mg',
      reminderTimes: ['12:00 PM'],
      daysSupply: 28,
      remaining: 28,
      profileId: '2',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !kProfileMode) return const SizedBox.shrink();

    final c = context.colors;
    final size = MediaQuery.of(context).size;

    return Positioned(
      right: _offset.dx.clamp(8.0, size.width - 100),
      bottom: _offset.dy.clamp(40.0, size.height - 100),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset = Offset(
              _offset.dx - details.delta.dx,
              _offset.dy - details.delta.dy,
            );
          });
        },
        child: Material(
          type: MaterialType.transparency,
          child: Pressable(
            onTap: () => _showPresetsSheet(context),
            scale: 0.92,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: c.ink.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: c.teal.withValues(alpha: 0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🛠️', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    'Debug',
                    style: TextStyle(
                      color: c.surface,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPresetsSheet(BuildContext context) {
    final navKey = widget.navigatorKey ?? rootNavigatorKey;
    final targetContext = navKey.currentState?.overlay?.context ??
        navKey.currentContext ??
        context;
    final c = targetContext.colors;
    final state = widget.appStateManager;

    showModalBottomSheet(
      context: targetContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grabber
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.grabber,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🛠️', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          'Developer Presets',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                      color: c.inkMuted,
                      iconSize: 22,
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch instant simulator and testing states with one tap.',
                  style: TextStyle(fontSize: 13, color: c.inkMuted),
                ),
                const SizedBox(height: 16),

                // Preset 1: Fresh A-to-Z Onboarding
                _buildPresetTile(
                  targetContext,
                  badge: 'PRESET 1',
                  title: 'Fresh A-to-Z Onboarding',
                  subtitle:
                      'Resets onboarding to Step 1, clears all 3 tab tour flags, and hides seeded test data.',
                  icon: CupertinoIcons.arrow_counterclockwise_circle_fill,
                  accentColor: c.alert,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await widget.database?.clearAllData();
                    await state.resetToFreshOnboarding();
                    await state.appLockService?.setEnabled(false);
                    navKey.currentState?.popUntil((r) => r.isFirst);
                    if (targetContext.mounted) {
                      _showFeedback(targetContext, 'Reset to Fresh A-to-Z Onboarding');
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Preset 2: Seeded UI Testing
                _buildPresetTile(
                  targetContext,
                  badge: 'PRESET 2',
                  title: 'Seeded UI Testing',
                  subtitle:
                      'Sets onboarding complete, marks all tours complete, and loads all seeded medications on Home Screen.',
                  icon: CupertinoIcons.checkmark_seal_fill,
                  accentColor: c.teal,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await state.setSeededUiTesting();
                    await widget.database?.seedIfEmpty(_seedProfiles, _seedPrescriptions);
                    navKey.currentState?.popUntil((r) => r.isFirst);
                    if (targetContext.mounted) {
                      _showFeedback(targetContext, 'Switched to Seeded UI Testing Mode');
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Preset 3: Replay Tab Tutorials
                _buildPresetTile(
                  targetContext,
                  badge: 'PRESET 3',
                  title: 'Replay Tab Tutorials',
                  subtitle:
                      'Keeps current onboarded state, but resets Schedule, Meds, and Account walkthrough flags to false.',
                  icon: CupertinoIcons.play_circle_fill,
                  accentColor: const Color(0xFF8B5CF6),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await state.replayTabTutorials();
                    navKey.currentState?.popUntil((r) => r.isFirst);
                    if (targetContext.mounted) {
                      _showFeedback(targetContext, 'Reset All 3 Tab Walkthrough Tours');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetTile(
    BuildContext context, {
    required String badge,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final c = context.colors;

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderChip),
          boxShadow: [
            BoxShadow(
              color: c.cardShadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: c.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedback(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
