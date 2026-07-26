import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'dbus_menu.dart';

final class LinuxAppMenuDelegate extends PlatformMenuDelegate {
  LinuxAppMenuDelegate({required this.channel});

  final MethodChannel channel;
  final Map<int, PlatformMenuItem> _items = <int, PlatformMenuItem>{};
  late final DbusMenuHost _host = DbusMenuHost(onActivate: _activate);

  int _serial = 0;
  int _generation = 0;
  BuildContext? _lockedContext;

  int _getId(PlatformMenuItem item) {
    final id = ++_serial;
    _items[id] = item;
    return id;
  }

  @override
  void clearMenus() {
    _items.clear();
    _host.update(const <Map<String, Object?>>[]);
    final generation = ++_generation;
    unawaited(_clearNative(generation));
  }

  @override
  void setMenus(List<PlatformMenuItem> topLevelMenus) {
    _items.clear();
    final representation = <Map<String, Object?>>[
      for (final item in topLevelMenus)
        ...item.toChannelRepresentation(this, getId: _getId),
    ];
    _host.update(representation);
    final generation = ++_generation;
    unawaited(_publish(generation));
  }

  Future<void> _publish(int generation) async {
    try {
      final address = await _host.address;
      if (generation != _generation) {
        return;
      }
      await channel.invokeMethod<void>('Menu.setAddress', <String, String>{
        'serviceName': address.serviceName,
        'objectPath': address.objectPath,
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'linux_app_menu',
          context: ErrorDescription(
            'while publishing the KDE application menu',
          ),
        ),
      );
    }
  }

  Future<void> _clearNative(int generation) async {
    await _host.address;
    if (generation == _generation) {
      await channel.invokeMethod<void>('Menu.clear');
    }
  }

  void _activate(int id) {
    final item = _items[id];
    if (item == null) {
      return;
    }
    item.onSelected?.call();
    final intent = item.onSelectedIntent;
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (intent != null && focusContext != null) {
      Actions.maybeInvoke(focusContext, intent);
    }
  }

  @override
  bool debugLockDelegate(BuildContext context) {
    assert(() {
      if (_lockedContext != null && _lockedContext != context) {
        return false;
      }
      _lockedContext = context;
      return true;
    }());
    return true;
  }

  @override
  bool debugUnlockDelegate(BuildContext context) {
    assert(() {
      if (_lockedContext != null && _lockedContext != context) {
        return false;
      }
      _lockedContext = null;
      return true;
    }());
    return true;
  }
}
