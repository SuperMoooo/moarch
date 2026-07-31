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

  group('buildCopyWith', () {
    test('takes and forwards every field', () {
      final fields = ModelFieldParser.parse(_userEntity, 'UserEntity');
      final copyWith = ModelFieldParser.buildCopyWith('UserEntity', fields);

      expect(copyWith, contains('Map<String, dynamic>? meta,'));
      expect(copyWith, contains('meta: meta ?? this.meta,'));
      expect(copyWith, contains('List<String>? tags,'));
    });

    test('does not double up the ? on a nullable field', () {
      final fields = ModelFieldParser.parse(_userEntity, 'UserEntity');
      final copyWith = ModelFieldParser.buildCopyWith('UserEntity', fields);
      expect(copyWith, contains('String? nickname,'));
      expect(copyWith, isNot(contains('String?? nickname')));
    });
  });

  group('buildEquality', () {
    test('keys on id when the class has one', () {
      final fields = ModelFieldParser.parse(_userEntity, 'UserEntity');
      final equality = ModelFieldParser.buildEquality('UserEntity', fields);

      expect(equality, contains('other.id == id'));
      expect(equality, contains('int get hashCode => id.hashCode;'));
      expect(equality, isNot(contains('other.meta')));
    });

    test('keys on every field when there is no id', () {
      const source = '''
class PointEntity {
  final int x;
  final int y;
}
''';
      final fields = ModelFieldParser.parse(source, 'PointEntity');
      final equality = ModelFieldParser.buildEquality('PointEntity', fields);

      expect(equality, contains('other.x == x'));
      expect(equality, contains('other.y == y'));
      expect(equality, contains('Object.hash('));
    });
  });
}
