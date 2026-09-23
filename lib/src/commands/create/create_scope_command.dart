import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../templates/bloc/scope_templates.dart' show ScopeTemplates;
import '../../templates/stack_templates.dart';
import '../../utils/file_utils.dart';
import '../../utils/project_paths.dart';
import '../../utils/state_management.dart';
import '../../utils/string_utils.dart';

/// Generates a bloc scope: the blocs a screen provides, gathered so what it
/// opens on top of it — a pushed route, a sheet, a dialog — can be handed the
/// same instances.
///
/// Those are siblings of the screen in the Navigator rather than children, so
/// `context.read` from inside them does not reach the screen's blocs. The
/// scope's `of(context)` collects them where they are and `provide(child:)`
/// provides them again where they are needed.
class CreateScopeCommand extends Command<int> {
  /// Creates the scope generator command.
  CreateScopeCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: 'lib',
        help: 'Path to the lib/ directory, or the project root holding it.',
      )
      ..addOption(
        'blocs',
        abbr: 'b',
        help:
            'Comma-separated bloc/cubit classes to carry. Defaults to every '
            'one the feature declares under presentation/.',
      )
      ..addOption(
        'parent',
        help:
            'A scope this one nests inside (e.g. LawfirmScope) — its blocs '
            'travel along and are provided around this one\'s.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'scope';

  @override
  String get description =>
      "Carry a screen's blocs to the routes, sheets and dialogs it opens "
      '(bloc only).';

  @override
  String get invocation =>
      'moarch create scope <featureName> <scopeName> [--blocs A,B] '
      '[--parent XScope]';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.length < 2) {
      _logger.err(
        'Provide a feature and a name.\n'
        '  Usage: moarch create scope <featureName> <scopeName>',
      );
      return 1;
    }

    final libPath = resolveLibPath(argResults?['path'] as String? ?? 'lib');
    final templates = StackTemplates(StateManagement.detect(libPath));

    if (!templates.hasScopes) {
      _logger.err('This project uses Riverpod — there is nothing to scope.');
      _logger.info(
        '  A provider lives above the Navigator, so a pushed route, a sheet '
        'or a dialog',
      );
      _logger.info(
        '  already reads the same notifier with ref.watch. A notifier that '
        'belongs to one',
      );
      _logger.info(
        '  record (a matter, an order) is a family provider keyed by its id.',
      );
      return 1;
    }

    final featureName = StringUtils.toSnakeCase(rest[0]);
    final featurePath = p.join(libPath, 'features', featureName);
    if (!Directory(featurePath).existsSync()) {
      _logger.err('No feature at $featurePath.');
      return 1;
    }

    // `MatterScope` and `matter` both mean the Matter scope.
    final stem = StringUtils.toPascalCase(
      rest[1],
    ).replaceFirst(RegExp(r'Scope$'), '');
    if (stem.isEmpty) {
      _logger.err('"${rest[1]}" is not a usable scope name.');
      return 1;
    }
    final scopeDir = p.join(featurePath, 'presentation', 'scopes');
    final scopeFile = p.join(
      scopeDir,
      '${StringUtils.toSnakeCase(stem)}_scope.dart',
    );
    if (File(scopeFile).existsSync()) {
      _logger.err(
        '${stem}Scope already exists at ${_rel(scopeFile, libPath)}.',
      );
      return 1;
    }

    // ── What it carries ───────────────────────────────────────────────────
    final projectBlocs = _declaredClasses(
      Directory(p.join(libPath, 'features')),
      RegExp(r'class\s+(\w+)\s+extends\s+\w*(?:Bloc|Cubit)\s*<'),
    );
    final requested = (argResults?['blocs'] as String?)
        ?.split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final List<String> blocNames;
    if (requested != null && requested.isNotEmpty) {
      final unknown = requested.where((b) => !projectBlocs.containsKey(b));
      if (unknown.isNotEmpty) {
        _logger.err(
          'No bloc or cubit named ${unknown.join(', ')} under '
          'lib/features/.',
        );
        return 1;
      }
      blocNames = requested;
    } else {
      final presentation = p.join(featurePath, 'presentation');
      blocNames =
          projectBlocs.entries
              .where((e) => p.isWithin(presentation, e.value))
              .map((e) => e.key)
              .toList()
            ..sort();
      if (blocNames.isEmpty) {
        _logger.err('$featureName declares no bloc or cubit to carry.');
        _logger.info(
          '  Name them with --blocs, or add one first: '
          'moarch create bloc $featureName <name>',
        );
        return 1;
      }
    }

    String importFor(String file) =>
        p.relative(file, from: scopeDir).replaceAll(r'\', '/');

    final usedFields = <String>{};
    String fieldFor(String className, String suffix) {
      final stripped = className.replaceFirst(RegExp('$suffix\$'), '');
      var field = StringUtils.toCamelCase(
        stripped.isEmpty ? className : stripped,
      );
      // Two blocs that strip to the same name keep their suffix.
      if (!usedFields.add(field)) {
        field = StringUtils.toCamelCase(className);
        usedFields.add(field);
      }
      return field;
    }

    ScopeParent? parent;
    final parentName = argResults?['parent'] as String?;
    if (parentName != null && parentName.isNotEmpty) {
      final scopes = _declaredClasses(
        Directory(libPath),
        RegExp(r'class\s+(\w+Scope)\b'),
        fileSuffix: '_scope.dart',
      );
      final parentFile = scopes[parentName];
      if (parentFile == null) {
        _logger.err(
          'No scope named $parentName in lib/ — create it first '
          'with `moarch create scope`.',
        );
        return 1;
      }
      parent = ScopeParent(
        className: parentName,
        field: fieldFor(parentName, 'Scope'),
        import: importFor(parentFile),
      );
    }

    final blocs = [
      for (final className in blocNames)
        ScopeBloc(
          className: className,
          field: fieldFor(
            className,
            className.endsWith('Cubit') ? 'Cubit' : 'Bloc',
          ),
          import: importFor(projectBlocs[className]!),
        ),
    ];

    FileUtils.beginSession();
    await FileUtils.writeFile(
      scopeFile,
      templates.scope(name: stem, blocs: blocs, parent: parent),
    );

    final cls = '${stem}Scope';
    _logger.info('');
    _logger.success('  ✓ ${_rel(scopeFile, libPath)}');
    _logger.info(
      '    carries ${[if (parent != null) parent.className, ...blocNames].join(', ')}',
    );
    _logger.info('');
    _logger.info('  Sheets and dialogs:');
    _logger.info('    context.show${stem}Sheet((_) => const MySheet());');
    _logger.info('    context.show${stem}Dialog((_) => const MyDialog());');
    _logger.info('');
    _logger.info('  A pushed route:');
    _logger.info('    context.push(AppRoutes.x, extra: $cls.of(context));');
    _logger.info('    // in its GoRoute:');
    _logger.info('    builder: (context, state) =>');
    _logger.info(
      '        (state.extra! as $cls).provide(child: const XPage()),',
    );
    _logger.info('');
    _logger.info(
      '  Routes nested under the screen are sturdier in a ShellRoute — '
      '`extra` is',
    );
    _logger.info(
      '  lost on a deep link or a web refresh, a shell\'s providers are not:',
    );
    _logger.info('');
    for (final line in ScopeTemplates.shellRouteSnippet(
      name: stem,
      blocs: blocs,
    ).split('\n')) {
      _logger.info('    $line');
    }
    _logger.info('');
    return 0;
  }

  /// Every class in [dir]'s Dart files matching [pattern] (group 1 is the
  /// name), mapped to the file declaring it.
  Map<String, String> _declaredClasses(
    Directory dir,
    RegExp pattern, {
    String fileSuffix = '.dart',
  }) {
    final found = <String, String>{};
    if (!dir.existsSync()) return found;
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      final path = file.path;
      if (!path.endsWith(fileSuffix)) continue;
      if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        found.putIfAbsent(match.group(1)!, () => path);
      }
    }
    return found;
  }

  String _rel(String path, String libPath) => p
      .relative(path, from: p.dirname(p.absolute(libPath)))
      .replaceAll(r'\', '/');
}
