// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:data_assets/data_assets.dart';
import 'package:font_subset/src/hook_helpers/build_options.dart'
    show BuildModeEnum, BuildOptions;
import 'package:font_subset/src/hook_helpers/cmake_build.dart'
    show buildDependencies, buildFontSubsetWithCMake;
import 'package:font_subset/src/hook_helpers/fetch.dart'
    show ensureExecutablePermission, fetchPrebuiltExecutable;
import 'package:font_subset/src/hook_helpers/targets.dart'
    show executableFileName, targetTripleFor;
import 'package:hooks/hooks.dart';

const _assetName = 'font-subset';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    final buildOptions = BuildOptions.fromDefines(input.userDefines);
    stdout.writeln('font_subset: build options: $buildOptions');

    final Uri executableUri;
    switch (buildOptions.buildMode) {
      case BuildModeEnum.fetch:
        executableUri = await _fetchOrBuild(input, output);
      case BuildModeEnum.build:
      case BuildModeEnum.checkout:
        executableUri = await _buildCMake(input, output);
      case BuildModeEnum.local:
        executableUri = await _useLocalBinary(
          input,
          output,
          buildOptions.localPath,
        );
    }

    if (input.config.buildDataAssets) {
      final asset = DataAsset(
        package: input.packageName,
        name: _assetName,
        file: executableUri,
      );
      output.assets.data.add(asset, routing: const ToBuildHooks());
      final linkHookPackage = input.userDefines['linkHookPackage'];
      if (linkHookPackage is String && linkHookPackage.isNotEmpty) {
        output.assets.data.add(asset, routing: ToLinkHook(linkHookPackage));
      }
    }

    output.dependencies.addAll(<Uri>[
      input.packageRoot.resolve('pubspec.yaml'),
      input.packageRoot.resolve('hook/build.dart'),
      input.packageRoot.resolve('lib/src/hook_helpers/hashes.dart'),
    ]);
  });
}

Future<Uri> _fetchOrBuild(BuildInput input, BuildOutputBuilder output) async {
  final cached = await fetchPrebuiltExecutable(
    cacheDirectory: input.outputDirectoryShared,
  );
  if (cached != null) {
    return cached;
  }
  stdout.writeln(
    'font_subset: falling back to building from local source via CMake.',
  );
  return _buildCMake(input, output);
}

Future<Uri> _buildCMake(BuildInput input, BuildOutputBuilder output) async {
  final targetTriple = targetTripleFor(OS.current, Architecture.current);
  final builtUri = await buildFontSubsetWithCMake(
    packageRoot: input.packageRoot,
    buildDir: input.outputDirectoryShared.resolve('cmake-build-$targetTriple/'),
    installDir: input.outputDirectoryShared.resolve(
      'cmake-install-$targetTriple/',
    ),
  );
  output.dependencies.addAll(buildDependencies(input.packageRoot));
  return builtUri;
}

Future<Uri> _useLocalBinary(
  BuildInput input,
  BuildOutputBuilder output,
  Uri? localPath,
) async {
  if (localPath == null) {
    throw BuildError(
      message:
          'buildMode is set to `local`, but `localPath` was not specified '
          'under `hooks.user_defines.font_subset`.',
    );
  }
  final file = File.fromUri(localPath);
  if (!file.existsSync()) {
    throw BuildError(
      message:
          'Specified local binary does not exist at ${localPath.toFilePath()}',
    );
  }
  final exeName = executableFileName(OS.current);
  final destFile = File.fromUri(input.outputDirectory.resolve(exeName));
  await file.copy(destFile.path);
  await ensureExecutablePermission(destFile);
  output.dependencies.add(localPath);
  return destFile.uri;
}
