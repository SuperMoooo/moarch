import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/update_command.dart';
import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/project_manifest.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String root;
  late String libPath;
  late CommandRunner<int> runner;

  /// The widget used throughout: written to disk in a "previous version"
  /// form so it differs from what the current template would produce.
  final spec = WidgetCatalog.byName('error-view')!;
  String widgetPath() => spec.pathIn(libPath);
  String staleContent() => '// written by an older moarch\n${spec.template()}';

  /// Writes [content] to [path], optionally recording it in the manifest as
  /// moarch's own output.
  Future<void> place(
    String path,
    String content, {
    required bool record,
  }) async {
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(content);

    final manifest = ProjectManifest.loadOrCreate(root);
    if (record) manifest.record(root, path, content);
    await manifest.save(root);
  }

  Future<void> placeWidget(String content, {required bool record}) =>
      place(widgetPath(), content, record: record);

  /// Puts a non-widget catalog file on disk one version behind its template,
  /// recorded as moarch's own — the case `update` is meant to refresh.
  Future<String> placeStaleScaffold(String name) async {
    final entry = ScaffoldCatalog.byName(name)!;
    final path = p.joinAll([root, ...p.posix.split(entry.path)]);
    final context = ScaffoldContext.detect(root);
    await place(
      path,
      '// written by an older moarch\n${entry.template(context)}',
      record: true,
    );
    return path;
  }

  /// What [name]'s template produces for this project right now.
  String currentSource(String name) =>
      ScaffoldCatalog.byName(name)!.template(ScaffoldContext.detect(root));

  Future<int?> runUpdate(List<String> args) =>
      runner.run(['update', '--path', root, ...args]);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_update_test');
    root = tempDir.path;
    libPath = p.join(root, 'lib');
    await Directory(libPath).create(recursive: true);

    runner = CommandRunner<int>('moarch', 'test')
      ..addCommand(UpdateCommand(logger: Logger(level: Level.quiet)));
  });

  tearDown(() async => tempDir.delete(recursive: true));

  test('refreshes a file that is unmodified since generation', () async {
    // Recorded hash matches what's on disk → moarch wrote it, nobody touched it.
    await placeWidget(staleContent(), record: true);

    final code = await runUpdate(['--yes']);

    expect(code, 0);
    expect(await File(widgetPath()).readAsString(), spec.template());
  });

  test('leaves a file the user edited alone', () async {
    // Recorded at the template, then edited afterwards → hash mismatch.
    await placeWidget(spec.template(), record: true);
    final edited = '// my own tweak\n${spec.template()}';
    await File(widgetPath()).writeAsString(edited);

    final code = await runUpdate(['--yes']);

    expect(code, 0);
    expect(await File(widgetPath()).readAsString(), edited);
  });

  test('leaves an unrecorded file alone', () async {
    // No manifest entry → provenance unknown, so edits cannot be ruled out.
    await placeWidget(staleContent(), record: false);

    final code = await runUpdate(['--yes']);

    expect(code, 0);
    expect(await File(widgetPath()).readAsString(), staleContent());
  });

  test('--force overwrites a file the user edited', () async {
    await placeWidget(spec.template(), record: true);
    await File(
      widgetPath(),
    ).writeAsString('// my own tweak\n${spec.template()}');

    final code = await runUpdate(['--yes', '--force']);

    expect(code, 0);
    expect(await File(widgetPath()).readAsString(), spec.template());
  });

  test('--dry-run writes nothing', () async {
    await placeWidget(staleContent(), record: true);

    final code = await runUpdate(['--dry-run']);

    expect(code, 0);
    expect(await File(widgetPath()).readAsString(), staleContent());
  });

  test('a refreshed file is re-recorded, so a second run is a no-op', () async {
    await placeWidget(staleContent(), record: true);
    await runUpdate(['--yes']);

    // Second run: nothing changed, and the manifest now matches the template.
    final manifest = ProjectManifest.load(root)!;
    expect(
      manifest.recordedHash(root, widgetPath()),
      ProjectManifest.hashContent(spec.template()),
    );
  });

  test('an up-to-date file is recorded so it stops reading as unknown', () async {
    // A pre-manifest project: file matches the template but was never recorded.
    await placeWidget(spec.template(), record: false);
    // Something else stale gives the run a reason to write.
    final other = WidgetCatalog.byName('empty-view')!;
    final otherPath = other.pathIn(libPath);
    await File(otherPath).writeAsString('// older\n${other.template()}');
    final manifest = ProjectManifest.loadOrCreate(root)
      ..record(root, otherPath, '// older\n${other.template()}');
    await manifest.save(root);

    await runUpdate(['--yes']);

    final updated = ProjectManifest.load(root)!;
    expect(
      updated.recordedHash(root, widgetPath()),
      ProjectManifest.hashContent(spec.template()),
    );
  });

  test('reports success when everything is already current', () async {
    await placeWidget(spec.template(), record: true);
    expect(await runUpdate(['--yes']), 0);
  });

  test('only the named widget is considered', () async {
    await placeWidget(staleContent(), record: true);

    // Restrict the run to a different widget — this one must stay stale.
    final code = await runUpdate(['--yes', 'button']);

    expect(code, 0);
    expect(await File(widgetPath()).readAsString(), staleContent());
  });

  test('rejects an unknown widget name', () async {
    await placeWidget(staleContent(), record: true);
    expect(await runUpdate(['--yes', 'not-a-widget']), 1);
  });

  test('fails when there is no lib/ directory', () async {
    await Directory(libPath).delete(recursive: true);
    expect(await runUpdate(['--yes']), 1);
  });

  test('succeeds on a project with no generated widgets', () async {
    expect(await runUpdate(['--yes']), 0);
  });

  group('beyond the widget kit', () {
    test('refreshes a generated file that is not a widget', () async {
      final path = await placeStaleScaffold('validation');

      final code = await runUpdate(['--yes']);

      expect(code, 0);
      expect(await File(path).readAsString(), currentSource('validation'));
    });

    test('a name refreshes that file and nothing else', () async {
      final validation = await placeStaleScaffold('validation');
      final extensions = await placeStaleScaffold('extensions');
      await placeWidget(staleContent(), record: true);

      final code = await runUpdate(['--yes', 'validation']);

      expect(code, 0);
      expect(
        await File(validation).readAsString(),
        currentSource('validation'),
      );
      // Everything not named keeps the older content it was placed with.
      expect(await File(extensions).readAsString(), startsWith('// written'));
      expect(await File(widgetPath()).readAsString(), staleContent());
    });

    test('a group name refreshes that category only', () async {
      final validation = await placeStaleScaffold('validation');
      final extensions = await placeStaleScaffold('extensions');

      final code = await runUpdate(['--yes', 'security']);

      expect(code, 0);
      expect(
        await File(validation).readAsString(),
        currentSource('validation'),
      );
      expect(await File(extensions).readAsString(), startsWith('// written'));
    });

    test('`widgets` refreshes the kit and leaves the rest alone', () async {
      final validation = await placeStaleScaffold('validation');
      await placeWidget(staleContent(), record: true);

      final code = await runUpdate(['--yes', 'widgets']);

      expect(code, 0);
      expect(await File(widgetPath()).readAsString(), spec.template());
      expect(await File(validation).readAsString(), startsWith('// written'));
    });

    test('several names and groups can be combined', () async {
      final validation = await placeStaleScaffold('validation');
      final extensions = await placeStaleScaffold('extensions');
      final theme = await placeStaleScaffold('theme');

      final code = await runUpdate(['--yes', 'security', 'extensions']);

      expect(code, 0);
      expect(
        await File(validation).readAsString(),
        currentSource('validation'),
      );
      expect(
        await File(extensions).readAsString(),
        currentSource('extensions'),
      );
      expect(await File(theme).readAsString(), startsWith('// written'));
    });

    test('never creates a file the project does not have', () async {
      // `biometric` is only generated when that option was selected. Naming it
      // in a project that declined it is a no-op, not a scaffold.
      final path = ScaffoldCatalog.byName('biometric')!.path;

      final code = await runUpdate(['--yes', 'biometric']);

      expect(code, 0);
      expect(
        File(p.joinAll([root, ...p.posix.split(path)])).existsSync(),
        isFalse,
      );
    });

    test('leaves an edited non-widget file alone', () async {
      final path = await placeStaleScaffold('validation');
      final edited = '// my own tweak\n${currentSource('validation')}';
      await File(path).writeAsString(edited);

      final code = await runUpdate(['--yes']);

      expect(code, 0);
      expect(await File(path).readAsString(), edited);
    });

    test(
      'a conditional template follows the project it is refreshed into',
      () async {
        // app_logger.dart has a Crashlytics-aware variant. Which one is current
        // depends on the project, not on how `update` was invoked.
        await File(p.join(root, 'pubspec.yaml')).writeAsString(
          'name: demo\ndependencies:\n  firebase_crashlytics: ^4.0.0\n',
        );
        final path = await placeStaleScaffold('logger');

        final code = await runUpdate(['--yes', 'logger']);

        expect(code, 0);
        expect(
          await File(path).readAsString(),
          CoreTemplates.appLogger(withCrashlytics: true),
        );
      },
    );

    test('--list exits without touching anything', () async {
      final path = await placeStaleScaffold('validation');

      final code = await runUpdate(['--list']);

      expect(code, 0);
      expect(await File(path).readAsString(), startsWith('// written'));
    });

    test('rejects an unknown group', () async {
      expect(await runUpdate(['--yes', 'not-a-group']), 1);
    });
  });

  group('a catalog entry that has moved', () {
    // The preview screen moved out of the UI kit into `shared/views/`: it is
    // a route, not a piece the kit composes with. A project generated before
    // that still holds it at the old path, and `update` is what relocates it.
    final preview = WidgetCatalog.byName('design-system')!;

    String legacyPath() => preview.legacyPathIn(libPath)!;
    String newPath() => preview.pathIn(libPath);
    String current() => SharedTemplates.designSystemView();
    String stale() => '// written by an older moarch\n${current()}';

    test('refreshing it moves it instead of copying it', () async {
      await place(legacyPath(), stale(), record: true);

      expect(await runUpdate(['--yes']), 0);

      expect(File(legacyPath()).existsSync(), isFalse);
      expect(await File(newPath()).readAsString(), current());
    });

    test('a file already matching the template still moves', () async {
      // Nothing to refresh, so the only thing out of date is where it sits.
      // Moving content that is byte-for-byte the template discards nothing,
      // which is why this does not need a manifest record to be safe.
      await place(legacyPath(), current(), record: false);

      expect(await runUpdate(['--yes']), 0);

      expect(File(legacyPath()).existsSync(), isFalse);
      expect(await File(newPath()).readAsString(), current());
    });

    test('the manifest stops vouching for the old path', () async {
      await place(legacyPath(), stale(), record: true);

      expect(await runUpdate(['--yes']), 0);

      final files = ProjectManifest.load(root)!.files;
      expect(files, isNot(contains('lib/${preview.movedFrom}')));
      expect(files, contains('lib/${preview.libFile}'));
    });

    test('a second run is a no-op', () async {
      await place(legacyPath(), stale(), record: true);
      expect(await runUpdate(['--yes']), 0);

      expect(await runUpdate(['--yes']), 0);
      expect(File(legacyPath()).existsSync(), isFalse);
      expect(await File(newPath()).readAsString(), current());
    });

    test('a file the user edited is left where it is', () async {
      await place(legacyPath(), current(), record: true);
      final edited = '// my own tweak\n${current()}';
      await File(legacyPath()).writeAsString(edited);

      expect(await runUpdate(['--yes']), 0);

      // Not moved and not overwritten — a move that discards edits is still
      // discarding edits.
      expect(await File(legacyPath()).readAsString(), edited);
      expect(File(newPath()).existsSync(), isFalse);
    });

    test('--force moves an edited file and discards the edits', () async {
      await place(legacyPath(), current(), record: true);
      await File(legacyPath()).writeAsString('// my own tweak\n${current()}');

      expect(await runUpdate(['--yes', '--force']), 0);

      expect(File(legacyPath()).existsSync(), isFalse);
      expect(await File(newPath()).readAsString(), current());
    });

    test('--dry-run moves nothing', () async {
      await place(legacyPath(), stale(), record: true);

      expect(await runUpdate(['--dry-run']), 0);

      expect(await File(legacyPath()).readAsString(), stale());
      expect(File(newPath()).existsSync(), isFalse);
    });

    test('a file already at the new path is refreshed in place', () async {
      await place(newPath(), stale(), record: true);

      expect(await runUpdate(['--yes']), 0);

      expect(await File(newPath()).readAsString(), current());
      expect(File(legacyPath()).existsSync(), isFalse);
    });

    test('the move does not drag the rest of the kit along', () async {
      // `update design-system` names one entry; a widget that has not moved
      // stays exactly where it is.
      await place(legacyPath(), stale(), record: true);
      await placeWidget(staleContent(), record: true);

      expect(await runUpdate(['--yes', 'design-system']), 0);

      expect(await File(widgetPath()).readAsString(), staleContent());
      expect(File(newPath()).existsSync(), isTrue);
    });
  });

  group('the auth models that moved under domain/', () {
    // 8.0.0 moved both auth models from `data/models/` to `domain/models/`,
    // since a model is the domain's own type once there is no entity. A project
    // scaffolded earlier still holds them at the old path.
    const legacy = 'lib/features/auth/data/models/auth_user_model.dart';
    const moved = 'lib/features/auth/domain/models/auth_user_model.dart';

    String at(String relative) => p.joinAll([root, ...p.posix.split(relative)]);
    String current() => currentSource('auth-user-model');

    test('the catalog says where each one used to be', () {
      for (final slug in ['auth-model', 'auth-user-model']) {
        final entry = ScaffoldCatalog.byName(slug)!;
        expect(entry.path, contains('/domain/models/'), reason: slug);
        expect(
          entry.movedFrom,
          entry.path.replaceFirst('/domain/', '/data/'),
          reason: slug,
        );
      }
    });

    test(
      'a project holding the old path still reads as the Firebase variant',
      () async {
        await place(at(legacy), current(), record: false);

        expect(ScaffoldContext.detect(root).hasFirebaseAuthFeature, isTrue);
      },
    );

    test('refreshing it moves it instead of copying it', () async {
      await place(
        at(legacy),
        '// written by an older moarch\n${current()}',
        record: true,
      );

      expect(await runUpdate(['--yes', 'auth-user-model']), 0);

      expect(File(at(legacy)).existsSync(), isFalse);
      expect(await File(at(moved)).readAsString(), current());
      final files = ProjectManifest.load(root)!.files;
      expect(files, isNot(contains(legacy)));
      expect(files, contains(moved));
    });

    test('a model the user edited is left where it is', () async {
      await place(at(legacy), '// mine\n${current()}', record: false);

      expect(await runUpdate(['--yes', 'auth-user-model']), 0);

      expect(File(at(legacy)).existsSync(), isTrue);
      expect(File(at(moved)).existsSync(), isFalse);
    });
  });
}
