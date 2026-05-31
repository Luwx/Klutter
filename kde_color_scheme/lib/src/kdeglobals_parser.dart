import 'dart:io';

import 'package:flutter/painting.dart';

import 'kde_color_effect.dart';
import 'kde_color_scheme.dart';
import 'kde_color_set.dart';
import 'kde_wm_colors.dart';

/// Parses a kdeglobals KConfig INI file into a [KdeColorScheme].
///
/// ## kdeglobals format
/// ```
/// [Colors:Window]
/// BackgroundNormal=30,29,39      ← R,G,B (no alpha) or R,G,B,A
/// ForegroundNormal=171,168,182
///
/// [ColorEffects:Disabled]
/// IntensityEffect=2
/// IntensityAmount=0.1
/// ContrastEffect=1
/// ContrastAmount=0.4
///
/// [General]
/// AccentColor=120,99,177
/// ColorScheme=MonochromeTint
/// accentColorFromWallpaper=true
///
/// [KDE]
/// contrast=4
///
/// [WM]
/// activeBackground=30,29,39
/// activeForeground=255,255,255
/// ```
class KdeglobalsParser {
  const KdeglobalsParser._();

  static String get defaultPath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.config/kdeglobals';
  }

  /// Returns true if kdeglobals exists at [path] (defaults to [defaultPath]).
  ///
  /// Use this to gate any KDE-specific UI - on non-KDE systems the file will
  /// not be present.
  static bool isAvailable([String? path]) =>
      File(path ?? defaultPath).existsSync();

  static KdeColorScheme? parseFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return _parseContent(file.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  static KdeColorScheme _parseContent(String content) {
    final sections = <String, Map<String, String>>{};
    String? current;

    for (var line in content.split('\n')) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
        continue;
      }

      if (line.startsWith('[') && line.endsWith(']')) {
        current = line.substring(1, line.length - 1);
        sections[current] = {};
      } else if (current != null) {
        final eq = line.indexOf('=');
        if (eq > 0) {
          sections[current]![line.substring(0, eq).trim()] = line
              .substring(eq + 1)
              .trim();
        }
      }
    }

    final general = sections['General'] ?? {};
    final kde = sections['KDE'] ?? {};
    final accent =
        _parseColor(general['AccentColor']) ?? const Color(0xFF3DAEE9);
    final schemeName = general['ColorScheme'] ?? 'Breeze';
    final accentFromWallpaper =
        general['accentColorFromWallpaper']?.toLowerCase() == 'true';
    final contrast = int.tryParse(kde['contrast'] ?? '') ?? 4;

    KdeColorSet parseSet(String group) {
      final data = sections['Colors:$group'] ?? {};
      Color get(String key, Color fallback) =>
          _parseColor(data[key]) ?? fallback;

      final bgNormal = get('BackgroundNormal', const Color(0xFF1E1D27));
      final fgNormal = get('ForegroundNormal', const Color(0xFFABA8B6));
      final fgInactive = get('ForegroundInactive', const Color(0xFF818296));
      final focus = get('DecorationFocus', accent);

      return KdeColorSet(
        backgroundNormal: bgNormal,
        backgroundAlternate: get('BackgroundAlternate', bgNormal),
        foregroundNormal: fgNormal,
        foregroundInactive: fgInactive,
        foregroundActive: get('ForegroundActive', focus),
        foregroundLink: get('ForegroundLink', const Color(0xFFC9C4DC)),
        foregroundVisited: get('ForegroundVisited', fgInactive),
        foregroundNegative: get('ForegroundNegative', const Color(0xFFCF4F65)),
        foregroundNeutral: get('ForegroundNeutral', const Color(0xFFEB7B47)),
        foregroundPositive: get('ForegroundPositive', const Color(0xFF78FAFF)),
        decorationFocus: focus,
        decorationHover: get('DecorationHover', focus),
      );
    }

    KdeColorEffect parseEffect(String effectGroup) {
      final data = sections['ColorEffects:$effectGroup'] ?? {};
      bool getBool(String key, bool fallback) {
        final v = data[key]?.toLowerCase();
        if (v == null || v.isEmpty) return fallback;
        return v == 'true';
      }

      double getDouble(String key, double fallback) =>
          double.tryParse(data[key] ?? '') ?? fallback;
      int getInt(String key, int fallback) =>
          int.tryParse(data[key] ?? '') ?? fallback;

      final enabled = getBool('Enable', effectGroup == 'Disabled');
      final changeSelectionColor = getBool('ChangeSelectionColor', false);

      final intensityRaw = getInt('IntensityEffect', 0);
      final intensityEffect = switch (intensityRaw) {
        1 => KdeIntensityEffect.shade,
        2 => KdeIntensityEffect.darken,
        3 => KdeIntensityEffect.lighten,
        _ => KdeIntensityEffect.none,
      };

      final colorRaw = getInt('ColorEffect', 0);
      final colorEffect = switch (colorRaw) {
        1 => KdeColorEffectType.desaturate,
        2 => KdeColorEffectType.tint,
        _ => KdeColorEffectType.none,
      };

      final contrastRaw = getInt('ContrastEffect', 0);
      final contrastEffect = switch (contrastRaw) {
        1 => KdeContrastEffect.fade,
        2 => KdeContrastEffect.tint,
        _ => KdeContrastEffect.none,
      };

      return KdeColorEffect(
        enabled: enabled,
        changeSelectionColor: changeSelectionColor,
        intensityEffect: intensityEffect,
        intensityAmount: getDouble('IntensityAmount', 0),
        colorEffect: colorEffect,
        colorAmount: getDouble('ColorAmount', 0),
        color: _parseColor(data['Color']) ?? const Color(0xFF383838),
        contrastEffect: contrastEffect,
        contrastAmount: getDouble('ContrastAmount', 0),
      );
    }

    KdeWmColors parseWm() {
      final data = sections['WM'] ?? {};
      Color get(String key, Color fallback) =>
          _parseColor(data[key]) ?? fallback;

      return KdeWmColors(
        activeBackground: get('activeBackground', const Color(0xFF1E1D27)),
        activeForeground: get('activeForeground', const Color(0xFFFFFFFF)),
        activeBlend: get('activeBlend', const Color(0xFFFFFFFF)),
        inactiveBackground: get('inactiveBackground', const Color(0xFF1E1D27)),
        inactiveForeground: get('inactiveForeground', const Color(0xFFA4A4A8)),
        inactiveBlend: get('inactiveBlend', const Color(0xFF9AA9C8)),
      );
    }

    return KdeColorScheme(
      name: schemeName,
      accentColor: accent,
      accentColorFromWallpaper: accentFromWallpaper,
      window: parseSet('Window'),
      button: parseSet('Button'),
      view: parseSet('View'),
      selection: parseSet('Selection'),
      tooltip: parseSet('Tooltip'),
      complementary: parseSet('Complementary'),
      header: sections.containsKey('Colors:Header') ? parseSet('Header') : null,
      wm: parseWm(),
      disabledEffect: parseEffect('Disabled'),
      inactiveEffect: parseEffect('Inactive'),
      contrast: contrast,
    );
  }

  /// Parses `"R,G,B"` or `"R,G,B,A"` into a [Color]. Returns null on failure.
  static Color? _parseColor(String? value) {
    if (value == null) return null;
    final parts = value.split(',');
    if (parts.length < 3) return null;
    try {
      final r = int.parse(parts[0].trim());
      final g = int.parse(parts[1].trim());
      final b = int.parse(parts[2].trim());
      final a = parts.length >= 4 ? int.parse(parts[3].trim()) : 255;
      return Color.fromARGB(a, r, g, b);
    } catch (_) {
      return null;
    }
  }
}
