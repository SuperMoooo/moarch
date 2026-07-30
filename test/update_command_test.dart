import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/update_command.dart';
import 'package:moarch/src/utils/project_manifest.dart';
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
  String widgetPath() => p.join(libPath, 'shared', 'widgets', spec.file);
  String staleContent() => '// written by an older moarch\n${spec.template()}';

  /// Writes [content] to the widget file, optionally recording it in the
  /// manifest as moarch's own output.
  Future<void> placeWidget(String content, {required bool record}) async {
    final path = widgetPath();
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(content);

    final manifest = ProjectManifest.loadOrCreate(root);
    if (record) manifest.record(root, path, content);
    await manifest.save(root);
  }

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
    await File(widgetPath())
        .writeAsString('// my own tweak\n${spec.template()}');

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

  test('an up-to-date file is recorded so it stops reading as unknown',
      () async {
    // A pre-manifest project: file matches the template but was never recorded.
    await placeWidget(spec.template(), record: false);
    // Something else stale gives the run a reason to write.
    final other = WidgetCatalog.byName('empty-view')!;
    final otherPath = p.join(libPath, 'shared', 'widgets', other.file);
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
}
