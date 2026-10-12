// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'fetch.dart' show ensureExecutablePermission;
import 'targets.dart' show executableFileName, targetTripleFor;

final _visualStudioPlatforms = <Architecture, String>{
  Architecture.arm64: 'ARM64',
  Architecture.ia32: 'Win32',
  Architecture.x64: 'x64',
};

final _macOSArchitectures = <Architecture, String>{
  Architecture.arm64: 'arm64',
  Architecture.x64: 'x86_64',
};

/// Compiles `font-subset` from the bundled C++ and HarfBuzz sources in
/// [packageRoot] using CMake, placing the built executable into [installDir].
Future<Uri> buildFontSubsetWithCMake({
  required Uri packageRoot,
  required Uri buildDir,
  required Uri installDir,
  OS? targetOS,
  Architecture? targetArch,
}) async {
  final os = targetOS ?? OS.current;
  final arch = targetArch ?? Architecture.current;
  final fileName = executableFileName(os);
  final installedBinary = File.fromUri(installDir.resolve(fileName));
  if (installedBinary.existsSync()) {
    await ensureExecutablePermission(installedBinary, os: os);
    return installedBinary.uri;
  }

  final sourceDir = Directory.fromUri(packageRoot.resolve('src/'));
  final buildDirFile = Directory.fromUri(buildDir);
  final installDirFile = Directory.fromUri(installDir);
  await buildDirFile.create(recursive: true);
  await installDirFile.create(recursive: true);

  final targetTriple = targetTripleFor(os, arch);
  stdout.writeln(
    'font_subset: building font-subset with CMake for $targetTriple...',
  );

  await _runCMake(<String>[
    '-S',
    sourceDir.path,
    '-B',
    buildDirFile.path,
    if (os == OS.windows &&
        _visualStudioPlatforms.containsKey(arch)) ...<String>[
      '-A',
      _visualStudioPlatforms[arch]!,
    ],
    if (os == OS.macOS && _macOSArchitectures.containsKey(arch))
      '-DCMAKE_OSX_ARCHITECTURES=${_macOSArchitectures[arch]!}',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DCMAKE_INSTALL_PREFIX=${installDirFile.path}',
  ]);

  await _runCMake(<String>[
    '--build',
    buildDirFile.path,
    '--config',
    'Release',
    '--target',
    'install',
    '--parallel',
    '${Platform.numberOfProcessors}',
  ]);

  if (!installedBinary.existsSync()) {
    throw BuildError(
      message: 'Failed to locate built $fileName in ${installDirFile.path}.',
    );
  }
  await ensureExecutablePermission(installedBinary, os: os);
  return installedBinary.uri;
}

Future<void> _runCMake(List<String> arguments) async {
  final result = await Process.run('cmake', arguments);
  if (result.exitCode != 0) {
    throw BuildError(
      message:
          'cmake ${arguments.join(' ')} failed (exit ${result.exitCode}):\n'
          'stdout: ${result.stdout}\n'
          'stderr: ${result.stderr}',
    );
  }
}

const _buildDependencyExtensions = <String>{
  '.c',
  '.cc',
  '.cmake',
  '.cpp',
  '.h',
  '.hh',
  'CMakeLists.txt',
};

/// Enumerates all C++/CMake source files in [packageRoot] that affect a local
/// CMake build of `font-subset`.
Iterable<Uri> buildDependencies(Uri packageRoot) sync* {
  yield* _filesForBuild(Directory.fromUri(packageRoot.resolve('src/')));
  yield* _filesForBuild(
    Directory.fromUri(packageRoot.resolve('third_party/harfbuzz/')),
  );
}

Iterable<Uri> _filesForBuild(Directory root) sync* {
  if (!root.existsSync()) {
    return;
  }
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    if (!_buildDependencyExtensions.any(entity.uri.path.endsWith)) {
      continue;
    }
    yield entity.uri;
  }
}
