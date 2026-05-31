import 'package:flutter/painting.dart';

/// Describes how KDE modifies colors for a specific widget state (disabled or
/// inactive window). Maps to a `[ColorEffects:Disabled]` or
/// `[ColorEffects:Inactive]` section in kdeglobals.
///
/// Native KDE/Qt apps apply these effects at render time to the base colors
/// from `[Colors:*]`. The stored `[Colors:*]` values are NOT pre-modified —
/// they are the base colors that effects act on.
///
/// Use [apply] to compute the derived color for a given state:
/// ```dart
/// final disabledBg = kde.disabledEffect.apply(
///   kde.button.backgroundNormal,
///   background: kde.window.backgroundNormal,
/// );
/// ```
class KdeColorEffect {
  const KdeColorEffect({
    required this.enabled,
    required this.changeSelectionColor,
    required this.intensityEffect,
    required this.intensityAmount,
    required this.colorEffect,
    required this.colorAmount,
    required this.color,
    required this.contrastEffect,
    required this.contrastAmount,
  });

  /// Whether this effect is active. When false, [apply] returns the input
  /// unchanged.
  final bool enabled;

  /// Whether selection colors should also be modified in this state.
  final bool changeSelectionColor;

  /// How to adjust lightness/darkness of the color.
  final KdeIntensityEffect intensityEffect;

  /// How strongly to apply the intensity effect (0.0–1.0).
  final double intensityAmount;

  /// How to blend a tint [color] into the base color.
  final KdeColorEffectType colorEffect;

  /// How strongly to apply the color tint (0.0–1.0).
  final double colorAmount;

  /// The tint/reference color used by [colorEffect].
  final Color color;

  /// How to adjust contrast relative to the background.
  final KdeContrastEffect contrastEffect;

  /// How strongly to apply the contrast effect (0.0–1.0).
  final double contrastAmount;

  /// Applies this effect to [base], returning the modified color.
  ///
  /// [background] is the background color of the containing surface, required
  /// for contrast calculations. When [enabled] is false the input is returned
  /// unchanged.
  Color apply(Color base, {required Color background}) {
    if (!enabled) return base;

    var c = _applyIntensity(base);
    c = _applyColorEffect(c);
    c = _applyContrast(c, background: background);
    return c;
  }

  Color _applyIntensity(Color c) {
    final hsl = HSLColor.fromColor(c);
    return switch (intensityEffect) {
      KdeIntensityEffect.none => c,
      // Shade: darken when amount > 0.5, lighten when < 0.5.
      KdeIntensityEffect.shade =>
        hsl
            .withLightness(
              (hsl.lightness * (1.0 - intensityAmount)).clamp(0, 1),
            )
            .toColor(),
      KdeIntensityEffect.darken =>
        hsl
            .withLightness(
              (hsl.lightness * (1.0 - intensityAmount)).clamp(0, 1),
            )
            .toColor(),
      KdeIntensityEffect.lighten =>
        hsl
            .withLightness(
              (hsl.lightness + (1.0 - hsl.lightness) * intensityAmount).clamp(
                0,
                1,
              ),
            )
            .toColor(),
    };
  }

  Color _applyColorEffect(Color c) {
    return switch (colorEffect) {
      KdeColorEffectType.none => c,
      KdeColorEffectType.desaturate =>
        HSLColor.fromColor(c)
            .withSaturation(
              (HSLColor.fromColor(c).saturation * (1.0 - colorAmount)).clamp(
                0,
                1,
              ),
            )
            .toColor(),
      KdeColorEffectType.tint => Color.lerp(c, color, colorAmount)!,
    };
  }

  Color _applyContrast(Color c, {required Color background}) {
    return switch (contrastEffect) {
      KdeContrastEffect.none => c,
      // Fade toward the mid-point between background and foreground.
      KdeContrastEffect.fade => Color.lerp(c, background, contrastAmount)!,
      KdeContrastEffect.tint => Color.lerp(c, background, contrastAmount)!,
    };
  }

  static const fallbackDisabled = KdeColorEffect(
    enabled: true,
    changeSelectionColor: false,
    intensityEffect: KdeIntensityEffect.darken,
    intensityAmount: 0.1,
    colorEffect: KdeColorEffectType.none,
    colorAmount: 0,
    color: Color(0xFF383838),
    contrastEffect: KdeContrastEffect.fade,
    contrastAmount: 0.4,
  );

  static const fallbackInactive = KdeColorEffect(
    enabled: false,
    changeSelectionColor: true,
    intensityEffect: KdeIntensityEffect.none,
    intensityAmount: 0,
    colorEffect: KdeColorEffectType.tint,
    colorAmount: 0.025,
    color: Color(0xFF706F6E),
    contrastEffect: KdeContrastEffect.tint,
    contrastAmount: 0.1,
  );
}

/// How to adjust the lightness/darkness of a color.
enum KdeIntensityEffect {
  /// No intensity adjustment.
  none,

  /// Shade: darken or lighten depending on [KdeColorEffect.intensityAmount].
  shade,

  /// Darken the color.
  darken,

  /// Lighten the color.
  lighten,
}

/// How to apply a tint color.
enum KdeColorEffectType {
  /// No color adjustment.
  none,

  /// Desaturate toward gray.
  desaturate,

  /// Tint toward [KdeColorEffect.color].
  tint,
}

/// How to adjust contrast relative to the background.
enum KdeContrastEffect {
  /// No contrast adjustment.
  none,

  /// Fade the color toward the background.
  fade,

  /// Tint the color toward the background.
  tint,
}
