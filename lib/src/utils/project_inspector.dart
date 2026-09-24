import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml_edit/yaml_edit.dart';

import '../templates/config/config_templates.dart';
import 'file_utils.dart';
import 'package_versions.dart';
import 'injector_utils.dart';
import 'plist_utils.dart';
import 'project_manifest.dart';
import 'pubspec_utils.dart';
import 'scaffold_catalog.dart';
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

  /// An informational finding. Nothing is wrong, so `doctor` prints it and
  /// still exits 0.
  const Diagnostic.info(this.message, {this.hint, this.fix})
    : severity = DiagnosticSeverity.info;

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
    final pubspec = pubspecFile.existsSync()
        ? pubspecFile.readAsStringSync()
        : null;

    return [
      ..._structure(root, libPath),
      ..._fvm(root),
      if (pubspec != null) ..._dependencies(libPath, pubspec),
      if (pubspec != null) ..._firebase(root, libPath, pubspec),
      if (pubspec != null) ..._localization(libPath, pubspec),
      ..._codegen(libPath),
      ..._theme(root, libPath),
      ..._agents(root),
      ..._skills(root),
      ..._widgets(root, libPath, pubspec),
    ];
  }

  // ── Agent guide ─────────────────────────────────────────────────────────────

  /// The release `init` started offering `AGENTS.md`.
  static const _agentsSince = [9, 0, 0];

  /// The release `init` started writing the agent skills beside it.
  static const _skillsSince = [9, 1, 0];

  /// A project scaffolded before `init` wrote `AGENTS.md` and `CLAUDE.md`.
  ///
  /// Offered only to those: a project from 9.0.0 on that has no `AGENTS.md`
  /// unticked it in the checklist, and being asked again on every `doctor`
  /// would be nagging. A project with no manifest cannot say, so it is asked.
  /// The fix brings the skills along, so one `--fix` leaves it where a fresh
  /// `init` would.
  static List<Diagnostic> _agents(String root) {
    if (File(p.join(root, 'AGENTS.md')).existsSync()) return const [];
    final manifest = ProjectManifest.load(root);
    if (manifest != null && !_predates(manifest.version, _agentsSince)) {
      return const [];
    }

    return [
      Diagnostic.info(
        "No AGENTS.md — coding agents get none of the project's rules",
        hint:
            'Generate AGENTS.md, CLAUDE.md and the agent skills with '
            '`moarch doctor --fix`.',
        // Skills first: AGENTS.md lists them only once they are on disk.
        fix: () => _generate(root, [
          ..._aiSpecs,
          'agents',
          'claude-md',
        ], 'the files already exist'),
      ),
    ];
  }

  /// A project with `AGENTS.md` from before `init` wrote the skills (9.1.0).
  ///
  /// Same rule as [_agents]: a newer project without them chose that.
  static List<Diagnostic> _skills(String root) {
    if (!File(p.join(root, 'AGENTS.md')).existsSync()) return const [];
    if (ScaffoldContext.detect(root).hasAgentSkills) return const [];
    final manifest = ProjectManifest.load(root);
    if (manifest != null && !_predates(manifest.version, _skillsSince)) {
      return const [];
    }

    return [
      Diagnostic.info(
        'No agent skills — agents get the rules but not the procedures',
        hint:
            'Generate .agents/skills/, .claude/ and .gemini/ with '
            '`moarch doctor --fix`, then `moarch update agents` to list the '
            'skills in AGENTS.md.',
        fix: () async {
          final result = await _generate(
            root,
            _aiSpecs,
            'the files already exist',
          );
          return '$result — run `moarch update agents` to list them in '
              'AGENTS.md';
        },
      ),
    ];
  }

  /// Every spec in the `ai` group: the skills and the agents' settings.
  static List<String> get _aiSpecs =>
      ScaffoldCatalog.byGroup('ai').map((spec) => spec.name).toList();

  /// Writes the catalog entries [names] into [root] and records them in the
  /// manifest. Never clobbers: a file the team wrote is left alone.
  static Future<String> _generate(
    String root,
    List<String> names,
    String whenNothing,
  ) async {
    final context = ScaffoldContext.detect(root);
    final written = <String>[];
    final updated = ProjectManifest.loadOrCreate(root);
    for (final name in names) {
      final spec = ScaffoldCatalog.byName(name)!;
      final path = context.resolve(spec.pathIn(context));
      final content = spec.template(context);
      if (await FileUtils.writeFile(path, content)) {
        updated.record(root, path, content);
        written.add(spec.pathIn(context));
      }
    }
    if (written.isNotEmpty) await updated.save(root);
    if (written.isEmpty) return 'nothing written — $whenNothing';
    return written.length > 4
        ? 'generated ${written.length} files'
        : 'generated ${written.join(', ')}';
  }

  /// Whether [version] (`major.minor.patch`) is older than [since]. An
  /// unparseable version counts as older, so it is offered the fix.
  static bool _predates(String version, List<int> since) {
    final parts = version.split('+').first.split('-').first.split('.');
    for (var i = 0; i < since.length; i++) {
      final part = i < parts.length ? int.tryParse(parts[i]) : 0;
      if (part == null) return true;
      if (part != since[i]) return part < since[i];
    }
    return false;
  }

  // ── Theme ───────────────────────────────────────────────────────────────────

  /// A project scaffolded before `AppStatusColors` existed.
  ///
  /// Nothing is broken — every widget that would read it still reads
  /// `AppConstants`, detected per project — so this is information with a fix
  /// rather than a warning. The fix only adds the file: `AppTheme` and the
  /// status widgets start using it on their next `moarch update`, which is
  /// what the message says, so no edited file is rewritten behind anyone's
  /// back.
  static List<Diagnostic> _theme(String root, String libPath) {
    final themeFile = File(
      p.join(libPath, 'config', 'theme', 'app_theme.dart'),
    );
    if (!themeFile.existsSync() || WidgetVariants.hasStatusColorsIn(libPath)) {
      return const [];
    }

    return [
      Diagnostic.info(
        'No AppStatusColors — success / warning / info ignore the dark theme',
        hint:
            'Generate lib/config/theme/app_status_colors.dart, then run '
            '`moarch update theme tag banner toast agents`.',
        fix: () async {
          final path = p.join(
            libPath,
            'config',
            'theme',
            'app_status_colors.dart',
          );
          final content = ConfigTemplates.appStatusColors(
            withDark: WidgetVariants.hasDarkThemeIn(libPath),
          );
          if (await FileUtils.writeFile(path, content)) {
            final manifest = ProjectManifest.loadOrCreate(root);
            manifest.record(root, path, content);
            await manifest.save(root);
          }
          return 'generated config/theme/app_status_colors.dart — run '
              '`moarch update theme tag banner toast agents` to use it';
        },
      ),
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
  static final RegExp _sdkPathPattern = RegExp(
    r'"dart\.flutterSdkPath"\s*:\s*"([^"]*)"',
  );

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
          hint:
              'Run `moarch init` to scaffold it, or set '
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
          hint:
              'Add "dart.flutterSdkPath": ".fvm/flutter_sdk" — without it '
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
          hint:
              'Point it at ".fvm/flutter_sdk" instead — that symlink '
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
    final linked =
        FileSystemEntity.typeSync(sdkPath, followLinks: false) !=
        FileSystemEntityType.notFound;
    if (!linked) {
      findings.add(
        Diagnostic.error(
          'dart.flutterSdkPath points at $configured, which does not exist — '
          'the editor is silently using the Flutter on your PATH',
          hint:
              'Run `fvm use` in the project root to create it, then reload '
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
          hint:
              'Run `fvm install` to restore the version .fvmrc pins, then '
              'reload the VS Code window.',
        ),
      );
    }

    return findings;
  }

  // ── The locator ──────────────────────────────────────────────

  /// Checks `lib/config/di/`, in whichever of the two shapes the project has.
  ///
  /// A project with no locator has nothing to resolve a dependency from, and
  /// the failure is a runtime "Object/factory with type X is not registered".
  /// One with a locator but no anchor is worse: `create feature` writes the
  /// feature and silently wires up none of it.
  static List<Diagnostic> _locator(
    String libPath,
    StateManagement stateManagement,
  ) {
    final findings = <Diagnostic>[];
    final injector = File(InjectorUtils.fileFor(libPath));

    if (!injector.existsSync()) {
      return [
        Diagnostic.error(
          'lib/config/di/injector.dart is missing',
          hint:
              'The generated '
              '${stateManagement.isBloc ? 'pages resolve their blocs' : 'notifiers resolve their repositories'} '
              'with `getIt<...>()`. Run `moarch update injector`, or write '
              'it by hand.',
        ),
      ];
    }

    // Which shape this project is, read off disk: the registrations are split
    // one file per layer now, and a project scaffolded before that has them
    // all in `injector.dart`. Both are supported; only the checks differ.
    if (!InjectorUtils.isSplit(libPath)) {
      if (!injector.readAsStringSync().contains(InjectorUtils.anchor)) {
        findings.add(
          const Diagnostic.warning(
            'lib/config/di/injector.dart has no `${InjectorUtils.anchor}` '
            'comment',
            hint:
                'That line is where `moarch create feature` inserts new '
                'registrations. Without it a generated feature is written but '
                'never wired up. Put it back anywhere inside setupInjector().',
          ),
        );
      }
      findings.add(
        const Diagnostic.info(
          'lib/config/di/injector.dart holds every registration in one file',
          hint:
              'Newer projects split them one file per layer — '
              'external_module, core_module, data_module and (on bloc) '
              'presentation_module — so no single file grows with the app. '
              'Nothing is wrong with the single file and moarch keeps '
              'writing to it; splitting it is a hand migration if you want '
              'the newer shape.',
        ),
      );
      return findings;
    }

    // Split layout. Each module `injector.dart` calls has to be there, and
    // the two `create` writes into have to keep their anchor.
    const modules = {
      'external_module.dart': 'registerExternals()',
      'core_module.dart': 'registerCoreServices()',
      'data_module.dart': 'registerDataLayer()',
    };
    for (final entry in modules.entries) {
      if (!File(p.join(libPath, 'config', 'di', entry.key)).existsSync()) {
        findings.add(
          Diagnostic.error(
            'lib/config/di/${entry.key} is missing',
            hint:
                'setupInjector() calls ${entry.value} from it, so the '
                'project does not compile without it. Run '
                '`moarch update injector` to see the current shape, or write '
                'the file by hand.',
          ),
        );
      }
    }
    if (stateManagement.isBloc &&
        !File(InjectorUtils.presentationFileFor(libPath)).existsSync()) {
      findings.add(
        const Diagnostic.error(
          'lib/config/di/presentation_module.dart is missing',
          hint:
              'On bloc the state holders are registered like any other '
              'dependency, and setupInjector() calls registerBlocs() from '
              'this file.',
        ),
      );
    }

    // The anchors. One per file `create` writes into, and each is the only
    // thing telling it where to write.
    final anchored = <String, String>{
      InjectorUtils.dataPath: InjectorUtils.dataFileFor(libPath),
      if (stateManagement.isBloc)
        InjectorUtils.presentationPath: InjectorUtils.presentationFileFor(
          libPath,
        ),
    };
    for (final entry in anchored.entries) {
      final file = File(entry.value);
      if (!file.existsSync()) continue;
      if (file.readAsStringSync().contains(InjectorUtils.anchor)) continue;
      findings.add(
        Diagnostic.warning(
          '${entry.key} has no `${InjectorUtils.anchor}` comment',
          hint:
              'That line is where `moarch create feature` inserts new '
              'registrations. Without it a generated feature is written but '
              'never wired up. Put it back anywhere inside the registrar '
              'function.',
        ),
      );
    }

    return findings;
  }

  // ── Dependencies ────────────────────────────────────────────────────────────

  /// The standalone test generators `moarch create tests` replaced.
  static const _mogenPackages = ['mogen_unit_tests', 'mogen_integration_tests'];

  /// A project still carrying the mogen dev dependencies.
  ///
  /// They pinned `analyzer` inside the app, which is where they collided with
  /// freezed and riverpod; the generator now runs inside moarch instead. The
  /// fix swaps them for what the generated tests import. Tests mogen already
  /// wrote keep working, and `moarch create tests` refreshes them.
  static List<Diagnostic> _mogen(
    String root,
    String pubspec,
    StateManagement stateManagement,
  ) {
    final present = _mogenPackages
        .where(
          (name) => RegExp('^\\s+$name:', multiLine: true).hasMatch(pubspec),
        )
        .toList();
    if (present.isEmpty) return const [];

    return [
      Diagnostic.info(
        '${present.join(' and ')} in pubspec.yaml — replaced by '
        '`moarch create tests`',
        hint:
            'Remove them from dev_dependencies, add mocktail'
            '${stateManagement.isBloc ? ' and bloc_test' : ''}, then run '
            '`moarch create tests`.',
        fix: () async {
          final file = File(p.join(root, 'pubspec.yaml'));
          final editor = YamlEditor(file.readAsStringSync());
          for (final name in present) {
            for (final section in const ['dev_dependencies', 'dependencies']) {
              try {
                editor.remove([section, name]);
              } catch (_) {
                // Not in this section — it is in the other one.
              }
            }
          }
          file.writeAsStringSync(editor.toString());
          await PubspecUtils.ensureDependencies(
            root,
            dependencies: const [],
            devDependencies: [
              PackageVersions.entry('mocktail'),
              if (stateManagement.isBloc) PackageVersions.entry('bloc_test'),
            ],
          );
          return 'removed ${present.join(', ')}; added mocktail'
              '${stateManagement.isBloc ? ' and bloc_test' : ''} — run '
              '`fvm flutter pub get`, then `moarch create tests`';
        },
      ),
    ];
  }

  static List<Diagnostic> _dependencies(String libPath, String pubspec) {
    final stateManagement = StateManagement.fromPubspec(pubspec);

    final findings = <Diagnostic>[
      // Both stacks: get_it is the DI in either. What follows the stack is
      // only the state-management package beside it.
      if (!pubspec.contains('get_it:'))
        const Diagnostic.error(
          'get_it is missing from pubspec.yaml',
          hint:
              'config/di/injector.dart registers every dependency in it, '
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

    findings.addAll(_locator(libPath, stateManagement));
    findings.addAll(_mogen(p.dirname(libPath), pubspec, stateManagement));

    // go_router and config/router/ are generated together — one without the
    // other means an edit went half-applied.
    final hasRouterDep = pubspec.contains('go_router:');
    final hasRouterFiles = File(
      p.join(libPath, 'config', 'router', 'app_router.dart'),
    ).existsSync();
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
    final usesGoogleSignIn =
        File(
          p.join(
            libPath,
            'features',
            'auth',
            'data',
            'datasources',
            'auth_remote_datasource.dart',
          ),
        ).existsSync() &&
        (File(
              p.join(
                libPath,
                'features',
                'auth',
                'domain',
                'models',
                'auth_user_model.dart',
              ),
            ).existsSync() ||
            // Where a project scaffolded before 8.0.0 keeps it.
            File(
              p.join(
                libPath,
                'features',
                'auth',
                'data',
                'models',
                'auth_user_model.dart',
              ),
            ).existsSync());

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
          hint:
              'Add `await Firebase.initializeApp();` before runApp — every '
              'Firestore/Auth call throws without it. Run `flutterfire '
              'configure` first and pass DefaultFirebaseOptions.currentPlatform.',
        ),
      );
    }

    // The per-platform config `flutterfire configure` writes. Without them
    // Firebase.initializeApp() fails on that platform at launch.
    final androidConfig = File(
      p.join(root, 'android', 'app', 'google-services.json'),
    );
    final iosConfig = File(
      p.join(root, 'ios', 'Runner', 'GoogleService-Info.plist'),
    );
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
          hint:
              'Run `flutterfire configure` to generate the platform config. '
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
          hint:
              'Run `flutterfire configure` to get GoogleService-Info.plist, '
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
          hint:
              'Firebase console → Authentication → Sign-in method → Google, '
              'then re-download GoogleService-Info.plist.',
        ),
      ];
    }

    return [
      Diagnostic.error(
        hasPlaceholder
            ? 'ios/Runner/Info.plist still has placeholder Google client ids'
            : 'ios/Runner/Info.plist is missing the Google sign-in keys',
        hint:
            'Copy CLIENT_ID into GIDClientID and REVERSED_CLIENT_ID into '
            'CFBundleURLSchemes.',
        fix: () async {
          var patched = content
              .replaceAll(PlistUtils.googleClientIdPlaceholder, clientId)
              .replaceAll(
                PlistUtils.googleReversedClientIdPlaceholder,
                reversed,
              );
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
          hint:
              'moarch generates one or the other. Pick one and remove the '
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
          hint:
              'Run `flutter gen-l10n`, or re-run `moarch init` to scaffold '
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
    final envGenerated = File(
      p.join(libPath, 'config', 'env', 'app_env.g.dart'),
    );

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

  /// The catalog entries whose file is present under `lib/shared/`.
  ///
  /// An entry that has moved counts as present at either path: a project that
  /// has not run `moarch update` since the move still holds a real, compiling
  /// file, and the checks below are about what that file imports — not about
  /// which directory it sits in.
  static List<WidgetSpec> generatedWidgets(String libPath) => WidgetCatalog.all
      .where(
        (spec) =>
            File(spec.pathIn(libPath)).existsSync() ||
            _legacyExists(spec, libPath),
      )
      .toList();

  /// Whether [spec] is present at the path moarch wrote before it moved.
  static bool _legacyExists(WidgetSpec spec, String libPath) {
    final legacy = spec.legacyPathIn(libPath);
    return legacy != null && File(legacy).existsSync();
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
              final path = spec.pathIn(libPath);
              final content = widgetSource(libPath, spec);
              if (await FileUtils.writeFile(path, content)) {
                manifest.record(root, path, content);
                written.add(spec.libFile);
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

            return 'generated ${written.join(', ')}';
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
    final hasRouter = File(
      p.join(libPath, 'config', 'router', 'app_router.dart'),
    ).existsSync();
    if (needsRouter.isNotEmpty && !hasRouter) {
      final names = needsRouter.map((spec) => spec.title).toList()..sort();
      findings.add(
        Diagnostic.error(
          '${names.join(', ')} import config/router/app_router.dart, which is missing',
          hint:
              'Generate the GoRouter setup, or point them at your own '
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
