# kde_color_scheme

Reads the active KDE Plasma color scheme from `~/.config/kdeglobals`.

The package exposes window, button, view, selection, tooltip, header, and title
bar colors. It also parses disabled and inactive color effects and can watch
for changes to the file.

## Installation

```yaml
dependencies:
  kde_color_scheme:
    git:
      url: https://github.com/Luwx/Klutter.git
      path: kde_color_scheme
```

## Usage

Read the current color scheme:

```dart
import 'package:kde_color_scheme/kde_color_scheme.dart';

final scheme = KdeColorSchemeWatcher().current;

print(scheme.name);
print(scheme.isDark);
print(scheme.accentColor);
print(scheme.window.backgroundNormal);
```

Watch for changes:

```dart
final watcher = KdeColorSchemeWatcher();

final subscription = watcher.stream.listen((scheme) {
  print('Color scheme changed to ${scheme.name}');
});

await subscription.cancel();
watcher.dispose();
```

Check whether KDE configuration is available:

```dart
if (KdeglobalsParser.isAvailable()) {
  final scheme = KdeglobalsParser.parseFile(
    KdeglobalsParser.defaultPath,
  );
}
```

`KdeColorSchemeWatcher.current` returns `KdeColorScheme.fallback` when the file
is missing or cannot be parsed.

## Main types

- `KdeColorScheme`
- `KdeColorSet`
- `KdeColorEffect`
- `KdeWmColors`
- `KdeColorSchemeWatcher`
- `KdeglobalsParser`
