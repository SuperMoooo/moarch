import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/utils/model_field_parser.dart';
import 'package:path/path.dart' as p;

import '../../templates/riverpod/feature_templates.dart';
import '../../utils/file_utils.dart';
import '../../utils/json_model_builder.dart';
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
      help: 'Inject a .empty() factory into an existing entity.',
    );
    argParser.addOption(
      'from-json',
      help: 'Infer the fields from a sample JSON payload file — the entity '
          'and model come out with real fields instead of TODOs.',
      valueHelp: 'file',
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
    final fromJsonPath = argResults?['from-json'] as String?;

    if (addEmpty && fromJsonPath != null) {
      _logger.err('--empty and --from-json are different jobs — '
          '--empty patches an existing entity, --from-json generates a new '
          'one. Pick one.');
      return 1;
    }

    if (!addEmpty) {
      if (File(modelFile).existsSync() || File(entityFile).existsSync()) {
        _logger.warn(
            'Model "$modelName" already exists in feature "$featureName".');
        return 0;
      }
    }

    if (addEmpty) {
      return _injectEmptyFactory(
        modelName: modelName,
        // The target is the entity file, and the class in it is `<Model>Entity`
        // — a factory named after the model alone would not compile.
        entityClass: '${modelClass}Entity',
        entityFile: entityFile,
      );
    }

    // With a JSON sample the fields are inferred instead of left as TODOs.
    List<JsonField>? fields;
    if (fromJsonPath != null) {
      fields = _parseJsonSample(fromJsonPath);
      if (fields == null) return 1;
    }

    _logger.info('');
    _logger.info('🧱 Creating model: $modelClass (in feature: $featureName)');
    _logger.info('');

    final progress = _logger.progress('Scaffolding');
    FileUtils.beginSession();

    try {
      await FileUtils.writeFile(
        modelFile,
        fields == null
            ? FeatureTemplates.model(modelName, modelClass)
            : JsonModelBuilder.modelSource(modelName, modelClass, fields),
      );
      await FileUtils.writeFile(
        entityFile,
        fields == null
            ? FeatureTemplates.entity(modelName, modelClass)
            : JsonModelBuilder.entitySource(modelName, modelClass, fields),
      );
      progress.complete('Model scaffolded');
    } catch (e) {
      progress.fail('Failed: $e');
      FileUtils.rollback();
      return 1;
    }

    _printTree(featureName, modelName, modelClass);
    if (fields != null) {
      _logger.info('  Fields inferred from $fromJsonPath:');
      for (final field in fields) {
        _logger.info('    ${field.type.padRight(24)} ${field.name}'
            '${field.name == field.jsonKey ? '' : "  (json: '${field.jsonKey}')"}');
      }
      // A null in the sample types as dynamic — the sample says nothing else.
      if (fields.any((f) => f.type == 'dynamic')) {
        _logger.info('');
        _logger.warn('  Fields typed `dynamic` were null in the sample — '
            'tighten them by hand.');
      }
      _logger.info('');
    }
    return 0;
  }

  /// Reads and decodes the `--from-json` sample, reporting exactly what is
  /// wrong when it can't be used. Returns null on failure.
  List<JsonField>? _parseJsonSample(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      _logger.err('No file at $path.');
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      _logger.err('$path is not valid JSON: ${e.message}');
      return null;
    }

    final fields = JsonModelBuilder.fieldsFrom(decoded);
    if (fields == null) {
      _logger.err('$path holds no JSON object to read fields from — '
          'pass a sample payload like {"id": 1, "name": "..."} '
          '(a list of them works too).');
      return null;
    }
    return fields;
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
    required String modelName,
    required String entityClass,
    required String entityFile,
  }) async {
    if (!File(entityFile).existsSync()) {
      _logger.err(
        'Entity file not found at $entityFile.\n'
        '  Scaffold it first with: moarch create model <feature> $modelName',
      );
      return 1;
    }

    final source = await File(entityFile).readAsString();

    // Guard — already has .empty()
    if (source.contains('factory $entityClass.empty(')) {
      _logger.warn('$entityClass already has an .empty() factory.');
      return 0;
    }

    final fields = ModelFieldParser.parse(source, entityClass);
    if (fields.isEmpty) {
      _logger.warn(
        'No fields found in $entityClass. '
        'Make sure the class has a const constructor with named parameters.',
      );
    }

    final factory = ModelFieldParser.buildEmptyFactory(entityClass, fields);

    // Inject at the end of the entity's own body — the file's last brace may
    // belong to a second class declared below it.
    final closing = ModelFieldParser.classBody(source, entityClass)?.end ??
        source.lastIndexOf('}');
    if (closing == -1) {
      _logger.err('Could not locate closing brace in $entityFile.');
      return 1;
    }

    final updated =
        source.substring(0, closing) + factory + source.substring(closing);

    _logger.info('');
    _logger.info('🏭 Injecting .empty() into $entityClass');
    _logger.info('');

    final progress = _logger.progress('Patching');
    try {
      await File(entityFile).writeAsString(updated);
      progress.complete('Done');
    } catch (e) {
      progress.fail('Failed: $e');
      return 1;
    }

    _logger.success('');
    _logger.info('  ✓ $entityClass.empty() added to');
    _logger.info(
        '    ${entityFile.replaceAll(RegExp(r'^.*[/\\]lib[/\\]'), 'lib/')}');
    _logger.info('');
    return 0;
  }
}
