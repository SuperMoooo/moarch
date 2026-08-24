import 'dart:convert';

import 'package:moarch/src/utils/json_model_builder.dart';
import 'package:moarch/src/utils/model_field_parser.dart';
import 'package:test/test.dart';

void main() {
  group('fieldsFrom', () {
    test('infers every JSON scalar to its Dart type', () {
      final fields = JsonModelBuilder.fieldsFrom(jsonDecode('''
        {"id": 7, "name": "Ana", "total": 12.5, "paid": true,
         "created_at": "2026-08-01T10:30:00Z", "coupon": null}
      '''))!;

      final types = {for (final f in fields) f.name: f.type};
      expect(types, {
        'id': 'int',
        'name': 'String',
        'total': 'double',
        'paid': 'bool',
        'createdAt': 'DateTime',
        'coupon': 'dynamic',
      });
    });

    test('a date needs the dashed ISO shape — digit runs stay strings', () {
      final fields = JsonModelBuilder.fieldsFrom(jsonDecode('''
        {"phone": "20260801", "when": "2026-08-01"}
      '''))!;

      final types = {for (final f in fields) f.name: f.type};
      expect(types['phone'], 'String');
      expect(types['when'], 'DateTime');
    });

    test('homogeneous lists keep their element type, mixed ones do not', () {
      final fields = JsonModelBuilder.fieldsFrom(jsonDecode('''
        {"tags": ["a", "b"], "counts": [1, 2], "mixed": [1, "a"],
         "empty": [], "rows": [{"sku": "A1"}]}
      '''))!;

      final types = {for (final f in fields) f.name: f.type};
      expect(types['tags'], 'List<String>');
      expect(types['counts'], 'List<int>');
      expect(types['mixed'], 'List<dynamic>');
      expect(types['empty'], 'List<dynamic>');
      expect(types['rows'], 'List<Map<String, dynamic>>');
    });

    test('samples a top-level list at its first element', () {
      final fields =
          JsonModelBuilder.fieldsFrom(jsonDecode('[{"id": 1}, {"id": 2}]'));

      expect(fields, isNotNull);
      expect(fields!.single.name, 'id');
    });

    test('keeps the original key next to the camelCase name', () {
      final field = JsonModelBuilder.fieldsFrom(
        jsonDecode('{"customer_name": "Ana"}'),
      )!
          .single;

      expect(field.jsonKey, 'customer_name');
      expect(field.name, 'customerName');
    });

    test('has nothing to read from a scalar or an empty payload', () {
      expect(JsonModelBuilder.fieldsFrom(jsonDecode('42')), isNull);
      expect(JsonModelBuilder.fieldsFrom(jsonDecode('[]')), isNull);
      expect(JsonModelBuilder.fieldsFrom(jsonDecode('{}')), isNull);
    });
  });

  group('generated sources', () {
    final fields = JsonModelBuilder.fieldsFrom(jsonDecode('''
      {"id": 7, "customer_name": "Ana", "total": 12.5,
       "created_at": "2026-08-01T10:30:00Z", "tags": ["vip"]}
    '''))!;

    test('the entity is a freezed class with no JSON on it', () {
      final source = JsonModelBuilder.entitySource('order', 'Order', fields);

      expect(source, contains('@freezed'));
      expect(source, contains("part 'order_entity.freezed.dart';"));
      expect(
          source, contains('abstract class OrderEntity with _\$OrderEntity'));
      expect(source, contains('required DateTime createdAt,'));
      expect(source, contains('required List<String> tags,'));
      // domain/ never learns that JSON exists.
      expect(source, isNot(contains('json_annotation')));
      expect(source, isNot(contains('.g.dart')));
      expect(source, isNot(contains('fromJson')));
    });

    test('no hand-rolled equality survives, keyed on id or otherwise', () {
      // Freezed derives `==` from the whole field list. The old `id`-keyed
      // equality made every draft of a create form compare equal, and a state
      // holder that drops an equal state dropped every edit after the first.
      for (final source in [
        JsonModelBuilder.entitySource('order', 'Order', fields),
        JsonModelBuilder.modelSource('order', 'Order', fields),
        JsonModelBuilder.entitySource(
          'thing',
          'Thing',
          JsonModelBuilder.fieldsFrom(jsonDecode('{"a": 1, "b": "x"}'))!,
        ),
      ]) {
        expect(source, isNot(contains('operator ==')));
        expect(source, isNot(contains('get hashCode')));
        expect(source, isNot(contains('Object.hash(')));
      }
    });

    test('the entity keeps its .empty() — freezed writes no such thing', () {
      final source = JsonModelBuilder.entitySource('order', 'Order', fields);

      expect(source, contains('factory OrderEntity.empty()'));
      expect(source, contains('id: 0,'));
      expect(source, contains("customerName: '',"));
      expect(source, contains('tags: const [],'));
    });

    test('a key that differs from the field name is stated once', () {
      final source = JsonModelBuilder.modelSource('order', 'Order', fields);

      // json_serializable owns both directions, so the key is an annotation
      // rather than a parse expression and a write expression that can drift.
      expect(
          source,
          contains(
              "@JsonKey(name: 'customer_name') required String customerName,"));
      expect(
          source,
          contains(
              "@JsonKey(name: 'created_at') required DateTime createdAt,"));
      // A key that already matches earns no annotation.
      expect(source, contains('required int id,'));
      expect(source, isNot(contains("@JsonKey(name: 'id')")));
    });

    group('a sample from a Firestore document', () {
      // `id` is absent on purpose: a document's id is its name, so an exported
      // payload does not carry one.
      final sample = JsonModelBuilder.fieldsFrom(jsonDecode('''
        {"titulo": "Obra", "criado_em": "2026-08-01T10:30:00Z"}
      '''))!;

      test('gets the String id the sample could not carry', () {
        final withId = JsonModelBuilder.withDocumentId(sample);

        expect(withId.first.name, 'id');
        expect(withId.first.type, 'String');
        expect(withId.first.jsonKey, 'id');
        expect(withId.length, sample.length + 1);
      });

      test('retypes an id the sample got wrong', () {
        // `doc.id` is always a String, so an `id` inferred as int would make
        // fromDoc throw on the first read.
        final numeric =
            JsonModelBuilder.fieldsFrom(jsonDecode('{"id": 7, "a": "x"}'))!;
        final withId = JsonModelBuilder.withDocumentId(numeric);

        expect(withId.first.name, 'id');
        expect(withId.first.type, 'String');
        expect(withId.length, numeric.length);
      });

      test('leaves a sample that already has a String id alone', () {
        final ok =
            JsonModelBuilder.fieldsFrom(jsonDecode('{"id": "d1", "a": "x"}'))!;
        expect(JsonModelBuilder.withDocumentId(ok), same(ok));
      });

      test('comes out as a document, not a REST payload', () {
        final fields = JsonModelBuilder.withDocumentId(sample);
        final source = JsonModelBuilder.modelSource(
          'fatura',
          'Fatura',
          fields,
          useFirestore: true,
          isDocumentRoot: true,
        );

        expect(source,
            contains('@JsonKey(includeToJson: false) required String id,'));
        expect(source, contains("{...?doc.data(), 'id': doc.id}"));
        expect(source, contains('@TimestampConverter()'));
        // The entity carries the id too, or the mapping would not compile.
        expect(
          JsonModelBuilder.entitySource('fatura', 'Fatura', fields),
          contains('required String id,'),
        );
      });

      test('without --doc it is a nested value that still stores Timestamps',
          () {
        // A map inside a document is still inside a document, so its dates
        // belong on the wire the same way.
        final source = JsonModelBuilder.modelSource(
          'linha',
          'Linha',
          sample,
          useFirestore: true,
        );

        expect(source, isNot(contains('fromDoc')));
        expect(source, isNot(contains('includeToJson')));
        expect(source, contains('@TimestampConverter()'));
      });
    });

    test('a REST model leaves its dates to json_serializable', () {
      // The Timestamp converter is a Firestore translation and nothing else —
      // annotating a REST model with it would name a file the project has no
      // reason to hold.
      final source = JsonModelBuilder.modelSource('order', 'Order', fields);

      expect(source, isNot(contains('TimestampConverter')));
      expect(source, isNot(contains('timestamp_converter.dart')));
    });

    test('a Firestore model keeps its dates queryable', () {
      final source = JsonModelBuilder.modelSourceFor(
        'order',
        'Order',
        const [
          ModelField(name: 'id', type: 'String'),
          ModelField(name: 'placedAt', type: 'DateTime'),
          ModelField(
            name: 'shippedAt',
            type: 'DateTime?',
            isRequired: false,
          ),
        ],
        useFirestore: true,
        isDocumentRoot: true,
      );

      expect(source,
          contains('@TimestampConverter() required DateTime placedAt,'));
      expect(source,
          contains('@NullableTimestampConverter() DateTime? shippedAt,'));
      expect(
          source,
          contains(
              "import '../../../../core/network/timestamp_converter.dart';"));
      // The id is the document's name, so it is read back off the snapshot.
      expect(source,
          contains('@JsonKey(includeToJson: false) required String id,'));
      expect(source, contains("{...?doc.data(), 'id': doc.id}"));
    });

    test('a nested value object is not treated as a document', () {
      // Being a document root is asked for, not inferred from an `id`: a value
      // object nested in a document can carry one and still be a plain map.
      // Guessing wrong writes a model whose `fromJson` demands a key its own
      // `toJson` never wrote.
      final source = JsonModelBuilder.modelSourceFor(
        'utilizador',
        'Utilizador',
        const [
          ModelField(name: 'id', type: 'String'),
          ModelField(name: 'inicio', type: 'DateTime'),
        ],
        useFirestore: true,
      );

      expect(source, isNot(contains('fromDoc')));
      expect(source, isNot(contains('includeToJson')));
      // Its dates still belong on the wire as Timestamps — a nested map lives
      // inside a Firestore document just the same.
      expect(
          source, contains('@TimestampConverter() required DateTime inicio,'));
    });

    test('the model is freezed + json_serializable, and maps to the entity',
        () {
      final source = JsonModelBuilder.modelSource('order', 'Order', fields);

      expect(source, contains("part 'order_model.freezed.dart';"));
      expect(source, contains("part 'order_model.g.dart';"));
      // Required before a freezed class may declare toEntity().
      expect(source, contains('const OrderModel._();'));
      expect(source, contains('_\$OrderModelFromJson(json)'));
      expect(source, isNot(contains('extends OrderEntity')));
      expect(source,
          contains('factory OrderModel.fromEntity(OrderEntity entity)'));
      expect(source, contains('customerName: entity.customerName,'));
      expect(source, contains('OrderEntity toEntity()'));
      // json_serializable writes both directions; nothing is hand-parsed.
      expect(source, isNot(contains('as num).toDouble()')));
      expect(source, isNot(contains('.cast<String>()')));
      expect(source, isNot(contains('toIso8601String()')));
    });
  });
}
