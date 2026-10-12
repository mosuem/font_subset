// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, Platform, Process;
import 'dart:isolate' show Isolate;

import 'package:code_assets/code_assets.dart';
import 'package:mime/mime.dart' as mime;

import 'hook_helpers/build_options.dart' show BuildModeEnum;
import 'hook_helpers/cmake_build.dart' show buildFontSubsetWithCMake;
import 'hook_helpers/fetch.dart'
    show ensureExecutablePermission, fetchPrebuiltExecutable;
import 'hook_helpers/targets.dart' show targetTripleFor;

/// The MIME types recognized as TTF/OTF font files that `font-subset` can
/// process.
const Set<String> kSupportedFontMimeTypes = <String>{
  'font/ttf',
  'font/opentype',
  'font/otf',
  'application/x-font-opentype',
  'application/x-font-otf',
  'application/x-font-ttf',
};

/// Returns whether [file] exists, has at least 12 bytes, and matches one of
/// [kSupportedFontMimeTypes].
Future<bool> isSupportedFontFile(File file) async {
  if (!file.existsSync() || file.lengthSync() < 12) {
    return false;
  }
  final headerBytes = await file.openRead(0, 12).first;
  final mimeType = mime.lookupMimeType(file.path, headerBytes: headerBytes);
  return kSupportedFontMimeTypes.contains(mimeType);
}

/// Resolves the `font-subset` executable for the current host, using the given
/// [buildMode] (defaults to `FONT_SUBSET_BUILD_MODE` or [BuildModeEnum.fetch],
/// falling back to building from bundled C++/HarfBuzz sources with CMake).
///
/// Throws a [FontSubsetException] if the binary cannot be fetched or built.
Future<File> fontSubsetExecutable({
  BuildModeEnum? buildMode,
  Uri? checkoutPath,
  Uri? localPath,
  Uri? cacheDirectory,
}) async {
  final effectiveMode = buildMode ?? _defaultBuildMode();
  if (effectiveMode == BuildModeEnum.local) {
    if (localPath == null) {
      throw const FontSubsetException(
        'buildMode is `local`, but `localPath` was not provided.',
      );
    }
    final file = File.fromUri(localPath);
    if (!file.existsSync()) {
      throw FontSubsetException(
        'Local font-subset binary does not exist at ${file.path}.',
      );
    }
    await ensureExecutablePermission(file);
    return file;
  }

  final libraryUri = await Isolate.resolvePackageUri(
    Uri.parse('package:font_subset/font_subset.dart'),
  );
  if (libraryUri == null) {
    throw const FontSubsetException(
      'Unable to resolve package:font_subset/font_subset.dart URI.',
    );
  }
  final packageRoot = checkoutPath ?? libraryUri.resolve('../');
  final sharedCache = cacheDirectory ?? _defaultCacheDirectory();

  try {
    if (effectiveMode == BuildModeEnum.fetch) {
      final fetched = await fetchPrebuiltExecutable(
        cacheDirectory: sharedCache,
      );
      if (fetched != null) {
        return File.fromUri(fetched);
      }
    }

    final targetTriple = targetTripleFor(OS.current, Architecture.current);
    final built = await buildFontSubsetWithCMake(
      packageRoot: packageRoot,
      buildDir: sharedCache.resolve('cmake-build-$targetTriple/'),
      installDir: sharedCache.resolve('cmake-install-$targetTriple/'),
    );
    return File.fromUri(built);
  } on Object catch (e) {
    throw FontSubsetException('Failed to resolve font-subset executable: $e');
  }
}

Uri _defaultCacheDirectory() {
  final hooksRunnerShared = Directory.current.uri.resolve(
    '.dart_tool/hooks_runner/shared/font_subset/build/',
  );
  if (Directory.fromUri(hooksRunnerShared).existsSync()) {
    return hooksRunnerShared;
  }
  return Directory.systemTemp.uri.resolve('font_subset_shared_cache/');
}

BuildModeEnum _defaultBuildMode() {
  final env = Platform.environment['FONT_SUBSET_BUILD_MODE'];
  if (env != null && env.isNotEmpty) {
    return BuildModeEnum.values.firstWhere(
      (m) => m.name == env,
      orElse: () => BuildModeEnum.fetch,
    );
  }
  return BuildModeEnum.fetch;
}

/// Runs `font-subset` to subset [input] into [output], retaining only the
/// glyphs at [codePoints] (and [optionalCodePoints] if present in [input]).
///
/// Throws a [FontSubsetException] if [input] is not a supported TTF/OTF font,
/// if [codePoints] and [optionalCodePoints] are both empty, or if the
/// `font-subset` process exits with a non-zero code.
Future<FontSubsetResult> subsetFont({
  required File input,
  required File output,
  required Iterable<int> codePoints,
  Iterable<int> optionalCodePoints = const <int>[],
  File? executable,
}) async {
  if (!await isSupportedFontFile(input)) {
    throw FontSubsetException(
      'Input file "${input.path}" does not exist or is not a supported TTF/OTF '
      'font.',
    );
  }

  final requiredStrings = codePoints.map((c) => c.toString()).toList();
  final optionalStrings = optionalCodePoints.map((c) => 'optional:$c').toList();
  if (requiredStrings.isEmpty && optionalStrings.isEmpty) {
    throw const FontSubsetException(
      'At least one code point must be provided to subsetFont.',
    );
  }

  output.parent.createSync(recursive: true);

  final fontSubset = executable ?? await fontSubsetExecutable();
  final codePointsLine = <String>[
    ...requiredStrings,
    ...optionalStrings,
  ].join(' ');

  final process = await Process.start(fontSubset.path, <String>[
    output.path,
    input.path,
  ]);
  final stdoutFuture = utf8.decodeStream(process.stdout);
  final stderrFuture = utf8.decodeStream(process.stderr);

  try {
    process.stdin.writeln(codePointsLine);
    await process.stdin.flush();
    await process.stdin.close();
  } on Object {
    // Handled below via exitCode and stderr.
  }

  final exitCode = await process.exitCode;
  final stdout = await stdoutFuture;
  final stderr = await stderrFuture;

  if (exitCode != 0) {
    throw FontSubsetException(
      'font-subset failed with exit code $exitCode.\n'
      'stdout: $stdout\n'
      'stderr: $stderr',
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
    );
  }

  return FontSubsetResult(
    inputFile: input,
    outputFile: output,
    inputSize: input.lengthSync(),
    outputSize: output.lengthSync(),
  );
}

/// Summary of a completed [subsetFont] invocation.
final class FontSubsetResult {
  /// Creates a [FontSubsetResult].
  const FontSubsetResult({
    required this.inputFile,
    required this.outputFile,
    required this.inputSize,
    required this.outputSize,
  });

  /// The original font file.
  final File inputFile;

  /// The subsetted font file written by `font-subset`.
  final File outputFile;

  /// Size of [inputFile] in bytes.
  final int inputSize;

  /// Size of [outputFile] in bytes.
  final int outputSize;

  /// Number of bytes saved (`inputSize - outputSize`).
  int get reductionBytes => inputSize - outputSize;

  /// Percentage size reduction (`0.0`..`100.0`).
  double get reductionPercentage =>
      inputSize == 0 ? 0.0 : (reductionBytes / inputSize) * 100.0;

  /// Human-readable summary matching Flutter's `IconTreeShaker` log message.
  String get summaryMessage {
    final fontName = inputFile.uri.pathSegments.last;
    final pct = reductionPercentage.toStringAsFixed(1);
    return 'Font asset "$fontName" was tree-shaken, reducing it from '
        '$inputSize to $outputSize bytes ($pct% reduction).';
  }
}

/// Exception thrown when locating or running `font-subset` fails.
final class FontSubsetException implements Exception {
  /// Creates a [FontSubsetException].
  const FontSubsetException(
    this.message, {
    this.exitCode,
    this.stdout,
    this.stderr,
  });

  /// Description of the failure.
  final String message;

  /// Process exit code, if `font-subset` was executed.
  final int? exitCode;

  /// Standard output from `font-subset`, if available.
  final String? stdout;

  /// Standard error from `font-subset`, if available.
  final String? stderr;

  @override
  String toString() => 'FontSubsetException: $message';
}
