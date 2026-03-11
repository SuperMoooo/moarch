import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../templates/feature_templates.dart';
import '../utils/checklist.dart';
import '../utils/file_utils.dart';
import '../utils/string_utils.dart';

// Layer labels used in the checklist
const _kRemoteDatasource = 'Remote Datasource';
const _kLocalDatasource = 'Local/Cache Datasource';
const _kRepository = 'Repository (interface + impl)';
const _kUseCases = 'Use Cases';
const _kStateNotifier = 'State + Notifier';
const _kView = 'View';

class CreateCommand extends Command<int> {
  CreateCommand({required Logger logger}) : _logger = logger {
    addSubcommand(_CreateFeatureCommand(logger: logger));
  }

  final Logger _logger;

  @override
  String get name => 'create';

  @override
  String get description => 'Create a new feature or component.';

  @override
  Future<int> run() async {
    _logger.info(usage);
    return 0;
  }
}

class _CreateFeatureCommand extends Command<int> {
  _CreateFeatureCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: 'lib',
        help: 'Path to lib/ directory.',
      )
      ..addFlag(
        'all',
        abbr: 'a',
        negatable: false,
        help: 'Skip checklist and generate all layers.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'feature';

  @override
  String get description =>
      'Scaffold a new feature with selectable Clean Architecture layers.';

  @override
  String get invocation => 'moarch create feature <n>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      _logger.err(
        'Provide a feature name.\n  Usage: moarch create feature <n>',
      );
      return 1;
    }

    final featureName = StringUtils.toSnakeCase(rest.first);
    final className = StringUtils.toPascalCase(rest.first);
    final libPath = argResults?['path'] as String? ?? 'lib';
    final featurePath = p.join(libPath, 'features', featureName);

    if (Directory(featurePath).existsSync()) {
      _logger.warn('Feature "$featureName" already exists at $featurePath');
      return 1;
    }

    // ── Checklist ─────────────────────────────────────────────────────────────
    final skipChecklist = argResults?['all'] as bool? ?? false;

    late Set<String> selected;

    if (skipChecklist) {
      selected = {
        _kRemoteDatasource,
        _kLocalDatasource,
        _kRepository,
        _kUseCases,
        _kStateNotifier,
        _kView,
      };
    } else {
      selected = Checklist.prompt(
        title:
            '  Select layers for "$className" (space = toggle, enter = confirm):',
        items: [
          const ChecklistItem(_kRemoteDatasource, defaultOn: true),
          const ChecklistItem(
            _kLocalDatasource,
            defaultOn: false,
          ), // off by default
          const ChecklistItem(_kRepository, defaultOn: true),
          const ChecklistItem(_kUseCases, defaultOn: false), // off by default
          const ChecklistItem(_kStateNotifier, defaultOn: true),
          const ChecklistItem(_kView, defaultOn: true),
        ],
      );
    }

    _logger.info('');
    _logger.info('🧱 Creating feature: $className');
    _logger.info('');

    final progress = _logger.progress('Scaffolding');

    try {
      // Data layer
      if (selected.contains(_kRemoteDatasource)) {
        await _writeRemoteDatasource(
          featurePath,
          featureName,
          className,
          hasRepo: selected.contains(_kRepository),
        );
      }
      if (selected.contains(_kLocalDatasource)) {
        await _writeLocalDatasource(featurePath, featureName, className);
      }
      if (selected.contains(_kRepository)) {
        await _writeRepository(
          featurePath,
          featureName,
          className,
          hasRemote: selected.contains(_kRemoteDatasource),
          hasLocal: selected.contains(_kLocalDatasource),
        );
      }
      await _writeModel(
        featurePath,
        featureName,
        className,
      );

      // Domain layer
      await _writeEntity(featurePath, featureName, className);
      if (selected.contains(_kUseCases)) {
        await _writeUsecase(featurePath, featureName, className);
      }

      // Presentation layer
      if (selected.contains(_kStateNotifier)) {
        await _writeState(featurePath, featureName, className);
        await _writeNotifier(
          featurePath,
          featureName,
          className,
          hasUseCase: selected.contains(_kUseCases),
        );
      }
      if (selected.contains(_kView)) {
        await _writeView(
          featurePath,
          featureName,
          className,
          hasNotifier: selected.contains(_kStateNotifier),
        );
      }

      progress.complete('Feature scaffolded');
    } catch (e) {
      progress.fail('Failed: $e');
      return 1;
    }

    _printTree(featureName, className, selected);
    return 0;
  }

  // ── Writers ─────────────────────────────────────────────────────────────────

  Future<void> _writeRemoteDatasource(
    String fp,
    String name,
    String cls, {
    required bool hasRepo,
  }) async {
    await FileUtils.writeFile(
      p.join(fp, 'data', 'datasources', '${name}_remote_datasource.dart'),
      FeatureTemplates.remoteDatasource(name, cls),
    );
  }

  Future<void> _writeLocalDatasource(String fp, String name, String cls) async {
    await FileUtils.writeFile(
      p.join(fp, 'data', 'datasources', '${name}_local_datasource.dart'),
      FeatureTemplates.localDatasource(name, cls),
    );
  }

  Future<void> _writeRepository(
    String fp,
    String name,
    String cls, {
    required bool hasRemote,
    required bool hasLocal,
  }) async {
    // Abstract interface in domain
    await FileUtils.writeFile(
      p.join(fp, 'domain', 'repositories', '${name}_repository.dart'),
      FeatureTemplates.repositoryInterface(name, cls),
    );
    // Impl in data
    await FileUtils.writeFile(
      p.join(fp, 'data', 'repositories', '${name}_repository_impl.dart'),
      FeatureTemplates.repositoryImpl(
        name,
        cls,
        hasRemote: hasRemote,
        hasLocal: hasLocal,
      ),
    );
  }

  Future<void> _writeModel(String fp, String name, String cls) async {
    await FileUtils.writeFile(
      p.join(fp, 'data', 'models', '${name}_model.dart'),
      FeatureTemplates.model(name, cls),
    );
  }

  Future<void> _writeEntity(String fp, String name, String cls) async {
    await FileUtils.writeFile(
      p.join(fp, 'domain', 'entities', '${name}_entity.dart'),
      FeatureTemplates.entity(name, cls),
    );
  }

  Future<void> _writeUsecase(String fp, String name, String cls) async {
    await FileUtils.writeFile(
      p.join(fp, 'domain', 'usecases', 'get_$name.dart'),
      FeatureTemplates.usecase(name, cls),
    );
  }

  Future<void> _writeState(String fp, String name, String cls) async {
    await FileUtils.writeFile(
      p.join(fp, 'presentation', 'states', '${name}_state.dart'),
      FeatureTemplates.state(name, cls),
    );
  }

  Future<void> _writeNotifier(
    String fp,
    String name,
    String cls, {
    required bool hasUseCase,
  }) async {
    await FileUtils.writeFile(
      p.join(fp, 'presentation', 'notifiers', '${name}_notifier.dart'),
      FeatureTemplates.notifier(name, cls, hasUseCase: hasUseCase),
    );
  }

  Future<void> _writeView(
    String fp,
    String name,
    String cls, {
    required bool hasNotifier,
  }) async {
    await FileUtils.writeFile(
      p.join(fp, 'presentation', 'views', '${name}_view.dart'),
      FeatureTemplates.view(name, cls, hasNotifier: hasNotifier),
    );
  }

  // ── Tree summary ─────────────────────────────────────────────────────────────

  void _printTree(String name, String cls, Set<String> selected) {
    _logger.success('');
    _logger.success('✅  $cls created at lib/features/$name/');
    _logger.info('');

    void line(String s) => _logger.info('  $s');

    line('domain/');
    line('├── entities/${name}_entity.dart');
    if (selected.contains(_kRepository))
      line('├── repositories/${name}_repository.dart');
    if (selected.contains(_kUseCases)) line('└── usecases/get_$name.dart');

    line('data/');
    if (selected.contains(_kRemoteDatasource))
      line('├── datasources/${name}_remote_datasource.dart');
    if (selected.contains(_kLocalDatasource))
      line('├── datasources/${name}_local_datasource.dart');
    line('├── models/${name}_model.dart');
    if (selected.contains(_kRepository))
      line('└── repositories/${name}_repository_impl.dart');

    line('presentation/');
    if (selected.contains(_kStateNotifier)) {
      line('├── states/${name}_state.dart');
      line('├── notifiers/${name}_notifier.dart');
    }
    if (selected.contains(_kView)) {
      line('├── views/${name}_view.dart');
    }
    _logger.info('');
    _logger.info(
      '  Run: dart run build_runner build --delete-conflicting-outputs',
    );
    _logger.info('');
  }
}
