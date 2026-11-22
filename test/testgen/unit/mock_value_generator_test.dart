import 'package:moarch/src/testgen/unit/utils/mock_value_generator.dart';
import 'package:test/test.dart';

void main() {
  group('MockValueGenerator.extractCustomType', () {
    test('unwraps Future and List down to the class to import', () {
      expect(
        MockValueGenerator.extractCustomType('Future<UserEntity>'),
        'UserEntity',
      );
      expect(
        MockValueGenerator.extractCustomType('Future<List<OrdersModel>>'),
        'OrdersModel',
      );
      expect(
        MockValueGenerator.extractCustomType('OrdersModel'),
        'OrdersModel',
      );
    });

    test('needs no import for primitives, void and nullable types', () {
      expect(MockValueGenerator.extractCustomType('Future<void>'), isNull);
      expect(MockValueGenerator.extractCustomType('Future<String>'), isNull);
      expect(MockValueGenerator.extractCustomType('Future<String?>'), isNull);
      expect(MockValueGenerator.extractCustomType('UserEntity?'), isNull);
    });

    // An offline-first repository's `watchAll()` returns this; it used to
    // come back whole and become `import '.../stream<list<orders_model>>.dart'`.
    test(
      'needs no import for a Stream, which is stubbed as Stream.empty()',
      () {
        expect(
          MockValueGenerator.extractCustomType('Stream<List<OrdersModel>>'),
          isNull,
        );
        expect(
          MockValueGenerator.extractCustomType('Stream<OrdersModel>'),
          isNull,
        );
      },
    );

    test('never returns a type that cannot be a file name', () {
      expect(
        MockValueGenerator.extractCustomType('Future<Either<Failure, User>>'),
        isNull,
      );
      expect(
        MockValueGenerator.extractCustomType('Future<(int, String)>'),
        isNull,
      );
    });
  });
}
