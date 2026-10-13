import 'package:flutter/material.dart';
import '../services/ios_accessibility_service.dart';
import 'app_theme.dart';
import 'liquid_glass_mode.dart';

/// Resolved styling properties for the floating navigation hotbar on iOS 26+.
///
/// Modifies translucency, blur sigma, borders, and animations dynamically
/// depending on whether the user is in [LiquidGlassMode.auto] (which reacts
/// directly to iOS "Reduce Transparency", "Increase Contrast", and "Reduce Motion"),
/// or an explicit mode ([LiquidGlassMode.liquid], [LiquidGlassMode.frosted],
/// or [LiquidGlassMode.opaque]).
class LiquidGlassStyle {
  const LiquidGlassStyle({
    required this.resolvedMode,
    required this.hasBlur,
    required this.blurSigma,
    required this.backgroundGradient,
    required this.solidBackgroundColor,
    required this.border,
    required this.shadows,
    required this.activePillGradient,
    required this.activePillColor,
    required this.activePillBorder,
    required this.activePillShadows,
    required this.liftScale,
    required this.disableAnimations,
  });

  /// The concrete mode resolved for this frame (never [LiquidGlassMode.auto]).
  final LiquidGlassMode resolvedMode;

  /// Whether a [BackdropFilter] should be inserted into the widget tree.
  /// When `false`, the [BackdropFilter] is completely omitted to avoid GPU
  /// render-pass and buffer allocations.
  final bool hasBlur;

  /// The blur radius passed to [ImageFilter.blur].
  final double blurSigma;

  /// Multi-stop surface gradient (null when in fully opaque mode).
  final Gradient? backgroundGradient;

  /// Solid color fill (used when [backgroundGradient] is null).
  final Color? solidBackgroundColor;

  /// Perimeter rim or high-contrast border.
  final Border border;

  /// Ambient and elevation drop shadows.
  final List<BoxShadow> shadows;

  /// Indicator pill gradient fill.
  final Gradient? activePillGradient;

  /// Indicator pill solid color fill.
  final Color? activePillColor;

  /// Indicator pill border.
  final Border activePillBorder;

  /// Indicator pill shadows.
  final List<BoxShadow> activePillShadows;

  /// Current scale multiplier applied to the bar.
  final double liftScale;

  /// Whether animations should be instant/disabled (iOS Reduce Motion).
  final bool disableAnimations;

  /// Resolves the styling configuration for the current context and state.
  static LiquidGlassStyle resolve(
    BuildContext context, {
    required bool isDark,
    required bool isLifted,
    LiquidGlassMode mode = LiquidGlassMode.auto,
    bool? isReduceTransparencyOverride,
  }) {
    final highContrast = MediaQuery.highContrastOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final reduceTransparency = isReduceTransparencyOverride ??
        IOSAccessibilityService.instance.isReduceTransparency;

    // Resolve the concrete display mode
    final LiquidGlassMode resolved;
    if (mode == LiquidGlassMode.auto) {
      if (highContrast || reduceTransparency) {
        resolved = LiquidGlassMode.opaque;
      } else {
        resolved = LiquidGlassMode.liquid;
      }
    } else {
      resolved = mode;
    }

    switch (resolved) {
      case LiquidGlassMode.opaque:
        return _buildOpaque(
          isDark: isDark,
          isLifted: isLifted,
          disableAnimations: reduceMotion,
        );
      case LiquidGlassMode.frosted:
        return _buildFrosted(
          isDark: isDark,
          isLifted: isLifted,
          disableAnimations: reduceMotion,
        );
      case LiquidGlassMode.liquid:
      case LiquidGlassMode.auto:
        return _buildLiquid(
          isDark: isDark,
          isLifted: isLifted,
          disableAnimations: reduceMotion,
        );
    }
  }

  static LiquidGlassStyle _buildLiquid({
    required bool isDark,
    required bool isLifted,
    required bool disableAnimations,
  }) {
    return LiquidGlassStyle(
      resolvedMode: LiquidGlassMode.liquid,
      hasBlur: true,
      blurSigma: 25.0,
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.11),
              ]
            : [
                Colors.white.withValues(alpha: 0.72),
                Colors.white.withValues(alpha: 0.45),
                Colors.white.withValues(alpha: 0.58),
              ],
      ),
      solidBackgroundColor: null,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: isLifted ? 0.28 : 0.18)
            : Colors.white.withValues(alpha: isLifted ? 0.90 : 0.75),
        width: 1.2,
      ),
      shadows: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: isLifted ? 0.55 : 0.35)
              : const Color(0xFF0F172A)
                  .withValues(alpha: isLifted ? 0.18 : 0.08),
          blurRadius: isLifted ? 36 : 22,
          offset: Offset(0, isLifted ? 16 : 8),
          spreadRadius: isLifted ? 1.0 : 0.0,
        ),
        if (isLifted)
          BoxShadow(
            color:
                AppTheme.interactiveTeal.withValues(alpha: isDark ? 0.25 : 0.14),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.30)
              : const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
      activePillGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                AppTheme.interactiveTeal
                    .withValues(alpha: isLifted ? 0.38 : 0.28),
                AppTheme.interactiveTeal
                    .withValues(alpha: isLifted ? 0.26 : 0.18),
              ]
            : [
                AppTheme.interactiveTeal
                    .withValues(alpha: isLifted ? 0.22 : 0.15),
                AppTheme.interactiveTeal
                    .withValues(alpha: isLifted ? 0.14 : 0.09),
              ],
      ),
      activePillColor: null,
      activePillBorder: Border.all(
        color: isDark
            ? AppTheme.interactiveTeal
                .withValues(alpha: isLifted ? 0.45 : 0.30)
            : AppTheme.interactiveTeal
                .withValues(alpha: isLifted ? 0.30 : 0.18),
        width: 1.0,
      ),
      activePillShadows: [
        BoxShadow(
          color: AppTheme.interactiveTeal
              .withValues(alpha: isLifted ? 0.25 : 0.12),
          blurRadius: isLifted ? 10 : 6,
          offset: Offset(0, isLifted ? 2 : 1),
        ),
      ],
      liftScale: disableAnimations ? 1.0 : (isLifted ? 1.05 : 1.0),
      disableAnimations: disableAnimations,
    );
  }

  static LiquidGlassStyle _buildFrosted({
    required bool isDark,
    required bool isLifted,
    required bool disableAnimations,
  }) {
    return LiquidGlassStyle(
      resolvedMode: LiquidGlassMode.frosted,
      hasBlur: true,
      blurSigma: 12.0,
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFF1E293B).withValues(alpha: 0.82),
                const Color(0xFF0F172A).withValues(alpha: 0.88),
              ]
            : [
                Colors.white.withValues(alpha: 0.90),
                Colors.white.withValues(alpha: 0.84),
              ],
      ),
      solidBackgroundColor: null,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: isLifted ? 0.26 : 0.18)
            : const Color(0xFFE2E8F0),
        width: 1.2,
      ),
      shadows: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: isLifted ? 0.45 : 0.25)
              : const Color(0xFF0F172A)
                  .withValues(alpha: isLifted ? 0.14 : 0.06),
          blurRadius: isLifted ? 24 : 14,
          offset: Offset(0, isLifted ? 10 : 5),
          spreadRadius: isLifted ? 0.5 : 0.0,
        ),
        if (isLifted)
          BoxShadow(
            color:
                AppTheme.interactiveTeal.withValues(alpha: isDark ? 0.20 : 0.10),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
      ],
      activePillGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                AppTheme.interactiveTeal
                    .withValues(alpha: isLifted ? 0.45 : 0.35),
                AppTheme.interactiveTeal
                    .withValues(alpha: isLifted ? 0.32 : 0.24),
              ]
            : [
                AppTheme.interactiveTeal
                    .withValues(alpha: isLifted ? 0.28 : 0.20),
                AppTheme.interactiveTeal
                    .withValues(alpha: isLifted ? 0.18 : 0.12),
              ],
      ),
      activePillColor: null,
      activePillBorder: Border.all(
        color: isDark
            ? AppTheme.interactiveTeal
                .withValues(alpha: isLifted ? 0.55 : 0.38)
            : AppTheme.interactiveTeal
                .withValues(alpha: isLifted ? 0.38 : 0.24),
        width: 1.0,
      ),
      activePillShadows: [
        BoxShadow(
          color: AppTheme.interactiveTeal
              .withValues(alpha: isLifted ? 0.20 : 0.10),
          blurRadius: isLifted ? 8 : 5,
          offset: Offset(0, isLifted ? 2 : 1),
        ),
      ],
      liftScale: disableAnimations ? 1.0 : (isLifted ? 1.03 : 1.0),
      disableAnimations: disableAnimations,
    );
  }

  static LiquidGlassStyle _buildOpaque({
    required bool isDark,
    required bool isLifted,
    required bool disableAnimations,
  }) {
    return LiquidGlassStyle(
      resolvedMode: LiquidGlassMode.opaque,
      hasBlur: false,
      blurSigma: 0.0,
      backgroundGradient: null,
      solidBackgroundColor:
          isDark ? const Color(0xFF141D1C) : const Color(0xFFFFFFFF),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        width: 1.5,
      ),
      shadows: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: isLifted ? 0.65 : 0.45)
              : const Color(0xFF0F172A)
                  .withValues(alpha: isLifted ? 0.20 : 0.12),
          blurRadius: isLifted ? 18 : 10,
          offset: Offset(0, isLifted ? 8 : 4),
          spreadRadius: isLifted ? 1.0 : 0.0,
        ),
        if (isLifted)
          BoxShadow(
            color: AppTheme.interactiveTeal
                .withValues(alpha: isDark ? 0.30 : 0.18),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
      ],
      activePillGradient: null,
      activePillColor: isDark
          ? AppTheme.interactiveTeal.withValues(alpha: 0.32)
          : AppTheme.interactiveTeal.withValues(alpha: 0.18),
      activePillBorder: Border.all(
        color: isDark
            ? AppTheme.interactiveTeal
            : const Color(0xFF007A78),
        width: 1.5,
      ),
      activePillShadows: [
        BoxShadow(
          color: AppTheme.interactiveTeal
              .withValues(alpha: isLifted ? 0.28 : 0.15),
          blurRadius: isLifted ? 8 : 4,
          offset: Offset(0, isLifted ? 2 : 1),
        ),
      ],
      liftScale: disableAnimations ? 1.0 : (isLifted ? 1.02 : 1.0),
      disableAnimations: disableAnimations,
    );
  }
}
