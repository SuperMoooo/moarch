import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/init_command.dart';
import 'package:moarch/src/utils/project_inspector.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/text_diff.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `init` writes every file from a checklist; `update` re-renders it from
/// what it finds on disk. The two must agree, or a project reports half of
/// itself as stale the moment it is generated — and a command that renders
/// from its own parameter list (the theme switch once did) silently drops
/// what the catalog knows about. So: scaffold, then ask the catalog.
void main() {
  for (final stack in ['riverpod', 'bloc']) {
    test('a fresh $stack project is up to date for update', () async {
      final tempDir = await Directory.systemTemp.createTemp('moarch_parity');
      addTearDown(() => tempDir.delete(recursive: true));
      final root = tempDir.path;

      final runner = CommandRunner<int>('moarch', 'test')
        ..addCommand(InitCommand(logger: Logger(level: Level.quiet)));
      expect(
        await runner.run(['init', '--path', root, '--all', '--state', stack]),
        0,
      );

      final stale = <String>[];
      final context = ScaffoldContext.detect(root);
      for (final spec in ScaffoldCatalog.generated(root)) {
        final path = context.resolve(spec.pathIn(context));
        if (TextDiff.differ(
          File(path).readAsStringSync(),
          spec.template(context),
        )) {
          stale.add(spec.name);
        }
      }
      final libPath = p.join(root, 'lib');
      for (final spec in ProjectInspector.generatedWidgets(libPath)) {
        if (TextDiff.differ(
          File(spec.pathIn(libPath)).readAsStringSync(),
          ProjectInspector.widgetSource(libPath, spec),
        )) {
          stale.add(spec.name);
        }
      }

      expect(stale, isEmpty, reason: 'init and the catalog disagree');
    });
  }
}
