import 'package:moarch/src/utils/model_field_parser.dart';
import 'package:test/test.dart';

/// What `moarch create model` writes, plus the fields a real model grows.
const _userModel = '''
class UserModel {
  const UserModel({
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
      final fields = ModelFieldParser.parse(_userModel, 'UserModel');
      final id = fields.firstWhere((f) => f.name == 'id');
      expect(id.type, 'int');
    });

    test('keeps a type whose generics carry a comma', () {
      final fields = ModelFieldParser.parse(_userModel, 'UserModel');
      final meta = fields.firstWhere(
        (f) => f.name == 'meta',
        orElse: () => const ModelField(name: 'missing'),
      );
      expect(meta.type, 'Map<String, dynamic>');
    });

    test('keeps a nullable field as nullable', () {
      final fields = ModelFieldParser.parse(_userModel, 'UserModel');
      expect(fields.firstWhere((f) => f.name == 'nickname').type, 'String?');
    });

    test('skips a static member', () {
      final fields = ModelFieldParser.parse(_userModel, 'UserModel');
      expect(fields.map((f) => f.name), isNot(contains('table')));
    });

    test('reads every field of the class exactly once', () {
      final fields = ModelFieldParser.parse(_userModel, 'UserModel');
      expect(fields.map((f) => f.name), ['id', 'meta', 'tags', 'nickname']);
    });

    test('handles generics nested two deep', () {
      const source = '''
class OrderModel {
  final Map<String, List<Map<int, String>>> buckets;
}
''';
      final fields = ModelFieldParser.parse(source, 'OrderModel');
      expect(fields.single.type, 'Map<String, List<Map<int, String>>>');
    });

    test('reads a function-typed field', () {
      const source = '''
class FormModel {
  final void Function(int)? onPick;
}
''';
      final fields = ModelFieldParser.parse(source, 'FormModel');
      expect(fields.single.name, 'onPick');
    });

    test('skips a private field — it cannot be a named parameter', () {
      const source = '''
class CacheModel {
  final String id;
  final int _revision;
}
''';
      final fields = ModelFieldParser.parse(source, 'CacheModel');
      expect(fields.map((f) => f.name), ['id']);
    });

    test('does not read a statement in a method body as a field', () {
      const source = '''
class TotalModel {
  final int amount;

  int doubled() {
    final int scaled = amount * 2;
    return scaled;
  }
}
''';
      final fields = ModelFieldParser.parse(source, 'TotalModel');
      expect(fields.map((f) => f.name), isNot(contains('scaled')));
    });

    test('does not read a getter declaration as a field', () {
      const source = '''
abstract class ReportModel {
  final int id;

  String get title;
}
''';
      final fields = ModelFieldParser.parse(source, 'ReportModel');
      expect(fields.map((f) => f.name), ['id']);
    });

    test('reads only the named class when the file declares two', () {
      const source = '''
class UserModel {
  final int id;
}

class AddressModel {
  final String street;
}
''';
      expect(ModelFieldParser.parse(source, 'UserModel').map((f) => f.name), [
        'id',
      ]);
      expect(
        ModelFieldParser.parse(source, 'AddressModel').map((f) => f.name),
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
        ModelFieldParser.parse(source, 'MissingModel').map((f) => f.name),
        ['id'],
      );
    });

    test('a class name is matched whole, not as a prefix', () {
      const source = '''
class UserModelDetails {
  final String detail;
}

class UserModel {
  final int id;
}
''';
      expect(ModelFieldParser.parse(source, 'UserModel').map((f) => f.name), [
        'id',
      ]);
    });

    test('a brace inside a string does not end the class body', () {
      const source = r'''
class TemplateModel {
  final String pattern;

  String render() => '{ $pattern }';

  final int version;
}
''';
      expect(
        ModelFieldParser.parse(source, 'TemplateModel').map((f) => f.name),
        ['pattern', 'version'],
      );
    });

    test('a brace inside a comment does not end the class body', () {
      const source = '''
class NoteModel {
  final String body;

  // closes with }
  /* and { here too */

  final int order;
}
''';
      expect(ModelFieldParser.parse(source, 'NoteModel').map((f) => f.name), [
        'body',
        'order',
      ]);
    });

    test('reads a class that extends another', () {
      const source = '''
class UserModel extends BaseModel {
  final String token;
}
''';
      expect(ModelFieldParser.parse(source, 'UserModel').map((f) => f.name), [
        'token',
      ]);
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
        source.substring(range.start, range.end),
        contains('final int a;'),
      );
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
      final fields = ModelFieldParser.parse(_userModel, 'UserModel');
      final factory = ModelFieldParser.buildEmptyFactory('UserModel', fields);

      expect(factory, contains('id: 0,'));
      expect(factory, contains('meta: const {},'));
      expect(factory, contains('tags: const [],'));
      expect(factory, contains('nickname: null,'));
    });

    test('a fieldless class gets a bare factory', () {
      expect(
        ModelFieldParser.buildEmptyFactory('EmptyModel', const []),
        contains('factory EmptyModel.empty() => EmptyModel();'),
      );
    });
  });

  group('freezed classes', () {
    const workModel = '''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'work_model.freezed.dart';

@freezed
abstract class WorkModel with _\$WorkModel {
  const factory WorkModel({
    required String id,
    /// When the work runs.
    required DatasModel datas,
    MoradaModel? morada,
    required List<UtilizadorModel> utilizadores,
    List<AnexoModel>? anexos,
    @Default(false) bool arquivado,
    required Map<String, dynamic> extras,
  }) = _WorkModel;

  factory WorkModel.empty() => const WorkModel(id: '');
}
''';

    final fields = ModelFieldParser.parse(workModel, 'WorkModel');
    ModelField field(String name) => fields.firstWhere((f) => f.name == name);

    test('reads the fields off the redirecting factory', () {
      // A freezed class declares no fields at all — the parameters are the
      // field list, and the `= _WorkModel;` redirect is what tells that
      // factory from `empty`.
      expect(fields.map((f) => f.name), [
        'id',
        'datas',
        'morada',
        'utilizadores',
        'anexos',
        'arquivado',
        'extras',
      ]);
      expect(field('extras').type, 'Map<String, dynamic>');
    });

    test('a doc comment on a parameter is not part of its type', () {
      expect(field('datas').type, 'DatasModel');
    });

    test('keeps @Default, and the field it makes optional', () {
      expect(field('arquivado').annotations, ['@Default(false)']);
      expect(field('arquivado').isRequired, isFalse);
      expect(field('id').isRequired, isTrue);
      expect(field('arquivado').asParameter, '@Default(false) bool arquivado');
    });
  });
}
