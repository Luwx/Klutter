#pragma once

#include <gtk/gtk.h>

G_BEGIN_DECLS

gchar* kde_color_scheme_wayland_set_palette(GtkWindow* window,
                                            const gchar* path);
void kde_color_scheme_wayland_reset(void);

G_END_DECLS
