import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/create/create_empty_factories_command.dart';
import 'package:moarch/src/commands/create/create_model_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String libPath;
  late CommandRunner<int> runner;

  String entityPath(String feature, String model) => p.join(
        libPath,
        'features',
        feature,
        'domain',
        'entities',
        '${model}_entity.dart',
      );

  Future<void> placeEntity(
    String feature,
    String model,
    String source,
  ) async {
    final path = entityPath(feature, model);
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(source);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_entity_test');
    libPath = p.join(tempDir.path, 'lib');
    await Directory(libPath).create(recursive: true);

    final logger = Logger(level: Level.quiet);
    runner = CommandRunner<int>('moarch', 'test')
      ..addCommand(CreateModelCommand(logger: logger))
      ..addCommand(CreateEmptyFactoriesCommand(logger: logger));
  });

  tearDown(() async => tempDir.delete(recursive: true));

  group('create model', () {
    setUp(() async {
      await Directory(p.join(libPath, 'features', 'auth'))
          .create(recursive: true);
    });

    test('writes the model and the entity into the named feature', () async {
      final code = await runner
          .run(['model', '--path', libPath, 'auth', 'login_response']);

      expect(code, 0);
      expect(File(entityPath('auth', 'login_response')).existsSync(), isTrue);
      expect(
        File(p.join(libPath, 'features', 'auth', 'data', 'models',
                'login_response_model.dart'))
            .existsSync(),
        isTrue,
      );
    });

    test('refuses a feature that does not exist', () async {
      final code =
          await runner.run(['model', '--path', libPath, 'billing', 'invoice']);

      expect(code, 1);
      expect(Directory(p.join(libPath, 'features', 'billing')).existsSync(),
          isFalse);
    });

    test('the scaffolded pair is freezed, and the entity holds no JSON',
        () async {
      await runner.run(['model', '--path', libPath, 'auth', 'login_response']);

      final entity =
          await File(entityPath('auth', 'login_response')).readAsString();
      final model = await File(p.join(libPath, 'features', 'auth', 'data',
              'models', 'login_response_model.dart'))
          .readAsString();

      expect(entity, contains('@freezed'));
      expect(entity, contains("part 'login_response_entity.freezed.dart';"));
      // Parsing is the model's job — domain/ never imports json_annotation.
      expect(entity, isNot(contains('json_annotation')));
      expect(entity, isNot(contains('.g.dart')));
      // Freezed writes equality over every field; nothing hand-rolled survives.
      expect(entity, isNot(contains('operator ==')));
      // .empty() is not something freezed writes, so the scaffold still does.
      expect(entity, contains('factory LoginResponseEntity.empty()'));

      expect(model, contains('const LoginResponseModel._();'));
      expect(model, contains("part 'login_response_model.g.dart';"));
      expect(model, isNot(contains('extends LoginResponseEntity')));
      expect(model, contains('LoginResponseEntity toEntity()'));
    });

    test('--empty names the factory after the entity class', () async {
      await placeEntity('auth', 'login_response', '''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_response_entity.freezed.dart';

@freezed
abstract class LoginResponseEntity with _\$LoginResponseEntity {
  const factory LoginResponseEntity({
    required int id,
    String? token,
  }) = _LoginResponseEntity;
}
''');

      final code = await runner.run(
          ['model', '--path', libPath, '--empty', 'auth', 'login_response']);

      expect(code, 0);
      final source =
          await File(entityPath('auth', 'login_response')).readAsString();
      expect(source, contains('factory LoginResponseEntity.empty()'));
      // Read off the freezed factory's parameters — a freezed class declares
      // no fields for the old parser to find.
      expect(source, contains('id: 0,'));
      expect(source, contains('token: null,'));
      // The class is LoginResponseEntity — a factory named for the model alone
      // would not compile.
      expect(source, isNot(contains('factory LoginResponse.empty()')));
    });

    test('--empty is a no-op once the entity has one', () async {
      await runner.run(['model', '--path', libPath, 'auth', 'login_response']);
      final scaffolded =
          await File(entityPath('auth', 'login_response')).readAsString();

      final code = await runner.run(
          ['model', '--path', libPath, '--empty', 'auth', 'login_response']);

      expect(code, 0);
      expect(await File(entityPath('auth', 'login_response')).readAsString(),
          scaffolded);
    });

    test('--empty injects into the entity, not a second class below it',
        () async {
      await placeEntity('auth', 'session', '''
class SessionEntity {
  const SessionEntity({required this.id});

  final int id;
}

class DeviceEntity {
  const DeviceEntity({required this.name});

  final String name;
}
''');

      final code = await runner
          .run(['model', '--path', libPath, '--empty', 'auth', 'session']);

      expect(code, 0);
      final source = await File(entityPath('auth', 'session')).readAsString();
      final factoryAt = source.indexOf('factory SessionEntity.empty()');
      expect(factoryAt, greaterThan(-1));
      expect(factoryAt, lessThan(source.indexOf('class DeviceEntity')));
      // Fields belong to the entity being patched, not to its neighbour.
      expect(source, isNot(contains("name: ''")));
    });
  });

  group('create empty-factories', () {
    test('covers a field whose type carries a comma', () async {
      await placeEntity('orders', 'order', '''
class OrderEntity {
  const OrderEntity({required this.id, required this.meta});

  final int id;
  final Map<String, dynamic> meta;
}
''');

      final code = await runner.run(['empty-factories', '--path', libPath]);

      expect(code, 0);
      final source = await File(entityPath('orders', 'order')).readAsString();
      expect(source, contains('id: 0,'));
      expect(source, contains('meta: const {},'));
    });

    test('a second run changes nothing', () async {
      await placeEntity('orders', 'order', '''
class OrderEntity {
  const OrderEntity({required this.id});

  final int id;
}
''');
      await runner.run(['empty-factories', '--path', libPath]);
      final once = await File(entityPath('orders', 'order')).readAsString();

      final code = await runner.run(['empty-factories', '--path', libPath]);

      expect(code, 0);
      expect(await File(entityPath('orders', 'order')).readAsString(), once);
    });

    test('leaves a hand-written block-bodied factory alone', () async {
      const handWritten = '''
class OrderEntity {
  const OrderEntity({required this.id});

  final int id;

  factory OrderEntity.empty() {
    return const OrderEntity(id: -1);
  }
}
''';
      await placeEntity('orders', 'order', handWritten);

      final code = await runner.run(['empty-factories', '--path', libPath]);

      expect(code, 0);
      expect(await File(entityPath('orders', 'order')).readAsString(),
          handWritten);
    });

    test('--dry-run writes nothing', () async {
      const original = '''
class OrderEntity {
  const OrderEntity({required this.id});

  final int id;
}
''';
      await placeEntity('orders', 'order', original);

      final code =
          await runner.run(['empty-factories', '--path', libPath, '--dry-run']);

      expect(code, 0);
      expect(
          await File(entityPath('orders', 'order')).readAsString(), original);
    });
  });

  group('create model --from-json --doc', () {
    late String samplePath;

    setUp(() async {
      await Directory(p.join(libPath, 'features', 'works'))
          .create(recursive: true);
      // The shape is read off the project, so it has to look like one that
      // stores its data in Firestore.
      await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString(
        'name: sample\n'
        'dependencies:\n'
        '  cloud_firestore: ^6.8.0\n',
      );
      samplePath = p.join(tempDir.path, 'sample.json');
      // No `id`: a document's id is its name, so an exported payload has none.
      await File(samplePath).writeAsString(
        '{"titulo": "Obra", "criado_em": "2026-08-01T10:30:00Z"}',
      );
    });

    String modelPath(String model) => p.join(
        libPath, 'features', 'works', 'data', 'models', '${model}_model.dart');
    String entity(String model) => entityPath('works', model);

    test('gives a document root the String id the sample could not', () async {
      final code = await runner.run([
        'model',
        '--path',
        libPath,
        '--from-json',
        samplePath,
        '--doc',
        'works',
        'fatura',
      ]);

      expect(code, 0);
      final model = await File(modelPath('fatura')).readAsString();

      expect(model,
          contains('@JsonKey(includeToJson: false) required String id,'));
      expect(model, contains("{...?doc.data(), 'id': doc.id}"));
      // The entity has to carry it too, or the mapping would not compile.
      expect(await File(entity('fatura')).readAsString(),
          contains('required String id,'));
    });

    test('without --doc the pair is a nested value', () async {
      final code = await runner.run([
        'model',
        '--path',
        libPath,
        '--from-json',
        samplePath,
        'works',
        'linha',
      ]);

      expect(code, 0);
      final model = await File(modelPath('linha')).readAsString();

      expect(model, isNot(contains('fromDoc')));
      expect(model, isNot(contains('includeToJson')));
      expect(model, isNot(contains('required String id,')));
      // A map inside a document is still inside a document, so its dates
      // belong on the wire the same way.
      expect(model, contains('@TimestampConverter()'));
    });
  });

  group('create model --from-entity', () {
    Future<void> placeFreezedEntity(String model, String params) =>
        placeEntity('works', model, '''
import 'package:freezed_annotation/freezed_annotation.dart';

part '${model}_entity.freezed.dart';

@freezed
abstract class ${_pascal(model)}Entity with _\$${_pascal(model)}Entity {
  const factory ${_pascal(model)}Entity({
$params
  }) = _${_pascal(model)}Entity;
}
''');

    String modelPath(String model) => p.join(
          libPath,
          'features',
          'works',
          'data',
          'models',
          '${model}_model.dart',
        );

    test('maps a nested entity and a list of them, both ways', () async {
      await placeFreezedEntity('work', '''
    required String id,
    required DatasEntity datas,
    MoradaEntity? morada,
    required List<UtilizadorEntity> utilizadores,
    required String titulo,''');

      final code = await runner.run(
        ['model', '--path', libPath, '--from-entity', 'works', 'work'],
      );

      expect(code, 0);
      final source = await File(modelPath('work')).readAsString();

      // The model declares the data-layer twin of each nested type.
      expect(source, contains('required DatasModel datas,'));
      expect(source, contains('MoradaModel? morada,'));
      expect(source, contains('required List<UtilizadorModel> utilizadores,'));

      // …and converts rather than assigns, in both directions.
      expect(source, contains('datas: DatasModel.fromEntity(entity.datas),'));
      expect(source, contains('datas: datas.toEntity(),'));
      expect(
        source,
        contains('morada: entity.morada == null'),
        reason: 'a nullable nested field must be guarded, not forced',
      );
      expect(source, contains('morada: morada?.toEntity(),'));
      expect(
        source,
        contains(
          'utilizadores: entity.utilizadores.map(UtilizadorModel.fromEntity)'
          '.toList(),',
        ),
      );
      expect(
        source,
        contains(
          'utilizadores: utilizadores.map((e) => e.toEntity()).toList(),',
        ),
      );

      // A plain field still goes straight across.
      expect(source, contains('titulo: entity.titulo,'));
    });

    test('imports the sibling model of every nested type', () async {
      await placeFreezedEntity('work', '''
    required String id,
    required DatasEntity datas,
    required List<UtilizadorEntity> utilizadores,''');

      await runner.run(
        ['model', '--path', libPath, '--from-entity', 'works', 'work'],
      );
      final source = await File(modelPath('work')).readAsString();

      expect(source, contains("import './datas_model.dart';"));
      expect(source, contains("import './utilizador_model.dart';"));
      expect(source, isNot(contains("import './work_model.dart';")));
    });

    test('every model carries the private constructor freezed needs', () async {
      await placeFreezedEntity('datas', '''
    required DateTime inicio,''');

      await runner.run(
        ['model', '--path', libPath, '--from-entity', 'works', 'datas'],
      );
      final source = await File(modelPath('datas')).readAsString();

      expect(source, contains('const DatasModel._();'));
      expect(source, contains("part 'datas_model.freezed.dart';"));
      expect(source, contains("part 'datas_model.g.dart';"));
      expect(source, isNot(contains('extends DatasEntity')));
    });

    test('leaves the entity alone', () async {
      await placeFreezedEntity('work', '    required String id,');
      final before = await File(entityPath('works', 'work')).readAsString();

      await runner.run(
        ['model', '--path', libPath, '--from-entity', 'works', 'work'],
      );

      expect(await File(entityPath('works', 'work')).readAsString(), before);
    });

    test('refuses to overwrite a model that already exists', () async {
      await placeFreezedEntity('work', '    required String id,');
      await Directory(p.dirname(modelPath('work'))).create(recursive: true);
      await File(modelPath('work')).writeAsString('// mine');

      final code = await runner.run(
        ['model', '--path', libPath, '--from-entity', 'works', 'work'],
      );

      expect(code, 1);
      expect(await File(modelPath('work')).readAsString(), '// mine');
    });

    test('refuses an entity that does not exist', () async {
      await Directory(p.join(libPath, 'features', 'works'))
          .create(recursive: true);

      final code = await runner.run(
        ['model', '--path', libPath, '--from-entity', 'works', 'ghost'],
      );

      expect(code, 1);
    });
  });
}

String _pascal(String snake) => snake
    .split('_')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join();
