#ifndef FLUTTER_PLUGIN_KWIN_BLUR_PRIVATE_H_
#define FLUTTER_PLUGIN_KWIN_BLUR_PRIVATE_H_

#include <gtk/gtk.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  int32_t x;
  int32_t y;
  int32_t width;
  int32_t height;
} KwinBlurRect;

/*
 * All backend entry points share the same return-value convention:
 *   - On success the returned heap-allocated string is "ok".
 *   - On failure the returned string starts with "error:" and a tag,
 *     e.g. "error:no_native_window".
 * The caller is responsible for g_free'ing the result.
 */

char* kwin_blur_wayland_enable(GtkWindow* window,
                              const KwinBlurRect* rects,
                              size_t n_rects);
char* kwin_blur_wayland_disable(GtkWindow* window);

char* kwin_blur_x11_enable(GtkWindow* window,
                          const KwinBlurRect* rects,
                          size_t n_rects);
char* kwin_blur_x11_disable(GtkWindow* window);

#ifdef __cplusplus
}
#endif

#endif  // FLUTTER_PLUGIN_KWIN_BLUR_PRIVATE_H_
