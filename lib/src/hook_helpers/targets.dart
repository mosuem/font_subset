// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_assets/code_assets.dart';

/// Supported host targets for prebuilt `font-subset` binaries.
const supportedTargets = <(OS, Architecture)>[
  (OS.linux, Architecture.arm64),
  (OS.linux, Architecture.x64),
  (OS.macOS, Architecture.arm64),
  (OS.macOS, Architecture.x64),
  (OS.windows, Architecture.arm64),
  (OS.windows, Architecture.x64),
];

/// Formats a canonical target identifier (`<os>-<arch>`).
String targetTripleFor(OS os, Architecture arch) => '${os.name}-${arch.name}';

/// The file name of the `font-subset` executable built by `src/CMakeLists.txt`
/// for [os].
String executableFileName(OS os) => os.executableFileName('font-subset');

/// The name of the GitHub release asset with the prebuilt executable for [os]
/// and [arch].
String releaseAssetName(OS os, Architecture arch) =>
    'font_subset-${targetTripleFor(os, arch)}-${executableFileName(os)}';
