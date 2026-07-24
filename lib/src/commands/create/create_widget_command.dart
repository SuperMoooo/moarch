import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../utils/file_utils.dart';
import '../../utils/pubspec_utils.dart';
import '../../utils/widget_catalog.dart';

/// Creates the `create widget` subcommand: scaffolds a widget from the shared
/// UI kit on demand, pulling in its dependencies and pub packages.
class CreateWidgetCommand extends Command<int> {
  /// CREATE WIDGET COMMAND
  CreateWidgetCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: 'lib',
        help: 'Path to lib/ directory.',
      )
      ..addFlag(
        'list',
        abbr: 'l',
        negatable: false,
        help: 'List every available widget and exit.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'widget';

  @override
  String get description =>
      'Generate a shared UI widget from the kit (see docs/UI_KIT.md).';

  @override
  String get invocation => 'moarch create widget <name> [<name>...]';

  @override
  Future<int> run() async {
    if (argResults?['list'] as bool? ?? false) {
      _printList();
      return 0;
    }

    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      _logger.err(
          'Provide a widget name.\n  Usage: moarch create widget <name> (or "all")');
      _logger.info('');
      _printList();
      return 1;
    }

    final libPath = argResults?['path'] as String? ?? 'lib';
    final projectRoot = p.dirname(p.absolute(libPath));

    // "all" expands to the whole catalog.
    final requested = rest.contains('all') ? WidgetCatalog.names : rest;

    final unknown =
        requested.where((n) => WidgetCatalog.byName(n) == null).toList();
    if (unknown.isNotEmpty) {
      _logger.err('Unknown widget(s): ${unknown.join(', ')}');
      _logger.info('Run `moarch create widget --list` to see valid names.');
      return 1;
    }

    final specs = WidgetCatalog.resolve(requested);
    final widgetsRoot = p.join(libPath, 'shared', 'widgets');
    final packages = <String>{for (final spec in specs) ...spec.packages};

    _logger.info('');
    _logger.info('🧱 Generating ${specs.length} widget(s)');
    _logger.info('');

    final progress = _logger.progress('Scaffolding widgets');
    FileUtils.beginSession();

    try {
      for (final spec in specs) {
        await FileUtils.writeFile(
          p.join(widgetsRoot, spec.file),
          spec.template(),
        );
      }
      if (packages.isNotEmpty) {
        await PubspecUtils.ensureDependencies(
          projectRoot,
          dependencies: packages.toList(),
        );
      }
      progress.complete('Widgets scaffolded');
    } catch (e) {
      progress.fail('Failed: $e');
      FileUtils.rollback();
      _logger.info('  Rolled back partially generated files.');
      return 1;
    }

    _logger.success('');
    for (final spec in specs) {
      _logger.info('  + shared/widgets/${spec.file}');
    }

    if (packages.isNotEmpty) {
      final names = packages.map((pkg) => pkg.replaceAll(':', '').trim());
      _logger.info('');
      _logger.info('  Added to pubspec.yaml: ${names.join(', ')}');
      _logger.info('  Run: flutter pub get');
    }

    // Router-dependent widgets import config/router/app_router.dart.
    final needsRouter = specs.any((spec) => spec.needsRouter);
    final hasRouter = File(
      p.join(libPath, 'config', 'router', 'app_router.dart'),
    ).existsSync();
    if (needsRouter && !hasRouter) {
      _logger.info('');
      _logger.warn(
          '  Some of these import config/router/app_router.dart (rootNavigatorKey).');
      _logger.warn(
          '  Generate the GoRouter setup first, or point them at your own navigator key.');
    }

    _logger.info('');
    return 0;
  }

  void _printList() {
    _logger.info('Available widgets  —  moarch create widget <name>');
    _logger.info('');
    for (final category in WidgetCatalog.categories) {
      final items =
          WidgetCatalog.all.where((w) => w.category == category).toList();
      if (items.isEmpty) continue;
      _logger.info('  $category:');
      for (final w in items) {
        final tag = w.common ? '  (on init)' : '';
        _logger.info('    ${w.name.padRight(18)} ${w.title}$tag');
      }
      _logger.info('');
    }
    _logger.info(
        '  moarch create widget all   → generate the whole kit + preview');
  }
}
