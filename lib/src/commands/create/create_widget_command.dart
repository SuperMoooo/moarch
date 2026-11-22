import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../templates/core/services_templates.dart';
import '../../utils/file_utils.dart';
import '../../utils/package_versions.dart';
import '../../utils/project_manifest.dart';
import '../../utils/project_paths.dart';
import '../../utils/pubspec_utils.dart';
import '../../utils/widget_catalog.dart';

/// Creates the `create widget` subcommand: scaffolds a widget from the shared
/// UI kit on demand, pulling in its dependencies and pub packages.
class CreateWidgetCommand extends Command<int> {
  /// CREATE WIDGET COMMAND
  CreateWidgetCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: 'lib',
        help: 'Path to the lib/ directory, or the project root holding it.',
      )
      ..addFlag(
        'list',
        abbr: 'l',
        negatable: false,
        help: 'List every available widget and exit.',
      );
  }

  final Logger _logger;

  @override
  String get name => 'widget';

  @override
  String get description =>
      'Generate a shared UI widget from the kit (see docs/UI_KIT.md).';

  @override
  String get invocation => 'moarch create widget <name> [<name>...]';

  @override
  Future<int> run() async {
    if (argResults?['list'] as bool? ?? false) {
      _printList();
      return 0;
    }

    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      _logger.err(
        'Provide a widget name.\n  Usage: moarch create widget <name> (or "all")',
      );
      _logger.info('');
      _printList();
      return 1;
    }

    final libPath = resolveLibPath(argResults?['path'] as String? ?? 'lib');
    final projectRoot = p.dirname(p.absolute(libPath));

    // "all" expands to the whole catalog.
    final requested = rest.contains('all') ? WidgetCatalog.names : rest;

    final unknown = requested
        .where((n) => WidgetCatalog.byName(n) == null)
        .toList();
    if (unknown.isNotEmpty) {
      _logger.err('Unknown widget(s): ${unknown.join(', ')}');
      _logger.info('Run `moarch create widget --list` to see valid names.');
      return 1;
    }

    // Some widgets are generated against the project's options — AppButton
    // against the biometric service, MaintenanceGate against the backend.
    // Read them off the project, so adding a widget later matches what `init`
    // would have written for it.
    final variants = WidgetVariants.detect(libPath);

    // A widget the project's stack has no use for is dropped rather than
    // written: `create widget all` on a bloc project leaves out the two
    // Riverpod-only pieces instead of adding files that cannot compile.
    final resolved = WidgetCatalog.resolve(
      requested,
      stateManagement: variants.stateManagement,
    );
    final unsupported = requested
        .where((name) => !resolved.any((spec) => spec.name == name))
        .toList();

    // OnboardingGate reads PreferencesService, which `init` writes only with
    // the onboarding or dark theme option. `all` leaves such widgets out of a
    // project without it, like the stack-specific ones above; asked for by
    // name, a widget brings the service along instead, so it compiles.
    final preferencesPath = p.join(
      libPath,
      'core',
      'services',
      'preferences_service.dart',
    );
    final hasPreferences = File(preferencesPath).existsSync();
    final leftOutForPreferences = rest.contains('all') && !hasPreferences
        ? resolved.where((spec) => spec.needsPreferences).toList()
        : const <WidgetSpec>[];
    final specs = resolved
        .where((spec) => !leftOutForPreferences.contains(spec))
        .toList();
    final addsPreferences =
        !hasPreferences && specs.any((spec) => spec.needsPreferences);
    if (unsupported.isNotEmpty && !rest.contains('all')) {
      _logger.warn(
        'Not available on '
        '${variants.hasBloc ? 'flutter_bloc' : 'Riverpod'}: '
        '${unsupported.join(', ')}',
      );
    }
    if (specs.isEmpty) {
      _logger.info('Nothing to generate.');
      return 0;
    }

    final packages = <String>{
      for (final spec in specs) ...spec.packages,
      if (addsPreferences) PackageVersions.entry('shared_preferences'),
    };

    _logger.info('');
    _logger.info('🧱 Generating ${specs.length} widget(s)');
    _logger.info('');

    final progress = _logger.progress('Scaffolding widgets');
    FileUtils.beginSession();

    final created = <WidgetSpec>[];
    final skipped = <WidgetSpec>[];

    // Files this run did not write, but which are still exactly what it would
    // have written — so the manifest can vouch for them anyway.
    final adopted = <WidgetSpec>[];

    // Entries the project still holds at the path moarch wrote before they
    // moved. Writing the new path would leave the project with two copies of
    // the same screen, so these are left for `moarch update`, which relocates
    // rather than duplicates.
    final unmoved = <WidgetSpec>[];

    // Records what was generated so `moarch update` can later tell these
    // files apart from ones the user edited. A skipped file whose content
    // differs is left out: that content is the user's, not ours to vouch for.
    final manifest = ProjectManifest.loadOrCreate(projectRoot);
    var wrotePreferences = false;

    try {
      if (addsPreferences) {
        final content = ServicesTemplates.preferencesService();
        wrotePreferences = await FileUtils.writeFile(preferencesPath, content);
        if (wrotePreferences) {
          manifest.record(projectRoot, preferencesPath, content);
        }
      }
      for (final spec in specs) {
        final content = WidgetCatalog.sourceFor(spec, variants);
        final path = spec.pathIn(libPath);
        final legacy = spec.legacyPathIn(libPath);
        if (legacy != null &&
            !File(path).existsSync() &&
            File(legacy).existsSync()) {
          unmoved.add(spec);
          continue;
        }
        final wrote = await FileUtils.writeFile(path, content);
        if (wrote) {
          manifest.record(projectRoot, path, content);
        } else if (_isGenerated(path, content)) {
          // Untracked until now — generated by a run that predates the
          // manifest, copied in from another project, or written by a
          // `create widget` that stopped before saving. However it got there,
          // it is moarch's own file and `update` should be able to refresh it.
          final tracked =
              manifest.recordedHash(projectRoot, path) ==
              ProjectManifest.hashContent(content);
          manifest.record(projectRoot, path, content);
          if (!tracked) adopted.add(spec);
        }
        (wrote ? created : skipped).add(spec);
      }
      if (packages.isNotEmpty) {
        await PubspecUtils.ensureDependencies(
          projectRoot,
          dependencies: packages.toList(),
        );
      }
      if (created.isNotEmpty || adopted.isNotEmpty || wrotePreferences) {
        await manifest.save(projectRoot);
      }
      progress.complete('Widgets scaffolded');
    } catch (e) {
      progress.fail('Failed: $e');
      FileUtils.rollback();
      _logger.info('  Rolled back partially generated files.');
      return 1;
    }

    _logger.success('');
    if (wrotePreferences) {
      _logger.info('  + core/services/preferences_service.dart');
    }
    for (final spec in created) {
      _logger.info('  + ${spec.libFile}');
    }
    // Existing files are never overwritten, so say so instead of claiming a
    // write that didn't happen — the caller may be re-running to pull in a
    // dependency and needs to know their edits were kept.
    if (skipped.isNotEmpty) {
      _logger.info('');
      _logger.info('  Already present, left untouched:');
      for (final spec in skipped) {
        _logger.info('    · ${spec.libFile}');
      }
      _logger.info('    Delete a file and re-run to regenerate it.');
      if (adopted.isNotEmpty) {
        _logger.info('');
        _logger.info(
          '  ${adopted.length} of them still match the current templates and are now',
        );
        _logger.info(
          '  recorded in ${ProjectManifest.fileName}, so `moarch update` can refresh them.',
        );
      }
    }

    if (unmoved.isNotEmpty) {
      _logger.info('');
      _logger.info('  Already present at their previous path:');
      for (final spec in unmoved) {
        _logger.info('    · lib/${spec.movedFrom}  →  lib/${spec.libFile}');
      }
      _logger.info(
        '    Run `moarch update ${unmoved.map((s) => s.name).join(' ')}` '
        'to move them.',
      );
    }

    if (packages.isNotEmpty) {
      final names = packages.map((pkg) => pkg.replaceAll(':', '').trim());
      _logger.info('');
      _logger.info('  Added to pubspec.yaml: ${names.join(', ')}');
      _logger.info('  Run: flutter pub get');
    }

    // Router-dependent widgets import config/router/app_router.dart.
    final needsRouter = specs.any((spec) => spec.needsRouter);
    final hasRouter = File(
      p.join(libPath, 'config', 'router', 'app_router.dart'),
    ).existsSync();
    if (leftOutForPreferences.isNotEmpty) {
      _logger.info('');
      _logger.info(
        '  Left out ${leftOutForPreferences.map((s) => s.title).join(', ')}: '
        'it reads PreferencesService, which this project does not have.',
      );
      _logger.info(
        '  Add it with `moarch create widget '
        '${leftOutForPreferences.map((s) => s.name).join(' ')}`, which brings the service.',
      );
    }

    // The service file compiles on its own, but the gate reads it from the
    // locator: unregistered, getIt throws on the first frame.
    if (wrotePreferences) {
      _logger.info('');
      _logger.warn(
        '  Register PreferencesService in lib/config/di/core_module.dart',
      );
      _logger.warn(
        '  (setupInjector already waits for it with getIt.allReady()):',
      );
      _logger.warn(
        '    ..registerSingletonAsync<PreferencesService>(PreferencesService.create)',
      );
    }

    if (needsRouter && !hasRouter) {
      _logger.info('');
      _logger.warn(
        '  Some of these import config/router/app_router.dart (rootNavigatorKey).',
      );
      _logger.warn(
        '  Generate the GoRouter setup first, or point them at your own navigator key.',
      );
    }

    _logger.info('');
    return 0;
  }

  /// Whether the file already at [path] is still exactly what moarch would
  /// generate for it — line endings aside, which a Windows checkout changes
  /// without anyone editing anything.
  bool _isGenerated(String path, String content) {
    final file = File(path);
    if (!file.existsSync()) return false;
    try {
      return ProjectManifest.hashContent(file.readAsStringSync()) ==
          ProjectManifest.hashContent(content);
    } on FileSystemException {
      // An unreadable file is one we cannot vouch for, which is the same
      // answer as an edited one.
      return false;
    }
  }

  void _printList() {
    _logger.info('Available widgets  —  moarch create widget <name>');
    _logger.info('');
    for (final category in WidgetCatalog.categories) {
      final items = WidgetCatalog.all
          .where((w) => w.category == category)
          .toList();
      if (items.isEmpty) continue;
      _logger.info('  $category:');
      for (final w in items) {
        final tag = w.common ? '  (on init)' : '';
        _logger.info('    ${w.name.padRight(18)} ${w.title}$tag');
      }
      _logger.info('');
    }
    _logger.info(
      '  moarch create widget all   → generate the whole kit + preview',
    );
  }
}
