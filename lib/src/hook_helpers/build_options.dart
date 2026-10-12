// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show Platform;

import 'package:hooks/hooks.dart' show HookInputUserDefines;

/// Supported build modes for `package:font_subset`.
enum BuildModeEnum {
  /// Download a prebuilt `font-subset` binary from GitHub Releases, verified
  /// against pinned SHA-256 hashes (falling back to local compilation if
  /// unavailable).
  fetch,

  /// Compile `font-subset` locally from bundled C++/HarfBuzz sources via CMake.
  build,

  /// Alias for [build]: compile `font-subset` locally from bundled sources.
  checkout,

  /// Use a user-specified local `font-subset` binary at
  /// [BuildOptions.localPath].
  local,
}

/// Configuration options read from `hooks.user_defines.font_subset` in
/// `pubspec.yaml` (or the `FONT_SUBSET_BUILD_MODE` environment variable).
class BuildOptions {
  /// Creates [BuildOptions].
  BuildOptions({required this.buildMode, this.localPath});

  /// Parses [BuildOptions] from [defines].
  factory BuildOptions.fromDefines(HookInputUserDefines defines) {
    final modeString =
        Platform.environment['FONT_SUBSET_BUILD_MODE'] ??
        defines['buildMode'] as String? ??
        'fetch';
    return BuildOptions(
      buildMode: BuildModeEnum.values.firstWhere(
        (element) => element.name == modeString,
        orElse: () => throw FormatException(
          'Invalid buildMode "$modeString". Expected one of: '
          '${BuildModeEnum.values.map((e) => e.name).join(', ')}.',
        ),
      ),
      localPath: defines.path('localPath'),
    );
  }

  /// Selected build mode.
  final BuildModeEnum buildMode;

  /// Path to a prebuilt `font-subset` binary when [buildMode] is
  /// [BuildModeEnum.local].
  final Uri? localPath;

  @override
  String toString() =>
      'BuildOptions(buildMode: $buildMode, localPath: $localPath)';
}
