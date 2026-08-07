import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../utils/project_inspector.dart';
import '../utils/project_manifest.dart';
import '../utils/scaffold_catalog.dart';
import '../utils/text_diff.dart';
import '../utils/widget_catalog.dart';
import '../version.dart';

/// What refreshing one generated file would mean.
enum UpdateStatus {
  /// On disk already matches the current template.
  upToDate,

  /// moarch wrote it, nobody edited it, and the template has since changed.
  /// Safe to overwrite.
  stale,

  /// The template changed *and* the file was edited after generation.
  /// Overwriting would discard the user's work.
  conflicted,

  /// The template changed but there is no record of what moarch wrote, so
  /// edits can't be ruled out. Treated as [conflicted] for safety.
  unknown,
}

/// The category widget-kit candidates report under.
const String _kWidgetCategory = 'Widgets';

/// The group slug that selects the whole widget kit.
const String _kWidgetGroup = 'widgets';

/// One generated file considered by `moarch update`.
class UpdateCandidate {
  /// Creates a candidate.
  const UpdateCandidate({
    required this.name,
    required this.title,
    required this.category,
    required this.displayPath,
    required this.path,
    required this.status,
    required this.current,
    required this.generated,
  });

  /// The CLI slug that selects this file on its own, e.g. `validation`.
  final String name;

  /// Human-facing name of what the file holds, e.g. `ValidationService`.
  final String title;

  /// Grouping, and the group slug's label.
  final String category;

  /// Project-relative path with forward slashes, as printed.
  final String displayPath;

  /// Absolute path to the file on disk.
  final String path;

  /// What updating it would mean.
  final UpdateStatus status;

  /// The file's current content.
  final String current;

  /// What the current template would write.
  final String generated;

  /// Whether this file can be refreshed without losing user edits.
  bool get isSafe => status == UpdateStatus.stale;

  /// Whether refreshing risks discarding edits.
  bool get needsDecision =>
      status == UpdateStatus.conflicted || status == UpdateStatus.unknown;
}

/// Refreshes generated files against the running moarch version's templates.
///
/// The manifest written at generation time tells an untouched file from an
/// edited one: untouched files refresh silently, edited ones are never
/// overwritten without an explicit choice.
///
/// Addressable per file (`moarch update validation`) or by group
/// (`moarch update core`); with no arguments the whole project is considered.
/// Files the project never generated are never added.
class UpdateCommand extends Command<int> {
  /// Creates the update command.
  UpdateCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Target project path (defaults to current directory).',
        defaultsTo: '.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Report what would change without writing anything.',
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        negatable: false,
        help: 'Refresh every unmodified file without prompting.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Also overwrite files you have edited (discards those edits).',
      )
      ..addFlag(
        'diff',
        abbr: 'd',
        negatable: false,
        help: 'Print the changes for each file instead of a summary line.',
      )
      ..addFlag(
        'list',
        abbr: 'l',
        negatable: false,
        help: 'List every name `update` accepts and exit.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'update';

  @override
  String get description =>
      'Refresh generated files against the current moarch templates.';

  @override
  String get invocation => 'moarch update [<name>|<group>...]';

  /// Every group slug, in listing order.
  static List<String> get _groups => [
        _kWidgetGroup,
        ...ScaffoldCatalog.groups.keys,
      ];

  @override
  Future<int> run() async {
    if (argResults?['list'] as bool? ?? false) {
      _printList();
      return 0;
    }

    final targetPath = p.absolute(argResults?['path'] as String? ?? '.');
    final libPath = p.join(targetPath, 'lib');
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final assumeYes = argResults?['yes'] as bool? ?? false;
    final force = argResults?['force'] as bool? ?? false;
    final showDiff = argResults?['diff'] as bool? ?? false;
    final requested = argResults?.rest ?? const <String>[];

    if (!Directory(libPath).existsSync()) {
      _logger
          .err('No lib/ directory at $targetPath — is this a Flutter project?');
      return 1;
    }

    final unknown = requested.where(_isUnknown).toList();
    if (unknown.isNotEmpty) {
      _logger.err('Unknown name(s): ${unknown.join(', ')}');
      _logger.info('Run `moarch update --list` to see what can be updated.');
      return 1;
    }

    final only = _expand(requested);

    _logger.info('');
    _logger.info('🔄 moarch update — v$packageVersion');

    final manifest = ProjectManifest.load(targetPath);
    if (manifest == null) {
      _logger.info('');
      _logger.warn('  No ${ProjectManifest.fileName} in this project.');
      _logger
          .info('  Without it moarch cannot tell an untouched generated file');
      _logger.info('  from one you edited, so every changed file is listed as');
      _logger.info('  needing review rather than refreshed automatically.');
    } else {
      _logger.info('   project generated by moarch v${manifest.version}');
    }
    _logger.info('');

    final candidates = _collect(targetPath, libPath, manifest, only);

    if (candidates.isEmpty) {
      _logger.info(only == null
          ? '  Nothing moarch generated was found in this project.'
          : '  None of the selected files are present in this project.');
      _logger.info('');
      return 0;
    }

    final changed =
        candidates.where((c) => c.status != UpdateStatus.upToDate).toList();
    final upToDate = candidates.length - changed.length;

    if (changed.isEmpty) {
      _logger.success(
          '  ✓  All ${candidates.length} generated file(s) are up to date.');
      _logger.info('');
      return 0;
    }

    final safe = changed.where((c) => c.isSafe).toList();
    final needsDecision = changed.where((c) => c.needsDecision).toList();

    _logger.info('  $upToDate up to date · ${safe.length} can be refreshed · '
        '${needsDecision.length} need review');
    _logger.info('');

    if (safe.isNotEmpty) {
      _logger.info('  Unmodified since moarch generated them:');
      _describeAll(safe, showDiff: showDiff);
      _logger.info('');
    }

    if (needsDecision.isNotEmpty) {
      _logger
          .info('  Changed by you since generation — not touched by default:');
      _describeAll(needsDecision, showDiff: showDiff);
      _logger.info('');
    }

    if (dryRun) {
      _logger.info('  Dry run — nothing was written.');
      _logger.info('');
      return 0;
    }

    final toWrite = <UpdateCandidate>[
      ...safe,
      if (force) ...needsDecision,
    ];

    if (toWrite.isEmpty) {
      _logger.info('  Nothing to refresh automatically.');
      if (needsDecision.isNotEmpty) {
        _logger.info('  Review the diffs above (`moarch update --diff`), then');
        _logger.info('  re-apply by hand, or overwrite with `--force`.');
      }
      _logger.info('');
      return 0;
    }

    if (force && needsDecision.isNotEmpty) {
      _logger.warn('  --force will discard your edits to '
          '${needsDecision.length} file(s).');
    }

    if (!assumeYes) {
      final confirmed = _logger.confirm(
        '  Refresh ${toWrite.length} file(s)?',
        defaultValue: !force,
      );
      if (!confirmed) {
        _logger.info('  Cancelled — nothing was written.');
        _logger.info('');
        return 0;
      }
    }

    final progress = _logger.progress('Refreshing ${toWrite.length} file(s)');
    final updated = ProjectManifest.loadOrCreate(targetPath);

    // What each file held before it was refreshed, so a failure partway
    // through puts every already-written file back instead of leaving the
    // project half on the old templates and half on the new.
    final replaced = <String, String>{};

    try {
      for (final candidate in toWrite) {
        replaced[candidate.path] = candidate.current;
        await File(candidate.path).writeAsString(candidate.generated);
        updated.record(targetPath, candidate.path, candidate.generated);
      }
      // Files that were already current are recorded too, so a project that
      // predates the manifest stops reporting "unknown" on the next run.
      for (final candidate in candidates) {
        if (candidate.status == UpdateStatus.upToDate) {
          updated.record(targetPath, candidate.path, candidate.current);
        }
      }
      await updated.save(targetPath);
      progress.complete('Refreshed');
    } catch (e) {
      progress.fail('Failed: $e');
      for (final entry in replaced.entries) {
        try {
          File(entry.key).writeAsStringSync(entry.value);
        } catch (_) {
          // Best-effort restore — the git diff still shows what changed.
        }
      }
      _logger.info('  Restored the files that had already been refreshed.');
      return 1;
    }

    _logger.info('');
    for (final candidate in toWrite) {
      _logger.info('  ↻ ${candidate.displayPath}');
    }
    _logger.info('');
    _logger.success('  Updated to moarch v$packageVersion.');
    _logger.info('  Review the changes with `git diff` before committing.');
    _logger.info('');
    return 0;
  }

  /// Whether [token] names nothing `update` understands.
  bool _isUnknown(String token) =>
      token != 'all' &&
      !_groups.contains(token) &&
      WidgetCatalog.byName(token) == null &&
      ScaffoldCatalog.byName(token) == null;

  /// Resolves the names and groups on the command line to the set of slugs to
  /// consider, or null for "everything" — which is both the no-argument case
  /// and `all`.
  Set<String>? _expand(List<String> requested) {
    if (requested.isEmpty || requested.contains('all')) return null;

    final slugs = <String>{};
    for (final token in requested) {
      if (token == _kWidgetGroup) {
        slugs.addAll(WidgetCatalog.names);
        continue;
      }
      final group = ScaffoldCatalog.byGroup(token);
      if (group.isNotEmpty) {
        slugs.addAll(group.map((spec) => spec.name));
        continue;
      }
      slugs.add(token);
    }
    return slugs;
  }

  /// Builds the candidate list by comparing each generated file on disk
  /// against what the current template would write.
  ///
  /// A file that isn't there is not a candidate: `update` refreshes what the
  /// project has rather than scaffolding what it declined.
  List<UpdateCandidate> _collect(
    String projectRoot,
    String libPath,
    ProjectManifest? manifest,
    Set<String>? only,
  ) {
    final candidates = <UpdateCandidate>[];

    UpdateCandidate? build({
      required String name,
      required String title,
      required String category,
      required String displayPath,
      required String path,
      required String Function() generate,
    }) {
      if (only != null && !only.contains(name)) return null;
      final file = File(path);
      if (!file.existsSync()) return null;

      final current = file.readAsStringSync();
      final generated = generate();

      final UpdateStatus status;
      if (!TextDiff.differ(current, generated)) {
        status = UpdateStatus.upToDate;
      } else {
        final recorded = manifest?.recordedHash(projectRoot, path);
        if (recorded == null) {
          status = UpdateStatus.unknown;
        } else if (recorded == ProjectManifest.hashContent(current)) {
          status = UpdateStatus.stale;
        } else {
          status = UpdateStatus.conflicted;
        }
      }

      return UpdateCandidate(
        name: name,
        title: title,
        category: category,
        displayPath: displayPath,
        path: path,
        status: status,
        current: current,
        generated: generated,
      );
    }

    final widgetsRoot = p.join(libPath, 'shared', 'widgets');
    for (final spec in ProjectInspector.generatedWidgets(libPath)) {
      final candidate = build(
        name: spec.name,
        title: spec.title,
        category: _kWidgetCategory,
        displayPath: 'lib/shared/widgets/${spec.file}',
        path: p.join(widgetsRoot, spec.file),
        generate: () => ProjectInspector.widgetSource(libPath, spec),
      );
      if (candidate != null) candidates.add(candidate);
    }

    // Built once: every template that varies reads the same project.
    final context = ScaffoldContext.detect(projectRoot);
    for (final spec in ScaffoldCatalog.generated(projectRoot)) {
      final candidate = build(
        name: spec.name,
        title: spec.title,
        category: spec.category,
        displayPath: spec.path,
        path: context.resolve(spec.path),
        generate: () => spec.template(context),
      );
      if (candidate != null) candidates.add(candidate);
    }

    final order = [_kWidgetCategory, ...ScaffoldCatalog.categories];
    candidates.sort((a, b) {
      final byCategory =
          order.indexOf(a.category).compareTo(order.indexOf(b.category));
      return byCategory != 0 ? byCategory : a.name.compareTo(b.name);
    });
    return candidates;
  }

  /// Prints [candidates] under a heading per category, so a run covering the
  /// whole project reads as sections rather than one long list.
  void _describeAll(
    List<UpdateCandidate> candidates, {
    required bool showDiff,
  }) {
    final order = [_kWidgetCategory, ...ScaffoldCatalog.categories];
    final multipleCategories =
        candidates.map((c) => c.category).toSet().length > 1;

    for (final category in order) {
      final items = candidates.where((c) => c.category == category).toList();
      if (items.isEmpty) continue;
      if (multipleCategories) _logger.info('    $category');
      for (final candidate in items) {
        _describe(candidate, showDiff: showDiff, indent: multipleCategories);
      }
    }
  }

  void _describe(
    UpdateCandidate candidate, {
    required bool showDiff,
    bool indent = false,
  }) {
    final stat = TextDiff.stat(candidate.current, candidate.generated);
    final label = switch (candidate.status) {
      UpdateStatus.unknown => ' (no generation record)',
      UpdateStatus.conflicted => ' (edited)',
      _ => '',
    };
    final pad = indent ? '      ' : '    ';
    _logger.info('$pad${candidate.name.padRight(24)} '
        '${candidate.displayPath}  '
        '+${stat.added} -${stat.removed}$label');

    if (!showDiff) return;
    for (final line
        in TextDiff.unified(candidate.current, candidate.generated)) {
      switch (line.kind) {
        case '+':
          _logger.info('$pad  ${green.wrap('+${line.text}')}');
        case '-':
          _logger.info('$pad  ${red.wrap('-${line.text}')}');
        default:
          _logger.info('$pad  ${darkGray.wrap(' ${line.text}')}');
      }
    }
    _logger.info('');
  }

  void _printList() {
    _logger.info('Everything `moarch update` can refresh.');
    _logger.info('');
    _logger.info('  moarch update                 # the whole project');
    _logger.info('  moarch update validation      # one file');
    _logger.info('  moarch update core docs       # whole groups');
    _logger.info('');
    _logger.info('Groups: ${_groups.join(', ')}');
    _logger.info('');
    _logger.info('  $_kWidgetCategory');
    _logger.info(
        '    ${WidgetCatalog.names.length} widgets — see `moarch create widget --list`');
    _logger.info('');

    for (final category in ScaffoldCatalog.categories) {
      final items =
          ScaffoldCatalog.all.where((spec) => spec.category == category);
      if (items.isEmpty) continue;
      _logger.info('  $category');
      for (final spec in items) {
        _logger.info('    ${spec.name.padRight(24)} ${spec.path}');
      }
      _logger.info('');
    }

    _logger.info('Only files the project actually has are ever touched —');
    _logger.info('`update` refreshes what is there, it does not scaffold.');
  }
}
