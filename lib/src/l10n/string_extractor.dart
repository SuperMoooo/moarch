import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// How a found string is read back once it is a translation key.
enum L10nAccessor {
  /// flutter_localizations: `AppLocalizations.of(context)!.key`.
  generated,

  /// easy_localization: `'key'.tr()`.
  easyLocalization,
}

/// A hard-coded UI string found in a file.
class FoundString {
  /// Creates a finding.
  const FoundString({
    required this.text,
    required this.offset,
    required this.length,
    required this.line,
    this.contextName,
    this.skipReason,
  });

  /// The string's value, quotes removed.
  final String text;

  /// Where the literal starts in the source, and its length.
  final int offset, length;

  /// 1-based line, for the report.
  final int line;

  /// The `BuildContext` in scope at the literal, when there is one.
  final String? contextName;

  /// Why it is reported rather than rewritten, or null when it can be.
  final String? skipReason;

  /// Whether the literal can be rewritten in place.
  bool get rewritable => skipReason == null;
}

/// One text edit: replace [length] characters at [offset].
class SourceEdit {
  /// Creates an edit.
  const SourceEdit(this.offset, this.length, this.replacement);

  /// Where it starts.
  final int offset;

  /// How much it replaces.
  final int length;

  /// What goes there.
  final String replacement;
}

/// Finds the user-facing string literals in a widget file and rewrites them
/// to translation keys.
///
/// The AST is parsed unresolved and read structurally (by source and by the
/// stable node types), like the test generator, so it holds across the
/// analyzer versions moarch supports.
abstract final class StringExtractor {
  /// Named arguments whose string is shown to the user.
  static const labelArguments = {
    'label',
    'labelText',
    'hintText',
    'helperText',
    'errorText',
    'title',
    'subtitle',
    'message',
    'tooltip',
    'semanticLabel',
    'semanticsLabel',
    'description',
    'placeholder',
    'confirmLabel',
    'cancelLabel',
    'emptyMessage',
    'buttonLabel',
  };

  /// Widgets whose first positional argument is the text they draw.
  static const textWidgets = {'Text', 'SelectableText'};

  /// Every UI string in [source].
  static List<FoundString> find(String source) {
    final unit = parseString(content: source, throwIfDiagnostics: false).unit;
    final visitor = _Visitor(unit);
    unit.accept(visitor);
    return visitor.found;
  }

  /// [source] with each rewritable finding in [keys] (finding offset → key)
  /// replaced by its accessor, the `const` that would no longer compile
  /// removed, and [import] added when it is not there yet.
  static String rewrite(
    String source,
    Map<int, String> keys, {
    required L10nAccessor accessor,
    required String import,
    bool nullableGetter = true,
    String className = 'AppLocalizations',
  }) {
    if (keys.isEmpty) return source;
    final unit = parseString(content: source, throwIfDiagnostics: false).unit;
    final edits = <SourceEdit>[];
    final constRemoved = <int>{};

    final literals = <SimpleStringLiteral>[];
    unit.accept(_LiteralCollector(literals));
    for (final literal in literals) {
      final key = keys[literal.offset];
      if (key == null) continue;
      final finding = _Visitor.inspect(literal, unit);
      if (finding == null || !finding.rewritable) continue;

      final replacement = switch (accessor) {
        L10nAccessor.generated =>
          '$className.of(${finding.contextName})${nullableGetter ? '!' : ''}.$key',
        L10nAccessor.easyLocalization => "'$key'.tr()",
      };
      edits.add(SourceEdit(literal.offset, literal.length, replacement));

      // A `const` around the literal no longer compiles once it reads a
      // runtime value: take it off every enclosing expression that has it.
      for (AstNode? node = literal.parent; node != null; node = node.parent) {
        if (node is! Expression) continue;
        final first = node.beginToken;
        if (first.lexeme != 'const' || !constRemoved.add(first.offset)) {
          continue;
        }
        var end = first.end;
        while (end < source.length &&
            (source[end] == ' ' || source[end] == '\n')) {
          end++;
        }
        edits.add(SourceEdit(first.offset, end - first.offset, ''));
      }
    }

    edits.sort((a, b) => b.offset.compareTo(a.offset));
    var out = source;
    for (final edit in edits) {
      out = out.replaceRange(edit.offset, edit.offset + edit.length, '');
      out =
          out.substring(0, edit.offset) +
          edit.replacement +
          out.substring(edit.offset);
    }
    return _addImport(out, import);
  }

  static String _addImport(String source, String import) {
    final line = "import '$import';";
    if (source.contains(line)) return source;
    final imports = RegExp(r'^import .*;$', multiLine: true).allMatches(source);
    if (imports.isEmpty) return '$line\n\n$source';
    final last = imports.last;
    return '${source.substring(0, last.end)}\n$line${source.substring(last.end)}';
  }
}

class _LiteralCollector extends GeneralizingAstVisitor<void> {
  _LiteralCollector(this.literals);

  final List<SimpleStringLiteral> literals;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    literals.add(node);
    super.visitSimpleStringLiteral(node);
  }
}

class _Visitor extends GeneralizingAstVisitor<void> {
  _Visitor(this.unit);

  final CompilationUnit unit;
  final found = <FoundString>[];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    final finding = inspect(node, unit);
    if (finding != null) found.add(finding);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    if (_uiSlot(node) != null && _hasLetters(node.toSource())) {
      found.add(
        FoundString(
          text: node.toSource(),
          offset: node.offset,
          length: node.length,
          line: unit.lineInfo.getLocation(node.offset).lineNumber,
          skipReason: 'interpolates a value — make it a placeholder by hand',
        ),
      );
    }
    super.visitStringInterpolation(node);
  }

  /// The finding for [literal], or null when it is not a UI string.
  static FoundString? inspect(
    SimpleStringLiteral literal,
    CompilationUnit unit,
  ) {
    if (_uiSlot(literal) == null) return null;
    final text = literal.value;
    if (!_hasLetters(text)) return null;
    // A lone lowercase identifier ('id', 'theme_mode') is a key, not copy.
    if (RegExp(r'^[a-z0-9_.]+$').hasMatch(text)) return null;

    String? skip;
    if (text.contains('{') || text.contains('}')) {
      skip = 'has braces, which are placeholders in a translation file';
    } else if (_inConstDeclaration(literal)) {
      skip = 'is in a const declaration, a default value or an annotation';
    }
    final contextName = _contextIn(literal);

    return FoundString(
      text: text,
      offset: literal.offset,
      length: literal.length,
      line: unit.lineInfo.getLocation(literal.offset).lineNumber,
      contextName: contextName,
      skipReason: skip,
    );
  }

  /// The slot a string sits in when it is shown to the user — the callee's
  /// name — or null.
  static String? _uiSlot(StringLiteral literal) {
    // The literal, or the node wrapping it in an argument list.
    AstNode child = literal;
    var parent = literal.parent;
    String? named;
    while (parent != null && parent is! ArgumentList) {
      final label = RegExp(r'^(\w+)\s*:').firstMatch(parent.toSource());
      if (label != null) named = label[1];
      // Only the argument itself may sit between the literal and the list:
      // `'a' + b`, a ternary or a method call on it are not a plain label.
      if (parent is Expression &&
          parent is! StringLiteral &&
          label == null &&
          parent.runtimeType.toString() != 'ArgumentImpl') {
        return null;
      }
      child = parent;
      parent = parent.parent;
    }
    if (parent is! ArgumentList) return null;

    final callee = _calleeName(parent.parent);
    if (callee == null || !RegExp(r'^[A-Z]').hasMatch(callee)) return null;

    if (named != null) {
      return StringExtractor.labelArguments.contains(named) ? callee : null;
    }
    final type = callee.split('.').first;
    if (!StringExtractor.textWidgets.contains(type)) return null;
    // The first positional argument.
    final first = parent.arguments.isEmpty ? null : parent.arguments.first;
    return first != null && first.offset == child.offset ? callee : null;
  }

  /// `Text`, `AppButton`, `Text.rich` — what the call builds, read off its
  /// source so the unresolved shape (method call or instance creation) does
  /// not matter.
  static String? _calleeName(AstNode? call) {
    if (call == null) return null;
    final source = call.toSource();
    final open = source.indexOf('(');
    if (open <= 0) return null;
    final head = source
        .substring(0, open)
        .replaceFirst(RegExp(r'^(const|new)\s+'), '')
        .trim();
    // `foo.bar.Baz` → `Baz`; a receiver (`logger.i`) has a lowercase start
    // and is turned away by the caller.
    final parts = head.split('.');
    if (parts.length >= 2 &&
        RegExp(r'^[A-Z]').hasMatch(parts[parts.length - 2])) {
      return '${parts[parts.length - 2]}.${parts.last}';
    }
    return parts.last.replaceAll(RegExp(r'<.*$'), '');
  }

  static bool _inConstDeclaration(AstNode node) {
    for (AstNode? n = node.parent; n != null; n = n.parent) {
      if (n is Annotation) return true;
      // A string inside a parameter can only be its default value. The
      // parameter classes changed in analyzer 13, so match the stable
      // supertype rather than `DefaultFormalParameter`.
      if (n is FormalParameter) return true;
      if (n is VariableDeclarationList && n.isConst) return true;
      final type = n.runtimeType.toString();
      if (type.contains('Pattern') || type.contains('SwitchCase')) return true;
      if (n is FunctionBody || n is ClassMember) break;
    }
    return false;
  }

  /// The name of the `BuildContext` in scope: a parameter of an enclosing
  /// function, or `context` inside a `State` subclass.
  static String? _contextIn(AstNode node) {
    for (AstNode? n = node.parent; n != null; n = n.parent) {
      FormalParameterList? params;
      if (n is FunctionExpression) params = n.parameters;
      if (n is MethodDeclaration) params = n.parameters;
      if (n is FunctionDeclaration) params = n.functionExpression.parameters;
      if (params != null) {
        for (final param in params.parameters) {
          final source = param.toSource();
          final match = RegExp(r'(\w+)\s*$').firstMatch(source);
          if (match == null) continue;
          if (source.contains('BuildContext') || match[1] == 'context') {
            return match[1];
          }
        }
      }
      if (n is MethodDeclaration && n.isStatic) return null;
      if (n.runtimeType.toString().contains('ClassDeclaration')) {
        final header = n.toSource().split('{').first;
        return RegExp(r'extends\s+State<').hasMatch(header) ? 'context' : null;
      }
    }
    return null;
  }

  static bool _hasLetters(String text) => RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(text);
}

/// Turns copy into translation keys: `Forgot password?` → `forgotPassword`.
abstract final class L10nKeys {
  static const _accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };

  /// A camelCase identifier from the first words of [text].
  static String fromText(String text) {
    var plain = text.toLowerCase();
    _accents.forEach((from, to) => plain = plain.replaceAll(from, to));
    final words = plain
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(5)
        .toList();
    if (words.isEmpty) return 'text';
    final key = [
      words.first,
      for (final w in words.skip(1)) w[0].toUpperCase() + w.substring(1),
    ].join();
    return RegExp(r'^[0-9]').hasMatch(key) ? 'text$key' : key;
  }

  /// The key for [text] given the keys [existing] already holds: the one
  /// that already has this text, or a fresh one that collides with none.
  static String assign(String text, Map<String, String> existing) {
    for (final entry in existing.entries) {
      if (entry.value == text) return entry.key;
    }
    final base = fromText(text);
    var key = base;
    var n = 2;
    while (existing.containsKey(key)) {
      key = '$base$n';
      n++;
    }
    return key;
  }
}
