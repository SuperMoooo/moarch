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
