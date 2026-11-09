/// The offline-first cache: a drift database under `lib/core/database/`, and
/// the feature layer that reads and writes it.
///
/// None of it holds state, so it is the same in both stacks. The screens are
/// what differ, and they stay in `templates/riverpod/` and `templates/bloc/`.
///
/// A feature's records start out cached as their JSON, one table for every
/// feature: `create feature` has no schema to patch, and the model is empty
/// until someone fills it in. Once it is, `create table` gives the feature a
/// drift table of its own, read from the model's fields (`@UseRowClass`, so
/// the rows are the model and nothing maps between them).
library;

import '../../utils/drift_table_builder.dart';

/// A feature table `AppDatabase` registers: the table class, and the import
/// from `lib/core/database/` that declares it.
typedef FeatureTableRef = ({String className, String importPath});

/// The cache's templates.
abstract final class CacheTemplates {
  /// `lib/core/database/app_database.dart` — the drift database.
  ///
  /// [withSync] adds the `PendingWrites` queue the sync option sends from,
  /// and opens the database so the background task's isolate can share it.
  ///
  /// [featureTables] are the tables `create table` wrote, as found on disk,
  /// and [schemaVersion] the one the project's database is at: both are read
  /// back so `update` refreshes the file without dropping either.
  ///
  /// [encrypted] opens it with the key from `database_key.dart`, through the
  /// SQLite3MultipleCiphers build `pubspec.yaml` selects.
  ///
  /// [keepRecords] is a project whose features keep records only on the
  /// device (`ScaffoldContext.keepsLocalRecords`): an upgrade then creates
  /// the tables that are new and drops nothing, since there is no API to
  /// refetch from. Changed tables are migrated step by step.
  static String appDatabase({
    bool withSync = false,
    List<FeatureTableRef> featureTables = const [],
    int schemaVersion = 1,
    bool encrypted = false,
    bool keepRecords = false,
  }) {
    final queueTable = withSync ? _pendingWritesTable : '';
    final tables = [
      'CacheEntries',
      if (withSync) 'PendingWrites',
      for (final table in featureTables) table.className,
    ].join(', ');
    final tableImports = featureTables.isEmpty
        ? ''
        : '\n${[for (final table in featureTables) "import '${table.importPath}';"].join('\n')}\n';
    final skipQueue = withSync
        ? '\n            if (table == pendingWrites) continue;'
        : '';
    final open = encrypted
        ? '_openEncrypted()'
        : withSync
        ? r'''driftDatabase(
              name: 'app_cache',
              // The background sync task opens it from its own isolate.
              native: const DriftNativeOptions(shareAcrossIsolates: true),
            )'''
        : "driftDatabase(name: 'app_cache')";
    final share = withSync
        ? '''
            // The background sync task opens it from its own isolate.
            shareAcrossIsolates: true,
'''
        : '';
    final openEncrypted = encrypted
        ? '''


  /// Opens the database encrypted with [DatabaseKey]. The key is read first,
  /// so the connection waits for it.
  static QueryExecutor _openEncrypted() {
    return LazyDatabase(() async {
      final key = await DatabaseKey.obtain();
      return driftDatabase(
        name: 'app_cache',
        native: DriftNativeOptions(
          databasePath: DatabaseKey.databasePath,
$share            setup: (db) {
            db.execute("PRAGMA key = '\$key';");
            // A plain SQLite build ignores the key and writes in the clear.
            assert(
              db.select('PRAGMA cipher').isNotEmpty,
              'Not SQLite3MultipleCiphers: pubspec.yaml needs '
              'hooks.user_defines.sqlite3.source: sqlite3mc',
            );
          },
        ),
      );
    });
  }'''
        : '';
    // After the table imports, which end on a newline of their own.
    final keyImport = !encrypted
        ? ''
        : tableImports.isEmpty
        ? "\nimport 'database_key.dart';\n"
        : "import 'database_key.dart';\n";
    final keep = withSync && !keepRecords
        ? r'''

          // PendingWrites holds writes the server has not seen: never drop
          // it. Migrate it step by step instead, keyed on `from`
          // (`fvm dart run drift_dev make-migrations`, docs/OFFLINE_FIRST.md).'''
        : '';
    final beforeOpen = withSync
        ? r'''
        // Columns the queue gained after an app first created it. Added in
        // place on every open, since the queue is never rebuilt.
        beforeOpen: (details) => _addMissingQueueColumns(),
'''
        : '';
    final queueColumns = withSync
        ? r'''


  Future<void> _addMissingQueueColumns() async {
    final rows = await customSelect('PRAGMA table_info(pending_writes)').get();
    final existing = {for (final row in rows) row.read<String>('name')};
    final migrator = createMigrator();
    for (final column in [
      pendingWrites.recordId,
      pendingWrites.idempotencyKey,
    ]) {
      if (!existing.contains(column.name)) {
        await migrator.addColumn(pendingWrites, column);
      }
    }
  }'''
        : '';
    final upgrade = keepRecords
        ? r'''          // Some features keep their records only on this device, with no
          // API to refetch them from: nothing is dropped here. New tables are
          // created; a changed one is migrated step by step, keyed on `from`
          // (`fvm dart run drift_dev make-migrations`, docs/OFFLINE_FIRST.md).
          for (final table in allTables) {
            if (await _tableExists(table.actualTableName)) continue;
            await m.createTable(table);
          }'''
        : '''          // The cache and the feature tables are a copy of what the API has:
          // start them over. A table you add that holds anything the API does
          // not have needs a real migration: skip it here and migrate it.
          for (final table in allTables) {$skipQueue
            await m.deleteTable(table.actualTableName);
            await m.createTable(table);
          }$keep''';
    final tableExists = keepRecords
        ? r'''


  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(name)],
    ).get();
    return rows.isNotEmpty;
  }'''
        : '';
    return '''
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
$tableImports$keyImport
part 'app_database.g.dart';

/// One row per cached record: its JSON, under the collection the feature
/// caches it in (see LocalCache).
@DataClassName('CacheEntry')
class CacheEntries extends Table {
  TextColumn get collection => text()();
  TextColumn get id => text()();

  /// Where the record was in the list it was saved with, so it reads back in
  /// the API's order.
  IntColumn get position => integer()();
  TextColumn get payload => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {collection, id};
}
$queueTable
/// Run `fvm dart run build_runner build --delete-conflicting-outputs` after
/// editing this file.
@DriftDatabase(tables: [$tables])
class AppDatabase extends _\$AppDatabase {
  /// Pass an executor in tests: `AppDatabase(NativeDatabase.memory())`
  /// (`package:drift/native.dart`).
  AppDatabase([QueryExecutor? executor])
      : super(
          executor ??
              $open,
        );

  /// Bump after changing a table. `moarch create table` bumps it for you.
  @override
  int get schemaVersion => $schemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
$upgrade
        },
$beforeOpen      );$queueColumns$tableExists$openEncrypted
}
''';
  }

  static const String _pendingWritesTable = r'''

/// Writes made while the server could not be reached, oldest first (see
/// SyncQueue).
@DataClassName('PendingWrite')
class PendingWrites extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The cache collection the write changed, refetched after it is sent.
  TextColumn get collection => text()();
  TextColumn get method => text()();
  TextColumn get path => text()();

  /// JSON, or null for a request without a body.
  TextColumn get body => text().nullable()();

  /// The record the write changes, as the app knows it: a negative id for one
  /// created offline, until the server answers with its own.
  TextColumn get recordId => text().nullable()();

  /// Sent as the `Idempotency-Key` header, the same on every retry.
  TextColumn get idempotencyKey => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastTriedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
''';

  /// `lib/core/database/database_key.dart` — the key the encrypted database
  /// is opened with, made once and kept in the platform keystore.
  static String databaseKey() => r'''
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// The key the local database is encrypted with: made on the first open and
/// kept in the Keychain / Android Keystore, never in the app's files.
///
/// It does not travel with a backup. A database restored onto a device that
/// never had its key cannot be read, so [obtain] deletes it and the app starts
/// over: the cache refills from the API, but writes that were never sent are
/// lost with it.
abstract final class DatabaseKey {
  static const _storage = FlutterSecureStorage();
  static const _name = 'app_database_key';

  /// Where the database lives. AppDatabase opens it here.
  static Future<String> databasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/app_cache.sqlite';
  }

  /// The key, made the first time it is asked for.
  static Future<String> obtain() async {
    final existing = await _storage.read(key: _name);
    if (existing != null) return existing;
    // No key yet: a database already here was written with another one.
    final path = await databasePath();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      if (file.existsSync()) await file.delete();
    }
    final random = Random.secure();
    final key = [
      for (var i = 0; i < 32; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await _storage.write(key: _name, value: key);
    return key;
  }
}
''';

  /// `lib/core/database/local_cache.dart` — what the features' local
  /// datasources call, so none of them touches drift.
  ///
  /// [withSync] makes `clearAll` empty the queue of unsent writes too: they
  /// belong to the account that is signing out.
  static String localCache({bool withSync = false}) {
    final logImport = withSync ? "\nimport '../utils/app_logger.dart';" : '';
    final logger = withSync
        ? "\n\nfinal _log = appLogger.scoped('LocalCache');"
        : '';
    final clearAll = withSync ? _clearAllWithQueue : _clearAll;
    return '''
import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';$logImport$logger

$_localCacheBody
$clearAll
$_localCacheTail''';
  }

  static const String _clearAll = r'''
  /// Empties every table: the collections and each feature's own table.
  Future<void> clearAll() {
    return _db.transaction(() async {
      for (final table in _db.allTables) {
        await _db.delete(table).go();
      }
    });
  }''';

  static const String _clearAllWithQueue = r'''
  /// Empties every table: the collections, each feature's own table and the
  /// queue of writes not yet sent.
  Future<void> clearAll() {
    return _db.transaction(() async {
      for (final table in _db.allTables) {
        final dropped = await _db.delete(table).go();
        if (table == _db.pendingWrites && dropped > 0) {
          _log.w('$dropped unsent writes dropped');
        }
      }
    });
  }''';

  static const String _localCacheBody = r'''
/// Each feature's records, stored as JSON under the feature's collection name.
/// A feature's local datasource is the only caller.
///
/// [clearAll] runs whenever an account signs out, so the next one does not
/// see its data. The generated auth repository calls it; anything else that
/// switches accounts calls it too.
class LocalCache {
  LocalCache(this._db);

  final AppDatabase _db;

  /// Everything in [collection], in the order it was saved.
  Future<List<T>> readAll<T>(
    String collection,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final rows = await _query(collection).get();
    return _decode(rows, fromJson);
  }

  /// [readAll] now, and again after every write to [collection].
  Stream<List<T>> watchAll<T>(
    String collection,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return _query(collection).watch().map((rows) => _decode(rows, fromJson));
  }

  /// Replaces [collection] with [items], in one transaction: a watcher sees
  /// the old list or the new one, never half of each.
  Future<void> replaceAll<T>(
    String collection,
    List<T> items, {
    required Object Function(T item) idOf,
    required Map<String, dynamic> Function(T item) toJson,
  }) {
    final now = DateTime.now();
    return _db.transaction(() async {
      await clear(collection);
      await _db.batch((batch) {
        batch.insertAll(
          _db.cacheEntries,
          [
            for (final (index, item) in items.indexed)
              CacheEntriesCompanion.insert(
                collection: collection,
                id: '${idOf(item)}',
                position: index,
                payload: jsonEncode(toJson(item)),
                cachedAt: now,
              ),
          ],
          // An id the API sent twice keeps its last copy.
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }

  /// Saves one record: in its place if [collection] has it, at the end if not.
  Future<void> put<T>(
    String collection,
    T item, {
    required Object Function(T item) idOf,
    required Map<String, dynamic> Function(T item) toJson,
  }) async {
    final id = '${idOf(item)}';
    final existing = await (_db.select(_db.cacheEntries)
          ..where((e) => e.collection.equals(collection) & e.id.equals(id)))
        .getSingleOrNull();
    await _db.into(_db.cacheEntries).insertOnConflictUpdate(
          CacheEntriesCompanion.insert(
            collection: collection,
            id: id,
            position: existing?.position ?? await _nextPosition(collection),
            payload: jsonEncode(toJson(item)),
            cachedAt: DateTime.now(),
          ),
        );
  }

  /// Deletes the record [id] from [collection].
  Future<void> remove(String collection, Object id) {
    return (_db.delete(_db.cacheEntries)
          ..where((e) => e.collection.equals(collection) & e.id.equals('$id')))
        .go();
  }

  /// Empties [collection].
  Future<void> clear(String collection) {
    return (_db.delete(_db.cacheEntries)
          ..where((entry) => entry.collection.equals(collection)))
        .go();
  }
''';

  static const String _localCacheTail = r'''

  Future<int> _nextPosition(String collection) async {
    final last = _db.cacheEntries.position.max();
    final row = await (_db.selectOnly(_db.cacheEntries)
          ..addColumns([last])
          ..where(_db.cacheEntries.collection.equals(collection)))
        .getSingle();
    return (row.read(last) ?? -1) + 1;
  }

  SimpleSelectStatement<$CacheEntriesTable, CacheEntry> _query(
    String collection,
  ) {
    return _db.select(_db.cacheEntries)
      ..where((entry) => entry.collection.equals(collection))
      ..orderBy([(entry) => OrderingTerm.asc(entry.position)]);
  }

  List<T> _decode<T>(
    List<CacheEntry> rows,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return [
      for (final row in rows)
        fromJson(jsonDecode(row.payload) as Map<String, dynamic>),
    ];
  }
}
''';

  /// A feature's `data/datasources/<name>_local_datasource.dart` in a project
  /// with the cache: its records under one collection of [LocalCache].
  static String localDatasource(String name, String cls) =>
      '''
import '../../../../core/database/local_cache.dart';
import '../models/${name}_model.dart';

class ${cls}LocalDataSource {
  const ${cls}LocalDataSource(this._cache);

  final LocalCache _cache;

  /// This feature's key in the cache. Changing it orphans what is stored.
  static const String collection = '$name';

  Future<List<${cls}Model>> readAll() {
    return _cache.readAll(collection, ${cls}Model.fromJson);
  }

  Stream<List<${cls}Model>> watchAll() {
    return _cache.watchAll(collection, ${cls}Model.fromJson);
  }

  Future<void> saveAll(List<${cls}Model> items) {
    return _cache.replaceAll(
      collection,
      items,
      idOf: (item) => item.id,
      toJson: (item) => item.toJson(),
    );
  }

  Future<void> save(${cls}Model item) {
    return _cache.put(
      collection,
      item,
      idOf: (item) => item.id,
      toJson: (item) => item.toJson(),
    );
  }

  Future<void> remove(Object id) => _cache.remove(collection, id);
}
''';

  /// A feature's `data/tables/<name>_table.dart`: a drift table with one
  /// column per field of the model, whose rows are the model itself.
  ///
  /// [imports] are the model file's project imports, rewritten for
  /// `data/tables/`: the table needs them for its enums and converters, and
  /// exports them so `app_database.g.dart` (which only sees what
  /// `app_database.dart` imports) can name the same types.
  static String featureTable({
    required String name,
    required String cls,
    required DriftTablePlan plan,
    List<String> imports = const [],
  }) {
    final table = '${cls}Rows';
    final uris = ['../models/${name}_model.dart', ...imports];
    final importLines = [for (final uri in uris) "import '$uri';"].join('\n');
    final exportLines = [for (final uri in uris) "export '$uri';"].join('\n');
    final columns = [
      for (final column in plan.columns)
        '  ${column.columnType} get ${column.name} => '
            '${column.builder}${column.nullable ? '.nullable()' : ''}();',
    ].join('\n');
    final converters = [
      for (final column in plan.columns)
        if (column.converter != null)
          '\n  static final ${column.converterField} = ${column.converter};',
    ].join('\n');
    const order = DriftTableBuilder.orderColumn;
    return '''
import 'package:drift/drift.dart';

$importLines

$exportLines

/// ${cls}Model's table: one column per field, so offline the list can be
/// filtered, sorted and joined in SQL. Its rows are ${cls}Model itself.
///
/// Written by `moarch create table $name` from the model. After changing the
/// model's fields, run it again: it rewrites this file and bumps
/// `schemaVersion`, and the upgrade starts the table over from the API.
@UseRowClass(${cls}Model)
class $table extends Table {
$columns

  /// Where the record was in the list it was saved with, so it reads back in
  /// the API's order. Not a model field: drift leaves it out of the model.
  IntColumn get $order => integer()();

  @override
  Set<Column> get primaryKey => {id};
${converters.isEmpty ? '' : '$converters\n'}}
''';
  }

  /// A feature's local datasource once it has its own table: the same calls
  /// as [localDatasource], answered from `<name>_table.dart` with SQL instead
  /// of from JSON in the shared cache.
  static String tableLocalDatasource({
    required String name,
    required String cls,
    required DriftTablePlan plan,
  }) {
    final table = '${cls}Rows';
    final getter = '${cls[0].toLowerCase()}${cls.substring(1)}Rows';
    final idType = plan.idType ?? 'int';
    const order = DriftTableBuilder.orderColumn;
    final values = [
      for (final column in plan.columns)
        // Optional in the companion: a nullable column, and an int id, which
        // SQLite keeps as the rowid.
        if (column.nullable || (column.name == 'id' && idType == 'int'))
          '      ${column.name}: Value(item.${column.name}),'
        else
          '      ${column.name}: item.${column.name},',
      '      $order: $order,',
    ].join('\n');
    return '''
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../models/${name}_model.dart';

/// ${cls}Model rows in their own table (data/tables/${name}_table.dart).
/// Queries the screens need offline — a filter, a search, a sort — go here,
/// written against the table's columns.
class ${cls}LocalDataSource {
  const ${cls}LocalDataSource(this._db);

  final AppDatabase _db;

  /// This feature's key in the sync queue. Changing it orphans queued writes.
  static const String collection = '$name';

  \$${table}Table get _table => _db.$getter;

  /// Every row, in the order the API sent them.
  Future<List<${cls}Model>> readAll() => _ordered().get();

  /// [readAll] now, and again after every write to the table.
  Stream<List<${cls}Model>> watchAll() => _ordered().watch();

  /// Replaces the table with [items], in one transaction: a watcher sees the
  /// old list or the new one, never half of each.
  Future<void> saveAll(List<${cls}Model> items) {
    return _db.transaction(() async {
      await _db.delete(_table).go();
      await _db.batch((batch) {
        batch.insertAll(
          _table,
          [for (final (index, item) in items.indexed) _row(item, index)],
          // An id the API sent twice keeps its last copy.
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }

  /// Saves one record: in its place if the table has it, at the end if not.
  Future<void> save(${cls}Model item) async {
    final existing = await (_db.selectOnly(_table)
          ..addColumns([_table.$order])
          ..where(_table.id.equals(item.id)))
        .map((row) => row.read(_table.$order))
        .getSingleOrNull();
    await _db
        .into(_table)
        .insertOnConflictUpdate(_row(item, existing ?? await _nextOrder()));
  }

  Future<void> remove($idType id) {
    return (_db.delete(_table)..where((row) => row.id.equals(id))).go();
  }

  SimpleSelectStatement<\$${table}Table, ${cls}Model> _ordered() {
    return _db.select(_table)
      ..orderBy([(row) => OrderingTerm.asc(row.$order)]);
  }

  Future<int> _nextOrder() async {
    final last = _table.$order.max();
    final row = await (_db.selectOnly(_table)..addColumns([last])).getSingle();
    return (row.read(last) ?? -1) + 1;
  }

  ${table}Companion _row(${cls}Model item, int $order) {
    return ${table}Companion.insert(
$values
    );
  }
}
''';
  }

  /// A feature's `data/repositories/<name>_repository.dart` when it has
  /// both a REST datasource and the cache: the API's list is saved to the
  /// cache, the cache is what `watchAll` follows, and offline `fetchAll`
  /// answers from the cache.
  ///
  /// [withSync] adds `create` / `update` / `delete`: each changes the cache
  /// at once and queues the request the remote datasource describes.
  static String repository(String name, String cls, {bool withSync = false}) {
    final syncImport = withSync
        ? "import '../../../../core/sync/sync_service.dart';\n"
        : '';
    final ctor = withSync
        ? '''
  ${cls}Repository(this._remote, this._local, this._sync) {
    // After a sync touches this collection, the server's list replaces what
    // was written offline.
    _sync.refreshOnSync(${cls}LocalDataSource.collection, fetchAll);
  }'''
        : '  const ${cls}Repository(this._remote, this._local);';
    final syncField = withSync ? '\n  final SyncService _sync;' : '';
    final writes = withSync
        ? '''


  /// Shown at once under a temporary negative id, sent when the connection
  /// allows. The refetch after the sync brings the server's id.
  Future<void> create(${cls}Model item) async {
    final temporaryId = -DateTime.now().microsecondsSinceEpoch;
    await _local.save(item.copyWith(id: temporaryId));
    await _sync.enqueue(
      ${cls}LocalDataSource.collection,
      _remote.create(item),
      recordId: temporaryId,
    );
  }

  /// Applied to the cache now, sent to the API when it can be.
  Future<void> update(${cls}Model item) async {
    await _local.save(item);
    await _sync.enqueue(
      ${cls}LocalDataSource.collection,
      _remote.update(item),
      recordId: item.id,
    );
  }

  /// Applied to the cache now, sent to the API when it can be.
  Future<void> delete(int id) async {
    await _local.remove(id);
    await _sync.enqueue(
      ${cls}LocalDataSource.collection,
      _remote.delete(id),
      recordId: id,
    );
  }'''
        : '';
    // With sync, unsent writes exist only in the cache: replacing it with the
    // API's list would hide them until the sync sends them and refetches.
    final keepPending = withSync
        ? '''
      // Unsent writes show only through the cache: keep it until the sync
      // has sent them, then refetches.
      if (await _sync.hasPending(${cls}LocalDataSource.collection)) {
        return _local.readAll();
      }
'''
        : '';
    return '''
import '../../../../core/errors/app_exception.dart';
${syncImport}import '../datasources/${name}_local_datasource.dart';
import '../datasources/${name}_remote_datasource.dart';
import '../models/${name}_model.dart';

class ${cls}Repository {
$ctor

  final ${cls}RemoteDataSource _remote;
  final ${cls}LocalDataSource _local;$syncField

  /// The API's list, saved to the cache. Offline, the cached list — unless
  /// there is none yet, when the NetworkException is the honest answer.
  Future<List<${cls}Model>> fetchAll() async {
    try {
      final items = await _remote.fetchAll();
$keepPending      await _local.saveAll(items);
      return items;
    } on NetworkException {
      final cached = await _local.readAll();
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  /// The cache: emits now, and again whenever [fetchAll] saves to it.
  Stream<List<${cls}Model>> watchAll() => _local.watchAll();$writes
}
''';
  }

  /// A feature's `data/repositories/<name>_repository.dart` when the cache
  /// is all it has: no API behind it, so the local database is the one copy
  /// and every write is final. `watchAll` is what the screen follows, as in
  /// [repository], so the holder and view are the cached feature's.
  static String localRepository(String name, String cls) =>
      '''
import '../datasources/${name}_local_datasource.dart';
import '../models/${name}_model.dart';

/// ${cls}Model records kept on the device. There is no API behind this
/// feature: the local database is the one copy.
class ${cls}Repository {
  const ${cls}Repository(this._local);

  final ${cls}LocalDataSource _local;

  /// Everything stored.
  Future<List<${cls}Model>> fetchAll() => _local.readAll();

  /// [fetchAll] now, and again after every write.
  Stream<List<${cls}Model>> watchAll() => _local.watchAll();

  /// Stored under a new id, which the returned record carries.
  Future<${cls}Model> create(${cls}Model item) async {
    final created = item.copyWith(id: DateTime.now().microsecondsSinceEpoch);
    await _local.save(created);
    return created;
  }

  Future<void> update(${cls}Model item) => _local.save(item);

  Future<void> delete(int id) => _local.remove(id);
}
''';

  /// The write calls a synced REST feature's remote datasource adds: each
  /// describes its request rather than sending it, since the queue sends it.
  /// [endpoint] is the collection's path expression.
  static String remoteWrites(String cls, String endpoint) {
    // `ApiConstants.x` goes into the string as an interpolation; a literal
    // path ('/orders') goes in as it is.
    final base = endpoint.startsWith("'")
        ? endpoint.substring(1, endpoint.length - 1)
        : '\${$endpoint}';
    return '''


  // Writes are described, not sent: the repository queues them and
  // SyncService sends them (core/sync/). TODO: match your API's methods and
  // bodies.
  SyncRequest create(${cls}Model item) {
    return SyncRequest.post($endpoint, item.toJson()..remove('id'));
  }

  SyncRequest update(${cls}Model item) {
    return SyncRequest.put('$base/\${item.id}', item.toJson());
  }

  SyncRequest delete(int id) {
    return SyncRequest.delete('$base/\$id');
  }''';
  }
}
