import 'package:flutter/painting.dart';

import 'kde_color_effect.dart';
import 'kde_color_set.dart';
import 'kde_wm_colors.dart';

/// The full KDE color scheme parsed from kdeglobals.
///
/// ## What is already "baked in"
///
/// The `[Colors:*]` values are the **final computed colors** — KDE writes the
/// post-tint, post-accent result into kdeglobals when a scheme is applied.
/// [accentColor] in `[General]` is metadata only; you do not need to re-apply
/// it to the color sets.
///
/// ## What is NOT baked in
///
/// [disabledEffect] and [inactiveEffect] are **runtime effect descriptors**.
/// Native Qt/KDE apps apply them on-the-fly when rendering disabled or
/// inactive-window widgets. The stored `[Colors:*]` values are the BASE colors
/// that effects act on. Use [KdeColorEffect.apply] to compute derived colors:
///
/// ```dart
/// final disabledFg = kde.disabledEffect.apply(
///   kde.window.foregroundNormal,
///   background: kde.window.backgroundNormal,
/// );
/// ```
///
/// ## Contrast
///
/// [contrast] (0–10, default 4) is used by native KDE to compute shaded
/// variants (mid, dark, light) of base colors. The stored colors are the
/// unmodified base values; contrast affects only derived shades computed at
/// runtime in `KColorScheme::shade()`.
class KdeColorScheme {
  const KdeColorScheme({
    required this.name,
    required this.accentColor,
    required this.accentColorFromWallpaper,
    required this.window,
    required this.button,
    required this.view,
    required this.selection,
    required this.tooltip,
    required this.complementary,
    required this.wm,
    required this.disabledEffect,
    required this.inactiveEffect,
    required this.contrast,
    this.header,
  });

  /// The scheme name from `[General] ColorScheme=`.
  final String name;

  /// Global accent color from `[General] AccentColor=`.
  ///
  /// Already baked into the `[Colors:*]` sections. Exposed here as metadata
  /// so the app can use it directly (e.g. for progress bars, highlights).
  final Color accentColor;

  /// True when `[General] accentColorFromWallpaper=true`.
  ///
  /// Means the user lets KDE pick the accent from the wallpaper palette rather
  /// than choosing it manually.
  final bool accentColorFromWallpaper;

  final KdeColorSet window;
  final KdeColorSet button;
  final KdeColorSet view;
  final KdeColorSet selection;
  final KdeColorSet tooltip;
  final KdeColorSet complementary;

  /// Only present when the scheme defines a `[Colors:Header]` section.
  final KdeColorSet? header;

  /// Window manager / title bar colors from `[WM]`.
  final KdeWmColors wm;

  /// Effect applied to colors when rendering disabled widgets.
  ///
  /// Applied on-the-fly in native apps; NOT pre-applied to `[Colors:*]`.
  final KdeColorEffect disabledEffect;

  /// Effect applied to colors when the window is inactive (unfocused).
  ///
  /// Often `enabled = false` (user turned off inactive window dimming).
  /// NOT pre-applied to `[Colors:*]`.
  final KdeColorEffect inactiveEffect;

  /// Global contrast level from `[KDE] contrast=` (0–10, default 4).
  ///
  /// Used by native KDE to compute shaded color variants. The `[Colors:*]`
  /// base values are unaffected.
  final int contrast;

  /// True when the window background is darker than mid-gray.
  bool get isDark => window.backgroundNormal.computeLuminance() < 0.5;

  static final fallback = KdeColorScheme(
    name: 'Breeze Dark',
    accentColor: const Color(0xFF7863B1),
    accentColorFromWallpaper: false,
    window: KdeColorSet.fallback,
    button: KdeColorSet.fallback,
    view: KdeColorSet.fallback,
    selection: KdeColorSet.fallback,
    tooltip: KdeColorSet.fallback,
    complementary: KdeColorSet.fallback,
    wm: KdeWmColors.fallback,
    disabledEffect: KdeColorEffect.fallbackDisabled,
    inactiveEffect: KdeColorEffect.fallbackInactive,
    contrast: 4,
  );
}
