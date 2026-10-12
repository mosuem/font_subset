## 0.2.1

- Remove redundant `BuildModeEnum.build` alias so `BuildModeEnum` strictly has
  `fetch`, `checkout`, and `local` (with optional `checkoutPath`).
- Use `package:crypto` for SHA-256 checksum verification.

## 0.2.0

- Remove checked-in binaries from the package archive; instead build
  `font-subset` from bundled C++/HarfBuzz sources via CMake or fetch SHA-256
  verified prebuilt binaries from GitHub Releases.
- Add `hook/build.dart` and `BuildOptions` supporting `fetch`, `checkout`, and
  `local` build modes via `hooks.user_defines.font_subset` or
  `FONT_SUBSET_BUILD_MODE`.
- Add `tool/precompile_binaries.dart`, `tool/regenerate_hashes.dart`,
  `tool/bump-harfbuzz-revision.sh`, and GitHub Actions CI & release workflows.

## 0.1.0

- Initial release with Dart wrapper API (`subsetFont`,
  `fontSubsetExecutable`, `isSupportedFontFile`).
