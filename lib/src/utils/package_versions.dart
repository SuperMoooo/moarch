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
    'equatable': '^2.1.0',

    // ── Core ────────────────────────────────────────────────────────────────
    'get_it': '^9.2.1',
    'flutter_native_splash': '^2.4.8',
    'envied': '^1.3.8',
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

    // ── Network ─────────────────────────────────────────────────────────────
    'go_router': '^17.5.0',
    'dio': '^5.11.0',
    'dio_smart_retry': '^7.0.1',
    'flutter_secure_storage': '^11.0.0',

    // ── Firebase ────────────────────────────────────────────────────────────
    'firebase_core': '^4.13.0',
    'firebase_messaging': '^16.5.0',
    'firebase_crashlytics': '^5.2.7',
    'firebase_auth': '^6.5.7',
    'cloud_firestore': '^6.8.0',
    // Floored because the generated Google flow is written against the 7.x
    // API — `GoogleSignIn.instance`, `initialize()` and `authenticate()`
    // replaced the constructor and `signIn()` of 6.x.
    'google_sign_in': '^7.0.0',

    // ── Device ──────────────────────────────────────────────────────────────
    // Held at 11: 12 pulls a win32 chain that conflicts with
    // flutter_secure_storage_windows.
    'file_picker': '^11.0.0',
    'image_picker': '^1.2.3',
    // Capped: permission_handler 13 pulls an android impl written against
    // AGP 9 / Gradle 9, which fails to compile on the AGP 8 toolchain
    // `flutter create` still scaffolds. The API is unchanged across the two.
    'permission_handler': '^12.0.3',
    'url_launcher': '^6.3.2',
    'flutter_local_notifications': '^22.3.0',
    'timezone': '^0.11.1',
    'local_auth': '^3.0.2',
    'local_auth_android': '^2.0.9',
    'local_auth_darwin': '^2.0.3',
    'easy_localization': '^3.0.8',

    // ── Dev ─────────────────────────────────────────────────────────────────
    'build_runner': '^2.16.0',
    'envied_generator': '^1.3.8',
    'flutter_lints': '^6.0.0',
    'bloc_lint': '^0.4.2',
    'mogen_unit_tests': '^1.4.2',
    'mogen_integration_tests': '^1.1.2',
  };
}
