import 'package:flutter/painting.dart';

/// Window manager (title bar) colors from the `[WM]` section of kdeglobals.
///
/// These are used by KWin to paint window decorations and are separate from
/// the widget color groups. Useful for matching the app chrome to the system
/// title bar.
class KdeWmColors {
  const KdeWmColors({
    required this.activeBackground,
    required this.activeForeground,
    required this.activeBlend,
    required this.inactiveBackground,
    required this.inactiveForeground,
    required this.inactiveBlend,
  });

  final Color activeBackground;
  final Color activeForeground;
  final Color activeBlend;
  final Color inactiveBackground;
  final Color inactiveForeground;
  final Color inactiveBlend;

  static const fallback = KdeWmColors(
    activeBackground: Color(0xFF1E1D27),
    activeForeground: Color(0xFFFFFFFF),
    activeBlend: Color(0xFFFFFFFF),
    inactiveBackground: Color(0xFF1E1D27),
    inactiveForeground: Color(0xFFA4A4A8),
    inactiveBlend: Color(0xFF9AA9C8),
  );
}
