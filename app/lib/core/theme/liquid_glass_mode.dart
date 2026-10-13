/// Controls the level of "liquid glass" translucency and blur applied to the
/// iOS 26+ floating navigation bar.
enum LiquidGlassMode {
  /// Adapts dynamically to iOS system accessibility settings:
  /// - If iOS "Reduce Transparency" or "Increase Contrast" is turned on,
  ///   automatically switches to solid [opaque] mode (0% blur).
  /// - If iOS "Reduce Motion" is turned on, disables spring lift bounce.
  /// - Otherwise, renders full [liquid] glass.
  auto,

  /// Apple genuine iOS 26 Liquid Glass:
  /// 25px Gaussian blur, translucent specular gradient, specular rim-light
  /// bevel, layered ambient shadows with interactive teal bloom, and spring lift.
  liquid,

  /// Muted semi-translucent glass:
  /// 12px Gaussian blur with ~85% opaque surface gradient for enhanced legibility
  /// while preserving subtle depth.
  frosted,

  /// Completely solid surface with 0% blur:
  /// Bypasses the GPU [BackdropFilter] render pass entirely to save battery and
  /// GPU cycles, featuring a high-contrast border and solid active indicator pill.
  opaque;

  String get label => switch (this) {
        LiquidGlassMode.auto => 'Auto',
        LiquidGlassMode.liquid => 'Liquid',
        LiquidGlassMode.frosted => 'Frosted',
        LiquidGlassMode.opaque => 'Opaque',
      };

  String get description => switch (this) {
        LiquidGlassMode.auto =>
          'Automatically adapts to your iPhone Accessibility settings (Reduce Transparency, Increase Contrast, and Reduce Motion).',
        LiquidGlassMode.liquid =>
          'Full iOS dynamic specular blur (25px), ambient glow, and spring elevation.',
        LiquidGlassMode.frosted =>
          'Subtle semi-translucent glass (12px blur) with muted reflections.',
        LiquidGlassMode.opaque =>
          'Solid high-contrast surface with 0% blur, saving battery and maximizing legibility.',
      };
}
