import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/core/security_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/misc/checklist_templates.dart';
import 'package:moarch/src/templates/misc/dev_templates.dart';
import 'package:moarch/src/templates/misc/workflow_templates.dart';
import 'package:moarch/src/templates/ui/dialogs_templates.dart';
import 'package:moarch/src/templates/ui/modals_templates.dart';
import 'package:moarch/src/utils/checklist.dart';
import 'package:path/path.dart' as p;

import '../templates/config/config_templates.dart';
import '../templates/core/core_templates.dart';
import '../templates/ui/shared_templates.dart';
import '../utils/file_utils.dart';
import '../utils/pubspec_utils.dart';

// ── Stack options ─────────────────────────────────────────────────────────────
// Add a new const + ChecklistItem + if block to support a new option.

const _kDio = 'Dio (REST API)';
const _kFirestore = 'Firebase Firestore';
const _kFirebaseAuth = 'Firebase Auth';

// ── Feature options ───────────────────────────────────────────────────────────
// What gets generated into lib/ beyond the bare minimum.

const _kRouter = 'Router (GoRouter)';
const _kWorkflows = 'Workflows (security, tests, build)';
const _kMediaService = 'Media Service (Image Picker and File Picker)';
const _kLaunchUrlService = 'Url launcher for links';
const _kDebouncerService = 'Debouncer for actions';
const _kNotificationsService = 'Notifications service';
const _kLocalizations = 'Localization (l10n)';

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
          ],
        );

        // ── Feature checklist ─────────────────────────────────────────────────
        // What extra files do you want generated?
        final features = Checklist.prompt(
          title: '  What to generate:',
          items: [
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
              _kLocalizations,
              defaultOn: false,
              description:
                  'l10n scaffolding with English + Portuguese .arb files.',
            ),
          ],
        );

        stack = {...stack, ...features};
      } on ChecklistCancelled {
        _logger.info('Cancelled — nothing was generated.');
        return 0;
      }
    }

    final progress = _logger.progress(
      dryRun ? 'Previewing structure' : 'Creating structure',
    );
    FileUtils.beginSession(dryRun: dryRun);

    final pubspecFile = File(p.join(p.absolute(targetPath), 'pubspec.yaml'));
    final pubspecExisted = pubspecFile.existsSync();
    final pubspecBackup =
        pubspecExisted ? await pubspecFile.readAsString() : null;

    // Caret-pinned to the versions the templates were written against, so a
    // breaking major release of a package can't silently break a fresh
    // scaffold. Bump these alongside template changes.
    final defaultDependencies = <String>[
      'flutter:\n    sdk: flutter',
      'flutter_riverpod: ^3.3.2',
      'flutter_native_splash: ^2.4.8',
      'envied: ^1.3.8',
      'skeletonizer: ^2.1.3',
      'cached_network_image: ^3.4.1',
      'intl: ^0.20.3',
      'logger: ^2.7.0',
      'connectivity_plus: ^7.2.0',
      if (stack.contains(_kRouter)) 'go_router: ^17.3.0',
      if (stack.contains(_kDio)) 'dio: ^5.10.0',
      if (stack.contains(_kDio)) 'dio_smart_retry: ^7.0.1',
      'flutter_secure_storage: ^10.3.1',
      if (stack.contains(_kFirebaseAuth) || stack.contains(_kFirestore))
        'firebase_core: ^4.11.0',
      if (stack.contains(_kFirebaseAuth)) 'firebase_auth: ^6.5.4',
      if (stack.contains(_kFirestore)) 'cloud_firestore: ^6.6.0',
      if (stack.contains(_kMediaService)) 'file_picker: ^11.0.2',
      if (stack.contains(_kMediaService)) 'image_picker: ^1.2.3',
      'permission_handler: ^12.0.3',
      if (stack.contains(_kLaunchUrlService)) 'url_launcher: ^6.3.2',
      if (stack.contains(_kNotificationsService))
        'flutter_local_notifications: ^22.0.1',
      if (stack.contains(_kNotificationsService)) 'timezone: ^0.11.1',
      if (stack.contains(_kLocalizations))
        'flutter_localizations:\n    sdk: flutter',
    ];

    final devDependencies = <String>[
      'build_runner: ^2.15.1',
      'envied_generator: ^1.3.8',
      'mogen_unit_tests: ^1.1.4',
      'mogen_integration_tests: ^1.0.12',
      'flutter_lints: ^6.0.0',
    ];

    try {
      await _buildCore(libPath, stack);
      await _buildConfig(libPath, stack);
      await _buildShared(libPath);
      await FileUtils.createDir(p.join(libPath, 'features'));
      final testPath = p.join(p.absolute(targetPath), 'test');
      await FileUtils.createDir(testPath);
      await FileUtils.createDir(p.join(testPath, 'unit'));
      await FileUtils.createDir(p.join(testPath, 'integration'));

      await FileUtils.writeFile(
        p.join(libPath, 'main.dart'),
        CoreTemplates.mainDart(
          withRouter: stack.contains(_kRouter),
          withLocalization: stack.contains(_kLocalizations),
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
        p.join(p.absolute(targetPath), 'CHECKLIST_BEFORE_DEPLOYMENT.md'),
        ChecklistTemplates.prodChecklist(),
      );

      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), 'SECURITY_BEFORE_DEPLOYMENT.md'),
        ChecklistTemplates.securityChecklist(),
      );

      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), 'GENERATE_JKS_FILE.md'),
        ChecklistTemplates.generateJKS(),
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
          WorkflowTemplates.buildIOS(),
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

      // `flutter create` projects already have a .gitignore, and writeFile
      // never overwrites existing files — so append `.env` if it's missing.
      final gitignoreFile = File(p.join(p.absolute(targetPath), '.gitignore'));
      if (!gitignoreFile.existsSync() || dryRun) {
        await FileUtils.writeFile(gitignoreFile.path, '.env\n');
      } else {
        final gitignore = await gitignoreFile.readAsString();
        final hasEnvRule =
            gitignore.split('\n').any((line) => line.trim() == '.env');
        if (!hasEnvRule) {
          await gitignoreFile.writeAsString(
            '${gitignore.trimRight()}\n\n# Environment secrets (moarch)\n.env\n',
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
    _logger.info('  moarch create feature <name>   → generate a feature');
    _logger.info('');
    return 0;
  }

  Future<void> _buildCore(String libPath, Set<String> stack) async {
    final c = p.join(libPath, 'core');

    await FileUtils.writeFile(
      p.join(c, 'errors', 'app_exception.dart'),
      ErrorTemplates.appException(
        hasDio: stack.contains(_kDio),
        hasFirebase:
            stack.contains(_kFirestore) || stack.contains(_kFirebaseAuth),
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
