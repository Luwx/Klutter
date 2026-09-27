## 0.1.0

* Convert from a method channel plugin to an FFI package. The native code is
  built by a Dart build hook and finds the Flutter window itself.
* **Breaking:** remove `LinuxAppMenu.channel` and the `methodChannel`
  parameter of `LinuxAppMenu.initialize`.

## 0.0.1

* Export Flutter `PlatformMenuBar` menus through DBusMenu.
* Associate menus through KWin's native Wayland AppMenu protocol.
* Support nested menus, groups, action state, and character accelerators.
* Support checkbox and radio items and dynamically enabled submenus.
* Support freedesktop icon names and `SingleActivator` accelerators.
* Support titled menu sections through `LinuxMenuSection`.
* Add a runnable KDE Global Menu example.
