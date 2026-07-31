import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/create/create_empty_factories_command.dart';
import 'package:moarch/src/commands/create/create_entity_copys_command.dart';
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
      ..addCommand(CreateEmptyFactoriesCommand(logger: logger))
      ..addCommand(CreateEntityCopysCommand(logger: logger));
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

    test('--empty names the factory after the entity class', () async {
      await runner.run(['model', '--path', libPath, 'auth', 'login_response']);

      final code = await runner.run(
          ['model', '--path', libPath, '--empty', 'auth', 'login_response']);

      expect(code, 0);
      final source =
          await File(entityPath('auth', 'login_response')).readAsString();
      expect(source, contains('factory LoginResponseEntity.empty()'));
      expect(source, contains('LoginResponseEntity(\n    id: 0,'));
      // The class is LoginResponseEntity — a factory named for the model alone
      // would not compile.
      expect(source, isNot(contains('factory LoginResponse.empty()')));
    });

    test('--empty is a no-op the second time', () async {
      await runner.run(['model', '--path', libPath, 'auth', 'login_response']);
      await runner.run(
          ['model', '--path', libPath, '--empty', 'auth', 'login_response']);
      final once =
          await File(entityPath('auth', 'login_response')).readAsString();

      final code = await runner.run(
          ['model', '--path', libPath, '--empty', 'auth', 'login_response']);

      expect(code, 0);
      expect(await File(entityPath('auth', 'login_response')).readAsString(),
          once);
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

  group('create entity-copys', () {
    test('copyWith takes every field, generics included', () async {
      await placeEntity('orders', 'order', '''
class OrderEntity {
  const OrderEntity({required this.id, required this.lines});

  final int id;
  final Map<String, int> lines;
}
''');

      final code = await runner.run(['entity-copys', '--path', libPath]);

      expect(code, 0);
      final source = await File(entityPath('orders', 'order')).readAsString();
      expect(source, contains('Map<String, int>? lines,'));
      expect(source, contains('lines: lines ?? this.lines,'));
    });

    test('patches the entity the file is named for, not the last class',
        () async {
      await placeEntity('orders', 'order', '''
class OrderEntity {
  const OrderEntity({required this.id});

  final int id;
}

class OrderLineEntity {
  const OrderLineEntity({required this.sku});

  final String sku;

  @override
  bool operator ==(Object other) => other is OrderLineEntity && other.sku == sku;

  @override
  int get hashCode => sku.hashCode;
}
''');

      final code = await runner.run(['entity-copys', '--path', libPath]);

      expect(code, 0);
      final source = await File(entityPath('orders', 'order')).readAsString();

      // The generated members land inside OrderEntity...
      final copyWithAt = source.indexOf('OrderEntity copyWith(');
      expect(copyWithAt, greaterThan(-1));
      expect(copyWithAt, lessThan(source.indexOf('class OrderLineEntity')));

      // ...built from its own field only...
      expect(source, isNot(contains('String? sku,')));

      // ...and the neighbour keeps the equality it already had.
      expect(source, contains('other is OrderLineEntity && other.sku == sku'));
    });

    test('a second run changes nothing', () async {
      await placeEntity('orders', 'order', '''
class OrderEntity {
  const OrderEntity({required this.id});

  final int id;
}
''');
      await runner.run(['entity-copys', '--path', libPath]);
      final once = await File(entityPath('orders', 'order')).readAsString();

      final code = await runner.run(['entity-copys', '--path', libPath]);

      expect(code, 0);
      expect(await File(entityPath('orders', 'order')).readAsString(), once);
    });
  });
}
