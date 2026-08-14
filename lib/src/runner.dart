import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'commands/create_command.dart';
import 'commands/doctor_command.dart';
import 'commands/init_command.dart';
import 'commands/update_command.dart';
import 'version.dart';

/// Runs the CLI entry point and command parsing.
class MoarchRunner {
  /// Creates the CLI runner used to parse and execute subcommands.
  MoarchRunner()
      : _logger = Logger(),
        _runner = CommandRunner<int>(
          'moarch',
          '🧱 moarch — Flutter scaffold CLI with Clean Architecture, '
              'Riverpod or flutter_bloc',
        ) {
    _runner
      ..addCommand(InitCommand(logger: _logger))
      ..addCommand(CreateCommand(logger: _logger))
      ..addCommand(UpdateCommand(logger: _logger))
      ..addCommand(DoctorCommand(logger: _logger));

    _runner.argParser
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the current version.',
      )
      ..addFlag(
        'verbose',
        negatable: false,
        help: 'Print stack traces on unexpected errors.',
      );
  }

  final Logger _logger;
  final CommandRunner<int> _runner;

  /// Executes the CLI command for the provided arguments.
  Future<int> run(List<String> args) async {
    final verbose = args.contains('--verbose');

    try {
      final argResults = _runner.parse(args);

      if (argResults['version'] == true) {
        _logger.info('moarch v$packageVersion');
        return 0;
      }

      return await _runner.runCommand(argResults) ?? 0;
    } on UsageException catch (e) {
      _logger.err(e.message);
      _logger.info(e.usage);
      return 1;
    } catch (e, stackTrace) {
      _logger.err('Unexpected error: $e');
      if (verbose) {
        _logger.err(stackTrace.toString());
      } else {
        _logger.info('Run with --verbose for a stack trace.');
      }
      return 1;
    }
  }
}
