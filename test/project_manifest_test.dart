import 'dart:io';

import 'package:moarch/src/utils/project_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_manifest_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  group('hashContent', () {
    test('is stable for the same content', () {
      expect(
        ProjectManifest.hashContent('class AppButton {}'),
        ProjectManifest.hashContent('class AppButton {}'),
      );
    });

    test('differs for different content', () {
      expect(
        ProjectManifest.hashContent('class AppButton {}'),
        isNot(ProjectManifest.hashContent('class AppBadge {}')),
      );
    });

    test('ignores line-ending style', () {
      // A CRLF checkout of an untouched file must not read as an edit.
      expect(
        ProjectManifest.hashContent('a\r\nb\r\nc'),
        ProjectManifest.hashContent('a\nb\nc'),
      );
    });

    test('is sensitive to a single character', () {
      expect(
        ProjectManifest.hashContent('final x = 1;'),
        isNot(ProjectManifest.hashContent('final x = 2;')),
      );
    });

    test('produces a 16-character hex digest', () {
      expect(
          ProjectManifest.hashContent('anything'), matches(r'^[0-9a-f]{16}$'));
    });

    test('handles non-ASCII content', () {
      expect(
        ProjectManifest.hashContent('// café ☕'),
        isNot(ProjectManifest.hashContent('// cafe')),
      );
    });
  });

  group('round trip', () {
    test('saves and reloads version, stack and file hashes', () async {
      final manifest = ProjectManifest(
        version: '2.2.2',
        generatedAt: DateTime(2026, 1, 1),
        stack: ['Dio (REST API)', 'Router (GoRouter)'],
      )..record(
          tempDir.path,
          p.join(tempDir.path, 'lib', 'shared', 'widgets', 'app_button.dart'),
          'class AppButton {}',
        );

      await manifest.save(tempDir.path);
      final loaded = ProjectManifest.load(tempDir.path)!;

      expect(loaded.stack, ['Dio (REST API)', 'Router (GoRouter)']);
      expect(
        loaded.recordedHash(
          tempDir.path,
          p.join(tempDir.path, 'lib', 'shared', 'widgets', 'app_button.dart'),
        ),
        ProjectManifest.hashContent('class AppButton {}'),
      );
    });

    test('keys are forward-slashed so a manifest is portable', () async {
      final manifest = ProjectManifest(
        version: '2.2.2',
        generatedAt: DateTime(2026, 1, 1),
      )..record(
          tempDir.path,
          p.join(tempDir.path, 'lib', 'shared', 'widgets', 'app_card.dart'),
          'class AppCard {}',
        );

      await manifest.save(tempDir.path);
      final raw = await File(p.join(tempDir.path, ProjectManifest.fileName))
          .readAsString();

      expect(raw, contains('lib/shared/widgets/app_card.dart'));
      expect(raw, isNot(contains(r'lib\shared')));
    });

    test('load returns null when there is no manifest', () {
      expect(ProjectManifest.load(tempDir.path), isNull);
    });

    test('a malformed manifest is treated as absent, not fatal', () async {
      await File(p.join(tempDir.path, ProjectManifest.fileName))
          .writeAsString('this: is: not: valid: yaml: [');

      expect(ProjectManifest.load(tempDir.path), isNull);
    });

    test('loadOrCreate falls back to an empty manifest', () {
      final manifest = ProjectManifest.loadOrCreate(tempDir.path);
      expect(manifest.files, isEmpty);
    });

    test('recordedHash is null for a file moarch never wrote', () async {
      await ProjectManifest(
        version: '2.2.2',
        generatedAt: DateTime(2026, 1, 1),
      ).save(tempDir.path);

      final loaded = ProjectManifest.load(tempDir.path)!;
      expect(
        loaded.recordedHash(
            tempDir.path, p.join(tempDir.path, 'lib/mine.dart')),
        isNull,
      );
    });

    test('stack entries containing quotes survive the round trip', () async {
      await ProjectManifest(
        version: '2.2.2',
        generatedAt: DateTime(2026, 1, 1),
        stack: ["Media Service (Image Picker and File Picker)"],
      ).save(tempDir.path);

      final loaded = ProjectManifest.load(tempDir.path)!;
      expect(
          loaded.stack.single, 'Media Service (Image Picker and File Picker)');
    });
  });
}
