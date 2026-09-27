# kde_color_scheme

Reads the active KDE Plasma color scheme from `kdeglobals` and sets custom
KWin title bar colors for the Flutter window.

The package exposes window, button, view, selection, tooltip, header, and title
bar colors. It also parses disabled and inactive color effects and can watch
for changes to the file.

`kdeglobals` is read from `$XDG_CONFIG_HOME/kdeglobals` when it exists, and
from `~/.config/kdeglobals` otherwise.

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

## Title bar colors

On KDE Plasma (Wayland), the KWin title bar of the Flutter window can be given
custom colors:

```dart
final applied = await KdeTitlebar.setTitlebarColors(
  background: const Color(0xFF1B5E20),
  foreground: Colors.white,
  // Optional; default to the active colors.
  inactiveBackground: const Color(0xFF5B7560),
  inactiveForeground: Colors.white70,
);

// Back to the system color scheme.
await KdeTitlebar.resetTitlebarColors();
```

`setTitlebarColors` returns false when the session cannot apply it (not
Linux, not Wayland, or a compositor without the KDE decoration palette
protocol) and throws a `PlatformException` for other failures. It can be
called before the window is shown; the colors are applied once it is mapped.

The window must use server-side decorations: do not install a `GtkHeaderBar`
with `gtk_window_set_titlebar()`. KWin may still ignore the colors, e.g. when
a window rule forces a color scheme. How they are used depends on the
decoration theme; Breeze also uses the header background for the window
outline.

### How it works

KWin's `org_kde_kwin_server_decoration_palette` protocol only accepts the path
of a KDE color scheme, not colors. The package writes a small `.colors` file
and sends its path:

- `[Colors:Header]` and `[Colors:Header][Inactive]` hold the requested colors.
  KWin uses them for the title bar background (`BackgroundNormal`) and its
  text and icons (`ForegroundNormal`). `[WM]` is written too, for schemes
  without a header group.
- The other color groups are copied from `kdeglobals`, so the outline, button
  hover and close button colors keep following the system scheme as of the
  call. Call `setTitlebarColors` again after a system scheme change to pick up
  the new values.

KWin ignores a path it already has and does not watch the file for changes,
so every color change writes a file with a new name and removes the old one.

Files are written to the session runtime directory, which is private to the
user, kept in memory and cleared at logout:

| Environment | Directory |
| --- | --- |
| Flatpak | `$XDG_RUNTIME_DIR/app/$FLATPAK_ID/` |
| Native, Snap | `$XDG_RUNTIME_DIR/<executable name>/` |
| No `XDG_RUNTIME_DIR` | `$XDG_CACHE_HOME/<app id>/` |

Files are named `titlebar-<owner>-<hash>.colors`, where the owner is the
process id, or the Flatpak instance id inside Flatpak. On first use, files
from processes that are no longer running are removed. Inside Flatpak other
instances are not visible, so their leftovers are only removed at logout.

See [`example/`](example/) for a runnable test application.

## Building

`KdeTitlebar`'s native library is compiled by a Dart build hook when the app is built. It
needs a C compiler (Flutter's Linux toolchain already provides one),
`pkg-config`, `wayland-scanner`, and the GTK 3 and Wayland development
packages:

- Fedora: `sudo dnf install gtk3-devel wayland-devel pkgconf-pkg-config`
- Debian/Ubuntu: `sudo apt install libgtk-3-dev libwayland-dev pkg-config`

The native functions look up the Flutter window themselves and must run on the
GTK main thread, which is where Flutter runs Dart by default. Apps that opt
into a separate UI thread get `error:not_main_thread`.

## Main types

- `KdeColorScheme`
- `KdeColorSet`
- `KdeColorEffect`
- `KdeWmColors`
- `KdeColorSchemeWatcher`
- `KdeglobalsParser`
- `KdeTitlebar`
