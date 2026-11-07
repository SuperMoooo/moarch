import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../l10n/string_extractor.dart';
import '../utils/scaffold_catalog.dart';

/// `moarch l10n` — the project's translations.
class L10nCommand extends Command<int> {
  /// Creates the l10n command and its subcommands.
  L10nCommand({required Logger logger}) : _logger = logger {
    addSubcommand(ExtractCommand(logger: logger));
  }

  final Logger _logger;

  @override
  String get name => 'l10n';

  @override
  String get description => 'Work with the translation files.';

  @override
  Future<int> run() async {
    _logger.info(usage);
    return 0;
  }
}

/// Where a project keeps its translations and how a screen reads one.
class _Setup {
  const _Setup({
    required this.accessor,
    required this.sourceFile,
    required this.otherFiles,
    required this.import,
    this.nullableGetter = true,
    this.className = 'AppLocalizations',
    this.generatedFile,
  });

  final L10nAccessor accessor;

  /// The source language's file: the `.arb` template, or `en.json`.
  final File sourceFile;

  /// The other languages' files.
  final List<File> otherFiles;

  /// What a rewritten file imports: a path under `lib/` for the generated
  /// class, a package URI for easy_localization.
  final String import;
  final bool nullableGetter;
  final String className;

  /// The generated localizations file, under `lib/`, for relative imports.
  final String? generatedFile;
}

/// `moarch l10n extract` — hard-coded UI strings into the translation files.
class ExtractCommand extends Command<int> {
  /// Creates the extract command.
  ExtractCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption('path', abbr: 'p', defaultsTo: '.', help: 'The project root.')
      ..addFlag(
        'dry-run',
        abbr: 'd',
        negatable: false,
        help: 'List what would change without writing anything.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'extract';

  @override
  String get description =>
      'Move hard-coded strings in screens (Text, labels, hints, titles) into '
      'the translation files, and read them back by key.';

  @override
  Future<int> run() async {
    final root = p.absolute(argResults?['path'] as String? ?? '.');
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final context = ScaffoldContext.detect(root);

    final setup = _setupOf(root, context);
    if (setup == null) {
      _logger.err(
        'No localization found: neither l10n.yaml (flutter_localizations) '
        'nor assets/translations/ (easy_localization).',
      );
      return 1;
    }

    final existing = _read(setup.sourceFile);
    final added = <String, String>{};
    final skipped = <String>[];
    final rewrites = <File, Map<int, String>>{};

    for (final file in _screens(root)) {
      final source = file.readAsStringSync();
      final display = p.relative(file.path, from: root).replaceAll(r'\', '/');
      for (final found in StringExtractor.find(source)) {
        final where = '$display:${found.line}';
        if (!found.rewritable) {
          skipped.add('$where  "${found.text}" — ${found.skipReason}');
          continue;
        }
        if (setup.accessor == L10nAccessor.generated &&
            found.contextName == null) {
          skipped.add(
            '$where  "${found.text}" — no BuildContext in scope; pass one in '
            'or move the string into build()',
          );
          continue;
        }
        final key = L10nKeys.assign(found.text, {...existing, ...added});
        if (!existing.containsKey(key)) added[key] = found.text;
        (rewrites[file] ??= {})[found.offset] = key;
        _logger.info('  $where  "${found.text}" → $key');
      }
    }

    if (rewrites.isEmpty) {
      _logger.info('No hard-coded strings to move.');
      _report(skipped);
      return 0;
    }

    if (dryRun) {
      _logger.info('');
      _logger.info(
        'Dry run: ${added.length} keys would be added to '
        '${p.basename(setup.sourceFile.path)}, '
        '${rewrites.length} files rewritten.',
      );
      _report(skipped);
      return 0;
    }

    _write(setup.sourceFile, added);
    for (final other in setup.otherFiles) {
      // The source text, so the language still builds; the list below says
      // what to translate.
      _write(other, added);
    }
    rewrites.forEach((file, keys) {
      final import = setup.accessor == L10nAccessor.generated
          ? p
                .relative(
                  p.join(root, 'lib', setup.generatedFile!),
                  from: p.dirname(file.path),
                )
                .replaceAll(r'\', '/')
          : setup.import;
      file.writeAsStringSync(
        StringExtractor.rewrite(
          file.readAsStringSync(),
          keys,
          accessor: setup.accessor,
          import: import,
          nullableGetter: setup.nullableGetter,
          className: setup.className,
        ),
      );
    });

    _logger.info('');
    _logger.success(
      '✓ ${added.length} keys added to ${p.basename(setup.sourceFile.path)}, '
      '${rewrites.length} files rewritten.',
    );
    if (setup.otherFiles.isNotEmpty && added.isNotEmpty) {
      _logger.warn(
        '  Translate them in '
        '${setup.otherFiles.map((f) => p.basename(f.path)).join(', ')}: '
        'they hold the source text for now.',
      );
    }
    _report(skipped);
    if (setup.accessor == L10nAccessor.generated) {
      _logger.info('Next: fvm flutter gen-l10n, then fvm dart format .');
    } else {
      _logger.info('Next: fvm dart format .');
    }
    return 0;
  }

  void _report(List<String> skipped) {
    if (skipped.isEmpty) return;
    _logger.info('');
    _logger.warn('Left as they are (${skipped.length}):');
    for (final line in skipped) {
      _logger.info('  $line');
    }
  }

  /// The screens: each feature's presentation layer and `shared/views/`.
  /// The UI kit is moarch's to refresh, so it is left out.
  Iterable<File> _screens(String root) sync* {
    final dirs = <Directory>[
      Directory(p.join(root, 'lib', 'shared', 'views')),
      ...switch (Directory(p.join(root, 'lib', 'features'))) {
        final features when features.existsSync() =>
          features.listSync().whereType<Directory>().map(
            (f) => Directory(p.join(f.path, 'presentation')),
          ),
        _ => const <Directory>[],
      },
    ];
    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart') ||
            entity.path.endsWith('.freezed.dart')) {
          continue;
        }
        yield entity;
      }
    }
  }

  _Setup? _setupOf(String root, ScaffoldContext context) {
    final l10nYaml = File(p.join(root, 'l10n.yaml'));
    if (l10nYaml.existsSync()) {
      final config = loadYaml(l10nYaml.readAsStringSync());
      String option(String key, String fallback) =>
          config is YamlMap && config[key] != null
          ? '${config[key]}'
          : fallback;
      final arbDir = option('arb-dir', 'lib/l10n');
      final template = option('template-arb-file', 'app_en.arb');
      final outputFile = option(
        'output-localization-file',
        'app_localizations.dart',
      );
      final outputDir = option('output-dir', arbDir);
      final dir = Directory(p.join(root, arbDir));
      final source = File(p.join(dir.path, template));
      if (!source.existsSync()) return null;
      final generated = p
          .relative(
            p.join(root, outputDir, outputFile),
            from: p.join(root, 'lib'),
          )
          .replaceAll(r'\', '/');
      return _Setup(
        accessor: L10nAccessor.generated,
        sourceFile: source,
        otherFiles: [
          for (final f in dir.listSync().whereType<File>())
            if (f.path.endsWith('.arb') && p.basename(f.path) != template) f,
        ],
        import: generated,
        generatedFile: generated,
        nullableGetter: option('nullable-getter', 'true') != 'false',
        className: option('output-class', 'AppLocalizations'),
      );
    }

    final translations = Directory(p.join(root, 'assets', 'translations'));
    if (translations.existsSync()) {
      final files =
          translations
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      if (files.isEmpty) return null;
      final source = files.firstWhere(
        (f) => p.basenameWithoutExtension(f.path).startsWith('en'),
        orElse: () => files.first,
      );
      return _Setup(
        accessor: L10nAccessor.easyLocalization,
        sourceFile: source,
        otherFiles: [
          for (final f in files)
            if (f.path != source.path) f,
        ],
        import: 'package:easy_localization/easy_localization.dart',
      );
    }
    return null;
  }

  /// The flat string entries of a translation file — ARB metadata (`@key`)
  /// and nested easy_localization groups are not keys a screen reads here.
  Map<String, String> _read(File file) {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return {};
    return {
      for (final entry in decoded.entries)
        if (entry.value is String && !'${entry.key}'.startsWith('@'))
          '${entry.key}': entry.value as String,
    };
  }

  void _write(File file, Map<String, String> added) {
    if (added.isEmpty) return;
    final decoded = jsonDecode(file.readAsStringSync());
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    added.forEach((key, value) => map.putIfAbsent(key, () => value));
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(map)}\n',
    );
  }
}
