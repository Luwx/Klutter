import 'dart:async';
import 'dart:io';

import 'kde_color_scheme.dart';
import 'kdeglobals_parser.dart';

/// Reads and watches the kdeglobals file, emitting a new [KdeColorScheme]
/// whenever KDE rewrites the file (e.g. when the user changes the color scheme
/// in System Settings).
///
/// KDE does an atomic rename-replace of kdeglobals, so we watch the parent
/// directory via inotify and filter for events on the kdeglobals filename.
///
/// Usage:
/// ```dart
/// final watcher = KdeColorSchemeWatcher();
/// final current = watcher.current;              // synchronous read
/// watcher.stream.listen((scheme) { ... });      // real-time updates
/// // ...
/// watcher.dispose();
/// ```
class KdeColorSchemeWatcher {
  KdeColorSchemeWatcher({String? path})
    : _path = path ?? KdeglobalsParser.defaultPath;

  final String _path;

  StreamController<KdeColorScheme>? _controller;
  StreamSubscription<FileSystemEvent>? _watchSub;

  /// Synchronously reads and parses the current scheme.
  /// Returns [KdeColorScheme.fallback] if the file is missing or unparseable.
  KdeColorScheme get current =>
      KdeglobalsParser.parseFile(_path) ?? KdeColorScheme.fallback;

  /// Broadcast stream that emits every time the color scheme changes on disk.
  /// The first event is NOT emitted automatically — call [current] for the
  /// initial value and subscribe to [stream] for subsequent changes.
  Stream<KdeColorScheme> get stream {
    final ctrl = _controller ??= StreamController<KdeColorScheme>.broadcast(
      onListen: _startWatching,
      onCancel: _stopWatching,
    );
    return ctrl.stream;
  }

  void _startWatching() {
    // The parent dir of kdeglobals (typically ~/.config).
    final dirPath = _parentDir(_path);
    final filename = _basename(_path);
    final dir = Directory(dirPath);

    if (!dir.existsSync()) return;

    _watchSub = dir
        .watch(events: FileSystemEvent.all)
        .where((e) => _basename(e.path) == filename)
        .listen((_) => _reload());
  }

  void _reload() {
    final scheme = KdeglobalsParser.parseFile(_path);
    if (scheme != null) _controller?.add(scheme);
  }

  void _stopWatching() {
    _watchSub?.cancel();
    _watchSub = null;
  }

  void dispose() {
    _stopWatching();
    _controller?.close();
    _controller = null;
  }

  // Avoids a `path` package dependency for a simple Linux-only use case.
  static String _parentDir(String p) {
    final idx = p.lastIndexOf('/');
    return idx > 0 ? p.substring(0, idx) : '/';
  }

  static String _basename(String p) {
    final idx = p.lastIndexOf('/');
    return idx >= 0 ? p.substring(idx + 1) : p;
  }
}
