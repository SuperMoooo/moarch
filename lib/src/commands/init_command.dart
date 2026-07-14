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
import 'package:moarch/src/templates/ui/dialogs_templates.dart';
import 'package:moarch/src/templates/ui/modals_templates.dart';
import 'package:moarch/src/utils/checklist.dart';
import 'package:path/path.dart' as p;

import '../templates/config/config_templates.dart';
import '../templates/core/core_templates.dart';
import '../templates/ui/shared_templates.dart';
import '../utils/file_utils.dart';
import '../utils/gradle_utils.dart';
import '../utils/plist_utils.dart';
import '../utils/podfile_utils.dart';
import '../utils/pubspec_utils.dart';
import '../utils/swift_utils.dart';

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
                  'REST auth feature: tokens + user id in secure storage, session restore on app start.',
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

    // The auth feature calls the API through the Dio client and its refresh
    // interceptor, so generating it without Dio would produce broken imports.
    if (stack.contains(_kAuthFeature) && !stack.contains(_kDio)) {
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
    FileUtils.beginSession(dryRun: dryRun);

    final pubspecFile = File(p.join(p.absolute(targetPath), 'pubspec.yaml'));
    final pubspecExisted = pubspecFile.existsSync();
    final pubspecBackup =
        pubspecExisted ? await pubspecFile.readAsString() : null;

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

    // Caret-pinned to the versions the templates were written against, so a
    // breaking major release of a package can't silently break a fresh
    // scaffold. Bump these alongside template changes.
    final defaultDependencies = <String>[
      'flutter:\n    sdk: flutter',
      'flutter_riverpod: ',
      'flutter_native_splash: ',
      'envied: ',
      'skeletonizer: ',
      'cached_network_image: ',
      'intl:',
      'logger: ',
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
      if (stack.contains(_kMediaService)) 'file_picker: ',
      if (stack.contains(_kMediaService)) 'image_picker: ',
      'permission_handler: ',
      if (stack.contains(_kLaunchUrlService)) 'url_launcher: ',
      if (stack.contains(_kNotificationsService))
        'flutter_local_notifications: ',
      if (stack.contains(_kNotificationsService)) 'timezone: ',
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

    try {
      await _buildCore(libPath, stack);
      await _buildConfig(libPath, stack);
      await _buildShared(libPath);
      await FileUtils.createDir(p.join(libPath, 'features'));
      if (stack.contains(_kAuthFeature)) {
        await _buildAuthFeature(libPath);
      }
      final testPath = p.join(p.absolute(targetPath), 'test');
      await FileUtils.createDir(testPath);
      await FileUtils.createDir(p.join(testPath, 'unit'));
      await FileUtils.createDir(p.join(testPath, 'integration'));

      await FileUtils.writeFile(
        p.join(libPath, 'main.dart'),
        CoreTemplates.mainDart(
          withRouter: stack.contains(_kRouter),
          withLocalization: stack.contains(_kLocalizations),
          withEasyLocalization: stack.contains(_kEasyLocalization),
          withNotificationsService: stack.contains(_kNotificationsService),
          withFirebaseNotifications: stack.contains(_kFirebaseNotifications),
          withCrashlytics: stack.contains(_kCrashlytics),
        ),
      );

      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.fvmrc'),
        '{\n  "flutter": "stable"\n}\n',
      );
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.env'),
        'BASE_URL=',
      );

      await FileUtils.writeFile(
          p.join(p.absolute(targetPath), 'flutter_native_splash.yaml'), '''
        # dart run flutter_native_splash:create --path=flutter_native_splash.yaml
        # No icon because it will use the app icon files in each platform folder
        flutter_native_splash:
          color: '#FFFFFF' # BG COLOR (light mode)
          color_dark: '#000000' # BG COLOR (dark mode)

          android_12:
              color: '#FFFFFF' # BG COLOR (light mode)
              color_dark: '#000000' # BG COLOR (dark mode)
    ''');

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

    _logger.success('');
    _logger.success('✅  Project scaffolded!');
    _logger.info('');
    _logger.info(
        '  The selected scaffold dependencies were added to pubspec.yaml.');
    _logger.info('  Run: flutter pub get');
    _logger.info('');
    if (stack.contains(_kAuthFeature)) {
      _logger
          .info('  Auth feature generated at lib/features/auth/ — adjust the');
      _logger.info(
          '  /auth/* endpoints and token JSON keys in auth_remote_datasource.dart');
      _logger.info('  and core/network/dio_client.dart to your API contract.');
      _logger.info('');
    }
    _logger.info('  moarch create feature <name>   → generate a feature');
    _logger.info('');
    return 0;
  }

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
    if (!wantsLocales && !wantsMedia && !wantsUrlLauncher && !wantsFcm) {
      return;
    }

    final additions = [
      if (wantsLocales) 'CFBundleLocalizations (en, pt)',
      if (wantsMedia) 'camera/photo library/microphone usage descriptions',
      if (wantsUrlLauncher) 'LSApplicationQueriesSchemes',
      if (wantsFcm) 'UIBackgroundModes (remote-notification)',
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
    await plistFile.writeAsString(content);
    _logger.info('  Updated ios/Runner/Info.plist with $additions.');
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

  Future<void> _buildCore(String libPath, Set<String> stack) async {
    final c = p.join(libPath, 'core');

    await FileUtils.writeFile(
      p.join(c, 'errors', 'app_exception.dart'),
      ErrorTemplates.appException(
        hasDio: stack.contains(_kDio),
        hasFirebase:
            stack.contains(_kFirestore) || stack.contains(_kFirebaseAuth),
        hasCrashlytics: stack.contains(_kCrashlytics),
      ),
    );

    await FileUtils.writeFile(
      p.join(c, 'utils', 'extensions.dart'),
      CoreTemplates.extensions(),
    );
    await FileUtils.writeFile(
      p.join(c, 'utils', 'app_logger.dart'),
      CoreTemplates.appLogger(),
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
    await FileUtils.writeFile(
      p.join(c, 'security', 'secure_storage.dart'),
      SecurityTemplates.secureStorage(),
    );
    await FileUtils.writeFile(
      p.join(c, 'security', 'validation_service.dart'),
      SecurityTemplates.validationService(),
    );

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

  Future<void> _buildAuthFeature(String libPath) async {
    final f = p.join(libPath, 'features', 'auth');

    await FileUtils.writeFile(
      p.join(f, 'domain', 'entities', 'auth_tokens_entity.dart'),
      AuthTemplates.entity(),
    );
    await FileUtils.writeFile(
      p.join(f, 'domain', 'repositories', 'auth_repository.dart'),
      AuthTemplates.repositoryInterface(),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'models', 'auth_tokens_model.dart'),
      AuthTemplates.model(),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'datasources', 'auth_remote_datasource.dart'),
      AuthTemplates.remoteDatasource(),
    );
    await FileUtils.writeFile(
      p.join(f, 'data', 'repositories', 'auth_repository_impl.dart'),
      AuthTemplates.repositoryImpl(),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'states', 'auth_state.dart'),
      AuthTemplates.state(),
    );
    await FileUtils.writeFile(
      p.join(f, 'presentation', 'notifiers', 'auth_notifier.dart'),
      AuthTemplates.notifier(),
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

  Future<void> _buildShared(String libPath) async {
    final s = p.join(libPath, 'shared', 'widgets');

    await FileUtils.writeFile(
      p.join(s, 'overlays', 'app_dialogs.dart'),
      DialogsTemplates.appDialog(),
    );
    await FileUtils.writeFile(
      p.join(s, 'overlays', 'app_bottom_modals.dart'),
      ModalsTemplates.appBottomModals(),
    );

    await FileUtils.writeFile(
      p.join(s, 'error_view.dart'),
      SharedTemplates.errorView(),
    );
    await FileUtils.writeFile(
      p.join(s, 'empty_view.dart'),
      SharedTemplates.emptyView(),
    );

    await FileUtils.writeFile(
      p.join(s, 'buttons', 'app_button.dart'),
      SharedTemplates.appButton(),
    );
    await FileUtils.writeFile(
      p.join(s, 'loadings', 'app_loading_data.dart'),
      SharedTemplates.appLoadingData(),
    );
    await FileUtils.writeFile(
      p.join(s, 'loadings', 'app_loading_action_overlay.dart'),
      SharedTemplates.appLoadingAction(),
    );

    await FileUtils.writeFile(
      p.join(s, 'inputs', 'input_title.dart'),
      SharedTemplates.inputTitle(),
    );
    await FileUtils.writeFile(
      p.join(s, 'inputs', 'app_input.dart'),
      SharedTemplates.appInput(),
    );
    await FileUtils.writeFile(
      p.join(s, 'inputs', 'app_date_input.dart'),
      SharedTemplates.dateInput(),
    );
    await FileUtils.writeFile(
      p.join(s, 'inputs', 'app_time_input.dart'),
      SharedTemplates.timeInput(),
    );
    await FileUtils.writeFile(
      p.join(s, 'inputs', 'app_dropdown_input.dart'),
      SharedTemplates.appDropdown(),
    );
    await FileUtils.writeFile(p.join(s, 'design_system_view.dart'),
        SharedTemplates.designSystemView());

    await FileUtils.writeFile(
        p.join(s, 'media', 'app_avatar.dart'), SharedTemplates.appAvatar());

    await FileUtils.writeFile(
        p.join(s, 'media', 'app_image.dart'), SharedTemplates.appImage());
  }
}
