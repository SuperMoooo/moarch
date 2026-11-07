import 'model_field_parser.dart';

/// One column of a feature's drift table, worked out from a model field.
class DriftColumn {
  /// Creates a column for the model field [name].
  const DriftColumn({
    required this.name,
    required this.dartType,
    required this.columnType,
    required this.builder,
    required this.nullable,
    this.converter,
  });

  /// The model field's name, which drift also uses as the column's getter.
  final String name;

  /// The field's Dart type without `?` — what a row hands the model.
  final String dartType;

  /// The drift column class: `IntColumn`, `TextColumn`…
  final String columnType;

  /// The column builder call, before `.nullable()` and the final `()`:
  /// `integer()`, `textEnum<Status>()`, `text().map(XRows.tagsConverter)`.
  final String builder;

  /// Whether the model field is nullable.
  final bool nullable;

  /// The static converter's initializer, for a column stored as JSON.
  final String? converter;

  /// The name of the static field on the table that holds [converter].
  String get converterField => '${name}Converter';
}

/// The columns of a model's table, or the fields that cannot be one.
class DriftTablePlan {
  /// Creates a plan.
  const DriftTablePlan({
    required this.columns,
    required this.unsupported,
    required this.idType,
  });

  /// One per model field, in the model's order.
  final List<DriftColumn> columns;

  /// `field: Type` for each field no column type fits. Non-empty means
  /// nothing should be written.
  final List<String> unsupported;

  /// The `id` field's type (`int` or `String`), or null when the model has no
  /// usable one.
  final String? idType;
}

/// Maps a freezed model's fields to the columns of a drift table whose rows
/// are that model (`@UseRowClass`).
///
/// Primitives and `DateTime` get their own column type and an enum a
/// `textEnum`. A nested model, or a `List` / `Map<String, …>` of primitives,
/// enums, dates or nested models, is stored as JSON text through
/// `TypeConverter.json2`. Anything else is reported, not guessed at, because a
/// wrong column only fails once build_runner or the app runs.
abstract final class DriftTableBuilder {
  /// The column that keeps a list in the order the API sent it. It is not a
  /// model field: drift leaves a column the row class lacks out of the row.
  static const String orderColumn = 'listOrder';

  static const _primitiveColumns = <String, (String, String)>{
    'int': ('IntColumn', 'integer()'),
    'double': ('RealColumn', 'real()'),
    'String': ('TextColumn', 'text()'),
    'bool': ('BoolColumn', 'boolean()'),
    'DateTime': ('DateTimeColumn', 'dateTime()'),
  };

  static const _jsonPrimitives = {'int', 'double', 'String', 'bool'};

  /// Plans the table for [fields]. [enums] holds every enum declared in the
  /// project, which is what tells `Status` (a `textEnum`) from `Address` (a
  /// nested model). [table] is the table class the converters live on.
  static DriftTablePlan plan(
    List<ModelField> fields, {
    required Set<String> enums,
    required String table,
  }) {
    final columns = <DriftColumn>[];
    final unsupported = <String>[];
    String? idType;

    for (final field in fields) {
      final raw = (field.type ?? 'dynamic').replaceAll(' ', '');
      final nullable = raw.endsWith('?');
      final type = nullable ? raw.substring(0, raw.length - 1) : raw;

      if (field.name == orderColumn) {
        unsupported.add(
          '${field.name}: $type (the table keeps the list order under this '
          'name; rename the field)',
        );
        continue;
      }

      if (field.name == 'id' &&
          !nullable &&
          (type == 'int' || type == 'String')) {
        idType = type;
      }

      final column = _column(field.name, type, nullable, enums, table);
      if (column == null) {
        unsupported.add('${field.name}: ${field.type}');
      } else {
        columns.add(column);
      }
    }

    return DriftTablePlan(
      columns: columns,
      unsupported: unsupported,
      idType: idType,
    );
  }

  static DriftColumn? _column(
    String name,
    String type,
    bool nullable,
    Set<String> enums,
    String table,
  ) {
    if (_primitiveColumns[type] case (final columnType, final builder)) {
      return DriftColumn(
        name: name,
        dartType: type,
        columnType: columnType,
        builder: builder,
        nullable: nullable,
      );
    }
    if (enums.contains(type)) {
      return DriftColumn(
        name: name,
        dartType: type,
        columnType: 'TextColumn',
        builder: 'textEnum<$type>()',
        nullable: nullable,
      );
    }

    final converter = _jsonConverter(type, enums);
    if (converter == null) return null;
    return DriftColumn(
      name: name,
      dartType: type,
      columnType: 'TextColumn',
      builder: 'text().map($table.${name}Converter)',
      nullable: nullable,
      converter: converter,
    );
  }

  /// The `TypeConverter.json2` initializer for [type], or null when [type] is
  /// not one JSON round-trips without help.
  static String? _jsonConverter(String type, Set<String> enums) {
    final list = RegExp(r'^List<(.+)>$').firstMatch(type);
    if (list != null) {
      final element = list.group(1)!;
      final read = _readElement(element, enums, 'e');
      if (read == null) return null;
      final write = _writeElement(element, enums, 'e');
      return 'TypeConverter.json2<$type>(\n'
          '    fromJson: (json) => [for (final e in json as List) $read],\n'
          '${write == null ? '' : '    toJson: (value) => [for (final e in value) $write],\n'}'
          '  )';
    }

    final map = RegExp(r'^Map<String,(.+)>$').firstMatch(type);
    if (map != null) {
      final value = map.group(1)!;
      final read = _readElement(value, enums, 'value');
      if (read == null) return null;
      final write = _writeElement(value, enums, 'value');
      return 'TypeConverter.json2<$type>(\n'
          '    fromJson: (json) => {\n'
          '      for (final MapEntry(:key, :value)\n'
          '          in (json as Map<String, Object?>).entries)\n'
          '        key: $read,\n'
          '    },\n'
          '${write == null ? '' : '    toJson: (map) => {\n'
                    '      for (final MapEntry(:key, :value) in map.entries) key: $write,\n'
                    '    },\n'}'
          '  )';
    }

    if (_isNestedModel(type, enums)) {
      return 'TypeConverter.json2<$type>(\n'
          '    fromJson: (json) => $type.fromJson(json as Map<String, Object?>),\n'
          '  )';
    }
    return null;
  }

  /// How one decoded JSON element [v] becomes a [type], or null when it
  /// cannot be read back.
  static String? _readElement(String type, Set<String> enums, String v) {
    switch (type) {
      case 'String' || 'bool' || 'int':
        return '$v as $type';
      case 'double':
        return '($v as num).toDouble()';
      case 'DateTime':
        return 'DateTime.parse($v as String)';
      case 'dynamic' || 'Object?':
        return v;
    }
    if (enums.contains(type)) return '$type.values.byName($v as String)';
    if (_isNestedModel(type, enums)) {
      return '$type.fromJson($v as Map<String, Object?>)';
    }
    return null;
  }

  /// How one [type] value [v] is written, or null when `jsonEncode` writes
  /// it as it is — primitives, and a nested model through its `toJson()`.
  static String? _writeElement(String type, Set<String> enums, String v) {
    if (type == 'DateTime') return '$v.toIso8601String()';
    if (enums.contains(type)) return '$v.name';
    return null;
  }

  /// A plain class name: what a nested freezed model looks like. Generics,
  /// `Set`, `Function` and the `dart:core` types without `fromJson` are not.
  static bool _isNestedModel(String type, Set<String> enums) {
    if (_jsonPrimitives.contains(type) || enums.contains(type)) return false;
    const notModels = {
      'dynamic',
      'Object',
      'num',
      'DateTime',
      'Duration',
      'Uri',
      'BigInt',
      'Function',
      'Set',
      'List',
      'Map',
      'Iterable',
    };
    if (notModels.contains(type)) return false;
    return RegExp(r'^[A-Z][A-Za-z0-9_]*$').hasMatch(type);
  }
}
