import 'string_utils.dart';

/// One field inferred from a JSON sample.
class JsonField {
  /// Creates an inferred field.
  const JsonField({
    required this.jsonKey,
    required this.name,
    required this.type,
  });

  /// The key as it appears in the JSON (`created_at`).
  final String jsonKey;

  /// The Dart field name (`createdAt`).
  final String name;

  /// The inferred Dart type (`DateTime`, `List<String>`, …).
  final String type;
}

/// Infers fields from a JSON sample and builds the entity + model sources
/// `moarch create model --from-json` writes.
///
/// The sample is a single payload the API actually returns — inference reads
/// the value each key holds: numbers and booleans map directly, an ISO-dated
/// string becomes a `DateTime`, a homogeneous list keeps its element type,
/// and a `null` can only come out as `dynamic` because a null carries no type.
abstract final class JsonModelBuilder {
  /// Builds the field list for [decoded], the result of `jsonDecode`.
  ///
  /// A top-level list is sampled at its first element, which is the common
  /// shape of a list endpoint's response. Returns null when there is no
  /// object to read fields from.
  static List<JsonField>? fieldsFrom(Object? decoded) {
    var sample = decoded;
    if (sample is List) {
      if (sample.isEmpty) return null;
      sample = sample.first;
    }
    if (sample is! Map) return null;

    final fields = <JsonField>[];
    final taken = <String>{};
    sample.forEach((key, value) {
      final jsonKey = '$key';
      var name = StringUtils.toCamelCase(jsonKey);
      if (name.isEmpty || RegExp(r'^[0-9]').hasMatch(name)) {
        name = 'field$name';
      }
      // Two keys that collapse to the same Dart name (`a_b` and `aB`) would
      // otherwise generate a duplicate field.
      if (!taken.add(name)) return;
      fields.add(JsonField(jsonKey: jsonKey, name: name, type: _typeOf(value)));
    });
    return fields.isEmpty ? null : fields;
  }

  static String _typeOf(Object? value) {
    if (value == null) return 'dynamic';
    if (value is bool) return 'bool';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is String) return _isIsoDate(value) ? 'DateTime' : 'String';
    if (value is Map) return 'Map<String, dynamic>';
    if (value is List) {
      if (value.isEmpty) return 'List<dynamic>';
      final elementTypes = value.map(_typeOf).toSet();
      if (elementTypes.length != 1) return 'List<dynamic>';
      final element = elementTypes.first;
      // A list of dates stays List<String>: a cast can't parse, and a field
      // few APIs use doesn't earn a mapped loop in generated code.
      return element == 'DateTime' || element == 'dynamic'
          ? 'List<dynamic>'
          : 'List<$element>';
    }
    return 'dynamic';
  }

  /// Whether [value] reads as an ISO-8601 date rather than a string that
  /// happens to satisfy `DateTime.tryParse` — `20120227` is a real parse but
  /// almost always an id or a phone number.
  static bool _isIsoDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value) &&
      DateTime.tryParse(value) != null;

  /// The entity source: the same shape the plain template writes, with the
  /// inferred fields in place of the TODOs. Equality is keyed on `id` when
  /// the sample has one, otherwise on every field.
  static String entitySource(String name, String cls, List<JsonField> fields) {
    final params = fields.map((f) => '    required this.${f.name},').join('\n');
    final declarations =
        fields.map((f) => '  final ${f.type} ${f.name};').join('\n');

    final hasId = fields.any((f) => f.name == 'id');
    final keys = hasId
        ? const ['id']
        : fields.map((f) => f.name).toList(growable: false);
    final comparisons =
        keys.map((k) => 'other.$k == $k').join(' &&\n          ');
    final hash = keys.length == 1
        ? '${keys.first}.hashCode'
        : 'Object.hash(\n        ${keys.join(',\n        ')},\n      )';

    return '''
class ${cls}Entity {
  const ${cls}Entity({
$params
  });

$declarations

  // TODO: add copyWith if needed (moarch create entity-copys)

  @override
  bool operator ==(Object other) =>
      other is ${cls}Entity && $comparisons;

  @override
  int get hashCode => $hash;
}
''';
  }

  /// The model source: `fromJson` parses each field off its original JSON
  /// key, `toJson` writes it back under the same key.
  static String modelSource(String name, String cls, List<JsonField> fields) {
    final superParams =
        fields.map((f) => '    required super.${f.name},').join('\n');
    final fromJson = fields
        .map((f) => '      ${f.name}: ${_fromJsonExpression(f)},')
        .join('\n');
    final toJson = fields
        .map((f) => "      '${f.jsonKey}': ${_toJsonExpression(f)},")
        .join('\n');
    final fromEntity =
        fields.map((f) => '    ${f.name}: entity.${f.name},').join('\n');
    final toEntity =
        fields.map((f) => '        ${f.name}: ${f.name},').join('\n');

    return '''
import '../../domain/entities/${name}_entity.dart';

class ${cls}Model extends ${cls}Entity {
  const ${cls}Model({
$superParams
  });

  factory ${cls}Model.fromJson(Map<String, dynamic> json) {
    return ${cls}Model(
$fromJson
    );
  }

  Map<String, dynamic> toJson() {
    return {
$toJson
    };
  }

  factory ${cls}Model.fromEntity(${cls}Entity entity) => ${cls}Model(
$fromEntity
  );

  ${cls}Entity toEntity() =>
      ${cls}Entity(
$toEntity
      );
}
''';
  }

  static String _fromJsonExpression(JsonField f) {
    final key = "json['${f.jsonKey}']";
    return switch (f.type) {
      'dynamic' => key,
      'DateTime' => 'DateTime.parse($key as String)',
      // Ints decode as int, so `as double` throws on a whole number — go
      // through num for the one type that trips on it.
      'double' => '($key as num).toDouble()',
      'Map<String, dynamic>' => '$key as Map<String, dynamic>',
      _ when f.type.startsWith('List<') =>
        '($key as List<dynamic>)${f.type == 'List<dynamic>' ? '' : '.cast${f.type.substring(4)}()'}',
      _ => '$key as ${f.type}',
    };
  }

  static String _toJsonExpression(JsonField f) =>
      f.type == 'DateTime' ? '${f.name}.toIso8601String()' : f.name;
}
