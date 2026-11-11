import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../utils/package_versions.dart';
import '../../utils/project_manifest.dart';
import '../../utils/pubspec_utils.dart';
import '../../utils/scaffold_catalog.dart';
import '../../utils/text_diff.dart';
import '../../utils/widget_catalog.dart';

/// One file `create theme` would rewrite, and what rewriting it would mean.
class _ThemeFile {
  _ThemeFile({
    required this.displayPath,
    required this.path,
    required this.current,
    required this.generated,
    required this.edited,
  });

  /// Project-relative path with forward slashes, as printed.
  final String displayPath;

  /// Absolute path on disk.
  final String path;

  /// What the file holds now.
  final String current;

  /// What the templates would write for the target theme scope.
  final String generated;

  /// The file no longer matches what moarch recorded writing — either because
  /// it was edited, or because there is no record to compare against.
  final bool edited;

  /// Nothing to do: the file is already what the target scope wants.
  bool get isCurrent => _sameText(current, generated);
}

/// The project as it will be once the theme scope is switched.
///
/// Every template reads the theme off disk — `AppTheme.dark` in
/// `app_theme.dart`, the switch's files under `core/services/` — and here
/// those files are the ones about to be rewritten. So the catalog renders
/// against this view of the project, which answers with the target instead:
/// the same specs `init` and `update` write through, with one option
/// overridden, rather than a second list of template calls that can drift
/// from them.
class _ThemeTarget extends ScaffoldContext {
  _ThemeTarget(ScaffoldContext context, {required this.dark, this.withSwitch})
    : super(projectRoot: context.projectRoot, pubspec: context.pubspec);

  /// Whether the project is getting the dark theme or losing it.
  final bool dark;

  /// Whether the saved light / dark / system switch is being added too, or
  /// null when that is left as the project has it.
  final bool? withSwitch;

  @override
  bool get hasDarkTheme => dark;

  @override
  bool get hasThemeMode => withSwitch ?? super.hasThemeMode;

  @override
  bool get hasPreferences => withSwitch ?? super.hasPreferences;
}

/// Line endings differ between a CRLF checkout and what the templates write,
/// which says nothing about the content.
bool _sameText(String a, String b) =>
    a.replaceAll('\r\n', '\n') == b.replaceAll('\r\n', '\n');

/// Adds the dark half of the theme to a project that was generated with one
/// brand theme — or takes it away again with `--no-dark`.
///
/// `AppConstants`, `AppTheme` and the widgets that pick a color per brightness
/// are generated against each other, so the switch is all of them at once: a
/// dark `AppTheme` without the `*Dark` constants does not compile. Files moarch
/// wrote and nobody edited are rewritten silently; anything edited since is
/// left alone and reported, so the diff is the user's to apply.
class CreateThemeCommand extends Command<int> {
  /// Creates the theme-scope command.
  CreateThemeCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Target project path (defaults to current directory).',
      )
      ..addFlag(
        'dark',
        defaultsTo: true,
        help:
            'Add the dark palette and AppTheme.dark. '
            '--no-dark strips them back to one brand theme.',
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
        help: 'Rewrite without prompting.',
      )
      ..addFlag(
        'diff',
        abbr: 'd',
        negatable: false,
        help: 'Print the changes for each file instead of a summary line.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Also rewrite files you have edited (discards those edits).',
      );
  }

  final Logger _logger;

  @override
  String get name => 'theme';

  @override
  String get description =>
      'Switch the project between one brand theme and light + dark.';

  @override
  String get invocation => 'moarch create theme [--dark|--no-dark]';

  @override
  Future<int> run() async {
    final root = p.absolute(argResults?['path'] as String? ?? '.');
    final libPath = p.join(root, 'lib');
    final target = argResults?['dark'] as bool? ?? true;
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final showDiff = argResults?['diff'] as bool? ?? false;
    final force = argResults?['force'] as bool? ?? false;
    final assumeYes = argResults?['yes'] as bool? ?? false;

    if (!Directory(libPath).existsSync()) {
      _logger.err('No lib/ directory at $root — is this a Flutter project?');
      return 1;
    }

    final themePath = p.join(libPath, 'config', 'theme', 'app_theme.dart');
    if (!File(themePath).existsSync()) {
      _logger.err(
        'No lib/config/theme/app_theme.dart — run `moarch init` '
        'first.',
      );
      return 1;
    }

    final current = WidgetVariants.hasDarkThemeIn(libPath);
    final detected = ScaffoldContext.detect(root);
    // The dark theme brings the saved light / dark / system choice with it
    // (9.2.0 on), so `--dark` also adds that to a project that has the dark
    // palette from before. It is registered in core_module.dart, which a
    // project from before the 9.0.0 locator split does not have.
    final addSwitch = target && detected.hasSplitDi && !detected.hasThemeMode;

    _logger.info('');
    _logger.info(
      target
          ? '🎨 moarch — adding the dark theme'
          : '🎨 moarch — dropping back to one brand theme',
    );
    _logger.info('');

    if (current == target && !addSwitch) {
      _logger.info(
        target
            ? '  This project already has AppTheme.dark — nothing to do.'
            : '  This project already has a single brand theme — nothing to do.',
      );
      _logger.info('');
      return 0;
    }

    final manifest = ProjectManifest.load(root);
    if (manifest == null) {
      _logger.warn('  No ${ProjectManifest.fileName} in this project.');
      _logger.info(
        '  Without it moarch cannot tell an untouched generated '
        'file from one',
      );
      _logger.info(
        '  you edited, so every file is reported for review rather '
        'than rewritten.',
      );
      _logger.info('');
    }

    final context = _ThemeTarget(
      detected,
      dark: target,
      withSwitch: addSwitch ? true : null,
    );
    final files = _collect(root, libPath, manifest, context, addSwitch);
    final changed = files.where((f) => !f.isCurrent).toList();
    final created = addSwitch ? _newFiles(context) : const <String, String>{};

    if (changed.isEmpty && created.isEmpty) {
      _logger.info('  Nothing to rewrite.');
      _logger.info('');
      return 0;
    }

    final safe = changed.where((f) => !f.edited).toList();
    final review = changed.where((f) => f.edited).toList();

    if (safe.isNotEmpty) {
      _logger.info('  Unmodified since moarch generated them:');
      _describe(safe, showDiff: showDiff);
      _logger.info('');
    }
    if (review.isNotEmpty) {
      _logger.info(
        '  Changed by you since generation — not touched by '
        'default:',
      );
      _describe(review, showDiff: showDiff);
      _logger.info('');
    }
    if (created.isNotEmpty) {
      _logger.info('  New — the saved light / dark / system choice:');
      for (final relative in created.keys) {
        _logger.info('    $relative');
      }
      _logger.info(
        '    pubspec.yaml: ${PackageVersions.entry('shared_preferences')}',
      );
      _logger.info('');
    }

    if (dryRun) {
      _logger.info('  Dry run — nothing was written.');
      _logger.info('');
      return 0;
    }

    final toWrite = <_ThemeFile>[...safe, if (force) ...review];

    // A theme scope applied to half the files does not compile: AppTheme.dark
    // reads constants AppConstants would no longer declare. Better to write
    // nothing and hand over the diffs.
    if (review.isNotEmpty && !force) {
      _logger.warn(
        '  Not writing anything: these files are generated against '
        'each other,',
      );
      _logger.warn('  and rewriting only some of them would not compile.');
      _logger.info('');
      _logger.info(
        '  Review the changes with `--diff`, then either apply them '
        'by hand',
      );
      _logger.info('  or re-run with `--force` to overwrite your edits.');
      _logger.info('');
      return 1;
    }

    if (force && review.isNotEmpty) {
      _logger.warn(
        '  --force will discard your edits to ${review.length} '
        'file(s).',
      );
    }

    if (!assumeYes) {
      final confirmed = _logger.confirm(
        created.isEmpty
            ? '  Rewrite ${toWrite.length} file(s)?'
            : '  Rewrite ${toWrite.length} file(s) and add ${created.length}?',
        defaultValue: !force,
      );
      if (!confirmed) {
        _logger.info('  Cancelled — nothing was written.');
        _logger.info('');
        return 0;
      }
    }

    final progress = _logger.progress('Rewriting ${toWrite.length} file(s)');
    final updated = ProjectManifest.loadOrCreate(root);

    // What each file held before, so a failure partway through restores the
    // ones already written rather than leaving the project half-switched.
    final replaced = <String, String>{};
    final added = <String>[];

    try {
      for (final entry in created.entries) {
        final path = p.joinAll([root, ...p.posix.split(entry.key)]);
        if (File(path).existsSync()) continue;
        await File(path).create(recursive: true);
        added.add(path);
        await File(path).writeAsString(entry.value);
        updated.record(root, path, entry.value);
      }
      if (created.isNotEmpty) {
        await PubspecUtils.ensureDependencies(
          root,
          dependencies: [PackageVersions.entry('shared_preferences')],
        );
      }
      for (final file in toWrite) {
        replaced[file.path] = file.current;
        await File(file.path).writeAsString(file.generated);
        updated.record(root, file.path, file.generated);
      }
      await updated.save(root);
      progress.complete('Done');
    } catch (e) {
      progress.fail('Failed: $e');
      for (final entry in replaced.entries) {
        try {
          File(entry.key).writeAsStringSync(entry.value);
        } catch (_) {
          // Best-effort restore — the git diff still shows what changed.
        }
      }
      for (final path in added) {
        try {
          File(path).deleteSync();
        } catch (_) {
          // Best-effort, like the restore above.
        }
      }
      _logger.info('  Restored the files that had already been written.');
      return 1;
    }

    _logger.success('');
    for (final path in added) {
      _logger.info(
        '  + ${p.posix.joinAll(p.split(p.relative(path, from: root)))}',
      );
    }
    for (final file in toWrite) {
      _logger.info('  ↻ ${file.displayPath}');
    }
    _logger.info('');
    if (added.isNotEmpty) {
      _logger.info('  Run `fvm flutter pub get` for shared_preferences.');
    }
    if (target && !detected.hasSplitDi && !detected.hasThemeMode) {
      _logger.info(
        '  The saved light / dark / system switch needs the split locator',
      );
      _logger.info(
        '  (lib/config/di/core_module.dart), so this project follows the system.',
      );
    }
    if (target) {
      _logger.info(
        '  The palette is placeholder black/white — set the *Dark '
        'colors in',
      );
      _logger.info(
        '  lib/core/constants/app_constants.dart to your brand\'s '
        'dark values.',
      );
    }
    _logger.info('  Review the changes with `git diff` before committing.');
    _logger.info('');
    return 0;
  }

  /// The files whose content depends on the theme scope, in the order they are
  /// reported. A file the project never generated is skipped rather than
  /// added: this switches a scope, it does not scaffold what was declined.
  ///
  /// Every one is rendered by its catalog entry against [context], which
  /// already answers for the target theme — the same call `moarch update`
  /// makes, so a file this writes is what `update` would then leave alone.
  /// Spelling the template calls out here instead once dropped the sync
  /// start out of `main.dart`, because this list had not followed the
  /// catalog's.
  List<_ThemeFile> _collect(
    String root,
    String libPath,
    ProjectManifest? manifest,
    _ThemeTarget context,
    bool addSwitch,
  ) {
    final candidates = <String, String>{};

    for (final name in [
      'constants',
      'theme',
      // Holds a `dark` set only while AppConstants has the `*Dark` colors it
      // reads, so it switches with them.
      'status-colors',
      'main',
      // Registers PreferencesService — only while the switch is being added,
      // since core_module.dart is where hand-written services go too, and an
      // edit there should not block switching the palette alone.
      if (addSwitch) 'di-core',
    ]) {
      final spec = ScaffoldCatalog.byName(name)!;
      candidates[spec.pathIn(context)] = spec.template(context);
    }

    // The kit's two entries that pick a color per brightness, written the way
    // `create widget` and `update` write them: every other option read off
    // the project, the theme answered by the target. The preview screen's
    // pre-move path is offered too: a project that has not run `moarch
    // update` yet still has one, and it should follow the theme scope
    // wherever it currently sits.
    final variants = WidgetVariants.detect(
      libPath,
    ).copyWith(hasDarkTheme: context.dark);
    for (final name in ['toast', 'design-system']) {
      final spec = WidgetCatalog.byName(name)!;
      final source = WidgetCatalog.sourceFor(spec, variants);
      candidates['lib/${spec.libFile}'] = source;
      if (spec.movedFrom != null) candidates['lib/${spec.movedFrom}'] = source;
    }

    final files = <_ThemeFile>[];
    candidates.forEach((relative, generated) {
      final path = p.joinAll([root, ...p.posix.split(relative)]);
      final file = File(path);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      final recorded = manifest?.recordedHash(root, path);
      files.add(
        _ThemeFile(
          displayPath: relative,
          path: path,
          current: content,
          generated: generated,
          edited: recorded != ProjectManifest.hashContent(content),
        ),
      );
    });
    return files;
  }

  /// The files the theme-mode switch adds, project-relative — from the
  /// catalog, like everything else this command writes.
  Map<String, String> _newFiles(ScaffoldContext context) => {
    for (final name in ['preferences', 'theme-mode'])
      ScaffoldCatalog.byName(name)!.pathIn(context): ScaffoldCatalog.byName(
        name,
      )!.template(context),
  };

  void _describe(List<_ThemeFile> files, {required bool showDiff}) {
    for (final file in files) {
      _logger.info('    ${file.displayPath}');
      if (!showDiff) continue;
      for (final line in TextDiff.unified(file.current, file.generated)) {
        _logger.info('      $line');
      }
      _logger.info('');
    }
  }
}
