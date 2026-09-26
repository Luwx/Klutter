import 'dart:async';

import 'package:dbus/dbus.dart';

const _interface = 'com.canonical.dbusmenu';
const _objectPath = '/dev/klutter/LinuxAppMenu';

final class DbusMenuAddress {
  const DbusMenuAddress(this.serviceName, this.objectPath);

  final String serviceName;
  final String objectPath;
}

final class DbusMenuHost {
  DbusMenuHost({required void Function(int id) onActivate})
    : _object = DbusMenuObject(onActivate: onActivate);

  final DbusMenuObject _object;
  late final Future<DbusMenuAddress> address = _connect();

  Future<DbusMenuAddress> _connect() async {
    final client = DBusClient.session();
    await client.registerObject(_object);
    return DbusMenuAddress(client.uniqueName, _objectPath);
  }

  void update(List<Map<String, Object?>> menus) {
    _object.update(menus);
  }
}

/// DBusMenu protocol object. Public for protocol-level tests.
final class DbusMenuObject extends DBusObject {
  DbusMenuObject({required this.onActivate})
    : super(DBusObjectPath(_objectPath));

  final void Function(int id) onActivate;
  List<Map<String, Object?>> _menus = const <Map<String, Object?>>[];
  Map<int, Map<String, Object?>> _items = <int, Map<String, Object?>>{};
  int _revision = 0;

  void update(List<Map<String, Object?>> menus) {
    _menus = menus;
    _items = <int, Map<String, Object?>>{};
    for (final item in menus) {
      _index(item);
    }
    _revision++;
    unawaited(
      emitSignal(_interface, 'LayoutUpdated', <DBusValue>[
        DBusUint32(_revision),
        const DBusInt32(0),
      ]),
    );
  }

  void _index(Map<String, Object?> item) {
    final id = item['id'];
    if (id is int) {
      _items[id] = item;
    }
    for (final child in (item['children'] as List<Object?>?) ?? const []) {
      _index((child! as Map<Object?, Object?>).cast<String, Object?>());
    }
  }

  Map<String, DBusValue> _properties(Map<String, Object?> item) {
    final properties = <String, DBusValue>{
      'visible': const DBusBoolean(true),
      'enabled': DBusBoolean(item['enabled'] == true),
    };
    if (item['isDivider'] == true) {
      properties['type'] = const DBusString('separator');
      final label = item['label'];
      if (label is String && label.isNotEmpty) {
        properties['label'] = DBusString(label);
      }
      final iconName = item['iconName'];
      if (iconName is String && iconName.isNotEmpty) {
        properties['icon-name'] = DBusString(iconName);
      }
      return properties;
    }
    properties['label'] = DBusString((item['label'] as String?) ?? '');
    final iconName = item['iconName'];
    if (iconName is String && iconName.isNotEmpty) {
      properties['icon-name'] = DBusString(iconName);
    }
    if (item['children'] is List<Object?>) {
      properties['children-display'] = const DBusString('submenu');
    }
    final toggleType = item['toggleType'];
    if (toggleType is String) {
      properties['toggle-type'] = DBusString(toggleType);
      properties['toggle-state'] = DBusInt32(
        (item['toggleState'] as int?) ?? 0,
      );
    }
    final shortcut = _shortcut(item);
    if (shortcut != null) {
      properties['shortcut'] = shortcut;
    }
    return properties;
  }

  DBusValue? _shortcut(Map<String, Object?> item) {
    final serializedCharacter = item['shortcutCharacter'];
    final serializedTrigger = item['shortcutTrigger'];
    final character = switch ((serializedCharacter, serializedTrigger)) {
      (final String character, _) => character,
      (_, final int trigger) when trigger > 0 && trigger <= 0x10ffff =>
        String.fromCharCode(trigger),
      (_, 0x00100000008) => 'Backspace',
      (_, 0x00100000009) => 'Tab',
      (_, 0x0010000000d) => 'Enter',
      (_, 0x0010000001b) => 'Escape',
      (_, 0x0010000007f) => 'Delete',
      _ => null,
    };
    if (character == null) {
      return null;
    }
    final modifiers = (item['shortcutModifiers'] as int?) ?? 0;
    final parts = <String>[
      if ((modifiers & (1 << 3)) != 0) 'Control',
      if ((modifiers & (1 << 2)) != 0) 'Alt',
      if ((modifiers & (1 << 1)) != 0) 'Shift',
      if ((modifiers & (1 << 0)) != 0) 'Super',
      character.toUpperCase(),
    ];
    return DBusArray(DBusSignature('as'), <DBusValue>[DBusArray.string(parts)]);
  }

  Map<String, Object?>? _item(int id) {
    if (id != 0) {
      return _items[id];
    }
    return <String, Object?>{'id': 0, 'enabled': true, 'children': _menus};
  }

  DBusStruct _layout(
    Map<String, Object?> item,
    int depth,
    Set<String> requestedProperties,
  ) {
    var properties = _properties(item);
    if (requestedProperties.isNotEmpty) {
      properties = Map<String, DBusValue>.fromEntries(
        properties.entries.where(
          (entry) => requestedProperties.contains(entry.key),
        ),
      );
    }
    final children = depth == 0
        ? const <DBusValue>[]
        : <DBusValue>[
            for (final child
                in (item['children'] as List<Object?>?) ?? const <Object?>[])
              _layout(
                (child! as Map<Object?, Object?>).cast<String, Object?>(),
                depth < 0 ? -1 : depth - 1,
                requestedProperties,
              ),
          ];
    return DBusStruct(<DBusValue>[
      DBusInt32(item['id']! as int),
      DBusDict.stringVariant(properties),
      DBusArray.variant(children),
    ]);
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface != _interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final value = switch (name) {
      'Version' => const DBusUint32(3),
      'TextDirection' => const DBusString('ltr'),
      'Status' => const DBusString('normal'),
      'IconThemePath' => DBusArray.string(const <String>[]),
      _ => null,
    };
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface != _interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    return DBusGetAllPropertiesResponse(<String, DBusValue>{
      'Version': const DBusUint32(3),
      'TextDirection': const DBusString('ltr'),
      'Status': const DBusString('normal'),
      'IconThemePath': DBusArray.string(const <String>[]),
    });
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != _interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (methodCall.name) {
      case 'GetLayout':
        final id = methodCall.values[0].asInt32();
        final depth = methodCall.values[1].asInt32();
        final requested = methodCall.values[2]
            .asArray()
            .map((value) => value.asString())
            .toSet();
        final item = _item(id);
        if (item == null) {
          return DBusMethodErrorResponse.invalidArgs('Unknown menu item $id');
        }
        return DBusMethodSuccessResponse(<DBusValue>[
          DBusUint32(_revision),
          _layout(item, depth, requested),
        ]);
      case 'GetGroupProperties':
        final ids = methodCall.values[0].asArray().map(
          (value) => value.asInt32(),
        );
        final requested = methodCall.values[1]
            .asArray()
            .map((value) => value.asString())
            .toSet();
        final values = <DBusValue>[];
        for (final id in ids) {
          final item = _item(id);
          if (item == null) {
            continue;
          }
          var properties = _properties(item);
          if (requested.isNotEmpty) {
            properties.removeWhere((name, _) => !requested.contains(name));
          }
          values.add(
            DBusStruct(<DBusValue>[
              DBusInt32(id),
              DBusDict.stringVariant(properties),
            ]),
          );
        }
        return DBusMethodSuccessResponse(<DBusValue>[
          DBusArray(DBusSignature('(ia{sv})'), values),
        ]);
      case 'GetProperty':
        final item = _item(methodCall.values[0].asInt32());
        final name = methodCall.values[1].asString();
        final value = item == null ? null : _properties(item)[name];
        return DBusMethodSuccessResponse(<DBusValue>[
          DBusVariant(value ?? const DBusString('')),
        ]);
      case 'Event':
        _handleEvent(
          methodCall.values[0].asInt32(),
          methodCall.values[1].asString(),
        );
        return DBusMethodSuccessResponse();
      case 'EventGroup':
        for (final event in methodCall.values[0].asArray()) {
          final fields = event.asStruct();
          _handleEvent(fields[0].asInt32(), fields[1].asString());
        }
        return DBusMethodSuccessResponse(<DBusValue>[
          DBusArray.int32(const <int>[]),
        ]);
      case 'AboutToShow':
        return DBusMethodSuccessResponse(<DBusValue>[const DBusBoolean(false)]);
      case 'AboutToShowGroup':
        return DBusMethodSuccessResponse(<DBusValue>[
          DBusArray.int32(const <int>[]),
          DBusArray.int32(const <int>[]),
        ]);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  void _handleEvent(int id, String event) {
    if (event == 'clicked' && _items.containsKey(id)) {
      onActivate(id);
    }
  }
}
