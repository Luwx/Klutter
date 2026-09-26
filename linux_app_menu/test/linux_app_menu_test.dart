import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linux_app_menu/linux_app_menu.dart';
import 'package:linux_app_menu/src/dbus_menu.dart';

void main() {
  test('serializes section, checkbox, radio, and submenu state', () {
    const delegate = _TestMenuDelegate();
    var nextId = 0;
    int getId(PlatformMenuItem _) => ++nextId;

    final section = const LinuxMenuSection(
      label: 'Gesture',
      iconName: 'input-mouse',
    ).toChannelRepresentation(delegate, getId: getId).single;
    final checkbox = LinuxCheckMenuItem(
      label: 'Feature',
      checked: true,
      enabled: false,
      onSelected: () {},
    ).toChannelRepresentation(delegate, getId: getId).single;
    final radio = LinuxRadioMenuItem(
      label: 'Theme',
      selected: true,
      onSelected: () {},
    ).toChannelRepresentation(delegate, getId: getId).single;
    final submenu = LinuxSubmenu(
      label: 'Advanced',
      enabled: false,
      menus: <PlatformMenuItem>[
        LinuxMenuItem(label: 'Action', onSelected: () {}),
      ],
    ).toChannelRepresentation(delegate, getId: getId).single;

    expect(section, containsPair('isDivider', true));
    expect(section, containsPair('label', 'Gesture'));
    expect(section, containsPair('iconName', 'input-mouse'));
    expect(section, containsPair('enabled', false));
    expect(checkbox, containsPair('toggleType', 'checkmark'));
    expect(checkbox, containsPair('toggleState', 1));
    expect(checkbox, containsPair('enabled', false));
    expect(radio, containsPair('toggleType', 'radio'));
    expect(radio, containsPair('toggleState', 1));
    expect(submenu, containsPair('enabled', false));
  });

  test('exports menu layout and dispatches clicked events', () async {
    var selectedId = 0;
    final menu = DbusMenuObject(onActivate: (id) => selectedId = id);
    menu.update(<Map<String, Object?>>[
      <String, Object?>{
        'id': 1,
        'label': 'File',
        'enabled': true,
        'children': <Map<String, Object?>>[
          <String, Object?>{
            'id': 2,
            'label': 'Open',
            'enabled': true,
            'shortcutCharacter': 'o',
            'shortcutModifiers': 1 << 3,
          },
          <String, Object?>{
            'id': 3,
            'isDivider': true,
            'label': 'Gesture',
            'iconName': 'input-mouse',
          },
          <String, Object?>{
            'id': 4,
            'label': 'Selected theme',
            'enabled': true,
            'toggleType': 'radio',
            'toggleState': 1,
          },
        ],
      },
    ]);

    final layoutResponse = await menu.handleMethodCall(
      DBusMethodCall(
        sender: ':1.1',
        interface: 'com.canonical.dbusmenu',
        name: 'GetLayout',
        values: <DBusValue>[
          const DBusInt32(0),
          const DBusInt32(-1),
          DBusArray.string(const <String>[]),
        ],
      ),
    );
    expect(layoutResponse, isA<DBusMethodSuccessResponse>());
    final layout = (layoutResponse as DBusMethodSuccessResponse).returnValues[1]
        .asStruct();
    final topLevel = layout[2].asArray().single.asVariant().asStruct();
    final fileChildren = topLevel[2].asArray();
    expect(fileChildren, hasLength(3));

    final propertiesResponse = await menu.handleMethodCall(
      DBusMethodCall(
        sender: ':1.1',
        interface: 'com.canonical.dbusmenu',
        name: 'GetGroupProperties',
        values: <DBusValue>[
          DBusArray.int32(const <int>[3, 4]),
          DBusArray.string(const <String>[]),
        ],
      ),
    );
    final propertyEntries = (propertiesResponse as DBusMethodSuccessResponse)
        .returnValues
        .single
        .asArray();
    final sectionProperties = (propertyEntries[0].asStruct()[1] as DBusDict)
        .mapStringVariant();
    final radioProperties = (propertyEntries[1].asStruct()[1] as DBusDict)
        .mapStringVariant();
    expect(sectionProperties['type']?.asString(), 'separator');
    expect(sectionProperties['label']?.asString(), 'Gesture');
    expect(sectionProperties['icon-name']?.asString(), 'input-mouse');
    expect(radioProperties['toggle-type']?.asString(), 'radio');
    expect(radioProperties['toggle-state']?.asInt32(), 1);

    await menu.handleMethodCall(
      const DBusMethodCall(
        sender: ':1.1',
        interface: 'com.canonical.dbusmenu',
        name: 'Event',
        values: <DBusValue>[
          DBusInt32(2),
          DBusString('clicked'),
          DBusVariant(DBusInt32(0)),
          DBusUint32(0),
        ],
      ),
    );
    expect(selectedId, 2);
  });
}

final class _TestMenuDelegate extends PlatformMenuDelegate {
  const _TestMenuDelegate();

  @override
  void clearMenus() {}

  @override
  bool debugLockDelegate(BuildContext context) => true;

  @override
  bool debugUnlockDelegate(BuildContext context) => true;

  @override
  void setMenus(List<PlatformMenuItem> topLevelMenus) {}
}
