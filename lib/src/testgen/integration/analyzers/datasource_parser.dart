import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../../ast_helpers.dart';
import '../models/datasource_info.dart';

/// Parses datasource source files and extracts GET endpoints for integration
/// tests.
///
/// Finds every `dio.get(...)` call inside a datasource class and records the
/// endpoint path, grouped by its first segment. A path is read from a string
/// literal, or from an `ApiConstants.x` reference resolved against the
/// project's `core/constants/api_constants.dart` — the way moarch's own
/// datasources name their endpoints.
class DataSourceParser {
  /// Creates a parser that operates within the given project root.
  ///
  /// [onWarning] is invoked with a message for every file or endpoint that
  /// had to be skipped.
  DataSourceParser({required this.projectRoot, this.onWarning})
    : _apiConstants = readApiConstants(projectRoot);

  /// The root directory of the Flutter project.
  final String projectRoot;

  /// Called with a human-readable message when a file or endpoint is skipped.
  final void Function(String message)? onWarning;

  final Map<String, String> _apiConstants;

  /// The `static const` string fields of `ApiConstants`, by name, read from
  /// `lib/core/constants/api_constants.dart`. Empty when the file is missing
  /// or declares none.
  static Map<String, String> readApiConstants(String projectRoot) {
    final file = File(
      p.join(projectRoot, 'lib', 'core', 'constants', 'api_constants.dart'),
    );
    if (!file.existsSync()) return const {};
    try {
      final parsed = parseString(
        content: file.readAsStringSync(),
        path: file.path,
      );
      final collector = _ConstantCollector();
      parsed.unit.visitChildren(collector);
      return collector.values;
    } catch (_) {
      return const {};
    }
  }

  /// Parses all provided datasource files and extracts endpoint information.
  ///
  /// Returns one [DataSourceInfo] per file that contains at least one GET
  /// endpoint. Files that cannot be parsed are skipped and reported through
  /// [onWarning].
  List<DataSourceInfo> parseAll(List<String> filePaths) {
    final result = <DataSourceInfo>[];
    for (final path in filePaths) {
      try {
        final source = _parse(path);
        if (source.endpoints.isNotEmpty) result.add(source);
      } catch (e) {
        onWarning?.call('Skipped $path (could not parse: $e)');
      }
    }
    return result;
  }

  DataSourceInfo _parse(String filePath) {
    final content = File(filePath).readAsStringSync();
    final featureName = _extractFeatureName(filePath);
    final visitor = _DataSourceVisitor(
      filePath: filePath,
      featureName: featureName,
      apiConstants: _apiConstants,
      onWarning: onWarning,
    );
    final parsed = parseString(content: content, path: filePath);
    parsed.unit.visitChildren(visitor);

    return DataSourceInfo(
      featureName: featureName,
      sourceFilePath: filePath,
      endpoints: visitor.endpoints,
    );
  }

  String _extractFeatureName(String filePath) {
    final rel = p.relative(filePath, from: projectRoot).replaceAll('\\', '/');
    final segments = rel.split('/');
    final featureIndex = segments.indexOf('features');
    if (featureIndex >= 0 && segments.length > featureIndex + 1) {
      return segments[featureIndex + 1];
    }
    return 'unknown';
  }
}

/// Collects `static const x = '...'` string fields.
class _ConstantCollector extends RecursiveAstVisitor<void> {
  final values = <String, String>{};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer is StringLiteral) {
      final value = initializer.stringValue;
      if (value != null) values[node.name.lexeme] = value;
    }
    super.visitVariableDeclaration(node);
  }
}

class _DataSourceVisitor extends RecursiveAstVisitor<void> {
  _DataSourceVisitor({
    required this.filePath,
    required this.featureName,
    required this.apiConstants,
    this.onWarning,
  });

  final String filePath;
  final String featureName;
  final Map<String, String> apiConstants;
  final void Function(String message)? onWarning;
  final endpoints = <EndpointInfo>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.namePart.typeName.lexeme;
    final body = node.body;
    if (body is! BlockClassBody) return;

    // Field types are needed to resolve `this.x` constructor parameters.
    final fieldTypes = <String, String>{};
    for (final member in body.members) {
      if (member is! FieldDeclaration) continue;
      final type = member.fields.type?.toSource();
      if (type == null) continue;
      for (final variable in member.fields.variables) {
        fieldTypes[variable.name.lexeme] = type;
      }
    }

    final constructorArguments = _buildConstructorArguments(
      className: className,
      members: body.members,
      fieldTypes: fieldTypes,
    );

    for (final member in body.members) {
      if (member is! MethodDeclaration) continue;
      final methodName = member.name.lexeme;
      final visitor = _DioGetVisitor(apiConstants);
      member.body.visitChildren(visitor);
      if (visitor.skippedNonLiteral > 0) {
        onWarning?.call(
          '$className.$methodName: skipped ${visitor.skippedNonLiteral} '
          'dio.get call(s) whose path is neither a literal nor an '
          'ApiConstants field (e.g. interpolation)',
        );
      }
      final callArguments = _buildCallArguments(
        member.parameters,
        fieldTypes,
        context: '$className.$methodName',
      );
      for (final endpoint in visitor.endpoints) {
        endpoints.add(
          EndpointInfo(
            className: className,
            methodName: methodName,
            httpMethod: 'GET',
            endpoint: endpoint,
            group: _extractGroup(endpoint),
            name: _extractName(endpoint),
            featureName: featureName,
            sourceFilePath: filePath,
            callArguments: callArguments,
            constructorArguments: constructorArguments,
          ),
        );
      }
    }
  }

  String _extractGroup(String endpoint) {
    final path = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    final parts = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'unknown' : parts.first;
  }

  String _extractName(String endpoint) {
    final path = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    final parts = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (parts.length <= 1) return parts.isEmpty ? 'root' : parts.first;
    return parts.skip(1).join('-');
  }

  /// Builds the argument list for the datasource constructor call.
  ///
  /// Parameters typed `Dio` receive the test client; other required
  /// parameters receive a type-appropriate default. Returns `'dio'` when no
  /// explicit constructor is declared (the default constructor convention).
  String _buildConstructorArguments({
    required String className,
    required List<ClassMember> members,
    required Map<String, String> fieldTypes,
  }) {
    ConstructorDeclaration? constructor;
    for (final member in members) {
      if (member is ConstructorDeclaration && member.name == null) {
        constructor = member;
        break;
      }
    }
    if (constructor == null) return 'dio';

    final positional = <String>[];
    final named = <String>[];

    for (final parameter in constructor.parameters.parameters) {
      if (!parameter.isRequired) continue;
      final type = _typeSource(parameter, fieldTypes);
      final baseType = _baseTypeName(type);
      final value = baseType == 'dio'
          ? 'dio'
          : _defaultArgumentValue(type, context: className);
      final name = parameter.name?.lexeme;
      if (parameter.isNamed && name != null) {
        named.add('$name: $value');
      } else {
        positional.add(value);
      }
    }

    return [...positional, ...named].join(', ');
  }

  /// Builds the argument list for the datasource method call, filling only
  /// required parameters with type-appropriate defaults.
  String _buildCallArguments(
    FormalParameterList? parameters,
    Map<String, String> fieldTypes, {
    required String context,
  }) {
    if (parameters == null) return '';

    final positional = <String>[];
    final named = <String>[];

    for (final parameter in parameters.parameters) {
      if (!parameter.isRequired) continue;
      final type = _typeSource(parameter, fieldTypes);
      final value = _defaultArgumentValue(type, context: context);
      final name = parameter.name?.lexeme;
      if (parameter.isNamed && name != null) {
        named.add('$name: $value');
      } else {
        positional.add(value);
      }
    }

    return [...positional, ...named].join(', ');
  }

  /// Returns the source of the parameter's declared type, resolving
  /// `this.x` parameters through the class field declarations.
  String? _typeSource(
    FormalParameter parameter,
    Map<String, String> fieldTypes,
  ) {
    final declared = AstHelpers.declaredType(parameter)?.toSource();
    if (declared != null) return declared;
    final name = parameter.name?.lexeme;
    if (name != null && AstHelpers.isFieldFormal(parameter)) {
      return fieldTypes[name];
    }
    return null;
  }

  String? _baseTypeName(String? typeSource) {
    if (typeSource == null) return null;
    return typeSource.replaceAll('?', '').split('<').first.trim().toLowerCase();
  }

  String _defaultArgumentValue(String? typeSource, {required String context}) {
    switch (_baseTypeName(typeSource)) {
      case 'string':
        return "''";
      case 'int':
        return '1';
      case 'double':
        return '1.0';
      case 'num':
        return '1';
      case 'bool':
        return 'false';
      default:
        // `null` compiles only for nullable/dynamic types; warn otherwise so
        // the user knows the generated call may need a manual value.
        if (typeSource != null && !typeSource.endsWith('?')) {
          onWarning?.call(
            '$context: no default value for required parameter of type '
            '$typeSource — generated `null` may not compile',
          );
        }
        return 'null';
    }
  }
}

class _DioGetVisitor extends RecursiveAstVisitor<void> {
  _DioGetVisitor(this.apiConstants);

  final Map<String, String> apiConstants;
  final endpoints = <String>[];

  /// Number of `dio.get` calls skipped because the path could not be read.
  int skippedNonLiteral = 0;

  /// Matches targets whose final identifier is `dio` or `_dio` (e.g. `dio`,
  /// `this._dio`, `client.dio`) without matching names like `audio`.
  static final _dioTarget = RegExp(r'(^|\.)_?dio$', caseSensitive: false);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    if (node.methodName.name != 'get') return;

    final target = node.realTarget?.toSource();
    if (target == null || !_dioTarget.hasMatch(target)) return;

    final firstArg = AstHelpers.firstExpression(node.argumentList);
    if (firstArg == null) return;

    final endpoint = _extractEndpoint(firstArg);
    if (endpoint == null) {
      skippedNonLiteral++;
      return;
    }
    if (!endpoints.contains(endpoint)) endpoints.add(endpoint);
  }

  /// The path [arg] names: a plain string literal, or `ApiConstants.x`.
  String? _extractEndpoint(Expression arg) {
    // stringValue is null for interpolated strings.
    if (arg is StringLiteral) return arg.stringValue;

    final match = RegExp(
      r'^ApiConstants\.(\w+)$',
    ).firstMatch(arg.toSource().trim());
    if (match != null) return apiConstants[match.group(1)];
    return null;
  }
}
