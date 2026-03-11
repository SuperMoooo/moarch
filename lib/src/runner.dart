import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'commands/create_command.dart';
import 'commands/init_command.dart';

class MoarchRunner {
  MoarchRunner()
    : _logger = Logger(),
      _runner = CommandRunner<int>(
        'moarch',
        '🧱 moarch — Flutter scaffold CLI with Clean Architecture & Riverpod',
      ) {
    _runner
      ..addCommand(InitCommand(logger: _logger))
      ..addCommand(CreateCommand(logger: _logger));

    _runner.argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the current version.',
    );
  }

  final Logger _logger;
  final CommandRunner<int> _runner;

  Future<int> run(List<String> args) async {
    try {
      final argResults = _runner.parse(args);

      if (argResults['version'] == true) {
        _logger.info('moarch v0.1.0');
        return 0;
      }

      return await _runner.runCommand(argResults) ?? 0;
    } on UsageException catch (e) {
      _logger.err(e.message);
      _logger.info(e.usage);
      return 1;
    } catch (e) {
      _logger.err('Unexpected error: $e');
      return 1;
    }
  }
}
