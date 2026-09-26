#include "include/kde_color_scheme/kde_color_scheme_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>

#include "kde_color_scheme_wayland.h"

#define KDE_COLOR_SCHEME_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), kde_color_scheme_plugin_get_type(), \
                              KdeColorSchemePlugin))

struct _KdeColorSchemePlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
};

G_DEFINE_TYPE(KdeColorSchemePlugin,
              kde_color_scheme_plugin,
              g_object_get_type())

namespace {

GtkWindow* get_window(KdeColorSchemePlugin* self) {
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

void handle_method_call(KdeColorSchemePlugin* self,
                        FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "Palette.set") == 0) {
    FlValue* arguments = fl_method_call_get_args(method_call);
    FlValue* path = arguments == nullptr
                        ? nullptr
                        : fl_value_lookup_string(arguments, "path");
    GtkWindow* window = get_window(self);
    if (window == nullptr) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "error:no_native_window", "No native GTK window.", nullptr));
    } else if (path == nullptr ||
               fl_value_get_type(path) != FL_VALUE_TYPE_STRING) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "error:invalid_path", "Expected a color scheme path.", nullptr));
    } else {
      response = result_response(kde_color_scheme_wayland_set_palette(
          window, fl_value_get_string(path)));
    }
  } else if (strcmp(method, "Palette.reset") == 0) {
    kde_color_scheme_wayland_reset();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

void method_call_cb(FlMethodChannel*, FlMethodCall* method_call,
                    gpointer user_data) {
  handle_method_call(KDE_COLOR_SCHEME_PLUGIN(user_data), method_call);
}

}  // namespace

static void kde_color_scheme_plugin_dispose(GObject* object) {
  KdeColorSchemePlugin* self = KDE_COLOR_SCHEME_PLUGIN(object);
  kde_color_scheme_wayland_reset();
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(kde_color_scheme_plugin_parent_class)->dispose(object);
}

static void kde_color_scheme_plugin_class_init(
    KdeColorSchemePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = kde_color_scheme_plugin_dispose;
}

static void kde_color_scheme_plugin_init(KdeColorSchemePlugin*) {}

void kde_color_scheme_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  KdeColorSchemePlugin* plugin = KDE_COLOR_SCHEME_PLUGIN(
      g_object_new(kde_color_scheme_plugin_get_type(), nullptr));
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "dev.klutter/kde_color_scheme", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);
  g_object_unref(plugin);
}
