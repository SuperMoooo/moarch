import 'dart:io';

import 'package:path/path.dart' as p;

import '../../testgen_result.dart';
import '../analyzers/datasource_parser.dart';
import '../analyzers/datasource_scanner.dart';
import '../models/datasource_info.dart';
import 'integration_test_generator.dart';

/// Scans every feature's remote datasources and writes an integration test
/// per GET endpoint into `test/integration/features/<feature>/`, plus the
/// shared `test/integration/dio_helper.dart` the first time one is needed.
class IntegrationTestOrchestrator {
  /// Creates an orchestrator for the project at [projectRoot].
  IntegrationTestOrchestrator({
    required this.projectRoot,
    required this.packageName,
    this.dryRun = false,
    this.force = false,
    this.feature,
    this.onProgress,
  });

  /// Absolute path to the project root.
  final String projectRoot;

  /// The Dart package name, used to construct import paths.
  final String packageName;

  /// When `true`, generated files are not written to disk.
  final bool dryRun;

  /// When `true`, existing test files are overwritten even when they no
  /// longer carry the generated marker.
  final bool force;

  /// If non-null, only generate tests for this feature name.
  final String? feature;

  /// Called with a line of progress per feature and endpoint, for
  /// `--verbose`.
  final void Function(String message)? onProgress;

  /// Scans the project, parses datasources, and writes tests.
  TestGenResult run() {
    final result = TestGenResult();
    final featuresRoot = p.join(projectRoot, 'lib', 'features');
    final testRoot = p.join(projectRoot, 'test', 'integration');

    final scanner = DataSourceScanner(featuresRoot: featuresRoot);
    final parser = DataSourceParser(
      projectRoot: projectRoot,
      onWarning: result.warnings.add,
    );
    final generator = IntegrationTestGenerator();

    var bundles = scanner.scan();
    final only = feature;
    if (only != null && only.isNotEmpty) {
      bundles = bundles.where((b) => b.featureName == only).toList();
    }
    result.featuresScanned = bundles.length;

    var helperPrepared = false;
    final usedPaths = <String>{};

    for (final bundle in bundles) {
      onProgress?.call(bundle.featureName);

      for (final source in parser.parseAll(bundle.datasourceFiles)) {
        for (final endpoint in source.endpoints) {
          onProgress?.call(
            '  GET ${endpoint.endpoint} → '
            '${endpoint.className}.${endpoint.methodName}()',
          );
          final String content;
          try {
            content = generator.generate(endpoint, packageName: packageName);
          } catch (e) {
            result.errors.add('${endpoint.className}: $e');
            continue;
          }

          // Only once a test is actually generated.
          if (!helperPrepared) {
            _prepareHelper(testRoot, result);
            helperPrepared = true;
          }

          final outPath = _resolveOutPath(testRoot, endpoint, usedPaths);
          result.emit(outPath, content, dryRun: dryRun, force: force);
        }
      }
    }

    return result;
  }

  /// Resolves a unique output path for [endpoint], disambiguating with the
  /// method name (and finally a counter) when two endpoints in the same
  /// feature would otherwise produce the same file name.
  String _resolveOutPath(
    String testRoot,
    EndpointInfo endpoint,
    Set<String> usedPaths,
  ) {
    final dir = p.join(testRoot, 'features', endpoint.importGroup);
    var path = p.join(dir, endpoint.fileName);
    if (usedPaths.add(path)) return path;

    final base = endpoint.fileName.replaceAll(
      RegExp(r'_integration_test\.dart$'),
      '',
    );
    path = p.join(dir, '${base}_${endpoint.methodName}_integration_test.dart');
    var counter = 2;
    while (!usedPaths.add(path)) {
      path = p.join(
        dir,
        '${base}_${endpoint.methodName}_${counter}_integration_test.dart',
      );
      counter++;
    }
    return path;
  }

  /// Writes `dio_helper.dart` when it does not exist yet. Never overwritten:
  /// the base URL and the test login are the team's.
  void _prepareHelper(String testRoot, TestGenResult result) {
    final helperPath = p.join(testRoot, 'dio_helper.dart');
    if (File(helperPath).existsSync()) return;
    if (dryRun) {
      result.planned.add(helperPath);
      return;
    }
    File(helperPath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(IntegrationTestGenerator.dioHelper(packageName));
    result.written.add(helperPath);
  }
}
