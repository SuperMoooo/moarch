/// Parses a Dart model file and builds an `.empty()` factory.
class ModelFieldParser {
  /// Extracts named constructor parameters from a model class.
  ///
  /// Supports the common pattern:
  ///   const ClassName({
  ///     required this.fieldName,         // required typed field
  ///     this.nullableField,              // optional / nullable
  ///   });
  static List<_Field> parse(String source, String className) {
    final fields = <_Field>[];

    // Look for: [Type] [name];
    // Exclude things like 'factory' or keywords
    final fieldPattern = RegExp(
        r'^\s+(?:final|late)?\s*(?<type>[A-Z][\w<>?]+)\s+(?<name>\w+);',
        multiLine: true);

    for (final match in fieldPattern.allMatches(source)) {
      final type = match.namedGroup('type');
      final name = match.namedGroup('name');

      // Ignore internal or static members if necessary
      if (name != null && type != null && !name.contains('factory')) {
        fields.add(_Field(name: name, type: type));
      }
    }
    return fields;
  }

  /// Builds the `.empty()` factory string to inject.
  static String buildEmptyFactory(String className, List<_Field> fields) {
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

  static String _defaultFor(_Field f) {
    final t = (f.type ?? '').replaceAll(' ', '');

    // Nullable — always null
    if (t.endsWith('?')) return 'null';

    // Common scalar types
    const defaults = <String, String>{
      'String': "''",
      'int': '0',
      'double': '0.0',
      'num': '0',
      'bool': 'false',
      'DateTime': 'DateTime(0)',
    };
    if (defaults.containsKey(t)) return defaults[t]!;

    // List / Set / Map literals
    if (t.startsWith('List')) return 'const []';
    if (t.startsWith('Set')) return 'const {}';
    if (t.startsWith('Map')) return 'const {}';

    // Unknown / custom type — call its own .empty() by convention
    if (t.isNotEmpty) return '$t.empty()';

    return 'null';
  }
}

class _Field {
  const _Field({required this.name, this.type});
  final String name;
  final String? type;
}
