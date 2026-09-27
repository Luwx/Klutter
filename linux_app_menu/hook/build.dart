import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Wayland protocols in `src/protocols/` compiled into the library.
const _protocols = ['appmenu'];

/// pkg-config packages the native code builds against.
const _pkgConfigPackages = ['gtk+-3.0', 'gdk-wayland-3.0', 'wayland-client'];

void main(List<String> args) async {
  await build(args, (input, output) async {
    // The native code only exists for Linux. Other targets get no asset and
    // the Dart API reports the platform as unsupported.
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.linux) {
      return;
    }

    final generated = input.outputDirectory.resolve('protocols/');
    await Directory.fromUri(generated).create(recursive: true);
    final scanner = await _waylandScanner();
    final protocolSources = <String>[];
    for (final protocol in _protocols) {
      final xml = input.packageRoot.resolve('src/protocols/$protocol.xml');
      final header = generated.resolve('$protocol-protocol.h');
      final code = generated.resolve('$protocol-protocol.c');
      await _run(scanner, ['client-header', xml.path, header.path]);
      await _run(scanner, ['private-code', xml.path, code.path]);
      output.dependencies.add(xml);
      protocolSources.add(code.path);
    }

    final cflags = await _pkgConfig(['--cflags', ..._pkgConfigPackages]);
    final libs = await _pkgConfig(['--libs', ..._pkgConfigPackages]);
    final packageName = input.packageName;
    await CBuilder.library(
      name: packageName,
      assetName: 'src/${packageName}_bindings_generated.dart',
      sources: ['src/$packageName.c', ...protocolSources],
      includes: [generated.path],
      flags: ['-fvisibility=hidden', ...cflags],
      libraries: [
        for (final flag in libs)
          if (flag.startsWith('-l')) flag.substring(2),
      ],
      libraryDirectories: [
        '.',
        for (final flag in libs)
          if (flag.startsWith('-L')) flag.substring(2),
      ],
    ).run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.INFO
        // Hook output is shown in the build log.
        // ignore: avoid_print
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}

Future<String> _waylandScanner() async {
  final result = await Process.run('pkg-config', [
    '--variable=wayland_scanner',
    'wayland-scanner',
  ]);
  final path = (result.stdout as String).trim();
  return result.exitCode == 0 && path.isNotEmpty ? path : 'wayland-scanner';
}

Future<List<String>> _pkgConfig(List<String> args) async {
  final result = await _run('pkg-config', args);
  return result.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
}

Future<String> _run(String executable, List<String> args) async {
  final result = await Process.run(executable, args);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      args,
      'Install the GTK 3 and Wayland development packages.\n${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout as String;
}
