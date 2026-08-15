import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/create/create_theme_command.dart';
import 'package:moarch/src/templates/config/config_templates.dart';
import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/project_manifest.dart';
import 'package:moarch/src/templates/riverpod/app_templates.dart' as riverpod;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String root;

  String at(String relative) => p.joinAll([root, ...p.posix.split(relative)]);

  String read(String relative) => File(at(relative)).readAsStringSync();

  /// Writes [content] to [relative], recording it as moarch's own output
  /// unless [record] says otherwise — the difference between a generated file
  /// and one the user has since edited.
  Future<void> place(
    String relative,
    String content, {
    bool record = true,
  }) async {
    final path = at(relative);
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(content);

    final manifest = ProjectManifest.loadOrCreate(root);
    if (record) manifest.record(root, path, content);
    await manifest.save(root);
  }

  /// A project generated with a single brand theme.
  Future<void> placeLightProject() async {
    await place(
      'lib/core/constants/app_constants.dart',
      CoreTemplates.appConstants(),
    );
    await place('lib/config/theme/app_theme.dart', ConfigTemplates.appTheme());
    await place(
        'lib/main.dart', riverpod.AppTemplates.mainDart(withRouter: false));
    await place(
      'lib/shared/widgets/overlays/app_toast.dart',
      SharedTemplates.appToast(),
    );
  }

  late CommandRunner<int> runner;

  Future<int?> run(List<String> args) =>
      runner.run(['theme', '--path', root, ...args]);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_theme_cmd');
    root = tempDir.path;

    final command = CreateThemeCommand(logger: Logger(level: Level.quiet));
    runner = CommandRunner<int>('moarch', 'test')..addCommand(command);
  });

  tearDown(() async => tempDir.delete(recursive: true));

  test('adds the dark half across every file that reads it', () async {
    await placeLightProject();

    expect(await run(['--yes']), 0);

    expect(read('lib/core/constants/app_constants.dart'),
        contains('static const Color primaryDark'));
    expect(read('lib/config/theme/app_theme.dart'),
        contains('static ThemeData get dark => ThemeData('));
    expect(read('lib/main.dart'), contains('darkTheme: AppTheme.dark,'));
    expect(read('lib/main.dart'), contains('themeMode: ThemeMode.system,'));
    expect(read('lib/shared/widgets/overlays/app_toast.dart'),
        contains('AppConstants.successDark'));
  });

  test('--no-dark strips it back to one brand theme', () async {
    await place(
      'lib/core/constants/app_constants.dart',
      CoreTemplates.appConstants(withDark: true),
    );
    await place(
      'lib/config/theme/app_theme.dart',
      ConfigTemplates.appTheme(withDark: true),
    );
    await place(
      'lib/main.dart',
      riverpod.AppTemplates.mainDart(withRouter: false, withDarkTheme: true),
    );

    expect(await run(['--no-dark', '--yes']), 0);

    expect(
        read('lib/core/constants/app_constants.dart'), isNot(contains('Dark')));
    expect(
        read('lib/config/theme/app_theme.dart'), isNot(contains('get dark')));
    expect(read('lib/main.dart'), isNot(contains('AppTheme.dark')));
  });

  test('does nothing when the project already has what was asked for',
      () async {
    await placeLightProject();
    final before = read('lib/config/theme/app_theme.dart');

    expect(await run(['--no-dark', '--yes']), 0);
    expect(read('lib/config/theme/app_theme.dart'), before);
  });

  test('leaves the project alone when one of the files was edited', () async {
    await placeLightProject();
    // The theme file is the user's now — rewriting only the others would leave
    // AppTheme reading constants that no longer exist.
    await File(at('lib/config/theme/app_theme.dart'))
        .writeAsString('// my own theme\n${ConfigTemplates.appTheme()}');

    expect(await run(['--yes']), 1);
    expect(
        read('lib/core/constants/app_constants.dart'), isNot(contains('Dark')));
    expect(
        read('lib/config/theme/app_theme.dart'), startsWith('// my own theme'));
    expect(read('lib/main.dart'), isNot(contains('AppTheme.dark')));
  });

  test('--force overwrites the edited file too', () async {
    await placeLightProject();
    await File(at('lib/config/theme/app_theme.dart'))
        .writeAsString('// my own theme\n${ConfigTemplates.appTheme()}');

    expect(await run(['--force', '--yes']), 0);
    expect(read('lib/config/theme/app_theme.dart'),
        contains('static ThemeData get dark => ThemeData('));
    expect(
        read('lib/core/constants/app_constants.dart'), contains('primaryDark'));
  });

  test('--dry-run writes nothing', () async {
    await placeLightProject();

    expect(await run(['--dry-run']), 0);
    expect(
        read('lib/config/theme/app_theme.dart'), isNot(contains('get dark')));
  });

  test('records what it wrote, so a second run is a no-op', () async {
    await placeLightProject();
    expect(await run(['--yes']), 0);

    // Everything it just wrote is recorded, so switching back does not report
    // the files as edited.
    expect(await run(['--no-dark', '--yes']), 0);
    expect(read('lib/config/theme/app_theme.dart'), ConfigTemplates.appTheme());
  });

  test('never adds a file the project does not have', () async {
    await placeLightProject();

    expect(await run(['--yes']), 0);
    expect(File(at('lib/shared/widgets/design_system_view.dart')).existsSync(),
        isFalse);
  });

  test('fails outside a scaffolded project', () async {
    expect(await run(['--yes']), 1);

    await Directory(at('lib')).create(recursive: true);
    expect(await run(['--yes']), 1);
  });
}
