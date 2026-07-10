/// Single source of truth for the CLI version string.
///
/// Keep this in sync with the `version:` field in `pubspec.yaml` — it can't
/// be read from the pubspec at runtime once the package is globally
/// activated, so it's duplicated here.
const packageVersion = '1.7.7';
