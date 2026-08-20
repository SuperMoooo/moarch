import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../templates/stack_templates.dart';
import '../../utils/file_utils.dart';
import '../../utils/injector_utils.dart';
import '../../utils/project_paths.dart';
import '../../utils/state_management.dart';
import '../../utils/string_utils.dart';

/// Adds one state + event + bloc trio to a feature that already exists.
///
/// `create feature` scaffolds a whole feature; this is for the second screen
/// in one — a detail bloc beside the list bloc — where the repository and the
/// data layer are already there and only the presentation side is missing.
class CreateBlocCommand extends Command<int> {
  /// Creates the bloc generator command.
  CreateBlocCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: 'lib',
        help: 'Path to the lib/ directory, or the project root holding it.',
      )
      ..addFlag(
        'firestore',
        negatable: false,
        help: 'Generate the live-collection variant (watchAll + snapshots).',
      );
  }

  final Logger _logger;

  @override
  String get name => 'bloc';

  @override
  String get description =>
      'Add a state + event + bloc trio to an existing feature.';

  @override
  String get invocation => 'moarch create bloc <featureName> <blocName>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.length < 2) {
      _logger.err('Provide a feature and a name.\n'
          '  Usage: moarch create bloc <featureName> <blocName>');
      return 1;
    }

    final libPath = resolveLibPath(argResults?['path'] as String? ?? 'lib');
    final stateManagement = StateManagement.detect(libPath);

    // A Riverpod project has no bloc to add. Say what it does have rather
    // than generating a file nothing in the project can wire up.
    if (!stateManagement.isBloc) {
      _logger.err('This project uses Riverpod, not flutter_bloc.');
      _logger.info('  `moarch create feature <name>` generates a state + '
          'notifier pair,');
      _logger.info('  and `moarch init` is where the stack is chosen.');
      return 1;
    }

    final templates = StackTemplates(stateManagement);
    final featureName = StringUtils.toSnakeCase(rest[0]);
    final blocName = StringUtils.toSnakeCase(rest[1]);
    final className = StringUtils.toPascalCase(rest[1]);
    final varName = StringUtils.toCamelCase(rest[1]);

    final featurePath = p.join(libPath, 'features', featureName);
    if (!Directory(featurePath).existsSync()) {
      _logger.err('No feature at $featurePath.');
      _logger.info('  Create it first: moarch create feature $featureName');
      return 1;
    }

    final blocFile = p.join(
      featurePath,
      'presentation',
      'blocs',
      templates.holderFile(blocName),
    );
    if (File(blocFile).existsSync()) {
      _logger.err('${className}Bloc already exists at '
          '${p.relative(blocFile, from: p.dirname(p.absolute(libPath)))}.');
      return 1;
    }

    // The bloc takes the feature's repository, which is what makes this an
    // addition to a feature rather than a feature of its own.
    final featureClass = StringUtils.toPascalCase(featureName);
    final repositoryFile = File(p.join(
      featurePath,
      'domain',
      'repositories',
      '${featureName}_repository.dart',
    ));
    final hasRepository = repositoryFile.existsSync();

    // The live variant is built on the repository's `watchAll()`, so it is
    // only available when the feature actually declares one — asked for or
    // not. Generating it against a repository without it produces a bloc that
    // does not compile, and the reason would not be obvious.
    final repositoryWatches = hasRepository &&
        repositoryFile.readAsStringSync().contains('watchAll(');
    final wantsFirestore = argResults?['firestore'] as bool? ?? false;

    if (wantsFirestore && !repositoryWatches) {
      _logger.err('$featureName\'s repository has no watchAll(), so there is '
          'no live query to build on.');
      _logger.info('  Add `Stream<${featureClass}Entity> watchAll();` to it '
          '(and implement it in the');
      _logger.info('  repository and datasource), or drop --firestore for the '
          'one-off variant.');
      return 1;
    }

    final useFirestore = repositoryWatches && wantsFirestore;

    // The placeholder's fake ids have to be the type the entity actually
    // declares, which is not always what the backend suggests: a feature
    // generated against REST keys on an int even once a live query is added.
    final entityFile = File(p.join(
      featurePath,
      'domain',
      'entities',
      '${featureName}_entity.dart',
    ));
    final entityIdIsString = entityFile.existsSync() &&
        RegExp(r'final\s+String\s+id\s*;')
            .hasMatch(entityFile.readAsStringSync());

    _logger.info('');
    _logger.info('🧱 Creating bloc: ${className}Bloc in $featureName');
    _logger.info('');

    final progress = _logger.progress('Scaffolding');
    FileUtils.beginSession();

    var registered = false;

    try {
      await FileUtils.writeFile(
        p.join(featurePath, 'presentation', templates.stateDir,
            '${blocName}_state.dart'),
        templates.featureState(
          blocName,
          className,
          useFirestore: useFirestore,
          // The feature's entity, for the same reason as the repository: a
          // second screen lists what the feature is made of.
          entityName: featureName,
          entityClass: featureClass,
          entityIdIsString: entityIdIsString,
        ),
      );
      await FileUtils.writeFile(
        p.join(featurePath, 'presentation', 'blocs', '${blocName}_event.dart'),
        templates.featureEvent(
          blocName,
          className,
          useFirestore: useFirestore,
          entityName: featureName,
          entityClass: featureClass,
        ),
      );
      await FileUtils.writeFile(
        blocFile,
        templates.featureHolder(
          blocName,
          className,
          varName,
          useFirestore: useFirestore,
          // The feature's repository, not one named after this bloc: a
          // second screen in a feature reads the same data layer.
          repositoryName: featureName,
          repositoryClass: featureClass,
        ),
      );
      if (hasRepository) {
        registered = await InjectorUtils.register(
          libPath,
          className: className,
          registrations:
              '''  // ── $className ${'─' * (56 - className.length).clamp(3, 56)}
  // A factory, not a singleton: the screen's BlocProvider creates it and
  // closing the route closes it, subscriptions and all.
  getIt.registerFactory<${className}Bloc>(
    () => ${className}Bloc(getIt<${featureClass}Repository>()),
  );''',
          imports: [
            "import '../../features/$featureName/domain/repositories/${featureName}_repository.dart';",
            "import '../../features/$featureName/presentation/blocs/${blocName}_bloc.dart';",
          ],
        );
      }

      progress.complete('Bloc scaffolded');
    } catch (e) {
      progress.fail('Failed: $e');
      FileUtils.rollback();
      _logger.info('  Rolled back partially generated files.');
      return 1;
    }

    _logger.success('');
    _logger.info('  features/$featureName/presentation/');
    _logger.info('  ├── blocs/${blocName}_state.dart');
    _logger.info('  ├── blocs/${blocName}_event.dart');
    _logger.info('  └── blocs/${blocName}_bloc.dart');
    _logger.info('');

    if (registered) {
      _logger.info('  Registered in ${InjectorUtils.path}.');
    } else if (!hasRepository) {
      // The bloc's constructor names a repository the feature does not have,
      // so it cannot be registered until that exists.
      _logger.warn('  $featureName has no repository, so ${className}Bloc was '
          'not registered.');
      _logger.info('  Point its constructor at whatever it should depend on, '
          'then register');
      _logger.info('  it in ${InjectorUtils.path}.');
    } else {
      _logger
          .warn('  Nothing was registered in ${InjectorUtils.path} — register');
      _logger.info('  ${className}Bloc there yourself, or put back the '
          '`${InjectorUtils.anchor}`');
      _logger.info('  comment.');
    }
    _logger.info('');
    return 0;
  }
}
