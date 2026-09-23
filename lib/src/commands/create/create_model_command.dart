import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/utils/model_field_parser.dart';
import 'package:path/path.dart' as p;

import '../../templates/riverpod/feature_templates.dart';
import '../../utils/file_utils.dart';
import '../../utils/json_model_builder.dart';
import '../../utils/project_paths.dart';
import '../../utils/scaffold_catalog.dart';
import '../../utils/string_utils.dart';

/// COMMAND FOR MODEL CREATION
class CreateModelCommand extends Command<int> {
  /// COMMAND FOR MODEL CREATION
  CreateModelCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'path',
      abbr: 'p',
      defaultsTo: 'lib',
      help: 'Path to the lib/ directory, or the project root holding it.',
    );
    argParser.addFlag(
      'empty',
      abbr: 'e',
      negatable: false,
      help: 'Inject a .empty() factory into an existing model.',
    );
    argParser.addOption(
      'from-json',
      help:
          'Infer the fields from a sample JSON payload file — the model '
          'comes out with real fields instead of TODOs.',
      valueHelp: 'file',
    );
    argParser.addFlag(
      'doc',
      negatable: false,
      help:
          'With --from-json on a Firestore project: this type is a document '
          'root, so it gets fromDoc and keeps its String id out of the body. '
          'Leave it off for a value object nested inside a document. The '
          'plain scaffold assumes it — a model whose only field is an id is '
          'a root by construction.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'model';

  @override
  String get description => 'Scaffold a model inside an existing feature.';

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

    final libPath = resolveLibPath(argResults?['path'] as String? ?? 'lib');
    final featurePath = p.join(libPath, 'features', featureName);

    // Guard — feature must exist
    if (!Directory(featurePath).existsSync()) {
      _logger.err(
        'Feature "$featureName" not found at $featurePath.\n'
        '  Create it first with: moarch create feature $featureName',
      );
      return 1;
    }

    final modelFile = p.join(
      featurePath,
      'domain',
      'models',
      '${modelName}_model.dart',
    );

    final addEmpty = argResults?['empty'] as bool? ?? false;
    final fromJsonPath = argResults?['from-json'] as String?;

    if (addEmpty && fromJsonPath != null) {
      _logger.err(
        '--empty and --from-json are different jobs — '
        '--empty patches an existing model, --from-json generates a new '
        'one. Pick one.',
      );
      return 1;
    }

    if (addEmpty) {
      return _injectEmptyFactory(
        modelName: modelName,
        modelClass: '${modelClass}Model',
        modelFile: modelFile,
      );
    }

    // Guard — avoid overwriting
    if (File(modelFile).existsSync()) {
      _logger.warn(
        'Model "$modelName" already exists in feature "$featureName".',
      );
      return 0;
    }

    // Firestore is read off the project rather than asked for: a document has
    // a different shape from a REST payload, and the project already says
    // which one it is.
    final useFirestore = ScaffoldContext.detect(
      p.dirname(libPath),
    ).hasFirestore;
    final isDocumentRoot = argResults?['doc'] as bool? ?? false;

    // With a JSON sample the fields are inferred instead of left as TODOs.
    List<JsonField>? fields;
    var addedDocumentId = false;
    if (fromJsonPath != null) {
      fields = _parseJsonSample(fromJsonPath);
      if (fields == null) return 1;

      // A document's id is its name, not one of its fields, so an exported
      // payload usually does not carry it — and where it does, it cannot be
      // trusted to be the String `doc.id` always is.
      if (isDocumentRoot) {
        final withId = JsonModelBuilder.withDocumentId(fields);
        addedDocumentId = !identical(withId, fields);
        fields = withId;
      }
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
            ? FeatureTemplates.model(
                modelName,
                modelClass,
                useFirestore: useFirestore,
              )
            : JsonModelBuilder.modelSource(
                modelName,
                modelClass,
                fields,
                useFirestore: useFirestore,
                isDocumentRoot: isDocumentRoot,
              ),
      );
      progress.complete('Model scaffolded');
    } catch (e) {
      progress.fail('Failed: $e');
      FileUtils.rollback();
      return 1;
    }

    _printTree(featureName, modelName);
    if (fields != null) {
      _logger.info('  Fields inferred from $fromJsonPath:');
      for (final field in fields) {
        _logger.info(
          '    ${field.type.padRight(24)} ${field.name}'
          '${field.name == field.jsonKey ? '' : "  (json: '${field.jsonKey}')"}',
        );
      }
      // A null in the sample types as dynamic — the sample says nothing else.
      if (fields.any((f) => f.type == 'dynamic')) {
        _logger.info('');
        _logger.warn(
          '  Fields typed `dynamic` were null in the sample — '
          'tighten them by hand.',
        );
      }
      if (addedDocumentId) {
        _logger.info('');
        _logger.info(
          '  `String id` is the document name rather than a field '
          'of its data, so it is read back off the snapshot by fromDoc and '
          'left out of toJson.',
        );
      }
      _logger.info('');
      // Said rather than guessed: only --doc makes a document root, so a
      // sample from a Firestore collection would otherwise come out shaped
      // like a REST payload.
      if (useFirestore && !isDocumentRoot) {
        _logger.info(
          '  Written as a nested value. If this is a document of '
          'its own, delete the file and rerun with --doc.',
        );
        _logger.info('');
      }
    }
    _logger.info(
      '  Then: fvm dart run build_runner build '
      '--delete-conflicting-outputs',
    );
    _logger.info('');
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
      _logger.err(
        '$path holds no JSON object to read fields from — '
        'pass a sample payload like {"id": 1, "name": "..."} '
        '(a list of them works too).',
      );
      return null;
    }
    return fields;
  }

  void _printTree(String featureName, String modelName) {
    _logger.success('');
    void line(String s) => _logger.info('  $s');

    line('features/$featureName/');
    line('└── domain/');
    line('    └── models/${modelName}_model.dart');
    line('');
    _logger.info('');
  }

  Future<int> _injectEmptyFactory({
    required String modelName,
    required String modelClass,
    required String modelFile,
  }) async {
    if (!File(modelFile).existsSync()) {
      _logger.err(
        'Model file not found at $modelFile.\n'
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
        'Make sure the class has a const factory with named parameters.',
      );
    }

    final factory = ModelFieldParser.buildEmptyFactory(modelClass, fields);

    // Inject at the end of the model's own body — the file's last brace may
    // belong to a second class declared below it.
    final closing =
        ModelFieldParser.classBody(source, modelClass)?.end ??
        source.lastIndexOf('}');
    if (closing == -1) {
      _logger.err('Could not locate closing brace in $modelFile.');
      return 1;
    }

    final updated =
        source.substring(0, closing) + factory + source.substring(closing);

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
    _logger.info(
      '    ${modelFile.replaceAll(RegExp(r'^.*[/\\]lib[/\\]'), 'lib/')}',
    );
    _logger.info('');
    return 0;
  }
}
