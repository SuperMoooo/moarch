import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_utils.dart';
import 'injector_utils.dart';
import 'plist_utils.dart';
import 'project_manifest.dart';
import 'pubspec_utils.dart';
import 'state_management.dart';
import 'widget_catalog.dart';

/// How much a [Diagnostic] matters.
enum DiagnosticSeverity {
  /// The project is broken or will not build as generated.
  error,

  /// Works, but something is inconsistent or half-configured.
  warning,

  /// Informational — nothing is wrong.
  info,
}

/// Applies a fix for a [Diagnostic], returning a description of what it did.
typedef DiagnosticFix = Future<String> Function();

/// One finding from [ProjectInspector.inspect].
class Diagnostic {
  /// Creates a diagnostic.
  const Diagnostic({
    required this.severity,
    required this.message,
    this.hint,
    this.fix,
  });

  /// An error-level finding.
  const Diagnostic.error(this.message, {this.hint, this.fix})
      : severity = DiagnosticSeverity.error;

  /// A warning-level finding.
  const Diagnostic.warning(this.message, {this.hint, this.fix})
      : severity = DiagnosticSeverity.warning;

  /// How much this finding matters.
  final DiagnosticSeverity severity;

  /// One-line description of what is wrong.
  final String message;

  /// What the user should do about it, when there is no automatic fix.
  final String? hint;

  /// Applies the fix, or null when this needs a human decision.
  final DiagnosticFix? fix;

  /// Whether `doctor --fix` can resolve this without asking.
  bool get isFixable => fix != null;
}

/// Inspects a project previously scaffolded by moarch: `doctor` reports and
/// fixes the findings, `update` reuses the widget detection.
abstract final class ProjectInspector {
  /// Every check, in reporting order.
  ///
  /// Structural checks come first because a missing `lib/core/` makes the
  /// widget and dependency findings below it noise rather than signal.
  static Future<List<Diagnostic>> inspect(String projectRoot) async {
    final root = p.absolute(projectRoot);
    final libPath = p.join(root, 'lib');
    final pubspecFile = File(p.join(root, 'pubspec.yaml'));
    final pubspec =
        pubspecFile.existsSync() ? pubspecFile.readAsStringSync() : null;

    return [
      ..._structure(root, libPath),
      ..._fvm(root),
      if (pubspec != null) ..._dependencies(libPath, pubspec),
      if (pubspec != null) ..._firebase(root, libPath, pubspec),
      if (pubspec != null) ..._localization(libPath, pubspec),
      ..._codegen(libPath),
      ..._widgets(root, libPath, pubspec),
    ];
  }

  // ── Structure ───────────────────────────────────────────────────────────────

  static List<Diagnostic> _structure(String root, String libPath) {
    final expected = <String, bool>{
      'lib/core/': Directory(p.join(libPath, 'core')).existsSync(),
      'lib/config/': Directory(p.join(libPath, 'config')).existsSync(),
      'lib/shared/': Directory(p.join(libPath, 'shared')).existsSync(),
      'lib/main.dart': File(p.join(libPath, 'main.dart')).existsSync(),
      'pubspec.yaml': File(p.join(root, 'pubspec.yaml')).existsSync(),
      '.env': File(p.join(root, '.env')).existsSync(),
      '.fvmrc': File(p.join(root, '.fvmrc')).existsSync(),
    };

    return [
      for (final entry in expected.entries)
        if (!entry.value)
          Diagnostic.error(
            '${entry.key} is missing',
            hint: 'Run `moarch init` to scaffold it.',
          ),
    ];
  }

  // ── FVM ─────────────────────────────────────────────────────────────────────

  /// Matches the `dart.flutterSdkPath` entry in `.vscode/settings.json`.
  ///
  /// Parsed by hand rather than with `jsonDecode`: the generated file is JSONC
  /// — the comments explaining the setting would make decoding throw.
  static final RegExp _sdkPathPattern =
      RegExp(r'"dart\.flutterSdkPath"\s*:\s*"([^"]*)"');

  /// The editor half of the FVM pin.
  ///
  /// A `dart.flutterSdkPath` that points nowhere is the worst case here and
  /// the reason these checks exist: the Dart extension does not error on it,
  /// it silently falls back to the first Flutter on PATH. Debug runs, hot
  /// reload and the analyzer then all use the SDK `.fvmrc` exists to avoid,
  /// and the only symptom is analyzer output that disagrees with
  /// `fvm flutter analyze`.
  static List<Diagnostic> _fvm(String root) {
    // Not an fvm project — `_structure` already reports the missing .fvmrc.
    if (!File(p.join(root, '.fvmrc')).existsSync()) return const [];

    final findings = <Diagnostic>[];
    final settingsFile = File(p.join(root, '.vscode', 'settings.json'));
    if (!settingsFile.existsSync()) {
      return [
        const Diagnostic.warning(
          '.vscode/settings.json is missing, so the editor ignores .fvmrc',
          hint: 'Run `moarch init` to scaffold it, or set '
              '"dart.flutterSdkPath": ".fvm/flutter_sdk" yourself.',
        ),
      ];
    }

    final settings = settingsFile.readAsStringSync();
    final configured = _sdkPathPattern.firstMatch(settings)?.group(1);
    if (configured == null) {
      return [
        const Diagnostic.warning(
          '.vscode/settings.json has no dart.flutterSdkPath, so the editor '
          'runs whatever Flutter is on PATH',
          hint: 'Add "dart.flutterSdkPath": ".fvm/flutter_sdk" — without it '
              'the .fvmrc pin only applies to `fvm flutter` on the CLI.',
        ),
      ];
    }

    // `fvm use` rewrites the setting to the resolved version — .fvm/versions/
    // <version> — which pins the editor a second time, in a second place, and
    // silently stops tracking .fvmrc the next time the pin changes.
    if (configured.contains('.fvm/versions/')) {
      findings.add(
        Diagnostic.warning(
          'dart.flutterSdkPath is "$configured", a versioned path that stops '
          'following .fvmrc',
          hint: 'Point it at ".fvm/flutter_sdk" instead — that symlink '
              'follows the pin, so switching SDKs needs no editor change.',
          fix: () async {
            await settingsFile.writeAsString(
              settings.replaceFirst(
                _sdkPathPattern,
                '"dart.flutterSdkPath": ".fvm/flutter_sdk"',
              ),
            );
            return 'pointed dart.flutterSdkPath back at .fvm/flutter_sdk '
                '(reload the VS Code window)';
          },
        ),
      );
    }

    // Only a project-relative path is ours to check — an absolute one is a
    // deliberate override of the pin.
    if (p.isAbsolute(configured)) return findings;

    final sdkPath = p.join(root, p.normalize(configured));
    final linked = FileSystemEntity.typeSync(sdkPath, followLinks: false) !=
        FileSystemEntityType.notFound;
    if (!linked) {
      findings.add(
        Diagnostic.error(
          'dart.flutterSdkPath points at $configured, which does not exist — '
          'the editor is silently using the Flutter on your PATH',
          hint: 'Run `fvm use` in the project root to create it, then reload '
              'the VS Code window. `.fvm/` is gitignored, so every fresh '
              'clone needs this once.',
        ),
      );
    } else if (!Directory(sdkPath).existsSync()) {
      // The symlink survived but its target did not — usually the pinned
      // version was removed from the fvm cache.
      findings.add(
        Diagnostic.error(
          '$configured is a dangling link — the pinned SDK is not installed',
          hint: 'Run `fvm install` to restore the version .fvmrc pins, then '
              'reload the VS Code window.',
        ),
      );
    }

    return findings;
  }

  // ── Dependencies ────────────────────────────────────────────────────────────

  static List<Diagnostic> _dependencies(String libPath, String pubspec) {
    final stateManagement = StateManagement.fromPubspec(pubspec);

    final findings = <Diagnostic>[
      // Both stacks: get_it is the DI in either. What follows the stack is
      // only the state-management package beside it.
      if (!pubspec.contains('get_it:'))
        const Diagnostic.error(
          'get_it is missing from pubspec.yaml',
          hint: 'config/di/injector.dart registers every dependency in it, '
              'and the generated code resolves them through it.',
        ),
      if (!stateManagement.isBloc && !pubspec.contains('flutter_riverpod:'))
        const Diagnostic.error(
          'flutter_riverpod is missing from pubspec.yaml',
          hint: 'The generated notifiers and providers need it.',
        ),
      if (!pubspec.contains('envied:'))
        const Diagnostic.error(
          'envied is missing from pubspec.yaml',
          hint: 'config/env/app_env.dart is generated from .env by envied.',
        ),
    ];

    // A project with no locator has nothing to resolve a dependency from, and
    // the failure is a runtime "Object/factory with type X is not registered".
    {
      final injector = File(p.join(libPath, 'config', 'di', 'injector.dart'));
      if (!injector.existsSync()) {
        findings.add(
          Diagnostic.error(
            'lib/config/di/injector.dart is missing',
            hint: 'The generated '
                '${stateManagement.isBloc ? 'views resolve their blocs' : 'notifiers resolve their repositories'} '
                'with `getIt<...>()`. Run `moarch update injector`, or write '
                'it by hand.',
          ),
        );
      } else if (!injector.readAsStringSync().contains(InjectorUtils.anchor)) {
        findings.add(
          const Diagnostic.warning(
            'lib/config/di/injector.dart has no `${InjectorUtils.anchor}` '
            'comment',
            hint: 'That line is where `moarch create feature` inserts new '
                'registrations. Without it a generated feature is written but '
                'never wired up. Put it back anywhere inside setupInjector().',
          ),
        );
      }
    }

    // go_router and config/router/ are generated together — one without the
    // other means an edit went half-applied.
    final hasRouterDep = pubspec.contains('go_router:');
    final hasRouterFiles =
        File(p.join(libPath, 'config', 'router', 'app_router.dart'))
            .existsSync();
    if (hasRouterDep != hasRouterFiles) {
      findings.add(
        Diagnostic.warning(
          hasRouterDep
              ? 'go_router is in pubspec.yaml but config/router/ is missing'
              : 'config/router/ exists but go_router is not in pubspec.yaml',
          hint: hasRouterDep
              ? 'Re-run `moarch init` and select the router option, or drop the dependency.'
              : 'Add `go_router` to pubspec.yaml and run `flutter pub get`.',
        ),
      );
    }

    return findings;
  }

  // ── Firebase ────────────────────────────────────────────────────────────────

  /// The three ways a Firebase-backed project is generated correctly but
  /// wired up incompletely — each of which only shows up at runtime, on the
  /// first call, as an exception with no obvious cause.
  static List<Diagnostic> _firebase(
    String root,
    String libPath,
    String pubspec,
  ) {
    final hasFirestore = pubspec.contains('cloud_firestore:');
    final hasFirebaseAuth = pubspec.contains('firebase_auth:');
    if (!hasFirestore && !hasFirebaseAuth) return const [];

    final findings = <Diagnostic>[];

    // The generated app_exception.dart and safe_firebase_call.dart import
    // firebase_core directly, so a transitive dependency is not enough.
    if (!pubspec.contains('firebase_core:')) {
      findings.add(
        Diagnostic.error(
          'firebase_core is missing from pubspec.yaml',
          hint: 'The generated Firebase error mapping imports it directly.',
          fix: () async {
            await PubspecUtils.ensureDependencies(
              root,
              dependencies: ['firebase_core: '],
            );
            return 'added firebase_core to pubspec.yaml (run `flutter pub get`)';
          },
        ),
      );
    }

    // The Firebase auth feature's datasource is the only generated file that
    // imports google_sign_in.
    final usesGoogleSignIn = File(p.join(libPath, 'features', 'auth', 'data',
                'datasources', 'auth_remote_datasource.dart'))
            .existsSync() &&
        File(p.join(libPath, 'features', 'auth', 'domain', 'entities',
                'auth_user_entity.dart'))
            .existsSync();

    if (usesGoogleSignIn && !pubspec.contains('google_sign_in:')) {
      findings.add(
        Diagnostic.error(
          'google_sign_in is missing from pubspec.yaml but the auth feature '
          'signs in with Google',
          hint: 'Add `google_sign_in: ^7.0.0` and run `flutter pub get`.',
          fix: () async {
            await PubspecUtils.ensureDependencies(
              root,
              dependencies: ['google_sign_in: ^7.0.0'],
            );
            return 'added google_sign_in to pubspec.yaml (run `flutter pub get`)';
          },
        ),
      );
    }

    // Nothing Firebase works before initializeApp — reading any provider
    // first throws "No Firebase App '[DEFAULT]' has been created". Not
    // auto-fixed: by this point main.dart is the user's file.
    final mainFile = File(p.join(libPath, 'main.dart'));
    if (mainFile.existsSync() &&
        !mainFile.readAsStringSync().contains('Firebase.initializeApp')) {
      findings.add(
        const Diagnostic.warning(
          'lib/main.dart never calls Firebase.initializeApp()',
          hint: 'Add `await Firebase.initializeApp();` before runApp — every '
              'Firestore/Auth call throws without it. Run `flutterfire '
              'configure` first and pass DefaultFirebaseOptions.currentPlatform.',
        ),
      );
    }

    // The per-platform config `flutterfire configure` writes. Without them
    // Firebase.initializeApp() fails on that platform at launch.
    final androidConfig =
        File(p.join(root, 'android', 'app', 'google-services.json'));
    final iosConfig =
        File(p.join(root, 'ios', 'Runner', 'GoogleService-Info.plist'));
    final missingConfigs = [
      if (Directory(p.join(root, 'android')).existsSync() &&
          !androidConfig.existsSync())
        'android/app/google-services.json',
      if (Directory(p.join(root, 'ios')).existsSync() &&
          !iosConfig.existsSync())
        'ios/Runner/GoogleService-Info.plist',
    ];
    if (missingConfigs.isNotEmpty) {
      findings.add(
        Diagnostic.warning(
          '${missingConfigs.join(' and ')} missing',
          hint: 'Run `flutterfire configure` to generate the platform config. '
              'Keep these files out of version control if the project is public.',
        ),
      );
    }

    findings.addAll(_googleSignInPlist(root, usesGoogleSignIn, iosConfig));

    return findings;
  }

  /// Google sign-in on iOS needs `GIDClientID` and the `REVERSED_CLIENT_ID`
  /// URL scheme in `Info.plist` — the plugin never reads
  /// `GoogleService-Info.plist` itself. This replaces the placeholders
  /// `moarch init` writes when it runs before `flutterfire configure`.
  static List<Diagnostic> _googleSignInPlist(
    String root,
    bool usesGoogleSignIn,
    File iosConfig,
  ) {
    if (!usesGoogleSignIn) return const [];

    final infoPlist = File(p.join(root, 'ios', 'Runner', 'Info.plist'));
    if (!infoPlist.existsSync()) return const [];

    final content = infoPlist.readAsStringSync();
    final hasClientId = content.contains('<key>GIDClientID</key>');
    final hasScheme = content.contains('com.googleusercontent.apps.');
    final hasPlaceholder =
        content.contains(PlistUtils.googleClientIdPlaceholder) ||
            content.contains(PlistUtils.googleReversedClientIdPlaceholder);

    if (hasClientId && hasScheme && !hasPlaceholder) return const [];

    // Nothing to copy from yet — say what is missing and leave it.
    if (!iosConfig.existsSync()) {
      return [
        Diagnostic.warning(
          hasPlaceholder
              ? 'ios/Runner/Info.plist still has placeholder Google client ids'
              : 'ios/Runner/Info.plist is missing the Google sign-in keys',
          hint: 'Run `flutterfire configure` to get GoogleService-Info.plist, '
              'then `moarch doctor --fix` to copy CLIENT_ID and '
              'REVERSED_CLIENT_ID into Info.plist.',
        ),
      ];
    }

    final source = iosConfig.readAsStringSync();
    final clientId = PlistUtils.readString(source, 'CLIENT_ID');
    final reversed = PlistUtils.readString(source, 'REVERSED_CLIENT_ID');
    if (clientId == null || reversed == null) {
      return [
        const Diagnostic.warning(
          'GoogleService-Info.plist has no CLIENT_ID — Google sign-in is not '
          'enabled for this Firebase app',
          hint: 'Firebase console → Authentication → Sign-in method → Google, '
              'then re-download GoogleService-Info.plist.',
        ),
      ];
    }

    return [
      Diagnostic.error(
        hasPlaceholder
            ? 'ios/Runner/Info.plist still has placeholder Google client ids'
            : 'ios/Runner/Info.plist is missing the Google sign-in keys',
        hint: 'Copy CLIENT_ID into GIDClientID and REVERSED_CLIENT_ID into '
            'CFBundleURLSchemes.',
        fix: () async {
          var patched = content
              .replaceAll(PlistUtils.googleClientIdPlaceholder, clientId)
              .replaceAll(
                  PlistUtils.googleReversedClientIdPlaceholder, reversed);
          patched = PlistUtils.ensureEntries(patched, {
            'GIDClientID': clientId,
          });
          patched = PlistUtils.ensureUrlScheme(
            patched,
            reversed,
            comment: 'Google sign-in (REVERSED_CLIENT_ID)',
          );
          await infoPlist.writeAsString(patched);
          return 'wrote the Google client ids into ios/Runner/Info.plist';
        },
      ),
    ];
  }

  // ── Localization ────────────────────────────────────────────────────────────

  /// `moarch init` keeps the two localization approaches mutually exclusive,
  /// but nothing stops a later hand-edit from installing both — at which
  /// point `MaterialApp` has two competing sets of delegates.
  static List<Diagnostic> _localization(String libPath, String pubspec) {
    final hasFlutterL10n = pubspec.contains('flutter_localizations:');
    final hasEasyL10n = pubspec.contains('easy_localization:');

    if (hasFlutterL10n && hasEasyL10n) {
      return [
        const Diagnostic.warning(
          'both flutter_localizations and easy_localization are installed',
          hint: 'moarch generates one or the other. Pick one and remove the '
              'other from pubspec.yaml — two sets of localization delegates '
              'will fight over MaterialApp.',
        ),
      ];
    }

    // The dependency without its files is a build failure waiting to happen.
    if (hasFlutterL10n &&
        !Directory(p.join(libPath, 'l10n')).existsSync() &&
        !File(p.join(p.dirname(libPath), 'l10n.yaml')).existsSync()) {
      return [
        const Diagnostic.warning(
          'flutter_localizations is installed but lib/l10n/ is missing',
          hint: 'Run `flutter gen-l10n`, or re-run `moarch init` to scaffold '
              'the .arb files.',
        ),
      ];
    }

    return const [];
  }

  // ── Code generation ─────────────────────────────────────────────────────────

  /// `config/env/app_env.dart` is a `part` of an envied-generated file. Until
  /// `build_runner` has run, `app_env.g.dart` doesn't exist and the project
  /// does not compile — the single most common first-run failure.
  static List<Diagnostic> _codegen(String libPath) {
    final envDart = File(p.join(libPath, 'config', 'env', 'app_env.dart'));
    final envGenerated =
        File(p.join(libPath, 'config', 'env', 'app_env.g.dart'));

    if (envDart.existsSync() && !envGenerated.existsSync()) {
      return [
        const Diagnostic.error(
          'config/env/app_env.g.dart has not been generated',
          hint: 'Run: dart run build_runner build --delete-conflicting-outputs',
        ),
      ];
    }
    return const [];
  }

  // ── Widget kit ──────────────────────────────────────────────────────────────

  /// The catalog slugs whose file is present under `lib/shared/widgets/`.
  static List<WidgetSpec> generatedWidgets(String libPath) {
    final widgetsRoot = p.join(libPath, 'shared', 'widgets');
    return WidgetCatalog.all
        .where((spec) => File(p.join(widgetsRoot, spec.file)).existsSync())
        .toList();
  }

  /// Two ways the kit drifts out of sync, both of which stop the project
  /// compiling: a widget whose dependency was never generated (broken
  /// import), and a widget whose pub package was never added (unresolved
  /// package import). Both are mechanically fixable from the catalog.
  static List<Diagnostic> _widgets(
    String root,
    String libPath,
    String? pubspec,
  ) {
    final present = generatedWidgets(libPath);
    if (present.isEmpty) return const [];

    final presentNames = {for (final spec in present) spec.name};
    final widgetsRoot = p.join(libPath, 'shared', 'widgets');
    final findings = <Diagnostic>[];

    // Missing widget dependencies.
    final missingDeps = <String, Set<String>>{};
    for (final spec in present) {
      for (final dep in spec.deps) {
        if (!presentNames.contains(dep)) {
          missingDeps.putIfAbsent(dep, () => <String>{}).add(spec.name);
        }
      }
    }

    for (final entry in missingDeps.entries) {
      final dep = WidgetCatalog.byName(entry.key);
      if (dep == null) continue;
      final dependents = entry.value.toList()..sort();
      findings.add(
        Diagnostic.error(
          '${dep.title} is missing but imported by '
          '${dependents.join(', ')}',
          hint: 'Run: moarch create widget ${dep.name}',
          // Does exactly what the hint says, dependencies and pub packages
          // included — generating the widget alone would just surface its own
          // missing dependency on the next run.
          fix: () async {
            final manifest = ProjectManifest.loadOrCreate(root);
            final written = <String>[];
            final packages = <String>{};

            for (final spec in WidgetCatalog.resolve([dep.name])) {
              final path = p.join(widgetsRoot, spec.file);
              final content = widgetSource(libPath, spec);
              if (await FileUtils.writeFile(path, content)) {
                manifest.record(root, path, content);
                written.add(spec.file);
              }
              packages.addAll(spec.packages);
            }

            if (packages.isNotEmpty) {
              await PubspecUtils.ensureDependencies(
                root,
                dependencies: packages.toList(),
              );
            }
            if (written.isNotEmpty) await manifest.save(root);

            return 'generated ${written.map((f) => 'shared/widgets/$f').join(', ')}';
          },
        ),
      );
    }

    // Missing pub packages for generated widgets.
    if (pubspec != null) {
      final missingPackages = <String, Set<String>>{};
      for (final spec in present) {
        for (final package in spec.packages) {
          final name = package.replaceAll(':', '').trim();
          if (!pubspec.contains('$name:')) {
            missingPackages.putIfAbsent(name, () => <String>{}).add(spec.title);
          }
        }
      }

      for (final entry in missingPackages.entries) {
        final users = entry.value.toList()..sort();
        findings.add(
          Diagnostic.error(
            '${entry.key} is missing from pubspec.yaml but needed by '
            '${users.join(', ')}',
            hint:
                'Add `${entry.key}` to pubspec.yaml and run `flutter pub get`.',
            fix: () async {
              await PubspecUtils.ensureDependencies(
                root,
                dependencies: ['${entry.key}: '],
              );
              return 'added ${entry.key} to pubspec.yaml (run `flutter pub get`)';
            },
          ),
        );
      }
    }

    // Router-dependent widgets need config/router/app_router.dart for the
    // rootNavigatorKey they import.
    final needsRouter = present.where((spec) => spec.needsRouter).toList();
    final hasRouter =
        File(p.join(libPath, 'config', 'router', 'app_router.dart'))
            .existsSync();
    if (needsRouter.isNotEmpty && !hasRouter) {
      final names = needsRouter.map((spec) => spec.title).toList()..sort();
      findings.add(
        Diagnostic.error(
          '${names.join(', ')} import config/router/app_router.dart, which is missing',
          hint: 'Generate the GoRouter setup, or point them at your own '
              'navigator key.',
        ),
      );
    }

    return findings;
  }

  /// The current template source for [spec], matching how the generator wrote
  /// it — the options are read back off the project, since that is the only
  /// record still true after the checklist is forgotten.
  static String widgetSource(String libPath, WidgetSpec spec) =>
      WidgetCatalog.sourceFor(spec, WidgetVariants.detect(libPath));
}
