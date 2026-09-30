/// `docs/OFFLINE_FIRST.md`: how the offline-first cache, and offline sync
/// when the project has it, work at runtime. Written for a developer new to
/// the pattern, with `orders` as the running example.
///
/// Reads and writes are separate sections, so a cache-only project gets the
/// first half and a synced one all of it. `docs/SYNC_SETUP.md` stays the
/// setup and testing page; this one is the explanation.
abstract final class OfflineDocsTemplates {
  /// The page. [withSync] adds the write path, the queue and the background
  /// task; [bloc] picks how the screen section reads; [withAuthFeature] says
  /// who clears the cache on sign-out.
  static String doc({
    bool withSync = false,
    bool bloc = false,
    bool withAuthFeature = false,
  }) => [
    _intro(withSync),
    withSync ? _bigPictureSync : _bigPictureCache,
    withSync ? _filesSync : _filesCache,
    withSync ? _tablesSync : _tablesCache,
    _readPath,
    bloc ? _screenBloc : _screenRiverpod,
    if (withSync) ...[_writePath, _drain, _serverWins, _background],
    _signOut(withSync: withSync, withAuthFeature: withAuthFeature),
    withSync ? _timelineSync : _timelineCache,
    _questions(withSync),
    _whereToChange(withSync),
  ].join('\n');

  static String _intro(bool withSync) =>
      '''
# Offline-first${withSync ? ' and sync' : ''}, explained

How this project keeps working without a connection: what each file does,
what happens at runtime, and why it is built this way. The example feature
throughout is `orders`; every feature `moarch create feature` writes with a
local datasource works the same way.
${withSync ? '''

- **Reads** work offline: the API's data is kept in a local database.
- **Writes** work offline too: they are applied locally at once and sent to
  the API when it can be reached. `docs/SYNC_SETUP.md` covers the iOS setup
  and how to test it.
''' : '''

- **Reads** work offline: the API's data is kept in a local database.
- **Writes** still need a connection: they go straight to the API.
'''}''';

  static const _bigPictureCache = r'''
## The one idea behind it

> **The screen follows the local database. The network only ever updates the
> local database.**

```text
 Screen ◄── watchAll() ── LOCAL DATABASE (drift / SQLite) ◄── fetchAll() ◄── API
```

The API's data is copied into the database, and the screen reads from the
database, so it has something to show when the API cannot be reached.
''';

  static const _bigPictureSync = r'''
## The one idea behind it

> **The screen never talks to the network. It talks to the local database.
> The network only ever updates the local database.**

```text
 Screen ◄── watchAll() ── LOCAL DATABASE (drift / SQLite) ◄── fetchAll() ◄── API
                                     ▲                          (reads)
                                     │
 Screen ── create/update/delete ─────┤  (1) change the database now
                                     │
                                     └─► (2) PendingWrites queue ──► SyncService ──► API
                                                                     (writes, later)
```

- **Reads**: the API's data is copied into the database, and the screen
  follows the database.
- **Writes**: the change goes into the database immediately, so the screen
  updates, and a note saying "send this to the API" goes into a queue. The
  queue is sent whenever possible.

Everything below is details of those two arrows.
''';

  static const _filesCache = r'''
## The files, and who calls whom

```text
lib/core/database/
  app_database.dart     drift database: one table, CacheEntries
  local_cache.dart      LocalCache: read / watch / save records of any feature
lib/features/orders/data/
  datasources/orders_local_datasource.dart   LocalCache, under the key 'orders'
  datasources/orders_remote_datasource.dart  the API, through Dio
  repositories/orders_repository_impl.dart   decides network vs cache
```

```text
the screen's state holder
        │
        ▼
OrdersRepositoryImpl ──► OrdersRemoteDataSource ──► Dio ──► API
        └──────────────► OrdersLocalDataSource ──► LocalCache ──► AppDatabase
```

All of it is wired by get_it in `lib/config/di/`. Features never touch drift:
they go through their local datasource.
''';

  static const _filesSync = r'''
## The files, and who calls whom

```text
lib/core/database/
  app_database.dart     drift database: two tables, CacheEntries and PendingWrites
  local_cache.dart      LocalCache: read / watch / save records of any feature
lib/core/sync/
  sync_queue.dart       SyncQueue: add / list / remove queued writes; SyncRequest
  sync_service.dart     SyncService: sends the queue, retries, refetches
  background_sync.dart  workmanager task: runs SyncService while the app is closed
lib/features/orders/data/
  datasources/orders_local_datasource.dart   LocalCache, under the key 'orders'
  datasources/orders_remote_datasource.dart  GET through Dio; writes as SyncRequest
  repositories/orders_repository_impl.dart   decides cache vs network vs queue
```

```text
the screen's state holder
        │
        ▼
OrdersRepositoryImpl ──► OrdersRemoteDataSource ──► Dio ──► API
        │         └────► OrdersLocalDataSource ──► LocalCache ──► AppDatabase
        └──────────────► SyncService ──► SyncQueue ──────────────► AppDatabase
                              └──► Dio (to send) + ConnectivityService (to know when)
```

All of it is wired by get_it in `lib/config/di/`. The rule of thumb:
**features never touch drift, the queue, or Dio for a write**. They go through
their datasources and `SyncService`.
''';

  static const _cacheTable = r'''
### `CacheEntries`: a copy of what the API has

| collection | id | position | payload (JSON) | cachedAt |
|---|---|---|---|---|
| `orders` | `3` | 0 | `{"id":3,"total":40}` | 10:02 |
| `orders` | `1` | 1 | `{"id":1,"total":12}` | 10:02 |
| `products` | `9` | 0 | `{"id":9,"name":"Pen"}` | 09:40 |

- One table for **every** feature: `collection` says which feature a row
  belongs to.
- The record is stored as the **freezed model's own JSON** (`toJson`) and
  read back with `fromJson`. Adding a feature or a field needs **no new table
  and no migration**.
- `position` keeps the list in the order the API returned it.
- It is disposable: it can always be fetched again. That's why a schema
  upgrade simply wipes and rebuilds this table.
''';

  static const _tablesCache = '''
## The database

$_cacheTable''';

  static const _tablesSync =
      '''
## The database: two tables

$_cacheTable
$_queueTable''';

  static const _queueTable = r'''
### `PendingWrites`: the outbox

| id | collection | method | path | body | attempts | lastTriedAt |
|---|---|---|---|---|---|---|
| 1 | `orders` | `POST` | `/orders` | `{"total":8}` | 0 | – |
| 2 | `orders` | `PUT` | `/orders/3` | `{"id":3,"total":45}` | 2 | 10:07 |
| 3 | `orders` | `DELETE` | `/orders/1` | – | 0 | – |

- Each row is **a full HTTP request, stored as data**: method, path, body.
- `id` is auto-increment, so it is also the **send order**: oldest first.
- It is **not** disposable: these are changes the server hasn't seen. A
  schema upgrade never drops it; changing this table needs a real migration.
''';

  static const _readPath = r'''
## Reading: `fetchAll` and `watchAll`

### `fetchAll()`: network first, the cache as the fallback

```dart
Future<List<OrdersModel>> fetchAll() async {
  try {
    final items = await _remote.fetchAll();   // 1. GET /orders
    await _local.saveAll(items);              // 2. replace 'orders' in the cache
    return items;
  } on NetworkException {                     // 3. no connection?
    final cached = await _local.readAll();    //    answer from the cache
    if (cached.isEmpty) rethrow;              //    nothing cached: show "offline"
    return cached;
  }
}
```

Only `NetworkException` (the request never reached the server) falls back to
the cache. A 500 or a 404 is a real answer and still reaches the screen: the
cache is for "can't reach the server", not for "the server said no".

### `watchAll()`: the screen follows the database

```dart
Stream<List<OrdersModel>> watchAll() => _local.watchAll();
```

drift can **watch** a query: it runs it again and emits a new list whenever a
row it reads changes. Whatever saves orders to the cache (this screen,
another one, a sync) redraws every screen watching `orders`. Nobody has to
call `invalidate` or refresh by hand.
''';

  static const _screenRiverpod = r'''
### How the screen uses them

```dart
// orders_notifier.dart
FutureOr<OrdersState> build() async {
  // 1. follow the cache: every change redraws
  final subscription = _repo.watchAll().listen((items) {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(items: items));
  });
  ref.onDispose(subscription.cancel);
  // 2. first load: the API, or the cache when offline
  return OrdersState(items: await _repo.fetchAll());
}
```

`refresh()` on the notifier fetches again while keeping the list on screen.
Prefer it to `ref.invalidate`, which swaps the list for a loading screen.
''';

  static const _screenBloc = r'''
### How the screen uses them

The bloc's `Started` handler calls `fetchAll()`, which already answers from
the cache when offline. It does **not** follow `watchAll()`, so a bloc screen
does not redraw by itself when the cache changes. When it should, follow the
stream in a handler:

```dart
Future<void> _onWatched(OrdersWatched event, Emitter<OrdersState> emit) =>
    emit.forEach(
      _repo.watchAll(),
      onData: (items) => state.copyWith(items: items),
    );
```
''';

  static const _writePath = r'''
## Writing: apply now, send later

### Step 1: the datasource *describes* the request, it does not send it

```dart
// orders_remote_datasource.dart
SyncRequest update(OrdersModel item) =>
    SyncRequest.put('${ApiConstants.orders}/${item.id}', item.toJson());
```

`SyncRequest` is plain data: method, path, body. Why not just call Dio? The
write may be sent minutes or hours later, possibly from a **different isolate**
(the background task) where no repository or datasource exists. A description
can be stored in a table and replayed by anything holding a Dio client, while
the path still lives in the datasource next to the GET.

### Step 2: the repository applies it locally, then queues it

```dart
// orders_repository_impl.dart
Future<void> update(OrdersModel item) async {
  await _local.save(item);                              // cache → screen redraws NOW
  await _sync.enqueue('orders', _remote.update(item));  // queue → sent later
}
```

This is an **optimistic update**: the change is shown before the server has
accepted it. If the server refuses it, the refetch after the sync puts the
screen back to what the server has (see "the server wins" below).

### Creating while offline: temporary ids

```dart
Future<void> create(OrdersModel item) async {
  await _local.save(item.copyWith(id: -DateTime.now().microsecondsSinceEpoch));
  await _sync.enqueue('orders', _remote.create(item));  // POST, without the id
}
```

The server assigns ids, but the record has to appear now, and the cache needs
a key. It gets a **negative** id, which can never clash with a real one. After
the sync, the refetch replaces the list with the server's, and the record
comes back with its real id.

A record with a negative id **cannot be edited or deleted** until it has
synced: `PUT /orders/-1712…` means nothing to the server, which answers 404,
and the write is dropped. Hide or disable those actions while `id < 0`.
''';

  static const _drain = r'''
## Sending: `SyncService.drain()`

```text
drain()
 └─ loop:
     writes = queue, oldest first
     if empty → done
     for each write:
        still backing off?   → schedule a timer, STOP
        send it (method, path, body through Dio)
          2xx                → remove from the queue, note its collection
          no connection      → STOP, keep everything
          401                → STOP, keep everything
          another 4xx        → remove, report on `rejected`, note its collection, go on
          5xx / timeout      → count the attempt, schedule a retry, STOP
                               (after 5 attempts: treated like a 4xx)
     read the queue again: writes added meanwhile are sent by this same run
 finally:
     refetch every noted collection (the repository's fetchAll)
```

| Rule | Why |
|---|---|
| **Strict order; a problem stops everything behind it** | `POST /orders` then `PUT /orders/5`: sending the second first could hit a record that does not exist yet. |
| **Offline → stop and keep** | Nothing is wrong with the write. It goes when the connection is back. |
| **401 → stop and keep** | The Dio client already tried to refresh the token. The user has to sign in again; the write is still valid. |
| **Another 4xx → drop and report** | The server looked at it and said no (validation, conflict, gone). Retrying it forever would **block the whole queue**. |
| **5xx → retry after 10s, 20s, 40s, 80s, then drop** | The server has a problem. Wait and try again, but never stay stuck forever. |
| **One run at a time** | `drain()` calls that overlap share one run, so a write is never sent twice. |

### When `drain()` runs

| Trigger | Where |
|---|---|
| App start | `main.dart`: `getIt<SyncService>().start()` |
| Right after each write | `SyncService.enqueue` |
| The connection comes back | `ConnectivityService.onReconnect`, set up by `start()` |
| The app returns to the foreground | `AppLifecycleListener`, set up by `start()` |
| A backoff timer expires | `SyncService` itself |
| The app is closed, every ~15 min | the workmanager task (below) |
''';

  static const _serverWins = r'''
## After a sync: the server wins

Every collection the drain touched, whether sent **or** dropped, is fetched
again. Each repository registers how, in its constructor:

```dart
_sync.refreshOnSync('orders', fetchAll);
```

After the drain, `fetchAll()` runs: `GET /orders` → `saveAll` replaces the
cached list → `watchAll` emits → the screen shows **exactly what the server
has**. That one refetch settles every loose end:

- A record created offline: its temporary id becomes the real one.
- A refused write: the optimistic change disappears, because the server never
  applied it. That's why refusals are reported on `SyncService.rejected`:
  show a toast, so the user knows why their change is gone.
- A change someone else made meanwhile: it appears.

Conflicts are **not merged** on the device. If two devices edit the same
order, the last write the server accepts wins. An API that wants more (a
version number, a 409 on stale data) is handled in `SyncService`.
''';

  static const _background = r'''
## Background sync (workmanager)

While the app is closed, the OS can wake a small piece of Dart code:

```text
OS (Android WorkManager / iOS BGTaskScheduler)
  └─ starts a NEW isolate: no app state, no get_it, no widgets
      └─ backgroundSyncDispatcher()          lib/core/sync/background_sync.dart
           1. signed out? → do nothing
           2. open AppDatabase (the same SQLite file, shared across isolates)
           3. build Dio + SyncQueue + SyncService by hand
           4. drain()
           5. close the database
```

**Why build them by hand rather than call `setupInjector()`?** The background
isolate starts empty, and `setupInjector()` also registers services that only
make sense with a UI. It only needs a database, the tokens and Dio.

**Why no refetch there?** No repository exists in the background, so nothing
registered one. The queue is sent, and the cache catches up the next time a
screen opens, since its `fetchAll` runs anyway.

| | Android | iOS |
|---|---|---|
| Setup | nothing | two `Info.plist` keys, added by `moarch init` (`docs/SYNC_SETUP.md`) |
| Timing | close to every 15 minutes, with a network | **iOS decides**, from how often the app is used, the battery and the network: hours, or never |
| After the user swipes the app away | still runs | never runs |

Background sync is a **bonus**. What the feature relies on are the foreground
triggers: start-up, after each write, reconnect, resume.
''';

  static String _signOut({
    required bool withSync,
    required bool withAuthFeature,
  }) {
    final what = withSync ? 'cache + queue' : 'cache';
    final who = withAuthFeature
        ? 'All of it goes through `LocalCache.clearAll()`, which the generated '
              '`AuthRepositoryImpl` calls.'
        : 'Call `getIt<LocalCache>().clearAll()` wherever the app signs a user '
              'out or switches accounts.';
    return '''
## Signing in and out

The cache${withSync ? ' and the queue belong' : ' belongs'} to **the account that filled ${withSync ? 'them' : 'it'}**.

| Event | Cleared | Why |
|---|---|---|
| Logout | $what | The next user must not see this user's data.${withSync ? " Queued writes can't be sent without a session anyway." : ''} |
| Account deleted | $what | The same. |${withAuthFeature ? '''

| Sign-in | $what | A session that expired while the app was closed cannot be told apart from another account's${withSync ? ", and sending writes as a different user is worse than losing them. The log says how many were dropped" : ''}. |''' : ''}

$who
''';
  }

  static const _timelineCache = r'''
## A full timeline

```text
10:00  App opens, online.
       fetchAll → GET /orders → [#3, #1] → saved to the cache → screen: #3, #1

10:05  Subway, no signal. The user opens the orders screen again.
       fetchAll → NetworkException → the cache → screen: #3, #1 (no error)

10:06  The user tries to cancel #3.
       The write goes straight to the API → NetworkException → error toast.
       (Writes need a connection in this project.)

10:07  Signal is back. The screen is opened again → GET /orders → cache →
       screen redraws with the latest.

18:00  Logout → clearAll() → the cache is empty.
```
''';

  static const _timelineSync = r'''
## A full timeline

```text
10:00  App opens, online.
       fetchAll → GET /orders → [#3, #1] → cache → screen: #3, #1
       SyncService.start(): the queue is empty, nothing to send.

10:05  Subway, no signal. The user creates an order (total 8).
         cache: + {id: -1712…, total: 8}   → screen: #3, #1, (new)
         queue: [1] POST /orders {total: 8}
         enqueue → drain → NetworkException → stop. The queue keeps it.

10:06  The user edits #3 (total 45) and deletes #1.
         cache: #3 updated, #1 removed     → screen: #3 (45), (new)
         queue: [1] POST, [2] PUT /orders/3, [3] DELETE /orders/1
         every drain stops at [1]: offline.

10:07  Signal is back → onReconnect → drain():
         [1] POST   → 201 → removed
         [2] PUT    → 200 → removed
         [3] DELETE → 404 (already deleted elsewhere) → dropped, `rejected` fires
       refetch 'orders' → GET → [#3 (45), #12 (8)]
         → screen: #3 (45), #12 (8)        the temporary id became #12

10:30  The app is closed with a write queued (the server was down: 503).
10:45  Android runs the background task → drain → 201 → the queue is empty.
11:00  The app opens → fetchAll → the cache catches up.

18:00  Logout → clearAll() → the cache and the queue are empty.
```
''';

  static String _questions(bool withSync) => [
    '## Common questions\n',
    if (withSync) ...[
      r'''**Why store requests (method, path, body) rather than call the datasource
later?** "Later" may be a different isolate with no datasources, or a newer
version of the app. A stored request replays with nothing but Dio.
''',
      r'''**What if the same record is edited twice offline?** Both writes are queued
and sent in order; the last one wins on the server, as it would online. They
are not merged into one request.
''',
      r'''**What if the API is down for a day?** Each write is tried 5 times with a
growing wait, then dropped and reported. Raise `maxAttempts` or change
`_backoff` in `sync_service.dart` if the API has long outages.
''',
      r'''**Can I show "3 changes not synced yet"?** Yes: the pending count
(`pendingSyncCountProvider` on Riverpod, `PendingSyncCubit` on bloc) follows
the queue table live.
''',
    ],
    r'''**Does Firestore use any of this?** No. Firestore keeps its own offline copy
(and its own write queue), so a Firestore feature is never cached twice.
''',
    '''**How do I test it by hand?** Airplane mode on, open a screen you loaded
before: it shows the cached list.${withSync ? ' Make a change: the pending count goes up. Airplane mode off: it drops to 0 and the list refreshes. `docs/SYNC_SETUP.md` has the commands that trigger the background task.' : ''}
''',
    '''**How do I look inside the database?** It is a SQLite file called
`app_cache`. On Android, Android Studio's App Inspection → Database Inspector
shows `cache_entries`${withSync ? ' and `pending_writes`' : ''} live.
''',
  ].join('\n');

  static String _whereToChange(bool withSync) => [
    '''## Where to change what

| To… | Change |
|---|---|''',
    if (withSync) ...[
      '| use other HTTP methods or paths for writes | the `SyncRequest`s in `<feature>_remote_datasource.dart` |',
      '| show refused writes to the user | listen to `getIt<SyncService>().rejected` (a toast) |',
      '| change the retries | `maxAttempts` and `_backoff` in `sync_service.dart` |',
      '| change how often the background task runs | `registerBackgroundSync()` in `background_sync.dart` (15 minutes is Android\'s minimum) |',
    ],
    '| show the cached list first and refresh behind it | the screen\'s first load: `readAll()`, then `fetchAll()` |',
    '| add a real table instead of JSON in the cache | `app_database.dart`, bump `schemaVersion`, write a migration |',
    '',
  ].join('\n');
}
