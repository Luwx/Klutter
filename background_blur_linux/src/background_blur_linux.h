#pragma once

#include <stddef.h>
#include <stdint.h>

#define BACKGROUND_BLUR_LINUX_EXPORT __attribute__((visibility("default")))

// A rectangle in surface-local logical pixels.
typedef struct {
  int32_t x;
  int32_t y;
  int32_t width;
  int32_t height;
} BackgroundBlurLinuxRect;

// Functions return "ok" or "error:<code>". The strings are static; do not free
// them. They must be called on the GTK main thread, which is where Flutter
// runs Dart by default.

// Blurs the given region behind the Flutter window. With no rectangles the
// whole window is blurred, following it across resizes.
BACKGROUND_BLUR_LINUX_EXPORT const char* background_blur_linux_enable(
    const BackgroundBlurLinuxRect* rects,
    size_t n_rects);

// Removes the blur.
BACKGROUND_BLUR_LINUX_EXPORT const char* background_blur_linux_disable(void);
