import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Small AST utilities shared by the parsers and detectors.
///
/// Everything here is written structurally rather than against concrete node
/// classes, because the analyzer's argument-list model changed between the
/// versions this package supports (`Expression` became `Argument` in
/// analyzer 13). Walking with a [GeneralizingAstVisitor] keeps one
/// implementation valid across all of them.
class AstHelpers {
  AstHelpers._();

  /// Returns the first argument of [list] as a plain [AstNode], or `null`
  /// when the list is empty.
  ///
  /// The static element type of `ArgumentList.arguments` differs per analyzer
  /// version, so the result is deliberately widened to [AstNode] — the one
  /// supertype every version agrees on.
  static AstNode? firstArgument(ArgumentList list) {
    final args = list.arguments;
    return args.isEmpty ? null : args.first;
  }

  /// Returns the first [FunctionExpression] reachable from [node] (including
  /// [node] itself), or `null` when there is none.
  ///
  /// Used to pull the `(event, emit) { ... }` closure out of an
  /// `on<Event>(...)` registration regardless of how the argument node is
  /// wrapped.
  static FunctionExpression? firstFunctionExpression(AstNode node) {
    final finder = _FunctionExpressionFinder();
    node.accept(finder);
    return finder.found;
  }

  /// The first expression inside the first argument of [list] — the argument
  /// itself on analyzer < 13, where an argument *is* an expression, and the
  /// expression it wraps on 13+, where arguments became `Argument` nodes.
  /// `null` when the list is empty.
  static Expression? firstExpression(ArgumentList list) {
    final arg = firstArgument(list);
    if (arg == null) return null;
    if (arg is Expression) return arg;
    final finder = _ExpressionFinder();
    arg.visitChildren(finder);
    return finder.found;
  }

  /// The explicit type annotation of [param], or `null` when it declares none
  /// (`this.value`, `super.value`, a bare `value`).
  ///
  /// Walks the AST for the first [TypeAnnotation] rather than matching
  /// concrete parameter classes: analyzer 13 folded that hierarchy together,
  /// so `SimpleFormalParameter` / `FieldFormalParameter` only exist on older
  /// versions, while [TypeAnnotation] is stable across all of them.
  static TypeAnnotation? declaredType(FormalParameter param) {
    // An old-style function-typed parameter (`void cb(int x)`) leads with its
    // *return* type, which is not the parameter's type.
    if (param.name?.next?.lexeme == '(') return null;
    final finder = _TypeAnnotationFinder();
    param.visitChildren(finder);
    return finder.type;
  }

  /// Whether [param] is a field formal (`this.dio`, `required this._dio`),
  /// read off its source for the same reason as [declaredType].
  static bool isFieldFormal(FormalParameter param) {
    final source = param.toSource().trim().replaceFirst(
      RegExp(r'^(required|covariant|final|const)\s+'),
      '',
    );
    return source.startsWith('this.');
  }

  /// Whether [source] is a bare identifier (e.g. a tear-off handler such as
  /// `_onLoginRequested` passed to `on<LoginRequested>(...)`).
  static bool isIdentifier(String source) =>
      RegExp(r'^[_a-zA-Z][a-zA-Z0-9_]*$').hasMatch(source.trim());

  /// Whether the function [body] is declared `async` / `async*`.
  static bool isAsyncBody(FunctionBody body) => body.keyword?.lexeme == 'async';

  /// The class name an expression constructs, or `null` when the expression
  /// isn't a construction at all.
  ///
  /// This is what turns `emit(AuthSuccess(user))` into `AuthSuccess` and
  /// `super(const AuthInitial())` into `AuthInitial`, while
  /// `emit(state.copyWith(...))` and `emit(next)` correctly yield `null` —
  /// nothing there names a state class.
  ///
  /// Parsed source is unresolved, so `AuthSuccess(user)` arrives as a method
  /// invocation while `const AuthFailure('x')` arrives as an instance
  /// creation; a leading capitalised identifier is what both have in common.
  static String? constructedTypeName(String source) {
    var expression = source.trim();
    for (final keyword in const ['const ', 'new ']) {
      if (expression.startsWith(keyword)) {
        expression = expression.substring(keyword.length).trim();
      }
    }
    final match = RegExp(
      r'^([A-Z][A-Za-z0-9_]*)\s*[(.]',
    ).firstMatch(expression);
    return match?.group(1);
  }
}

class _ExpressionFinder extends GeneralizingAstVisitor<void> {
  Expression? found;

  @override
  void visitNode(AstNode node) {
    if (found != null) return;
    if (node is Expression) {
      found = node;
      return;
    }
    super.visitNode(node);
  }
}

class _TypeAnnotationFinder extends GeneralizingAstVisitor<void> {
  TypeAnnotation? type;

  @override
  void visitNode(AstNode node) {
    if (type != null) return;
    if (node is TypeAnnotation) {
      // Stop here so the outermost annotation wins over its type arguments.
      type = node;
      return;
    }
    super.visitNode(node);
  }
}

class _FunctionExpressionFinder extends GeneralizingAstVisitor<void> {
  FunctionExpression? found;

  @override
  void visitNode(AstNode node) {
    if (found != null) return;
    if (node is FunctionExpression) {
      found = node;
      return;
    }
    super.visitNode(node);
  }
}
