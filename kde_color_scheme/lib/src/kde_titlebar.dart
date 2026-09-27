import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'color_scheme_store.dart';
import 'kde_color_scheme_bindings_generated.dart' as bindings;
import 'kdeglobals_parser.dart';
import 'titlebar_color_scheme.dart';

/// Controls the KWin title bar of the Flutter window on KDE Plasma (Wayland).
///
/// KWin's `org_kde_kwin_server_decoration_palette` protocol only accepts the
/// path of a KDE color scheme, so custom colors are written to a generated
/// `.colors` file that KWin reads.
abstract final class KdeTitlebar {
  /// Error codes returned when the session cannot apply decoration palettes.
  static const Set<String> _unsupportedCodes = {
    'error:not_wayland',
    'error:palette_manager_not_available',
  };

  static final ColorSchemeStore _store = ColorSchemeStore();
  static Future<void> _queue = Future<void>.value();
  static bool _staleRemoved = false;
  static File? _current;

  /// Whether this package can run on the current target platform.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Asks KWin to paint the title bar with [background] and [foreground].
  ///
  /// The inactive colors default to the active ones. Other decoration colors,
  /// such as the outline and button hover colors, follow the current system
  /// color scheme at the time of the call.
  ///
  /// Returns false when the session does not support it: not Linux, not
  /// Wayland, or a compositor without the KDE decoration palette protocol.
  /// Throws a [PlatformException] for other failures.
  ///
  /// The window does not need to be shown yet; the colors are applied when it
  /// is mapped. KWin may still ignore them, e.g. when a window rule forces a
  /// color scheme or the window uses client-side decorations.
  static Future<bool> setTitlebarColors({
    required Color background,
    required Color foreground,
    Color? inactiveBackground,
    Color? inactiveForeground,
  }) {
    final colors = TitlebarColors(
      background: background,
      foreground: foreground,
      inactiveBackground: inactiveBackground,
      inactiveForeground: inactiveForeground,
    );
    return _enqueue(() => _apply(colors));
  }

  /// Returns the title bar to the system color scheme.
  static Future<void> resetTitlebarColors() => _enqueue(() async {
    if (!isSupported) {
      return;
    }
    _check(bindings.kde_color_scheme_reset_palette());
    final current = _current;
    _current = null;
    if (current != null) {
      await _store.delete(current);
    }
  });

  static Future<bool> _apply(TitlebarColors colors) async {
    if (!isSupported) {
      return false;
    }
    if (!_staleRemoved) {
      _staleRemoved = true;
      await _store.removeStale();
    }

    final contents = buildTitlebarColorScheme(
      colors,
      base: await _readKdeglobals(),
    );
    final file = await _store.write(contents);
    final previous = _current;
    if (previous?.path == file.path) {
      return true;
    }

    try {
      using((arena) {
        final path = file.path.toNativeUtf8(allocator: arena);
        _check(bindings.kde_color_scheme_set_palette(path.cast()));
      });
    } on PlatformException catch (error) {
      await _store.delete(file);
      if (_unsupportedCodes.contains(error.code)) {
        return false;
      }
      rethrow;
    }

    // The window now points KWin at the new file; the old one is unused.
    _current = file;
    if (previous != null) {
      await _store.delete(previous);
    }
    return true;
  }

  /// Throws a [PlatformException] with the code of a native error result.
  static void _check(Pointer<Char> result) {
    final status = result.cast<Utf8>().toDartString();
    if (status != 'ok') {
      throw PlatformException(
        code: status,
        message: 'kde_color_scheme: $status',
      );
    }
  }

  static Future<String?> _readKdeglobals() async {
    try {
      return await File(KdeglobalsParser.defaultPath).readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// Runs calls one at a time so files are never deleted while KWin may still
  /// be switching to them.
  static Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}
