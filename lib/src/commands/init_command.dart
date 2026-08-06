import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/core/security_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/misc/dev_templates.dart';
import 'package:moarch/src/templates/misc/docs_templates.dart';
import 'package:moarch/src/templates/misc/ios_templates.dart';
import 'package:moarch/src/templates/misc/workflow_templates.dart';
import 'package:moarch/src/templates/ui/auth_templates.dart';
import 'package:moarch/src/templates/ui/firebase_auth_templates.dart';
import 'package:moarch/src/utils/checklist.dart';
import 'package:path/path.dart' as p;

import '../templates/config/config_templates.dart';
import '../templates/core/core_templates.dart';
import '../templates/ui/shared_templates.dart';
import '../utils/file_utils.dart';
import '../utils/gradle_utils.dart';
import '../utils/kotlin_utils.dart';
import '../utils/manifest_utils.dart';
import '../utils/plist_utils.dart';
import '../utils/project_manifest.dart';
import '../utils/podfile_utils.dart';
import '../utils/pubspec_utils.dart';
import '../utils/swift_utils.dart';
import '../utils/widget_catalog.dart';
import '../version.dart';

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
        _kLocalizations,
      };
    } else {
      try {
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
            const ChecklistItem(
              _kDebouncerService,
              defaultOn: false,
              description: 'Debounce rapid user actions (e.g. search input).',
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

    final progress = _logger.progress(
      dryRun ? 'Previewing structure' : 'Creating structure',
    );

    // Records the stack and a hash of every file written, so `moarch update`
    // can later tell an untouched generated file from one the user edited.
    final manifest = ProjectManifest(
      version: packageVersion,
      generatedAt: DateTime.now(),
      stack: stack.toList()..sort(),
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

    // Unversioned, so pub fetches the newest release each package's own
    // constraints allow. That is usually what a fresh scaffold wants — but it
    // does mean pub is free to resolve *backwards* to settle a conflict
    // elsewhere in the set, so a package that breaks when it does gets a floor
    // of its own below.
    final defaultDependencies = <String>[
      'flutter:\n    sdk: flutter',
      'flutter_riverpod: ',
      'flutter_native_splash: ',
      'envied: ',
      'skeletonizer: ',
      'intl:',
      // Floored because app_logger.dart uses PrettyPrinter's `dateTimeFormat`,
      // which replaced the older `printTime` flag partway through logger 2.x.
      'logger: ^2.4.0',
      'connectivity_plus: ',
      if (stack.contains(_kRouter)) 'go_router: ',
      if (stack.contains(_kDio)) 'dio: ',
      if (stack.contains(_kDio)) 'dio_smart_retry: ',
      'flutter_secure_storage: ',
      if (stack.contains(_kFirebaseAuth) ||
          stack.contains(_kFirestore) ||
          stack.contains(_kCrashlytics) ||
          stack.contains(_kFirebaseNotifications))
        'firebase_core: ',
      if (stack.contains(_kFirebaseNotifications)) 'firebase_messaging: ',
      if (stack.contains(_kCrashlytics)) 'firebase_crashlytics: ',
      if (stack.contains(_kFirebaseAuth)) 'firebase_auth: ',
      if (stack.contains(_kFirestore)) 'cloud_firestore: ',
      // Floored because the generated Google flow is written against the 7.x
      // API — `GoogleSignIn.instance`, `initialize()` and `authenticate()`
      // replaced the constructor and `signIn()` of 6.x.
      if (firebaseAuthFeature) 'google_sign_in: ^7.0.0',
      // Pinned, unlike its neighbours, because it is the one package here whose
      // unversioned entry resolves to something broken. file_picker 11 wants
      // win32 ^5, flutter_secure_storage_windows wants win32 ^6, and pub settles
      // that Windows-only conflict by walking file_picker back to 3.0.4 — which
      // predates AGP's `namespace` requirement, so the Android build fails with
      // "Namespace not specified" before the app ever runs.
      if (stack.contains(_kMediaService)) 'file_picker: ^11.0.0',
      if (stack.contains(_kMediaService)) 'image_picker: ',
      // Capped, unlike its neighbours, because permission_handler 13 pulls
      // permission_handler_android 14, whose android/build.gradle.kts is
      // written against AGP 9 / Gradle 9 / Kotlin 2.3 and its built-in Kotlin
      // support. On the AGP 8 toolchain `flutter create` still scaffolds, its
      // top-level `kotlin { compilerOptions { ... } }` block fails to resolve
      // and the build dies in script compilation. 12.x resolves the android
      // impl to 13.x, which is Groovy/AGP 8 and builds; the API the generated
      // PermissionService uses is unchanged across the two.
      'permission_handler: ^12.0.3',
      if (stack.contains(_kLaunchUrlService)) 'url_launcher: ',
      if (stack.contains(_kNotificationsService))
        'flutter_local_notifications: ',
      if (stack.contains(_kNotificationsService)) 'timezone: ',
      if (stack.contains(_kBiometricAuth)) 'local_auth: ',
      if (stack.contains(_kBiometricAuth)) 'local_auth_android: ',
      if (stack.contains(_kBiometricAuth)) 'local_auth_darwin: ',
      if (stack.contains(_kLocalizations))
        'flutter_localizations:\n    sdk: flutter',
      if (stack.contains(_kEasyLocalization)) 'easy_localization: ',
    ];

    final devDependencies = <String>[
      'build_runner: ',
      'envied_generator: ',
      'mogen_unit_tests: ',
      'mogen_integration_tests: ',
      'flutter_lints: ',
    ];

    // False when a main.dart the developer wrote was left in place, which is
    // the one case they have to wire ProviderScope up themselves.
    var wroteMainDart = false;

    try {
      await _buildCore(libPath, stack);
      await _buildConfig(libPath, stack);
      await _buildShared(libPath, stack);
      await FileUtils.createDir(p.join(libPath, 'features'));
      if (stack.contains(_kAuthFeature)) {
        if (firebaseAuthFeature) {
          await _buildFirebaseAuthFeature(
            libPath,
            withFirestore: stack.contains(_kFirestore),
            withPushNotifications: stack.contains(_kFirebaseNotifications),
          );
        } else {
          await _buildAuthFeature(
            libPath,
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

      // `flutter create` always leaves a main.dart behind, and files that
      // already exist are never clobbered — so without this the scaffold's own
      // main.dart, the one that installs ProviderScope and initialises the
      // selected services, was never written at all. The counter demo is
      // replaced; anything the developer has written is not.
      wroteMainDart = await FileUtils.writeFile(
        p.join(libPath, 'main.dart'),
        CoreTemplates.mainDart(
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
        ),
        overwriteWhen: _isFlutterCounterDemo,
      );

      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.fvmrc'),
        DevTemplates.fvmrc(),
      );
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.env'),
        'BASE_URL=',
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
          DevTemplates.analysisOptions());

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
          WorkflowTemplates.unifiedWorkflow(),
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
          ServicesTemplates.languageService(),
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
    _logger.info(
        '  The selected scaffold dependencies were added to pubspec.yaml.');
    _logger.info('  Run: flutter pub get');
    // config/env/app_env.dart is a `part` of an envied-generated file, so the
    // project does not analyze cleanly until build_runner has produced
    // app_env.g.dart. Say so here rather than letting it look like a bug.
    _logger.info(
        '  Then:  dart run build_runner build --delete-conflicting-outputs');
    _logger.info(
        '         (generates config/env/app_env.g.dart from .env — required)');
    _logger.info('');
    // Nothing in the scaffold works without a ProviderScope at the root, and a
    // main.dart moarch was not allowed to touch has none.
    if (!wroteMainDart) {
      _logger.warn('  lib/main.dart is yours, so it was left alone.');
      _logger.info('    Wrap your app in a ProviderScope and initialise the');
      _logger.info(
          '    services you selected — see the App widget moarch generates');
      _logger.info('    for the shape it expects.');
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
    _logger.info('  moarch create feature <name>   → generate a feature');
    _logger.info('');
    return 0;
  }

  /// Whether [source] is still the counter app `flutter create` writes.
  ///
  /// Matched on the two private names only that template declares, so a
  /// main.dart the developer has written — even one that kept `MyApp` — is
  /// never mistaken for it and never replaced.
  static bool _isFlutterCounterDemo(String source) =>
      source.contains('_MyHomePageState') &&
      source.contains('_incrementCounter');

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

  /// Adds the two iOS keys Google sign-in cannot work without: `GIDClientID`,
  /// and the URL scheme built from `REVERSED_CLIENT_ID` that the sign-in
  /// sheet returns through. The plugin does not read GoogleService-Info.plist
  /// itself — both values have to be copied into `Info.plist`.
  ///
  /// When `flutterfire configure` has already run, the real values are lifted
  /// straight out of `ios/Runner/GoogleService-Info.plist`. When it hasn't,
  /// placeholders go in with an XML comment saying what to replace them with,
  /// and `moarch doctor --fix` finishes the job once the file appears.
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

  /// permission_handler is always a dependency (PermissionService is
  /// generated unconditionally), so without this block it compiles every
  /// permission group's native code by default — pulling in usage-description
  /// requirements for permissions the app never requests. Only camera/photos
  /// are turned on, since MediaService (gated by [_kMediaService]) is the
  /// only place generated code ever calls permission_handler.
  ///
  /// When `ios/Podfile` doesn't exist yet (e.g. `moarch init` ran before
  /// `flutter create` scaffolded `ios/`), a generic one is written instead
  /// of skipped, with the same permission block already wired in.
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

  Future<void> _buildCore(String libPath, Set<String> stack) async {
    final c = p.join(libPath, 'core');

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
    await FileUtils.writeFile(
      p.join(c, 'utils', 'action_notifier.dart'),
      CoreTemplates.actionNotifier(),
    );
    await FileUtils.writeFile(
      p.join(c, 'constants', 'app_constants.dart'),
      CoreTemplates.appConstants(),
    );
    await FileUtils.writeFile(
      p.join(c, 'constants', 'api_constants.dart'),
      CoreTemplates.apiConstants(),
    );
    if (stack.contains(_kDio)) {
      await FileUtils.writeFile(
        p.join(c, 'network', 'dio_client.dart'),
        CoreTemplates.dioClient(),
      );
      await FileUtils.writeFile(
        p.join(c, 'network', 'safe_api_call.dart'),
        CoreTemplates.safeApiCall(),
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
    String libPath, {
    required bool withPushNotifications,
  }) async {
    final f = p.join(libPath, 'features', 'auth');

    await FileUtils.writeFile(
      p.join(f, 'domain', 'entities', 'auth_tokens_entity.dart'),
      AuthTemplates.entity(),
    );
    await FileUtils.writeFile(
      p.join(f, 'domain', 'repositories', 'auth_repository.dart'),
      AuthTemplates.repositoryInterface(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'models', 'auth_tokens_model.dart'),
      AuthTemplates.model(),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'datasources', 'auth_remote_datasource.dart'),
      AuthTemplates.remoteDatasource(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'repositories', 'auth_repository_impl.dart'),
      AuthTemplates.repositoryImpl(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'states', 'auth_state.dart'),
      AuthTemplates.state(),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'notifiers', 'auth_notifier.dart'),
      AuthTemplates.notifier(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'views', 'login_view.dart'),
      AuthTemplates.loginView(),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'views', 'register_view.dart'),
      AuthTemplates.registerView(),
    );
  }

  /// The same feature against Firebase Auth: email/password and Google
  /// sign-in, with no token storage — Firebase persists the session itself.
  ///
  /// [withFirestore] additionally keeps a `users/{uid}` profile document in
  /// step with the account, and [withPushNotifications] registers the device's
  /// FCM token against the user on sign-in and on session restore.
  Future<void> _buildFirebaseAuthFeature(
    String libPath, {
    required bool withFirestore,
    required bool withPushNotifications,
  }) async {
    final f = p.join(libPath, 'features', 'auth');

    await FileUtils.writeFile(
      p.join(f, 'domain', 'entities', 'auth_user_entity.dart'),
      FirebaseAuthTemplates.entity(),
    );
    await FileUtils.writeFile(
      p.join(f, 'domain', 'repositories', 'auth_repository.dart'),
      FirebaseAuthTemplates.repositoryInterface(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'models', 'auth_user_model.dart'),
      FirebaseAuthTemplates.model(withFirestore: withFirestore),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'datasources', 'auth_remote_datasource.dart'),
      FirebaseAuthTemplates.remoteDatasource(
        withFirestore: withFirestore,
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'repositories', 'auth_repository_impl.dart'),
      FirebaseAuthTemplates.repositoryImpl(
        withFirestore: withFirestore,
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'states', 'auth_state.dart'),
      FirebaseAuthTemplates.state(),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'notifiers', 'auth_notifier.dart'),
      FirebaseAuthTemplates.notifier(
        withPushNotifications: withPushNotifications,
      ),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'views', 'login_view.dart'),
      FirebaseAuthTemplates.loginView(),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'views', 'register_view.dart'),
      FirebaseAuthTemplates.registerView(),
    );
  }

  Future<void> _buildConfig(String libPath, Set<String> stack) async {
    final c = p.join(libPath, 'config');
    await FileUtils.writeFile(
      p.join(c, 'env', 'app_env.dart'),
      ConfigTemplates.appEnv(),
    );
    await FileUtils.writeFile(
      p.join(c, 'theme', 'app_theme.dart'),
      ConfigTemplates.appTheme(),
    );
    if (stack.contains(_kRouter)) {
      await FileUtils.writeFile(
        p.join(c, 'router', 'app_router.dart'),
        ConfigTemplates.appRouter(),
      );
      await FileUtils.writeFile(
        p.join(c, 'router', 'app_routes.dart'),
        ConfigTemplates.appRoutes(),
      );
    }
    if (stack.contains(_kFirestore) || stack.contains(_kFirebaseAuth)) {
      await FileUtils.writeFile(
        p.join(c, 'firebase', 'firebase_providers.dart'),
        ConfigTemplates.firebaseProviders(
            hasAuth: stack.contains(_kFirebaseAuth),
            hasDb: stack.contains(_kFirestore)),
      );
    }
  }

  Future<void> _buildShared(String libPath, Set<String> stack) async {
    final s = p.join(libPath, 'shared', 'widgets');
    final hasRouter = stack.contains(_kRouter);
    final hasBiometric = stack.contains(_kBiometricAuth);

    // Only the common set (see WidgetCatalog) is scaffolded here; the rest of
    // the kit is added on demand with `moarch create widget <name>`.
    for (final spec in WidgetCatalog.common) {
      if (spec.needsRouter && !hasRouter) {
        _logger.info(
          '  Skipped ${spec.title} (needs the GoRouter option) — add it later '
          'with: moarch create widget ${spec.name}',
        );
        continue;
      }
      final content = spec.name == 'button'
          ? SharedTemplates.appButton(hasBiometricAuth: hasBiometric)
          : spec.template();
      await FileUtils.writeFile(p.join(s, spec.file), content);
    }

    // A catalog of the whole UI kit and how to scaffold the rest on demand.
    await FileUtils.writeFile(
      p.join(p.dirname(libPath), 'docs', 'UI_KIT.md'),
      WidgetCatalog.markdown(),
    );
  }
}
