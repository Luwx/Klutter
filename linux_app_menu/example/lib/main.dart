import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linux_app_menu/linux_app_menu.dart';

enum AccentColor { purple, blue, teal, orange }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LinuxAppMenu.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _customAccentEnabled = true;
  AccentColor _accentColor = AccentColor.teal;

  Color get _seedColor => switch (_accentColor) {
    AccentColor.purple => Colors.deepPurple,
    AccentColor.blue => Colors.blue,
    AccentColor.teal => Colors.teal,
    AccentColor.orange => Colors.orange,
  };

  String get _themeModeLabel => switch (_themeMode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  String _accentLabel(AccentColor color) => switch (color) {
    AccentColor.purple => 'Purple',
    AccentColor.blue => 'Blue',
    AccentColor.teal => 'Teal',
    AccentColor.orange => 'Orange',
  };

  List<PlatformMenuItem> _menus(BuildContext context) {
    return <PlatformMenuItem>[
      LinuxSubmenu(
        label: 'File',
        iconName: 'document-open',
        menus: <PlatformMenuItem>[
          LinuxMenuItem(
            label: 'Quit',
            iconName: 'application-exit',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyQ,
              control: true,
            ),
            onSelected: SystemNavigator.pop,
          ),
        ],
      ),
      LinuxSubmenu(
        label: 'Appearance',
        iconName: 'preferences-desktop-theme',
        menus: <PlatformMenuItem>[
          LinuxSubmenu(
            label: 'Theme Mode',
            iconName: 'preferences-desktop-theme',
            menus: <PlatformMenuItem>[
              for (final mode in ThemeMode.values)
                LinuxRadioMenuItem(
                  label: switch (mode) {
                    ThemeMode.system => 'Follow System',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  },
                  iconName: switch (mode) {
                    ThemeMode.system => 'preferences-system',
                    ThemeMode.light => 'weather-clear',
                    ThemeMode.dark => 'weather-clear-night',
                  },
                  shortcut: SingleActivator(
                    switch (mode) {
                      ThemeMode.system => LogicalKeyboardKey.digit0,
                      ThemeMode.light => LogicalKeyboardKey.digit1,
                      ThemeMode.dark => LogicalKeyboardKey.digit2,
                    },
                    control: true,
                    alt: true,
                  ),
                  selected: _themeMode == mode,
                  onSelected: () => setState(() => _themeMode = mode),
                ),
            ],
          ),
          PlatformMenuItemGroup(
            members: <PlatformMenuItem>[
              LinuxCheckMenuItem(
                label: 'Use Custom Accent Color',
                iconName: 'preferences-desktop-color',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyA,
                  control: true,
                  shift: true,
                ),
                checked: _customAccentEnabled,
                onSelected: () {
                  setState(() {
                    _customAccentEnabled = !_customAccentEnabled;
                  });
                },
              ),
              LinuxSubmenu(
                label: 'Accent Color',
                iconName: 'preferences-desktop-color',
                enabled: _customAccentEnabled,
                menus: <PlatformMenuItem>[
                  for (final color in AccentColor.values)
                    LinuxRadioMenuItem(
                      label: _accentLabel(color),
                      iconName: 'preferences-desktop-color',
                      shortcut: SingleActivator(
                        switch (color) {
                          AccentColor.purple => LogicalKeyboardKey.keyP,
                          AccentColor.blue => LogicalKeyboardKey.keyB,
                          AccentColor.teal => LogicalKeyboardKey.keyT,
                          AccentColor.orange => LogicalKeyboardKey.keyO,
                        },
                        control: true,
                        alt: true,
                      ),
                      selected: _accentColor == color,
                      onSelected: () {
                        setState(() => _accentColor = color);
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
      LinuxSubmenu(
        label: 'Help',
        iconName: 'help-contents',
        menus: <PlatformMenuItem>[
          const LinuxMenuSection(label: 'Resources', iconName: 'help-contents'),
          LinuxMenuItem(
            label: 'About linux_app_menu',
            iconName: 'help-about',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyH,
              control: true,
              alt: true,
            ),
            onSelected: () => showAboutDialog(
              context: context,
              applicationName: 'linux_app_menu example',
              applicationVersion: '0.0.1',
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = _customAccentEnabled ? _seedColor : Colors.deepPurple;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorSchemeSeed: seedColor,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: seedColor,
        brightness: Brightness.dark,
      ),
      home: Builder(
        builder: (context) => PlatformMenuBar(
          menus: _menus(context),
          child: Scaffold(
            appBar: AppBar(title: const Text('Linux App Menu example')),
            body: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.palette_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Theme mode: $_themeModeLabel',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _customAccentEnabled
                            ? 'Accent color: ${_accentLabel(_accentColor)}'
                            : 'Custom accent color disabled',
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Change these settings from KDE’s Global Menu\n'
                        'or Application Menu title-bar button.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
