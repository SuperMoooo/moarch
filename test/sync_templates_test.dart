import 'dart:io';

import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/templates/core/cache_templates.dart';
import 'package:moarch/src/templates/core/sync_templates.dart';
import 'package:moarch/src/templates/misc/agents_templates.dart';
import 'package:moarch/src/templates/misc/project_docs_templates.dart';
import 'package:moarch/src/templates/misc/readme_templates.dart';
import 'package:moarch/src/templates/misc/skills_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/injector_utils.dart';
import 'package:moarch/src/utils/package_versions.dart';
import 'package:moarch/src/utils/platform_requirements.dart';
import 'package:moarch/src/utils/plist_utils.dart';
import 'package:moarch/src/utils/project_inspector.dart';
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
          '          for (final table in allTables) {\n'
          '            if (table == pendingWrites) continue;\n'
          '            await m.deleteTable(table.actualTableName);',
        ),
      );
      expect(
        synced,
        contains('// PendingWrites holds writes the server has not seen'),
      );
      expect(CacheTemplates.appDatabase(), isNot(contains('pendingWrites')));
    });

    test('clearAll empties the queue too, only with sync', () {
      final synced = CacheTemplates.localCache(withSync: true);

      expect(synced, contains('for (final table in _db.allTables) {'));
      expect(
        synced,
        contains('if (table == _db.pendingWrites && dropped > 0)'),
      );
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
        contains(
          'Future<void> add(String collection, SyncRequest request, {Object? recordId})',
        ),
      );
      expect(source, contains('Stream<int> watchCount()'));
      expect(source, contains('OrderingTerm.asc(write.id)'));
    });

    test('every write gets an idempotency key, kept in the queue', () {
      final queue = SyncTemplates.syncQueue();
      final service = SyncTemplates.syncService();
      final database = CacheTemplates.appDatabase(withSync: true);

      expect(queue, contains('idempotencyKey: Value(_newKey()),'));
      expect(queue, contains('Random.secure()'));
      expect(service, contains("headers: {'Idempotency-Key': ?key},"));
      expect(
        database,
        contains('TextColumn get idempotencyKey => text().nullable()();'),
      );
    });

    test('a create resolves the writes queued for its temporary id', () {
      final queue = SyncTemplates.syncQueue();
      final service = SyncTemplates.syncService();

      expect(
        queue,
        contains(
          'Future<void> resolve(String collection, String temporaryId, Object id)',
        ),
      );
      expect(
        queue,
        contains("path: Value(_swapSegment(write.path, temporaryId, '\$id')),"),
      );
      expect(queue, contains("return jsonEncode({...json, 'id': to});"));
      expect(service, contains('static Object? createdIdOf(Object? response)'));
      // The writes behind it changed, so the run reads the queue again.
      expect(
        service,
        contains('if (await _resolveCreate(write, response)) break;'),
      );
      // A refused create takes its record's writes with it.
      expect(
        service,
        contains(
          'await _queue.removeRecord(write.collection, write.recordId!);',
        ),
      );
      // A write made between the answer and the refetch is resolved too.
      expect(
        service,
        contains("final created = _created['\$collection/\$recordId'];"),
      );
    });

    test('an existing queue gains the new columns when it opens', () {
      final synced = CacheTemplates.appDatabase(withSync: true);

      expect(
        synced,
        contains('beforeOpen: (details) => _addMissingQueueColumns(),'),
      );
      expect(
        synced,
        contains("customSelect('PRAGMA table_info(pending_writes)')"),
      );
      expect(
        synced,
        contains('await migrator.addColumn(pendingWrites, column);'),
      );
      expect(CacheTemplates.appDatabase(), isNot(contains('beforeOpen')));
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

    test('the repository has the writes only with sync', () {
      const stack = StackTemplates(StateManagement.bloc);

      expect(
        stack.featureRepository(
          'order',
          'Order',
          'order',
          hasRemote: true,
          hasLocal: true,
          offlineFirst: true,
          withSync: true,
        ),
        contains('Future<void> create(OrderModel item) async {'),
      );
      expect(
        stack.featureRepository(
          'order',
          'Order',
          'order',
          hasRemote: true,
          hasLocal: true,
          offlineFirst: true,
        ),
        isNot(contains('create(')),
      );
    });

    test('the repository applies to the cache, then enqueues', () {
      final source = CacheTemplates.repository(
        'order',
        'Order',
        withSync: true,
      );

      expect(
        source,
        contains('OrderRepository(this._remote, this._local, this._sync) {'),
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
          '    await _sync.enqueue(\n'
          '      OrderLocalDataSource.collection,\n'
          '      _remote.update(item),\n'
          '      recordId: item.id,\n'
          '    );',
        ),
      );
      expect(
        source,
        contains('final temporaryId = -DateTime.now().microsecondsSinceEpoch;'),
      );
      expect(source, contains('      recordId: temporaryId,\n'));
      expect(
        CacheTemplates.repository('order', 'Order'),
        isNot(contains('SyncService')),
      );
    });

    test('a refetch keeps the cache while writes are unsent', () {
      final synced = CacheTemplates.repository(
        'order',
        'Order',
        withSync: true,
      );

      expect(
        synced,
        contains(
          '      final items = await _remote.fetchAll();\n'
          '      // Unsent writes show only through the cache: keep it until the sync\n'
          '      // has sent them, then refetches.\n'
          '      if (await _sync.hasPending(OrderLocalDataSource.collection)) {\n'
          '        return _local.readAll();\n'
          '      }\n'
          '      await _local.saveAll(items);',
        ),
      );
      expect(
        CacheTemplates.repository('order', 'Order'),
        isNot(contains('hasPending')),
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

    test('the sync status file: a shared listener, a banner per stack', () {
      final riverpod = const StackTemplates(
        StateManagement.riverpod,
      ).syncStatus();
      final bloc = const StackTemplates(StateManagement.bloc).syncStatus();

      for (final source in [riverpod, bloc]) {
        expect(
          source,
          contains('class SyncStatusListener extends StatefulWidget'),
        );
        expect(
          source,
          contains('getIt<SyncService>().rejected.listen(_show);'),
        );
        // Above the Navigator: it brings the overlay the toast shows in.
        expect(source, contains('Overlay(initialEntries: [_app])'));
        expect(
          source,
          contains('KeyedSubtree(key: _inside, child: widget.child)'),
        );
        expect(source, contains('_app.markNeedsBuild();'));
        expect(source, contains('AppToast.error('));
        expect(source, contains("import 'feedback/app_banner.dart';"));
        expect(source, contains("import 'overlays/app_toast.dart';"));
        expect(source, contains("'\$pending changes waiting to sync'"));
      }
      expect(
        riverpod,
        contains('ref.watch(pendingSyncCountProvider).value ?? 0;'),
      );
      expect(riverpod, isNot(contains('flutter_bloc')));
      expect(bloc, contains('BlocBuilder<PendingSyncCubit, int>('));
      expect(bloc, isNot(contains('flutter_riverpod')));
    });

    test('main.dart mounts the listener only when the file is there', () {
      for (final stateManagement in StateManagement.values) {
        final stack = StackTemplates(stateManagement);
        final synced = stack.mainDart(withSync: true);
        final older = stack.mainDart(withSync: true, withSyncStatus: false);

        expect(synced, contains('SyncStatusListener(child: child!)'));
        expect(synced, contains("import 'shared/widgets/sync_status.dart';"));
        expect(older, isNot(contains('SyncStatusListener')));
        expect(older, isNot(contains('sync_status.dart')));
        expect(older, contains('getIt<SyncService>().start();'));
        expect(stack.mainDart(), isNot(contains('SyncStatusListener')));
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
          const DocsOptions(
            projectName: 'demo',
            stateManagement: StateManagement.bloc,
            withSync: true,
          ),
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
      expect(
        skills,
        contains('`_sync.enqueue(collection, request, recordId: item.id)`'),
      );
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
      expect(byName['sync-status'], 'lib/shared/widgets/sync_status.dart');
    });

    test('hasSyncStatus reads sync_status.dart off disk', () async {
      expect(ScaffoldContext.detect(tempDir.path).hasSyncStatus, isFalse);
      await File(
        p.join(tempDir.path, 'lib', 'shared', 'widgets', 'sync_status.dart'),
      ).create(recursive: true);
      expect(ScaffoldContext.detect(tempDir.path).hasSyncStatus, isTrue);
    });

    test(
      'doctor offers the status file to a sync project without it',
      () async {
        await File(
          p.join(tempDir.path, 'lib', 'core', 'sync', 'sync_service.dart'),
        ).create(recursive: true);

        final before = await ProjectInspector.inspect(tempDir.path);
        final finding = before.singleWhere(
          (d) => d.message.contains('SyncStatusListener'),
        );
        expect(finding.isFixable, isTrue);

        await finding.fix!();
        expect(
          File(
            p.join(
              tempDir.path,
              'lib',
              'shared',
              'widgets',
              'sync_status.dart',
            ),
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            p.join(
              tempDir.path,
              'lib',
              'shared',
              'widgets',
              'feedback',
              'app_banner.dart',
            ),
          ).existsSync(),
          isTrue,
        );
        final after = await ProjectInspector.inspect(tempDir.path);
        expect(
          after.where((d) => d.message.contains('SyncStatusListener')),
          isEmpty,
        );
      },
    );

    test('workmanager carries a constraint', () {
      expect(PackageVersions.packages, contains('workmanager'));
    });
  });
}

extension on String {
  int allMatchesIn(String source) => allMatches(source).length;
}
