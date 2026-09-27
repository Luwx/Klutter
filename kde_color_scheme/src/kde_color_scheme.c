#include "kde_color_scheme.h"

#include <gdk/gdkwayland.h>
#include <gtk/gtk.h>
#include <string.h>
#include <wayland-client.h>

#include "server-decoration-palette-protocol.h"

static struct org_kde_kwin_server_decoration_palette_manager* g_manager = NULL;
static struct org_kde_kwin_server_decoration_palette* g_palette = NULL;
static struct wl_surface* g_palette_surface = NULL;
static gchar* g_path = NULL;
static GtkWindow* g_window = NULL;
static gulong g_map_handler = 0;
static gboolean g_init_attempted = FALSE;

static void registry_global(void* data,
                            struct wl_registry* registry,
                            uint32_t name,
                            const char* interface,
                            uint32_t version) {
  (void)data;
  (void)version;
  if (strcmp(interface, "org_kde_kwin_server_decoration_palette_manager") ==
      0) {
    g_manager = wl_registry_bind(
        registry, name,
        &org_kde_kwin_server_decoration_palette_manager_interface, 1);
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

static void release_palette(void) {
  if (g_palette != NULL) {
    org_kde_kwin_server_decoration_palette_release(g_palette);
    g_palette = NULL;
  }
  g_palette_surface = NULL;
}

static struct wl_surface* window_surface(GtkWindow* window) {
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window == NULL || !GDK_IS_WAYLAND_WINDOW(gdk_window)) {
    return NULL;
  }
  return gdk_wayland_window_get_wl_surface(gdk_window);
}

// Sends the pending path for the window's current surface. GDK creates the
// wl_surface when the window is mapped and destroys it when it is hidden, so
// the palette object is recreated whenever the surface changes.
static gboolean apply_palette(GtkWindow* window) {
  struct wl_surface* surface = window_surface(window);
  if (surface == NULL || g_path == NULL) {
    return FALSE;
  }
  if (g_palette != NULL && g_palette_surface != surface) {
    release_palette();
  }
  if (g_palette == NULL) {
    g_palette = org_kde_kwin_server_decoration_palette_manager_create(
        g_manager, surface);
    if (g_palette == NULL) {
      return FALSE;
    }
    g_palette_surface = surface;
  }
  org_kde_kwin_server_decoration_palette_set_palette(g_palette, g_path);
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  wl_display_flush(gdk_wayland_display_get_wl_display(display));
  return TRUE;
}

static void window_mapped(GtkWidget* widget, gpointer user_data) {
  (void)user_data;
  apply_palette(GTK_WINDOW(widget));
}

static void track_window(GtkWindow* window) {
  if (g_window == window) {
    return;
  }
  if (g_window != NULL) {
    g_signal_handler_disconnect(g_window, g_map_handler);
    g_object_remove_weak_pointer(G_OBJECT(g_window), (gpointer*)&g_window);
  }
  g_window = window;
  g_object_add_weak_pointer(G_OBJECT(g_window), (gpointer*)&g_window);
  g_map_handler = g_signal_connect_after(g_window, "map",
                                         G_CALLBACK(window_mapped), NULL);
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

const char* kde_color_scheme_reset_palette(void) {
  if (!on_main_thread()) {
    return "error:not_main_thread";
  }
  release_palette();
  g_clear_pointer(&g_path, g_free);
  if (g_window != NULL) {
    GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(g_window));
    if (GDK_IS_WAYLAND_DISPLAY(display)) {
      wl_display_flush(gdk_wayland_display_get_wl_display(display));
    }
  }
  return "ok";
}

const char* kde_color_scheme_set_palette(const char* path) {
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
    return "error:palette_manager_not_available";
  }

  g_free(g_path);
  g_path = g_strdup(path);
  track_window(window);

  // An unmapped window has no surface yet; the map handler applies the path.
  if (window_surface(window) != NULL && !apply_palette(window)) {
    return "error:palette_create_failed";
  }
  return "ok";
}
