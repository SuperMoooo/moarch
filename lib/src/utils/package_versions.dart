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
    // ── Design libraries ────────────────────────────────────────────────────
    // Material and Cupertino left the framework in Flutter 3.47 and the
    // in-framework copies are deprecated from 3.50: every generated file
    // imports these two instead of `package:flutter/material.dart`. Floored
    // at the line that needs Flutter 3.47, the `.fvmrc` pin.
    'material_ui': '^1.11.0',
    'cupertino_ui': '^1.1.6',

    // ── State management ────────────────────────────────────────────────────
    'flutter_riverpod': '^3.5.0',
    'flutter_bloc': '^9.1.1',
    'bloc': '^9.2.1',
    'equatable': '^3.0.0',
    'bloc_concurrency': '^0.3.0',

    // ── Core ────────────────────────────────────────────────────────────────
    'get_it': '^9.3.0',
    'flutter_native_splash': '^2.4.8',
    // Dev only: makes the icons once, nothing of it ships in the app.
    'flutter_launcher_icons': '^0.14.4',
    'envied': '^1.3.10',
    'skeletonizer': '^3.0.0',
    // Deliberately unconstrained, and the only one: `flutter_localizations`
    // depends on an exact `intl` from the Flutter SDK, so any caret here
    // eventually fails to resolve against a Flutter version that wants a
    // different one. Let pub take whatever the SDK allows.
    'intl': 'any',
    // Floored because app_logger.dart uses PrettyPrinter's `dateTimeFormat`,
    // which replaced the older `printTime` flag partway through logger 2.x.
    'logger': '^2.8.0',
    'connectivity_plus': '^7.3.2',
    // Floored for SharedPreferencesWithCache, which preferences_service.dart
    // is built on: loaded once, then read synchronously.
    'shared_preferences': '^2.5.6',

    // ── Codegen (models) ───────────────────────────────────────
    // The annotations are runtime dependencies — the generated `.freezed.dart`
    // and `.g.dart` parts reference them — while the generators below are
    // dev-only.
    //
    // freezed 4 still uses the 3.x annotations.
    'freezed_annotation': '^3.1.0',
    'json_annotation': '^4.12.0',

    // ── Network ─────────────────────────────────────────────────────────────
    'go_router': '^18.1.4',
    'dio': '^5.11.1',
    'dio_smart_retry': '^7.0.1',
    'flutter_secure_storage': '^11.2.0',

    // ── Offline-first cache ─────────────────────────────────────────────────
    // Floored at the drift_dev that takes analyzer 14, the line freezed 4
    // needs. `create table` writes `@UseRowClass` tables, which drift has
    // supported for freezed classes since well before this.
    'drift': '^2.35.4',
    'drift_flutter': '^0.3.1',
    'drift_dev': '^2.35.3',
    // Where the encrypted database's file is, so a key-less one can be
    // deleted. drift_flutter already depends on it.
    'path_provider': '^2.1.5',
    // Floored at the 0.10 line, where the plugin registers the iOS task
    // handler itself: background_sync.dart and SYNC_SETUP.md rely on
    // AppDelegate.swift needing no change. Needs Flutter 3.38+.
    'workmanager': '^0.10.10',

    // ── Firebase ────────────────────────────────────────────────────────────
    'firebase_core': '^5.1.0',
    'firebase_messaging': '^17.0.1',
    'firebase_crashlytics': '^6.0.1',
    'firebase_analytics': '^13.0.1',
    'firebase_auth': '^7.0.1',
    'cloud_firestore': '^7.1.0',
    // Floored because the generated Google flow is written against the 7.x
    // API — `GoogleSignIn.instance`, `initialize()` and `authenticate()`
    // replaced the constructor and `signIn()` of 6.x.
    'google_sign_in': '^7.2.0',
    // The REST auth feature's Apple sheet. Floored at 8, the line on Flutter
    // 3.44+ that the generated datasource is written against.
    'sign_in_with_apple': '^8.2.0',

    // ── Device ──────────────────────────────────────────────────────────────
    // 12 is where file_picker stopped depending on win32 directly (up to 11
    // it clashed with flutter_secure_storage 11 over it) and dropped
    // `FilePickerResult`; 13 only removes the parameters 12 had deprecated
    // and makes `PlatformFile.length()` nullable, neither of which
    // `media_service.dart` touches.
    'file_picker': '^13.3.3',
    'image_picker': '^1.2.4',
    // 13 compiles against API 37, as does flutter_local_notifications 23:
    // `init` floors `compileSdk` there (`GradleUtils.requiredCompileSdk`),
    // and the AGP 9 toolchain it is written for is what Flutter 3.47
    // scaffolds.
    'permission_handler': '^13.0.2',
    'url_launcher': '^6.3.3',
    // The installed version the update gate compares against the backend's
    // minimum.
    'package_info_plus': '^10.2.2',
    'flutter_local_notifications': '^23.0.0',
    'timezone': '^0.11.2',
    'local_auth': '^3.0.2',
    'local_auth_android': '^2.0.9',
    'local_auth_darwin': '^2.0.3',
    'easy_localization': '^3.0.8',

    // ── UI kit (`moarch create widget`) ─────────────────────────────────────
    // The widget specs name these bare; `PubspecUtils` resolves them here.
    // cached_network_image 4 is the material_ui line.
    'cached_network_image': '^4.0.6',
    'table_calendar': '^3.3.0',
    'just_audio': '^0.10.6',

    // ── Flavors (`moarch create flavors`) ───────────────────────────────────
    'flutter_flavorizr': '^2.6.0',

    // ── Dev ─────────────────────────────────────────────────────────────────
    // Floored at the first build_runner on analyzer 13.3, where freezed 4
    // starts. Not higher: 2.17.1 moved to `build` 5 while envied_generator
    // still wants `build` ^4, so pub has to be able to back off to 2.17.0.
    'build_runner': '^2.15.2',
    'envied_generator': '^1.3.10',
    // freezed 4 needs Dart 3.13 (Flutter 3.47), the line the .fvmrc pin
    // (`DevTemplates.flutterVersion`) is on. The class shape moarch writes is the
    // same as in 3.x.
    'freezed': '^4.0.1',
    'json_serializable': '^6.15.2',
    'flutter_lints': '^6.0.0',
    // 0.4.3 caps `_fe_analyzer_shared` at 108, so in a bloc project pub holds
    // analyzer at 13.3 — the reason freezed is floored at 4.0.1, the last
    // that takes analyzer 13. Raise both when a bloc_lint takes a newer one.
    'bloc_lint': '^0.4.3',
    // What the tests `moarch create tests` writes import. The generator runs
    // inside moarch, so unlike the mogen packages it replaced it adds no
    // analyzer to the app's dependency graph.
    'mocktail': '^1.0.5',
    'bloc_test': '^10.0.0',
  };
}
