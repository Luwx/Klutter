/// Flutter package for reading KDE Plasma color schemes from kdeglobals.
///
/// Provides:
/// - [KdeColorScheme] - the parsed color data (accent, groups, WM, effects)
/// - [KdeColorSet] - one color group (Window, Button, View, …)
/// - [KdeColorEffect] - disabled/inactive state effect descriptor with [apply]
/// - [KdeWmColors] - window manager / title bar colors
/// - [KdeColorSchemeWatcher] - synchronous read + real-time [Stream] of changes
/// - [KdeglobalsParser] — low-level INI parser (use directly if needed)
library kde_color_scheme;

export 'src/kde_color_effect.dart';
export 'src/kde_color_scheme.dart';
export 'src/kde_color_scheme_watcher.dart';
export 'src/kde_color_set.dart';
export 'src/kde_wm_colors.dart';
export 'src/kdeglobals_parser.dart';
