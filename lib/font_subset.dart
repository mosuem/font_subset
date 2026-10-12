/// Builds or fetches the Flutter `font-subset` binary and provides a Dart API
/// for subsetting TTF and OTF fonts.
library;

export 'src/font_subset_base.dart'
    show
        FontSubsetException,
        FontSubsetResult,
        fontSubsetExecutable,
        isSupportedFontFile,
        kSupportedFontMimeTypes,
        subsetFont;
export 'src/hook_helpers/build_options.dart' show BuildModeEnum, BuildOptions;
