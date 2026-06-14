import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
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

    if (File(modelFile).existsSync() || File(entityFile).existsSync()) {
      _logger
          .warn('Model "$modelName" already exists in feature "$featureName".');
      return 0;
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
}
