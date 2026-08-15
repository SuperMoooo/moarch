import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/doctor_command.dart';
import 'package:moarch/src/templates/misc/dev_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String root;
  late String libPath;
  late CommandRunner<int> runner;

  Future<void> scaffoldHealthyProject() async {
    for (final dir in ['core', 'config', 'shared']) {
      await Directory(p.join(libPath, dir)).create(recursive: true);
    }
    await File(p.join(libPath, 'main.dart')).writeAsString('void main() {}');
    await File(p.join(root, '.env')).writeAsString('API_URL=http://x');
    await File(p.join(root, '.fvmrc')).writeAsString('{}');
    await File(p.join(root, '.vscode', 'settings.json'))
        .create(recursive: true)
        .then((file) => file.writeAsString(DevTemplates.vscodeSettings()));
    // Stands in for the symlink `fvm use` creates — a real directory resolves
    // the same way without needing Windows symlink privileges.
    await Directory(p.join(root, '.fvm', 'flutter_sdk'))
        .create(recursive: true);
    // The locator is part of a healthy project in both stacks now: it is
    // where the data layer is wired, whichever one holds the state.
    await File(p.join(libPath, 'config', 'di', 'injector.dart'))
        .create(recursive: true)
        .then((file) => file.writeAsString('''
final getIt = GetIt.instance;

Future<void> setupInjector() async {
  // moarch:registrations
}
'''));
    await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: demo

dependencies:
  flutter_riverpod: ^2.0.0
  get_it: ^8.0.0
  envied: ^0.5.0
''');
  }

  Future<void> writeWidget(String name) async {
    final spec = WidgetCatalog.byName(name)!;
    final path = p.join(libPath, 'shared', 'widgets', spec.file);
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(spec.template());
  }

  Future<int?> runDoctor(List<String> args) =>
      runner.run(['doctor', '--path', root, ...args]);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_doctor_test');
    root = tempDir.path;
    libPath = p.join(root, 'lib');
    await Directory(libPath).create(recursive: true);

    runner = CommandRunner<int>('moarch', 'test')
      ..addCommand(DoctorCommand(logger: Logger(level: Level.quiet)));
  });

  tearDown(() async => tempDir.delete(recursive: true));

  test('exits 0 on a healthy project', () async {
    await scaffoldHealthyProject();
    expect(await runDoctor([]), 0);
  });

  test('exits 1 when something is wrong', () async {
    await scaffoldHealthyProject();
    await File(p.join(root, '.env')).delete();
    expect(await runDoctor([]), 1);
  });

  test('without --fix nothing is written', () async {
    await scaffoldHealthyProject();
    await writeWidget('switch'); // missing its AppInputStyle dependency

    expect(await runDoctor([]), 1);

    final style = WidgetCatalog.byName('input-style')!;
    expect(
      File(p.join(libPath, 'shared', 'widgets', style.file)).existsSync(),
      isFalse,
    );
  });

  test('--fix resolves a missing widget dependency and exits 0', () async {
    await scaffoldHealthyProject();
    await writeWidget('switch');

    expect(await runDoctor(['--fix']), 0);

    final style = WidgetCatalog.byName('input-style')!;
    expect(
      File(p.join(libPath, 'shared', 'widgets', style.file)).existsSync(),
      isTrue,
    );
  });

  test('--fix adds a missing widget package and exits 0', () async {
    await scaffoldHealthyProject();
    await writeWidget('avatar'); // needs cached_network_image

    expect(await runDoctor(['--fix']), 0);
    expect(
      await File(p.join(root, 'pubspec.yaml')).readAsString(),
      contains('cached_network_image'),
    );
  });

  test('--fix still exits 1 when an issue needs a human decision', () async {
    await scaffoldHealthyProject();
    // build_runner has not run — moarch will not run it for the user.
    final envDir = p.join(libPath, 'config', 'env');
    await Directory(envDir).create(recursive: true);
    await File(p.join(envDir, 'app_env.dart')).writeAsString('// envied');

    expect(await runDoctor(['--fix']), 1);
  });

  test('--fix records what it generated in the manifest', () async {
    await scaffoldHealthyProject();
    await writeWidget('switch');
    await runDoctor(['--fix']);

    // The regenerated dependency is moarch's, so `update` may refresh it later.
    expect(File(p.join(root, '.moarch.yaml')).existsSync(), isTrue);
  });

  group('wrap', () {
    test('breaks a long hint at the requested width', () {
      final lines = DoctorCommand.wrap('${'a' * 10} ${'b' * 10}', 12);
      expect(lines, hasLength(2));
    });

    test('keeps a short hint on one line', () {
      expect(DoctorCommand.wrap('short hint', 40), ['short hint']);
    });

    test('never splits a word longer than the width', () {
      final lines = DoctorCommand.wrap('supercalifragilistic', 5);
      expect(lines, ['supercalifragilistic']);
    });
  });
}
