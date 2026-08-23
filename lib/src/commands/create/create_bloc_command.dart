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
    argParser.addOption(
      'path',
      abbr: 'p',
      defaultsTo: 'lib',
      help: 'Path to the lib/ directory, or the project root holding it.',
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
        templates.featureState(blocName, className),
      );
      await FileUtils.writeFile(
        p.join(featurePath, 'presentation', 'blocs', '${blocName}_event.dart'),
        templates.featureEvent(blocName, className),
      );
      await FileUtils.writeFile(
        blocFile,
        templates.featureHolder(
          blocName,
          className,
          varName,
          hasRepository: hasRepository,
          // The feature's repository, not one named after this bloc: a
          // second screen in a feature reads the same data layer.
          repositoryName: featureName,
          repositoryClass: featureClass,
        ),
      );
      registered = await InjectorUtils.register(
        libPath,
        className: className,
        registrations: InjectorUtils.registrationsFor(
          featureName: featureName,
          className: className,
          hasRemote: false,
          hasLocal: false,
          hasRepository: false,
          hasBloc: true,
          useFirestore: false,
          // The feature's repository, which this bloc shares rather than
          // declaring a data layer of its own.
          blocRepositoryClass: hasRepository ? featureClass : null,
        ),
        imports: [
          if (hasRepository)
            "import '../../features/$featureName/domain/repositories/${featureName}_repository.dart';",
          "import '../../features/$featureName/presentation/blocs/${blocName}_bloc.dart';",
        ],
      );

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
      if (!hasRepository) {
        // Nothing to take, so it was registered taking nothing. Say so — the
        // alternative is finding out from a constructor that does not match.
        _logger.info('  $featureName has no repository, so ${className}Bloc '
            'takes nothing yet.');
      }
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
