import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/create/create_table_command.dart';
import 'package:moarch/src/templates/core/cache_templates.dart';
import 'package:moarch/src/utils/drift_table_builder.dart';
import 'package:moarch/src/utils/model_field_parser.dart';
import 'package:moarch/src/utils/project_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _todoModel = '''
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/network/timestamp_converter.dart';
import '../../../tags/data/models/tag_model.dart';
import 'todo_status.dart';

part 'todo_model.freezed.dart';
part 'todo_model.g.dart';

@freezed
abstract class TodoModel with _\$TodoModel {
  const factory TodoModel({
    required int id,
    required String title,
    @Default(false) bool done,
    DateTime? dueAt,
    required TodoStatus status,
    @Default([]) List<String> labels,
    TagModel? tag,
  }) = _TodoModel;

  factory TodoModel.fromJson(Map<String, dynamic> json) =>
      _\$TodoModelFromJson(json);
}
''';

List<ModelField> _fields(String source) =>
    ModelFieldParser.parse(source, 'TodoModel');

void main() {
  group('DriftTableBuilder', () {
    final plan = DriftTableBuilder.plan(
      _fields(_todoModel),
      enums: {'TodoStatus'},
      table: 'TodoRows',
    );

    test('maps each field to its column, keeping nullability', () {
      final byName = {for (final c in plan.columns) c.name: c};
      expect(plan.unsupported, isEmpty);
      expect(plan.idType, 'int');
      expect(byName['id']!.builder, 'integer()');
      expect(byName['title']!.builder, 'text()');
      expect(byName['done']!.builder, 'boolean()');
      expect(byName['dueAt']!.builder, 'dateTime()');
      expect(byName['dueAt']!.nullable, isTrue);
      expect(byName['status']!.builder, 'textEnum<TodoStatus>()');
    });

    test('stores lists and nested models as JSON through a converter', () {
      final byName = {for (final c in plan.columns) c.name: c};
      expect(byName['labels']!.builder, 'text().map(TodoRows.labelsConverter)');
      expect(
        byName['labels']!.converter,
        contains(
          'fromJson: (json) => [for (final e in json as List) e as String]',
        ),
      );
      expect(
        byName['tag']!.converter,
        contains('TagModel.fromJson(json as Map<String, Object?>)'),
      );
    });

    test('writes enums and dates in a list back as strings', () {
      final plan = DriftTableBuilder.plan(
        const [
          ModelField(name: 'id', type: 'String'),
          ModelField(name: 'states', type: 'List<TodoStatus>'),
          ModelField(name: 'days', type: 'List<DateTime>'),
        ],
        enums: {'TodoStatus'},
        table: 'TodoRows',
      );
      expect(plan.idType, 'String');
      expect(
        plan.columns[1].converter,
        contains('toJson: (value) => [for (final e in value) e.name]'),
      );
      expect(
        plan.columns[2].converter,
        contains('DateTime.parse(e as String)'),
      );
    });

    test('reports what no column fits instead of guessing', () {
      final plan = DriftTableBuilder.plan(
        const [
          ModelField(name: 'id', type: 'int'),
          ModelField(name: 'ratio', type: 'num'),
          ModelField(name: 'seen', type: 'Set<int>'),
          ModelField(name: 'listOrder', type: 'int'),
        ],
        enums: const {},
        table: 'TodoRows',
      );
      expect(plan.unsupported, hasLength(3));
      expect(plan.unsupported.last, contains('rename the field'));
    });

    test('a model without a usable id has no primary key', () {
      final plan = DriftTableBuilder.plan(
        const [ModelField(name: 'id', type: 'int?')],
        enums: const {},
        table: 'TodoRows',
      );
      expect(plan.idType, isNull);
    });
  });

  group('the table templates', () {
    final plan = DriftTableBuilder.plan(
      _fields(_todoModel),
      enums: {'TodoStatus'},
      table: 'TodoRows',
    );

    test(
      'the table uses the model as its row class and keeps the list order',
      () {
        final source = CacheTemplates.featureTable(
          name: 'todo',
          cls: 'Todo',
          plan: plan,
          imports: const ['../models/todo_status.dart'],
        );
        expect(source, contains('@UseRowClass(TodoModel)'));
        expect(source, contains('class TodoRows extends Table {'));
        expect(
          source,
          contains('DateTimeColumn get dueAt => dateTime().nullable()();'),
        );
        expect(source, contains('IntColumn get listOrder => integer()();'));
        expect(source, contains('Set<Column> get primaryKey => {id};'));
        // The class closes on its own line, after the converters.
        expect(source, contains('  );\n}\n'));
        expect(
          source,
          contains('static final labelsConverter = TypeConverter.json2'),
        );
        // app_database.g.dart sees only what app_database.dart imports.
        expect(source, contains("export '../models/todo_model.dart';"));
        expect(source, contains("export '../models/todo_status.dart';"));
        expect(source, contains('moarch create table todo'));
      },
    );

    test('the datasource answers from the table, in the API order', () {
      final source = CacheTemplates.tableLocalDatasource(
        name: 'todo',
        cls: 'Todo',
        plan: plan,
      );
      expect(source, contains(r'$TodoRowsTable get _table => _db.todoRows;'));
      expect(source, contains('OrderingTerm.asc(row.listOrder)'));
      expect(source, contains('Future<void> remove(int id)'));
      // An int id is the rowid, and optional in the companion.
      expect(source, contains('      id: Value(item.id),'));
      expect(source, contains('      title: item.title,'));
      expect(source, contains('      dueAt: Value(item.dueAt),'));
      expect(source, contains('      listOrder: listOrder,'));
      // The sync queue still keys the feature's writes by it.
      expect(source, contains("static const String collection = 'todo';"));
    });
  });

  group('create table', () {
    late Directory tempDir;
    late String root;
    late String libPath;
    late CommandRunner<int> runner;

    String file(String relative) => p.joinAll([root, ...relative.split('/')]);
    void write(String relative, String content) {
      File(file(relative))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    String read(String relative) => File(file(relative)).readAsStringSync();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_table_test');
      root = tempDir.path;
      libPath = p.join(root, 'lib');
      write('pubspec.yaml', 'name: demo\ndependencies:\n  drift: ^2.35.3\n');
      write(
        'lib/core/database/app_database.dart',
        CacheTemplates.appDatabase(),
      );
      write('lib/core/database/local_cache.dart', CacheTemplates.localCache());
      write('lib/features/todo/data/models/todo_model.dart', _todoModel);
      write(
        'lib/features/todo/data/models/todo_status.dart',
        'enum TodoStatus { open, closed }\n',
      );
      write(
        'lib/features/tags/data/models/tag_model.dart',
        'abstract class TagModel {}\n',
      );
      write('lib/core/network/timestamp_converter.dart', 'class Ts {}\n');
      write(
        'lib/features/todo/data/datasources/todo_local_datasource.dart',
        CacheTemplates.localDatasource('todo', 'Todo'),
      );
      write('lib/config/di/data_module.dart', '''
import '../../core/database/local_cache.dart';
import '../../features/todo/data/datasources/todo_local_datasource.dart';
import 'injector.dart';

void registerData() {
  getIt.registerLazySingleton<TodoLocalDataSource>(
    () => TodoLocalDataSource(getIt<LocalCache>()),
  );
  // moarch:registrations
}
''');
      final manifest = ProjectManifest.loadOrCreate(root)
        ..record(
          root,
          file('lib/core/database/local_cache.dart'),
          CacheTemplates.localCache(),
        );
      await manifest.save(root);

      runner = CommandRunner<int>('moarch', 'test')
        ..addCommand(CreateTableCommand(logger: Logger(level: Level.quiet)));
    });

    tearDown(() async => tempDir.delete(recursive: true));

    Future<int?> run() => runner.run(['table', '--path', libPath, 'todo']);

    test(
      'writes the table, importing only what declares a column type',
      () async {
        expect(await run(), 0);
        final table = read('lib/features/todo/data/tables/todo_table.dart');
        expect(table, contains("import '../models/todo_status.dart';"));
        expect(
          table,
          contains("import '../../../tags/data/models/tag_model.dart';"),
        );
        // Imported by the model for an annotation, not by any column.
        expect(table, isNot(contains('timestamp_converter')));
      },
    );

    test('registers it in AppDatabase and bumps the schema', () async {
      expect(await run(), 0);
      final db = read('lib/core/database/app_database.dart');
      expect(
        db,
        contains("import '../../features/todo/data/tables/todo_table.dart';"),
      );
      expect(db, contains('tables: [CacheEntries, TodoRows]'));
      expect(db, contains('int get schemaVersion => 2;'));
    });

    test('a re-run with the same model changes nothing', () async {
      expect(await run(), 0);
      final db = read('lib/core/database/app_database.dart');
      expect(await run(), 0);
      expect(read('lib/core/database/app_database.dart'), db);
    });

    test(
      'a changed model rewrites the table and bumps the schema again',
      () async {
        expect(await run(), 0);
        write(
          'lib/features/todo/data/models/todo_model.dart',
          _todoModel.replaceFirst(
            'required String title,',
            'required String title,\n    String? note,',
          ),
        );
        expect(await run(), 0);
        expect(
          read('lib/features/todo/data/tables/todo_table.dart'),
          contains('TextColumn get note => text().nullable()();'),
        );
        expect(
          read('lib/core/database/app_database.dart'),
          contains('int get schemaVersion => 3;'),
        );
        expect(
          read('lib/features/todo/data/datasources/todo_local_datasource.dart'),
          contains('      note: Value(item.note),'),
        );
      },
    );

    test(
      'moves the untouched datasource and its registration onto the table',
      () async {
        expect(await run(), 0);
        expect(
          read('lib/features/todo/data/datasources/todo_local_datasource.dart'),
          contains('const TodoLocalDataSource(this._db);'),
        );
        final di = read('lib/config/di/data_module.dart');
        expect(di, contains('TodoLocalDataSource(getIt<AppDatabase>())'));
        expect(di, contains("import '../../core/database/app_database.dart';"));
        expect(di, isNot(contains('local_cache.dart')));
      },
    );

    test(
      'refreshes an untouched LocalCache so sign-out empties the table',
      () async {
        expect(await run(), 0);
        expect(
          read('lib/core/database/local_cache.dart'),
          contains('for (final table in _db.allTables)'),
        );
      },
    );

    test(
      'an edited datasource keeps its own code; only the row mapping moves',
      () async {
        expect(await run(), 0);
        const path =
            'lib/features/todo/data/datasources/todo_local_datasource.dart';
        write(
          path,
          read(path).replaceFirst(
            '  Future<void> remove(',
            '  Future<int> countOpen() async => 0;\n\n  Future<void> remove(',
          ),
        );
        write(
          'lib/features/todo/data/models/todo_model.dart',
          _todoModel.replaceFirst(
            'required String title,',
            'required String title,\n    String? note,',
          ),
        );
        expect(await run(), 0);
        final source = read(path);
        expect(source, contains('Future<int> countOpen()'));
        expect(source, contains('      note: Value(item.note),'));
      },
    );

    test('refuses a model it cannot map, and writes nothing', () async {
      write(
        'lib/features/todo/data/models/todo_model.dart',
        _todoModel.replaceFirst('TagModel? tag,', 'Set<int> seen,'),
      );
      expect(await run(), 1);
      expect(
        File(
          file('lib/features/todo/data/tables/todo_table.dart'),
        ).existsSync(),
        isFalse,
      );
      expect(
        read('lib/core/database/app_database.dart'),
        contains('int get schemaVersion => 1;'),
      );
    });

    test('refuses a project without the offline-first cache', () async {
      File(file('lib/core/database/local_cache.dart')).deleteSync();
      expect(await run(), 1);
    });
  });
}
