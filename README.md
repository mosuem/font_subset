# package:font_subset

Bundles the Flutter `font-subset` executable for `linux-x64`, `linux-arm64`,
`darwin-x64`, `darwin-arm64`, `windows-x64`, and `windows-arm64`, and provides a
Dart API to subset TTF/OTF fonts (for example from a `hook/link.dart`).

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
