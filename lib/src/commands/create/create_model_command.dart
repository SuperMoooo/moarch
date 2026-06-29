import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/utils/model_field_parser.dart';
import 'package:path/path.dart' as p;

import '../../templates/ui/feature_templates.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';

/// COMMAND FOR MODEL CREATION
class CreateModelCommand extends Command<int> {
  /// COMMAND FOR MODEL CREATION
  CreateModelCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'path',
      abbr: 'p',
      defaultsTo: 'lib',
      help: 'Path to lib/ directory.',
    );
    argParser.addFlag(
      'empty',
      abbr: 'e',
      negatable: false,
      help: 'Inject a .empty() factory into an existing model.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'model';

  @override
  String get description =>
      'Scaffold a model + entity inside an existing feature.';

  @override
  String get invocation => 'moarch create model <feature_name> <model_name>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.length < 2) {
      _logger.err(
        'Provide feature and model names.\n'
        '  Usage: moarch create model <feature_name> <model_name>',
      );
      return 1;
    }

    final featureName = StringUtils.toSnakeCase(rest[0]);
    final modelName = StringUtils.toSnakeCase(rest[1]);
    final modelClass = StringUtils.toPascalCase(rest[1]);

    final libPath = argResults?['path'] as String? ?? 'lib';
    final featurePath = p.join(libPath, 'features', featureName);

    // Guard — feature must exist
    if (!Directory(featurePath).existsSync()) {
      _logger.err(
        'Feature "$featureName" not found at $featurePath.\n'
        '  Create it first with: moarch create feature $featureName',
      );
      return 1;
    }

    // Guard — avoid overwriting
    final modelFile =
        p.join(featurePath, 'data', 'models', '${modelName}_model.dart');
    final entityFile =
        p.join(featurePath, 'domain', 'entities', '${modelName}_entity.dart');

    final addEmpty = argResults?['empty'] as bool? ?? false;

    if (!addEmpty) {
      if (File(modelFile).existsSync() || File(entityFile).existsSync()) {
        _logger.warn(
            'Model "$modelName" already exists in feature "$featureName".');
        return 0;
      }
    }

    if (addEmpty) {
      return _injectEmptyFactory(
        featurePath: featurePath,
        modelName: modelName,
        modelClass: modelClass,
        modelFile: entityFile,
      );
    }

    _logger.info('');
    _logger.info('🧱 Creating model: $modelClass (in feature: $featureName)');
    _logger.info('');

    final progress = _logger.progress('Scaffolding');

    try {
      await FileUtils.writeFile(
        modelFile,
        FeatureTemplates.model(modelName, modelClass),
      );
      await FileUtils.writeFile(
        entityFile,
        FeatureTemplates.entity(modelName, modelClass),
      );
      progress.complete('Model scaffolded');
    } catch (e) {
      progress.fail('Failed: $e');
      return 1;
    }

    _printTree(featureName, modelName, modelClass);
    return 0;
  }

  void _printTree(String featureName, String modelName, String modelClass) {
    _logger.success('');
    void line(String s) => _logger.info('  $s');

    line('features/$featureName/');
    line('├── data/');
    line('│   └── models/${modelName}_model.dart');
    line('└── domain/');
    line('    └── entities/${modelName}_entity.dart');
    line('');
    _logger.info('');
  }

  Future<int> _injectEmptyFactory({
    required String featurePath,
    required String modelName,
    required String modelClass,
    required String modelFile,
  }) async {
    if (!File(modelFile).existsSync()) {
      _logger.err(
        'Entity file not found at $modelFile.\n'
        '  Scaffold it first with: moarch create model <feature> $modelName',
      );
      return 1;
    }

    final source = await File(modelFile).readAsString();

    // Guard — already has .empty()
    if (source.contains('factory $modelClass.empty(')) {
      _logger.warn('$modelClass already has an .empty() factory.');
      return 0;
    }

    final fields = ModelFieldParser.parse(source, modelClass);
    if (fields.isEmpty) {
      _logger.warn(
        'No fields found in $modelClass. '
        'Make sure the class has a const constructor with named parameters.',
      );
    }

    final factory = ModelFieldParser.buildEmptyFactory(modelClass, fields);

    // Inject just before the last closing brace of the class
    final lastBrace = source.lastIndexOf('}');
    if (lastBrace == -1) {
      _logger.err('Could not locate closing brace in $modelFile.');
      return 1;
    }

    final updated =
        source.substring(0, lastBrace) + factory + source.substring(lastBrace);

    _logger.info('');
    _logger.info('🏭 Injecting .empty() into $modelClass');
    _logger.info('');

    final progress = _logger.progress('Patching');
    try {
      await File(modelFile).writeAsString(updated);
      progress.complete('Done');
    } catch (e) {
      progress.fail('Failed: $e');
      return 1;
    }

    _logger.success('');
    _logger.info('  ✓ $modelClass.empty() added to');
    _logger.info('    ${modelFile.replaceAll(RegExp(r'^.*/lib/'), 'lib/')}');
    _logger.info('');
    return 0;
  }
}
