import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

/// Sanity-checks an existing project previously scaffolded by moarch.
class DoctorCommand extends Command<int> {
  /// Creates the doctor command.
  DoctorCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'path',
      abbr: 'p',
      help: 'Target project path (defaults to current directory).',
      defaultsTo: '.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check an existing project for common scaffolding issues.';

  @override
  Future<int> run() async {
    final targetPath = p.absolute(argResults?['path'] as String? ?? '.');
    final libPath = p.join(targetPath, 'lib');

    _logger.info('');
    _logger.info('🩺 moarch doctor — checking $targetPath');
    _logger.info('');

    var issues = 0;

    issues += _check(
      Directory(p.join(libPath, 'core')).existsSync(),
      'lib/core/ exists',
    );
    issues += _check(
      Directory(p.join(libPath, 'config')).existsSync(),
      'lib/config/ exists',
    );
    issues += _check(
      Directory(p.join(libPath, 'shared')).existsSync(),
      'lib/shared/ exists',
    );
    issues += _check(
      File(p.join(libPath, 'main.dart')).existsSync(),
      'lib/main.dart exists',
    );
    issues += _check(
      File(p.join(targetPath, 'pubspec.yaml')).existsSync(),
      'pubspec.yaml exists',
    );
    issues += _check(
      File(p.join(targetPath, '.env')).existsSync(),
      '.env exists',
    );
    issues += _check(
      File(p.join(targetPath, '.fvmrc')).existsSync(),
      '.fvmrc exists',
    );

    final pubspecFile = File(p.join(targetPath, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      final pubspec = pubspecFile.readAsStringSync();

      issues += _check(
        pubspec.contains('flutter_riverpod:'),
        'flutter_riverpod dependency present',
      );
      issues += _check(
        pubspec.contains('envied:'),
        'envied dependency present',
      );

      final hasRouterDep = pubspec.contains('go_router:');
      final hasRouterFiles = File(
        p.join(libPath, 'config', 'router', 'app_router.dart'),
      ).existsSync();
      if (hasRouterDep != hasRouterFiles) {
        issues++;
        _logger.err(
          '  ✗  go_router dependency and config/router/ files are out of sync',
        );
      }
    }

    final featuresDir = Directory(p.join(libPath, 'features'));
    if (!featuresDir.existsSync() || featuresDir.listSync().isEmpty) {
      _logger.warn(
        '  !  No features generated yet — run: moarch create feature <name>',
      );
    }

    _logger.info('');
    if (issues == 0) {
      _logger.success('No issues found.');
      return 0;
    }
    _logger.err('$issues issue(s) found.');
    return 1;
  }

  int _check(bool ok, String label) {
    if (ok) {
      _logger.info('  ✓  $label');
      return 0;
    }
    _logger.err('  ✗  $label');
    return 1;
  }
}
