import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:path/path.dart' as p;

import '../../templates/config/config_templates.dart';
import '../../templates/ui/feature_templates.dart';
import '../../utils/checklist.dart';
import '../../utils/file_utils.dart';
import '../../utils/project_manifest.dart';
import '../../utils/pubspec_utils.dart';
import '../../utils/scaffold_catalog.dart';
import '../../utils/string_utils.dart';
import '../../utils/widget_catalog.dart';

// Layer labels used in the checklist
const _kRemoteDatasource = 'Remote Datasource';
// Shown in place of the label above when the project has both backends, so
// the choice of which one this feature talks to is the user's.
const _kDioDatasource = 'Remote Datasource (Dio)';
const _kFirestoreDatasource = 'Remote Datasource (Firestore)';
const _kLocalDatasource = 'Local/Cache Datasource';
const _kRepository = 'Repository (interface + impl)';
const _kUseCases = 'Use Cases';
const _kStateNotifier = 'State + Notifier';
const _kView = 'View';

/// Creates the feature subcommand for scaffolding.
class CreateFeatureCommand extends Command<int> {
  /// CREATE FEATURE COMMAND
  CreateFeatureCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: 'lib',
        help: 'Path to lib/ directory.',
      )
      ..addFlag(
        'all',
        abbr: 'a',
        negatable: false,
        help: 'Skip checklist and generate all layers.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'feature';

  @override
  String get description =>
      'Scaffold a new feature with selectable Clean Architecture layers.';

  @override
  String get invocation => 'moarch create feature <name>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      _logger.err(
          'Provide a feature name.\n  Usage: moarch create feature <name>');
      return 1;
    }

    final featureName = StringUtils.toSnakeCase(rest.first);
    final className = StringUtils.toPascalCase(rest.first);
    final varName = StringUtils.toCamelCase(rest.first);
    final libPath = argResults?['path'] as String? ?? 'lib';
    final featurePath = p.join(libPath, 'features', featureName);
    final featureExists = Directory(featurePath).existsSync();

    // ── Existing feature — offer tests only ───────────────────────────────────
    if (featureExists) {
      _logger.warn('Feature "$featureName" already exists at $featurePath');
      _logger.info('');

      // For existing features we need to know which layers exist
      // to generate the right tests — use the checklist for test selection
      final hasRemote = File(p.join(
        featurePath,
        'data',
        'datasources',
        '${featureName}_remote_datasource.dart',
      )).existsSync();
      final hasRepo = File(p.join(
        featurePath,
        'data',
        'repositories',
        '${featureName}_repository_impl.dart',
      )).existsSync();
      final hasNotifier = File(p.join(
        featurePath,
        'presentation',
        'notifiers',
        '${featureName}_notifier.dart',
      )).existsSync();
      final hasUseCase = File(p.join(
        featurePath,
        'domain',
        'usecases',
        'get_$featureName.dart',
      )).existsSync();

      final selected = <String>{
        if (hasRemote) _kRemoteDatasource,
        if (hasRepo) _kRepository,
        if (hasNotifier) _kStateNotifier,
        if (hasUseCase) _kUseCases,
      };

      _printTree(
        featureName,
        className,
        selected,
        includeUnit: false,
        includeIntegration: false,
        testsOnly: true,
      );
      _logger.info(
          'If you want tests, use the mogen_unit_tests and mogen_integration_tests package on pub.dev.');
      return 0;
    }

    // ── New feature ───────────────────────────────────────────────────────────

    // What this project talks to. The datasource is the one layer whose shape
    // depends on it: Dio and a REST path, or a Firestore collection.
    final context = ScaffoldContext.detect(p.dirname(p.absolute(libPath)));
    final hasDio = context.hasDio;
    final hasFirestore = context.hasFirestore;
    // Both installed → the user picks per feature. Only one → that one. None
    // detected → Dio, which is what every project scaffolded so far used.
    final bothBackends = hasDio && hasFirestore;
    var useFirestore = hasFirestore && !hasDio;

    // Layer checklist
    final skipChecklist = argResults?['all'] as bool? ?? false;

    late Set<String> selected;

    if (skipChecklist) {
      selected = {
        _kRemoteDatasource,
        _kLocalDatasource,
        _kRepository,
        _kUseCases,
        _kStateNotifier,
        _kView,
      };
    } else {
      try {
        selected = Checklist.prompt(
          title: '  Select layers for "$className":',
          items: [
            if (bothBackends) ...[
              const ChecklistItem(
                _kDioDatasource,
                defaultOn: true,
                description: 'Fetches data from an API via the Dio client.',
                excludes: {_kFirestoreDatasource},
              ),
              const ChecklistItem(
                _kFirestoreDatasource,
                defaultOn: false,
                description:
                    'Reads, writes and watches a Firestore collection.',
                excludes: {_kDioDatasource},
              ),
            ] else
              ChecklistItem(
                _kRemoteDatasource,
                defaultOn: true,
                description: useFirestore
                    ? 'Reads, writes and watches a Firestore collection.'
                    : 'Fetches data from an API via the Dio client.',
              ),
            const ChecklistItem(
              _kLocalDatasource,
              defaultOn: false,
              description: 'Cache fallback used when there is no connectivity.',
            ),
            const ChecklistItem(
              _kRepository,
              defaultOn: true,
              description:
                  'Interface + implementation combining the datasources.',
            ),
            const ChecklistItem(
              _kUseCases,
              defaultOn: false,
              description:
                  'Domain-layer use case wrapping the repository call.',
            ),
            const ChecklistItem(
              _kStateNotifier,
              defaultOn: true,
              description: 'Riverpod state + notifier for this feature.',
            ),
            const ChecklistItem(
              _kView,
              defaultOn: true,
              description: 'Basic Flutter view wired to the notifier.',
            ),
          ],
        );
      } on ChecklistCancelled {
        _logger.info('Cancelled — nothing was generated.');
        return 0;
      }
    }

    // Fold the backend-specific labels back into the canonical one, so
    // everything below only asks "is there a remote datasource?".
    if (selected.remove(_kFirestoreDatasource)) {
      selected.add(_kRemoteDatasource);
      useFirestore = true;
    }
    if (selected.remove(_kDioDatasource)) {
      selected.add(_kRemoteDatasource);
      useFirestore = false;
    }

    // The use case and notifier templates depend on the repository provider,
    // so generating them without it would produce broken imports.
    if ((selected.contains(_kUseCases) || selected.contains(_kStateNotifier)) &&
        !selected.contains(_kRepository)) {
      selected.add(_kRepository);
      _logger.info(
          '  Note: Repository layer added — Use Cases / Notifier depend on it.');
    }

    _logger.info('');
    _logger.info('🧱 Creating feature: $className');
    _logger.info('');

    // The model is only used by the datasources, and the entity only by the
    // repository/use case layers (and the model) — skip both when no data
    // layer was selected.
    final needsDataLayer = selected.contains(_kRemoteDatasource) ||
        selected.contains(_kLocalDatasource) ||
        selected.contains(_kRepository);

    final progress = _logger.progress('Scaffolding');
    FileUtils.beginSession();

    try {
      if (selected.contains(_kRemoteDatasource)) {
        await _writeRemoteDatasource(
          featurePath,
          featureName,
          className,
          varName,
          hasRepo: selected.contains(_kRepository),
          useFirestore: useFirestore,
        );
        if (useFirestore) {
          // The datasource imports the Firebase providers and the safe-call
          // wrapper. A project that took Firestore through `moarch init` has
          // both; one that added cloud_firestore by hand does not.
          await _ensureFirebaseFiles(libPath, context);
        }
      }
      if (selected.contains(_kLocalDatasource)) {
        await _writeLocalDatasource(
            featurePath, featureName, className, varName, libPath);
      }
      if (selected.contains(_kRepository)) {
        await _writeRepository(
          featurePath,
          featureName,
          className,
          varName,
          hasRemote: selected.contains(_kRemoteDatasource),
          hasLocal: selected.contains(_kLocalDatasource),
          useFirestore: useFirestore,
        );
      }
      if (needsDataLayer) {
        await _writeModel(featurePath, featureName, className,
            useFirestore: useFirestore);
        await _writeEntity(featurePath, featureName, className,
            useFirestore: useFirestore);
      }
      if (selected.contains(_kUseCases)) {
        await _writeUsecase(featurePath, featureName, className, varName);
      }
      if (selected.contains(_kStateNotifier)) {
        await _writeState(featurePath, featureName, className,
            useFirestore: useFirestore);
        await _writeNotifier(
          featurePath,
          featureName,
          className,
          varName,
          hasUseCase: selected.contains(_kUseCases),
          useFirestore: useFirestore,
        );
        // The state/notifier depend on the shared runAction helper — write it
        // if the project doesn't have it yet (writeFile never overwrites).
        await FileUtils.writeFile(
          p.join(libPath, 'core', 'utils', 'action_notifier.dart'),
          CoreTemplates.actionNotifier(),
        );
      }
      if (selected.contains(_kView)) {
        await _writeView(
          featurePath,
          featureName,
          className,
          varName,
          hasNotifier: selected.contains(_kStateNotifier),
          useFirestore: useFirestore,
        );
        if (selected.contains(_kStateNotifier)) {
          await _ensureViewWidgets(libPath);
        }
      }

      progress.complete('Feature scaffolded');
    } catch (e) {
      progress.fail('Failed: $e');
      FileUtils.rollback();
      _logger.info('  Rolled back partially generated files.');
      return 1;
    }

    _printTree(
      featureName,
      className,
      selected,
      includeUnit: false,
      includeIntegration: false,
    );
    if (useFirestore && selected.contains(_kRemoteDatasource)) {
      _logger.info(
          '  Firestore-backed — point `collectionPath` in ${featureName}_remote_datasource.dart');
      _logger.info('  at your collection, and check your security rules.');
      _logger.info('');
    }
    _logger.info(
        'If you want tests, use the mogen_unit_tests and mogen_integration_tests package on pub.dev.');
    return 0;
  }

  // ── Interactive prompt ────────────────────────────────────────────────────────

  /* bool _askYesNo(String question) {
    stdout.write(question);
    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    return input.isEmpty || input == 'y' || input == 'yes';
  }
*/
  // ── Writers ─────────────────────────────────────────────────────────────────

  /// Writes the kit widgets the generated view imports — [AppAsyncView] and the
  /// `listenAction` extension — along with everything they import in turn.
  ///
  /// They are part of `moarch init`, so a project scaffolded by this version
  /// already has them and nothing here writes anything ([FileUtils.writeFile]
  /// never overwrites). A project scaffolded by an older one does not, and a
  /// view importing a file that was never generated is the one way this command
  /// can hand back code that does not compile.
  Future<void> _ensureViewWidgets(String libPath) async {
    final projectRoot = p.dirname(p.absolute(libPath));
    final widgetsRoot = p.join(libPath, 'shared', 'widgets');
    final specs = WidgetCatalog.resolve(['async-view', 'action-listener']);
    final manifest = ProjectManifest.loadOrCreate(projectRoot);

    var wroteAny = false;
    final packages = <String>{};

    for (final spec in specs) {
      final content = spec.template();
      final path = p.join(widgetsRoot, spec.file);
      final wrote = await FileUtils.writeFile(path, content);
      if (!wrote) continue;
      // Recorded so `moarch update` can tell a file it wrote from one the user
      // has since edited. A file that was already there is left unrecorded:
      // its content is the user's, not ours to vouch for.
      manifest.record(projectRoot, path, content);
      packages.addAll(spec.packages);
      wroteAny = true;
    }

    if (!wroteAny) return;
    if (packages.isNotEmpty) {
      await PubspecUtils.ensureDependencies(
        projectRoot,
        dependencies: packages.toList(),
      );
    }
    await manifest.save(projectRoot);
  }

  /// Writes the Firebase files the Firestore datasource imports, for a project
  /// that has cloud_firestore but was never scaffolded with it.
  ///
  /// Mirrors [_ensureViewWidgets]: [FileUtils.writeFile] never overwrites, so
  /// a project that already has them is left exactly as it is.
  Future<void> _ensureFirebaseFiles(
    String libPath,
    ScaffoldContext context,
  ) async {
    final projectRoot = p.dirname(p.absolute(libPath));
    final manifest = ProjectManifest.loadOrCreate(projectRoot);

    final files = <String, String>{
      p.join(libPath, 'config', 'firebase', 'firebase_providers.dart'):
          ConfigTemplates.firebaseProviders(
        hasAuth: context.hasFirebaseAuth,
        hasDb: true,
      ),
      p.join(libPath, 'core', 'network', 'safe_firebase_call.dart'):
          CoreTemplates.safeFirebaseCall(withAuth: context.hasFirebaseAuth),
    };

    var wroteAny = false;
    for (final entry in files.entries) {
      if (!await FileUtils.writeFile(entry.key, entry.value)) continue;
      // Recorded so `moarch update` can tell a file it wrote from one the
      // user has since edited.
      manifest.record(projectRoot, entry.key, entry.value);
      wroteAny = true;
    }

    if (wroteAny) await manifest.save(projectRoot);

    // A project scaffolded with Firebase Auth but no Firestore has a providers
    // file with no firebaseDbProvider in it, and the file above was left alone
    // because it already existed — so the new datasource would not compile.
    final providersFile =
        File(p.join(libPath, 'config', 'firebase', 'firebase_providers.dart'));
    if (providersFile.existsSync() &&
        !providersFile.readAsStringSync().contains('firebaseDbProvider')) {
      _logger.warn(
          '  config/firebase/firebase_providers.dart has no firebaseDbProvider.');
      _logger.info('    Add it, or run: moarch update firebase-providers');
    }
  }

  Future<void> _writeRemoteDatasource(
      String fp, String name, String cls, String varName,
      {required bool hasRepo, bool useFirestore = false}) async {
    await FileUtils.writeFile(
      p.join(fp, 'data', 'datasources', '${name}_remote_datasource.dart'),
      FeatureTemplates.remoteDatasource(name, cls, varName,
          useFirestore: useFirestore),
    );
  }

  Future<void> _writeLocalDatasource(String fp, String name, String cls,
      String varName, String libPath) async {
    await FileUtils.writeFile(
      p.join(fp, 'data', 'datasources', '${name}_local_datasource.dart'),
      FeatureTemplates.localDatasource(name, cls, varName),
    );
    // CONN SERVICE
    final c = p.join(libPath, 'core');
    await FileUtils.writeFile(
      p.join(c, 'services', 'connectivity_service.dart'),
      ServicesTemplates.connectivityService(),
    );
  }

  Future<void> _writeRepository(
      String fp, String name, String cls, String varName,
      {required bool hasRemote,
      required bool hasLocal,
      bool useFirestore = false}) async {
    await FileUtils.writeFile(
      p.join(fp, 'domain', 'repositories', '${name}_repository.dart'),
      FeatureTemplates.repositoryInterface(name, cls,
          useFirestore: useFirestore),
    );
    await FileUtils.writeFile(
      p.join(fp, 'data', 'repositories', '${name}_repository_impl.dart'),
      FeatureTemplates.repositoryImpl(name, cls, varName,
          hasRemote: hasRemote, hasLocal: hasLocal, useFirestore: useFirestore),
    );
  }

  Future<void> _writeModel(String fp, String name, String cls,
      {bool useFirestore = false}) async {
    await FileUtils.writeFile(
      p.join(fp, 'data', 'models', '${name}_model.dart'),
      FeatureTemplates.model(name, cls, useFirestore: useFirestore),
    );
  }

  Future<void> _writeEntity(String fp, String name, String cls,
      {bool useFirestore = false}) async {
    await FileUtils.writeFile(
      p.join(fp, 'domain', 'entities', '${name}_entity.dart'),
      FeatureTemplates.entity(name, cls, useFirestore: useFirestore),
    );
  }

  Future<void> _writeUsecase(
    String fp,
    String name,
    String cls,
    String varName,
  ) async {
    await FileUtils.writeFile(
      p.join(fp, 'domain', 'usecases', 'get_$name.dart'),
      FeatureTemplates.usecase(name, cls, varName),
    );
  }

  Future<void> _writeState(String fp, String name, String cls,
      {bool useFirestore = false}) async {
    await FileUtils.writeFile(
      p.join(fp, 'presentation', 'states', '${name}_state.dart'),
      FeatureTemplates.state(name, cls, useFirestore: useFirestore),
    );
  }

  Future<void> _writeNotifier(
      String fp, String name, String cls, String varName,
      {required bool hasUseCase, bool useFirestore = false}) async {
    await FileUtils.writeFile(
      p.join(fp, 'presentation', 'notifiers', '${name}_notifier.dart'),
      FeatureTemplates.notifier(name, cls, varName,
          hasUseCase: hasUseCase, useFirestore: useFirestore),
    );
  }

  Future<void> _writeView(String fp, String name, String cls, String varName,
      {required bool hasNotifier, bool useFirestore = false}) async {
    await FileUtils.writeFile(
      p.join(fp, 'presentation', 'views', '${name}_view.dart'),
      FeatureTemplates.view(name, cls, varName,
          hasNotifier: hasNotifier, useFirestore: useFirestore),
    );
  }

  // ── Tree summary ─────────────────────────────────────────────────────────────

  void _printTree(
    String name,
    String cls,
    Set<String> selected, {
    bool includeUnit = true,
    bool includeIntegration = true,
    bool testsOnly = false,
  }) {
    _logger.success('');
    /* _logger.success(testsOnly
        ? '✅  Tests generated for $cls'
        : '✅  $cls created at lib/features/$name/');
    _logger.info('');*/

    void line(String s) => _logger.info('  $s');

    final hasDataLayer = selected.contains(_kRemoteDatasource) ||
        selected.contains(_kLocalDatasource) ||
        selected.contains(_kRepository);

    if (!testsOnly) {
      if (hasDataLayer || selected.contains(_kUseCases)) {
        line('domain/');
        if (hasDataLayer) {
          line('├── entities/${name}_entity.dart');
        }
        if (selected.contains(_kRepository)) {
          line('├── repositories/${name}_repository.dart');
        }
        if (selected.contains(_kUseCases)) {
          line('└── usecases/get_$name.dart');
        }
      }

      if (hasDataLayer) {
        line('data/');
        if (selected.contains(_kRemoteDatasource)) {
          line('├── datasources/${name}_remote_datasource.dart');
        }
        if (selected.contains(_kLocalDatasource)) {
          line('├── datasources/${name}_local_datasource.dart');
        }
        line('├── models/${name}_model.dart');
        if (selected.contains(_kRepository)) {
          line('└── repositories/${name}_repository_impl.dart');
        }
      }

      line('presentation/');
      if (selected.contains(_kStateNotifier)) {
        line('├── states/${name}_state.dart');
        line('├── notifiers/${name}_notifier.dart');
      }
      if (selected.contains(_kView)) {
        line('└── views/${name}_view.dart');
      }
      line('');
    }

    _logger.info('');
  }
}
