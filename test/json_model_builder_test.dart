import 'dart:convert';

import 'package:moarch/src/utils/json_model_builder.dart';
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

    test('entity declares the fields and keys equality on id', () {
      final source = JsonModelBuilder.entitySource('order', 'Order', fields);

      expect(source, contains('final DateTime createdAt;'));
      expect(source, contains('final List<String> tags;'));
      expect(source, contains('other is OrderEntity && other.id == id;'));
      expect(source, contains('int get hashCode => id.hashCode;'));
    });

    test('without an id, equality covers every field', () {
      final noId =
          JsonModelBuilder.fieldsFrom(jsonDecode('{"a": 1, "b": "x"}'))!;
      final source = JsonModelBuilder.entitySource('thing', 'Thing', noId);

      expect(source, contains('other.a == a'));
      expect(source, contains('other.b == b'));
      expect(source, contains('Object.hash('));
    });

    test('model round-trips each field through its original JSON key', () {
      final source = JsonModelBuilder.modelSource('order', 'Order', fields);

      expect(source, contains("customerName: json['customer_name'] as String"));
      expect(source, contains("'customer_name': customerName,"));
      expect(source,
          contains("createdAt: DateTime.parse(json['created_at'] as String)"));
      expect(source, contains("'created_at': createdAt.toIso8601String(),"));
    });

    test('a double parses through num — an int in the payload must not throw',
        () {
      final source = JsonModelBuilder.modelSource('order', 'Order', fields);

      expect(source, contains("total: (json['total'] as num).toDouble()"));
      expect(source, isNot(contains('as double')));
    });

    test('a typed list is cast, an untyped one is not', () {
      final source = JsonModelBuilder.modelSource('order', 'Order', fields);

      expect(source,
          contains("tags: (json['tags'] as List<dynamic>).cast<String>()"));
    });
  });
}
