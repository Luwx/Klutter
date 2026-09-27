import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import 'linux_app_menu_bindings_generated.dart' as bindings;

/// Associates the Flutter window with an exported DBusMenu through KWin's
/// native Wayland AppMenu protocol.
///
/// Failures throw a [PlatformException] whose code is the native error, e.g.
/// `error:not_wayland`.
class AppMenuNative {
  const AppMenuNative();

  void setAddress(String serviceName, String objectPath) {
    using((arena) {
      _check(
        bindings.linux_app_menu_set_address(
          serviceName.toNativeUtf8(allocator: arena).cast(),
          objectPath.toNativeUtf8(allocator: arena).cast(),
        ),
      );
    });
  }

  void clear() => _check(bindings.linux_app_menu_clear());

  static void _check(Pointer<Char> result) {
    final status = result.cast<Utf8>().toDartString();
    if (status != 'ok') {
      throw PlatformException(code: status, message: 'linux_app_menu: $status');
    }
  }
}
