import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../templates/config_templates.dart';
import '../templates/core_templates.dart';
import '../templates/shared_templates.dart';
import '../utils/file_utils.dart';

class InitCommand extends Command<int> {
  InitCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'path',
      abbr: 'p',
      help: 'Target project path (defaults to current directory).',
      defaultsTo: '.',
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

    _logger.info('');
    _logger.info('🧱 moarch — Initializing project...');
    _logger.info('');

    final progress = _logger.progress('Creating structure');

    try {
      await _buildCore(libPath);
      await _buildConfig(libPath);
      await _buildShared(libPath);
      await FileUtils.createDir(p.join(libPath, 'features'));
      await FileUtils.writeFile(
        p.join(libPath, 'main.dart'),
        CoreTemplates.mainDart(),
      );
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.fvmrc'),
        '{\n  "flutter": "stable"\n}\n',
      );
      await FileUtils.writeFile(
        p.join(p.absolute(targetPath), '.env'),
        'BASE_URL=\n',
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

  Future<void> _buildCore(String libPath) async {
    final c = p.join(libPath, 'core');
    await FileUtils.writeFile(
      p.join(c, 'errors', 'app_exception.dart'),
      CoreTemplates.appException(),
    );
    await FileUtils.writeFile(
      p.join(c, 'utils', 'extensions.dart'),
      CoreTemplates.extensions(),
    );
    await FileUtils.writeFile(
      p.join(c, 'utils', 'logger.dart'),
      CoreTemplates.logger(),
    );
    await FileUtils.writeFile(
      p.join(c, 'constants', 'app_constants.dart'),
      CoreTemplates.appConstants(),
    );
    await FileUtils.writeFile(
      p.join(c, 'constants', 'api_constants.dart'),
      CoreTemplates.apiConstants(),
    );
    await FileUtils.writeFile(
      p.join(c, 'network', 'dio_client.dart'),
      CoreTemplates.dioClient(),
    );
    await FileUtils.writeFile(
      p.join(c, 'security', 'secure_storage.dart'),
      CoreTemplates.secureStorage(),
    );
    await FileUtils.writeFile(
      p.join(c, 'usecases', 'usecase.dart'),
      CoreTemplates.usecaseBase(),
    );
  }

  Future<void> _buildConfig(String libPath) async {
    final c = p.join(libPath, 'config');
    await FileUtils.writeFile(
      p.join(c, 'theme', 'app_theme.dart'),
      ConfigTemplates.appTheme(),
    );
  }

  Future<void> _buildShared(String libPath) async {
    final s = p.join(libPath, 'shared', 'widgets');
    await FileUtils.writeFile(
      p.join(s, 'app_button.dart'),
      SharedTemplates.appButton(),
    );
    await FileUtils.writeFile(
      p.join(s, 'app_loading.dart'),
      SharedTemplates.appLoading(),
    );
    await FileUtils.writeFile(
      p.join(s, 'error_view.dart'),
      SharedTemplates.errorView(),
    );
  }
}
