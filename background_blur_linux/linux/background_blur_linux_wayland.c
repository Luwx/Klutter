#include "background_blur_linux_private.h"

#include <gdk/gdk.h>
#include <gdk/gdkwayland.h>
#include <glib.h>
#include <string.h>
#include <wayland-client.h>

#include "blur-protocol.h"
#include "ext-background-effect-v1-protocol.h"

/*
 * Wayland backend for the background_blur_linux plugin.
 *
 * Protocol selection:
 *   - We prefer the standardized ext_background_effect_v1 protocol, which KWin
 *     ships from Plasma 6.7 onwards (and which other compositors may adopt). It
 *     is only used when the compositor advertises the "blur" capability.
 *   - When that protocol is unavailable we fall back to the legacy KDE-specific
 *     org_kde_kwin_blur protocol, which has been around since 2015 and works on
 *     essentially all current KDE versions.
 *
 * Lifecycle:
 *   - The managers are bound lazily on the first call. We use a private event
 *     queue + proxy wrapper so the registry roundtrip does not steal events
 *     from GTK's own queue. The ext manager also emits a capabilities event on
 *     bind, so we run a second roundtrip to collect it before deciding which
 *     backend to use. Once bound, the manager proxies are moved back to the
 *     default queue so any future events follow the normal GTK dispatch loop.
 *   - One effect/blur object can exist per surface. We keep a single active
 *     handle per protocol and release it when the user toggles state. This
 *     keeps enable() idempotent: repeated calls swap regions cleanly.
 */

static struct ext_background_effect_manager_v1* g_ext_manager = NULL;
static struct ext_background_effect_surface_v1* g_ext_active = NULL;
static gboolean g_ext_blur_supported = FALSE;

static struct org_kde_kwin_blur_manager* g_kde_manager = NULL;
static struct org_kde_kwin_blur* g_kde_active = NULL;

static gboolean g_init_attempted = FALSE;

static void ext_manager_capabilities(void* data,
                                     struct ext_background_effect_manager_v1* mgr,
                                     uint32_t flags) {
  (void)data;
  (void)mgr;
  g_ext_blur_supported =
      (flags & EXT_BACKGROUND_EFFECT_MANAGER_V1_CAPABILITY_BLUR) ? TRUE : FALSE;
}

static const struct ext_background_effect_manager_v1_listener kExtManagerListener = {
    .capabilities = ext_manager_capabilities,
};

static void registry_global(void* data,
                            struct wl_registry* registry,
                            uint32_t name,
                            const char* interface,
                            uint32_t version) {
  (void)data;
  (void)version;
  if (strcmp(interface, "ext_background_effect_manager_v1") == 0) {
    g_ext_manager = (struct ext_background_effect_manager_v1*)wl_registry_bind(
        registry, name, &ext_background_effect_manager_v1_interface, 1);
    ext_background_effect_manager_v1_add_listener(g_ext_manager,
                                                  &kExtManagerListener, NULL);
  } else if (strcmp(interface, "org_kde_kwin_blur_manager") == 0) {
    g_kde_manager = (struct org_kde_kwin_blur_manager*)wl_registry_bind(
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

/* TRUE when at least one usable blur backend is available. */
static gboolean have_backend(void) {
  return (g_ext_manager != NULL && g_ext_blur_supported) ||
         g_kde_manager != NULL;
}

static gboolean ensure_initialized(GdkDisplay* gdk_display) {
  if (g_init_attempted) {
    return have_backend();
  }
  g_init_attempted = TRUE;

  if (!GDK_IS_WAYLAND_DISPLAY(gdk_display)) {
    return FALSE;
  }

  struct wl_display* display = gdk_wayland_display_get_wl_display(gdk_display);
  if (display == NULL) {
    return FALSE;
  }

  struct wl_event_queue* queue = wl_display_create_queue(display);
  struct wl_display* display_wrapper =
      (struct wl_display*)wl_proxy_create_wrapper(display);
  if (display_wrapper == NULL) {
    wl_event_queue_destroy(queue);
    return FALSE;
  }
  wl_proxy_set_queue((struct wl_proxy*)display_wrapper, queue);

  struct wl_registry* registry = wl_display_get_registry(display_wrapper);
  wl_proxy_wrapper_destroy(display_wrapper);

  wl_registry_add_listener(registry, &kRegistryListener, NULL);
  // First roundtrip: receive the globals and bind the managers (which also
  // attaches the ext capabilities listener).
  if (wl_display_roundtrip_queue(display, queue) < 0) {
    wl_registry_destroy(registry);
    wl_event_queue_destroy(queue);
    return FALSE;
  }
  // Second roundtrip: the ext manager emits its capabilities event on bind;
  // collect it so g_ext_blur_supported is known before we choose a backend.
  if (g_ext_manager != NULL) {
    if (wl_display_roundtrip_queue(display, queue) < 0) {
      wl_registry_destroy(registry);
      wl_event_queue_destroy(queue);
      return FALSE;
    }
  }
  wl_registry_destroy(registry);
  wl_event_queue_destroy(queue);

  // Move the managers off our private (now-destroyed) queue so any future
  // events route through GTK's default dispatch.
  if (g_ext_manager != NULL) {
    wl_proxy_set_queue((struct wl_proxy*)g_ext_manager, NULL);
  }
  if (g_kde_manager != NULL) {
    wl_proxy_set_queue((struct wl_proxy*)g_kde_manager, NULL);
  }
  return have_backend();
}

static struct wl_surface* surface_for_window(GtkWindow* window) {
  GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_win == NULL || !GDK_IS_WAYLAND_WINDOW(gdk_win)) {
    return NULL;
  }
  return gdk_wayland_window_get_wl_surface(gdk_win);
}

static void release_active_blur(void) {
  if (g_ext_active != NULL) {
    ext_background_effect_surface_v1_destroy(g_ext_active);
    g_ext_active = NULL;
  }
  if (g_kde_active != NULL) {
    org_kde_kwin_blur_release(g_kde_active);
    g_kde_active = NULL;
  }
}

// A region far larger than any real window. The compositor clips the blur
// region to the surface, so this stands in for "the whole window" and keeps
// covering it as the window is resized.
#define BLUR_WHOLE_WINDOW_EXTENT (1 << 24)

static struct wl_region* whole_window_region(struct wl_compositor* wl_comp) {
  struct wl_region* region = wl_compositor_create_region(wl_comp);
  if (region == NULL) {
    return NULL;
  }
  wl_region_add(region, 0, 0, BLUR_WHOLE_WINDOW_EXTENT, BLUR_WHOLE_WINDOW_EXTENT);
  return region;
}

static struct wl_region* build_region(struct wl_compositor* wl_comp,
                                      const BackgroundBlurLinuxRect* rects,
                                      size_t n_rects) {
  struct wl_region* region = wl_compositor_create_region(wl_comp);
  if (region == NULL) {
    return NULL;
  }
  for (size_t i = 0; i < n_rects; i++) {
    wl_region_add(region, rects[i].x, rects[i].y, rects[i].width,
                  rects[i].height);
  }
  return region;
}

char* background_blur_linux_wayland_enable(GtkWindow* window,
                              const BackgroundBlurLinuxRect* rects,
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

  if (g_ext_manager != NULL && g_ext_blur_supported) {
    // Preferred path: ext_background_effect_v1.
    g_ext_active =
        ext_background_effect_manager_v1_get_background_effect(g_ext_manager,
                                                              surface);
    if (g_ext_active == NULL) {
      return g_strdup("error:blur_create_failed");
    }
    // Unlike org_kde_kwin_blur, a NULL region here *removes* the effect rather
    // than meaning "whole window". For whole-window blur we set an oversized
    // region; the compositor clips it to the surface size, so it also keeps
    // tracking the window across resizes without us re-applying it.
    struct wl_region* region =
        n_rects == 0 ? whole_window_region(wl_comp)
                     : build_region(wl_comp, rects, n_rects);
    if (region == NULL) {
      release_active_blur();
      return g_strdup("error:region_create_failed");
    }
    ext_background_effect_surface_v1_set_blur_region(g_ext_active, region);
    wl_region_destroy(region);
    // ext has no per-object commit; state applies on wl_surface.commit.
  } else {
    // Fallback path: org_kde_kwin_blur.
    g_kde_active = org_kde_kwin_blur_manager_create(g_kde_manager, surface);
    if (g_kde_active == NULL) {
      return g_strdup("error:blur_create_failed");
    }
    if (n_rects == 0) {
      org_kde_kwin_blur_set_region(g_kde_active, NULL);
    } else {
      struct wl_region* region = build_region(wl_comp, rects, n_rects);
      if (region == NULL) {
        release_active_blur();
        return g_strdup("error:region_create_failed");
      }
      org_kde_kwin_blur_set_region(g_kde_active, region);
      wl_region_destroy(region);
    }
    org_kde_kwin_blur_commit(g_kde_active);
  }

  wl_surface_commit(surface);
  wl_display_flush(wl_disp);
  return g_strdup("ok");
}

char* background_blur_linux_wayland_disable(GtkWindow* window) {
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

  // For ext, set_blur_region(NULL) clears the effect and destroy() drops the
  // regions on the next commit. For the legacy protocol we additionally call
  // unset() on the manager. release_active_blur() handles the destroys; we set
  // NULL first so the cleared region is part of the same commit.
  if (g_ext_active != NULL) {
    ext_background_effect_surface_v1_set_blur_region(g_ext_active, NULL);
  }
  release_active_blur();
  if (g_kde_manager != NULL) {
    org_kde_kwin_blur_manager_unset(g_kde_manager, surface);
  }

  struct wl_display* wl_disp = gdk_wayland_display_get_wl_display(gdk_display);
  wl_surface_commit(surface);
  if (wl_disp != NULL) {
    wl_display_flush(wl_disp);
  }
  return g_strdup("ok");
}
