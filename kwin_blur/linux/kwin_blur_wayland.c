#include "kwin_blur_private.h"

#include <gdk/gdk.h>
#include <gdk/gdkwayland.h>
#include <glib.h>
#include <string.h>
#include <wayland-client.h>

#include "blur-protocol.h"

/*
 * Wayland backend for the kwin_blur plugin.
 *
 * Lifecycle:
 *   - The blur manager is bound lazily on the first call. We use a private
 *     event queue + proxy wrapper so the registry roundtrip does not steal
 *     events from GTK's own queue. Once bound, the manager proxy is moved
 *     back to the default queue so its (currently non-existent) events would
 *     follow the normal GTK dispatch loop.
 *   - One org_kde_kwin_blur object can exist per surface. We keep a single
 *     active handle and release it when the user toggles state. This keeps
 *     enable() idempotent: repeated calls swap regions cleanly.
 */

static struct org_kde_kwin_blur_manager* g_blur_manager = NULL;
static gboolean g_init_attempted = FALSE;
static gboolean g_init_failed = FALSE;
static struct org_kde_kwin_blur* g_active_blur = NULL;

static void registry_global(void* data,
                            struct wl_registry* registry,
                            uint32_t name,
                            const char* interface,
                            uint32_t version) {
  (void)data;
  (void)version;
  if (strcmp(interface, "org_kde_kwin_blur_manager") == 0) {
    g_blur_manager = (struct org_kde_kwin_blur_manager*)wl_registry_bind(
        registry, name, &org_kde_kwin_blur_manager_interface, 1);
  }
}

static void registry_global_remove(void* data,
                                   struct wl_registry* registry,
                                   uint32_t name) {
  (void)data;
  (void)registry;
  (void)name;
}

static const struct wl_registry_listener kRegistryListener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static gboolean ensure_initialized(GdkDisplay* gdk_display) {
  if (g_init_attempted) {
    return g_blur_manager != NULL;
  }
  g_init_attempted = TRUE;

  if (!GDK_IS_WAYLAND_DISPLAY(gdk_display)) {
    g_init_failed = TRUE;
    return FALSE;
  }

  struct wl_display* display = gdk_wayland_display_get_wl_display(gdk_display);
  if (display == NULL) {
    g_init_failed = TRUE;
    return FALSE;
  }

  struct wl_event_queue* queue = wl_display_create_queue(display);
  struct wl_display* display_wrapper =
      (struct wl_display*)wl_proxy_create_wrapper(display);
  if (display_wrapper == NULL) {
    wl_event_queue_destroy(queue);
    g_init_failed = TRUE;
    return FALSE;
  }
  wl_proxy_set_queue((struct wl_proxy*)display_wrapper, queue);

  struct wl_registry* registry = wl_display_get_registry(display_wrapper);
  wl_proxy_wrapper_destroy(display_wrapper);

  wl_registry_add_listener(registry, &kRegistryListener, NULL);
  if (wl_display_roundtrip_queue(display, queue) < 0) {
    wl_registry_destroy(registry);
    wl_event_queue_destroy(queue);
    g_init_failed = TRUE;
    return FALSE;
  }
  wl_registry_destroy(registry);
  wl_event_queue_destroy(queue);

  if (g_blur_manager != NULL) {
    // Move the manager off our private (now-destroyed) queue so any future
    // events route through GTK's default dispatch.
    wl_proxy_set_queue((struct wl_proxy*)g_blur_manager, NULL);
  } else {
    g_init_failed = TRUE;
  }
  return g_blur_manager != NULL;
}

static struct wl_surface* surface_for_window(GtkWindow* window) {
  GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_win == NULL || !GDK_IS_WAYLAND_WINDOW(gdk_win)) {
    return NULL;
  }
  return gdk_wayland_window_get_wl_surface(gdk_win);
}

static void release_active_blur(void) {
  if (g_active_blur != NULL) {
    org_kde_kwin_blur_release(g_active_blur);
    g_active_blur = NULL;
  }
}

char* kwin_blur_wayland_enable(GtkWindow* window,
                              const KwinBlurRect* rects,
                              size_t n_rects) {
  GdkDisplay* gdk_display = gdk_display_get_default();
  if (gdk_display == NULL || !GDK_IS_WAYLAND_DISPLAY(gdk_display)) {
    return g_strdup("error:not_wayland");
  }
  if (!ensure_initialized(gdk_display)) {
    return g_strdup("error:blur_manager_not_available");
  }

  struct wl_surface* surface = surface_for_window(window);
  if (surface == NULL) {
    return g_strdup("error:no_native_window");
  }

  struct wl_display* wl_disp = gdk_wayland_display_get_wl_display(gdk_display);
  struct wl_compositor* wl_comp =
      gdk_wayland_display_get_wl_compositor(gdk_display);
  if (wl_disp == NULL || wl_comp == NULL) {
    return g_strdup("error:no_compositor");
  }

  release_active_blur();

  g_active_blur =
      org_kde_kwin_blur_manager_create(g_blur_manager, surface);
  if (g_active_blur == NULL) {
    return g_strdup("error:blur_create_failed");
  }

  if (n_rects == 0) {
    org_kde_kwin_blur_set_region(g_active_blur, NULL);
  } else {
    struct wl_region* region = wl_compositor_create_region(wl_comp);
    if (region == NULL) {
      release_active_blur();
      return g_strdup("error:region_create_failed");
    }
    for (size_t i = 0; i < n_rects; i++) {
      wl_region_add(region, rects[i].x, rects[i].y, rects[i].width,
                    rects[i].height);
    }
    org_kde_kwin_blur_set_region(g_active_blur, region);
    wl_region_destroy(region);
  }

  org_kde_kwin_blur_commit(g_active_blur);
  wl_surface_commit(surface);
  wl_display_flush(wl_disp);
  return g_strdup("ok");
}

char* kwin_blur_wayland_disable(GtkWindow* window) {
  GdkDisplay* gdk_display = gdk_display_get_default();
  if (gdk_display == NULL || !GDK_IS_WAYLAND_DISPLAY(gdk_display)) {
    return g_strdup("error:not_wayland");
  }
  // Even if init previously failed (no manager), there is nothing to undo —
  // report success so callers can call disable() unconditionally.
  if (!ensure_initialized(gdk_display)) {
    release_active_blur();
    return g_strdup("ok");
  }

  struct wl_surface* surface = surface_for_window(window);
  if (surface == NULL) {
    release_active_blur();
    return g_strdup("error:no_native_window");
  }

  release_active_blur();
  org_kde_kwin_blur_manager_unset(g_blur_manager, surface);

  struct wl_display* wl_disp = gdk_wayland_display_get_wl_display(gdk_display);
  wl_surface_commit(surface);
  if (wl_disp != NULL) {
    wl_display_flush(wl_disp);
  }
  return g_strdup("ok");
}
