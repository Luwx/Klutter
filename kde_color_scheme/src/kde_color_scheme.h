#pragma once

#define KDE_COLOR_SCHEME_EXPORT __attribute__((visibility("default")))

// Functions return "ok" or "error:<code>". The strings are static; do not free
// them. They must be called on the GTK main thread, which is where Flutter
// runs Dart by default.

// Asks KWin to paint the Flutter window's decoration with the KDE color scheme
// at `path`. An unmapped window gets the scheme once it is mapped.
KDE_COLOR_SCHEME_EXPORT const char* kde_color_scheme_set_palette(
    const char* path);

// Returns the decoration to the system color scheme.
KDE_COLOR_SCHEME_EXPORT const char* kde_color_scheme_reset_palette(void);
