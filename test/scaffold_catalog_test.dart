import 'dart:io';

import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ScaffoldCatalog', () {
    test('every slug is unique', () {
      final seen = <String>{};
      final duplicates = <String>[];
      for (final name in ScaffoldCatalog.names) {
        if (!seen.add(name)) duplicates.add(name);
      }
      expect(duplicates, isEmpty);
    });

    test('no slug collides with a widget slug', () {
      // `moarch update <name>` resolves against both catalogs, so a name that
      // means two things would silently update the wrong file.
      final widgets = WidgetCatalog.names.toSet();
      expect(
        ScaffoldCatalog.names.where(widgets.contains),
        isEmpty,
      );
    });

    test('no slug collides with a group slug or with `all`', () {
      final reserved = {...ScaffoldCatalog.groups.keys, 'widgets', 'all'};
      expect(
        [...ScaffoldCatalog.names, ...WidgetCatalog.names]
            .where(reserved.contains),
        isEmpty,
      );
    });

    test('every category is declared, and every declared one is used', () {
      final used = ScaffoldCatalog.all.map((spec) => spec.category).toSet();
      expect(used.difference(ScaffoldCatalog.categories.toSet()), isEmpty);
      expect(ScaffoldCatalog.categories.toSet().difference(used), isEmpty);
    });

    test('every group resolves to specs', () {
      for (final group in ScaffoldCatalog.groups.keys) {
        expect(ScaffoldCatalog.byGroup(group), isNotEmpty, reason: group);
      }
      expect(ScaffoldCatalog.byGroup('not-a-group'), isEmpty);
    });

    test('paths are project-relative and use forward slashes', () {
      for (final spec in ScaffoldCatalog.all) {
        expect(spec.path, isNot(contains(r'\')), reason: spec.name);
        expect(p.posix.isAbsolute(spec.path), isFalse, reason: spec.name);
      }
    });

    test('byName finds an entry and rejects an unknown one', () {
      expect(ScaffoldCatalog.byName('validation')?.title, 'ValidationService');
      expect(ScaffoldCatalog.byName('nope'), isNull);
    });
  });

  group('ScaffoldContext', () {
    late Directory tempDir;
    late String root;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_scaffold_test');
      root = tempDir.path;
    });

    tearDown(() async => tempDir.delete(recursive: true));

    test('a package is matched as a whole entry, not as a substring', () {
      const context = ScaffoldContext(
        projectRoot: '.',
        pubspec: 'dependencies:\n  dio_smart_retry: ^7.0.0\n'
            '  local_auth_android: ^1.0.0\n',
      );

      expect(context.hasPackage('dio_smart_retry'), isTrue);
      expect(context.hasPackage('dio'), isFalse);
      expect(context.hasPackage('local_auth'), isFalse);
    });

    test('detect reads the pubspec, or copes without one', () async {
      expect(ScaffoldContext.detect(root).hasCrashlytics, isFalse);

      await File(p.join(root, 'pubspec.yaml')).writeAsString(
        'name: demo\ndependencies:\n  firebase_crashlytics: ^4.0.0\n',
      );

      expect(ScaffoldContext.detect(root).hasCrashlytics, isTrue);
    });

    test('options are read off the files that were generated', () async {
      final context = ScaffoldContext.detect(root);
      expect(context.hasRouter, isFalse);
      expect(context.hasBiometric, isFalse);

      final router =
          File(p.join(root, 'lib', 'config', 'router', 'app_router.dart'));
      await router.parent.create(recursive: true);
      await router.writeAsString('// router');

      expect(ScaffoldContext.detect(root).hasRouter, isTrue);
    });

    test('generated lists only the files a project actually has', () async {
      expect(ScaffoldCatalog.generated(root), isEmpty);

      final validation = File(
          p.join(root, 'lib', 'core', 'security', 'validation_service.dart'));
      await validation.parent.create(recursive: true);
      await validation.writeAsString('// validation');

      expect(
        ScaffoldCatalog.generated(root).map((spec) => spec.name),
        ['validation'],
      );
    });
  });
}
