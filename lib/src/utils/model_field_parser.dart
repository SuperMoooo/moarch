/// Parses a Dart model file and builds an `.empty()` factory.
class ModelFieldParser {
  /// Locates the body of `class [className]` in [source].
  ///
  /// Returns the index just past its opening brace and the index of the
  /// matching closing brace, or null when the class isn't declared here or its
  /// braces don't balance.
  ///
  /// Callers use it to stay inside the one class they mean. An entity file is
  /// free to declare a second class, and without a range the fields of one end
  /// up in the other's `copyWith` — and a member appended at the file's last
  /// brace lands on whichever class happens to be written last.
  static ({int start, int end})? classBody(String source, String className) {
    final header = RegExp(
      r'\bclass\s+' + RegExp.escape(className) + r'\b[^{;]*\{',
    ).firstMatch(source);
    if (header == null) return null;

    final start = header.end;
    var depth = 1;
    var i = start;

    while (i < source.length) {
      final char = source[i];

      // Braces inside a comment or a string literal aren't structure.
      if (char == '/' && i + 1 < source.length) {
        final next = source[i + 1];
        if (next == '/') {
          final end = source.indexOf('\n', i);
          i = end == -1 ? source.length : end;
          continue;
        }
        if (next == '*') {
          final end = source.indexOf('*/', i + 2);
          i = end == -1 ? source.length : end + 2;
          continue;
        }
      }
      if (char == "'" || char == '"') {
        i = _skipString(source, i);
        continue;
      }

      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) return (start: start, end: i);
      }
      i++;
    }

    // Unbalanced — say so rather than hand back a range that isn't the class.
    return null;
  }

  /// Extracts the fields a generated member has to cover from a model class.
  ///
  /// Reads the field declarations inside [className]'s body — the entity
  /// convention is one `final` field per named constructor parameter — and
  /// falls back to the whole file when the class isn't found, so a class named
  /// differently from its file still parses as it did before.
  ///
  /// Supports the common pattern:
  ///   const ClassName({
  ///     required this.fieldName,         // required typed field
  ///     this.nullableField,              // optional / nullable
  ///   });
  static List<ModelField> parse(String source, String className) {
    final range = classBody(source, className);
    final scope =
        range == null ? source : source.substring(range.start, range.end);

    final fields = <ModelField>[];
    for (final match in _fieldPattern.allMatches(scope)) {
      final type = match.namedGroup('type')!.trim();
      final name = match.namedGroup('name')!;

      // A private field is never a named constructor parameter, so putting it
      // in a `copyWith` signature would not compile.
      if (name.startsWith('_')) continue;
      if (!_isDeclaredType(type)) continue;

      fields.add(ModelField(name: name, type: type));
    }
    return fields;
  }

  /// Matches `[modifiers] Type name;` on one line.
  ///
  /// The type is deliberately loose — anything up to the last identifier
  /// before the semicolon — because a declared type can carry commas and
  /// spaces (`Map<String, dynamic>`) that a character class would drop the
  /// field over. [_isDeclaredType] is what tells a type from a statement.
  /// Nothing here may cross a newline: a type allowed to run over one would
  /// swallow the declaration below it whole.
  static final RegExp _fieldPattern = RegExp(
    r'^[ \t]*(?!static\b)(?:(?:final|late|covariant)[ \t]+)*'
    r'(?<type>[A-Za-z_$][^;=\r\n]*?)[ \t]+(?<name>[a-zA-Z_$][\w$]*)[ \t]*;',
    multiLine: true,
  );

  /// Statement heads that a `word word;` line matches just as well as a field
  /// declaration does — `return value;` is not a field of type `return`.
  static const Set<String> _statementKeywords = {
    'return',
    'throw',
    'rethrow',
    'await',
    'yield',
    'assert',
    'break',
    'continue',
    'new',
    'var',
    'super',
    'this',
    'part',
    'import',
    'export',
  };

  /// Whether [type] reads as a declared Dart type rather than the first half
  /// of a statement or of another member.
  ///
  /// Type arguments and parameter lists are stripped innermost-first, which
  /// leaves a single dotted identifier for a real type (`Map<String, int>` →
  /// `Map`) and two bare words for the things that only look like one
  /// (`String get name;` → `String get`).
  static bool _isDeclaredType(String type) {
    var core = type;
    final innermost = RegExp(r'<[^<>]*>|\([^()]*\)');
    while (innermost.hasMatch(core)) {
      core = core.replaceAll(innermost, '');
    }

    final words = core.trim().split(RegExp(r'\s+'));
    // `void Function(int)? cb;` reduces to `void Function?` — the one two-word
    // type there is.
    if (words.length == 2 && words.last.replaceAll('?', '') == 'Function') {
      return _isTypeName(words.first);
    }
    return words.length == 1 && _isTypeName(words.first);
  }

  static bool _isTypeName(String word) {
    final name = word.replaceAll('?', '');
    if (_statementKeywords.contains(name)) return false;
    return RegExp(r'^[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)?$').hasMatch(name);
  }

  /// Returns the index just past the string literal starting at [start].
  static int _skipString(String source, int start) {
    final quote = source[start];
    final isTriple = source.startsWith(quote * 3, start);
    final closing = isTriple ? quote * 3 : quote;
    final isRaw = start > 0 && source[start - 1] == 'r';

    var i = start + closing.length;
    while (i < source.length) {
      if (!isRaw && source[i] == r'\') {
        i += 2;
        continue;
      }
      if (source.startsWith(closing, i)) return i + closing.length;
      i++;
    }
    return source.length;
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
