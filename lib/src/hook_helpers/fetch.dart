// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'hashes.dart' show fileHashes, version;
import 'sha256.dart' show sha256Hex;
import 'targets.dart' show executableFileName, releaseAssetName;

/// Downloads and verifies the pre-built `font-subset` executable for [targetOS]
/// and [targetArch] from the GitHub release [version], caching it in
/// [cacheDirectory].
///
/// Returns `null` if no hash is registered in [fileHashes] or if downloading
/// fails due to an HTTP or network error. Throws a [BuildError] if the
/// downloaded file's SHA-256 checksum does not match [fileHashes].
Future<Uri?> fetchPrebuiltExecutable({
  required Uri cacheDirectory,
  OS? targetOS,
  Architecture? targetArch,
}) async {
  final os = targetOS ?? OS.current;
  final arch = targetArch ?? Architecture.current;

  final assetRemoteName = releaseAssetName(os, arch);
  final expectedHash = fileHashes[assetRemoteName];

  if (expectedHash == null || expectedHash.isEmpty) {
    stdout.writeln(
      'font_subset: no prebuilt binary hash registered for $assetRemoteName.',
    );
    return null;
  }

  final fileName = executableFileName(os);
  final cachedFile = File.fromUri(
    cacheDirectory
        .resolve('font_subset-$version/$assetRemoteName/')
        .resolve(fileName),
  );
  if (await cachedFile.exists()) {
    final cachedHash = sha256Hex(await cachedFile.readAsBytes());
    if (cachedHash == expectedHash) {
      stdout.writeln(
        'font_subset: using cached prebuilt binary ($assetRemoteName).',
      );
      await ensureExecutablePermission(cachedFile, os: os);
      return cachedFile.uri;
    }
  }

  final binaryUrl = Uri.parse(
    'https://github.com/mosuem/font_subset/releases/download/v$version/$assetRemoteName',
  );

  stdout.writeln('font_subset: fetching prebuilt binary from $binaryUrl...');

  final client = HttpClient();
  final List<int> bytes;
  try {
    final request = await client.getUrl(binaryUrl);
    final response = await request.close();
    if (response.statusCode != 200) {
      stdout.writeln(
        'font_subset: failed to download from $binaryUrl '
        '(status: ${response.statusCode}).',
      );
      return null;
    }
    bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
  } on IOException catch (e) {
    stdout.writeln(
      'font_subset: network error downloading prebuilt binary ($e).',
    );
    return null;
  } finally {
    client.close();
  }

  final actualHash = sha256Hex(bytes);

  if (actualHash != expectedHash) {
    throw BuildError(
      message:
          'SHA256 hash mismatch for prebuilt binary $assetRemoteName.\n'
          'Expected: $expectedHash\n'
          'Actual:   $actualHash\n'
          'To build font_subset locally from source instead, set '
          '`buildMode: checkout` in your pubspec.yaml under '
          '`hooks.user_defines.font_subset`.',
    );
  }

  stdout.writeln('font_subset: verified SHA256 checksum ($actualHash).');

  await cachedFile.parent.create(recursive: true);
  await cachedFile.writeAsBytes(bytes);
  await ensureExecutablePermission(cachedFile, os: os);
  return cachedFile.uri;
}

/// Ensures [file] has owner execute permission when running on a non-Windows
/// host.
Future<void> ensureExecutablePermission(File file, {OS? os}) async {
  final targetOS = os ?? OS.current;
  if (targetOS != OS.windows && !Platform.isWindows) {
    final mode = file.statSync().mode;
    if ((mode & 0x40) == 0) {
      await Process.run('chmod', <String>['+x', file.path]);
    }
  }
}
