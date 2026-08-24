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
  /// A freezed class declares nothing but its redirecting factory, so its
  /// parameter list *is* the field list and is read first. A hand-written
  /// class has one `final` field per named constructor parameter, which is
  /// what [_fieldPattern] reads when there is no factory to find.
  ///
  /// Falls back to the whole file when the class isn't found, so a class named
  /// differently from its file still parses as it did before.
  ///
  /// Supports both shapes:
  ///   const factory ClassName({           // freezed
  ///     required String id,
  ///     @Default(false) bool active,
  ///     DatasEntity? datas,
  ///   }) = _ClassName;
  ///
  ///   const ClassName({                   // hand-written
  ///     required this.fieldName,
  ///     this.nullableField,
  ///   });
  static List<ModelField> parse(String source, String className) {
    final range = classBody(source, className);
    final scope =
        range == null ? source : source.substring(range.start, range.end);

    final freezed = _freezedFields(scope, className);
    if (freezed != null) return freezed;

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

  /// The fields of [className]'s freezed redirecting factory, or null when
  /// [scope] holds no such factory.
  ///
  /// The redirect (`= _ClassName;`) is what tells that factory from the others
  /// a freezed class carries — `fromJson`, `empty`, `fromEntity` all have the
  /// same header and none of them describes the fields.
  static List<ModelField>? _freezedFields(String scope, String className) {
    final header = RegExp(
      r'factory\s+' + RegExp.escape(className) + r'\s*\(',
    );

    for (final match in header.allMatches(scope)) {
      final open = match.end - 1;
      final close = _matchingBracket(scope, open);
      if (close == null) continue;

      final after = scope.substring(close + 1);
      if (!RegExp(r'^\s*=\s*[A-Za-z_$][\w$]*\s*;').hasMatch(after)) continue;

      final params = scope.substring(open + 1, close);
      // Named parameters only: freezed's own lint rejects positional ones, and
      // every generated member is written against names.
      final braceStart = params.indexOf('{');
      if (braceStart == -1) return const [];
      final braceEnd = _matchingBracket(params, braceStart);
      if (braceEnd == null) return const [];

      return _splitParams(params.substring(braceStart + 1, braceEnd))
          .map(_parseParam)
          .nonNulls
          .toList(growable: false);
    }
    return null;
  }

  /// The index of the bracket closing the one at [open], or null when the
  /// source runs out first. Skips over strings and comments.
  static int? _matchingBracket(String source, int open) {
    const pairs = {'(': ')', '{': '}', '[': ']', '<': '>'};
    final opening = source[open];
    final closing = pairs[opening]!;

    var depth = 0;
    var i = open;
    while (i < source.length) {
      final char = source[i];

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

      if (char == opening) depth++;
      if (char == closing) {
        depth--;
        if (depth == 0) return i;
      }
      i++;
    }
    return null;
  }

  /// Splits a parameter list on the commas that separate parameters, leaving
  /// the ones inside `Map<String, dynamic>` or `@Default(const [1, 2])` alone.
  static List<String> _splitParams(String params) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    var i = 0;

    while (i < params.length) {
      final char = params[i];

      if (char == "'" || char == '"') {
        final end = _skipString(params, i);
        buffer.write(params.substring(i, end));
        i = end;
        continue;
      }
      if ('([{<'.contains(char)) depth++;
      if (')]}>'.contains(char)) depth--;

      if (char == ',' && depth == 0) {
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
      i++;
    }
    parts.add(buffer.toString());

    return parts.where((part) => part.trim().isNotEmpty).toList();
  }

  /// Reads one freezed parameter — `@Default(false) bool active` — into a
  /// field, or null when it isn't one.
  static ModelField? _parseParam(String raw) {
    // A parameter may carry a doc comment of its own; it says nothing about
    // the field's shape.
    var text = raw
        .replaceAll(RegExp(r'^[ \t]*//.*$', multiLine: true), '')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .trim();

    final annotations = <String>[];
    final annotation = RegExp(r'^@[A-Za-z_$][\w$]*');
    while (true) {
      final match = annotation.firstMatch(text);
      if (match == null) break;
      var end = match.end;
      if (end < text.length && text[end] == '(') {
        final close = _matchingBracket(text, end);
        if (close == null) break;
        end = close + 1;
      }
      annotations.add(text.substring(match.start, end));
      text = text.substring(end).trim();
    }

    var isRequired = false;
    if (text.startsWith('required ')) {
      isRequired = true;
      text = text.substring('required '.length).trim();
    }

    // A default written the plain way rather than with `@Default` — freezed
    // rejects it, but the parser should not choke on one either.
    final equals = text.indexOf('=');
    if (equals != -1) text = text.substring(0, equals).trim();

    final split = RegExp(r'^(?<type>.+[>?\s])\s*(?<name>[a-zA-Z_$][\w$]*)$')
        .firstMatch(text);
    if (split == null) return null;

    final name = split.namedGroup('name')!;
    if (name.startsWith('_')) return null;

    return ModelField(
      name: name,
      type: split.namedGroup('type')!.trim(),
      isRequired: isRequired,
      annotations: annotations,
    );
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

  // ── Crossing the domain/data line ──────────────────────────────────────────
  //
  // A model used to `extend` its entity, which made mapping a nested field a
  // no-op: `datas: entity.datas` type-checked because a `DatasEntity` *was*
  // what the model held. Freezed generates the concrete class, so that
  // `extends` is gone and the model declares a `DatasModel` of its own —
  // which an entity no longer satisfies. Everything below is what replaces it:
  // one place that knows a field's type is another generated entity, and what
  // converting it costs in each direction.

  /// The suffix the templates give every domain type, and its data-layer twin.
  ///
  /// Nothing else in a generated project wears either one, which is what makes
  /// reading a type name enough to tell a nested entity from a plain value.
  static const String _entitySuffix = 'Entity';
  static const String _modelSuffix = 'Model';

  /// Whether [type] names one of the project's generated entities — on its own
  /// (`DatasEntity?`) or as the element of a list (`List<UtilizadorEntity>`).
  ///
  /// A field that answers false is carried across untouched: primitives,
  /// `DateTime`, enums and maps all mean the same thing in both layers.
  static bool holdsEntity(String? type) {
    if (type == null) return false;
    final core = _withoutNullability(type);
    final element = _listElement(core);
    return element != null
        ? holdsEntity(element)
        : core.endsWith(_entitySuffix);
  }

  /// The type a field declared as [type] on an entity has on its model.
  ///
  /// `DatasEntity` → `DatasModel`, `List<UtilizadorEntity>?` →
  /// `List<UtilizadorModel>?`. A type holding no entity is returned unchanged.
  static String modelTypeOf(String type) {
    final trimmed = type.trim();
    final nullable = trimmed.endsWith('?');
    final core = _withoutNullability(trimmed);
    final suffix = nullable ? '?' : '';

    final element = _listElement(core);
    if (element != null) {
      return 'List<${modelTypeOf(element)}>$suffix';
    }
    if (!core.endsWith(_entitySuffix)) return trimmed;

    final base = core.substring(0, core.length - _entitySuffix.length);
    return '$base$_modelSuffix$suffix';
  }

  /// The value a model's `fromEntity` passes for [field].
  ///
  /// `entity.titulo` for anything plain, `DatasModel.fromEntity(entity.datas)`
  /// for a nested entity, an element-wise `map` for a list of them, and a null
  /// guard rather than a `!` when the field can be absent.
  static String fromEntityValue(ModelField field) => _convert(
        field.type ?? 'dynamic',
        'entity.${field.name}',
        toModel: true,
      );

  /// The value a model's `toEntity` passes for [field] — the mirror of
  /// [fromEntityValue], reading the model's own fields.
  static String toEntityValue(ModelField field) => _convert(
        field.type ?? 'dynamic',
        field.name,
        toModel: false,
      );

  /// Converts [value], declared as [type], to the other layer.
  ///
  /// [promotable] says whether [value] is a local the compiler can promote to
  /// non-null — a `map` callback's parameter is, a field read off `entity` is
  /// not, and only the second needs a `!` after its null check.
  static String _convert(
    String type,
    String value, {
    required bool toModel,
    bool promotable = false,
  }) {
    final trimmed = type.trim();
    final nullable = trimmed.endsWith('?');
    final core = _withoutNullability(trimmed);

    final element = _listElement(core);
    if (element != null) {
      final inner = _convert(element, 'e', toModel: toModel, promotable: true);
      if (inner == 'e') return value;

      // `XModel.fromEntity(e)` is just the constructor applied to each
      // element, so hand `map` the tear-off rather than a wrapper.
      final tearOff = RegExp(r'^([\w$.]+)\(e\)$').firstMatch(inner);
      final mapper = tearOff != null ? tearOff.group(1)! : '(e) => $inner';
      return '$value${nullable ? '?' : ''}.map($mapper).toList()';
    }

    if (!core.endsWith(_entitySuffix)) return value;

    if (!toModel) {
      return nullable ? '$value?.toEntity()' : '$value.toEntity()';
    }

    final constructor = '${modelTypeOf(core)}.fromEntity';
    if (!nullable) return '$constructor($value)';
    return '$value == null '
        '? null '
        ': $constructor($value${promotable ? '' : '!'})';
  }

  static String _withoutNullability(String type) {
    final trimmed = type.trim();
    return trimmed.endsWith('?')
        ? trimmed.substring(0, trimmed.length - 1).trim()
        : trimmed;
  }

  /// The element type of a `List<...>`, or null for anything else.
  static String? _listElement(String type) =>
      RegExp(r'^List\s*<(.+)>$', dotAll: true).firstMatch(type)?.group(1);

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
  const ModelField({
    required this.name,
    this.type,
    this.isRequired = true,
    this.annotations = const [],
  });

  /// The field name as declared in the class.
  final String name;

  /// The declared Dart type, if one was found.
  final String? type;

  /// Whether the parameter was marked `required`.
  ///
  /// A freezed field carrying `@Default(...)` is not, and copying it onto the
  /// model as `required` would reject the very call the default exists for.
  final bool isRequired;

  /// The annotations written in front of the parameter, source order kept —
  /// `@Default(false)`, `@JsonKey(name: 'created_at')`.
  ///
  /// Carried so a model generated from an entity keeps the entity's own
  /// defaults instead of turning every field into a required one.
  final List<String> annotations;

  /// The parameter as it is written in a freezed factory, with [type]
  /// translated to the data layer's twin — see [ModelFieldParser.modelTypeOf].
  String get asModelParameter {
    final prefix = annotations.isEmpty ? '' : '${annotations.join(' ')} ';
    final declared = modelType;
    return '$prefix${isRequired ? 'required ' : ''}$declared $name';
  }

  /// This field's type on the model side.
  String get modelType => ModelFieldParser.modelTypeOf(type ?? 'dynamic');
}
