/// Parses a Dart model file and builds an `.empty()` factory.
class ModelFieldParser {
  /// Extracts named constructor parameters from a model class.
  ///
  /// Supports the common pattern:
  ///   const ClassName({
  ///     required this.fieldName,         // required typed field
  ///     this.nullableField,              // optional / nullable
  ///   });
  static List<ModelField> parse(String source, String className) {
    final fields = <ModelField>[];

    // Look for: [Type] [name];
    // Exclude things like 'factory' or keywords
    final fieldPattern = RegExp(
      r'^\s+(?:final|late)?\s*(?<type>[a-zA-Z][\w<>?]+)\s+(?<name>\w+);',
      multiLine: true,
    );

    for (final match in fieldPattern.allMatches(source)) {
      final type = match.namedGroup('type');
      final name = match.namedGroup('name');

      // Ignore internal or static members if necessary
      if (name != null && type != null && !name.contains('factory')) {
        fields.add(ModelField(name: name, type: type));
      }
    }
    return fields;
  }

  /// Builds the `.empty()` factory string to inject.
  static String buildEmptyFactory(String className, List<ModelField> fields) {
    if (fields.isEmpty) {
      return '\n  factory $className.empty() => $className();\n';
    }

    final args =
        fields.map((f) => '    ${f.name}: ${_defaultFor(f)},').join('\n');
    return '''

  factory $className.empty() => $className(
$args
  );
''';
  }

  /// Builds the `copyWith` method string to inject.
  static String buildCopyWith(String className, List<ModelField> fields) {
    if (fields.isEmpty) {
      return '\n  $className copyWith() => $className();\n';
    }

    final params =
        fields.map((f) => '    ${_nullableTypeFor(f)} ${f.name},').join('\n');
    final args = fields
        .map((f) => '      ${f.name}: ${f.name} ?? this.${f.name},')
        .join('\n');
    return '''

  $className copyWith({
$params
  }) {
    return $className(
$args
    );
  }
''';
  }

  /// Builds the `==` / `hashCode` overrides string to inject.
  ///
  /// Equality is keyed on `id` when the class declares one, otherwise on
  /// every parsed field.
  static String buildEquality(String className, List<ModelField> fields) {
    final hasId = fields.any((f) => f.name == 'id');
    final keys = hasId
        ? const ['id']
        : fields.map((f) => f.name).toList(growable: false);

    if (keys.isEmpty) {
      return '''

  @override
  bool operator ==(Object other) => other is $className;

  @override
  int get hashCode => runtimeType.hashCode;
''';
    }

    final comparisons =
        keys.map((k) => 'other.$k == $k').join(' &&\n          ');
    final hash = keys.length == 1
        ? '${keys.first}.hashCode'
        : 'Object.hash(\n        ${keys.join(',\n        ')},\n      )';

    return '''

  @override
  bool operator ==(Object other) =>
      other is $className && $comparisons;

  @override
  int get hashCode => $hash;
''';
  }

  static String _nullableTypeFor(ModelField f) {
    final t = (f.type ?? 'dynamic').trim();
    if (t == 'dynamic' || t.endsWith('?')) return t;
    return '$t?';
  }

  static String _defaultFor(ModelField f) {
    final t = (f.type ?? '').replaceAll(' ', '');

    if (t == 'dynamic') return 'null';
    if (t.endsWith('?')) return 'null';

    const defaults = <String, String>{
      'String': "''",
      'int': '0',
      'double': '0.0',
      'num': '0',
      'bool': 'false',
      'DateTime': 'DateTime.now()',
    };

    if (defaults.containsKey(t)) return defaults[t]!;
    if (t.startsWith('List')) return 'const []';
    if (t.startsWith('Set')) return 'const {}';
    if (t.startsWith('Map')) return 'const {}';

    // Fallback for custom objects
    return '$t.empty()';
  }
}

/// A single constructor field extracted from a model/entity class.
class ModelField {
  /// Creates a parsed field with its declared [name] and optional [type].
  const ModelField({required this.name, this.type});

  /// The field name as declared in the class.
  final String name;

  /// The declared Dart type, if one was found.
  final String? type;
}
