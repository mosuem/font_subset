// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' show base64Decode;
import 'dart:ffi' show Abi;
import 'dart:io' show Directory, File;

import 'package:font_subset/font_subset.dart';
import 'package:test/test.dart';

/// Roboto Regular subset containing the three glyphs `h` (104), `k` (107),
/// and `o` (111).
const String _kRobotoThreeGlyphFontBase64 =
    'AAEAAAAPAIAAAwBwT1MvMnRvghoAAAJoAAAAYGNtYXAAfwFBAAAB0AAAAERj'
    'dnQgK6gHnQAAAhQAAABUZnBnbXf4YKsAAAUoAAABvGdhc3AACAATAAABCAAA'
    'AAxnbHlmm9QWxQAABuQAAAHYaGRteA4KBA4AAAEUAAAAEGhlYWT8atJ6AAAB'
    'mAAAADZoaGVhCroFpAAAAXQAAAAkaG10eBCSAdgAAAEkAAAAEGxvY2EBMgCd'
    'AAAA/AAAAAptYXhwAjQDCQAAATQAAAAgbmFtZRIELQQAAALIAAABFHBvc3T/'
    'bQBkAAABVAAAACBwcmVwomb6yQAAA9wAAAFJAAAAAABGAJ0A7AAAAAEAAgAI'
    'AAL//wAPAAAAAQAAAAgJBQQFBQUAAAOMAGQEaACMBA4AjQSQAFsAAQAAAAQA'
    'jwAWAFQABQABAAAAAAAOAAACAAIkAAYAAQADAAAAAAAA/2oAZAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAEAAAds/gwAAAlJ+hv+SgkwAAEAAAAAAAAAAAAAAAAA'
    'AAAEAAEAAAACIxJ4oEfFXw889QAZCAAAAAAAxPARLgAAAADVAVL0+hv91Qkw'
    'CHMAAAAJAAIAAAAAAAAAAAACAAAAAwAAABQAAwABAAAAFAAEADAAAAAIAAgA'
    'AgAAAGgAawBv//8AAABoAGsAb////5n/l/+UAAEAAAAAAAAAAAAqAJ0AgACK'
    'AHgA1ABkAE4AWgCHAGAAVgA0AjwAvACyAI4AxAAAABT+YAAUApsAIAMhAAsE'
    'OgAUBI0AEAWwABQGGAAVAaYAEQbAAA4G2QAGAAAAAAADBIYBkAAFAAAFmgUz'
    'AAABHwWaBTMAAAPRAGYCAAAAAgAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAABH'
    'T09HAEAAaABvBgD+AABmB5oCACAAAZ8AAAAABDoFsAAgACAAAwAAAAcAWgAD'
    'AAEECQAAAF4AXAADAAEECQABAAwAUAADAAEECQACAA4AQgADAAEECQADAAwA'
    'UAADAAEECQAEAAwAUAADAAEECQAFACYAHAADAAEECQAGABwAAABSAG8AYgBv'
    'AHQAbwAtAFIAZQBnAHUAbABhAHIAVgBlAHIAcwBpAG8AbgAgADIALgAxADMA'
    'NwA7ACAAMgAwADEANwBSAGUAZwB1AGwAYQByAFIAbwBiAG8AdABvAEMAbwBw'
    'AHkAcgBpAGcAaAB0ACAAMgAwADEAMQAgAEcAbwBvAGcAbABlACAASQBuAGMA'
    'LgAgAEEAbABsACAAUgBpAGcAaAB0AHMAIABSAGUAcwBlAHIAdgBlAGQALrAM'
    'K7AAKwCyARACKwGyEQECKwG3ETowJRsQAAgrALcBSDsuIRQACCu3AlhIOCgU'
    'AAgrtwNSQzQlFgAIK7cEXk08KxkACCu3BTYsIhkPAAgrtwZxXUYyGwAIK7cH'
    'kXdcOiMACCu3CH5nUDkaAAgrtwlURTYmFAAIK7cKdmBLNh0ACCu3C4NkTjoj'
    'AAgrtwzZsopjPAAIK7cNFBAMCQYACCu3DjwyJxwRAAgrtw9ANCkdFAAIK7cQ'
    'UEEuIRQACCsAshILByuwACBFfWkYRLI/GgFzsl8aAXOyfxoBc7IvGgF0sk8a'
    'AXSybxoBdLKPGgF0sq8aAXSy/xoBdLIfGgF1sj8aAXWyXxoBdbJ/GgF1sg8e'
    'AXOyfx4Bc7LvHgFzsh8eAXSyXx4BdLKPHgF0ss8eAXSy/x4BdLI/HgF1sm8e'
    'AXWyLyABc7JvIAFzAAAAsAAsS7AJUFixAQGOWbgB/4WwhB2xCQNfXi2wASwg'
    'IEVpRLABYC2wAiywASohLbADLCBGsAMlRlJYI1kgiiCKSWSKIEYgaGFksAQl'
    'RiBoYWRSWCNlilkvILAAU1hpILAAVFghsEBZG2kgsABUWCGwQGVZWTotsAQs'
    'IEawBCVGUlgjilkgRiBqYWSwBCVGIGphZFJYI4pZL/0tsAUsSyCwAyZQWFFY'
    'sIBEG7BARFkbISEgRbDAUFiwwEQbIVlZLbAGLCAgRWlEsAFgICBFfWkYRLAB'
    'YC2wByywBiotsAgsSyCwAyZTWLBAG7AAWYqKILADJlNYIyGwgIqKG4ojWSCw'
    'AyZTWCMhsMCKihuKI1kgsAMmU1gjIbgBAIqKG4ojWSCwAyZTWCMhuAFAioob'
    'iiNZILADJlNYsAMlRbgBgFBYIyG4AYAjIRuwAyVFIyEjIVkbIVlELbAJLEtT'
    'WEVEGyEhWS2wCiywKEUtsAsssClFLbAMLLEnAYggilNYuUAABABjuAgAiFRY'
    'uQAoA+hwWRuwI1NYsCCIuBAAVFi5ACgD6HBZWVktsA0ssECIuCAAWlixKQBE'
    'G7kAKQPoRFktAAEAjAAAA98GAAARAEqyChITERI5ALAQL7AARViwAi8bsQIa'
    'PlmwAEVYsAUvG7EFEj5ZsABFWLAOLxuxDhI+WbIAAgUREjmwAhCxCgGwCitY'
    'Idgb9FkwMQE2MyATESMRJiYjIgYHESMRMwFFe8UBVwO5AWlvWogmubkDt5f+'
    'ff01Asx1cGBO/P0GAAAAAQCNAAAEDAYAAAwAdQCwAEVYsAQvG7EEID5ZsABF'
    'WLAILxuxCBo+WbAARViwAi8bsQISPlmwAEVYsAsvG7ELEj5ZsgAIAhESOUAV'
    'OgBKAFoAagB6AIoAmgCqALoAygAKXbIGCAIREjlAFTYGRgZWBmYGdgaGBpYG'
    'pga2BsYGCl0wMQEHESMRMxE3ATMBASMBunS5uWMBUeH+WwHW2QH1ef6EBgD8'
    'X3cBZP48/YoAAgBb/+wENAROAA8AGwBFsgwcHRESObAMELAT0ACwAEVYsAQv'
    'G7EEGj5ZsABFWLAMLxuxDBI+WbETAbAKK1gh2Bv0WbAEELEZAbAKK1gh2Bv0'
    'WTAxEzQ2NjMyABUVFAYGIyIANRcUFjMyNjU0JiMiBlt934/dARF54ZLc/u+6'
    'p4yNpqmMiagCJ5/+iv7O/g2e+4wBMvwJtNrdx7Ld2g==';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('font_subset_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('fontSubsetExecutable', () {
    test('resolves bundled executable for all supported host ABIs', () async {
      for (final abi in <Abi>[
        Abi.linuxX64,
        Abi.linuxArm64,
        Abi.macosX64,
        Abi.macosArm64,
        Abi.windowsX64,
        Abi.windowsArm64,
      ]) {
        final exe = await fontSubsetExecutable(abi: abi);
        expect(exe.existsSync(), isTrue, reason: 'Missing binary for $abi');
      }
    });

    test('throws FontSubsetException for unsupported ABI', () async {
      await expectLater(
        fontSubsetExecutable(abi: Abi.androidArm64),
        throwsA(isA<FontSubsetException>()),
      );
    });
  });

  group('isSupportedFontFile', () {
    test(
      'returns true for valid TTF font and false for invalid files',
      () async {
        final fontFile = File('${tempDir.path}/Roboto.ttf')
          ..writeAsBytesSync(base64Decode(_kRobotoThreeGlyphFontBase64));
        expect(await isSupportedFontFile(fontFile), isTrue);

        final tooShort = File('${tempDir.path}/short.ttf')
          ..writeAsBytesSync(<int>[1, 2, 3]);
        expect(await isSupportedFontFile(tooShort), isFalse);

        final textFile = File('${tempDir.path}/not_a_font.txt')
          ..writeAsStringSync('not a valid font header at all');
        expect(await isSupportedFontFile(textFile), isFalse);

        final missingFile = File('${tempDir.path}/does_not_exist.ttf');
        expect(await isSupportedFontFile(missingFile), isFalse);
      },
    );
  });

  group('subsetFont', () {
    test('subsets 3-glyph TTF down to 1 glyph and reports reduction', () async {
      final inputFile = File('${tempDir.path}/input.ttf')
        ..writeAsBytesSync(base64Decode(_kRobotoThreeGlyphFontBase64));
      final outputFile = File('${tempDir.path}/out/subset.ttf');

      final result = await subsetFont(
        input: inputFile,
        output: outputFile,
        codePoints: const <int>[104], // 'h'
        optionalCodePoints: const <int>[32], // absent optional space
      );

      expect(outputFile.existsSync(), isTrue);
      expect(await isSupportedFontFile(outputFile), isTrue);
      expect(result.inputSize, inputFile.lengthSync());
      expect(result.outputSize, outputFile.lengthSync());
      expect(result.outputSize, lessThan(result.inputSize));
      expect(result.reductionBytes, greaterThan(0));
      expect(result.reductionPercentage, greaterThan(0));
      expect(result.summaryMessage, contains('was tree-shaken'));
    });

    test('throws FontSubsetException when codePoints are empty', () async {
      final inputFile = File('${tempDir.path}/input.ttf')
        ..writeAsBytesSync(base64Decode(_kRobotoThreeGlyphFontBase64));
      final outputFile = File('${tempDir.path}/subset.ttf');

      await expectLater(
        subsetFont(
          input: inputFile,
          output: outputFile,
          codePoints: const <int>[],
        ),
        throwsA(isA<FontSubsetException>()),
      );
    });

    test('throws FontSubsetException when codepoint is not in font', () async {
      final inputFile = File('${tempDir.path}/input.ttf')
        ..writeAsBytesSync(base64Decode(_kRobotoThreeGlyphFontBase64));
      final outputFile = File('${tempDir.path}/subset.ttf');

      await expectLater(
        subsetFont(
          input: inputFile,
          output: outputFile,
          codePoints: const <int>[0xe047], // not in the 3-glyph font
        ),
        throwsA(
          isA<FontSubsetException>().having(
            (e) => e.exitCode,
            'exitCode',
            isNotNull,
          ),
        ),
      );
    });
  });
}
