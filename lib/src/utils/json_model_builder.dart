import 'model_field_parser.dart';
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

  /// The entity source: the same freezed class the plain template writes,
  /// with the inferred fields in place of the TODOs.
  ///
  /// No JSON on it — parsing belongs to the model. Equality is not written
  /// here at all: freezed derives it from the whole field list, which is the
  /// point of moving to it. An `id`-keyed `==` made every draft of a create
  /// form compare equal, and a state holder that drops an equal state then
  /// dropped every keystroke after the first.
  static String entitySource(String name, String cls, List<JsonField> fields) {
    final params =
        fields.map((f) => '    required ${f.type} ${f.name},').join('\n');
    final empty = ModelFieldParser.buildEmptyFactory(
      '${cls}Entity',
      fields.map(_asModelField).toList(growable: false),
    ).trimRight();

    return '''
import 'package:freezed_annotation/freezed_annotation.dart';

part '${name}_entity.freezed.dart';

/// What the app reasons about, with no idea where it came from.
///
/// Run `fvm dart run build_runner build --delete-conflicting-outputs` after
/// editing this file.
@freezed
abstract class ${cls}Entity with _\$${cls}Entity {
  const factory ${cls}Entity({
$params
  }) = _${cls}Entity;
$empty
}
''';
  }

  /// The model source inferred from a JSON sample.
  ///
  /// json_serializable writes `fromJson` and `toJson`; a key that differs from
  /// the Dart name is stated once as a `@JsonKey(name: …)` rather than twice
  /// as hand-written parse and write expressions.
  ///
  /// [useFirestore] and [isDocumentRoot] mean what they do in
  /// [modelSourceFor]. Pass [withDocumentId]'s result as [fields] for a
  /// document root — an exported document usually has no `id` in its payload
  /// at all, because the id is the document's name.
  static String modelSource(
    String name,
    String cls,
    List<JsonField> fields, {
    bool useFirestore = false,
    bool isDocumentRoot = false,
  }) =>
      modelSourceFor(
        name,
        cls,
        fields.map(_asModelField).toList(growable: false),
        useFirestore: useFirestore,
        isDocumentRoot: isDocumentRoot,
      );

  /// [fields] with the `String id` a Firestore document root needs.
  ///
  /// A document's id is its name rather than one of its fields, so a payload
  /// exported from one usually does not carry it — and where a sample does,
  /// the value cannot be trusted to be the right type: `doc.id` is always a
  /// String, so an `id` inferred as `int` would make `fromDoc` throw on the
  /// very first read.
  ///
  /// Returns the list unchanged when it already declares a `String id`.
  static List<JsonField> withDocumentId(List<JsonField> fields) {
    const id = JsonField(jsonKey: 'id', name: 'id', type: 'String');
    final existing = fields.indexWhere((f) => f.name == 'id');

    if (existing == -1) return [id, ...fields];
    if (fields[existing].type == 'String') return fields;
    return [
      for (var i = 0; i < fields.length; i++)
        if (i == existing) id else fields[i],
    ];
  }

  /// The model source for fields read off an entity that already exists —
  /// what `moarch create model … --from-entity` writes.
  ///
  /// [useFirestore] says the payload is a Firestore document rather than a
  /// REST body, which is what decides how a `DateTime` is stored.
  ///
  /// [isDocumentRoot] adds the document plumbing on top: `fromDoc`, and an
  /// `id` kept out of `toJson` because the document is already keyed by it.
  /// It is asked for rather than guessed — a nested value object can carry an
  /// `id` of its own and still be a map inside someone else's document, and
  /// guessing wrong writes a model whose `fromJson` demands a key its own
  /// `toJson` never wrote.
  static String modelSourceFor(
    String name,
    String cls,
    List<ModelField> fields, {
    bool useFirestore = false,
    bool isDocumentRoot = false,
  }) {
    final asDocument =
        useFirestore && isDocumentRoot && fields.any((f) => f.name == 'id');
    // Only a Firestore project has a converter to point at — a REST payload
    // carries an ISO string, which json_serializable already reads and writes.
    bool convertsDate(ModelField f) => useFirestore && _isDate(f.type);
    final dates = fields.any(convertsDate);

    final params = fields.map((f) {
      final prefix = [
        // Only on the id of a document, never on a nested value object's:
        // Firestore keys the document by its own name, so a copy of it in the
        // body is stale the moment `add()` assigns a different one.
        if (asDocument && f.name == 'id') '@JsonKey(includeToJson: false)',
        // Without this json_serializable writes the date as an ISO string,
        // which Firestore sorts and ranges as text.
        if (convertsDate(f))
          (f.type ?? '').trim().endsWith('?')
              ? '@NullableTimestampConverter()'
              : '@TimestampConverter()',
      ].join(' ');
      return '    ${prefix.isEmpty ? '' : '$prefix '}${f.asModelParameter},';
    }).join('\n');

    final fromEntity = fields
        .map((f) => '    ${f.name}: ${ModelFieldParser.fromEntityValue(f)},')
        .join('\n');
    final toEntity = fields
        .map((f) => '    ${f.name}: ${ModelFieldParser.toEntityValue(f)},')
        .join('\n');

    final imports = [
      if (asDocument) "import 'package:cloud_firestore/cloud_firestore.dart';",
      "import 'package:freezed_annotation/freezed_annotation.dart';",
      '',
      if (dates) "import '../../../../core/network/timestamp_converter.dart';",
      "import '../../domain/entities/${name}_entity.dart';",
      // A nested field holds the *model* of that entity, which lives beside
      // this file.
      ..._nestedModelImports(fields, self: '${name}_model.dart'),
    ].join('\n');

    final fromDoc = asDocument
        ? '''

  /// The id lives on the document, so it is folded into the payload before
  /// parsing rather than read out of it.
  factory ${cls}Model.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ${cls}Model.fromJson({...?doc.data(), 'id': doc.id});
'''
        : '';

    return '''
$imports

part '${name}_model.freezed.dart';
part '${name}_model.g.dart';

/// The wire shape, and the only layer that knows it.
///
/// It does not extend the entity — freezed generates the concrete class, so
/// there is no constructor left to inherit. The fields are declared again and
/// mapped explicitly below.
///
/// Run `fvm dart run build_runner build --delete-conflicting-outputs` after
/// editing this file.
@freezed
abstract class ${cls}Model with _\$${cls}Model {
  /// Freezed needs a private constructor before a class may declare members
  /// of its own — [toEntity] below is one.
  const ${cls}Model._();

  const factory ${cls}Model({
$params
  }) = _${cls}Model;

  factory ${cls}Model.fromJson(Map<String, dynamic> json) =>
      _\$${cls}ModelFromJson(json);
$fromDoc
  factory ${cls}Model.fromEntity(${cls}Entity entity) => ${cls}Model(
$fromEntity
  );

  ${cls}Entity toEntity() => ${cls}Entity(
$toEntity
  );
}
''';
  }

  /// The sibling imports a model needs for the entities its fields hold.
  ///
  /// Sorted and de-duplicated, and never the file being written — a type that
  /// refers to itself would otherwise import its own file.
  static List<String> _nestedModelImports(
    List<ModelField> fields, {
    required String self,
  }) {
    final files = <String>{};
    for (final field in fields) {
      final modelType = field.modelType;
      if (modelType == (field.type ?? '')) continue;

      for (final match
          in RegExp(r'\b([A-Z][\w$]*)Model\b').allMatches(modelType)) {
        final file = '${StringUtils.toSnakeCase(match.group(1)!)}_model.dart';
        if (file != self) files.add(file);
      }
    }
    return (files.toList()..sort())
        .map((file) => "import './$file';")
        .toList(growable: false);
  }

  /// Whether [type] is a `DateTime`, nullable or not — the one type Firestore
  /// and json_serializable disagree about.
  static bool _isDate(String? type) {
    final trimmed = (type ?? '').trim();
    return trimmed == 'DateTime' || trimmed == 'DateTime?';
  }

  /// A field inferred from JSON, as the shared model builder wants it.
  ///
  /// The original key travels as a `@JsonKey` annotation rather than as parse
  /// and write expressions, so json_serializable owns both directions.
  static ModelField _asModelField(JsonField f) => ModelField(
        name: f.name,
        type: f.type,
        annotations:
            f.jsonKey == f.name ? const [] : ["@JsonKey(name: '${f.jsonKey}')"],
      );
}
