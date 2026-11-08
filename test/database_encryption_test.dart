import 'dart:io';

import 'package:moarch/src/templates/core/cache_templates.dart';
import 'package:moarch/src/templates/misc/offline_docs_templates.dart';
import 'package:moarch/src/utils/package_versions.dart';
import 'package:moarch/src/utils/project_inspector.dart';
import 'package:moarch/src/utils/pubspec_utils.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('the encrypted database', () {
    test('opens through the key, only when encrypted', () {
      final encrypted = CacheTemplates.appDatabase(encrypted: true);
      final plain = CacheTemplates.appDatabase();

      expect(encrypted, contains("import 'database_key.dart';\n\npart"));
      expect(
        encrypted,
        contains('executor ??\n              _openEncrypted(),'),
      );
      expect(encrypted, contains('final key = await DatabaseKey.obtain();'));
      expect(encrypted, contains('databasePath: DatabaseKey.databasePath,'));
      expect(encrypted, contains('''db.execute("PRAGMA key = '\$key';");'''));
      expect(encrypted, contains("db.select('PRAGMA cipher').isNotEmpty"));
      expect(plain, isNot(contains('DatabaseKey')));
      expect(plain, isNot(contains('PRAGMA key')));
    });

    test('with sync, the encrypted database is still shared', () {
      final source = CacheTemplates.appDatabase(
        withSync: true,
        encrypted: true,
      );

      expect(source, contains('          shareAcrossIsolates: true,\n'));
      expect(source, isNot(contains('const DriftNativeOptions')));
      expect(source, contains('_addMissingQueueColumns'));
    });

    test('the key is random, kept in secure storage, and replaces a '
        'database it cannot open', () {
      final source = CacheTemplates.databaseKey();

      expect(source, contains('Random.secure()'));
      expect(source, contains('for (var i = 0; i < 32; i++)'));
      expect(source, contains('await _storage.write(key: _name, value: key);'));
      expect(
        source,
        contains("for (final suffix in ['', '-wal', '-shm', '-journal'])"),
      );
      expect(source, contains("return '\${directory.path}/app_cache.sqlite';"));
    });

    test('the guide explains it only with it', () {
      expect(
        OfflineDocsTemplates.doc(withEncryption: true),
        contains('## Encrypted at rest'),
      );
      expect(OfflineDocsTemplates.doc(), isNot(contains('Encrypted at rest')));
    });

    test('is a catalog entry, and path_provider is pinned', () {
      expect(
        ScaffoldCatalog.byName('database-key')?.path,
        'lib/core/database/database_key.dart',
      );
      expect(PackageVersions.packages, contains('path_provider'));
    });
  });

  group('the cipher build in pubspec.yaml', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_encrypt_test');
    });

    tearDown(() async => tempDir.delete(recursive: true));

    Future<void> writePubspec(String content) =>
        File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString(content);

    String readPubspec() =>
        File(p.join(tempDir.path, 'pubspec.yaml')).readAsStringSync();

    test('ensureHookUserDefine adds the section, keeping the rest', () async {
      await writePubspec('name: demo\n\ndependencies:\n  drift: ^2.35.3\n');

      await PubspecUtils.ensureHookUserDefine(
        tempDir.path,
        package: 'sqlite3',
        key: 'source',
        value: 'sqlite3mc',
      );

      final yaml = loadYaml(readPubspec()) as Map;
      expect(yaml['hooks']['user_defines']['sqlite3']['source'], 'sqlite3mc');
      expect(yaml['dependencies']['drift'], '^2.35.3');
    });

    test(
      'ensureHookUserDefine joins existing hooks and keeps a choice',
      () async {
        await writePubspec(
          'name: demo\nhooks:\n  user_defines:\n    other:\n      a: b\n',
        );
        await PubspecUtils.ensureHookUserDefine(
          tempDir.path,
          package: 'sqlite3',
          key: 'source',
          value: 'sqlite3mc',
        );
        var yaml = loadYaml(readPubspec()) as Map;
        expect(yaml['hooks']['user_defines']['other']['a'], 'b');
        expect(yaml['hooks']['user_defines']['sqlite3']['source'], 'sqlite3mc');

        await writePubspec(
          'name: demo\nhooks:\n  user_defines:\n    sqlite3:\n      source: system\n',
        );
        await PubspecUtils.ensureHookUserDefine(
          tempDir.path,
          package: 'sqlite3',
          key: 'source',
          value: 'sqlite3mc',
        );
        yaml = loadYaml(readPubspec()) as Map;
        expect(yaml['hooks']['user_defines']['sqlite3']['source'], 'system');
      },
    );

    test('hasEncryptedDatabase reads database_key.dart off disk', () async {
      expect(
        ScaffoldContext.detect(tempDir.path).hasEncryptedDatabase,
        isFalse,
      );
      await File(
        p.join(tempDir.path, 'lib', 'core', 'database', 'database_key.dart'),
      ).create(recursive: true);
      expect(ScaffoldContext.detect(tempDir.path).hasEncryptedDatabase, isTrue);
    });

    test('doctor flags a key without the cipher build, and fixes it', () async {
      await writePubspec('name: demo\n\ndependencies:\n  drift: ^2.35.3\n');
      await File(
        p.join(tempDir.path, 'lib', 'core', 'database', 'database_key.dart'),
      ).create(recursive: true);

      final before = await ProjectInspector.inspect(tempDir.path);
      final finding = before.singleWhere(
        (d) => d.message.contains('cipher build'),
      );
      expect(finding.isFixable, isTrue);

      await finding.fix!();
      expect(
        PubspecUtils.hookUserDefine(readPubspec(), 'sqlite3', 'source'),
        'sqlite3mc',
      );
      final after = await ProjectInspector.inspect(tempDir.path);
      expect(after.where((d) => d.message.contains('cipher build')), isEmpty);
    });
  });
}
