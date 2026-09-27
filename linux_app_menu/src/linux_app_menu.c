#include "linux_app_menu.h"

#include <gdk/gdkwayland.h>
#include <gtk/gtk.h>
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

// Flutter's GTK window: the toplevel that contains the FlView. The type is
// looked up by name so the library does not link against the Flutter engine.
static gboolean contains_widget_of_type(GtkWidget* widget, GType type) {
  if (G_TYPE_CHECK_INSTANCE_TYPE(widget, type)) {
    return TRUE;
  }
  if (!GTK_IS_CONTAINER(widget)) {
    return FALSE;
  }
  GList* children = gtk_container_get_children(GTK_CONTAINER(widget));
  gboolean found = FALSE;
  for (GList* l = children; l != NULL && !found; l = l->next) {
    found = contains_widget_of_type(GTK_WIDGET(l->data), type);
  }
  g_list_free(children);
  return found;
}

static GtkWindow* find_flutter_window(void) {
  GType view_type = g_type_from_name("FlView");
  if (view_type == 0) {
    return NULL;
  }
  GList* windows = gtk_window_list_toplevels();
  GtkWindow* found = NULL;
  for (GList* l = windows; l != NULL && found == NULL; l = l->next) {
    if (contains_widget_of_type(GTK_WIDGET(l->data), view_type)) {
      found = GTK_WINDOW(l->data);
    }
  }
  g_list_free(windows);
  return found;
}

// GTK is not thread safe. Flutter runs Dart on the GTK main thread unless the
// app opts into a separate UI thread.
static gboolean on_main_thread(void) {
  return g_main_context_is_owner(g_main_context_default());
}

static void release_appmenu(void) {
  if (g_appmenu != NULL) {
    org_kde_kwin_appmenu_release(g_appmenu);
    g_appmenu = NULL;
  }
}

const char* linux_app_menu_clear(void) {
  if (!on_main_thread()) {
    return "error:not_main_thread";
  }
  release_appmenu();
  return "ok";
}

const char* linux_app_menu_set_address(const char* service_name,
                                       const char* object_path) {
  if (!on_main_thread()) {
    return "error:not_main_thread";
  }
  GtkWindow* window = find_flutter_window();
  if (window == NULL) {
    return "error:no_native_window";
  }
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (!GDK_IS_WAYLAND_DISPLAY(display)) {
    return "error:not_wayland";
  }
  if (!ensure_initialized(display)) {
    return "error:appmenu_manager_not_available";
  }

  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window == NULL || !GDK_IS_WAYLAND_WINDOW(gdk_window)) {
    return "error:no_wayland_surface";
  }
  struct wl_surface* surface = gdk_wayland_window_get_wl_surface(gdk_window);
  if (surface == NULL) {
    return "error:no_wayland_surface";
  }

  release_appmenu();
  g_appmenu = org_kde_kwin_appmenu_manager_create(g_manager, surface);
  if (g_appmenu == NULL) {
    return "error:appmenu_create_failed";
  }
  org_kde_kwin_appmenu_set_address(g_appmenu, service_name, object_path);
  wl_display_flush(gdk_wayland_display_get_wl_display(display));
  return "ok";
}
