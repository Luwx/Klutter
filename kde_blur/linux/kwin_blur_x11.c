#include "kwin_blur_private.h"

#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <gdk/gdk.h>
#include <gdk/gdkx.h>
#include <glib.h>

/*
 * X11 backend for the kwin_blur plugin.
 *
 * KWin reads the _KDE_NET_WM_BLUR_BEHIND_REGION property on the toplevel
 * X window. The property is a CARDINAL[] of 32-bit values laid out as
 * tuples of (x, y, width, height). A zero-length property blurs the whole
 * window. Setting an unknown property is harmless on non-KDE WMs.
 *
 * Note: when format=32, Xlib expects an array of `long` regardless of
 * the actual word size on the host (this is the documented quirk in
 * XChangeProperty).
 */

#define BLUR_ATOM_NAME "_KDE_NET_WM_BLUR_BEHIND_REGION"

static Window get_x_window(GtkWindow* window, Display** out_display) {
  *out_display = NULL;
  GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_win == NULL || !GDK_IS_X11_WINDOW(gdk_win)) {
    return None;
  }
  GdkDisplay* gdk_display = gdk_window_get_display(gdk_win);
  if (gdk_display == NULL || !GDK_IS_X11_DISPLAY(gdk_display)) {
    return None;
  }
  *out_display = gdk_x11_display_get_xdisplay(gdk_display);
  return gdk_x11_window_get_xid(gdk_win);
}

char* kwin_blur_x11_enable(GtkWindow* window,
                          const KwinBlurRect* rects,
                          size_t n_rects) {
  Display* display = NULL;
  Window xwin = get_x_window(window, &display);
  if (display == NULL || xwin == None) {
    return g_strdup("error:no_native_window");
  }

  Atom atom = XInternAtom(display, BLUR_ATOM_NAME, False);
  if (atom == None) {
    return g_strdup("error:atom_failed");
  }

  if (n_rects == 0) {
    // Empty property = blur the whole window. Xlib accepts nelements=0 with
    // a NULL data pointer for PropModeReplace.
    XChangeProperty(display, xwin, atom, XA_CARDINAL, 32, PropModeReplace,
                    NULL, 0);
  } else {
    // XChangeProperty with format=32 expects an array of `long` (per Xlib).
    size_t n_longs = n_rects * 4;
    long* data = g_new0(long, n_longs);
    for (size_t i = 0; i < n_rects; i++) {
      data[i * 4 + 0] = (long)rects[i].x;
      data[i * 4 + 1] = (long)rects[i].y;
      data[i * 4 + 2] = (long)rects[i].width;
      data[i * 4 + 3] = (long)rects[i].height;
    }
    XChangeProperty(display, xwin, atom, XA_CARDINAL, 32, PropModeReplace,
                    (unsigned char*)data, (int)n_longs);
    g_free(data);
  }

  XFlush(display);
  return g_strdup("ok");
}

char* kwin_blur_x11_disable(GtkWindow* window) {
  Display* display = NULL;
  Window xwin = get_x_window(window, &display);
  if (display == NULL || xwin == None) {
    return g_strdup("error:no_native_window");
  }
  Atom atom = XInternAtom(display, BLUR_ATOM_NAME, False);
  if (atom == None) {
    return g_strdup("error:atom_failed");
  }
  XDeleteProperty(display, xwin, atom);
  XFlush(display);
  return g_strdup("ok");
}
