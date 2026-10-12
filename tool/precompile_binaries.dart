// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// coverage:ignore-file

import 'dart:io';

import 'package:args/args.dart';
import 'package:code_assets/code_assets.dart';
import 'package:font_subset/src/hook_helpers/cmake_build.dart';
import 'package:font_subset/src/hook_helpers/targets.dart';

/// Builds the `font-subset` executable for a GitHub Release.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'target-os',
      abbr: 'o',
      allowed: <String>['linux', 'macos', 'windows', 'current'],
      defaultsTo: 'current',
      help: 'Target OS to build for.',
    )
    ..addOption(
      'target-arch',
      abbr: 'a',
      allowed: <String>['x64', 'arm64', 'current'],
      defaultsTo: 'current',
      help: 'Target architecture to build for.',
    )
    ..addOption(
      'out-dir',
      abbr: 'd',
      defaultsTo: 'bin',
      help: 'Output directory for built release binaries.',
    );

  final ArgResults results;
  try {
    results = parser.parse(args);
  } on Object catch (e) {
    stderr.writeln('Error parsing arguments: $e\n');
    stderr.writeln(parser.usage);
    exit(1);
  }

  final targetOS = results['target-os'] == 'current'
      ? OS.current
      : OS.values.firstWhere((o) => o.name == results['target-os']);

  final targetArch = results['target-arch'] == 'current'
      ? Architecture.current
      : Architecture.values.firstWhere((a) => a.name == results['target-arch']);

  final packageRoot = Platform.script.resolve('../');
  final outDir = Directory.fromUri(
    packageRoot.resolve('${results['out-dir']}/'),
  );
  await outDir.create(recursive: true);

  final targetTriple = targetTripleFor(targetOS, targetArch);
  stdout.writeln('==> Building font-subset for $targetTriple...');

  final buildDir = packageRoot.resolve('build/precompile-$targetTriple/');
  final installDir = buildDir.resolve('install/');

  final builtExecutable = await buildFontSubsetWithCMake(
    packageRoot: packageRoot,
    buildDir: buildDir,
    installDir: installDir,
    targetOS: targetOS,
    targetArch: targetArch,
  );

  final releaseAsset = File.fromUri(
    outDir.uri.resolve(releaseAssetName(targetOS, targetArch)),
  );
  await File.fromUri(builtExecutable).copy(releaseAsset.path);
  stdout.writeln('==> Created release binary: ${releaseAsset.path}');
}
