import 'package:flutter/material.dart';

/// Every color token from the PillPal design system, with a Light and a Dark
/// value. Tokens with no Dark value (nav scrim, profile colors, tag text)
/// reuse the Light one. `lerp` is what lets a theme switch cross-fade.
@immutable
class PillPalColors extends ThemeExtension<PillPalColors> {
  const PillPalColors({
    required this.background,
    required this.surface,
    required this.headerTeal,
    required this.tint,
    required this.mint,
    required this.ink,
    required this.inkMuted,
    required this.teal,
    required this.tealDeep,
    required this.tealRipple,
    required this.onTeal,
    required this.alert,
    required this.alertTint,
    required this.borderLight,
    required this.borderChip,
    required this.checkRing,
    required this.grabber,
    required this.neutralChip,
    required this.neutralInk,
    required this.navSurface,
    required this.navBorder,
    required this.navInactive,
    required this.navScrim,
    required this.privacyBg,
    required this.privacyBorder,
    required this.privacyIcon,
    required this.privacyTitle,
    required this.privacyBody,
    required this.profileBlue,
    required this.profileViolet,
    required this.profilePink,
    required this.profileAmber,
    required this.profileGreen,
    required this.profileRed,
    required this.tagText,
    required this.tagTextDark,
    required this.glass,
    required this.glassRim,
    required this.segmentTrack,
    required this.segmentThumb,
    required this.cardShadow,
    required this.liftShadow,
  });

  final Color background, surface, headerTeal, tint, mint, ink, inkMuted;
  final Color teal, tealDeep, tealRipple, onTeal, alert, alertTint;
  final Color borderLight,
      borderChip,
      checkRing,
      grabber,
      neutralChip,
      neutralInk;
  final Color navSurface, navBorder, navInactive, navScrim;
  final Color privacyBg, privacyBorder, privacyIcon, privacyTitle, privacyBody;
  final Color profileBlue,
      profileViolet,
      profilePink,
      profileAmber,
      profileGreen,
      profileRed;
  final Color tagText, tagTextDark, glass, glassRim, segmentTrack, segmentThumb;
  final Color cardShadow, liftShadow;

  static const light = PillPalColors(
    background: Color(0xFFF8FAFA),
    surface: Color(0xFFFFFFFF),
    headerTeal: Color(0xFF92D6D3),
    tint: Color(0xFFE4F6F4),
    mint: Color(0xFFBBE5E2),
    ink: Color(0xFF102A29),
    inkMuted: Color(0xFF526A69),
    teal: Color(0xFF168B87),
    tealDeep: Color(0xFF106864),
    tealRipple: Color(0x1F168B87),
    onTeal: Color(0xFFFFFFFF),
    alert: Color(0xFFE11D48),
    alertTint: Color(0x1AE11D48),
    borderLight: Color(0xFFEFF5F4),
    borderChip: Color(0xFFE2ECEB),
    checkRing: Color(0xFFC7D8D7),
    grabber: Color(0xFFCBD5E1),
    neutralChip: Color(0xFFE2E8F0),
    neutralInk: Color(0xFF475569),
    navSurface: Color(0xFFF1F6F5),
    navBorder: Color(0xFFD9E2EC),
    navInactive: Color(0xFF627D98),
    navScrim: Color(0x66000000),
    privacyBg: Color(0xFFE6FFFA),
    privacyBorder: Color(0xFF99F6E4),
    privacyIcon: Color(0xFF0E8A8A),
    privacyTitle: Color(0xFF0D6E6E),
    privacyBody: Color(0xFF0F766E),
    profileBlue: Color(0xFF3B82F6),
    profileViolet: Color(0xFF8B5CF6),
    profilePink: Color(0xFFEC4899),
    profileAmber: Color(0xFFF59E0B),
    profileGreen: Color(0xFF10B981),
    profileRed: Color(0xFFEF4444),
    tagText: Color(0xFFFFFFFF),
    tagTextDark: Color(0xFF102A29),
    glass: Color(0xB3FFFFFF),
    glassRim: Color(0xE6FFFFFF),
    segmentTrack: Color(0xFFEDF3F2),
    segmentThumb: Color(0xFFFFFFFF),
    cardShadow: Color(0x08102A29), // ink at 3%
    liftShadow: Color(0x14102A29), // ink at 8%
  );

  static const dark = PillPalColors(
    background: Color(0xFF0C1514),
    surface: Color(0xFF15201F),
    headerTeal: Color(0xFF1E4B48),
    tint: Color(0xFF183331),
    mint: Color(0xFF1F4F4B),
    ink: Color(0xFFE4F1F0),
    inkMuted: Color(0xFF9CB4B2),
    teal: Color(0xFF2FB5AE),
    tealDeep: Color(0xFF6FD6CF),
    tealRipple: Color(0x292FB5AE),
    onTeal: Color(0xFF0C1514),
    alert: Color(0xFFFB7185),
    alertTint: Color(0x26FB7185),
    borderLight: Color(0xFF22302E),
    borderChip: Color(0xFF2C3D3B),
    checkRing: Color(0xFF5F7573),
    grabber: Color(0xFF3A4A49),
    neutralChip: Color(0xFF253230),
    neutralInk: Color(0xFFC5D2D0),
    navSurface: Color(0xFF111C1B),
    navBorder: Color(0xFF22302E),
    navInactive: Color(0xFF9CB4B2),
    navScrim: Color(0x66000000),
    privacyBg: Color(0xFF10302D),
    privacyBorder: Color(0xFF1F5C55),
    privacyIcon: Color(0xFF5EEAD4),
    privacyTitle: Color(0xFF99F6E4),
    privacyBody: Color(0xFF8FDCD2),
    profileBlue: Color(0xFF3B82F6),
    profileViolet: Color(0xFF8B5CF6),
    profilePink: Color(0xFFEC4899),
    profileAmber: Color(0xFFF59E0B),
    profileGreen: Color(0xFF10B981),
    profileRed: Color(0xFFEF4444),
    tagText: Color(0xFFFFFFFF),
    tagTextDark: Color(0xFF102A29),
    glass: Color(0x14FFFFFF),
    glassRim: Color(0x26FFFFFF),
    segmentTrack: Color(0xFF0C1514),
    segmentThumb: Color(0xFF2A3A38),
    cardShadow: Color(0x40000000), // black at 25%
    liftShadow: Color(0x59000000), // black at 35%
  );

  @override
  PillPalColors copyWith() => this;

  @override
  PillPalColors lerp(PillPalColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PillPalColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      headerTeal: l(headerTeal, other.headerTeal),
      tint: l(tint, other.tint),
      mint: l(mint, other.mint),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      teal: l(teal, other.teal),
      tealDeep: l(tealDeep, other.tealDeep),
      tealRipple: l(tealRipple, other.tealRipple),
      onTeal: l(onTeal, other.onTeal),
      alert: l(alert, other.alert),
      alertTint: l(alertTint, other.alertTint),
      borderLight: l(borderLight, other.borderLight),
      borderChip: l(borderChip, other.borderChip),
      checkRing: l(checkRing, other.checkRing),
      grabber: l(grabber, other.grabber),
      neutralChip: l(neutralChip, other.neutralChip),
      neutralInk: l(neutralInk, other.neutralInk),
      navSurface: l(navSurface, other.navSurface),
      navBorder: l(navBorder, other.navBorder),
      navInactive: l(navInactive, other.navInactive),
      navScrim: l(navScrim, other.navScrim),
      privacyBg: l(privacyBg, other.privacyBg),
      privacyBorder: l(privacyBorder, other.privacyBorder),
      privacyIcon: l(privacyIcon, other.privacyIcon),
      privacyTitle: l(privacyTitle, other.privacyTitle),
      privacyBody: l(privacyBody, other.privacyBody),
      profileBlue: l(profileBlue, other.profileBlue),
      profileViolet: l(profileViolet, other.profileViolet),
      profilePink: l(profilePink, other.profilePink),
      profileAmber: l(profileAmber, other.profileAmber),
      profileGreen: l(profileGreen, other.profileGreen),
      profileRed: l(profileRed, other.profileRed),
      tagText: l(tagText, other.tagText),
      tagTextDark: l(tagTextDark, other.tagTextDark),
      glass: l(glass, other.glass),
      glassRim: l(glassRim, other.glassRim),
      segmentTrack: l(segmentTrack, other.segmentTrack),
      segmentThumb: l(segmentThumb, other.segmentThumb),
      cardShadow: l(cardShadow, other.cardShadow),
      liftShadow: l(liftShadow, other.liftShadow),
    );
  }
}

extension PillPalColorsX on BuildContext {
  /// Falls back to Light when a widget is built without the extension (e.g.
  /// a bare `MaterialApp()` in a widget test) instead of crashing.
  PillPalColors get colors =>
      Theme.of(this).extension<PillPalColors>() ?? PillPalColors.light;
}
