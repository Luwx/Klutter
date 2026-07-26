#include "linux_app_menu_wayland.h"

#include <gdk/gdkwayland.h>
#include <string.h>
#include <wayland-client.h>

#include "appmenu-protocol.h"

static struct org_kde_kwin_appmenu_manager* g_manager = NULL;
static struct org_kde_kwin_appmenu* g_appmenu = NULL;
static gboolean g_init_attempted = FALSE;

static void registry_global(void* data,
                            struct wl_registry* registry,
                            uint32_t name,
                            const char* interface,
                            uint32_t version) {
  (void)data;
  (void)version;
  if (strcmp(interface, "org_kde_kwin_appmenu_manager") == 0) {
    g_manager = wl_registry_bind(
        registry, name, &org_kde_kwin_appmenu_manager_interface, 1);
  }
}

static void registry_global_remove(void* data,
                                   struct wl_registry* registry,
                                   uint32_t name) {
  (void)data;
  (void)registry;
  (void)name;
}

static const struct wl_registry_listener k_registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static gboolean ensure_initialized(GdkDisplay* gdk_display) {
  if (g_init_attempted) {
    return g_manager != NULL;
  }
  g_init_attempted = TRUE;
  if (!GDK_IS_WAYLAND_DISPLAY(gdk_display)) {
    return FALSE;
  }

  struct wl_display* display =
      gdk_wayland_display_get_wl_display(gdk_display);
  struct wl_event_queue* queue = wl_display_create_queue(display);
  struct wl_display* wrapper = wl_proxy_create_wrapper(display);
  if (queue == NULL || wrapper == NULL) {
    if (wrapper != NULL) {
      wl_proxy_wrapper_destroy(wrapper);
    }
    if (queue != NULL) {
      wl_event_queue_destroy(queue);
    }
    return FALSE;
  }
  wl_proxy_set_queue((struct wl_proxy*)wrapper, queue);

  struct wl_registry* registry = wl_display_get_registry(wrapper);
  wl_proxy_wrapper_destroy(wrapper);
  wl_registry_add_listener(registry, &k_registry_listener, NULL);
  const int result = wl_display_roundtrip_queue(display, queue);
  wl_registry_destroy(registry);
  wl_event_queue_destroy(queue);
  if (result < 0 || g_manager == NULL) {
    return FALSE;
  }
  wl_proxy_set_queue((struct wl_proxy*)g_manager, NULL);
  return TRUE;
}

void linux_app_menu_wayland_clear(void) {
  if (g_appmenu != NULL) {
    org_kde_kwin_appmenu_release(g_appmenu);
    g_appmenu = NULL;
  }
}

gchar* linux_app_menu_wayland_set_address(GtkWindow* window,
                                          const gchar* service_name,
                                          const gchar* object_path) {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (!GDK_IS_WAYLAND_DISPLAY(display)) {
    return g_strdup("error:not_wayland");
  }
  if (!ensure_initialized(display)) {
    return g_strdup("error:appmenu_manager_not_available");
  }

  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window == NULL || !GDK_IS_WAYLAND_WINDOW(gdk_window)) {
    return g_strdup("error:no_wayland_surface");
  }
  struct wl_surface* surface =
      gdk_wayland_window_get_wl_surface(gdk_window);
  if (surface == NULL) {
    return g_strdup("error:no_wayland_surface");
  }

  linux_app_menu_wayland_clear();
  g_appmenu = org_kde_kwin_appmenu_manager_create(g_manager, surface);
  if (g_appmenu == NULL) {
    return g_strdup("error:appmenu_create_failed");
  }
  org_kde_kwin_appmenu_set_address(g_appmenu, service_name, object_path);
  wl_display_flush(gdk_wayland_display_get_wl_display(display));
  return g_strdup("ok");
}
