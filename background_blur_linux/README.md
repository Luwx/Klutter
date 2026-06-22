# background_blur_linux

A Flutter plugin that adds blur effect to the Linux app window. Wayland only.

## Requirements

- "Background Blur" effect enabled in System Settings > Desktop Effects
- Flutter >= 3.3

Build dependencies:

Fedora: `sudo dnf install wayland-devel gtk3-devel`  
Debian/Ubuntu: `sudo apt install libwayland-dev libgtk-3-dev`

## Installation

```yaml
dependencies:
  background_blur_linux:
    path: ../background_blur_linux
```

## Setup

Before the blur effect works you need to make three changes to your app's Linux runner (`linux/runner/my_application.cc`).

### 1. Make the window transparent

Add this block after `gtk_window_set_default_size` and before `FlView` is created:

```c
GdkScreen* gtk_screen = gtk_widget_get_screen(GTK_WIDGET(window));
GdkVisual* visual = gdk_screen_get_rgba_visual(gtk_screen);
if (visual != nullptr && gdk_screen_is_composited(gtk_screen)) {
    gtk_widget_set_visual(GTK_WIDGET(window), visual);
}
gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
```

### 2. Set Flutter's background color to transparent

Find where `FlView` is set up and change the background color:

```c
FlView* view = fl_view_new(project);

GdkRGBA background_color;
gdk_rgba_parse(&background_color, "#00000000");
fl_view_set_background_color(view, &background_color);
```

### 3. Use server-side decorations

Replace the `use_header_bar` block with a simple title call. This lets KWin draw the window frame instead of GTK, which is required for blur to work correctly.

```diff
-  gboolean use_header_bar = TRUE;
-#ifdef GDK_WINDOWING_X11
-  GdkScreen* screen = gtk_window_get_screen(window);
-  if (GDK_IS_X11_SCREEN(screen)) {
-    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
-    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
-      use_header_bar = FALSE;
-    }
-  }
-#endif
-  if (use_header_bar) {
-    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
-    gtk_widget_show(GTK_WIDGET(header_bar));
-    gtk_header_bar_set_title(header_bar, "my_app");
-    gtk_header_bar_set_show_close_button(header_bar, TRUE);
-    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
-  } else {
-    gtk_window_set_title(window, "my_app");
-  }
+  gtk_window_set_title(window, "my_app");
```

Also remove the X11 header at the top:

```diff
-#ifdef GDK_WINDOWING_X11
-#include <gdk/gdkx.h>
-#endif
```

If your app also needs to run on GNOME, detect the desktop and add the header bar only there:

```c
const char* desktop = g_getenv("XDG_CURRENT_DESKTOP");
gboolean is_gnome = desktop != nullptr && strstr(desktop, "GNOME") != nullptr;
if (is_gnome) {
  GtkHeaderBar* bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_header_bar_set_title(bar, "my_app");
  gtk_header_bar_set_show_close_button(bar, TRUE);
  gtk_widget_show(GTK_WIDGET(bar));
  gtk_window_set_titlebar(window, GTK_WIDGET(bar));
} else {
  gtk_window_set_title(window, "my_app");
}
```

### 4. Make your Flutter UI transparent

Use a transparent or translucent background in your widget tree:

```dart
Scaffold(
  backgroundColor: Colors.black.withValues(alpha: 0.3),
  body: ...,
)
```

## Usage

Call `enable()` after the first frame. The window must be visible before you call it.

```dart
import 'package:background_blur_linux/background_blur_linux.dart';

// Blur the whole window
await BackgroundBlurLinux.enable();

// Blur specific regions (in pixels)
await BackgroundBlurLinux.enable(region: [
  const BlurRect(0, 0, 300, 60),
  const BlurRect(0, 540, 300, 60),
]);

// Disable blur
await BackgroundBlurLinux.disable();
```

### Rounded corners

```dart
import 'package:flutter/material.dart';
import 'package:background_blur_linux/background_blur_linux.dart';

Future<void> applyRoundedBlur() async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final dpr = view.devicePixelRatio;
  final w = (view.physicalSize.width  / dpr).round();
  final h = (view.physicalSize.height / dpr).round();

  final region = blurRegionForRoundedRect(w, h, BorderRadius.circular(12));
  await BackgroundBlurLinux.enable(region: region);
}
```

`BorderRadius.only`, `BorderRadius.vertical`, and `Radius.elliptical` all work.

### Window resize

Whole-window blur (no region, or an empty region) tracks the window size
automatically. An explicit region is a snapshot in window-local coordinates and
is not rescaled, so re-apply it when the window size changes:

```dart
WidgetsBinding.instance.platformDispatcher.onMetricsChanged = () {
  if (_blurEnabled) applyRoundedBlur();
};
```

## API

**`BackgroundBlurLinux.enable({List<BlurRect>? region})`**  
Enables blur. If region is null or empty, blurs the whole window. Throws if the blur effect is disabled in System Settings.

**`BackgroundBlurLinux.disable()`**  
Removes the blur.

**`BlurRect(int x, int y, int width, int height)`**  
A rectangle in window-local **logical pixels** (`physicalSize / devicePixelRatio`), the surface-local space KWin expects on Wayland.

**`blurRegionForRoundedRect(int width, int height, BorderRadius borderRadius)`**  
Returns a list of `BlurRect` that forms a rounded rectangle.

## Notes

- Call `enable()` after the first frame, not before.
- The blur effect must be enabled in System Settings > Desktop Effects > Background Blur.
- Only works on KDE Plasma. On other desktops the call either errors or does nothing.
