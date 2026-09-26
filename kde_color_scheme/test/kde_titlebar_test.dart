import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kde_color_scheme/kde_color_scheme.dart';
import 'package:kde_color_scheme/src/color_scheme_store.dart';
import 'package:kde_color_scheme/src/titlebar_color_scheme.dart';

Map<String, Map<String, String>> _groups(String content) {
  final groups = <String, Map<String, String>>{};
  Map<String, String>? current;
  for (final line in content.split('\n')) {
    if (line.startsWith('[')) {
      current = groups[line.substring(1, line.length - 1)] = {};
    } else if (line.contains('=')) {
      final eq = line.indexOf('=');
      current![line.substring(0, eq)] = line.substring(eq + 1);
    }
  }
  return groups;
}

const _kdeglobals = '''
[General]
AccentColor=61,174,233
ColorScheme=BreezeDark

[Colors:Window]
BackgroundNormal=32,35,38
ForegroundNormal=252,252,252
ForegroundNegative=218,68,83

[Colors:View]
ForegroundNormal=250,250,250

[Colors:Header]
BackgroundNormal=41,44,48
ForegroundNormal=252,252,252
ForegroundNegative=218,68,83

[Colors:Header][Inactive]
BackgroundNormal=32,35,38
ForegroundNormal=161,169,177

[ColorEffects:Inactive]
Enable=false

[KDE]
contrast=4
LookAndFeelPackage=org.kde.breezedark.desktop

[Icons]
Theme=breeze-dark
''';

void main() {
  group('buildTitlebarColorScheme', () {
    test('overrides header and WM colors', () {
      final groups = _groups(
        buildTitlebarColorScheme(
          const TitlebarColors(
            background: Color(0xFF102030),
            foreground: Color(0x80FFFFFF),
            inactiveBackground: Color(0xFF405060),
          ),
        ),
      );

      expect(groups['Colors:Header'], {
        'BackgroundNormal': '16,32,48',
        'BackgroundAlternate': '16,32,48',
        'ForegroundNormal': '255,255,255,128',
      });
      expect(groups['Colors:Header][Inactive'], {
        'BackgroundNormal': '64,80,96',
        'BackgroundAlternate': '64,80,96',
        'ForegroundNormal': '255,255,255,128',
      });
      expect(groups['WM'], {
        'activeBackground': '16,32,48',
        'activeForeground': '255,255,255,128',
        'inactiveBackground': '64,80,96',
        'inactiveForeground': '255,255,255,128',
      });
      expect(groups['General'], {'Name': 'Klutter Title Bar'});
    });

    test('keeps system color groups but not general settings', () {
      final groups = _groups(
        buildTitlebarColorScheme(
          const TitlebarColors(
            background: Color(0xFF000000),
            foreground: Color(0xFFFFFFFF),
          ),
          base: _kdeglobals,
        ),
      );

      expect(groups['Colors:View'], {'ForegroundNormal': '250,250,250'});
      expect(groups['ColorEffects:Inactive'], {'Enable': 'false'});
      expect(groups['KDE'], {'contrast': '4'});
      expect(groups['General'], {'Name': 'Klutter Title Bar'});
      expect(groups, isNot(contains('Icons')));
      expect(
        groups['Colors:Header'],
        containsPair('ForegroundNegative', '218,68,83'),
      );
      expect(
        groups['Colors:Header'],
        containsPair('BackgroundNormal', '0,0,0'),
      );
      expect(
        groups['Colors:Header][Inactive'],
        containsPair('ForegroundNormal', '255,255,255'),
      );
    });

    test('seeds the header from the window colors when missing', () {
      final groups = _groups(
        buildTitlebarColorScheme(
          const TitlebarColors(
            background: Color(0xFF000000),
            foreground: Color(0xFFFFFFFF),
          ),
          base: '[Colors:Window]\nForegroundNegative=1,2,3\n',
        ),
      );

      expect(
        groups['Colors:Header'],
        containsPair('ForegroundNegative', '1,2,3'),
      );
      expect(
        groups['Colors:Header][Inactive'],
        containsPair('ForegroundNegative', '1,2,3'),
      );
    });
  });

  group('ColorSchemeStore', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('kde_color_scheme'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('uses the runtime directory named after the executable', () {
      final store = ColorSchemeStore(
        environment: {'XDG_RUNTIME_DIR': '/run/user/1000', 'HOME': '/home/u'},
        processId: 42,
        executable: '/opt/app/my_app',
      );
      expect(store.directory.path, '/run/user/1000/my_app');
      expect(store.owner, '42');
    });

    test('uses the shared app directory inside Flatpak', () {
      final info = File('${temp.path}/flatpak-info')
        ..writeAsStringSync(
          '[Application]\nname=org.example.App\n\n'
          '[Instance]\ninstance-id=1234567\n',
        );
      final store = ColorSchemeStore(
        environment: {
          'XDG_RUNTIME_DIR': '/run/user/1000',
          'FLATPAK_ID': 'org.example.App',
        },
        processId: 2,
        executable: '/app/bin/my_app',
        flatpakInfoPath: info.path,
      );
      expect(store.directory.path, '/run/user/1000/app/org.example.App');
      expect(store.owner, 'i1234567');
    });

    test('falls back to the cache directory', () {
      final store = ColorSchemeStore(
        environment: {'HOME': '/home/u'},
        executable: '/opt/app/my_app',
      );
      expect(store.directory.path, '/home/u/.cache/my_app');
    });

    test('writes content under a content-dependent name', () async {
      final store = ColorSchemeStore(
        environment: {'XDG_RUNTIME_DIR': temp.path},
        processId: 42,
        executable: 'my_app',
      );
      final first = await store.write('a');
      final again = await store.write('a');
      final second = await store.write('b');

      expect(first.path, again.path);
      expect(first.path, isNot(second.path));
      expect(
        first.path,
        matches(RegExp(r'/my_app/titlebar-42-[0-9a-f]{16}\.colors$')),
      );
      expect(first.readAsStringSync(), 'a');
      expect(
        Directory('${temp.path}/my_app').listSync().map((e) => e.path),
        isNot(contains(endsWith('.tmp'))),
      );
    });

    test('removes files of processes that are gone', () async {
      final dir = Directory('${temp.path}/my_app')..createSync();
      for (final name in [
        'titlebar-42-00000000000000aa.colors',
        'titlebar-100-00000000000000bb.colors',
        'titlebar-200-00000000000000cc.colors',
        '.titlebar-200-00000000000000dd.colors.tmp',
        'titlebar-i5-00000000000000ee.colors',
        'unrelated.colors',
      ]) {
        File('${dir.path}/$name').writeAsStringSync('');
      }

      await ColorSchemeStore(
        environment: {'XDG_RUNTIME_DIR': temp.path},
        processId: 42,
        executable: 'my_app',
        isProcessAlive: (pid) => pid == 100,
      ).removeStale();

      final left = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
      expect(left, {
        'titlebar-42-00000000000000aa.colors',
        'titlebar-100-00000000000000bb.colors',
        'titlebar-i5-00000000000000ee.colors',
        'unrelated.colors',
      });
    });
  });

  test('finds kdeglobals in XDG_CONFIG_HOME, then ~/.config', () {
    final temp = Directory.systemTemp.createTempSync('kde_color_scheme');
    addTearDown(() => temp.deleteSync(recursive: true));
    final environment = {
      'HOME': '${temp.path}/home',
      'XDG_CONFIG_HOME': '${temp.path}/config',
    };

    expect(
      KdeglobalsParser.defaultPathFor(environment),
      '${temp.path}/home/.config/kdeglobals',
    );

    Directory('${temp.path}/config').createSync();
    File('${temp.path}/config/kdeglobals').writeAsStringSync('');
    expect(
      KdeglobalsParser.defaultPathFor(environment),
      '${temp.path}/config/kdeglobals',
    );
  });
}
