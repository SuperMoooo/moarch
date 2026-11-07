/// The version constraint moarch writes for each package it adds to a
/// generated project.
///
/// Constraints rather than `any`, because the templates are written against a
/// specific API. `any` lets the next `pub get` in CI pick up a major release
/// of `dio` or `go_router` and break generated code that nobody touched, and
/// it costs a pub.dev score point on top. A caret keeps the project inside the
/// major version the templates target while still taking patches and minors.
///
/// Bumping is a release chore: raise the entries here, regenerate a project
/// and make sure it still builds. That is one file to review per release,
/// rather than a surprise per developer.
library;

/// Version constraints for the packages moarch adds to generated projects.
abstract final class PackageVersions {
  /// The constraint for [package], as it is written into `pubspec.yaml`.
  ///
  /// Falls back to `any` for a package the table does not know, so adding a
  /// dependency to `init` without touching this file degrades to the old
  /// behaviour rather than throwing.
  static String constraintFor(String package) => _constraints[package] ?? 'any';

  /// A whole `pubspec.yaml` dependency line, e.g. `dio: ^5.11.0`.
  static String entry(String package) => '$package: ${constraintFor(package)}';

  /// Every package this table pins. Exposed for the test that keeps it in
  /// step with what `init` actually adds.
  static Iterable<String> get packages => _constraints.keys;

  static const _constraints = <String, String>{
    // ── State management ────────────────────────────────────────────────────
    'flutter_riverpod': '^3.4.2',
    'flutter_bloc': '^9.1.1',
    'bloc': '^9.2.1',
    'equatable': '^3.0.0',
    'bloc_concurrency': '^0.3.0',

    // ── Core ────────────────────────────────────────────────────────────────
    'get_it': '^9.3.0',
    'flutter_native_splash': '^2.4.8',
    'envied': '^1.3.10',
    'skeletonizer': '^2.1.3',
    // Deliberately unconstrained, and the only one: `flutter_localizations`
    // depends on an exact `intl` from the Flutter SDK, so any caret here
    // eventually fails to resolve against a Flutter version that wants a
    // different one. Let pub take whatever the SDK allows.
    'intl': 'any',
    // Floored because app_logger.dart uses PrettyPrinter's `dateTimeFormat`,
    // which replaced the older `printTime` flag partway through logger 2.x.
    'logger': '^2.4.0',
    'connectivity_plus': '^7.3.1',
    // Floored for SharedPreferencesWithCache, which preferences_service.dart
    // is built on: loaded once, then read synchronously.
    'shared_preferences': '^2.5.5',

    // ── Codegen (models) ───────────────────────────────────────
    // The annotations are runtime dependencies — the generated `.freezed.dart`
    // and `.g.dart` parts reference them — while the generators below are
    // dev-only.
    //
    // freezed 4 still uses the 3.x annotations.
    'freezed_annotation': '^3.1.0',
    'json_annotation': '^4.12.0',

    // ── Network ─────────────────────────────────────────────────────────────
    'go_router': '^17.5.0',
    'dio': '^5.11.1',
    'dio_smart_retry': '^7.0.1',
    'flutter_secure_storage': '^11.2.0',

    // ── Offline-first cache ─────────────────────────────────────────────────
    // Floored at the drift_dev that takes analyzer 14, the line freezed 4
    // needs. `create table` writes `@UseRowClass` tables, which drift has
    // supported for freezed classes since well before this.
    'drift': '^2.35.3',
    'drift_flutter': '^0.3.1',
    'drift_dev': '^2.35.2',
    // Floored at the 0.10 line, where the plugin registers the iOS task
    // handler itself: background_sync.dart and SYNC_SETUP.md rely on
    // AppDelegate.swift needing no change. Needs Flutter 3.38+.
    'workmanager': '^0.10.10',

    // ── Firebase ────────────────────────────────────────────────────────────
    'firebase_core': '^4.15.0',
    'firebase_messaging': '^16.7.0',
    'firebase_crashlytics': '^5.4.0',
    'firebase_auth': '^6.7.0',
    'cloud_firestore': '^6.10.0',
    // Floored because the generated Google flow is written against the 7.x
    // API — `GoogleSignIn.instance`, `initialize()` and `authenticate()`
    // replaced the constructor and `signIn()` of 6.x.
    'google_sign_in': '^7.2.0',
    // The REST auth feature's Apple sheet. Floored at 8, the line on Flutter
    // 3.44+ that the generated datasource is written against.
    'sign_in_with_apple': '^8.0.0',

    // ── Device ──────────────────────────────────────────────────────────────
    // Floored at 12, which is where file_picker stopped depending on win32
    // directly. Up to 11 it pinned `win32 ^5.9.0`, and flutter_secure_storage
    // 11 reaches `win32 ^6.0.1` through flutter_secure_storage_windows — the
    // two simply do not resolve together. 12 also drops `FilePickerResult`:
    // `pickFiles` returns the `List<PlatformFile>` directly, which is what
    // `media_service.dart` is written against.
    'file_picker': '^12.0.0',
    'image_picker': '^1.2.3',
    // Capped: permission_handler 13 pulls an android impl written against
    // AGP 9 / Gradle 9, which fails to compile on the AGP 8 toolchain
    // `flutter create` still scaffolds. The API is unchanged across the two.
    'permission_handler': '^12.0.3',
    'url_launcher': '^6.3.2',
    // The installed version the update gate compares against the backend's
    // minimum.
    'package_info_plus': '^10.2.1',
    'flutter_local_notifications': '^22.3.0',
    'timezone': '^0.11.1',
    'local_auth': '^3.0.2',
    'local_auth_android': '^2.0.9',
    'local_auth_darwin': '^2.0.3',
    'easy_localization': '^3.0.8',

    // ── Dev ─────────────────────────────────────────────────────────────────
    // Floored at the first build_runner on analyzer 13.3, where freezed 4
    // starts. Not higher: 2.17.1 moved to `build` 5 while envied_generator
    // still wants `build` ^4, so pub has to be able to back off to 2.17.0.
    'build_runner': '^2.15.2',
    'envied_generator': '^1.3.10',
    // freezed 4 needs Dart 3.13 (Flutter 3.47), what `stable` in .fvmrc
    // resolves to since August 2026. The class shape moarch writes is the
    // same as in 3.x.
    'freezed': '^4.0.1',
    'json_serializable': '^6.15.2',
    'flutter_lints': '^6.0.0',
    // 0.4.3 caps `_fe_analyzer_shared` at 108, so in a bloc project pub holds
    // analyzer at 13.3 — the reason freezed is floored at 4.0.1, the last
    // that takes analyzer 13. Raise both when a bloc_lint takes a newer one.
    'bloc_lint': '^0.4.2',
    // What the tests `moarch create tests` writes import. The generator runs
    // inside moarch, so unlike the mogen packages it replaced it adds no
    // analyzer to the app's dependency graph.
    'mocktail': '^1.0.5',
    'bloc_test': '^10.0.0',
  };
}
