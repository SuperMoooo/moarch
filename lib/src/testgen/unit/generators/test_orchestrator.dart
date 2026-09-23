import 'package:path/path.dart' as p;

import '../../testgen_result.dart';
import '../analyzers/event_parser.dart';
import '../analyzers/feature_scanner.dart';
import '../analyzers/notifier_parser.dart';
import '../analyzers/state_parser.dart';
import '../models/notifier_info.dart';
import 'test_generator.dart';

/// Scans `lib/features`, parses every notifier, bloc and cubit, and writes a
/// unit test per class into `test/unit/features/<feature>/`.
class UnitTestOrchestrator {
  /// Creates an orchestrator for the project at [projectRoot].
  UnitTestOrchestrator({
    required this.projectRoot,
    required this.packageName,
    this.dryRun = false,
    this.force = false,
    this.feature,
    this.onProgress,
  });

  /// Absolute path to the project root.
  final String projectRoot;

  /// Package name used to build import paths.
  final String packageName;

  /// When `true`, generated files are not written to disk.
  final bool dryRun;

  /// When `true`, existing test files are overwritten even when they no
  /// longer carry the generated marker — i.e. someone edited them.
  final bool force;

  /// If non-null, only generate tests for this feature name.
  final String? feature;

  /// Called with a line of progress per feature and class, for `--verbose`.
  final void Function(String message)? onProgress;

  /// Scans the project, parses the state holders and writes their tests.
  TestGenResult run() {
    final result = TestGenResult();
    final featuresRoot = p.join(projectRoot, 'lib', 'features');
    final testRoot = p.join(projectRoot, 'test');

    final scanner = FeatureScanner(featuresRoot: featuresRoot);
    final notifierParser = NotifierParser(
      projectRoot: projectRoot,
      packageName: packageName,
    );
    final stateParser = StateParser(
      projectRoot: projectRoot,
      packageName: packageName,
    );
    final eventParser = EventParser(
      projectRoot: projectRoot,
      packageName: packageName,
    );

    var bundles = scanner.scan();
    final only = feature;
    if (only != null && only.isNotEmpty) {
      bundles = bundles.where((b) => b.featureName == only).toList();
    }
    result.featuresScanned = bundles.length;

    // ── First pass: parse every class and state up front and build the
    //    project-wide registries. They let the generator resolve imports for
    //    a dependency that lives in another feature, mock another notifier
    //    safely, and construct an event declared in someone else's file.
    final parsedByBundle = <FeatureBundle, List<NotifierInfo>>{};
    final notifierIndex = <String, String>{};
    final notifierRegistry = <String, NotifierInfo>{};
    final eventRegistry = <String, EventClassInfo>{};

    for (final bundle in bundles) {
      final states = stateParser.parseAll(bundle.stateFiles);

      for (final event in eventParser.parseAll(bundle.eventFiles)) {
        eventRegistry.putIfAbsent(event.className, () => event);
      }

      final notifiers = <NotifierInfo>[];
      for (final notifierFile in bundle.notifierFiles) {
        try {
          for (var notifier in notifierParser.parse(notifierFile)) {
            notifier = notifier.withStateInfo(_matchState(notifier, states));
            notifiers.add(notifier);

            if (notifierRegistry.containsKey(notifier.className)) {
              result.warnings.add(
                'Two classes are named ${notifier.className} — '
                '${notifierIndex[notifier.className]} is used to resolve '
                'dependencies on it, ${notifier.importPath} is shadowed.',
              );
            } else {
              notifierIndex[notifier.className] = notifier.importPath;
              notifierRegistry[notifier.className] = notifier;
            }
          }
        } catch (e) {
          result.errors.add('${_relative(notifierFile)}: $e');
        }
      }
      parsedByBundle[bundle] = notifiers;
    }

    final generator = TestGenerator(
      projectRoot: projectRoot,
      notifierIndex: notifierIndex,
      notifierRegistry: notifierRegistry,
      eventRegistry: eventRegistry,
    );

    // ── Second pass: one test file per class.
    for (final bundle in bundles) {
      onProgress?.call(bundle.featureName);

      for (final notifier in parsedByBundle[bundle] ?? const <NotifierInfo>[]) {
        final kind = switch (notifier.kind) {
          StateManagementKind.bloc => 'bloc',
          StateManagementKind.cubit => 'cubit',
          StateManagementKind.riverpod => 'riverpod',
        };
        final state = notifier.stateInfo?.className;
        onProgress?.call(
          '  ${notifier.className} [$kind]'
          '${state == null ? ' — no state class matched' : ' → $state'}',
        );

        final String content;
        try {
          content = generator.generate(notifier);
        } catch (e) {
          result.errors.add('${notifier.className}: $e');
          continue;
        }
        final outPath = p.join(
          testRoot,
          'unit',
          'features',
          bundle.featureName,
          '${_snake(notifier.className)}_test.dart',
        );
        result.emit(outPath, content, dryRun: dryRun, force: force);
      }
    }

    return result;
  }

  StateInfo? _matchState(NotifierInfo n, List<StateInfo> states) {
    if (states.isEmpty) return null;

    if (n.stateType != null) {
      for (final s in states) {
        if (s.className == n.stateType) return s;
      }
    }

    final prefix = n.className.replaceAll(
      RegExp(r'(Notifier|Cubit|Bloc|ViewModel)$'),
      '',
    );

    // Prefer the exact `${prefix}State` match before falling back to a
    // prefix search, whose result would otherwise depend on filesystem
    // enumeration order when several states share the prefix
    // (`CartState` and `CartSummaryState` both matching `CartNotifier`).
    for (final s in states) {
      if (s.className == '${prefix}State') return s;
    }
    for (final s in states) {
      if (s.className.startsWith(prefix)) return s;
    }
    return null;
  }

  String _relative(String path) =>
      p.relative(path, from: projectRoot).replaceAll(r'\', '/');

  /// Acronym-aware snake_case (`APIClient` → `api_client`), matching the
  /// generator's file-name convention.
  String _snake(String name) => name
      .replaceAllMapped(
        RegExp(r'([A-Z]+)([A-Z][a-z])'),
        (m) => '${m.group(1)}_${m.group(2)}',
      )
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m.group(1)}_${m.group(2)}',
      )
      .toLowerCase();
}
