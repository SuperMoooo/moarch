import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../testgen/integration/generators/test_orchestrator.dart';
import '../../testgen/testgen_result.dart';
import '../../testgen/unit/generators/test_orchestrator.dart';
import '../../utils/package_versions.dart';
import '../../utils/project_paths.dart';
import '../../utils/pubspec_utils.dart';
import '../../utils/scaffold_catalog.dart';
import '../../utils/string_utils.dart';

/// Generates tests from the code the project already has.
///
/// - **Unit** — one file per notifier, bloc or cubit under
///   `test/unit/features/<feature>/`: every dependency mocked with mocktail
///   (registered in `getIt` when a notifier reads it from there, passed to the
///   constructor for a bloc), and a success and an error test per action.
///   Blocs and cubits get `bloc_test`.
/// - **Integration** — one file per GET endpoint a remote datasource calls,
///   under `test/integration/features/<feature>/`, against the real API
///   through `test/integration/dio_helper.dart`.
///
/// A file that no longer carries the generated marker was edited, and is left
/// alone unless `--force`. Re-running is how the tests follow the code: new
/// methods, events and endpoints get their tests, and untouched files are
/// refreshed.
class CreateTestsCommand extends Command<int> {
  /// Creates the test-generation command.
  CreateTestsCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: 'lib',
        help: 'Path to the lib/ directory, or the project root holding it.',
      )
      ..addFlag(
        'unit',
        defaultsTo: true,
        help: 'Generate unit tests for notifiers, blocs and cubits.',
      )
      ..addFlag(
        'integration',
        defaultsTo: true,
        help: 'Generate integration tests for datasource GET endpoints.',
      )
      ..addFlag(
        'dry-run',
        abbr: 'd',
        negatable: false,
        help: 'List what would be written without writing anything.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Also overwrite generated tests you have edited.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Print every class and endpoint as it is scanned.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'tests';

  @override
  String get description =>
      'Generate unit tests for every notifier/bloc and integration tests for '
      'every datasource GET endpoint.';

  @override
  String get invocation => 'moarch create tests [feature_name]';

  @override
  Future<int> run() async {
    final libPath = resolveLibPath(argResults?['path'] as String? ?? 'lib');
    final root = p.dirname(p.absolute(libPath));
    final unit = argResults?['unit'] as bool? ?? true;
    final integration = argResults?['integration'] as bool? ?? true;
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final force = argResults?['force'] as bool? ?? false;
    final verbose = argResults?['verbose'] as bool? ?? false;
    final rest = argResults?.rest ?? const <String>[];
    final feature = rest.isEmpty ? null : StringUtils.toSnakeCase(rest.first);

    if (!Directory(p.join(libPath, 'features')).existsSync()) {
      _logger.err('No lib/features/ at $root — is this a moarch project?');
      return 1;
    }
    if (feature != null &&
        !Directory(p.join(libPath, 'features', feature)).existsSync()) {
      _logger.err('Feature "$feature" not found under lib/features/.');
      return 1;
    }
    if (!unit && !integration) {
      _logger.err('Nothing to do: both --no-unit and --no-integration.');
      return 1;
    }

    final context = ScaffoldContext.detect(root);
    final packageName = context.projectName;
    void progress(String line) {
      if (verbose) _logger.info('  $line');
    }

    _logger.info('');
    _logger.info(
      '🧪 moarch — generating tests'
      '${feature == null ? '' : ' for $feature'}',
    );
    if (dryRun) _logger.warn('  Dry run — nothing will be written.');
    _logger.info('');

    final results = <String, TestGenResult>{};
    if (unit) {
      results['Unit'] = UnitTestOrchestrator(
        projectRoot: root,
        packageName: packageName,
        dryRun: dryRun,
        force: force,
        feature: feature,
        onProgress: progress,
      ).run();
    }
    if (integration) {
      results['Integration'] = IntegrationTestOrchestrator(
        projectRoot: root,
        packageName: packageName,
        dryRun: dryRun,
        force: force,
        feature: feature,
        onProgress: progress,
      ).run();
    }

    var failed = false;
    results.forEach((kind, result) {
      _report(kind, result, root);
      failed = failed || result.hasErrors;
    });

    final wroteAnything = results.values.any((r) => r.written.isNotEmpty);
    if (wroteAnything && !dryRun) {
      await _ensureTestPackages(root, context, unit: unit);
    }
    _warnMissingEmptyFactories(
      libPath,
      feature,
      results.values.expand((r) => r.written),
    );

    if (wroteAnything) {
      _logger.info('');
      _logger.info('  Run them:');
      if (unit) _logger.info('    fvm flutter test test/unit');
      if (integration) {
        _logger.info(
          '    fvm flutter test test/integration   '
          '(calls the real API — BASE_URL in .env)',
        );
      }
    }
    _logger.info('');
    return failed ? 1 : 0;
  }

  void _report(String kind, TestGenResult result, String root) {
    String rel(String path) =>
        p.relative(path, from: root).replaceAll(r'\', '/');

    final files = [...result.written, ...result.planned];
    _logger.info(
      '  $kind — ${result.featuresScanned} feature(s), '
      '${files.length} file(s)${result.planned.isEmpty ? '' : ' planned'}',
    );
    for (final path in files) {
      _logger.info(
        '    ${result.planned.contains(path) ? '·' : '↻'} '
        '${rel(path)}',
      );
    }
    if (result.handMaintained.isNotEmpty) {
      _logger.warn(
        '    Edited since generation, left alone (--force to '
        'overwrite):',
      );
      for (final path in result.handMaintained) {
        _logger.warn('      ${rel(path)}');
      }
    }
    for (final warning in result.warnings) {
      _logger.warn('    $warning');
    }
    for (final error in result.errors) {
      _logger.err('    $error');
    }
    _logger.info('');
  }

  /// What the generated files import: mocktail everywhere, bloc_test on a
  /// bloc project. Added as dev dependencies when missing, the same way
  /// `create widget` adds a widget's package.
  Future<void> _ensureTestPackages(
    String root,
    ScaffoldContext context, {
    required bool unit,
  }) async {
    if (!unit) return;
    final missing = [
      if (!context.hasPackage('mocktail')) 'mocktail',
      if (context.hasBloc && !context.hasPackage('bloc_test')) 'bloc_test',
    ];
    if (missing.isEmpty) return;
    await PubspecUtils.ensureDependencies(
      root,
      dependencies: const [],
      devDependencies: missing.map(PackageVersions.entry).toList(),
    );
    _logger.info(
      '  Added ${missing.join(' and ')} to dev_dependencies — '
      'run `fvm flutter pub get`.',
    );
  }

  /// The generated stubs return `Model.empty()` for a model a dependency
  /// hands back, so a model without that factory is a test that does not
  /// compile. Said here rather than left for the analyzer to find — and only
  /// for the models the written tests actually call it on.
  void _warnMissingEmptyFactories(
    String libPath,
    String? feature,
    Iterable<String> writtenTests,
  ) {
    final used = <String>{};
    for (final path in writtenTests) {
      final file = File(path);
      if (!file.existsSync()) continue;
      for (final match in RegExp(
        r'\b([A-Z]\w*)\.empty\(\)',
      ).allMatches(file.readAsStringSync())) {
        used.add(match.group(1)!);
      }
    }
    if (used.isEmpty) return;

    final featuresDir = Directory(p.join(libPath, 'features'));
    final missing = <String>[];
    for (final featureDir in featuresDir.listSync().whereType<Directory>()) {
      final models = Directory(p.join(featureDir.path, 'domain', 'models'));
      if (!models.existsSync()) continue;
      for (final file in models.listSync().whereType<File>()) {
        final source = file.readAsStringSync();
        final declares = used.any(
          (type) => RegExp('\\bclass\\s+$type\\b').hasMatch(source),
        );
        if (declares && !source.contains('.empty(')) {
          missing.add(p.basename(file.path));
        }
      }
    }
    if (missing.isEmpty) return;
    _logger.warn(
      '  ${missing.length} model(s) have no .empty() factory, which '
      'the generated stubs call:',
    );
    _logger.warn('    ${missing.join(', ')}');
    _logger.info(
      '  Add them with: moarch create empty-factories'
      '${feature == null ? '' : ' $feature'}',
    );
  }
}
