import 'package:flutter/painting.dart';

/// One KDE color group (e.g. Window, Button, View, Selection).
///
/// Maps to a `[Colors:GroupName]` section in kdeglobals.
class KdeColorSet {
  const KdeColorSet({
    required this.backgroundNormal,
    required this.backgroundAlternate,
    required this.foregroundNormal,
    required this.foregroundInactive,
    required this.foregroundActive,
    required this.foregroundLink,
    required this.foregroundVisited,
    required this.foregroundNegative,
    required this.foregroundNeutral,
    required this.foregroundPositive,
    required this.decorationFocus,
    required this.decorationHover,
  });

  final Color backgroundNormal;
  final Color backgroundAlternate;
  final Color foregroundNormal;
  final Color foregroundInactive;
  final Color foregroundActive;
  final Color foregroundLink;
  final Color foregroundVisited;
  final Color foregroundNegative;
  final Color foregroundNeutral;
  final Color foregroundPositive;
  final Color decorationFocus;
  final Color decorationHover;

  static const fallback = KdeColorSet(
    backgroundNormal: Color(0xFF1E1D27),
    backgroundAlternate: Color(0xFF3A3848),
    foregroundNormal: Color(0xFFABA8B6),
    foregroundInactive: Color(0xFF818296),
    foregroundActive: Color(0xFF7863B1),
    foregroundLink: Color(0xFFC9C4DC),
    foregroundVisited: Color(0xFF818296),
    foregroundNegative: Color(0xFFCF4F65),
    foregroundNeutral: Color(0xFFEB7B47),
    foregroundPositive: Color(0xFF78FAFF),
    decorationFocus: Color(0xFF7863B1),
    decorationHover: Color(0xFF7863B1),
  );
}
