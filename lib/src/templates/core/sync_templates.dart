import '../../utils/state_management.dart';

/// Offline sync: writes are applied to the cache at once and queued in the
/// database, then sent to the API in order whenever the app can — on start,
/// on reconnect, on resume and from a background task.
///
/// Everything here is under `lib/core/sync/` and is the same in both stacks
/// except how the pending count is read: a provider on Riverpod, a cubit on
/// bloc. A queued write is replayed as the method, path and body the feature's
/// remote datasource described, so the background isolate can send it with a
/// Dio client and nothing else.
abstract final class SyncTemplates {
  /// The BGTaskScheduler identifier and workmanager unique name of the
  /// background task. `Info.plist` lists it under
  /// `BGTaskSchedulerPermittedIdentifiers`.
  static const String taskId = 'outbox-sync';

  /// `lib/core/sync/sync_queue.dart` — the `PendingWrites` table, oldest first.
  static String syncQueue() => r'''
import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// A write as the API takes it. A feature's remote datasource describes its
/// writes with these; the queue stores them and SyncService sends them.
class SyncRequest {
  const SyncRequest(this.method, this.path, [this.body]);

  const SyncRequest.post(String path, Object? body) : this('POST', path, body);
  const SyncRequest.put(String path, Object? body) : this('PUT', path, body);
  const SyncRequest.delete(String path) : this('DELETE', path);

  final String method;
  final String path;

  /// Anything `jsonEncode` takes.
  final Object? body;
}

/// Writes waiting for the server, oldest first. SyncService is the only
/// reader; repositories add through `SyncService.enqueue`.
class SyncQueue {
  SyncQueue(this._db);

  final AppDatabase _db;

  Future<void> add(String collection, SyncRequest request) {
    return _db.into(_db.pendingWrites).insert(
          PendingWritesCompanion.insert(
            collection: collection,
            method: request.method,
            path: request.path,
            body: Value(
              request.body == null ? null : jsonEncode(request.body),
            ),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Every queued write, in the order it was made.
  Future<List<PendingWrite>> all() {
    return (_db.select(_db.pendingWrites)
          ..orderBy([(write) => OrderingTerm.asc(write.id)]))
        .get();
  }

  /// How many writes are waiting: now, and after every change.
  Stream<int> watchCount() {
    final count = _db.pendingWrites.id.count();
    return (_db.selectOnly(_db.pendingWrites)..addColumns([count]))
        .map((row) => row.read(count) ?? 0)
        .watchSingle();
  }

  Future<void> remove(int id) {
    return (_db.delete(_db.pendingWrites)..where((w) => w.id.equals(id))).go();
  }

  /// Records a failed attempt, for the backoff.
  Future<void> markFailed(int id, int attempts) {
    return (_db.update(_db.pendingWrites)..where((w) => w.id.equals(id)))
        .write(
      PendingWritesCompanion(
        attempts: Value(attempts),
        lastTriedAt: Value(DateTime.now()),
      ),
    );
  }
}
''';

  /// `lib/core/sync/sync_service.dart` — sends the queue. Takes the stack
  /// for how the pending count is read.
  static String syncService({
    StateManagement stateManagement = StateManagement.riverpod,
  }) {
    final isBloc = stateManagement.isBloc;
    final blocImport = isBloc ? "import 'package:bloc/bloc.dart';\n" : '';
    final riverpodImport = isBloc
        ? ''
        : "\nimport 'package:flutter_riverpod/flutter_riverpod.dart';";
    final locatorImport = isBloc
        ? ''
        : "\nimport '../../config/di/injector.dart';";
    final holder = isBloc ? _pendingCubit : _pendingProvider;
    return '''
import 'dart:async';
import 'dart:convert';

${blocImport}import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';$riverpodImport
$locatorImport
import '../database/app_database.dart';
import '../errors/app_exception.dart';
import '../network/safe_api_call.dart';
import '../services/connectivity_service.dart';
import '../utils/app_logger.dart';
import 'sync_queue.dart';

final _log = appLogger.scoped('Sync');
$holder
$_syncServiceBody''';
  }

  static const String _pendingProvider = '''

/// How many writes are waiting to be sent. Show it where the user should know
/// their changes have not reached the server yet (an `AppBanner`, a badge).
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return getIt<SyncService>().pendingCount;
});
''';

  static const String _pendingCubit = '''

/// How many writes are waiting to be sent, as bloc state. Provide it where the
/// user should know their changes have not reached the server yet:
/// `BlocProvider(create: (_) => PendingSyncCubit(getIt<SyncService>()))`.
// ignore: prefer_file_naming_conventions
class PendingSyncCubit extends Cubit<int> {
  PendingSyncCubit(SyncService service) : super(0) {
    _subscription = service.pendingCount.listen(emit);
  }

  late final StreamSubscription<int> _subscription;

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
''';

  static const String _syncServiceBody = r'''
/// A write the server refused. It has left the queue, and the refetch after
/// the sync puts the screen back to what the server has.
class RejectedWrite {
  const RejectedWrite(this.write, this.error);

  final PendingWrite write;
  final AppException error;
}

/// Sends the queue, oldest first:
///
/// - 2xx: done, the write leaves the queue.
/// - offline, or 401 (the session could not be refreshed): stop; the rest
///   waits for the next try.
/// - any other 4xx: the server refused it — dropped, and reported on
///   [rejected].
/// - anything else (5xx): retried later with a growing wait, and dropped like a
///   refusal after [maxAttempts].
///
/// After a sync, every collection it touched is refetched ([refreshOnSync]):
/// the server's version replaces what was written offline, temporary ids
/// included.
class SyncService {
  SyncService(this._queue, this._dio, this._connectivity);

  final SyncQueue _queue;
  final Dio _dio;
  final ConnectivityService _connectivity;

  static const int maxAttempts = 5;

  final _rejected = StreamController<RejectedWrite>.broadcast();
  final _refreshers = <String, Future<void> Function()>{};
  StreamSubscription<bool>? _reconnect;
  AppLifecycleListener? _lifecycle;
  Timer? _retry;
  Future<void>? _draining;

  /// How many writes are waiting: now, and after every change.
  Stream<int> get pendingCount => _queue.watchCount();

  /// Writes the server refused. Show them (a toast) — the change the user
  /// made has been undone.
  Stream<RejectedWrite> get rejected => _rejected.stream;

  /// Drains now, and again on every reconnect and every return to the
  /// foreground. Called once, from `main.dart`.
  void start() {
    _reconnect ??= _connectivity.onReconnect(drain);
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(drain()));
    unawaited(drain());
  }

  /// Queues [request] for [collection] and tries to send it straight away.
  /// Apply the change to the cache first, so the screen shows it now.
  Future<void> enqueue(String collection, SyncRequest request) async {
    await _queue.add(collection, request);
    unawaited(drain());
  }

  /// [refresh] runs after a sync touched [collection]: the repository's
  /// `fetchAll`, so the cache matches the server again.
  void refreshOnSync(String collection, Future<void> Function() refresh) {
    _refreshers[collection] = refresh;
  }

  /// Sends what is queued. Calls that overlap share one run.
  Future<void> drain() {
    return _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    final touched = <String>{};
    try {
      // Read again after each pass: a write queued while this run was
      // sending joined it rather than starting its own.
      while (true) {
        final writes = await _queue.all();
        if (writes.isEmpty) return;
        for (final write in writes) {
          final wait = _waitBefore(write);
          if (wait > Duration.zero) {
            // Backing off. The queue keeps its order, so everything behind it
            // waits too.
            _retryIn(wait);
            return;
          }
          try {
            await _send(write);
            await _queue.remove(write.id);
            touched.add(write.collection);
          } on NetworkException {
            return;
          } on AppException catch (error) {
            final status = error.statusCode;
            if (status == 401) return;
            final refused = status != null && status >= 400 && status < 500;
            final attempts = write.attempts + 1;
            if (refused || attempts >= maxAttempts) {
              await _queue.remove(write.id);
              touched.add(write.collection);
              _log.w('${write.method} ${write.path} dropped', error: error);
              _rejected.add(RejectedWrite(write, error));
              continue;
            }
            await _queue.markFailed(write.id, attempts);
            _retryIn(_backoff(attempts));
            return;
          }
        }
      }
    } finally {
      await _refresh(touched);
    }
  }

  Future<void> _send(PendingWrite write) {
    final body = write.body;
    return safeApiCall<void>(
      apiCall: () => _dio.request<Object?>(
        write.path,
        data: body == null ? null : jsonDecode(body),
        options: Options(method: write.method),
      ),
    );
  }

  Future<void> _refresh(Set<String> collections) async {
    for (final collection in collections) {
      final refresh = _refreshers[collection];
      if (refresh == null) continue;
      try {
        await refresh();
      } catch (error, stackTrace) {
        _log.w('Refetching $collection failed', error: error, stackTrace: stackTrace);
      }
    }
  }

  /// 10s, 20s, 40s, 80s after the last failed try.
  static Duration _backoff(int attempts) =>
      Duration(seconds: 5 * (1 << attempts));

  static Duration _waitBefore(PendingWrite write) {
    final last = write.lastTriedAt;
    if (last == null) return Duration.zero;
    return last.add(_backoff(write.attempts)).difference(DateTime.now());
  }

  void _retryIn(Duration wait) {
    _retry?.cancel();
    _retry = Timer(wait, () => unawaited(drain()));
  }

  Future<void> dispose() async {
    await _reconnect?.cancel();
    _lifecycle?.dispose();
    _retry?.cancel();
    await _rejected.close();
  }
}
''';

  /// `lib/core/sync/background_sync.dart` — the workmanager task.
  ///
  /// [withRestAuth] refreshes an expired access token the way the Dio
  /// client's interceptor does in the app, through the auth datasource.
  static String backgroundSync({bool withRestAuth = false}) {
    final authImports = withRestAuth
        ? "import '../../features/auth/data/datasources/auth_remote_datasource.dart';\n"
        : '';
    final client = withRestAuth
        ? r'''
  late final Dio dio;
  dio = buildDioClient(
    tokens,
    // What AuthRepository.refresh does in the app. Offline, the interceptor
    // keeps the session and the write waits for the app.
    refreshSession: () async {
      final refreshToken = await tokens.refreshToken;
      if (refreshToken == null) throw AppException.sessionExpired();
      final session = await AuthRemoteDataSource(
        dio,
      ).refresh(refreshToken: refreshToken);
      await tokens.saveSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
    },
  );'''
        : '  final dio = buildDioClient(tokens);';
    final sessionCheck = withRestAuth
        ? r'''

      // Signed out: nothing to send on anyone's behalf.
      if (await tokens.refreshToken == null) return true;
'''
        : '';
    final exceptionImport = withRestAuth
        ? "import '../errors/app_exception.dart';\n"
        : '';
    return '''
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

${authImports}import '../database/app_database.dart';
${exceptionImport}import '../network/dio_client.dart';
import '../security/secure_storage.dart';
import '../services/connectivity_service.dart';
import '../utils/app_logger.dart';
import 'sync_queue.dart';
import 'sync_service.dart';

final _log = appLogger.scoped('BackgroundSync');

/// The task's id. iOS only runs it because `Info.plist` lists it under
/// `BGTaskSchedulerPermittedIdentifiers` — see docs/SYNC_SETUP.md.
const backgroundSyncTask = '$taskId';

/// Schedules the queue to be sent every ~15 minutes while the app is not
/// running, when there is a network. Android runs it close to that; iOS
/// decides for itself when, or whether. Called from `main.dart`.
Future<void> registerBackgroundSync() async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
  try {
    await Workmanager().initialize(backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      backgroundSyncTask,
      backgroundSyncTask,
      frequency: const Duration(minutes: 15),
      // iOS's only scheduling hint (earliestBeginDate).
      initialDelay: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (error, stackTrace) {
    // The app syncs in the foreground either way.
    _log.w('Not scheduled', error: error, stackTrace: stackTrace);
  }
}

/// Runs in a background isolate, with none of the app's state: it builds the
/// few things a sync needs rather than the whole locator.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    const tokens = TokenStorage(FlutterSecureStorage());
    final db = AppDatabase();
    try {$sessionCheck
      final service = SyncService(
        SyncQueue(db),
        _client(tokens),
        ConnectivityService(),
      );
      await service.drain();
      await service.dispose();
      return true;
    } catch (error, stackTrace) {
      _log.e('Background sync failed', error: error, stackTrace: stackTrace);
      return false;
    } finally {
      await db.close();
    }
  });
}

Dio _client(TokenStorage tokens) {
$client
  return dio;
}
''';
  }

  /// `docs/SYNC_SETUP.md`. [androidApplicationId] fills in the adb commands
  /// when the project has one.
  static String setupDoc({String? androidApplicationId}) {
    final package = androidApplicationId ?? '<your.package.name>';
    return '''
# Offline sync

Writes reach the screen at once and the server when they can. This page is
the rules, the one thing to check on iOS, and how to see it work;
`docs/OFFLINE_FIRST.md` explains the flow behind them, step by step.

## How it works

1. A repository write (`create`, `update`, `delete`) changes the local cache
   first, so every screen following it redraws immediately, then queues the
   request its remote datasource described (`SyncRequest`) in the
   `PendingWrites` table (`lib/core/database/app_database.dart`).
2. `SyncService` (`lib/core/sync/sync_service.dart`) sends the queue, oldest
   first: straight after each write, at start-up, when the connection comes
   back, when the app returns to the foreground, and from the background task.
3. After a sync, each collection it touched is refetched from the API. **The
   server wins**: its version replaces whatever was written offline, including
   the temporary (negative) ids of records created offline.

What happens to each write:

| The API answers | The write |
|---|---|
| 2xx | leaves the queue |
| no connection | stays; the rest wait behind it |
| 401 after a refresh attempt | stays until the user signs in again |
| another 4xx (400, 404, 409, 422…) | is dropped and reported on `SyncService.rejected` — show it, the change has been undone |
| 5xx, timeout | is retried after 10s, 20s, 40s, 80s, then dropped like a 4xx |

Signing out empties the queue with the cache: those writes cannot be sent
without a session. So does signing in, since a queue left by an expired session
cannot be told apart from another account's — the log says how many were
dropped.

A record created offline can be edited or deleted once it has synced. Until
then it only has a temporary id, which the API does not know.

## Background sync

`lib/core/sync/background_sync.dart` registers a workmanager task
(`$taskId`) from `main.dart`. It runs roughly every 15 minutes, only with a
network, in a separate isolate that opens the database and a Dio client of its
own and calls `SyncService.drain()`.

- **Android** — nothing to set up. WorkManager honours the 15 minutes closely,
  and keeps the task across reboots.
- **iOS** — `moarch init` added this to `ios/Runner/Info.plist`; check it is
  there after editing the file by hand:

  ```xml
  <key>UIBackgroundModes</key>
  <array>
      <string>fetch</string>
  </array>
  <key>BGTaskSchedulerPermittedIdentifiers</key>
  <array>
      <string>$taskId</string>
  </array>
  ```

  workmanager registers the task handler itself; `AppDelegate.swift` needs no
  change. iOS decides when the task runs — from how often the app is used, the
  battery and the network — and never runs it after the user swipes the app
  away. Treat it as a bonus: the foreground triggers above are what the
  feature relies on.

## Seeing it work

- **Queue and retry** — turn on airplane mode, make a change, turn it off. The
  pending count (`pendingSyncCountProvider` / `PendingSyncCubit`) goes up, then
  back to 0 once the reconnect sends it.
- **Android background run** — with a write queued and the app in the
  background:

  ```bash
  adb shell cmd jobscheduler run -f $package 999
  adb logcat | grep -i workmanager
  ```

  (The job id varies; `adb shell dumpsys jobscheduler | grep $package`
  lists it.)
- **iOS background run** — run from Xcode, send the app to the background,
  pause the debugger and enter:

  ```text
  e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"$taskId"]
  ```

  then resume. A real device is needed; the simulator does not run background
  tasks.

## Not covered

- Guaranteed timing on iOS, or a sync after the app was force-quit.
- Merging concurrent edits: the server's answer is final. For version checks
  or field-level merges, send an `updatedAt` / version with each write and
  handle the 409 in `SyncService`.
- Uploads (files, images): queue the metadata, and upload the bytes from the
  foreground.
''';
  }
}
