import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/templates/core/security_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/helpers/helper_templates.dart';
import 'package:moarch/src/templates/misc/checklist_templates.dart';
import 'package:moarch/src/templates/misc/dev_templates.dart';
import 'package:moarch/src/templates/misc/workflow_templates.dart';
import 'package:moarch/src/utils/checklist.dart';
import 'package:path/path.dart' as p;

import '../templates/config/config_templates.dart';
import '../templates/core/core_templates.dart';
import '../templates/ui/shared_templates.dart';
import '../utils/file_utils.dart';

// ── Stack options ─────────────────────────────────────────────────────────────
// Add a new const + ChecklistItem + if block to support a new option.

const _kDio = 'Dio (REST API)';
const _kFirestore = 'Firebase Firestore';
const _kFirebaseAuth = 'Firebase Auth';

// ── Feature options ───────────────────────────────────────────────────────────
// What gets generated into lib/ beyond the bare minimum.

const _kRouter = 'Router (GoRouter)';
const _kCi = 'CI workflow (.github/workflows/ci.yml)';
const _kSecurityWorkflows = 'Secrets Scans and SAST Scan (.github/workflows/)';
const _kMediaService = 'Media Service (Image Picker and File Picker)';
const _kLaunchUrlService = 'Url launcher for links';
const _kDebouncerService = 'Debouncer for actions';
const _kHelpers = 'Helper folder (dialog and bottom modal)';

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

    _logger.info('');
    _logger.info('🧱 moarch — Initializing project...');
    _logger.info('');

    // ── Stack checklist ───────────────────────────────────────────────────────
    // What backend/networking does this project use?

    late Set<String> stack;

    if (skipChecklist) {
      stack = {_kDio, _kRouter, _kCi};
    } else {
      stack = Checklist.prompt(
        title: '  Backend / networking:',
        items: [
          const ChecklistItem(_kDio, defaultOn: true),
          const ChecklistItem(_kFirestore, defaultOn: false),
          const ChecklistItem(_kFirebaseAuth, defaultOn: false),
        ],
      );

      // ── Feature checklist ───────────────────────────────────────────────────
      // What extra files do you want generated?
      final features = Checklist.prompt(
        title: '  What to generate:',
        items: [
          const ChecklistItem(_kRouter, defaultOn: true),
          const ChecklistItem(_kCi, defaultOn: true),
          const ChecklistItem(_kSecurityWorkflows, defaultOn: true),
          const ChecklistItem(_kHelpers, defaultOn: true),
          const ChecklistItem(_kMediaService, defaultOn: false),
          const ChecklistItem(_kLaunchUrlService, defaultOn: false),
          const ChecklistItem(_kDebouncerService, defaultOn: false)
        ],
      );

      stack = {...stack, ...features};
    }

    final progress = _logger.progress('Creating structure');

    try {
      await _buildCore(libPath, stack);
      await _buildConfig(libPath, stack);
      await _buildHelper(libPath);
      await _buildShared(libPath);
      await FileUtils.createDir(p.join(libPath, 'features'));
      final testPath = p.join(p.absolute(targetPath), 'test');
      await FileUtils.createDir(testPath);
      await FileUtils.createDir(p.join(testPath, 'unit'));
      await FileUtils.createDir(p.join(testPath, 'integration'));

      await FileUtils.writeFile(
        p.join(libPath, 'main.dart'),
        CoreTemplates.mainDart(withRouter: stack.contains(_kRouter)),
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

      if (stack.contains(_kCi)) {
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), '.github', 'workflows', 'ci.yml'),
          WorkflowTemplates.ciWorkflow(),
        );
      }

      if (stack.contains(_kSecurityWorkflows)) {
        await FileUtils.writeFile(
          p.join(
              p.absolute(targetPath), '.github', 'workflows', 'sast_scan.yml'),
          WorkflowTemplates.sastWorkflow(),
        );
        await FileUtils.writeFile(
          p.join(p.absolute(targetPath), '.github', 'workflows',
              'secrets_scan.yml'),
          WorkflowTemplates.secretsScanWorkflow(),
        );
      }

      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.gitignore'),
        '.env\n',
      );

      progress.complete('Done');
    } catch (e) {
      progress.fail('Failed: $e');
      return 1;
    }

    _logger.success('');
    _logger.success('✅  Project scaffolded!');
    _logger.info('');
    _logger.info('  moarch create feature <name>   → generate a feature');
    _logger.info('');
    return 0;
  }

  Future<void> _buildCore(String libPath, Set<String> stack) async {
    final c = p.join(libPath, 'core');
    await FileUtils.writeFile(
      p.join(c, 'errors', 'app_exception.dart'),
      CoreTemplates.appException(hasDio: stack.contains(_kDio)),
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

  Future<void> _buildHelper(String libPath) async {
    final s = p.join(libPath, 'helpers');
    await FileUtils.writeFile(
      p.join(s, 'app_dialog.dart'),
      HelperTemplates.appDialog(),
    );
    await FileUtils.writeFile(
      p.join(s, 'app_bottom_modal.dart'),
      HelperTemplates.appBottomModal(),
    );
  }

  Future<void> _buildShared(String libPath) async {
    final s = p.join(libPath, 'shared', 'widgets');
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
      p.join(s, 'error_view.dart'),
      SharedTemplates.errorView(),
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
  }
}
