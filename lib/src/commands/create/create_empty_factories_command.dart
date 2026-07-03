import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../utils/model_field_parser.dart';
import '../../utils/string_utils.dart';

/// Injects `.empty()` factories into every entity file in a feature (or all features).
class CreateEmptyFactoriesCommand extends Command<int> {
  ///  Injects `.empty()` factories into every entity file in a feature (or all features).
  CreateEmptyFactoriesCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'path',
      abbr: 'p',
      defaultsTo: 'lib',
      help: 'Path to lib/ directory.',
    );
    argParser.addFlag(
      'dry-run',
      abbr: 'd',
      negatable: false,
      help: 'Preview what would be changed without writing any files.',
    );
  }

  final Logger _logger;

  @override
  String get name => 'empty-factories';

  @override
  String get description =>
      'Inject .empty() factories into every *_entity.dart in a feature (or all features).';

  @override
  String get invocation => 'moarch create empty-factories [feature_name]';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    final libPath = argResults?['path'] as String? ?? 'lib';
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final featuresDir = Directory(p.join(libPath, 'features'));

    if (!featuresDir.existsSync()) {
      _logger.err('No features/ directory found at ${featuresDir.path}.');
      return 1;
    }

    // Collect target feature dirs
    final List<Directory> featureDirs;
    if (rest.isNotEmpty) {
      final name = StringUtils.toSnakeCase(rest[0]);
      final dir = Directory(p.join(featuresDir.path, name));
      if (!dir.existsSync()) {
        _logger.err('Feature "$name" not found at ${dir.path}.');
        return 1;
      }
      featureDirs = [dir];
    } else {
      featureDirs = featuresDir.listSync().whereType<Directory>().toList();
    }

    if (dryRun) {
      _logger.info('');
      _logger.warn('Dry run — no files will be modified.');
      _logger.info('');
    }

    int patched = 0;
    int skipped = 0;
    int failed = 0;

    for (final featureDir in featureDirs) {
      final entityDir = Directory(
        p.join(featureDir.path, 'domain', 'entities'),
      );
      if (!entityDir.existsSync()) continue;

      final entityFiles = entityDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_entity.dart'))
          .toList();

      if (entityFiles.isEmpty) continue;

      final featureName = p.basename(featureDir.path);
      _logger.info('📦 $featureName');

      for (final file in entityFiles) {
        final result = await _processEntity(
          file: file,
          dryRun: dryRun,
        );
        switch (result) {
          case _Result.patched:
            patched++;
          case _Result.skipped:
            skipped++;
          case _Result.failed:
            failed++;
        }
      }
      _logger.info('');
    }

    // Summary
    _logger.info('─' * 40);
    if (dryRun) {
      _logger.info('  Would patch : $patched');
      _logger.info('  Already done: $skipped');
    } else {
      _logger.success('  Patched : $patched');
      if (skipped > 0) {
        _logger.info('  Skipped : $skipped (already have .empty())');
      }

      if (failed > 0) {
        _logger.err('  Failed  : $failed');
      }
    }
    _logger.info('');

    return failed > 0 ? 1 : 0;
  }

  Future<_Result> _processEntity({
    required File file,
    required bool dryRun,
  }) async {
    final relativePath = file.path.replaceAll(RegExp(r'^.*/lib/'), 'lib/');

    try {
      String source = await file.readAsString();
      final fileName = p.basenameWithoutExtension(file.path);
      final className = StringUtils.toPascalCase(fileName);

      final fields = ModelFieldParser.parse(source, className);
      final newFactory = ModelFieldParser.buildEmptyFactory(className, fields);

      // Regex to find an existing factory .empty()
      final factoryPattern = RegExp(
        r'factory\s+' + RegExp.escape(className) + r'\.empty\(\)\s*=>\s*.*?;',
        dotAll: true,
      );

      String updated;
      if (source.contains('factory $className.empty(')) {
        // Replace existing
        updated = source.replaceFirst(factoryPattern, newFactory.trim());
        _logger.info('  🔄  $relativePath (replaced existing .empty())');
      } else {
        // Append new
        final lastBrace = source.lastIndexOf('}');
        if (lastBrace == -1) throw Exception('Could not find closing brace');
        updated = source.substring(0, lastBrace) +
            newFactory +
            source.substring(lastBrace);
        _logger.info('  ✨  $relativePath (injected new .empty())');
      }

      if (dryRun) return _Result.patched;

      await file.writeAsString(updated);
      return _Result.patched;
    } catch (e) {
      _logger.err('  ✗  $relativePath — $e');
      return _Result.failed;
    }
  }
}

enum _Result { patched, skipped, failed }
