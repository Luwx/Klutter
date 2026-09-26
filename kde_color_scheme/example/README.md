# kde_color_scheme example

This application shows color swatches. Selecting one sets the KWin title bar
to that color, with a readable foreground and a grayer inactive variant.
**Reset to system colors** returns the title bar to the system color scheme.

To test it on KDE Plasma, run `flutter run -d linux` from this directory and
select a swatch. Focus another window to see the inactive colors.

The example requests server-side decorations and runs through the native
Wayland backend.
