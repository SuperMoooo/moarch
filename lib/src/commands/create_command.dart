import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../templates/feature_templates.dart';
import '../templates/test_templates.dart';
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
      )
      ..addFlag(
        'unit',
        defaultsTo: true,
        negatable: true,
        help: 'Generate unit tests. Use --no-unit to skip.',
      )
      ..addFlag(
        'integration',
        defaultsTo: true,
        negatable: true,
        help: 'Generate integration tests. Use --no-integration to skip.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'feature';

  @override
  String get description =>
      'Scaffold a new feature with selectable Clean Architecture layers.';

  @override
  String get invocation => 'mo create feature <n>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      _logger.err('Provide a feature name.\n  Usage: mo create feature <n>');
      return 1;
    }

    final featureName = StringUtils.toSnakeCase(rest.first);
    final className = StringUtils.toPascalCase(rest.first);
    final libPath = argResults?['path'] as String? ?? 'lib';
    final featurePath = p.join(libPath, 'features', featureName);
    final featureExists = Directory(featurePath).existsSync();

    // ── Existing feature — offer tests only ───────────────────────────────────
    if (featureExists) {
      _logger.warn('Feature "$featureName" already exists at $featurePath');
      _logger.info('');

      final generateTests = _askYesNo(
        '  Generate tests for existing feature "$className"? (Y/n): ',
      );

      if (!generateTests) {
        _logger.info('  Nothing generated.');
        return 0;
      }

      // For existing features we need to know which layers exist
      // to generate the right tests — use the checklist for test selection
      final hasRemote = File(p.join(
        featurePath,
        'data',
        'datasources',
        '${featureName}_remote_datasource.dart',
      )).existsSync();
      final hasRepo = File(p.join(
        featurePath,
        'data',
        'repositories',
        '${featureName}_repository_impl.dart',
      )).existsSync();
      final hasNotifier = File(p.join(
        featurePath,
        'presentation',
        'notifiers',
        '${featureName}_notifier.dart',
      )).existsSync();
      final hasUseCase = File(p.join(
        featurePath,
        'domain',
        'usecases',
        'get_$featureName.dart',
      )).existsSync();

      final selected = <String>{
        if (hasRemote) _kRemoteDatasource,
        if (hasRepo) _kRepository,
        if (hasNotifier) _kStateNotifier,
        if (hasUseCase) _kUseCases,
      };

      final includeUnit = _askYesNo('  Generate unit tests? (Y/n): ');
      final includeIntegration = hasRemote
          ? _askYesNo('  Generate integration tests? (Y/n): ')
          : false;

      if (includeUnit) {
        final unitProgress = _logger.progress('Generating unit tests');
        try {
          await _writeUnitTests(
            libPath: libPath,
            featureName: featureName,
            className: className,
            selected: selected,
          );
          unitProgress.complete('Unit tests generated');
        } catch (e) {
          unitProgress.fail('Unit tests failed: $e');
        }
      }

      if (includeIntegration) {
        final integrationProgress =
            _logger.progress('Generating integration tests');
        try {
          await _writeIntegrationTests(
            libPath: libPath,
            featureName: featureName,
            className: className,
          );
          integrationProgress.complete('Integration tests generated');
        } catch (e) {
          integrationProgress.fail('Integration tests failed: $e');
        }
      }

      _printTree(
        featureName,
        className,
        selected,
        includeUnit: includeUnit,
        includeIntegration: includeIntegration,
        testsOnly: true,
      );
      return 0;
    }

    // ── New feature ───────────────────────────────────────────────────────────

    // Layer checklist
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
        title: '  Select layers for "$className":',
        items: [
          const ChecklistItem(_kRemoteDatasource, defaultOn: true),
          const ChecklistItem(_kLocalDatasource, defaultOn: false),
          const ChecklistItem(_kRepository, defaultOn: true),
          const ChecklistItem(_kUseCases, defaultOn: false),
          const ChecklistItem(_kStateNotifier, defaultOn: true),
          const ChecklistItem(_kView, defaultOn: true),
        ],
      );
    }

    // Test prompts
    final unitExplicit = argResults?.wasParsed('unit') ?? false;
    final integrationExplicit = argResults?.wasParsed('integration') ?? false;

    final includeUnit = unitExplicit
        ? (argResults?['unit'] as bool? ?? true)
        : _askYesNo('  Generate unit tests? (Y/n): ');

    final includeIntegration = integrationExplicit
        ? (argResults?['integration'] as bool? ?? true)
        : selected.contains(_kRemoteDatasource)
            ? _askYesNo('  Generate integration tests? (Y/n): ')
            : false;

    _logger.info('');
    _logger.info('🧱 Creating feature: $className');
    _logger.info('');

    final progress = _logger.progress('Scaffolding');

    try {
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
      await _writeModel(featurePath, featureName, className);
      await _writeEntity(featurePath, featureName, className);
      if (selected.contains(_kUseCases)) {
        await _writeUsecase(featurePath, featureName, className);
      }
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

    // Unit tests
    if (includeUnit) {
      final unitProgress = _logger.progress('Generating unit tests');
      try {
        await _writeUnitTests(
          libPath: libPath,
          featureName: featureName,
          className: className,
          selected: selected,
        );
        unitProgress.complete('Unit tests generated');
      } catch (e) {
        unitProgress.fail('Unit tests failed: $e');
      }
    } else {
      _logger.detail('  Unit tests skipped.');
    }

    // Integration tests
    if (includeIntegration && selected.contains(_kRemoteDatasource)) {
      final integrationProgress =
          _logger.progress('Generating integration tests');
      try {
        await _writeIntegrationTests(
          libPath: libPath,
          featureName: featureName,
          className: className,
        );
        integrationProgress.complete('Integration tests generated');
      } catch (e) {
        integrationProgress.fail('Integration tests failed: $e');
      }
    } else if (!selected.contains(_kRemoteDatasource)) {
      _logger.detail(
          '  Integration tests skipped — no Remote Datasource selected.');
    } else {
      _logger.detail('  Integration tests skipped.');
    }

    _printTree(
      featureName,
      className,
      selected,
      includeUnit: includeUnit,
      includeIntegration:
          includeIntegration && selected.contains(_kRemoteDatasource),
    );
    return 0;
  }

  // ── Interactive prompt ────────────────────────────────────────────────────────

  bool _askYesNo(String question) {
    stdout.write(question);
    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    return input.isEmpty || input == 'y' || input == 'yes';
  }

  // ── Writers ─────────────────────────────────────────────────────────────────

  Future<void> _writeRemoteDatasource(String fp, String name, String cls,
      {required bool hasRepo}) async {
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

  Future<void> _writeRepository(String fp, String name, String cls,
      {required bool hasRemote, required bool hasLocal}) async {
    await FileUtils.writeFile(
      p.join(fp, 'domain', 'repositories', '${name}_repository.dart'),
      FeatureTemplates.repositoryInterface(name, cls),
    );
    await FileUtils.writeFile(
      p.join(fp, 'data', 'repositories', '${name}_repository_impl.dart'),
      FeatureTemplates.repositoryImpl(name, cls,
          hasRemote: hasRemote, hasLocal: hasLocal),
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

  Future<void> _writeNotifier(String fp, String name, String cls,
      {required bool hasUseCase}) async {
    await FileUtils.writeFile(
      p.join(fp, 'presentation', 'notifiers', '${name}_notifier.dart'),
      FeatureTemplates.notifier(name, cls, hasUseCase: hasUseCase),
    );
  }

  Future<void> _writeView(String fp, String name, String cls,
      {required bool hasNotifier}) async {
    await FileUtils.writeFile(
      p.join(fp, 'presentation', 'views', '${name}_view.dart'),
      FeatureTemplates.view(name, cls, hasNotifier: hasNotifier),
    );
  }

  Future<void> _writeUnitTests({
    required String libPath,
    required String featureName,
    required String className,
    required Set<String> selected,
  }) async {
    final projectRoot = p.dirname(p.absolute(libPath));
    final unitPath =
        p.join(projectRoot, 'test', 'unit', 'features', featureName);

    if (selected.contains(_kStateNotifier) && selected.contains(_kRepository)) {
      await FileUtils.writeFile(
        p.join(unitPath, '${featureName}_notifier_test.dart'),
        TestTemplates.notifierTest(featureName, className),
      );
    }
    if (selected.contains(_kRepository)) {
      await FileUtils.writeFile(
        p.join(unitPath, '${featureName}_repository_test.dart'),
        TestTemplates.repositoryTest(featureName, className),
      );
    }
    if (selected.contains(_kUseCases)) {
      await FileUtils.writeFile(
        p.join(unitPath, '${featureName}_usecase_test.dart'),
        TestTemplates.usecaseTest(featureName, className),
      );
    }
  }

  Future<void> _writeIntegrationTests({
    required String libPath,
    required String featureName,
    required String className,
  }) async {
    final projectRoot = p.dirname(p.absolute(libPath));
    final integrationPath =
        p.join(projectRoot, 'test', 'integration', 'features', featureName);

    await FileUtils.writeFile(
      p.join(projectRoot, 'test', 'test_helper.dart'),
      TestTemplates.testHelper(),
    );
    await FileUtils.writeFile(
      p.join(integrationPath, '${featureName}_integration_test.dart'),
      TestTemplates.integrationTest(featureName, className),
    );
  }

  // ── Tree summary ─────────────────────────────────────────────────────────────

  void _printTree(
    String name,
    String cls,
    Set<String> selected, {
    bool includeUnit = true,
    bool includeIntegration = true,
    bool testsOnly = false,
  }) {
    _logger.success('');
    _logger.success(testsOnly
        ? '✅  Tests generated for $cls'
        : '✅  $cls created at lib/features/$name/');
    _logger.info('');

    void line(String s) => _logger.info('  $s');

    if (!testsOnly) {
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
      if (selected.contains(_kView)) line('└── views/${name}_view.dart');
      line('');
    }

    if (includeUnit) {
      final hasUnit = (selected.contains(_kStateNotifier) &&
              selected.contains(_kRepository)) ||
          selected.contains(_kRepository) ||
          selected.contains(_kUseCases);

      if (hasUnit) {
        line('test/unit/features/$name/');
        if (selected.contains(_kStateNotifier) &&
            selected.contains(_kRepository)) {
          line('├── ${name}_notifier_test.dart');
        }
        if (selected.contains(_kRepository)) {
          line('├── ${name}_repository_test.dart');
        }
        if (selected.contains(_kUseCases)) {
          line('└── ${name}_usecase_test.dart');
        }
        line('');
      }
    }

    if (includeIntegration) {
      line('test/integration/features/$name/');
      line('└── ${name}_integration_test.dart   ← needs live API');
      line('');
    }

    _logger.info('');
    if (includeUnit) _logger.info('  Unit:        flutter test test/unit/');
    if (includeIntegration)
      _logger.info('  Integration: flutter test test/integration/');
    _logger
        .info('  Replace "your_app" in test imports with your package name.');
    _logger.info('');
  }
}
