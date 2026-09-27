## 0.2.0

* Add `KdeTitlebar.setTitlebarColors` and `resetTitlebarColors` to set custom
  KWin title bar colors through the KDE decoration palette protocol.
* Read `kdeglobals` from `$XDG_CONFIG_HOME` when it exists, falling back to
  `~/.config`. Add `KdeglobalsParser.defaultPathFor`.
* Merge repeated groups in `kdeglobals`, as KConfig does, instead of keeping
  only the last one.
* The native code is built by a Dart build hook and called through FFI. Apps
  need the GTK 3 and Wayland development packages to build on Linux.

## 0.1.0

* Read the active KDE color scheme from `kdeglobals`, including color sets,
  window manager colors, and disabled and inactive color effects.
* Watch `kdeglobals` for changes.
