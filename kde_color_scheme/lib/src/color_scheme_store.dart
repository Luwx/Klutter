import 'dart:io';

/// Writes generated color schemes where KWin can read them.
///
/// Files live in the session runtime directory: it is private to the user,
/// kept in memory, and cleared at logout.
///
/// - Flatpak: `$XDG_RUNTIME_DIR/app/$FLATPAK_ID`, the only part of the
///   sandbox's runtime directory that is shared with the host at the same path.
/// - Otherwise: `$XDG_RUNTIME_DIR/<executable name>`. Snap already scopes
///   `XDG_RUNTIME_DIR` to a host-visible directory.
/// - Without `XDG_RUNTIME_DIR`: `$XDG_CACHE_HOME/<app id>`.
///
/// Each file is named `titlebar-<owner>-<hash>.colors`. KWin ignores a path it
/// has already been given, so new content needs a new name. The owner keeps
/// several running instances apart and lets stale files be found later.
class ColorSchemeStore {
  ColorSchemeStore({
    Map<String, String>? environment,
    int? processId,
    String? executable,
    String? flatpakInfoPath,
    bool Function(int pid)? isProcessAlive,
  }) : _environment = environment ?? Platform.environment,
       _processId = processId ?? pid,
       _executable = executable ?? Platform.resolvedExecutable,
       _flatpakInfoPath = flatpakInfoPath ?? '/.flatpak-info',
       _isProcessAlive = isProcessAlive ?? _procExists;

  final Map<String, String> _environment;
  final int _processId;
  final String _executable;
  final String _flatpakInfoPath;
  final bool Function(int pid) _isProcessAlive;

  static final RegExp _hostFilePattern = RegExp(
    r'^\.?titlebar-(\d+)-[0-9a-f]+\.colors(\.tmp)?$',
  );

  String? get _flatpakId {
    final id = _environment['FLATPAK_ID'];
    return id == null || id.isEmpty ? null : id;
  }

  /// The directory the schemes are written to.
  Directory get directory {
    final runtimeDir = _environment['XDG_RUNTIME_DIR'];
    final flatpakId = _flatpakId;
    if (runtimeDir != null && runtimeDir.isNotEmpty) {
      return flatpakId != null
          ? Directory('$runtimeDir/app/$flatpakId')
          : Directory('$runtimeDir/${_basename(_executable)}');
    }
    final cacheHome = _environment['XDG_CACHE_HOME'];
    final base = cacheHome != null && cacheHome.isNotEmpty
        ? cacheHome
        : '${_environment['HOME'] ?? ''}/.cache';
    return Directory('$base/${flatpakId ?? _basename(_executable)}');
  }

  /// Identifies this process in file names.
  ///
  /// Flatpak runs each instance in its own PID namespace, where PIDs repeat
  /// across instances, so the Flatpak instance id is used there instead.
  late final String owner = () {
    if (_flatpakId == null) {
      return '$_processId';
    }
    final instanceId = _readFlatpakInstanceId();
    return instanceId != null ? 'i$instanceId' : 'p$_processId';
  }();

  /// Writes [contents] and returns the file. The file is written under a
  /// temporary name first so KWin never reads a partial scheme.
  Future<File> write(String contents) async {
    final dir = directory;
    await dir.create(recursive: true);
    final name = 'titlebar-$owner-${_hash(contents)}.colors';
    final file = File('${dir.path}/$name');
    if (await file.exists()) {
      return file;
    }
    final temp = File('${dir.path}/.$name.tmp');
    await temp.writeAsString(contents, flush: true);
    return temp.rename(file.path);
  }

  /// Deletes [file], ignoring files that are already gone.
  Future<void> delete(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already removed, e.g. by a user cleaning the directory.
    }
  }

  /// Deletes files left behind by processes that are no longer running.
  ///
  /// Only possible outside Flatpak: the sandbox cannot see other instances'
  /// processes. Files left there are removed when the session ends.
  Future<void> removeStale() async {
    if (_flatpakId != null) {
      return;
    }
    final dir = directory;
    try {
      if (!await dir.exists()) {
        return;
      }
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final match = _hostFilePattern.firstMatch(_basename(entity.path));
        if (match == null) {
          continue;
        }
        final filePid = int.parse(match.group(1)!);
        if (filePid != _processId && !_isProcessAlive(filePid)) {
          await delete(entity);
        }
      }
    } on FileSystemException {
      // Cleanup is best effort.
    }
  }

  String? _readFlatpakInstanceId() {
    try {
      var inInstance = false;
      for (var line in File(_flatpakInfoPath).readAsLinesSync()) {
        line = line.trim();
        if (line.startsWith('[')) {
          inInstance = line == '[Instance]';
        } else if (inInstance && line.startsWith('instance-id=')) {
          final id = line.substring('instance-id='.length).trim();
          return RegExp(r'^[0-9]+$').hasMatch(id) ? id : null;
        }
      }
    } on FileSystemException {
      return null;
    }
    return null;
  }

  static bool _procExists(int pid) => Directory('/proc/$pid').existsSync();

  static String _basename(String path) {
    final idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  /// 64-bit FNV-1a, enough to give distinct content distinct names.
  static String _hash(String contents) {
    var hash = 0xcbf29ce484222325;
    for (final unit in contents.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    String half(int bits) => bits.toRadixString(16).padLeft(8, '0');
    return half((hash >> 32) & 0xFFFFFFFF) + half(hash & 0xFFFFFFFF);
  }
}
