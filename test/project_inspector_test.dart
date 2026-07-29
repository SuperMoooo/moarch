import 'dart:io';

import 'package:moarch/src/utils/file_utils.dart';
import 'package:moarch/src/utils/project_inspector.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String root;
  late String libPath;

  /// A project that passes every structural check, so each test can break
  /// exactly one thing and assert on that finding alone.
  Future<void> scaffoldHealthyProject() async {
    for (final dir in ['core', 'config', 'shared']) {
      await Directory(p.join(libPath, dir)).create(recursive: true);
    }
    await File(p.join(libPath, 'main.dart')).writeAsString('void main() {}');
    await File(p.join(root, '.env')).writeAsString('API_URL=http://x');
    await File(p.join(root, '.fvmrc')).writeAsString('{}');
    await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: demo

dependencies:
  flutter_riverpod: ^2.0.0
  envied: ^0.5.0
''');
  }

  /// Writes a widget from the catalog into the project as the generator would.
  Future<void> writeWidget(String name) async {
    final spec = WidgetCatalog.byName(name)!;
    final path = p.join(libPath, 'shared', 'widgets', spec.file);
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(spec.template());
  }

  List<Diagnostic> matching(List<Diagnostic> findings, String fragment) =>
      findings.where((f) => f.message.contains(fragment)).toList();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_inspector_test');
    root = tempDir.path;
    libPath = p.join(root, 'lib');
    FileUtils.beginSession();
  });

  tearDown(() async => tempDir.delete(recursive: true));

  group('structure', () {
    test('a healthy project reports nothing', () async {
      await scaffoldHealthyProject();
      expect(await ProjectInspector.inspect(root), isEmpty);
    });

    test('flags each missing structural piece', () async {
      await scaffoldHealthyProject();
      await Directory(p.join(libPath, 'core')).delete();
      await File(p.join(root, '.env')).delete();

      final findings = await ProjectInspector.inspect(root);
      expect(matching(findings, 'lib/core/'), hasLength(1));
      expect(matching(findings, '.env'), hasLength(1));
    });
  });

  group('code generation', () {
    test('flags app_env.g.dart when build_runner has not run', () async {
      await scaffoldHealthyProject();
      final envDir = p.join(libPath, 'config', 'env');
      await Directory(envDir).create(recursive: true);
      await File(p.join(envDir, 'app_env.dart')).writeAsString('// envied');

      final findings = await ProjectInspector.inspect(root);
      final finding = matching(findings, 'app_env.g.dart').single;
      expect(finding.severity, DiagnosticSeverity.error);
      expect(finding.hint, contains('build_runner'));
    });

    test('stays quiet once app_env.g.dart exists', () async {
      await scaffoldHealthyProject();
      final envDir = p.join(libPath, 'config', 'env');
      await Directory(envDir).create(recursive: true);
      await File(p.join(envDir, 'app_env.dart')).writeAsString('// envied');
      await File(p.join(envDir, 'app_env.g.dart')).writeAsString('// generated');

      expect(
        matching(await ProjectInspector.inspect(root), 'app_env.g.dart'),
        isEmpty,
      );
    });
  });

  group('localization', () {
    test('flags both localization approaches installed at once', () async {
      await scaffoldHealthyProject();
      await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: demo

dependencies:
  flutter_riverpod: ^2.0.0
  envied: ^0.5.0
  easy_localization: ^3.0.0
  flutter_localizations:
    sdk: flutter
''');

      final finding = matching(
        await ProjectInspector.inspect(root),
        'both flutter_localizations and easy_localization',
      ).single;
      expect(finding.severity, DiagnosticSeverity.warning);
      // Which one to drop is the user's call, not ours.
      expect(finding.isFixable, isFalse);
    });

    test('flags flutter_localizations without its l10n files', () async {
      await scaffoldHealthyProject();
      await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: demo

dependencies:
  flutter_riverpod: ^2.0.0
  envied: ^0.5.0
  flutter_localizations:
    sdk: flutter
''');

      expect(
        matching(await ProjectInspector.inspect(root), 'lib/l10n/ is missing'),
        hasLength(1),
      );
    });
  });

  group('router', () {
    test('flags go_router without config/router/', () async {
      await scaffoldHealthyProject();
      await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: demo

dependencies:
  flutter_riverpod: ^2.0.0
  envied: ^0.5.0
  go_router: ^14.0.0
''');

      expect(
        matching(await ProjectInspector.inspect(root), 'config/router/ is missing'),
        hasLength(1),
      );
    });

    test('flags config/router/ without go_router', () async {
      await scaffoldHealthyProject();
      final routerDir = p.join(libPath, 'config', 'router');
      await Directory(routerDir).create(recursive: true);
      await File(p.join(routerDir, 'app_router.dart')).writeAsString('// router');

      expect(
        matching(
          await ProjectInspector.inspect(root),
          'go_router is not in pubspec.yaml',
        ),
        hasLength(1),
      );
    });
  });

  group('widget kit', () {
    test('flags a widget whose dependency was never generated', () async {
      await scaffoldHealthyProject();
      // AppSwitch imports AppInputStyle; generate only the switch.
      await writeWidget('switch');

      final finding = matching(
        await ProjectInspector.inspect(root),
        'AppInputStyle is missing',
      ).single;
      expect(finding.severity, DiagnosticSeverity.error);
      expect(finding.isFixable, isTrue);
    });

    test('the fix generates the missing dependency', () async {
      await scaffoldHealthyProject();
      await writeWidget('switch');

      final finding = matching(
        await ProjectInspector.inspect(root),
        'AppInputStyle is missing',
      ).single;
      await finding.fix!();

      final style = WidgetCatalog.byName('input-style')!;
      expect(
        File(p.join(libPath, 'shared', 'widgets', style.file)).existsSync(),
        isTrue,
      );
      // And the project is clean afterwards.
      expect(
        matching(await ProjectInspector.inspect(root), 'AppInputStyle is missing'),
        isEmpty,
      );
    });

    test('names every dependent of a missing widget', () async {
      await scaffoldHealthyProject();
      await writeWidget('switch');
      await writeWidget('slider');

      final finding = matching(
        await ProjectInspector.inspect(root),
        'AppInputStyle is missing',
      ).single;
      expect(finding.message, contains('slider'));
      expect(finding.message, contains('switch'));
    });

    test('flags a pub package a generated widget needs', () async {
      await scaffoldHealthyProject();
      await writeWidget('avatar'); // needs cached_network_image

      final finding = matching(
        await ProjectInspector.inspect(root),
        'cached_network_image is missing',
      ).single;
      expect(finding.isFixable, isTrue);
    });

    test('the fix adds the package to pubspec.yaml', () async {
      await scaffoldHealthyProject();
      await writeWidget('avatar');

      final finding = matching(
        await ProjectInspector.inspect(root),
        'cached_network_image is missing',
      ).single;
      await finding.fix!();

      final pubspec = await File(p.join(root, 'pubspec.yaml')).readAsString();
      expect(pubspec, contains('cached_network_image'));
      expect(
        matching(
          await ProjectInspector.inspect(root),
          'cached_network_image is missing',
        ),
        isEmpty,
      );
    });

    test('stays quiet when the package is already present', () async {
      await scaffoldHealthyProject();
      await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: demo

dependencies:
  flutter_riverpod: ^2.0.0
  envied: ^0.5.0
  cached_network_image: ^3.0.0
''');
      await writeWidget('avatar');

      expect(
        matching(await ProjectInspector.inspect(root), 'cached_network_image'),
        isEmpty,
      );
    });

    test('reports nothing when no widgets are generated', () async {
      await scaffoldHealthyProject();
      expect(await ProjectInspector.inspect(root), isEmpty);
    });
  });

  group('generatedWidgets', () {
    test('detects exactly the widgets present on disk', () async {
      await scaffoldHealthyProject();
      await writeWidget('button');
      await writeWidget('card');

      final names =
          ProjectInspector.generatedWidgets(libPath).map((s) => s.name).toSet();
      expect(names, {'button', 'card'});
    });

    test('is empty for a project with no widgets', () async {
      await scaffoldHealthyProject();
      expect(ProjectInspector.generatedWidgets(libPath), isEmpty);
    });
  });
}
