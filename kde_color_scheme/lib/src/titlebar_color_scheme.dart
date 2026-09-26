import 'dart:ui';

import 'kconfig.dart';

/// Colors used by KWin for a window's title bar.
class TitlebarColors {
  const TitlebarColors({
    required this.background,
    required this.foreground,
    Color? inactiveBackground,
    Color? inactiveForeground,
  }) : inactiveBackground = inactiveBackground ?? background,
       inactiveForeground = inactiveForeground ?? foreground;

  final Color background;
  final Color foreground;
  final Color inactiveBackground;
  final Color inactiveForeground;
}

/// Builds a KDE `.colors` file that KWin uses for the window decoration.
///
/// [base] is the content of the user's `kdeglobals`. Its color groups are
/// copied so that the parts of the decoration not covered by [colors], such as
/// the outline and the close button hover color, keep following the system
/// scheme. `[General]` is not copied, so the accent color is not reapplied on
/// top of the custom colors.
///
/// KWin paints the title bar with `[Colors:Header]` when the scheme has it, and
/// only falls back to `[WM]` otherwise. Both are written.
String buildTitlebarColorScheme(TitlebarColors colors, {String? base}) {
  final groups = <String, Map<String, String>>{};
  if (base != null) {
    for (final MapEntry(key: name, value: entries) in parseKConfigGroups(
      base,
    ).entries) {
      if (name.startsWith('Colors:') ||
          name.startsWith('ColorEffects:') ||
          name == 'WM') {
        groups[name] = entries;
      } else if (name == 'KDE' && entries.containsKey('contrast')) {
        groups[name] = {'contrast': entries['contrast']!};
      }
    }
  }

  // KColorScheme reads the inactive header colors from a subgroup and does not
  // fall back to the active group for missing keys, so both are seeded fully.
  final header = {...?groups['Colors:Header'] ?? groups['Colors:Window']};
  final inactiveHeader = {...groups['Colors:Header][Inactive'] ?? header};

  groups['Colors:Header'] = header
    ..['BackgroundNormal'] = _formatColor(colors.background)
    ..['BackgroundAlternate'] = _formatColor(colors.background)
    ..['ForegroundNormal'] = _formatColor(colors.foreground);
  groups['Colors:Header][Inactive'] = inactiveHeader
    ..['BackgroundNormal'] = _formatColor(colors.inactiveBackground)
    ..['BackgroundAlternate'] = _formatColor(colors.inactiveBackground)
    ..['ForegroundNormal'] = _formatColor(colors.inactiveForeground);
  groups['WM'] = {...?groups['WM']}
    ..['activeBackground'] = _formatColor(colors.background)
    ..['activeForeground'] = _formatColor(colors.foreground)
    ..['inactiveBackground'] = _formatColor(colors.inactiveBackground)
    ..['inactiveForeground'] = _formatColor(colors.inactiveForeground);

  final buffer = StringBuffer()
    ..writeln('[General]')
    ..writeln('Name=Klutter Title Bar');
  final names = groups.keys.toList()..sort();
  for (final name in names) {
    buffer
      ..writeln()
      ..writeln('[$name]');
    groups[name]!.forEach((key, value) => buffer.writeln('$key=$value'));
  }
  return buffer.toString();
}

String _formatColor(Color color) {
  final argb = color.toARGB32();
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return a == 0xFF ? '$r,$g,$b' : '$r,$g,$b,$a';
}
