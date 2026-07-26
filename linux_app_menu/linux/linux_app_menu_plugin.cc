#include "include/linux_app_menu/linux_app_menu_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>

#include "linux_app_menu_wayland.h"

#define LINUX_APP_MENU_PLUGIN(obj)                                      \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), linux_app_menu_plugin_get_type(),  \
                              LinuxAppMenuPlugin))

struct _LinuxAppMenuPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
};

G_DEFINE_TYPE(LinuxAppMenuPlugin, linux_app_menu_plugin, g_object_get_type())

namespace {

GtkWindow* get_window(LinuxAppMenuPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr) {
    return nullptr;
  }
  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  return toplevel != nullptr && GTK_IS_WINDOW(toplevel)
             ? GTK_WINDOW(toplevel)
             : nullptr;
}

FlMethodResponse* result_response(gchar* result) {
  if (result == nullptr || strcmp(result, "ok") == 0) {
    g_free(result);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  g_autofree gchar* owned_result = result;
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(result, result, nullptr));
}

void handle_method_call(LinuxAppMenuPlugin* self,
                        FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "Menu.setAddress") == 0) {
    FlValue* arguments = fl_method_call_get_args(method_call);
    FlValue* service = arguments == nullptr
                           ? nullptr
                           : fl_value_lookup_string(arguments, "serviceName");
    FlValue* path = arguments == nullptr
                        ? nullptr
                        : fl_value_lookup_string(arguments, "objectPath");
    GtkWindow* window = get_window(self);
    if (window == nullptr) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "error:no_native_window", "No native GTK window.", nullptr));
    } else if (service == nullptr || path == nullptr ||
               fl_value_get_type(service) != FL_VALUE_TYPE_STRING ||
               fl_value_get_type(path) != FL_VALUE_TYPE_STRING) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "error:invalid_address", "Expected a D-Bus service and path.",
          nullptr));
    } else {
      response = result_response(linux_app_menu_wayland_set_address(
          window, fl_value_get_string(service), fl_value_get_string(path)));
    }
  } else if (strcmp(method, "Menu.clear") == 0) {
    linux_app_menu_wayland_clear();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

void method_call_cb(FlMethodChannel*, FlMethodCall* method_call,
                    gpointer user_data) {
  handle_method_call(LINUX_APP_MENU_PLUGIN(user_data), method_call);
}

}  // namespace

static void linux_app_menu_plugin_dispose(GObject* object) {
  LinuxAppMenuPlugin* self = LINUX_APP_MENU_PLUGIN(object);
  linux_app_menu_wayland_clear();
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(linux_app_menu_plugin_parent_class)->dispose(object);
}

static void linux_app_menu_plugin_class_init(LinuxAppMenuPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = linux_app_menu_plugin_dispose;
}

static void linux_app_menu_plugin_init(LinuxAppMenuPlugin*) {}

void linux_app_menu_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  LinuxAppMenuPlugin* plugin = LINUX_APP_MENU_PLUGIN(
      g_object_new(linux_app_menu_plugin_get_type(), nullptr));
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "dev.klutter/linux_app_menu", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);
  g_object_unref(plugin);
}
