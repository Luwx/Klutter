#pragma once

#include <gtk/gtk.h>

G_BEGIN_DECLS

gchar* linux_app_menu_wayland_set_address(GtkWindow* window,
                                          const gchar* service_name,
                                          const gchar* object_path);
void linux_app_menu_wayland_clear(void);

G_END_DECLS
