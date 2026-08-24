import 'package:moarch/src/utils/model_field_parser.dart';
import 'package:test/test.dart';

/// What `moarch create model` writes, plus the fields a real entity grows.
const _userEntity = '''
class UserEntity {
  const UserEntity({
    required this.id,
    required this.meta,
    required this.tags,
    this.nickname,
  });

  final int id;
  final Map<String, dynamic> meta;
  final List<String> tags;
  final String? nickname;

  static const String table = 'users';
}
''';

void main() {
  group('parse', () {
    test('reads a plain typed field', () {
      final fields = ModelFieldParser.parse(_userEntity, 'UserEntity');
      final id = fields.firstWhere((f) => f.name == 'id');
      expect(id.type, 'int');
    });

    test('keeps a type whose generics carry a comma', () {
      final fields = ModelFieldParser.parse(_userEntity, 'UserEntity');
      final meta = fields.firstWhere(
        (f) => f.name == 'meta',
        orElse: () => const ModelField(name: 'missing'),
      );
      expect(meta.type, 'Map<String, dynamic>');
    });

    test('keeps a nullable field as nullable', () {
      final fields = ModelFieldParser.parse(_userEntity, 'UserEntity');
      expect(
        fields.firstWhere((f) => f.name == 'nickname').type,
        'String?',
      );
    });

    test('skips a static member', () {
      final fields = ModelFieldParser.parse(_userEntity, 'UserEntity');
      expect(fields.map((f) => f.name), isNot(contains('table')));
    });

    test('reads every field of the class exactly once', () {
      final fields = ModelFieldParser.parse(_userEntity, 'UserEntity');
      expect(
        fields.map((f) => f.name),
        ['id', 'meta', 'tags', 'nickname'],
      );
    });

    test('handles generics nested two deep', () {
      const source = '''
class OrderEntity {
  final Map<String, List<Map<int, String>>> buckets;
}
''';
      final fields = ModelFieldParser.parse(source, 'OrderEntity');
      expect(fields.single.type, 'Map<String, List<Map<int, String>>>');
    });

    test('reads a function-typed field', () {
      const source = '''
class FormEntity {
  final void Function(int)? onPick;
}
''';
      final fields = ModelFieldParser.parse(source, 'FormEntity');
      expect(fields.single.name, 'onPick');
    });

    test('skips a private field — it cannot be a named parameter', () {
      const source = '''
class CacheEntity {
  final String id;
  final int _revision;
}
''';
      final fields = ModelFieldParser.parse(source, 'CacheEntity');
      expect(fields.map((f) => f.name), ['id']);
    });

    test('does not read a statement in a method body as a field', () {
      const source = '''
class TotalEntity {
  final int amount;

  int doubled() {
    final int scaled = amount * 2;
    return scaled;
  }
}
''';
      final fields = ModelFieldParser.parse(source, 'TotalEntity');
      expect(fields.map((f) => f.name), isNot(contains('scaled')));
    });

    test('does not read a getter declaration as a field', () {
      const source = '''
abstract class ReportEntity {
  final int id;

  String get title;
}
''';
      final fields = ModelFieldParser.parse(source, 'ReportEntity');
      expect(fields.map((f) => f.name), ['id']);
    });

    test('reads only the named class when the file declares two', () {
      const source = '''
class UserEntity {
  final int id;
}

class AddressEntity {
  final String street;
}
''';
      expect(
        ModelFieldParser.parse(source, 'UserEntity').map((f) => f.name),
        ['id'],
      );
      expect(
        ModelFieldParser.parse(source, 'AddressEntity').map((f) => f.name),
        ['street'],
      );
    });

    test('falls back to the whole file when the class is not found', () {
      const source = '''
class Something {
  final int id;
}
''';
      expect(
        ModelFieldParser.parse(source, 'MissingEntity').map((f) => f.name),
        ['id'],
      );
    });

    test('a class name is matched whole, not as a prefix', () {
      const source = '''
class UserEntityDetails {
  final String detail;
}

class UserEntity {
  final int id;
}
''';
      expect(
        ModelFieldParser.parse(source, 'UserEntity').map((f) => f.name),
        ['id'],
      );
    });

    test('a brace inside a string does not end the class body', () {
      const source = r'''
class TemplateEntity {
  final String pattern;

  String render() => '{ $pattern }';

  final int version;
}
''';
      expect(
        ModelFieldParser.parse(source, 'TemplateEntity').map((f) => f.name),
        ['pattern', 'version'],
      );
    });

    test('a brace inside a comment does not end the class body', () {
      const source = '''
class NoteEntity {
  final String body;

  // closes with }
  /* and { here too */

  final int order;
}
''';
      expect(
        ModelFieldParser.parse(source, 'NoteEntity').map((f) => f.name),
        ['body', 'order'],
      );
    });

    test('reads a class that extends another', () {
      const source = '''
class UserModel extends UserEntity {
  final String token;
}
''';
      expect(
        ModelFieldParser.parse(source, 'UserModel').map((f) => f.name),
        ['token'],
      );
    });
  });

  group('classBody', () {
    test('spans the named class only', () {
      const source = '''
class A {
  final int a;
}

class B {
  final int b;
}
''';
      final range = ModelFieldParser.classBody(source, 'A')!;
      expect(
          source.substring(range.start, range.end), contains('final int a;'));
      expect(
        source.substring(range.start, range.end),
        isNot(contains('final int b;')),
      );
      expect(source[range.end], '}');
    });

    test('is null for a class that is not there', () {
      expect(ModelFieldParser.classBody('class A {}', 'B'), isNull);
    });

    test('is null when the braces do not balance', () {
      expect(ModelFieldParser.classBody('class A {', 'A'), isNull);
    });
  });

  group('buildEmptyFactory', () {
    test('covers every field, including the ones with generic types', () {
      final fields = ModelFieldParser.parse(_userEntity, 'UserEntity');
      final factory = ModelFieldParser.buildEmptyFactory('UserEntity', fields);

      expect(factory, contains('id: 0,'));
      expect(factory, contains('meta: const {},'));
      expect(factory, contains('tags: const [],'));
      expect(factory, contains('nickname: null,'));
    });

    test('a fieldless class gets a bare factory', () {
      expect(
        ModelFieldParser.buildEmptyFactory('EmptyEntity', const []),
        contains('factory EmptyEntity.empty() => EmptyEntity();'),
      );
    });
  });

  group('freezed classes', () {
    const workEntity = '''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'work_entity.freezed.dart';

@freezed
abstract class WorkEntity with _\$WorkEntity {
  const factory WorkEntity({
    required String id,
    /// When the work runs.
    required DatasEntity datas,
    MoradaEntity? morada,
    required List<UtilizadorEntity> utilizadores,
    List<AnexoEntity>? anexos,
    @Default(false) bool arquivado,
    required Map<String, dynamic> extras,
  }) = _WorkEntity;

  factory WorkEntity.empty() => const WorkEntity(id: '');
}
''';

    final fields = ModelFieldParser.parse(workEntity, 'WorkEntity');
    ModelField field(String name) => fields.firstWhere((f) => f.name == name);

    test('reads the fields off the redirecting factory', () {
      // A freezed class declares no fields at all — the parameters are the
      // field list, and the `= _WorkEntity;` redirect is what tells that
      // factory from `empty`.
      expect(
        fields.map((f) => f.name),
        [
          'id',
          'datas',
          'morada',
          'utilizadores',
          'anexos',
          'arquivado',
          'extras'
        ],
      );
      expect(field('extras').type, 'Map<String, dynamic>');
    });

    test('a doc comment on a parameter is not part of its type', () {
      expect(field('datas').type, 'DatasEntity');
    });

    test('keeps @Default, and the field it makes optional', () {
      expect(field('arquivado').annotations, ['@Default(false)']);
      expect(field('arquivado').isRequired, isFalse);
      expect(field('id').isRequired, isTrue);
      expect(field('arquivado').asModelParameter,
          '@Default(false) bool arquivado');
    });
  });

  group('crossing the domain/data line', () {
    ModelField f(String type) => ModelField(name: 'x', type: type);

    test('a plain field is carried across untouched', () {
      for (final type in [
        'String',
        'int?',
        'DateTime',
        'List<String>',
        'Map<String, dynamic>',
        'dynamic'
      ]) {
        expect(ModelFieldParser.holdsEntity(type), isFalse, reason: type);
        expect(ModelFieldParser.modelTypeOf(type), type);
        expect(ModelFieldParser.fromEntityValue(f(type)), 'entity.x');
        expect(ModelFieldParser.toEntityValue(f(type)), 'x');
      }
    });

    test('a nested entity is converted, not assigned', () {
      expect(ModelFieldParser.holdsEntity('DatasEntity'), isTrue);
      expect(ModelFieldParser.modelTypeOf('DatasEntity'), 'DatasModel');
      expect(
        ModelFieldParser.fromEntityValue(f('DatasEntity')),
        'DatasModel.fromEntity(entity.x)',
      );
      expect(ModelFieldParser.toEntityValue(f('DatasEntity')), 'x.toEntity()');
    });

    test('a nullable nested entity is null-guarded, never forced', () {
      expect(ModelFieldParser.modelTypeOf('MoradaEntity?'), 'MoradaModel?');
      expect(
        ModelFieldParser.fromEntityValue(f('MoradaEntity?')),
        'entity.x == null ? null : MoradaModel.fromEntity(entity.x!)',
      );
      expect(
          ModelFieldParser.toEntityValue(f('MoradaEntity?')), 'x?.toEntity()');
    });

    test('a list of entities maps element-wise, both ways', () {
      expect(
        ModelFieldParser.modelTypeOf('List<UtilizadorEntity>'),
        'List<UtilizadorModel>',
      );
      expect(
        ModelFieldParser.fromEntityValue(f('List<UtilizadorEntity>')),
        'entity.x.map(UtilizadorModel.fromEntity).toList()',
      );
      expect(
        ModelFieldParser.toEntityValue(f('List<UtilizadorEntity>')),
        'x.map((e) => e.toEntity()).toList()',
      );
    });

    test('a nullable list of entities keeps the null', () {
      expect(
        ModelFieldParser.fromEntityValue(f('List<AnexoEntity>?')),
        'entity.x?.map(AnexoModel.fromEntity).toList()',
      );
      expect(
        ModelFieldParser.toEntityValue(f('List<AnexoEntity>?')),
        'x?.map((e) => e.toEntity()).toList()',
      );
    });

    test('a list of nullable entities promotes rather than forcing', () {
      // `e` is a callback parameter, so the compiler promotes it — a `!`
      // there would trip unnecessary_non_null_assertion.
      expect(
        ModelFieldParser.fromEntityValue(f('List<AnexoEntity?>')),
        'entity.x.map((e) => e == null ? null : AnexoModel.fromEntity(e))'
        '.toList()',
      );
    });

    test('a list of plain values is left alone', () {
      expect(ModelFieldParser.fromEntityValue(f('List<String>')), 'entity.x');
    });
  });
}
