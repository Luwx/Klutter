# linux_app_menu

Exports Flutter's standard `PlatformMenuBar` hierarchy through DBusMenu and
associates it with the Flutter window using KWin's native Wayland AppMenu
protocol. The same exported menu can appear in KDE Plasma's Global Menu panel
widget or Application Menu title-bar button.

This package intentionally supports KDE Plasma on Wayland only.

## Usage

Initialize the delegate before `runApp`, then use Flutter's normal platform
menu classes:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LinuxAppMenu.initialize();
  runApp(const MyApp());
}

PlatformMenuBar(
  menus: <PlatformMenuItem>[
    PlatformMenu(
      label: 'File',
      menus: <PlatformMenuItem>[
        PlatformMenuItem(
          label: 'Quit',
          shortcut: const CharacterActivator('q', control: true),
          onSelected: SystemNavigator.pop,
        ),
      ],
    ),
  ],
  child: const MyAppContent(),
)
```

`LinuxAppMenuBar` is also available as a convenience wrapper that installs the
delegate automatically.

## Supported behavior

- top-level menus and nested submenus
- enabled and disabled items
- `PlatformMenuItemGroup` separators
- checkbox and radio items
- titled menu sections on hosts that support labeled separators
- dynamically enabled leaf items and submenus
- `onSelected` and `onSelectedIntent` dispatch through Flutter
- `CharacterActivator` accelerators
- dynamic replacement of the complete menu hierarchy

DBusMenu does not provide matching submenu close notifications, so
`PlatformMenu.onOpen` and `PlatformMenu.onClose` are currently not called.
The plugin does not render an in-window fallback menu.

### Checkboxes, radio buttons, and enabled state

The package adds four item classes that can be mixed with Flutter's standard
menu classes:

- `LinuxMenuItem`
- `LinuxMenuSection`
- `LinuxCheckMenuItem`
- `LinuxRadioMenuItem`
- `LinuxSubmenu`

They are immutable. Change application state in `onSelected`, rebuild the
`PlatformMenuBar`, and pass the new `checked`, `selected`, or `enabled` value:

```dart
LinuxCheckMenuItem(
  label: 'Enable themes',
  checked: themesEnabled,
  onSelected: () => setState(() {
    themesEnabled = !themesEnabled;
  }),
),
LinuxSubmenu(
  label: 'Editor Color Theme',
  enabled: themesEnabled,
  menus: <PlatformMenuItem>[
    for (final theme in themes)
      LinuxRadioMenuItem(
        label: theme.label,
        selected: selectedTheme == theme,
        onSelected: () => setState(() {
          selectedTheme = theme;
        }),
      ),
  ],
),
```

All Linux-specific item classes accept an optional freedesktop `iconName`.
Both `CharacterActivator` and Unicode-key `SingleActivator` shortcuts are
exported for display by the desktop shell.

## KDE notes

Enable KDE's Global Menu widget or Application Menu decoration button. The
plugin talks directly to the `org_kde_kwin_appmenu_manager` Wayland global and
exports `com.canonical.dbusmenu`, so `appmenu-gtk-module` is not required.

The application must use server-side decorations if the Application Menu
title-bar button is being tested. Do not install a `GtkHeaderBar` with
`gtk_window_set_titlebar()`. The bundled example follows this setup.

See [`example/`](example/) for a runnable test application.
