#include "include/background_blur_linux/background_blur_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>
#include <vector>

#include "background_blur_linux_private.h"

#define BACKGROUND_BLUR_LINUX_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), background_blur_linux_plugin_get_type(), \
                              BackgroundBlurLinuxPlugin))

struct _BackgroundBlurLinuxPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;  // strong ref (released in dispose)
};

G_DEFINE_TYPE(BackgroundBlurLinuxPlugin, background_blur_linux_plugin, g_object_get_type())

static GtkWindow* get_window(BackgroundBlurLinuxPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr) {
    return nullptr;
  }
  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  if (toplevel == nullptr || !GTK_IS_WINDOW(toplevel)) {
    return nullptr;
  }
  return GTK_WINDOW(toplevel);
}

// Pulls a list of {x,y,w,h} maps from a Flutter argument value.
// Returns true on success and fills `out_rects`. If the argument is
// missing/null/empty, returns true with an empty vector.
static gboolean parse_rects(FlValue* args, std::vector<BackgroundBlurLinuxRect>* out_rects,
                            gchar** out_error) {
  out_rects->clear();
  if (args == nullptr || fl_value_get_type(args) == FL_VALUE_TYPE_NULL) {
    return TRUE;
  }
  if (fl_value_get_type(args) != FL_VALUE_TYPE_LIST) {
    *out_error = g_strdup("error:invalid_argument_type");
    return FALSE;
  }
  size_t n = fl_value_get_length(args);
  out_rects->reserve(n);
  for (size_t i = 0; i < n; i++) {
    FlValue* item = fl_value_get_list_value(args, i);
    if (item == nullptr || fl_value_get_type(item) != FL_VALUE_TYPE_MAP) {
      *out_error = g_strdup("error:invalid_rect");
      return FALSE;
    }
    FlValue* xv = fl_value_lookup_string(item, "x");
    FlValue* yv = fl_value_lookup_string(item, "y");
    FlValue* wv = fl_value_lookup_string(item, "w");
    FlValue* hv = fl_value_lookup_string(item, "h");
    if (xv == nullptr || yv == nullptr || wv == nullptr || hv == nullptr) {
      *out_error = g_strdup("error:invalid_rect");
      return FALSE;
    }
    BackgroundBlurLinuxRect r;
    r.x = static_cast<int32_t>(fl_value_get_int(xv));
    r.y = static_cast<int32_t>(fl_value_get_int(yv));
    r.width = static_cast<int32_t>(fl_value_get_int(wv));
    r.height = static_cast<int32_t>(fl_value_get_int(hv));
    out_rects->push_back(r);
  }
  return TRUE;
}

static FlMethodResponse* respond_string(gchar* str_owned) {
  g_autoptr(FlValue) v = fl_value_new_string(str_owned != nullptr ? str_owned : "ok");
  g_free(str_owned);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(v));
}

static FlMethodResponse* handle_enable(BackgroundBlurLinuxPlugin* self, FlValue* args) {
  std::vector<BackgroundBlurLinuxRect> rects;
  gchar* err = nullptr;
  if (!parse_rects(args, &rects, &err)) {
    return respond_string(err);
  }

  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return respond_string(g_strdup("error:no_native_window"));
  }

  gchar* result =
      background_blur_linux_wayland_enable(window, rects.data(), rects.size());
  return respond_string(result);
}

static FlMethodResponse* handle_disable(BackgroundBlurLinuxPlugin* self) {
  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return respond_string(g_strdup("error:no_native_window"));
  }
  gchar* result = background_blur_linux_wayland_disable(window);
  return respond_string(result);
}

static void background_blur_linux_plugin_handle_method_call(BackgroundBlurLinuxPlugin* self,
                                               FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "enable") == 0) {
    response = handle_enable(self, args);
  } else if (strcmp(method, "disable") == 0) {
    response = handle_disable(self);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void background_blur_linux_plugin_dispose(GObject* object) {
  BackgroundBlurLinuxPlugin* self = BACKGROUND_BLUR_LINUX_PLUGIN(object);
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(background_blur_linux_plugin_parent_class)->dispose(object);
}

static void background_blur_linux_plugin_class_init(BackgroundBlurLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = background_blur_linux_plugin_dispose;
}

static void background_blur_linux_plugin_init(BackgroundBlurLinuxPlugin* self) {}

static void method_call_cb(FlMethodChannel* /*channel*/,
                           FlMethodCall* method_call, gpointer user_data) {
  BackgroundBlurLinuxPlugin* plugin = BACKGROUND_BLUR_LINUX_PLUGIN(user_data);
  background_blur_linux_plugin_handle_method_call(plugin, method_call);
}

void background_blur_linux_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  BackgroundBlurLinuxPlugin* plugin =
      BACKGROUND_BLUR_LINUX_PLUGIN(g_object_new(background_blur_linux_plugin_get_type(), nullptr));
  // Keep the registrar alive for the lifetime of the plugin so that
  // fl_plugin_registrar_get_view() remains valid when method calls arrive.
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));
  // This plugin only supports Wayland. Under an X11 session the Wayland backend
  // returns "error:not_wayland" from every call.

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "background_blur_linux", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
