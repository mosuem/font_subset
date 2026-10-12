# package:font_subset

Builds or fetches the Flutter `font-subset` executable (powered by HarfBuzz) across Linux, macOS, and Windows, and provides a Dart API to subset TTF/OTF fonts (for example from a `hook/link.dart`).

## Usage

```dart
import 'dart:io';
import 'package:font_subset/font_subset.dart';

Future<void> main() async {
  final result = await subsetFont(
    input: File('fonts/MyIcons.otf'),
    output: File('build/MyIcons.subset.otf'),
    codePoints: const [0xe047],
    optionalCodePoints: const [32],
  );
  print(result.summaryMessage);
}
```

## Build Modes

Configured in `pubspec.yaml` under `hooks.user_defines.font_subset` (or via the `FONT_SUBSET_BUILD_MODE` environment variable):

```yaml
hooks:
  user_defines:
    font_subset:
      buildMode: fetch # 'fetch', 'checkout', or 'local'
```

- **`fetch`** *(default)*: Downloads prebuilt binaries from GitHub Releases verified against pinned SHA-256 checksums, falling back to local CMake compilation if unavailable.
- **`checkout`**: Always compiles `font-subset` locally from C++ and HarfBuzz sources via CMake (using `checkoutPath` if specified, or the bundled sources in this package).
- **`local`**: Uses a custom prebuilt `font-subset` binary at `localPath`.
