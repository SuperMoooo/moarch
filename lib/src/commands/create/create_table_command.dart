import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../templates/core/cache_templates.dart';
import '../../utils/dart_source.dart';
import '../../utils/drift_table_builder.dart';
import '../../utils/file_utils.dart';
import '../../utils/model_field_parser.dart';
import '../../utils/project_manifest.dart';
import '../../utils/project_paths.dart';
import '../../utils/scaffold_catalog.dart';
import '../../utils/string_utils.dart';

/// Gives a feature a drift table of its own, read from its freezed model,
/// and moves its local datasource off the shared JSON cache onto it.
///
/// The model is the source of truth: the table is regenerated from it, so
/// after changing the model's fields the command is simply run again. Files
/// the developer owns are changed only where they are still exactly what
/// moarch wrote; anything else gets the edit printed instead.
class CreateTableCommand extends Command<int> {
  /// CREATE TABLE COMMAND
  CreateTableCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'path',
      abbr: 'p',
      defaultsTo: 'lib',
      help: 'Path to the lib/ directory, or the project root holding it.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'table';

  @override
  String get description =>
      "Give a feature its own drift table, read from the feature's model "
      '(offline-first projects).';

  @override
  String get invocation => 'moarch create table <feature_name>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      _logger.err('Name the feature: $invocation');
      return 64;
    }
    final libPath = resolveLibPath(argResults?['path'] as String? ?? 'lib');
    final root = p.dirname(p.absolute(libPath));
    final context = ScaffoldContext.detect(root);

    if (!context.hasLocalCache) {
      _logger.err(
        'This project has no offline-first cache '
        '(lib/core/database/local_cache.dart). A feature table lives in its '
        'drift database: scaffold with the "Offline-first cache" option.',
      );
      return 1;
    }

    final name = StringUtils.toSnakeCase(rest.first);
    final cls = StringUtils.toPascalCase(name);
    final featureDir = p.join(libPath, 'features', name);
    final modelFile = File(
      p.join(featureDir, 'data', 'models', '${name}_model.dart'),
    );
    if (!modelFile.existsSync()) {
      _logger.err('No model at ${_display(root, modelFile.path)}.');
      return 1;
    }

    final modelSource = modelFile.readAsStringSync();
    final fields = ModelFieldParser.parse(modelSource, '${cls}Model');
    final table = '${cls}Rows';
    final plan = DriftTableBuilder.plan(
      fields,
      enums: _projectEnums(libPath),
      table: table,
    );
    if (plan.idType == null) {
      _logger.err(
        '${cls}Model needs a non-null `int id` or `String id`: it is the '
        "table's primary key.",
      );
      return 1;
    }
    if (plan.unsupported.isNotEmpty) {
      _logger.err('No column type fits these fields of ${cls}Model:');
      for (final field in plan.unsupported) {
        _logger.err('  $field');
      }
      _logger.info(
        'Supported: int, double, String, bool, DateTime, an enum, a nested '
        'model, and a List or Map<String, …> of those.',
      );
      return 1;
    }

    final manifest = ProjectManifest.loadOrCreate(root);
    FileUtils.beginSession();
    final todo = <String>[];

    // 1. The table, which a re-run rewrites.
    final tablePath = p.join(
      featureDir,
      'data',
      'tables',
      '${name}_table.dart',
    );
    final tableFile = File(tablePath);
    final previousTable = tableFile.existsSync()
        ? tableFile.readAsStringSync()
        : null;
    final tableSource = CacheTemplates.featureTable(
      name: name,
      cls: cls,
      plan: plan,
      imports: _typeImports(
        modelFile: modelFile,
        modelSource: modelSource,
        tablesDir: p.dirname(tablePath),
        libPath: libPath,
        projectName: context.projectName,
        types: _referencedTypes(plan),
      ),
    );
    final tableChanged =
        previousTable == null ||
        _normalize(previousTable) != _normalize(tableSource);
    if (previousTable != null &&
        tableChanged &&
        !previousTable.contains('moarch create table')) {
      _logger.err(
        '${_display(root, tablePath)} exists and was not written by moarch: '
        'left alone.',
      );
      return 1;
    }
    if (tableChanged) {
      await FileUtils.writeFile(
        tablePath,
        tableSource,
        overwriteWhen: (_) => true,
      );
      manifest.record(root, tablePath, tableSource);
    }

    // 2. The database: registers the table and bumps the schema.
    _updateDatabase(root, context, manifest, tableChanged, todo, table);

    // 3. LocalCache.clearAll must empty the new table on sign-out.
    _updateLocalCache(root, context, manifest, todo);

    // 4. The local datasource reads the table instead of the JSON cache.
    final datasourcePath = p.join(
      featureDir,
      'data',
      'datasources',
      '${name}_local_datasource.dart',
    );
    final datasource = CacheTemplates.tableLocalDatasource(
      name: name,
      cls: cls,
      plan: plan,
    );
    _updateDatasource(root, datasourcePath, datasource, name, cls, todo);

    // 5. The locator hands it the database instead of LocalCache.
    _updateRegistration(libPath, cls, todo);

    await manifest.save(root);

    _logger.info('');
    _logger.success(
      tableChanged
          ? '✓ ${cls}Rows written to ${_display(root, tablePath)}'
          : '✓ ${cls}Rows already matches ${cls}Model',
    );
    if (todo.isNotEmpty) {
      _logger.info('');
      _logger.warn('Left for you, since these files were edited:');
      for (final step in todo) {
        _logger.info('  • $step');
      }
    }
    _logger.info('');
    _logger.info('Next: fvm dart run build_runner build -d');
    return 0;
  }

  void _updateDatabase(
    String root,
    ScaffoldContext context,
    ProjectManifest manifest,
    bool tableChanged,
    List<String> todo,
    String table,
  ) {
    final path = context.resolve('lib/core/database/app_database.dart');
    final file = File(path);
    final current = file.existsSync() ? file.readAsStringSync() : '';
    final tables = context.featureTables;
    final version = context.databaseSchemaVersion;
    final next = CacheTemplates.appDatabase(
      withSync: context.hasSync,
      featureTables: tables,
      schemaVersion: tableChanged ? version + 1 : version,
      encrypted: context.hasEncryptedDatabase,
    );
    if (_normalize(current) == _normalize(next)) return;

    // Untouched means: what moarch would have written before this table, or
    // what the manifest says it last wrote.
    final before = CacheTemplates.appDatabase(
      withSync: context.hasSync,
      featureTables: [
        for (final t in tables)
          if (t.className != table) t,
      ],
      schemaVersion: version,
      encrypted: context.hasEncryptedDatabase,
    );
    final recorded = manifest.recordedHash(root, path);
    final untouched =
        _normalize(current) == _normalize(before) ||
        (recorded != null && recorded == ProjectManifest.hashContent(current));
    if (untouched) {
      file.writeAsStringSync(next);
      manifest.record(root, path, next);
      return;
    }
    final ref = tables.firstWhere((t) => t.className == table);
    todo.add(
      "lib/core/database/app_database.dart: import '${ref.importPath}', add "
      '$table to @DriftDatabase(tables: [...])'
      '${tableChanged ? ', and bump schemaVersion to ${version + 1}' : ''}. '
      'onUpgrade must create $table (the generated loop over allTables '
      'does).',
    );
  }

  void _updateLocalCache(
    String root,
    ScaffoldContext context,
    ProjectManifest manifest,
    List<String> todo,
  ) {
    final path = context.resolve('lib/core/database/local_cache.dart');
    final file = File(path);
    final current = file.readAsStringSync();
    if (current.contains('allTables')) return;
    final next = CacheTemplates.localCache(withSync: context.hasSync);
    final recorded = manifest.recordedHash(root, path);
    if (recorded != null && recorded == ProjectManifest.hashContent(current)) {
      file.writeAsStringSync(next);
      manifest.record(root, path, next);
      return;
    }
    todo.add(
      'lib/core/database/local_cache.dart: make clearAll() delete from every '
      'table in _db.allTables, or sign-out leaves this table full '
      '(`moarch update local-cache --diff` shows the change).',
    );
  }

  void _updateDatasource(
    String root,
    String path,
    String next,
    String name,
    String cls,
    List<String> todo,
  ) {
    final file = File(path);
    if (!file.existsSync()) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(next);
      return;
    }
    final current = file.readAsStringSync();
    if (_normalize(current) == _normalize(next)) return;
    if (_normalize(current) ==
        _normalize(CacheTemplates.localDatasource(name, cls))) {
      file.writeAsStringSync(next);
      return;
    }
    // A datasource already on the table, with queries of its own added: only
    // the row mapping follows the model.
    final row = RegExp(r'  \w+Companion _row\([\s\S]*?\n  \}\n');
    final fresh = row.firstMatch(next);
    if (current.contains('Companion _row(') && fresh != null) {
      final patched = current.replaceFirst(row, fresh.group(0)!);
      if (patched != current) file.writeAsStringSync(patched);
      return;
    }
    todo.add(
      '${_display(root, path)}: read and write ${cls}Rows through '
      'AppDatabase instead of LocalCache (the shape '
      '`moarch create table` writes for an untouched datasource).',
    );
  }

  void _updateRegistration(String libPath, String cls, List<String> todo) {
    final di = Directory(p.join(libPath, 'config', 'di'));
    if (!di.existsSync()) return;
    final old = '${cls}LocalDataSource(getIt<LocalCache>())';
    final next = '${cls}LocalDataSource(getIt<AppDatabase>())';
    for (final file in di.listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      var source = file.readAsStringSync();
      if (source.contains(next)) return;
      if (!source.contains(old)) continue;
      source = source.replaceAll(old, next);
      source = DartSource.addImports(source, [
        "import '../../core/database/app_database.dart';",
      ]);
      // The datasource was the file's last use of LocalCache.
      if (!RegExp(r'\bLocalCache\b').hasMatch(
        source.replaceAll("import '../../core/database/local_cache.dart';", ''),
      )) {
        source = source.replaceAll(
          RegExp(r"import '\.\./\.\./core/database/local_cache\.dart';\r?\n"),
          '',
        );
      }
      file.writeAsStringSync(source);
      return;
    }
    todo.add(
      'lib/config/di: register ${cls}LocalDataSource with '
      '`getIt<AppDatabase>()` instead of `getIt<LocalCache>()`.',
    );
  }

  /// Every enum declared under lib/, which is what tells a `textEnum` column
  /// from a nested model stored as JSON.
  Set<String> _projectEnums(String libPath) {
    final enums = <String>{};
    final pattern = RegExp(r'^\s*enum\s+(\w+)', multiLine: true);
    for (final entity in Directory(libPath).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        enums.add(match.group(1)!);
      }
    }
    return enums;
  }

  /// The class names a column's type mentions — `List<TagModel>` → TagModel.
  Set<String> _referencedTypes(DriftTablePlan plan) => {
    for (final column in plan.columns)
      ...RegExp(r'[A-Z]\w*').allMatches(column.dartType).map((m) => m[0]!),
  }..removeAll(const {'String', 'DateTime', 'List', 'Map', 'Object'});

  /// The model's own imports that declare one of [types], rewritten to be
  /// relative to [tablesDir]. Package imports from outside the project are
  /// left out: a column type from another package is not one moarch maps.
  List<String> _typeImports({
    required File modelFile,
    required String modelSource,
    required String tablesDir,
    required String libPath,
    required String? projectName,
    required Set<String> types,
  }) {
    if (types.isEmpty) return const [];
    final imports = <String>[];
    final pattern = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true);
    for (final match in pattern.allMatches(modelSource)) {
      final uri = match.group(1)!;
      final String target;
      if (uri.startsWith('dart:')) continue;
      if (uri.startsWith('package:')) {
        final prefix = 'package:$projectName/';
        if (projectName == null || !uri.startsWith(prefix)) continue;
        target = p.join(libPath, uri.substring(prefix.length));
      } else {
        target = p.normalize(p.join(p.dirname(modelFile.path), uri));
      }
      final file = File(target);
      if (!file.existsSync()) continue;
      final declares = RegExp(
        '\\b(?:class|enum|typedef|mixin)\\s+(?:${types.map(RegExp.escape).join('|')})\\b',
      );
      if (!declares.hasMatch(file.readAsStringSync())) continue;
      imports.add(
        uri.startsWith('package:')
            ? uri
            : p.relative(target, from: tablesDir).replaceAll(r'\', '/'),
      );
    }
    return imports;
  }

  static String _normalize(String source) => source.replaceAll('\r\n', '\n');

  static String _display(String root, String path) =>
      p.relative(path, from: root).replaceAll(r'\', '/');
}
