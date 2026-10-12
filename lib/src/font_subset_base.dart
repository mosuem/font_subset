// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show utf8;
import 'dart:ffi' show Abi;
import 'dart:io' show File, Platform, Process;
import 'dart:isolate' show Isolate;

import 'package:mime/mime.dart' as mime;

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

/// Resolves the bundled `font-subset` executable for the given host [abi]
/// (defaults to [Abi.current]).
///
/// Throws a [FontSubsetException] if [abi] is not supported or the binary
/// cannot be located.
Future<File> fontSubsetExecutable({Abi? abi}) async {
  final targetAbi = abi ?? Abi.current();
  final (dirName, exeName) = switch (targetAbi) {
    Abi.linuxX64 => ('linux-x64', 'font-subset'),
    Abi.linuxArm64 => ('linux-arm64', 'font-subset'),
    Abi.macosX64 => ('darwin-x64', 'font-subset'),
    Abi.macosArm64 => ('darwin-arm64', 'font-subset'),
    Abi.windowsX64 => ('windows-x64', 'font-subset.exe'),
    Abi.windowsArm64 => ('windows-arm64', 'font-subset.exe'),
    _ => throw FontSubsetException(
      'Unsupported host ABI for font-subset: $targetAbi.',
    ),
  };

  final libraryUri = await Isolate.resolvePackageUri(
    Uri.parse('package:font_subset/font_subset.dart'),
  );
  if (libraryUri == null) {
    throw const FontSubsetException(
      'Unable to resolve package:font_subset/font_subset.dart URI.',
    );
  }

  final binaryUri = libraryUri.resolve('../binaries/$dirName/$exeName');
  final binaryFile = File.fromUri(binaryUri);
  if (!binaryFile.existsSync()) {
    throw FontSubsetException(
      'Bundled font-subset binary not found at ${binaryFile.path}.',
    );
  }

  if (targetAbi == Abi.current() && !Platform.isWindows) {
    final mode = binaryFile.statSync().mode;
    // Ensure owner execute bit (0o100 = 64) is set in case archive unpacking
    // stripped permissions.
    if ((mode & 0x40) == 0) {
      await Process.run('chmod', <String>['+x', binaryFile.path]);
    }
  }

  return binaryFile;
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
