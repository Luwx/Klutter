# linux_app_menu example

This application exports File, Appearance, and Help menus. Its Appearance menu
uses radio groups to control the app's theme mode and accent color. A checkbox
dynamically enables or disables the Accent Color submenu.

To test it on KDE Plasma:

1. Add the **Global Menu** widget to a panel, or add the **Application Menu**
   button to the active window decoration.
2. Run `flutter run -d linux` from this directory.
3. Select **Appearance → Theme Mode → Light/Dark** and verify that the app
   theme and radio indicator change.
4. Toggle **Appearance → Use Custom Accent Color** and verify that
   **Accent Color** becomes disabled or enabled.
5. Select an **Accent Color** radio item and verify that the app's color scheme
   and radio indicator change.

The example requests server-side decorations and runs through the native
Wayland backend. The package intentionally does not support X11 or XWayland.
