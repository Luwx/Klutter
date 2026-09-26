# Klutter

Flutter packages for KDE Plasma and Linux desktop integration.

## Packages

| Package | Description |
| --- | --- |
| [background_blur_linux](background_blur_linux/) | Enables KWin background blur for Flutter windows on Wayland. |
| [kde_color_scheme](kde_color_scheme/) | Reads KDE color settings and watches for changes. |
| [linux_app_menu](linux_app_menu/) | Exports Flutter menus to KDE's Global Menu on Wayland. |

## Development

The repository uses a Dart pub workspace. Resolve all packages from the
repository root:

```sh
dart pub get
```

List the workspace packages:

```sh
dart pub workspace list
```

Run package commands from its directory:

```sh
cd linux_app_menu
flutter test
dart analyze
```
