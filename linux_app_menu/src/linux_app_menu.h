#pragma once

#define LINUX_APP_MENU_EXPORT __attribute__((visibility("default")))

// Functions return "ok" or "error:<code>". The strings are static; do not free
// them. They must be called on the GTK main thread, which is where Flutter
// runs Dart by default.

// Associates the Flutter window with the DBusMenu exported at `service_name`
// and `object_path` through KWin's AppMenu protocol.
LINUX_APP_MENU_EXPORT const char* linux_app_menu_set_address(
    const char* service_name,
    const char* object_path);

// Removes the window's menu association.
LINUX_APP_MENU_EXPORT const char* linux_app_menu_clear(void);
