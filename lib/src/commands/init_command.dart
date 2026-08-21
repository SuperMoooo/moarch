import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/core/security_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/misc/android_templates.dart';
import 'package:moarch/src/templates/misc/dev_templates.dart';
import 'package:moarch/src/templates/misc/docs_templates.dart';
import 'package:moarch/src/templates/misc/ios_templates.dart';
import 'package:moarch/src/templates/misc/readme_templates.dart';
import 'package:moarch/src/templates/misc/workflow_templates.dart';
import 'package:moarch/src/utils/checklist.dart';
import 'package:path/path.dart' as p;

import '../templates/config/config_templates.dart';
import '../templates/core/core_templates.dart';
import '../templates/stack_templates.dart';
import '../utils/file_utils.dart';
import '../utils/gradle_utils.dart';
import '../utils/kotlin_utils.dart';
import '../utils/manifest_utils.dart';
import '../utils/package_versions.dart';
import '../utils/plist_utils.dart';
import '../utils/project_manifest.dart';
import '../utils/podfile_utils.dart';
import '../utils/pubspec_utils.dart';
import '../utils/scaffold_catalog.dart';
import '../utils/state_management.dart';
import '../utils/swift_utils.dart';
import '../utils/widget_catalog.dart';
import '../version.dart';

// ── State management ──────────────────────────────────────────────────────────
// The first choice, because every state-bearing file below follows it.

const _kRiverpod = 'Riverpod (AsyncNotifier + runAction)';
const _kBloc = 'flutter_bloc (events + Bloc)';

// ── Stack options ─────────────────────────────────────────────────────────────
// Add a new const + ChecklistItem + if block to support a new option.

const _kDio = 'Dio (REST API)';
const _kFirestore = 'Firebase Firestore';
const _kFirebaseAuth = 'Firebase Auth';
const _kCrashlytics = 'Firebase Crashlytics';

// ── Feature options ───────────────────────────────────────────────────────────
// What gets generated into lib/ beyond the bare minimum.

const _kAuthFeature = 'Auth feature (login/register/refresh/logout/delete)';
const _kRouter = 'Router (GoRouter)';
const _kWorkflows = 'Workflows (security, tests, build)';
const _kMediaService = 'Media Service (Image Picker and File Picker)';
const _kLaunchUrlService = 'Url launcher for links';
const _kDebouncerService = 'Debouncer for actions';
const _kNotificationsService = 'Notifications service';
const _kFirebaseNotifications = 'Firebase push notifications (FCM)';
const _kBiometricAuth = 'Biometric authentication';
const _kMaintenanceGate = 'Maintenance gate (backend kill switch)';
const _kDarkTheme = 'Dark theme (second palette)';
const _kMoAdapt = 'MoAdapt (proportional UI scaling)';
const _kLocalizations = 'Localization (l10n)';
const _kEasyLocalization = 'Localization (easy_localization)';

/// Creates the project-initialization CLI command.
class InitCommand extends Command<int> {
  /// Creates the project initialization command.
  InitCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Target project path (defaults to current directory).',
        defaultsTo: '.',
      )
      ..addFlag(
        'all',
        abbr: 'a',
        negatable: false,
        help: 'Skip checklist and generate everything.',
      )
      ..addOption(
        'state',
        abbr: 's',
        allowed: ['riverpod', 'bloc'],
        help: 'State management. Skips that checklist; the only way to pick '
            'one with --all.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Preview the files that would be created without writing them.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'init';

  @override
  String get description => 'Scaffold a full Flutter project structure.';

  @override
  Future<int> run() async {
    final targetPath = argResults?['path'] as String? ?? '.';
    final libPath = p.join(p.absolute(targetPath), 'lib');
    final skipChecklist = argResults?['all'] as bool? ?? false;
    final dryRun = argResults?['dry-run'] as bool? ?? false;

    _logger.info('');
    _logger.info('🧱 moarch — Initializing project...');
    _logger.info('');

    // ── Stack checklist ───────────────────────────────────────────────────────
    // What backend/networking does this project use?

    late Set<String> stack;
    // Riverpod unless told otherwise — the stack every project scaffolded
    // before this option existed uses.
    final stateFlag = argResults?['state'] as String?;
    var stateManagement =
        stateFlag == 'bloc' ? StateManagement.bloc : StateManagement.riverpod;

    if (skipChecklist) {
      stack = {
        _kDio,
        _kAuthFeature,
        _kRouter,
        _kWorkflows,
        _kMediaService,
        _kLaunchUrlService,
        _kDebouncerService,
        _kNotificationsService,
        _kBiometricAuth,
        _kMaintenanceGate,
        _kMoAdapt,
        _kDarkTheme,
        _kLocalizations,
      };
    } else {
      try {
        // Asked first, and on its own: it decides the shape of every
        // state-bearing file the two checklists below select. Skipped when
        // --state already answered it.
        if (stateFlag == null) {
          final stateChoice = Checklist.prompt(
            title: '  State management:',
            items: [
              const ChecklistItem(
                _kRiverpod,
                defaultOn: true,
                description: 'An AsyncNotifier + runAction per feature, over a '
                    'get_it service locator.',
                excludes: {_kBloc},
              ),
              const ChecklistItem(
                _kBloc,
                defaultOn: false,
                description: 'A sealed event family and a Bloc per feature, '
                    'over the same get_it locator. Adds bloc_lint.',
                excludes: {_kRiverpod},
              ),
            ],
          );
          // Neither ticked is not a third stack — it is the default.
          stateManagement = stateChoice.contains(_kBloc)
              ? StateManagement.bloc
              : StateManagement.riverpod;
        }

        stack = Checklist.prompt(
          title: '  Backend / networking:',
          items: [
            const ChecklistItem(
              _kDio,
              defaultOn: true,
              description:
                  'REST client with retry + secure-storage auth interceptor.',
            ),
            const ChecklistItem(
              _kFirestore,
              defaultOn: false,
              description:
                  'Cloud Firestore provider (requires Firebase setup).',
            ),
            const ChecklistItem(
              _kFirebaseAuth,
              defaultOn: false,
              description: 'FirebaseAuth provider (requires Firebase setup).',
            ),
            const ChecklistItem(
              _kCrashlytics,
              defaultOn: false,
              description:
                  'Crash reporting wired into the error handlers (requires Firebase setup).',
            ),
          ],
        );

        // ── Feature checklist ─────────────────────────────────────────────────
        // What extra files do you want generated?
        final features = Checklist.prompt(
          title: '  What to generate:',
          items: [
            const ChecklistItem(
              _kAuthFeature,
              defaultOn: true,
              description:
                  'Follows the backend above: Firebase Auth (email/password + Google) '
                  'when selected, otherwise REST with tokens in secure storage.',
            ),
            const ChecklistItem(
              _kRouter,
              defaultOn: true,
              description: 'GoRouter with an auth-aware redirect.',
            ),
            const ChecklistItem(
              _kWorkflows,
              defaultOn: true,
              description:
                  'GitHub Actions: CI, code scanning, Android/iOS build, store deploy.',
            ),
            const ChecklistItem(
              _kMediaService,
              defaultOn: false,
              description: 'Image/file picker with permission handling.',
            ),
            const ChecklistItem(
              _kLaunchUrlService,
              defaultOn: false,
              description: 'Open external links/URLs.',
            ),
            ChecklistItem(
              _kDebouncerService,
              defaultOn: false,
              // A bloc debounces what reaches it with an EventTransformer, so
              // this service is only the widget-level timer there — worth
              // saying, or it reads as the way to debounce a search.
              description: stateManagement.isBloc
                  ? 'Debounce rapid callbacks in widgets (e.g. filtering a '
                      'local list). Events reaching a bloc debounce in an '
                      'EventTransformer instead.'
                  : 'Debounce rapid user actions (e.g. search input).',
            ),
            const ChecklistItem(
              _kNotificationsService,
              defaultOn: false,
              description: 'Local push notifications.',
            ),
            const ChecklistItem(
              _kFirebaseNotifications,
              defaultOn: false,
              description:
                  'Remote push notifications via Firebase Cloud Messaging (requires Firebase setup).',
            ),
            const ChecklistItem(
              _kBiometricAuth,
              defaultOn: false,
              description:
                  'Face ID / fingerprint via local_auth, wired into AppButton through beforePressed.',
            ),
            const ChecklistItem(
              _kMaintenanceGate,
              defaultOn: false,
              description:
                  'Empties the app while a backend flag says maintenance; '
                  'fails open if the flag cannot be read.',
            ),
            const ChecklistItem(
              _kMoAdapt,
              defaultOn: true,
              description: 'Wraps the app so every fixed dimension scales '
                  'proportionally to the screen from a 390×844 design frame.',
            ),
            const ChecklistItem(
              _kDarkTheme,
              defaultOn: false,
              description:
                  'A dark half for AppConstants and AppTheme, followed by '
                  'MaterialApp through themeMode. Off leaves one brand theme; '
                  'add it later with `moarch create theme --dark`.',
            ),
            const ChecklistItem(
              _kLocalizations,
              defaultOn: false,
              description:
                  'l10n scaffolding with English + Portuguese .arb files.',
              excludes: {_kEasyLocalization},
            ),
            const ChecklistItem(
              _kEasyLocalization,
              defaultOn: false,
              description:
                  'easy_localization with English + Portuguese JSON files in assets/translations.',
              excludes: {_kLocalizations},
            ),
          ],
        );

        stack = {...stack, ...features};
      } on ChecklistCancelled {
        _logger.info('Cancelled — nothing was generated.');
        return 0;
      }
    }

    // Which backend the auth feature is generated against. Firebase Auth wins
    // when both are selected: it is the more specific choice — a project can
    // still use Dio for everything else.
    final firebaseAuthFeature =
        stack.contains(_kAuthFeature) && stack.contains(_kFirebaseAuth);

    if (firebaseAuthFeature && stack.contains(_kDio)) {
      _logger
          .info('  Note: the auth feature is generated against Firebase Auth.');
    }

    // The REST auth feature calls the API through the Dio client and its
    // refresh interceptor, so generating it without Dio would produce broken
    // imports. Firebase Auth needs none of that.
    if (stack.contains(_kAuthFeature) &&
        !stack.contains(_kDio) &&
        !firebaseAuthFeature) {
      stack.add(_kDio);
      _logger.info('  Note: Dio added — the auth feature depends on it.');
    }

    // The two localization options are mutually exclusive (the checklist
    // enforces this interactively); if both end up selected anyway,
    // easy_localization wins — matching the mainDart template.
    if (stack.contains(_kEasyLocalization) && stack.contains(_kLocalizations)) {
      stack.remove(_kLocalizations);
      _logger.info(
          '  Note: flutter_localizations dropped — easy_localization selected.');
    }

    // Every state-bearing template goes through this rather than through the
    // riverpod/ or bloc/ folder directly.
    final templates = StackTemplates(stateManagement);

    final progress = _logger.progress(
      dryRun ? 'Previewing structure' : 'Creating structure',
    );

    // Records the stack and a hash of every file written, so `moarch update`
    // can later tell an untouched generated file from one the user edited.
    // The state management goes in as a checklist entry so the record reads
    // as what was chosen, though every command re-detects it from pubspec.
    final manifest = ProjectManifest(
      version: packageVersion,
      generatedAt: DateTime.now(),
      stack: [
        ...stack,
        stateManagement.isBloc ? _kBloc : _kRiverpod,
      ]..sort(),
    );

    FileUtils.beginSession(
      dryRun: dryRun,
      manifest: manifest,
      projectRoot: p.absolute(targetPath),
    );

    final pubspecFile = File(p.join(p.absolute(targetPath), 'pubspec.yaml'));
    final pubspecExisted = pubspecFile.existsSync();
    final pubspecBackup =
        pubspecExisted ? await pubspecFile.readAsString() : null;

    // analysis_options.yaml is the one file FileUtils overwrites rather than
    // skips, so it needs a backup like the platform files below.
    final analysisOptionsFile =
        File(p.join(p.absolute(targetPath), 'analysis_options.yaml'));
    final analysisOptionsBackup = analysisOptionsFile.existsSync()
        ? await analysisOptionsFile.readAsString()
        : null;

    final infoPlistFile =
        File(p.join(p.absolute(targetPath), 'ios', 'Runner', 'Info.plist'));
    final infoPlistBackup =
        infoPlistFile.existsSync() ? await infoPlistFile.readAsString() : null;

    final appDelegateFile = File(
        p.join(p.absolute(targetPath), 'ios', 'Runner', 'AppDelegate.swift'));
    final appDelegateBackup = appDelegateFile.existsSync()
        ? await appDelegateFile.readAsString()
        : null;

    final podfileFile = File(p.join(p.absolute(targetPath), 'ios', 'Podfile'));
    final podfileBackup =
        podfileFile.existsSync() ? await podfileFile.readAsString() : null;

    final buildGradleFile = File(
        p.join(p.absolute(targetPath), 'android', 'app', 'build.gradle.kts'));
    final buildGradleBackup = buildGradleFile.existsSync()
        ? await buildGradleFile.readAsString()
        : null;

    final androidManifestFile = File(p.join(p.absolute(targetPath), 'android',
        'app', 'src', 'main', 'AndroidManifest.xml'));
    final androidManifestBackup = androidManifestFile.existsSync()
        ? await androidManifestFile.readAsString()
        : null;

    // MainActivity.kt sits under a package-name folder that varies per
    // project, so it can't be addressed by a fixed path like the files above.
    final mainActivityFile = _findMainActivityFile(p.absolute(targetPath));
    final mainActivityBackup =
        mainActivityFile != null && mainActivityFile.existsSync()
            ? await mainActivityFile.readAsString()
            : null;

    // Unversioned, so pub fetches the newest release each package allows. Pub
    // is free to resolve *backwards* to settle a conflict, so the packages
    // that break when it does carry a constraint of their own below.
    // Every constraint comes from `PackageVersions`, one table bumped per
    // moarch release. Not `any`: the templates are written against a specific
    // API, and an unconstrained entry lets the next `pub get` walk a project
    // onto a major release nobody asked for.
    final defaultDependencies = <String>[
      'flutter:\n    sdk: flutter',
      if (stateManagement.isBloc) ...[
        PackageVersions.entry('flutter_bloc'),
        // Declared as well as flutter_bloc, which re-exports it: the blocs
        // import `package:bloc/bloc.dart` so they stay pure Dart — which is
        // what the avoid_flutter_imports lint rule is there to keep true.
        PackageVersions.entry('bloc'),
        // Value equality on states and events. Bloc drops an emit whose state
        // equals the current one and BlocConsumer rebuilds on the same test,
        // so without it every emit repaints.
        PackageVersions.entry('equatable'),
      ] else
        PackageVersions.entry('flutter_riverpod'),
      // The service locator, in both stacks: dependency injection is get_it's
      // job either way. What Riverpod keeps is state — the notifiers, which
      // read what they depend on out of here.
      PackageVersions.entry('get_it'),
      PackageVersions.entry('flutter_native_splash'),
      PackageVersions.entry('envied'),
      PackageVersions.entry('skeletonizer'),
      PackageVersions.entry('intl'),
      PackageVersions.entry('logger'),
      PackageVersions.entry('connectivity_plus'),
      if (stack.contains(_kRouter)) PackageVersions.entry('go_router'),
      if (stack.contains(_kDio)) PackageVersions.entry('dio'),
      if (stack.contains(_kDio)) PackageVersions.entry('dio_smart_retry'),
      PackageVersions.entry('flutter_secure_storage'),
      if (stack.contains(_kFirebaseAuth) ||
          stack.contains(_kFirestore) ||
          stack.contains(_kCrashlytics) ||
          stack.contains(_kFirebaseNotifications))
        PackageVersions.entry('firebase_core'),
      if (stack.contains(_kFirebaseNotifications))
        PackageVersions.entry('firebase_messaging'),
      if (stack.contains(_kCrashlytics))
        PackageVersions.entry('firebase_crashlytics'),
      if (stack.contains(_kFirebaseAuth))
        PackageVersions.entry('firebase_auth'),
      if (stack.contains(_kFirestore)) PackageVersions.entry('cloud_firestore'),
      if (firebaseAuthFeature) PackageVersions.entry('google_sign_in'),
      if (stack.contains(_kMediaService)) PackageVersions.entry('file_picker'),
      if (stack.contains(_kMediaService)) PackageVersions.entry('image_picker'),
      PackageVersions.entry('permission_handler'),
      if (stack.contains(_kLaunchUrlService))
        PackageVersions.entry('url_launcher'),
      if (stack.contains(_kNotificationsService))
        PackageVersions.entry('flutter_local_notifications'),
      if (stack.contains(_kNotificationsService))
        PackageVersions.entry('timezone'),
      if (stack.contains(_kBiometricAuth)) PackageVersions.entry('local_auth'),
      if (stack.contains(_kBiometricAuth))
        PackageVersions.entry('local_auth_android'),
      if (stack.contains(_kBiometricAuth))
        PackageVersions.entry('local_auth_darwin'),
      if (stack.contains(_kLocalizations))
        'flutter_localizations:\n    sdk: flutter',
      if (stack.contains(_kEasyLocalization))
        PackageVersions.entry('easy_localization'),
    ];

    final devDependencies = <String>[
      PackageVersions.entry('build_runner'),
      PackageVersions.entry('envied_generator'),
      PackageVersions.entry('mogen_unit_tests'),
      PackageVersions.entry('mogen_integration_tests'),
      PackageVersions.entry('flutter_lints'),
      // The bloc team's own rules — file naming, no Flutter imports in a
      // bloc, no public fields on a state. Run with `bloc lint .` (see
      // `dart pub global activate bloc_tools`); analysis_options.yaml
      // carries the ruleset.
      if (stateManagement.isBloc) PackageVersions.entry('bloc_lint'),
      // No bloc_test: moarch scaffolds no tests, and mogen_unit_tests above
      // is the testing story for both stacks. Add it the day you write a
      // bloc test by hand — `flutter pub add --dev bloc_test`.
    ];

    // False when a main.dart the developer wrote was left in place, which is
    // the one case they have to wire ProviderScope up themselves.
    var wroteMainDart = false;

    try {
      await _buildCore(libPath, stack, templates);
      await _buildConfig(libPath, stack, templates);
      await _buildShared(libPath, stack, stateManagement);
      await FileUtils.createDir(p.join(libPath, 'features'));
      if (stack.contains(_kAuthFeature)) {
        if (firebaseAuthFeature) {
          await _buildFirebaseAuthFeature(
            libPath,
            templates,
            withFirestore: stack.contains(_kFirestore),
            withPushNotifications: stack.contains(_kFirebaseNotifications),
          );
        } else {
          await _buildAuthFeature(
            libPath,
            templates,
            withPushNotifications: stack.contains(_kFirebaseNotifications),
          );
        }
      }
      final testPath = p.join(p.absolute(targetPath), 'test');
      await FileUtils.createDir(testPath);
      await FileUtils.createDir(p.join(testPath, 'unit'));
      await FileUtils.createDir(p.join(testPath, 'integration'));

      // The counter test pumps the demo main.dart replaced just below, so it
      // would fail to compile the moment the scaffold lands. Only that test is
      // replaced — a test the developer wrote is left alone.
      await FileUtils.writeFile(
        p.join(testPath, 'widget_test.dart'),
        DevTemplates.widgetTest(),
        overwriteWhen: _isFlutterCounterTest,
      );

      // `flutter create` always leaves a main.dart behind and existing files
      // are never clobbered, so the counter demo is replaced explicitly.
      // Anything the developer wrote is left alone.
      wroteMainDart = await FileUtils.writeFile(
        p.join(libPath, 'main.dart'),
        templates.mainDart(
          withRouter: stack.contains(_kRouter),
          withLocalization: stack.contains(_kLocalizations),
          withEasyLocalization: stack.contains(_kEasyLocalization),
          withNotificationsService: stack.contains(_kNotificationsService),
          withFirebaseNotifications: stack.contains(_kFirebaseNotifications),
          withCrashlytics: stack.contains(_kCrashlytics),
          // Firestore and Firebase Auth are read through providers the app
          // touches on its first frame, so Firebase has to be up by then.
          withFirebase: stack.contains(_kFirestore) ||
              stack.contains(_kFirebaseAuth) ||
              stack.contains(_kCrashlytics),
          withMaintenanceGate: stack.contains(_kMaintenanceGate),
          withMoAdapt: stack.contains(_kMoAdapt),
          withDarkTheme: stack.contains(_kDarkTheme),
          withAuthFeature: stack.contains(_kAuthFeature),
        ),
        overwriteWhen: _isFlutterCounterDemo,
      );

      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.fvmrc'),
        DevTemplates.fvmrc(),
      );
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.env'),
        'BASE_URL=\n',
      );

      // The committed half of the pair. `.env` itself is gitignored, so
      // without this a fresh clone has no `.env` at all and `build_runner`
      // fails on `app_env.dart` before the new developer can run anything.
      // This one is tracked, holds no values, and says what to fill in.
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.env.example'),
        '# Copy to `.env` and fill in. `.env` is gitignored; this file is not,\n'
        '# so keep it free of real values and add a line here whenever you add\n'
        '# an @EnviedField to lib/config/env/app_env.dart.\n'
        'BASE_URL=\n',
      );

      // The editor side of the .fvmrc above: without dart.flutterSdkPath the
      // extension runs whatever Flutter is on PATH, which is the version the
      // pin exists to stop using. An existing .vscode/ is left alone.
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.vscode', 'settings.json'),
        DevTemplates.vscodeSettings(),
      );
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.vscode', 'launch.json'),
        DevTemplates.vscodeLaunch(),
      );

      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), 'flutter_native_splash.yaml'),
        DevTemplates.nativeSplash(),
      );

      await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'analysis_options.yaml'),
          DevTemplates.analysisOptions(stateManagement: stateManagement));

      // The one generated document aimed at a person rather than a task: what
      // the project is, how to run it, how the layers fit together, where the
      // rest of docs/ picks up. `flutter create` always leaves its own README
      // behind and existing files are never clobbered, so — as with main.dart
      // above — the stock one is replaced explicitly and anything the team
      // wrote is left alone.
      //
      // Flavors are set up later, by `moarch create flavors`, so the flavor
      // list is empty here and the section generates as the setup walkthrough.
      // `moarch update readme` re-reads flavorizr.yaml and rewrites it with
      // the real flavors once they exist.
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), 'README.md'),
        ReadmeTemplates.projectReadme(
          projectName:
              ScaffoldContext.detect(p.absolute(targetPath)).projectName,
          stateManagement: stateManagement,
          withDio: stack.contains(_kDio),
          withRouter: stack.contains(_kRouter),
          withAuthFeature: stack.contains(_kAuthFeature),
          withFirebaseAuthFeature: firebaseAuthFeature,
          withFirebase: stack.contains(_kFirestore) ||
              stack.contains(_kFirebaseAuth) ||
              stack.contains(_kCrashlytics) ||
              stack.contains(_kFirebaseNotifications),
          withFirestore: stack.contains(_kFirestore),
          withCrashlytics: stack.contains(_kCrashlytics),
          withFirebaseNotifications: stack.contains(_kFirebaseNotifications),
          withNotifications: stack.contains(_kNotificationsService),
          withLocalization: stack.contains(_kLocalizations),
          withEasyLocalization: stack.contains(_kEasyLocalization),
          withBiometric: stack.contains(_kBiometricAuth),
          withDarkTheme: stack.contains(_kDarkTheme),
          withWorkflows: stack.contains(_kWorkflows),
        ),
        overwriteWhen: _isFlutterStockReadme,
      );

      await FileUtils.writeFile(
        p.join(
            p.absolute(targetPath), 'docs', 'CHECKLIST_BEFORE_DEPLOYMENT.md'),
        DocsTemplates.prodChecklist(),
      );

      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), 'docs', 'SECURITY_BEFORE_DEPLOYMENT.md'),
        DocsTemplates.securityChecklist(),
      );

      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), 'docs', 'GENERATE_JKS_FILE.md'),
        DocsTemplates.generateJKS(),
      );
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), 'docs', 'STEPS_FOR_WORKFLOW.md'),
        DocsTemplates.stepsForWorkflow(),
      );

      // The platform-side work the generated Firebase code depends on —
      // config files, sign-in providers, SHA fingerprints, the iOS URL
      // scheme. None of it is visible from the Dart, and all of it fails at
      // runtime rather than at build time.
      if (stack.contains(_kFirestore) ||
          stack.contains(_kFirebaseAuth) ||
          stack.contains(_kCrashlytics) ||
          stack.contains(_kFirebaseNotifications)) {
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'docs', 'FIREBASE_SETUP.md'),
          DocsTemplates.firebaseSetup(
            withAuth: stack.contains(_kFirebaseAuth),
            withGoogleSignIn: firebaseAuthFeature,
            withFirestore: stack.contains(_kFirestore),
            withCrashlytics: stack.contains(_kCrashlytics),
            withMessaging: stack.contains(_kFirebaseNotifications),
          ),
        );
      }

      if (stack.contains(_kWorkflows)) {
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), '.github', 'workflows',
              'unified_workflow.yml'),
          WorkflowTemplates.unifiedWorkflow(
            stateManagement: stateManagement,
          ),
        );
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), '.github', 'workflows', 'csa.yml'),
          WorkflowTemplates.csaWorkflow(),
        );
        await FileUtils.writeFile(
          p.join(
              p.absolute(targetPath), '.github', 'workflows', 'build_ipa.yml'),
          WorkflowTemplates.buildIOS(
            withFirebase: stack.contains(_kFirestore) ||
                stack.contains(_kFirebaseAuth) ||
                stack.contains(_kCrashlytics) ||
                stack.contains(_kFirebaseNotifications),
            withPushEntitlements: stack.contains(_kFirebaseNotifications),
          ),
        );
        await FileUtils.writeFile(
          p.join(
              p.absolute(targetPath), '.github', 'workflows', 'build_apk.yml'),
          WorkflowTemplates.buildANDROID(),
        );
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), '.github', 'workflows',
              'deploy_stores.yml'),
          WorkflowTemplates.deployWorkflow(),
        );
      }

      // Secrets and generated files that must never be committed.
      const ignoreRules = [
        '.fvm/',
        'android/key.properties',
        'android/*.jks',
        '*.jks',
        '*.jks.old',
        '*.keystore',
        '.env',
        // The template is meant to be committed; the negation keeps it that
        // way under a broader `.env*` rule further up someone's file.
        '!.env.example',
        'lib/config/env/app_env.g.dart',
      ];

      // `flutter create` projects already have a .gitignore, and writeFile
      // never overwrites existing files — so append the missing rules instead.
      final gitignoreFile = File(p.join(p.absolute(targetPath), '.gitignore'));
      if (!gitignoreFile.existsSync() || dryRun) {
        await FileUtils.writeFile(
          gitignoreFile.path,
          '# Secrets & generated files (moarch)\n${ignoreRules.join('\n')}\n',
        );
      } else {
        final gitignore = await gitignoreFile.readAsString();
        final existingRules = gitignore
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toSet();
        final missingRules =
            ignoreRules.where((rule) => !existingRules.contains(rule));
        if (missingRules.isNotEmpty) {
          await gitignoreFile.writeAsString(
            '${gitignore.trimRight()}\n\n'
            '# Secrets & generated files (moarch)\n'
            '${missingRules.join('\n')}\n',
          );
        }
      }

      if (dryRun) {
        _logger.info('  Would update pubspec.yaml with:');
        for (final dep in [...defaultDependencies, ...devDependencies]) {
          _logger.info('    + $dep');
        }
      } else {
        await PubspecUtils.ensureDependencies(
          p.absolute(targetPath),
          dependencies: defaultDependencies,
          devDependencies: devDependencies,
        );
      }

      if (stack.contains(_kLocalizations)) {
        // ARB files (flutter_localizations uses .arb, not .json)
        await FileUtils.createDir(
            p.join(p.absolute(targetPath), 'lib', 'l10n'));
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'lib', 'l10n', 'app_en.arb'),
          '{\n  "@@locale": "en",\n  "appTitle": "Moarch App",\n  "welcome": "Welcome"\n}\n',
        );
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'lib', 'l10n', 'app_pt.arb'),
          '{\n  "@@locale": "pt",\n  "appTitle": "App Moarch",\n  "welcome": "Bem-vindo"\n}\n',
        );
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'lib', 'l10n', 'l10n.dart'),
          "import 'dart:ui';\n"
          '\n'
          'class L10n {\n'
          "  static const all = [Locale('en'), Locale('pt')];\n"
          '}\n',
        );

        // l10n.yaml config file at project root
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'l10n.yaml'),
          'arb-dir: lib/l10n\n'
          'template-arb-file: app_en.arb\n'
          'output-localization-file: app_localizations.dart\n\n'
          '# flutter gen-l10n',
        );

        // generate: true under flutter: section
        if (dryRun) {
          _logger.info(
              '  Would set generate: true and uses-material-design: true in pubspec.yaml');
        } else {
          await PubspecUtils.ensureFlutterFlags(
            p.absolute(targetPath),
            flags: ['generate: true', 'uses-material-design: true'],
          );
        }

        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'lib', 'core', 'services',
              'language_service.dart'),
          templates.languageService(),
        );
      }

      if (stack.contains(_kEasyLocalization)) {
        // easy_localization loads JSON translation files from assets.
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'assets', 'translations', 'en.json'),
          '{\n  "appTitle": "Moarch App",\n  "welcome": "Welcome"\n}\n',
        );
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'assets', 'translations', 'pt.json'),
          '{\n  "appTitle": "App Moarch",\n  "welcome": "Bem-vindo"\n}\n',
        );

        if (dryRun) {
          _logger.info(
              '  Would add assets/translations/ under flutter: assets in pubspec.yaml');
        } else {
          await PubspecUtils.ensureAssets(
            p.absolute(targetPath),
            assets: ['assets/translations/'],
          );
        }
      }
      if (!dryRun) {
        await PubspecUtils.ensureFlutterFlags(
          p.absolute(targetPath),
          flags: ['uses-material-design: true'],
        );
      }

      final hasFirebase = stack.contains(_kFirestore) ||
          stack.contains(_kFirebaseAuth) ||
          stack.contains(_kCrashlytics) ||
          stack.contains(_kFirebaseNotifications);

      if (stack.contains(_kFirebaseNotifications)) {
        // APNs entitlements for remote push. Local-only notifications don't
        // get these: aps-environment makes codesigning fail when the
        // provisioning profile lacks the push capability.
        await FileUtils.writeFile(
          p.join(
              p.absolute(targetPath), 'ios', 'Runner', 'Runner.entitlements'),
          IosTemplates.runnerEntitlements(),
        );
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'ios', 'Runner',
              'RunnerProfile.entitlements'),
          IosTemplates.runnerProfileEntitlements(),
        );
      }

      if (hasFirebase) {
        // Used by the build_ipa workflow to (re)link GoogleService-Info.plist
        // into the Xcode project after it's recreated from a CI secret.
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'add_files_to_xcode.rb'),
          IosTemplates.addFilesToXcodeScript(),
        );
      }

      await _patchInfoPlist(infoPlistFile, stack, dryRun: dryRun);
      await _patchAppDelegate(appDelegateFile, stack, dryRun: dryRun);
      await _patchPodfile(podfileFile, stack, dryRun: dryRun);
      await _patchBuildGradle(buildGradleFile, stack, dryRun: dryRun);
      await _patchAndroidManifest(androidManifestFile, stack, dryRun: dryRun);
      await _patchMainActivity(mainActivityFile, stack, dryRun: dryRun);
      await _writeProguardRules(p.absolute(targetPath));

      progress.complete('Done');
    } catch (e) {
      progress.fail('Failed: $e');
      if (!dryRun) {
        FileUtils.rollback();
        if (pubspecExisted && pubspecBackup != null) {
          await pubspecFile.writeAsString(pubspecBackup);
        } else if (!pubspecExisted && pubspecFile.existsSync()) {
          await pubspecFile.delete();
        }
        if (analysisOptionsBackup != null) {
          await analysisOptionsFile.writeAsString(analysisOptionsBackup);
        }
        if (infoPlistBackup != null) {
          await infoPlistFile.writeAsString(infoPlistBackup);
        }
        if (appDelegateBackup != null) {
          await appDelegateFile.writeAsString(appDelegateBackup);
        }
        if (podfileBackup != null) {
          await podfileFile.writeAsString(podfileBackup);
        }
        if (buildGradleBackup != null) {
          await buildGradleFile.writeAsString(buildGradleBackup);
        }
        if (androidManifestBackup != null) {
          await androidManifestFile.writeAsString(androidManifestBackup);
        }
        if (mainActivityFile != null && mainActivityBackup != null) {
          await mainActivityFile.writeAsString(mainActivityBackup);
        }
        _logger.info('  Rolled back partially generated files.');
      }
      return 1;
    }

    if (dryRun) {
      _logger.info('');
      _logger.info('Dry run — the following files would be created:');
      for (final path in FileUtils.plannedWrites) {
        _logger.info('  ${p.relative(path, from: p.absolute(targetPath))}');
      }
      _logger.info('');
      _logger.info('Run without --dry-run to actually scaffold.');
      return 0;
    }

    // Written last, so it only ever describes a scaffold that completed.
    await manifest.save(p.absolute(targetPath));

    _logger.success('');
    _logger.success('✅  Project scaffolded!');
    _logger.info('');
    // .vscode/settings.json points dart.flutterSdkPath at .fvm/flutter_sdk,
    // and only `fvm use` creates it. Until then the Dart extension does not
    // complain — it quietly falls back to the Flutter on PATH, which is the
    // version .fvmrc exists to stop using. So this comes before pub get.
    _logger.info('  Run: fvm use   (creates .fvm/flutter_sdk, which');
    _logger
        .info('       .vscode/settings.json points the editor at — until it');
    _logger
        .info('       exists, debug and the analyzer use your PATH Flutter)');
    _logger.info('');
    _logger.info(
        '  The selected scaffold dependencies were added to pubspec.yaml.');
    _logger.info('  Then:  fvm flutter pub get');
    // config/env/app_env.dart is a `part` of an envied-generated file, so the
    // project does not analyze cleanly until build_runner has produced
    // app_env.g.dart. Say so here rather than letting it look like a bug.
    _logger.info(
        '  Then:  fvm dart run build_runner build --delete-conflicting-outputs');
    _logger.info(
        '         (generates config/env/app_env.g.dart from .env — required)');
    _logger.info('');
    // Nothing in the scaffold is reachable without its root wiring, and a
    // main.dart moarch was not allowed to touch has none.
    if (!wroteMainDart) {
      _logger.warn('  lib/main.dart is yours, so it was left alone.');
      _logger.info('    Call `await setupInjector()` before runApp and');
      if (stateManagement.isBloc) {
        _logger
            .info('    provide the app-wide blocs — see the App widget moarch');
        _logger.info('    generates for the shape it expects.');
      } else {
        _logger.info('    wrap your app in a ProviderScope — see the App');
        _logger.info('    widget moarch generates for the shape it expects.');
      }
      _logger.info('');
    }
    _logger
        .info('  Dependencies are registered in lib/config/di/injector.dart,');
    _logger.info('  and `moarch create feature` adds to it.');
    if (!stateManagement.isBloc) {
      _logger.info('  Notifiers stay Riverpod providers and read the locator.');
    }
    _logger.info('');
    if (stateManagement.isBloc) {
      _logger.info('  For the bloc lint rules in analysis_options.yaml,');
      _logger.info('  install the CLI once:');
      _logger.info('    dart pub global activate bloc_tools');
      _logger.info('    bloc lint .');
      _logger.info('');
    }
    if (stack.contains(_kAuthFeature) && !firebaseAuthFeature) {
      _logger
          .info('  Auth feature generated at lib/features/auth/ — adjust the');
      _logger.info(
          '  /auth/* endpoints and token JSON keys in auth_remote_datasource.dart');
      _logger.info('  and core/network/dio_client.dart to your API contract.');
      _logger.info('');
    }
    if (firebaseAuthFeature) {
      _logger.info(
          '  Auth feature generated at lib/features/auth/ — Firebase Auth with');
      _logger.info('  email/password and Google sign-in. Before it runs:');
      _logger.info(
          '    1. flutterfire configure  (writes the google-services files)');
      _logger.info(
          '    2. Firebase console → Authentication → Sign-in method: enable');
      _logger.info('       Email/Password and Google');
      _logger.info(
          '    3. Android: add your SHA-1 and SHA-256 to the Firebase project,');
      _logger.info('       then re-download google-services.json');
      _logger.info(
          '    4. iOS: GIDClientID + the REVERSED_CLIENT_ID URL scheme in');
      _logger
          .info('       Info.plist — `moarch doctor --fix` copies them across');
      _logger.info('');
      _logger.info('  Full guide: docs/FIREBASE_SETUP.md');
      _logger.info('');
    } else if (stack.contains(_kFirestore) ||
        stack.contains(_kFirebaseAuth) ||
        stack.contains(_kCrashlytics) ||
        stack.contains(_kFirebaseNotifications)) {
      _logger.info(
          '  Firebase selected — run `flutterfire configure` before the first');
      _logger.info('  launch. See docs/FIREBASE_SETUP.md.');
      _logger.info('');
    }
    // Said here rather than left to the docs: the palette is the first file
    // most people open, and it is the one place the choice is invisible.
    if (!stack.contains(_kDarkTheme)) {
      _logger
          .info('  One brand palette in core/constants/app_constants.dart —');
      _logger
          .info('  add the dark half later with `moarch create theme --dark`.');
      _logger.info('');
    }
    _logger.info('  moarch create feature <name>   → generate a feature');
    _logger.info('');
    return 0;
  }

  /// Whether [source] is still the counter app `flutter create` writes.
  ///
  /// Matched on private names only that template declares, so a main.dart the
  /// developer wrote is never mistaken for it.
  static bool _isFlutterCounterDemo(String source) =>
      source.contains('_MyHomePageState') &&
      source.contains('_incrementCounter');

  /// Whether [source] is still the README `flutter create` writes.
  ///
  /// Matched on two of its own sentences, so a README the team wrote — even a
  /// short one that happens to mention Flutter — is never mistaken for it.
  static bool _isFlutterStockReadme(String source) =>
      source.contains('A new Flutter project.') &&
      source.contains(
          'This project is a starting point for a Flutter application.');

  /// Whether [source] is still the counter test `flutter create` writes — the
  /// one that pumps the demo app [_isFlutterCounterDemo] matches.
  static bool _isFlutterCounterTest(String source) =>
      source.contains('Counter increments smoke test') &&
      source.contains('MyApp()');

  /// iOS refuses to activate non-default locales and rejects permission
  /// prompts whose usage description is missing, so the selected options
  /// need matching Info.plist entries. Existing keys are never overwritten.
  Future<void> _patchInfoPlist(
    File plistFile,
    Set<String> stack, {
    required bool dryRun,
  }) async {
    final wantsLocales =
        stack.contains(_kLocalizations) || stack.contains(_kEasyLocalization);
    final wantsMedia = stack.contains(_kMediaService);
    final wantsUrlLauncher = stack.contains(_kLaunchUrlService);
    final wantsFcm = stack.contains(_kFirebaseNotifications);
    final wantsBiometrics = stack.contains(_kBiometricAuth);
    final wantsGoogleSignIn =
        stack.contains(_kFirebaseAuth) && stack.contains(_kAuthFeature);
    if (!wantsLocales &&
        !wantsMedia &&
        !wantsUrlLauncher &&
        !wantsFcm &&
        !wantsBiometrics &&
        !wantsGoogleSignIn) {
      return;
    }

    final additions = [
      if (wantsLocales) 'CFBundleLocalizations (en, pt)',
      if (wantsMedia) 'camera/photo library/microphone usage descriptions',
      if (wantsUrlLauncher) 'LSApplicationQueriesSchemes',
      if (wantsFcm) 'UIBackgroundModes (remote-notification)',
      if (wantsBiometrics) 'NSFaceIDUsageDescription',
      if (wantsGoogleSignIn) 'GIDClientID + the Google sign-in URL scheme',
    ].join(' and ');

    if (dryRun) {
      _logger.info('  Would add $additions to ios/Runner/Info.plist');
      return;
    }
    if (!plistFile.existsSync()) {
      _logger.info(
          '  Note: ios/Runner/Info.plist not found — add $additions manually '
          'once the iOS folder exists.');
      return;
    }

    var content = await plistFile.readAsString();
    if (wantsLocales) {
      content = PlistUtils.ensureLocalizations(content, ['en', 'pt']);
    }
    if (wantsMedia) {
      content = PlistUtils.ensureEntries(content, {
        'NSCameraUsageDescription':
            'This app uses the camera to take photos and record videos.',
        'NSPhotoLibraryUsageDescription':
            'This app accesses your photo library so you can pick images.',
        'NSMicrophoneUsageDescription':
            'This app uses the microphone when recording videos.',
      });
    }
    if (wantsBiometrics) {
      // Face ID requires an explicit usage description on iOS; Touch ID does
      // not, but the key is harmless to include either way.
      content = PlistUtils.ensureEntries(content, {
        'NSFaceIDUsageDescription':
            'This app uses Face ID to verify your identity.',
      });
    }
    if (wantsUrlLauncher) {
      // canLaunchUrl returns false on iOS for schemes not declared here,
      // which would force every link into the in-app web view fallback.
      content = PlistUtils.ensureArray(
        content,
        'LSApplicationQueriesSchemes',
        ['https', 'http', 'mailto', 'tel', 'sms'],
      );
    }
    if (wantsFcm) {
      // Without the remote-notification background mode, FCM messages are
      // only delivered while the app is in the foreground.
      content = PlistUtils.ensureArray(
        content,
        'UIBackgroundModes',
        ['fetch', 'remote-notification'],
      );
    }
    if (wantsGoogleSignIn) {
      content = _patchGoogleSignInPlist(plistFile, content);
    }
    await plistFile.writeAsString(content);
    _logger.info('  Updated ios/Runner/Info.plist with $additions.');
  }

  /// Adds the two iOS keys Google sign-in needs in `Info.plist`: `GIDClientID`
  /// and the `REVERSED_CLIENT_ID` URL scheme. The plugin never reads
  /// GoogleService-Info.plist itself.
  ///
  /// Real values are lifted from that plist when `flutterfire configure` has
  /// run; otherwise placeholders go in and `moarch doctor --fix` finishes.
  String _patchGoogleSignInPlist(File plistFile, String content) {
    final googleServices =
        File(p.join(p.dirname(plistFile.path), 'GoogleService-Info.plist'));

    String? clientId;
    String? reversedClientId;
    if (googleServices.existsSync()) {
      final source = googleServices.readAsStringSync();
      clientId = PlistUtils.readString(source, 'CLIENT_ID');
      reversedClientId = PlistUtils.readString(source, 'REVERSED_CLIENT_ID');
    }

    if (clientId == null || reversedClientId == null) {
      _logger.warn(
          '  ios/Runner/GoogleService-Info.plist not found — Info.plist got '
          'placeholder Google client ids.');
      _logger.info('    Run `flutterfire configure`, then `moarch doctor --fix`'
          ' to fill them in.');
    }

    final patched = PlistUtils.ensureEntries(content, {
      'GIDClientID': clientId ?? PlistUtils.googleClientIdPlaceholder,
    });

    return PlistUtils.ensureUrlScheme(
      patched,
      reversedClientId ?? PlistUtils.googleReversedClientIdPlaceholder,
      comment: reversedClientId == null
          ? 'moarch: replace with REVERSED_CLIENT_ID from GoogleService-Info.plist'
          : 'Google sign-in (REVERSED_CLIENT_ID)',
    );
  }

  /// flutter_local_notifications needs the UNUserNotificationCenter delegate
  /// wired up in AppDelegate.swift; without it, foreground notifications and
  /// taps are not delivered on iOS. Skipped when the user already touched
  /// UNUserNotificationCenter or customized away the registrant anchor line.
  Future<void> _patchAppDelegate(
    File appDelegateFile,
    Set<String> stack, {
    required bool dryRun,
  }) async {
    if (!stack.contains(_kNotificationsService)) return;

    const addition = 'UNUserNotificationCenter delegate wiring';

    if (dryRun) {
      _logger.info('  Would add $addition to ios/Runner/AppDelegate.swift');
      return;
    }
    if (!appDelegateFile.existsSync()) {
      _logger.info('  Note: ios/Runner/AppDelegate.swift not found — add the '
          'UNUserNotificationCenter delegate manually once the iOS folder '
          'exists (see the comment in notifications_service.dart).');
      return;
    }

    final content = await appDelegateFile.readAsString();
    final patched = SwiftUtils.ensureNotificationDelegate(content);
    if (patched == content) return;
    await appDelegateFile.writeAsString(patched);
    _logger.info('  Updated ios/Runner/AppDelegate.swift with $addition.');
  }

  /// permission_handler compiles every permission group's native code by
  /// default, pulling in usage-description requirements for permissions the
  /// app never requests. Only camera/photos are turned on.
  ///
  /// A missing `ios/Podfile` is written rather than skipped, with the same
  /// block already wired in.
  Future<void> _patchPodfile(
    File podfileFile,
    Set<String> stack, {
    required bool dryRun,
  }) async {
    final wantsMedia = stack.contains(_kMediaService);

    if (!podfileFile.existsSync()) {
      if (dryRun) {
        _logger.info('  Would create ios/Podfile with permission_handler '
            'defaults (camera/photos only)');
        return;
      }
      await FileUtils.writeFile(
        podfileFile.path,
        PodfileUtils.defaultPodfile(camera: wantsMedia, photos: wantsMedia),
      );
      _logger.info('  Created ios/Podfile with permission_handler defaults '
          '(camera/photos only).');
      return;
    }

    const addition =
        'permission_handler GCC_PREPROCESSOR_DEFINITIONS (camera/photos only)';
    if (dryRun) {
      _logger.info('  Would add $addition to ios/Podfile');
      return;
    }

    final content = await podfileFile.readAsString();
    final patched = PodfileUtils.ensurePermissionHandlerDefinitions(
      content,
      camera: wantsMedia,
      photos: wantsMedia,
    );
    if (patched == content) return;
    await podfileFile.writeAsString(patched);
    _logger.info('  Updated ios/Podfile with $addition.');
  }

  /// flutter_local_notifications needs Java 8+ core library desugaring
  /// enabled on Android, or `flutter build apk`/`appbundle` fails the first
  /// time it runs with the notifications service enabled.
  Future<void> _patchBuildGradle(
    File buildGradleFile,
    Set<String> stack, {
    required bool dryRun,
  }) async {
    if (!stack.contains(_kNotificationsService)) return;

    const addition =
        'core library desugaring (isCoreLibraryDesugaringEnabled + desugar_jdk_libs)';

    if (!buildGradleFile.existsSync()) {
      _logger.info('  Note: android/app/build.gradle.kts not found — enable '
          'core library desugaring manually once the android folder exists '
          '(flutter_local_notifications requires it).');
      return;
    }

    if (dryRun) {
      _logger.info('  Would add $addition to android/app/build.gradle.kts');
      return;
    }

    final content = await buildGradleFile.readAsString();
    final patched = GradleUtils.ensureCoreLibraryDesugaring(content);
    if (patched == content) return;
    await buildGradleFile.writeAsString(patched);
    _logger.info('  Updated android/app/build.gradle.kts with $addition.');
  }

  /// local_auth needs the `USE_BIOMETRIC` permission declared, or biometric
  /// prompts silently fail to appear on Android.
  Future<void> _patchAndroidManifest(
    File manifestFile,
    Set<String> stack, {
    required bool dryRun,
  }) async {
    if (!stack.contains(_kBiometricAuth)) return;

    const addition = 'USE_BIOMETRIC permission';

    if (!manifestFile.existsSync()) {
      _logger.info(
          '  Note: android/app/src/main/AndroidManifest.xml not found — add '
          'the $addition manually once the android folder exists.');
      return;
    }

    if (dryRun) {
      _logger.info(
          '  Would add $addition to android/app/src/main/AndroidManifest.xml');
      return;
    }

    final content = await manifestFile.readAsString();
    final patched = ManifestUtils.ensurePermissions(
      content,
      ['android.permission.USE_BIOMETRIC'],
    );
    if (patched == content) return;
    await manifestFile.writeAsString(patched);
    _logger.info(
        '  Updated android/app/src/main/AndroidManifest.xml with $addition.');
  }

  /// local_auth's biometric prompt is shown by the native Android side as a
  /// dialog fragment, which requires the hosting activity to be a
  /// FragmentActivity — the default FlutterActivity template isn't one.
  Future<void> _patchMainActivity(
    File? mainActivityFile,
    Set<String> stack, {
    required bool dryRun,
  }) async {
    if (!stack.contains(_kBiometricAuth)) return;

    const addition = 'FlutterFragmentActivity (required by local_auth)';

    if (mainActivityFile == null || !mainActivityFile.existsSync()) {
      _logger
          .info('  Note: MainActivity.kt not found — make MainActivity extend '
              'FlutterFragmentActivity manually once the android folder exists '
              '(local_auth requires it).');
      return;
    }

    if (dryRun) {
      _logger.info('  Would update MainActivity to use $addition');
      return;
    }

    final content = await mainActivityFile.readAsString();
    final patched = KotlinUtils.ensureFragmentActivity(content);
    if (patched == content) return;
    await mainActivityFile.writeAsString(patched);
    _logger.info('  Updated MainActivity to use $addition.');
  }

  /// R8 renames and strips whatever it cannot see being called, which is most
  /// of what the Flutter engine and its plugins reach for reflectively. The
  /// rules go in from the start so that turning minification on before a
  /// release is the one gradle block in docs/SECURITY_BEFORE_DEPLOYMENT.md,
  /// not that block plus an evening of chasing release-only crashes.
  ///
  /// Written whether or not R8 is enabled yet — an unreferenced
  /// `proguard-rules.pro` costs the build nothing.
  Future<void> _writeProguardRules(String projectRoot) async {
    final appDir = Directory(p.join(projectRoot, 'android', 'app'));
    if (!appDir.existsSync()) {
      _logger.info('  Note: android/app not found — copy the ProGuard rules '
          'from docs/SECURITY_BEFORE_DEPLOYMENT.md once the android folder '
          'exists.');
      return;
    }
    await FileUtils.writeFile(
      p.join(appDir.path, 'proguard-rules.pro'),
      AndroidTemplates.proguardRules(),
    );
  }

  /// MainActivity.kt/.java lives under a package-name folder that varies per
  /// project (e.g. android/app/src/main/kotlin/com/example/app/), so it can't
  /// be addressed by a fixed path like AndroidManifest.xml.
  File? _findMainActivityFile(String projectRoot) {
    for (final base in ['kotlin', 'java']) {
      final dir =
          Directory(p.join(projectRoot, 'android', 'app', 'src', 'main', base));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File &&
            (entity.path.endsWith('MainActivity.kt') ||
                entity.path.endsWith('MainActivity.java'))) {
          return entity;
        }
      }
    }
    return null;
  }

  Future<void> _buildCore(
    String libPath,
    Set<String> stack,
    StackTemplates templates,
  ) async {
    final c = p.join(libPath, 'core');

    // The auth feature against the REST client — the variant that owns a
    // refresh token, and so the only one whose `/auth/*` paths ApiConstants
    // declares and whose refresh the Dio interceptor calls back into.
    // Firebase Auth wins when both are selected, matching `run()`.
    final restAuthFeature =
        stack.contains(_kAuthFeature) && !stack.contains(_kFirebaseAuth);

    await FileUtils.writeFile(
      p.join(c, 'errors', 'app_exception.dart'),
      ErrorTemplates.appException(
        hasDio: stack.contains(_kDio),
        hasFirebase:
            stack.contains(_kFirestore) || stack.contains(_kFirebaseAuth),
        hasFirebaseAuth: stack.contains(_kFirebaseAuth),
        hasCrashlytics: stack.contains(_kCrashlytics),
      ),
    );

    await FileUtils.writeFile(
      p.join(c, 'utils', 'extensions.dart'),
      CoreTemplates.extensions(),
    );
    await FileUtils.writeFile(
      p.join(c, 'utils', 'app_logger.dart'),
      CoreTemplates.appLogger(withCrashlytics: stack.contains(_kCrashlytics)),
    );
    // Riverpod's notifiers share a runAction mixin; a bloc's sealed states
    // leave nothing central to declare.
    if (templates.hasActionBase) {
      await FileUtils.writeFile(
        p.join(c, 'utils', templates.actionBaseFile),
        templates.actionBase(),
      );
    }
    await FileUtils.writeFile(
      p.join(c, 'constants', 'app_constants.dart'),
      CoreTemplates.appConstants(withDark: stack.contains(_kDarkTheme)),
    );
    await FileUtils.writeFile(
      p.join(c, 'constants', 'api_constants.dart'),
      CoreTemplates.apiConstants(withAuthFeature: restAuthFeature),
    );
    if (stack.contains(_kDio)) {
      await FileUtils.writeFile(
        p.join(c, 'network', 'dio_client.dart'),
        templates.dioClient(withAuthFeature: restAuthFeature),
      );
      await FileUtils.writeFile(
        p.join(c, 'network', 'safe_api_call.dart'),
        CoreTemplates.safeApiCall(),
      );
      // The envelope a paginated endpoint answers with. Nothing generated
      // reads it yet — it is here so the first feature that paginates has one
      // shape to share instead of one per repository, and it is safe to
      // delete in a project whose API never pages.
      await FileUtils.writeFile(
        p.join(c, 'network', 'paginated.dart'),
        CoreTemplates.paginated(),
      );
    }
    // The Firebase counterpart of safeApiCall — every generated Firestore and
    // Firebase Auth call goes through it, so the failures reach the UI as the
    // same AppException a REST call would raise.
    if (stack.contains(_kFirestore) || stack.contains(_kFirebaseAuth)) {
      await FileUtils.writeFile(
        p.join(c, 'network', 'safe_firebase_call.dart'),
        CoreTemplates.safeFirebaseCall(
          withAuth: stack.contains(_kFirebaseAuth),
        ),
      );
    }
    await FileUtils.writeFile(
      p.join(c, 'security', 'secure_storage.dart'),
      SecurityTemplates.secureStorage(),
    );
    await FileUtils.writeFile(
      p.join(c, 'security', 'validation_service.dart'),
      SecurityTemplates.validationService(),
    );
    if (stack.contains(_kBiometricAuth)) {
      await FileUtils.writeFile(
        p.join(c, 'security', 'biometric_service.dart'),
        SecurityTemplates.biometricService(),
      );
    }

    if (stack.contains(_kMediaService)) {
      await FileUtils.writeFile(
        p.join(c, 'services', 'media_service.dart'),
        ServicesTemplates.mediaService(),
      );
    }
    if (stack.contains(_kLaunchUrlService)) {
      await FileUtils.writeFile(
        p.join(c, 'services', 'url_launcher_service.dart'),
        ServicesTemplates.launchUrlService(),
      );
    }
    if (stack.contains(_kNotificationsService)) {
      await FileUtils.writeFile(
        p.join(c, 'services', 'notifications_service.dart'),
        ServicesTemplates.notificationsService(),
      );
    }
    if (stack.contains(_kFirebaseNotifications)) {
      await FileUtils.writeFile(
        p.join(c, 'services', 'firebase_notifications_service.dart'),
        ServicesTemplates.firebaseNotificationsService(),
      );
    }

    if (stack.contains(_kDebouncerService)) {
      await FileUtils.writeFile(
        p.join(c, 'services', 'debouncer_service.dart'),
        ServicesTemplates.debouncerService(),
      );
    }

    await FileUtils.writeFile(
      p.join(c, 'services', 'permission_service.dart'),
      ServicesTemplates.permissionService(),
    );
  }

  /// [withPushNotifications] registers the device's FCM token with the backend
  /// on login, on register and on session restore.
  Future<void> _buildAuthFeature(
    String libPath,
    StackTemplates templates, {
    required bool withPushNotifications,
  }) async {
    final f = p.join(libPath, 'features', 'auth');

    await FileUtils.writeFile(
      p.join(f, 'domain', 'entities', 'auth_tokens_entity.dart'),
      templates.authEntity(),
    );
    await FileUtils.writeFile(
      p.join(f, 'domain', 'repositories', 'auth_repository.dart'),
      templates.authRepositoryInterface(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'models', 'auth_tokens_model.dart'),
      templates.authModel(),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'datasources', 'auth_remote_datasource.dart'),
      templates.authRemoteDatasource(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'repositories', 'auth_repository_impl.dart'),
      templates.authRepositoryImpl(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', templates.stateDir, 'auth_state.dart'),
      templates.authState(),
    );
    if (templates.isBloc) {
      await FileUtils.writeFile(
        p.join(f, 'presentation', 'blocs', 'auth_event.dart'),
        templates.authEvent(),
      );
    }
    await FileUtils.writeFile(
      p.join(
          f, 'presentation', templates.holderDir, templates.holderFile('auth')),
      templates.authHolder(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'views', 'login_view.dart'),
      templates.authLoginView(),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'views', 'register_view.dart'),
      templates.authRegisterView(),
    );
  }

  /// The same feature against Firebase Auth: email/password and Google
  /// sign-in, with no token storage — Firebase persists the session itself.
  ///
  /// [withFirestore] additionally keeps a `users/{uid}` profile document in
  /// step with the account, and [withPushNotifications] registers the device's
  /// FCM token against the user on sign-in and on session restore.
  Future<void> _buildFirebaseAuthFeature(
    String libPath,
    StackTemplates templates, {
    required bool withFirestore,
    required bool withPushNotifications,
  }) async {
    final f = p.join(libPath, 'features', 'auth');

    await FileUtils.writeFile(
      p.join(f, 'domain', 'entities', 'auth_user_entity.dart'),
      templates.firebaseAuthEntity(),
    );
    await FileUtils.writeFile(
      p.join(f, 'domain', 'repositories', 'auth_repository.dart'),
      templates.firebaseAuthRepositoryInterface(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'models', 'auth_user_model.dart'),
      templates.firebaseAuthModel(withFirestore: withFirestore),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'datasources', 'auth_remote_datasource.dart'),
      templates.firebaseAuthRemoteDatasource(
        withFirestore: withFirestore,
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'repositories', 'auth_repository_impl.dart'),
      templates.firebaseAuthRepositoryImpl(
        withFirestore: withFirestore,
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', templates.stateDir, 'auth_state.dart'),
      templates.firebaseAuthState(),
    );
    if (templates.isBloc) {
      await FileUtils.writeFile(
        p.join(f, 'presentation', 'blocs', 'auth_event.dart'),
        templates.firebaseAuthEvent(),
      );
    }
    await FileUtils.writeFile(
      p.join(
          f, 'presentation', templates.holderDir, templates.holderFile('auth')),
      templates.firebaseAuthHolder(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'views', 'login_view.dart'),
      templates.firebaseAuthLoginView(),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'views', 'register_view.dart'),
      templates.firebaseAuthRegisterView(),
    );
  }

  Future<void> _buildConfig(
    String libPath,
    Set<String> stack,
    StackTemplates templates,
  ) async {
    final c = p.join(libPath, 'config');
    await FileUtils.writeFile(
      p.join(c, 'env', 'app_env.dart'),
      ConfigTemplates.appEnv(),
    );
    await FileUtils.writeFile(
      p.join(c, 'theme', 'app_theme.dart'),
      ConfigTemplates.appTheme(withDark: stack.contains(_kDarkTheme)),
    );
    if (stack.contains(_kRouter)) {
      await FileUtils.writeFile(
        p.join(c, 'router', 'app_router.dart'),
        templates.appRouter(withAuth: stack.contains(_kAuthFeature)),
      );
      await FileUtils.writeFile(
        p.join(c, 'router', 'app_routes.dart'),
        ConfigTemplates.appRoutes(),
      );
    }
    if (stack.contains(_kFirestore) || stack.contains(_kFirebaseAuth)) {
      await FileUtils.writeFile(
        p.join(c, 'firebase', 'firebase_providers.dart'),
        templates.firebaseProviders(
            hasAuth: stack.contains(_kFirebaseAuth),
            hasDb: stack.contains(_kFirestore)),
      );
    }

    // The get_it wiring — everything the checklist selected, registered in one
    // place. Both stacks get it: the difference is only that a bloc project's
    // state holders are in there too.
    await FileUtils.writeFile(
      p.join(c, 'di', 'injector.dart'),
      templates.injector(
        withDio: stack.contains(_kDio),
        withFirestore: stack.contains(_kFirestore),
        withFirebaseAuth: stack.contains(_kFirebaseAuth),
        withAuthFeature: stack.contains(_kAuthFeature),
        withFirebaseAuthFeature:
            stack.contains(_kAuthFeature) && stack.contains(_kFirebaseAuth),
        withMedia: stack.contains(_kMediaService),
        withUrlLauncher: stack.contains(_kLaunchUrlService),
        withNotifications: stack.contains(_kNotificationsService),
        withFirebaseNotifications: stack.contains(_kFirebaseNotifications),
        withDebouncer: stack.contains(_kDebouncerService),
        withBiometric: stack.contains(_kBiometricAuth),
        withLocalization: stack.contains(_kLocalizations),
      ),
    );
  }

  Future<void> _buildShared(
    String libPath,
    Set<String> stack,
    StateManagement stateManagement,
  ) async {
    final s = p.join(libPath, 'shared', 'widgets');
    final hasRouter = stack.contains(_kRouter);

    // Taken from the checklist rather than from disk: in a dry run nothing has
    // been written yet, so detection would report every option as absent.
    final variants = WidgetVariants(
      hasBiometric: stack.contains(_kBiometricAuth),
      hasFirestore: stack.contains(_kFirestore),
      hasDio: stack.contains(_kDio),
      hasDarkTheme: stack.contains(_kDarkTheme),
      stateManagement: stateManagement,
    );

    // Only the common set (see WidgetCatalog) is scaffolded here; the rest of
    // the kit is added on demand with `moarch create widget <name>`.
    final specs = [
      ...WidgetCatalog.commonFor(stateManagement),
      if (stack.contains(_kMaintenanceGate))
        ...WidgetCatalog.resolve(
          ['maintenance-gate'],
          stateManagement: stateManagement,
        ),
      if (stack.contains(_kMoAdapt))
        ...WidgetCatalog.resolve(['mo-adapt'],
            stateManagement: stateManagement),
    ];

    for (final spec in {for (final spec in specs) spec.name: spec}.values) {
      if (spec.needsRouter && !hasRouter) {
        _logger.info(
          '  Skipped ${spec.title} (needs the GoRouter option) — add it later '
          'with: moarch create widget ${spec.name}',
        );
        continue;
      }
      await FileUtils.writeFile(
        p.join(s, spec.file),
        WidgetCatalog.sourceFor(spec, variants),
      );
    }

    // A catalog of the whole UI kit and how to scaffold the rest on demand.
    await FileUtils.writeFile(
      p.join(p.dirname(libPath), 'docs', 'UI_KIT.md'),
      WidgetCatalog.markdown(),
    );
  }
}
