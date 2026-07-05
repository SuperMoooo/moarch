# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

Found by actually running `moarch init --all` + `moarch create feature --all` against a real `flutter create` project and checking `flutter pub get` / `flutter analyze` — several of these meant the documented quick-start flow didn't compile out of the box.

- **`PubspecUtils._ensureSection` corrupted `pubspec.yaml`.** It misread the nested `sdk: flutter` line under `flutter:` (present in every `flutter create` project) as the end of the `dependencies:` section, so all new dependencies were inserted in the wrong place and produced a duplicate YAML key that made `flutter pub get` fail outright.
- Generated `app_router.dart` referenced an undefined `authNotifierProvider` and `AppRoutes.login` (which is commented out by default) — a fresh `moarch init --all` project never compiled. The auth-guard redirect is now documented as an opt-in commented example instead of active code.
- Generated `dio_client.dart` referenced `AppEnv.prodBaseUrl` / `AppEnv.devBaseUrl`, which don't exist on the generated `AppEnv` (only `baseUrl` does).
- Generated `safe_api_call.dart` had a stray `~` character right after the opening string literal, which was a syntax error.
- Generated `connectivity_service.dart` imported a garbled path (`core/utils/appappLogger.iger.dart`) and called an undefined top-level `log()` instead of `appLogger`.
- Generated `media_service.dart` called `FilePicker.pickFiles(...)` statically; `pickFiles` is an instance method on `FilePicker.platform`.
- Generated use case (`get_<name>.dart`) imported a `core/usecases/usecase.dart` base class that is never generated anywhere, and its import path to `repository_impl.dart` had one extra `../`. Use cases are now self-contained (no missing base class) with corrected import depth.
- Generated repository interface/impl never declared the `getAll()` method that the generated use case called against it.
- Generated notifier (`<name>_notifier.dart`) only imported the repository provider when "Use Cases" was _not_ selected, so `authRepositoryProvider` was undefined whenever use cases were included (the notifier's `_repo` getter needs it either way).
- Generated `<name>_remote_datasource.dart` called `safeApiCall` without importing the file that defines it.
- `create feature <name>` with the "Local/Cache Datasource" layer selected wrote the connectivity service to the wrong path and passed the wrong variable name into the generated datasource (swapped arguments).
- Generated `AppImage` widget had a syntax error (`?.isValidUrl != null` with no receiver).
- Generated `AppAvatar` / `AppImage` widgets checked a method tear-off instead of calling `isValidUrl()`, so an invalid URL was never actually detected.

### Added

- CI workflow (`dart analyze`, `dart format --set-exit-if-changed`, `dart test`, `dart pub publish --dry-run`) on push/PR to `main`.
- `moarch doctor` command to sanity-check an existing scaffolded project.
- `--dry-run` flag on `moarch init` to preview generated files without writing them.
- `--verbose` flag to print stack traces on unexpected errors.
- Per-item descriptions and a quit option (`q`) in the interactive checklist prompt.
- Real dark theme (`AppTheme.dark`) instead of an empty stub, with matching dark color tokens in `AppConstants`.
- Dark-mode variant in the generated `flutter_native_splash.yaml`.

### Changed

- `init` and `create feature`/`create model` now roll back files they created if scaffolding fails partway through, instead of leaving the target project in a half-generated state. `init` also restores the original `pubspec.yaml` on failure.
- CLI version string is now read from a single source (`lib/src/version.dart`) instead of being hardcoded in `runner.dart`.

### Known gaps (not addressed this round — out of scope)

- The generated `test/test_helper.dart` references `mocktail`, which isn't declared as a dependency, so it doesn't compile as-is. Left untouched since testing scaffolding is handled by the separate `mogen_unit_tests`/`mogen_integration_tests` packages.

## [1.6.5]

### Fixed

- Various scaffold generation fixes.
