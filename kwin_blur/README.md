# kde_blur

A Flutter plugin that enables the **KDE KWin compositor background blur** effect on Linux, supporting both X11 and Wayland sessions.

When the application window is transparent, KWin blurs the desktop content visible behind it — the same effect used by Plasma's Latte Dock, KRunner, and themes like Lightly/Breeze.

> **Platform**: Linux only (KDE Plasma / KWin).  
> The plugin is a no-op stub on all other platforms (throws `UnsupportedError` if called).

---

## Requirements

| Requirement | Notes |
|---|---|
| KDE Plasma with KWin | Any recent version (Plasma 5 or 6) |
| KWin "Background Blur" effect | Must be enabled in *System Settings → Desktop Effects* |
| Flutter ≥ 3.3 | Linux desktop support |
| Build tools | `wayland-scanner`, `libwayland-dev`, `libx11-dev`, `libgtk-3-dev` |

On Fedora/RHEL: `sudo dnf install wayland-devel libX11-devel gtk3-devel`  
On Debian/Ubuntu: `sudo apt install libwayland-dev libx11-dev libgtk-3-dev`

---

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  kde_blur:
    path: ../kde_blur   # or the pub.dev version once published
```

---

## Required native changes in your app

The plugin sets the blur hint, but **your application's GTK window must be transparent** for the compositor to have anything to blur through. This requires two edits to your app's Linux runner — neither is done automatically by Flutter.

### 1. Apply an RGBA visual to the GTK window

Open `linux/runner/my_application.cc` and add the following block **after** `gtk_window_set_default_size` and **before** creating `FlView`:

```c
// ── kde_blur: make the window transparent ──────────────────────────────────
GdkScreen* gtk_screen = gtk_widget_get_screen(GTK_WIDGET(window));
GdkVisual* visual = gdk_screen_get_rgba_visual(gtk_screen);
if (visual != nullptr && gdk_screen_is_composited(gtk_screen)) {
    gtk_widget_set_visual(GTK_WIDGET(window), visual);
}
gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
// ──────────────────────────────────────────────────────────────────────────
```

`gdk_screen_is_composited` guards the call so that the app still works on non-composited sessions (Wayland always composites; X11 may not).

### 2. Set the Flutter background colour to transparent

Find the `FlView` setup in the same file and change the background colour to fully transparent:

```c
FlView* view = fl_view_new(project);

GdkRGBA background_color;
gdk_rgba_parse(&background_color, "#00000000");   // ← was "#000000"
fl_view_set_background_color(view, &background_color);
```

### 3. Use server-side decorations (SSD)

Flutter's Linux runner defaults to a `GtkHeaderBar` (client-side decorations, CSD). CSD means GTK draws its own title bar and shadow *inside* the window, which conflicts with blur — the compositor only blurs the area the app reports as transparent, but GTK's CSD shell is opaque and sits on top.

With SSD the window manager owns the title bar and frame entirely, so the app's drawable surface starts cleanly at the top-left corner and the blur region covers exactly what you expect.

**The change:** in `linux/runner/my_application.cc`, remove the entire `use_header_bar` block (including `GtkHeaderBar` construction and `gtk_window_set_titlebar()`) and replace it with a plain title call:

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
+  // Do NOT call gtk_window_set_titlebar() — that locks GTK into CSD.
+  // Without a custom titlebar widget GTK negotiates SSD with the compositor
+  // via the xdg-decoration protocol. KWin supports this and will draw the
+  // title bar server-side. On X11 the WM always owns decorations anyway.
+  gtk_window_set_title(window, "my_app");
```

Also remove the now-unused X11 header at the top of the file:

```diff
-#ifdef GDK_WINDOWING_X11
-#include <gdk/gdkx.h>
-#endif
```

**Why this works on Wayland:** when `gtk_window_set_titlebar()` is never called, GTK advertises support for the `zxdg_decoration_manager_v1` protocol during surface creation. KWin sees this and grants `SERVER_SIDE` mode, so the WM draws the frame and the application's surface is decoration-free.

**GNOME caveat:** Mutter (GNOME's compositor) does not implement `xdg-decoration` and falls back to CSD regardless. If your app needs to run on both KDE and GNOME, detect the desktop at runtime and conditionally add the header bar only on GNOME:

```c
const char* desktop = g_getenv("XDG_CURRENT_DESKTOP");
gboolean is_gnome = desktop != nullptr &&
                    strstr(desktop, "GNOME") != nullptr;
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

### 4. Make your Flutter UI transparent where you want blur

Your widget tree must **not** paint an opaque background over the window. Use `Colors.transparent` (or a translucent colour) as the `Scaffold` or topmost container background:

```dart
Scaffold(
  backgroundColor: Colors.black.withValues(alpha: 0.3), // translucent
  body: ...,
)
```

---

## Usage

### Enable blur for the whole window

```dart
import 'package:kde_blur/kde_blur.dart';

// Call after the first frame (the native window must be visible first).
await KdeBlur.enable();
```

### Blur a specific region

Pass a list of `BlurRect` values (window-local pixels):

```dart
await KdeBlur.enable(region: [
  const BlurRect(0, 0, 300, 60),    // top bar
  const BlurRect(0, 540, 300, 60),  // bottom bar
]);
```

### Rounded corners

Use `blurRegionForRoundedRect` to generate a pixel-accurate scanline approximation of a rounded rectangle. It accepts Flutter's standard `BorderRadius` so each corner can have an independent (and optionally elliptical) radius.

```dart
import 'package:flutter/material.dart';
import 'package:kde_blur/kde_blur.dart';

Future<void> applyRoundedBlur() async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;

  // Wayland → logical pixels.  X11 → physical pixels (multiply by dpr).
  final dpr = view.devicePixelRatio;
  final w = (view.physicalSize.width  / dpr).round();
  final h = (view.physicalSize.height / dpr).round();

  final region = blurRegionForRoundedRect(
    w, h,
    BorderRadius.circular(12),
  );

  await KdeBlur.enable(region: region);
}
```

`BorderRadius.only`, `BorderRadius.vertical`, and elliptical radii (`Radius.elliptical`) all work.

### Disable blur

```dart
await KdeBlur.disable();
```

### Responding to window resize

The blur region is static — KWin does not automatically scale it when the window is resized. Re-apply the region from a `LayoutBuilder` or by listening to `PlatformDispatcher.onMetricsChanged`:

```dart
WidgetsBinding.instance.platformDispatcher.onMetricsChanged = () {
  if (_blurEnabled) applyRoundedBlur();
};
```

---

## API reference

### `KdeBlur.enable({List<BlurRect>? region})`

Sends the blur hint to KWin. A null or empty `region` blurs the entire window. Throws `Exception` if the compositor reports an error (e.g. blur effect disabled), and `UnsupportedError` on non-Linux platforms.

### `KdeBlur.disable()`

Removes the blur hint. Throws `UnsupportedError` on non-Linux platforms.

### `BlurRect(int x, int y, int width, int height)`

A rectangle in window-local pixel coordinates. On Wayland these are logical pixels; on X11 they are physical pixels.

### `blurRegionForRoundedRect(int width, int height, BorderRadius borderRadius)`

Returns a `List<BlurRect>` that approximates a rounded rectangle. Consecutive scanlines with equal spans are merged, so the list stays small (`O(radius)` entries). Corners are clamped to half the window dimension so the result is always valid.

**Coordinate space**:

| Session | `width`/`height` to pass |
|---|---|
| Wayland | `(physicalSize / devicePixelRatio).round()` — logical pixels |
| X11 | `physicalSize.round()` — physical pixels |

---

## How it works

### Runtime backend selection

At plugin registration the `WAYLAND_DISPLAY` environment variable is checked once. If it is set and non-empty, the Wayland backend is used; otherwise the X11 backend is used. This mirrors how GTK itself chooses a backend and is safe to evaluate once per process.

### Wayland backend

Binds to the `org_kde_kwin_blur_manager` Wayland global (a KDE unstable extension). The global is discovered via a private `wl_event_queue` + `wl_proxy_create_wrapper` so the registry roundtrip does not steal events from GTK's queue. If the global is not advertised — because a non-KDE compositor is running, or because the blur effect is disabled — the call returns `error:blur_manager_not_available`.

For each `enable` call, a new `org_kde_kwin_blur` object is created with the requested `wl_region`, committed, then the surface is committed so KWin picks it up immediately. The previous handle (if any) is `release`d first so toggling is idempotent.

### X11 backend

Sets the `_KDE_NET_WM_BLUR_BEHIND_REGION` property on the top-level X window via `XChangeProperty` as `CARDINAL[32]` (four `long` values per rect: `x y width height`). An empty property (`nelements=0`) signals KWin to blur the whole window. On non-KDE window managers this property is silently ignored.

### Rounded-corner geometry

`blurRegionForRoundedRect` computes per-scanline left/right insets using the ellipse formula with pixel-centre sampling:

```
inset(dy, rx, ry) = rx − ⌊rx · √(1 − t²)⌋     where t = (ry − dy − 0.5) / ry
```

The `−0.5` samples the pixel centre rather than the top edge, so the blur boundary aligns with Flutter's own rounded-rect painter at the same radius.

---

## Caveats

- **Call `enable()` after the first frame.** The GTK window has no native handle until it is shown. Calling before the first frame will return `error:no_native_window`.

- **The blur region is not automatically resized.** Re-call `enable()` after window resize if you are using a custom region (including rounded corners).

- **Wayland coordinate space is logical pixels, X11 is physical pixels.** If you mix them up the region will be mis-sized on HiDPI screens. Use `view.physicalSize / view.devicePixelRatio` for Wayland and `view.physicalSize` for X11.

- **Blur must be enabled in System Settings.** On a fresh KDE install the effect is on by default; it can be disabled in *System Settings → Desktop Effects → Background Blur*. When disabled, `enable()` throws on Wayland (`error:blur_manager_not_available`) and silently does nothing on X11.

- **Non-KDE compositors.** GNOME/Mutter, wlroots-based compositors, and bare X11 WMs do not implement `org_kde_kwin_blur_manager` or `_KDE_NET_WM_BLUR_BEHIND_REGION`. The Wayland backend returns an error; the X11 backend succeeds silently with no visual effect.

- **Transparency requires a compositor.** On bare X11 without a compositing window manager, `gdk_screen_is_composited` returns false, the RGBA visual is not applied, and the window will be opaque regardless.
