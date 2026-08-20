import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../utils/model_field_parser.dart';
import '../../utils/project_paths.dart';
import '../../utils/string_utils.dart';

/// Injects `copyWith`, `==` and `hashCode` into every entity file in a feature
/// (or all features).
class CreateEntityCopysCommand extends Command<int> {
  /// Injects `copyWith`, `==` and `hashCode` into every entity file in a
  /// feature (or all features).
  CreateEntityCopysCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'path',
      abbr: 'p',
      defaultsTo: 'lib',
      help: 'Path to the lib/ directory, or the project root holding it.',
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
  String get name => 'entity-copys';

  @override
  String get description =>
      'Inject copyWith, == and hashCode into every *_entity.dart in a feature (or all features).';

  @override
  String get invocation => 'moarch create entity-copys [feature_name]';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    final libPath = resolveLibPath(argResults?['path'] as String? ?? 'lib');
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
    } else {
      _logger.success('  Patched : $patched');

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
    final relativePath =
        file.path.replaceAll(RegExp(r'^.*[/\\]lib[/\\]'), 'lib/');

    try {
      String source = await file.readAsString();
      final fileName = p.basenameWithoutExtension(file.path);
      final className = StringUtils.toPascalCase(fileName);

      final fields = ModelFieldParser.parse(source, className);
      final newCopyWith = ModelFieldParser.buildCopyWith(className, fields);
      final newEquality = ModelFieldParser.buildEquality(className, fields);

      // Regex to find an existing copyWith method (block or arrow body)
      final copyWithPattern = RegExp(
        RegExp.escape(className) +
            r'\s+copyWith\s*\([^)]*\)\s*(?:=>\s*[^;]*;|\{.*?\n  \})',
        dotAll: true,
      );

      final actions = <String>[];

      String updated;
      if (copyWithPattern.hasMatch(source)) {
        // Replace existing
        updated = source.replaceFirst(copyWithPattern, newCopyWith.trim());
        actions.add('replaced copyWith');
      } else {
        updated = _appendToClass(source, className, newCopyWith);
        actions.add('injected copyWith');
      }

      // Strip any existing == / hashCode, then append the freshly built pair.
      // Scoped to this class: a second class in the same file keeps its own.
      var hadEquality = false;
      updated = _editClassBody(updated, className, (body) {
        hadEquality =
            _equalityPattern.hasMatch(body) || _hashCodePattern.hasMatch(body);
        return body
            .replaceAll(_equalityPattern, '')
            .replaceAll(_hashCodePattern, '');
      });
      updated = _appendToClass(updated, className, newEquality);
      actions
          .add(hadEquality ? 'replaced ==/hashCode' : 'injected ==/hashCode');

      _logger.info('  ✨  $relativePath (${actions.join(', ')})');

      if (dryRun) return _Result.patched;

      await file.writeAsString(updated);
      return _Result.patched;
    } catch (e) {
      _logger.err('  ✗  $relativePath — $e');
      return _Result.failed;
    }
  }

  /// Inserts [member] at the end of [className]'s body.
  ///
  /// Falls back to the file's last closing brace when the class can't be
  /// located — which is where a single-class entity file ends anyway.
  static String _appendToClass(
    String source,
    String className,
    String member,
  ) {
    final closing = ModelFieldParser.classBody(source, className)?.end ??
        source.lastIndexOf('}');
    if (closing == -1) throw Exception('Could not find closing brace');
    return source.substring(0, closing) + member + source.substring(closing);
  }

  /// Applies [edit] to [className]'s body alone, leaving the rest of the file
  /// — including any other class in it — untouched.
  static String _editClassBody(
    String source,
    String className,
    String Function(String body) edit,
  ) {
    final range = ModelFieldParser.classBody(source, className);
    if (range == null) return edit(source);
    return source.replaceRange(
      range.start,
      range.end,
      edit(source.substring(range.start, range.end)),
    );
  }
}

/// Matches an existing `operator ==` (arrow or block body), with its
/// `@override` annotation when present.
final _equalityPattern = RegExp(
  r'\n*[ \t]*(?:@override\s*\n[ \t]*)?bool\s+operator\s*==\s*\(\s*Object\s+\w+\s*\)\s*(?:=>[^;]*;|\{.*?\n[ \t]*\})',
  dotAll: true,
);

/// Matches an existing `hashCode` getter (arrow or block body), with its
/// `@override` annotation when present.
final _hashCodePattern = RegExp(
  r'\n*[ \t]*(?:@override\s*\n[ \t]*)?int\s+get\s+hashCode\s*(?:=>[^;]*;|\{.*?\n[ \t]*\})',
  dotAll: true,
);

enum _Result { patched, failed }
