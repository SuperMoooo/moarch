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

  String modelPath(String feature, String model) => p.join(
        libPath,
        'features',
        feature,
        'domain',
        'models',
        '${model}_model.dart',
      );

  Future<void> placeModel(
    String feature,
    String model,
    String source,
  ) async {
    final path = modelPath(feature, model);
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(source);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_model_test');
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

    test('writes the model into the named feature, and nothing else', () async {
      final code = await runner
          .run(['model', '--path', libPath, 'auth', 'login_response']);

      expect(code, 0);
      expect(File(modelPath('auth', 'login_response')).existsSync(), isTrue);
      // A model is the only type a feature has — there is no domain/entities,
      // and nothing is written under data/.
      final feature = p.join(libPath, 'features', 'auth');
      expect(Directory(p.join(feature, 'domain', 'entities')).existsSync(),
          isFalse);
      expect(Directory(p.join(feature, 'data')).existsSync(), isFalse);
    });

    test('refuses a feature that does not exist', () async {
      final code =
          await runner.run(['model', '--path', libPath, 'billing', 'invoice']);

      expect(code, 1);
      expect(Directory(p.join(libPath, 'features', 'billing')).existsSync(),
          isFalse);
    });

    test('the scaffolded model is freezed and carries its own JSON', () async {
      await runner.run(['model', '--path', libPath, 'auth', 'login_response']);

      final model =
          await File(modelPath('auth', 'login_response')).readAsString();

      expect(model, contains('@freezed'));
      expect(model, contains("part 'login_response_model.freezed.dart';"));
      expect(model, contains("part 'login_response_model.g.dart';"));
      expect(model, contains('const LoginResponseModel._();'));
      expect(model, contains('factory LoginResponseModel.fromJson('));
      // Freezed writes equality over every field; nothing hand-rolled survives.
      expect(model, isNot(contains('operator ==')));
      // .empty() is not something freezed writes, so the scaffold still does.
      expect(model, contains('factory LoginResponseModel.empty()'));
      // No entity to map to or from.
      expect(model, isNot(contains('Entity')));
    });

    test('--empty names the factory after the model class', () async {
      await placeModel('auth', 'login_response', '''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_response_model.freezed.dart';

@freezed
abstract class LoginResponseModel with _\$LoginResponseModel {
  const factory LoginResponseModel({
    required int id,
    String? token,
  }) = _LoginResponseModel;
}
''');

      final code = await runner.run(
          ['model', '--path', libPath, '--empty', 'auth', 'login_response']);

      expect(code, 0);
      final source =
          await File(modelPath('auth', 'login_response')).readAsString();
      expect(source, contains('factory LoginResponseModel.empty()'));
      // Read off the freezed factory's parameters — a freezed class declares
      // no fields for the old parser to find.
      expect(source, contains('id: 0,'));
      expect(source, contains('token: null,'));
      // The class is LoginResponseModel — a factory named for the feature alone
      // would not compile.
      expect(source, isNot(contains('factory LoginResponse.empty()')));
    });

    test('--empty is a no-op once the model has one', () async {
      await runner.run(['model', '--path', libPath, 'auth', 'login_response']);
      final scaffolded =
          await File(modelPath('auth', 'login_response')).readAsString();

      final code = await runner.run(
          ['model', '--path', libPath, '--empty', 'auth', 'login_response']);

      expect(code, 0);
      expect(await File(modelPath('auth', 'login_response')).readAsString(),
          scaffolded);
    });

    test('--empty injects into the model, not a second class below it',
        () async {
      await placeModel('auth', 'session', '''
class SessionModel {
  const SessionModel({required this.id});

  final int id;
}

class DeviceModel {
  const DeviceModel({required this.name});

  final String name;
}
''');

      final code = await runner
          .run(['model', '--path', libPath, '--empty', 'auth', 'session']);

      expect(code, 0);
      final source = await File(modelPath('auth', 'session')).readAsString();
      final factoryAt = source.indexOf('factory SessionModel.empty()');
      expect(factoryAt, greaterThan(-1));
      expect(factoryAt, lessThan(source.indexOf('class DeviceModel')));
      // Fields belong to the model being patched, not to its neighbour.
      expect(source, isNot(contains("name: ''")));
    });
  });

  group('create empty-factories', () {
    test('covers a field whose type carries a comma', () async {
      await placeModel('orders', 'order', '''
class OrderModel {
  const OrderModel({required this.id, required this.meta});

  final int id;
  final Map<String, dynamic> meta;
}
''');

      final code = await runner.run(['empty-factories', '--path', libPath]);

      expect(code, 0);
      final source = await File(modelPath('orders', 'order')).readAsString();
      expect(source, contains('id: 0,'));
      expect(source, contains('meta: const {},'));
    });

    test('a second run changes nothing', () async {
      await placeModel('orders', 'order', '''
class OrderModel {
  const OrderModel({required this.id});

  final int id;
}
''');
      await runner.run(['empty-factories', '--path', libPath]);
      final once = await File(modelPath('orders', 'order')).readAsString();

      final code = await runner.run(['empty-factories', '--path', libPath]);

      expect(code, 0);
      expect(await File(modelPath('orders', 'order')).readAsString(), once);
    });

    test('leaves a hand-written block-bodied factory alone', () async {
      const handWritten = '''
class OrderModel {
  const OrderModel({required this.id});

  final int id;

  factory OrderModel.empty() {
    return const OrderModel(id: -1);
  }
}
''';
      await placeModel('orders', 'order', handWritten);

      final code = await runner.run(['empty-factories', '--path', libPath]);

      expect(code, 0);
      expect(
          await File(modelPath('orders', 'order')).readAsString(), handWritten);
    });

    test('--dry-run writes nothing', () async {
      const original = '''
class OrderModel {
  const OrderModel({required this.id});

  final int id;
}
''';
      await placeModel('orders', 'order', original);

      final code =
          await runner.run(['empty-factories', '--path', libPath, '--dry-run']);

      expect(code, 0);
      expect(await File(modelPath('orders', 'order')).readAsString(), original);
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
      final model = await File(modelPath('works', 'fatura')).readAsString();

      expect(model,
          contains('@JsonKey(includeToJson: false) required String id,'));
      expect(model, contains("{...?doc.data(), 'id': doc.id}"));
    });

    test('without --doc the model is a nested value', () async {
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
      final model = await File(modelPath('works', 'linha')).readAsString();

      expect(model, isNot(contains('fromDoc')));
      expect(model, isNot(contains('includeToJson')));
      expect(model, isNot(contains('required String id,')));
      // A map inside a document is still inside a document, so its dates
      // belong on the wire the same way.
      expect(model, contains('@TimestampConverter()'));
    });
  });
}
