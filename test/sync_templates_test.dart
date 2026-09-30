import 'dart:io';

import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/templates/core/cache_templates.dart';
import 'package:moarch/src/templates/core/sync_templates.dart';
import 'package:moarch/src/templates/misc/agents_templates.dart';
import 'package:moarch/src/templates/misc/readme_templates.dart';
import 'package:moarch/src/templates/misc/skills_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/injector_utils.dart';
import 'package:moarch/src/utils/package_versions.dart';
import 'package:moarch/src/utils/platform_requirements.dart';
import 'package:moarch/src/utils/plist_utils.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('the database with sync', () {
    test('adds the PendingWrites queue only with sync', () {
      final synced = CacheTemplates.appDatabase(withSync: true);
      final cacheOnly = CacheTemplates.appDatabase();

      expect(synced, contains('class PendingWrites extends Table'));
      expect(
        synced,
        contains('@DriftDatabase(tables: [CacheEntries, PendingWrites])'),
      );
      expect(synced, contains('DriftNativeOptions(shareAcrossIsolates: true)'));
      expect(cacheOnly, isNot(contains('PendingWrites')));
      expect(cacheOnly, contains('@DriftDatabase(tables: [CacheEntries])'));
    });

    test('an upgrade rebuilds the cache and never the queue', () {
      final synced = CacheTemplates.appDatabase(withSync: true);

      expect(
        synced,
        contains(
          '          await m.createTable(cacheEntries);\n'
          '          // PendingWrites holds writes the server has not seen',
        ),
      );
      expect(synced, isNot(contains('deleteTable(pendingWrites')));
    });

    test('clearAll empties the queue too, only with sync', () {
      final synced = CacheTemplates.localCache(withSync: true);

      expect(synced, contains('await _db.delete(_db.pendingWrites).go();'));
      expect(synced, contains("appLogger.scoped('LocalCache')"));
      expect(CacheTemplates.localCache(), isNot(contains('pendingWrites')));
    });

    test('LocalCache writes one record at a time', () {
      final source = CacheTemplates.localCache();

      expect(source, contains('Future<void> put<T>('));
      expect(source, contains('Future<void> remove(String collection'));
      expect(source, contains('insertOnConflictUpdate('));
    });
  });

  group('the sync files', () {
    test('the queue stores what a SyncRequest describes', () {
      final source = SyncTemplates.syncQueue();

      expect(source, contains('class SyncRequest {'));
      expect(
        source,
        contains("const SyncRequest.post(String path, Object? body)"),
      );
      expect(
        source,
        contains('Future<void> add(String collection, SyncRequest request)'),
      );
      expect(source, contains('Stream<int> watchCount()'));
      expect(source, contains('OrderingTerm.asc(write.id)'));
    });

    for (final stateManagement in StateManagement.values) {
      test('the service follows the status rules ($stateManagement)', () {
        final source = SyncTemplates.syncService(
          stateManagement: stateManagement,
        );

        expect(
          source,
          contains('} on NetworkException {\n            return;'),
        );
        expect(source, contains('if (status == 401) return;'));
        expect(
          source,
          contains(
            'final refused = status != null && status >= 400 && status < 500;',
          ),
        );
        expect(source, contains('static const int maxAttempts = 5;'));
        expect(source, contains('_rejected.add(RejectedWrite(write, error));'));
        // A write queued mid-run is picked up by the same run.
        expect(source, contains('while (true) {'));
        expect(source, contains('await _refresh(touched);'));
        expect(source, contains('AppLifecycleListener(onResume:'));
        expect(source, contains('_connectivity.onReconnect(drain)'));
        expect(source, contains("import '../database/app_database.dart';"));
      });
    }

    test('the pending count is a provider or a cubit, by stack', () {
      final riverpod = SyncTemplates.syncService();
      final bloc = SyncTemplates.syncService(
        stateManagement: StateManagement.bloc,
      );

      expect(riverpod, contains('final pendingSyncCountProvider'));
      expect(riverpod, isNot(contains('Cubit')));
      expect(bloc, contains('class PendingSyncCubit extends Cubit<int>'));
      expect(bloc, isNot(contains('flutter_riverpod')));
    });

    test('the background task registers under the plist identifier', () {
      final source = SyncTemplates.backgroundSync();

      expect(source, contains("const backgroundSyncTask = 'outbox-sync';"));
      expect(source, contains("@pragma('vm:entry-point')"));
      expect(source, contains('frequency: const Duration(minutes: 15)'));
      expect(source, contains('networkType: NetworkType.connected'));
      expect(source, contains('DartPluginRegistrant.ensureInitialized();'));
      expect(source, contains("import 'dart:ui';"));
      expect(source, contains('await db.close();'));
      expect(source, contains('final dio = buildDioClient(tokens);'));
      expect(source, isNot(contains('AuthRemoteDataSource')));
    });

    test('with REST auth it refreshes tokens and checks the session', () {
      final source = SyncTemplates.backgroundSync(withRestAuth: true);

      expect(source, contains('refreshSession: () async {'));
      expect(
        source,
        contains('AuthRemoteDataSource(\n        dio,\n      ).refresh('),
      );
      expect(
        source,
        contains(
          '    try {\n'
          "      // Signed out: nothing to send on anyone's behalf.\n"
          '      if (await tokens.refreshToken == null) return true;',
        ),
      );
    });

    test('the setup doc fills in the app id when it has one', () {
      expect(
        SyncTemplates.setupDoc(androidApplicationId: 'dev.shop.app'),
        contains('adb shell cmd jobscheduler run -f dev.shop.app 999'),
      );
      expect(
        SyncTemplates.setupDoc(),
        contains('run -f <your.package.name> 999'),
      );
      expect(
        SyncTemplates.setupDoc(),
        contains('<string>outbox-sync</string>'),
      );
    });
  });

  group('a synced feature', () {
    test('the remote datasource describes its writes', () {
      for (final stateManagement in StateManagement.values) {
        final source = StackTemplates(stateManagement).featureRemoteDatasource(
          'order',
          'Order',
          'order',
          withApiConstant: true,
          withSync: true,
        );

        expect(
          source,
          contains("import '../../../../core/sync/sync_queue.dart';\n"),
        );
        expect(
          source,
          contains(
            "return SyncRequest.post(ApiConstants.order, item.toJson()..remove('id'));",
          ),
        );
        expect(
          source,
          contains(r"SyncRequest.put('${ApiConstants.order}/${item.id}'"),
        );
        expect(
          source,
          contains(r"SyncRequest.delete('${ApiConstants.order}/$id')"),
        );
        expect(source, contains('  }\n\n  // Writes are described'));
      }
    });

    test('a literal path goes in as it is', () {
      final source = const StackTemplates(
        StateManagement.riverpod,
      ).featureRemoteDatasource('order', 'Order', 'order', withSync: true);

      expect(source, contains(r"SyncRequest.put('/order/${item.id}'"));
    });

    test('the interface declares the writes only with sync', () {
      const stack = StackTemplates(StateManagement.bloc);

      expect(
        stack.featureRepositoryInterface('order', 'Order', withWrites: true),
        contains('Future<void> create(OrderModel item);'),
      );
      expect(
        stack.featureRepositoryInterface('order', 'Order'),
        isNot(contains('create(')),
      );
    });

    test('the repository applies to the cache, then enqueues', () {
      final source = CacheTemplates.repositoryImpl(
        'order',
        'Order',
        withSync: true,
      );

      expect(
        source,
        contains(
          'OrderRepositoryImpl(this._remote, this._local, this._sync) {',
        ),
      );
      expect(
        source,
        contains(
          '_sync.refreshOnSync(OrderLocalDataSource.collection, fetchAll);',
        ),
      );
      expect(
        source,
        contains(
          '    await _local.save(item);\n'
          '    await _sync.enqueue(OrderLocalDataSource.collection, _remote.update(item));',
        ),
      );
      expect(source, contains('-DateTime.now().microsecondsSinceEpoch'));
      expect(
        CacheTemplates.repositoryImpl('order', 'Order'),
        isNot(contains('SyncService')),
      );
    });

    test('the repository registration gets the SyncService', () {
      final registrations = InjectorUtils.registrationsFor(
        featureName: 'order',
        className: 'Order',
        hasRemote: true,
        hasLocal: true,
        hasRepository: true,
        hasBloc: false,
        useFirestore: false,
        withLocalCache: true,
        withSync: true,
      );

      expect(registrations.data, contains('      getIt<SyncService>(),'));
      expect(
        registrations.dataImports,
        contains("import '../../core/sync/sync_service.dart';"),
      );
    });
  });

  group('the app around it', () {
    test('the core module registers the queue and the service', () {
      final source = InjectorTemplates.coreModule(
        withConnectivity: true,
        withLocalCache: true,
        withSync: true,
      );

      expect(source, contains('registerLazySingleton<SyncQueue>('));
      expect(source, contains('registerLazySingleton<SyncService>('));
      expect(source, contains('getIt<ConnectivityService>(),'));
      expect(source, contains("import 'package:dio/dio.dart';\n\n"));
    });

    test('main.dart starts the sync and the background task', () {
      for (final stateManagement in StateManagement.values) {
        final stack = StackTemplates(stateManagement);
        final synced = stack.mainDart(withSync: true);

        expect(synced, contains('  getIt<SyncService>().start();\n'));
        expect(synced, contains('  await registerBackgroundSync();\n'));
        expect(synced, contains("import 'core/sync/background_sync.dart';"));
        expect(stack.mainDart(), isNot(contains('SyncService')));
      }
    });

    test('Info.plist gets the refresh mode and the identifier', () {
      const plist =
          '<plist><dict>\n'
          '\t<key>UIBackgroundModes</key>\n'
          '\t<array>\n'
          '\t\t<string>remote-notification</string>\n'
          '\t</array>\n'
          '</dict></plist>';

      final out = PlatformRequirement.backgroundSync.patchPlist(plist);

      // Added to the existing array, not a second one.
      expect(
        out,
        contains(
          '\t<array>\n'
          '\t\t<string>remote-notification</string>\n'
          '\t\t<string>fetch</string>\n'
          '\t</array>',
        ),
      );
      expect('<key>UIBackgroundModes</key>'.allMatchesIn(out), 1);
      expect(out, contains('<key>BGTaskSchedulerPermittedIdentifiers</key>'));
      expect(out, contains('<string>outbox-sync</string>'));
      expect(PlatformRequirement.backgroundSync.isDescribedIn(out), isTrue);
    });

    test('ensureArrayValues leaves a complete array alone', () {
      const plist =
          '<dict>\n\t<key>K</key>\n\t<array>\n\t\t<string>a</string>\n'
          '\t</array>\n</dict>';

      expect(PlistUtils.ensureArrayValues(plist, 'K', ['a']), plist);
    });

    test('the docs describe sync only with it', () {
      final withSync = AgentsTemplates.agentsMd(
        projectName: 'demo',
        stateManagement: StateManagement.riverpod,
        withDio: true,
        withLocalCache: true,
        withSync: true,
      );
      expect(withSync, contains('### Writes (offline sync)'));
      expect(
        AgentsTemplates.agentsMd(
          projectName: 'demo',
          stateManagement: StateManagement.riverpod,
          withDio: true,
          withLocalCache: true,
        ),
        isNot(contains('offline sync')),
      );

      expect(
        ReadmeTemplates.projectReadme(
          projectName: 'demo',
          stateManagement: StateManagement.bloc,
          withSync: true,
        ),
        contains('pub.dev/packages/workmanager'),
      );

      final skills = [
        for (final skill in SkillsTemplates.all)
          SkillsTemplates.skill(
            skill,
            const SkillOptions(
              stateManagement: StateManagement.riverpod,
              withDio: true,
              withLocalCache: true,
              withSync: true,
            ),
          ),
      ].join();
      expect(skills, contains('`_sync.enqueue(collection, request)`'));
    });
  });

  group('detection and the catalog', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_sync_test');
    });

    tearDown(() async => tempDir.delete(recursive: true));

    test('hasSync reads sync_service.dart off disk', () async {
      expect(ScaffoldContext.detect(tempDir.path).hasSync, isFalse);
      await File(
        p.join(tempDir.path, 'lib', 'core', 'sync', 'sync_service.dart'),
      ).create(recursive: true);
      expect(ScaffoldContext.detect(tempDir.path).hasSync, isTrue);
    });

    test('every sync file is a catalog entry', () {
      final byName = {for (final s in ScaffoldCatalog.all) s.name: s.path};

      expect(byName['sync-queue'], 'lib/core/sync/sync_queue.dart');
      expect(byName['sync-service'], 'lib/core/sync/sync_service.dart');
      expect(byName['background-sync'], 'lib/core/sync/background_sync.dart');
      expect(byName['sync-setup'], 'docs/SYNC_SETUP.md');
    });

    test('workmanager carries a constraint', () {
      expect(PackageVersions.packages, contains('workmanager'));
    });
  });
}

extension on String {
  int allMatchesIn(String source) => allMatches(source).length;
}
