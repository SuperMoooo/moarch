import 'dart:io';

import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/templates/core/cache_templates.dart';
import 'package:moarch/src/templates/misc/agents_templates.dart';
import 'package:moarch/src/templates/misc/readme_templates.dart';
import 'package:moarch/src/templates/misc/skills_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/injector_utils.dart';
import 'package:moarch/src/utils/package_versions.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('the database', () {
    final source = CacheTemplates.appDatabase();

    test('is one drift table of JSON records, keyed by feature', () {
      expect(source, contains("part 'app_database.g.dart';"));
      expect(source, contains("@DataClassName('CacheEntry')"));
      expect(source, contains('class CacheEntries extends Table'));
      expect(source, contains('@DriftDatabase(tables: [CacheEntries])'));
      expect(
        source,
        contains('Set<Column> get primaryKey => {collection, id};'),
      );
    });

    test('opens through drift_flutter, and takes an executor for tests', () {
      expect(
        source,
        contains("import 'package:drift_flutter/drift_flutter.dart';"),
      );
      expect(source, contains('AppDatabase([QueryExecutor? executor])'));
      expect(source, contains("driftDatabase(name: 'app_cache')"));
    });

    test('rebuilds only the cache table on a schema upgrade', () {
      expect(source, contains('int get schemaVersion => 1;'));
      expect(
        source,
        contains('await m.deleteTable(cacheEntries.actualTableName);'),
      );
      expect(source, contains('await m.createTable(cacheEntries);'));
      expect(source, isNot(contains('allTables')));
    });
  });

  group('LocalCache', () {
    final source = CacheTemplates.localCache();

    test('reads, watches and replaces a collection', () {
      for (final method in [
        'Future<List<T>> readAll<T>(',
        'Stream<List<T>> watchAll<T>(',
        'Future<void> replaceAll<T>(',
        'Future<void> clear(String collection)',
        'Future<void> clearAll()',
      ]) {
        expect(source, contains(method));
      }
    });

    test('replaces in one transaction and reads back in saved order', () {
      expect(source, contains('_db.transaction('));
      expect(source, contains('OrderingTerm.asc(entry.position)'));
      expect(source, contains('mode: InsertMode.insertOrReplace'));
    });
  });

  group('a cached feature', () {
    test('the local datasource keeps its records under the feature name', () {
      final source = CacheTemplates.localDatasource('order', 'Order');

      expect(
        source,
        contains("import '../../../../core/database/local_cache.dart';"),
      );
      expect(source, contains('const OrderLocalDataSource(this._cache);'));
      expect(source, contains("static const String collection = 'order';"));
      expect(source, contains('Future<void> saveAll(List<OrderModel> items)'));
      expect(
        source,
        contains('_cache.watchAll(collection, OrderModel.fromJson)'),
      );
    });

    test('the repository saves the API list and falls back offline', () {
      final source = CacheTemplates.repositoryImpl('order', 'Order');

      expect(
        source,
        contains('const OrderRepositoryImpl(this._remote, this._local);'),
      );
      expect(source, contains('await _local.saveAll(items);'));
      expect(source, contains('} on NetworkException {'));
      expect(source, contains('if (cached.isEmpty) rethrow;'));
      expect(
        source,
        contains('Stream<List<OrderModel>> watchAll() => _local.watchAll();'),
      );
      expect(
        source,
        contains("import '../../../../core/errors/app_exception.dart';"),
      );
    });

    test('is the same data layer in both stacks', () {
      const riverpod = StackTemplates(StateManagement.riverpod);
      const bloc = StackTemplates(StateManagement.bloc);

      expect(
        riverpod.featureLocalDatasource(
          'order',
          'Order',
          'order',
          withCache: true,
        ),
        bloc.featureLocalDatasource('order', 'Order', 'order', withCache: true),
      );
      expect(
        riverpod.featureRepositoryImpl(
          'order',
          'Order',
          'order',
          hasRemote: true,
          hasLocal: true,
          offlineFirst: true,
        ),
        bloc.featureRepositoryImpl(
          'order',
          'Order',
          'order',
          hasRemote: true,
          hasLocal: true,
          offlineFirst: true,
        ),
      );
    });

    test('without the cache the local datasource stays a stub', () {
      for (final stateManagement in StateManagement.values) {
        final source = StackTemplates(
          stateManagement,
        ).featureLocalDatasource('order', 'Order', 'order');

        expect(
          source,
          isNot(contains('LocalCache')),
          reason: '$stateManagement',
        );
        expect(source, contains('TODO'), reason: '$stateManagement');
      }
    });

    test('the Riverpod notifier loads, then follows the cache', () {
      final source = const StackTemplates(
        StateManagement.riverpod,
      ).featureHolder('order', 'Order', 'order', offlineFirst: true);

      expect(source, contains('_repo.watchAll().listen('));
      expect(source, contains('ref.onDispose(subscription.cancel);'));
      expect(
        source,
        contains('return OrderState(items: await _repo.fetchAll());'),
      );
      expect(source, contains('Future<void> refresh() {'));
      // Not the Firestore variant's first-snapshot plumbing.
      expect(source, isNot(contains('Completer')));
    });

    test('the bloc loads through fetchAll as it always does', () {
      const stack = StackTemplates(StateManagement.bloc);

      expect(
        stack.featureHolder('order', 'Order', 'order', offlineFirst: true),
        stack.featureHolder('order', 'Order', 'order'),
      );
    });

    test('the Riverpod view prints an int id through interpolation', () {
      const stack = StackTemplates(StateManagement.riverpod);

      expect(
        stack.featureView(
          'order',
          'Order',
          'order',
          hasHolder: true,
          useFirestore: true,
          offlineFirst: true,
        ),
        contains(r"title: Text('${order.id}'),"),
      );
      // A Firestore id is already a String.
      expect(
        stack.featureView(
          'order',
          'Order',
          'order',
          hasHolder: true,
          useFirestore: true,
        ),
        contains('title: Text(order.id),'),
      );
    });
  });

  group('the locator', () {
    test('the external module holds the database only with the cache', () {
      final withCache = InjectorTemplates.externalModule(
        withDio: true,
        withLocalCache: true,
      );
      final without = InjectorTemplates.externalModule(withDio: true);

      expect(withCache, contains('registerLazySingleton<AppDatabase>('));
      expect(withCache, contains('dispose: (db) => db.close()'));
      expect(
        withCache,
        contains("import '../../core/database/app_database.dart';"),
      );
      expect(without, isNot(contains('AppDatabase')));
    });

    test('the core module holds LocalCache only with the cache', () {
      final withCache = InjectorTemplates.coreModule(withLocalCache: true);
      final without = InjectorTemplates.coreModule();

      expect(withCache, contains('() => LocalCache(getIt<AppDatabase>())'));
      expect(
        withCache,
        contains("import '../../core/database/local_cache.dart';"),
      );
      expect(without, isNot(contains('LocalCache')));
    });

    test('a cached local datasource is built over LocalCache', () {
      InjectorRegistrations register({required bool withLocalCache}) =>
          InjectorUtils.registrationsFor(
            featureName: 'order',
            className: 'Order',
            hasRemote: true,
            hasLocal: true,
            hasRepository: true,
            hasBloc: false,
            useFirestore: false,
            withLocalCache: withLocalCache,
          );

      final cached = register(withLocalCache: true);
      expect(
        cached.data,
        contains('() => OrderLocalDataSource(getIt<LocalCache>())'),
      );
      expect(
        cached.dataImports,
        contains("import '../../core/database/local_cache.dart';"),
      );

      final stub = register(withLocalCache: false);
      expect(stub.data, contains('OrderLocalDataSource.new'));
      expect(stub.dataImports.join(), isNot(contains('local_cache')));
    });
  });

  group('signing out empties the cache', () {
    for (final stateManagement in StateManagement.values) {
      final stack = StackTemplates(stateManagement);

      test('REST auth clears it on logout, delete and sign-in '
          '($stateManagement)', () {
        final source = stack.authRepositoryImpl(withLocalCache: true);

        expect(
          source,
          contains("import '../../../../core/database/local_cache.dart';"),
        );
        expect(
          source,
          contains(
            'AuthRepositoryImpl(this._remote, this._tokens, this._cache);',
          ),
        );
        // Each clear is its own statement, on its own line.
        expect(
          source,
          contains(
            '      await _tokens.clearSession();\n'
            '      await _cache.clearAll();\n'
            '    }',
          ),
        );
        expect(
          source,
          contains(
            '    await _tokens.clearSession();\n'
            '    await _cache.clearAll();\n'
            '  }',
          ),
        );
        expect(
          source,
          contains(
            'Future<UserModel> _startSession(AuthTokensModel tokens) async {\n'
            '    // Whoever was signed in before, their cached data goes.\n'
            '    await _cache.clearAll();\n'
            '    await _tokens.saveSession(',
          ),
        );
        expect(stack.authRepositoryImpl(), isNot(contains('LocalCache')));
      });

      test('Firebase auth clears it on logout and delete '
          '($stateManagement)', () {
        final source = stack.firebaseAuthRepositoryImpl(withLocalCache: true);

        expect(
          source,
          contains('const AuthRepositoryImpl(this._remote, this._cache);'),
        );
        expect(
          source,
          contains(
            '  Future<void> logout() async {\n'
            '    await _remote.logout();\n'
            '    await _cache.clearAll();\n'
            '  }',
          ),
        );
        expect(
          source,
          contains(
            '    await _remote.delete();\n    await _cache.clearAll();\n',
          ),
        );
        expect(
          stack.firebaseAuthRepositoryImpl(),
          contains('Future<void> logout() => _remote.logout();'),
        );
      });
    }

    test('the data module hands the auth repository LocalCache', () {
      final rest = InjectorTemplates.dataModule(
        withDio: true,
        withAuthFeature: true,
        withLocalCache: true,
      );
      expect(
        rest,
        contains(
          '        getIt<TokenStorage>(),\n        getIt<LocalCache>(),\n',
        ),
      );
      expect(rest, contains("import '../../core/database/local_cache.dart';"));

      final firebase = InjectorTemplates.dataModule(
        withAuthFeature: true,
        withFirebaseAuthFeature: true,
        withLocalCache: true,
      );
      expect(
        firebase,
        contains(
          '        getIt<AuthRemoteDataSource>(),\n'
          '        getIt<LocalCache>(),\n',
        ),
      );

      expect(
        InjectorTemplates.dataModule(withDio: true, withAuthFeature: true),
        isNot(contains('LocalCache')),
      );
    });
  });

  group('detection and the catalog', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_cache_test');
    });

    tearDown(() async => tempDir.delete(recursive: true));

    test('hasLocalCache reads local_cache.dart off disk', () async {
      expect(ScaffoldContext.detect(tempDir.path).hasLocalCache, isFalse);

      final file = File(
        p.join(tempDir.path, 'lib', 'core', 'database', 'local_cache.dart'),
      );
      await file.create(recursive: true);

      expect(ScaffoldContext.detect(tempDir.path).hasLocalCache, isTrue);
    });

    test('both files are catalog entries, so update can refresh them', () {
      final byName = {for (final s in ScaffoldCatalog.all) s.name: s};

      expect(
        byName['app-database']?.path,
        'lib/core/database/app_database.dart',
      );
      expect(byName['local-cache']?.path, 'lib/core/database/local_cache.dart');
    });

    test('the drift packages carry constraints', () {
      for (final package in ['drift', 'drift_flutter', 'drift_dev']) {
        expect(PackageVersions.packages, contains(package));
      }
    });
  });

  group('what describes the project', () {
    test('the README lists drift only with the cache', () {
      String readme({required bool withLocalCache}) =>
          ReadmeTemplates.projectReadme(
            projectName: 'demo',
            stateManagement: StateManagement.riverpod,
            withDio: true,
            withLocalCache: withLocalCache,
          );

      expect(readme(withLocalCache: true), contains('pub.dev/packages/drift'));
      expect(
        readme(withLocalCache: false),
        isNot(contains('pub.dev/packages/drift')),
      );
    });

    test('AGENTS.md has the offline-first rules only with the cache', () {
      for (final stateManagement in StateManagement.values) {
        String agents({required bool withLocalCache}) =>
            AgentsTemplates.agentsMd(
              projectName: 'demo',
              stateManagement: stateManagement,
              withDio: true,
              withLocalCache: withLocalCache,
            );

        final withCache = agents(withLocalCache: true);
        expect(withCache, contains('## Offline-first'));
        expect(withCache, contains('getIt<LocalCache>().clearAll()'));
        expect(
          withCache,
          stateManagement.isBloc
              ? isNot(contains('refresh()'))
              : contains('Refetch with its `refresh()`'),
        );
        expect(
          agents(withLocalCache: false),
          isNot(contains('## Offline-first')),
        );
      }
    });

    test('the skills describe the cached data layer only with the cache', () {
      for (final withLocalCache in [true, false]) {
        final options = SkillOptions(
          stateManagement: StateManagement.riverpod,
          withDio: true,
          withLocalCache: withLocalCache,
        );
        final all = [
          for (final skill in SkillsTemplates.all)
            SkillsTemplates.skill(skill, options),
        ].join('\n');

        expect(
          all.contains('saves the\n   API\'s list to `LocalCache`'),
          withLocalCache,
        );
        expect(
          all.contains('A read the screen should have offline'),
          withLocalCache,
        );
      }
    });
  });
}
