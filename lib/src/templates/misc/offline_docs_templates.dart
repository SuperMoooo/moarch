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
  ///
  /// [withApiProbe] (a project with Dio) adds how `ConnectivityService`
  /// decides it is offline, and [withEncryption] how the database is
  /// encrypted.
  static String doc({
    bool withSync = false,
    bool bloc = false,
    bool withAuthFeature = false,
    bool withApiProbe = false,
    bool withEncryption = false,
  }) => [
    _intro(withSync),
    withSync ? _bigPictureSync : _bigPictureCache,
    withSync ? _filesSync : _filesCache,
    withSync ? _tablesSync : _tablesCache,
    _featureTables,
    _migrations,
    if (withEncryption) _encryption,
    _readPath,
    bloc ? _screenBloc : _screenRiverpod,
    if (withSync) ...[_writePath, _drain, _serverWins, _background],
    _signOut(withSync: withSync, withAuthFeature: withAuthFeature),
    withSync ? _timelineSync : _timelineCache,
    _questions(withSync, withApiProbe: withApiProbe),
    _whereToChange(withSync),
  ].join('\n');

  static const _encryption = r'''
## Encrypted at rest

The database file is encrypted, so a copy of it (a rooted phone, a backup
pulled off a laptop) is unreadable without the key:

- `pubspec.yaml` selects the SQLite3MultipleCiphers build instead of plain
  SQLite (`hooks: user_defines: sqlite3: source: sqlite3mc`). Remove that and
  `PRAGMA key` silently does nothing; a debug build's assert says so, and
  `moarch doctor` flags it.
- `lib/core/database/database_key.dart` makes a random 256-bit key on the
  first open and keeps it in the Keychain / Android Keystore
  (`flutter_secure_storage`). `AppDatabase` reads it before it opens.
- The key does not travel with a backup. A database file restored onto a
  device that never had its key cannot be opened, so it is deleted on the
  first open there: the cache refills from the API, and writes that were
  never sent are lost.

Everything else on this page is unchanged: the encryption is below drift,
and nothing above it knows.
''';

  static const _featureTables = r'''
## A feature's own table: `moarch create table`

JSON in `CacheEntries` is enough to show a list offline. It is not enough to
**query** it: offline, the screen can read the whole list back and nothing
else. Once a feature's model has its fields, give it a real table:

```bash
moarch create table orders
fvm dart run build_runner build -d
```

That reads `OrderModel`'s fields and writes
`lib/features/orders/data/tables/orders_table.dart`:

```dart
@UseRowClass(OrderModel)
class OrderRows extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  TextColumn get status => textEnum<OrderStatus>()();
  TextColumn get tags => text().map(OrderRows.tagsConverter)();
  IntColumn get listOrder => integer()();   // the API's order, not a field

  @override
  Set<Column> get primaryKey => {id};
}
```

- **The rows are the model.** `@UseRowClass` makes drift build an
  `OrderModel` from each row, so there is no second class and no mapping to
  keep in step — the same rule as everywhere else in the project.
- **One column per field**: `int`, `double`, `String`, `bool` and `DateTime`
  get their own column type, an enum is stored by name, and a nested model
  or a `List` / `Map` is stored as JSON in a text column. A field no column
  fits is reported, and nothing is written.
- It also registers the table in `AppDatabase`, bumps `schemaVersion`, moves
  the feature's local datasource onto the table and its registration in
  `lib/config/di/` onto `AppDatabase`. A file you edited is left alone and
  the change is printed for you to make instead.

The repository does not change: the local datasource keeps the same
`readAll` / `watchAll` / `saveAll` / `save` / `remove`. What changes is that
the datasource can now answer **queries**, in SQL, offline:

```dart
// orders_local_datasource.dart
Stream<List<OrderModel>> watchOpen() {
  return (_db.select(_table)
        ..where((row) => row.status.equalsValue(OrderStatus.open))
        ..orderBy([(row) => OrderingTerm.desc(row.dueAt)]))
      .watch();
}
```

**Changing the model later:** run `moarch create table orders` again. It
rewrites the table and the datasource's row mapping (your queries stay), and
bumps `schemaVersion` again.
''';

  static const _migrations = r'''
## Schema versions and migrations

`schemaVersion` in `app_database.dart` goes up whenever a table changes. On
the next launch, `onUpgrade` runs. The tables that are a **copy of the API**
— `CacheEntries` and every feature table — are simply dropped and created
again: the next `fetchAll()` fills them. Nothing is lost that the server does
not have.

A table that holds something the server does **not** have — the sync queue,
or a table you add for drafts or settings — must never be dropped. Skip it in
the `onUpgrade` loop and migrate it step by step. drift writes the tooling
for that, configured in `build.yaml`:

```bash
fvm dart run drift_dev make-migrations
```

Run it after every `schemaVersion` bump. It saves the schema of each version
under `drift_schemas/`, generates a step-by-step migration helper, and writes
a test under `test/drift/` that upgrades a database from every old version.
Commit `drift_schemas/`: it is the history the next migration is checked
against.
''';

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
  repositories/orders_repository.dart        decides network vs cache
```

```text
the screen's state holder
        │
        ▼
OrdersRepository ──► OrdersRemoteDataSource ──► Dio ──► API
        └──────────► OrdersLocalDataSource ──► LocalCache ──► AppDatabase
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
  repositories/orders_repository.dart        decides cache vs network vs queue
```

```text
the screen's state holder
        │
        ▼
OrdersRepository ──► OrdersRemoteDataSource ──► Dio ──► API
        │     └────► OrdersLocalDataSource ──► LocalCache ──► AppDatabase
        └──────────► SyncService ──► SyncQueue ──────────────► AppDatabase
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
- It cannot be queried: offline, a feature reads its whole list back. A
  feature that needs to filter or sort offline gets a table of its own
  (below).
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

With offline sync, there is one more rule: while the collection has writes
the server has not seen (`_sync.hasPending('orders')`), `fetchAll` answers
from the cache and leaves it as it is. Those writes exist only there, and the
server's list would hide them until the sync sent them. The refetch after the
sync brings the server's list instead.

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
// orders_repository.dart
Future<void> update(OrdersModel item) async {
  await _local.save(item);                              // cache → screen redraws NOW
  await _sync.enqueue('orders', _remote.update(item),   // queue → sent later
      recordId: item.id);                               // the record it changes
}
```

This is an **optimistic update**: the change is shown before the server has
accepted it. If the server refuses it, the refetch after the sync puts the
screen back to what the server has (see "the server wins" below).

### Creating while offline: temporary ids

```dart
Future<void> create(OrdersModel item) async {
  final temporaryId = -DateTime.now().microsecondsSinceEpoch;
  await _local.save(item.copyWith(id: temporaryId));
  await _sync.enqueue('orders', _remote.create(item),   // POST, without the id
      recordId: temporaryId);
}
```

The server assigns ids, but the record has to appear now, and the cache needs
a key. It gets a **negative** id, which can never clash with a real one. After
the sync, the refetch replaces the list with the server's, and the record
comes back with its real id.

The record can be edited and deleted before then. Those writes are queued
under the temporary id (`PUT /orders/-1712…`), and when the POST is answered,
`SyncService` reads the new id from the response (`SyncService.createdIdOf`:
the body's `id` by default) and rewrites them, in their path and their body's
`id`, before they are sent. If your API answers a create with a wrapped record
(`{"data": {...}}`) or no body at all, change `createdIdOf`. Without an id,
the edits after it get a 404 and are dropped. If the server refuses the
POST, the writes queued for that record are dropped with it: there is nothing
for them to change.

### The same write, sent twice

A POST whose answer was lost (a timeout after the server saved it) is retried,
and could create the record twice. Every queued write has an
`Idempotency-Key` header, a UUID made when it was queued and kept across its
retries. An API that stores the keys it has seen can answer a repeat with the
first result instead of applying it again. An API that ignores the header
behaves as before.
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
        send it (method, path, body and Idempotency-Key through Dio)
          2xx                → remove from the queue, note its collection
                               (a create: point the writes queued for its
                               temporary id at the server's id, read again)
          no connection      → STOP, keep everything
          401                → STOP, keep everything
          another 4xx        → remove, report on `rejected`, note its collection, go on
                               (a create: its record's queued writes go too)
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
  the app shows a toast for each (`SyncStatusListener`, in the app shell), so
  the user knows why their change is gone.
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
              '`AuthRepository` calls.'
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

10:06  The user edits #3 (total 45), deletes #1 and changes the new
       order's total to 9.
         cache: #3 updated, #1 removed, (new) total 9
                                            → screen: #3 (45), (new)
         queue: [1] POST, [2] PUT /orders/3, [3] DELETE /orders/1,
                [4] PUT /orders/-1712… {total: 9}
         every drain stops at [1]: offline.

10:07  Signal is back → onReconnect → drain():
         [1] POST   → 201 {id: 12} → removed; [4] becomes PUT /orders/12
         [2] PUT    → 200 → removed
         [3] DELETE → 404 (already deleted elsewhere) → dropped, `rejected` fires
         [4] PUT /orders/12 → 200 → removed
       refetch 'orders' → GET → [#3 (45), #12 (9)]
         → screen: #3 (45), #12 (9)        the temporary id became #12

10:30  The app is closed with a write queued (the server was down: 503).
10:45  Android runs the background task → drain → 201 → the queue is empty.
11:00  The app opens → fetchAll → the cache catches up.

18:00  Logout → clearAll() → the cache and the queue are empty.
```
''';

  static String _questions(bool withSync, {bool withApiProbe = false}) => [
    '## Common questions\n',
    if (withApiProbe)
      r'''**Why does the app say it is offline when the wifi is on?** Being online
means the API answers, not that a network is connected: once an interface is
up, `ConnectivityService` sends a `HEAD` to `BASE_URL` (3-second timeout), and
any response — even a 404 — counts. Wifi behind a captive portal, a router
with no uplink, or the API itself being down all read as offline.
''',
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
      r'''**Can I show "3 changes not synced yet"?** Yes: put `SyncStatusBanner`
(`lib/shared/widgets/sync_status.dart`) where the user should see it. It
takes no space while nothing is waiting, and its "Sync now" drains the queue.
It reads the pending count (`pendingSyncCountProvider` on Riverpod,
`PendingSyncCubit` on bloc), which follows the queue table live.
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
shows `cache_entries`${withSync ? ', `pending_writes`' : ''} and each feature table live.
''',
  ].join('\n');

  static String _whereToChange(bool withSync) => [
    '''## Where to change what

| To… | Change |
|---|---|''',
    if (withSync) ...[
      '| use other HTTP methods or paths for writes | the `SyncRequest`s in `<feature>_remote_datasource.dart` |',
      '| show refused writes to the user | already done: `SyncStatusListener` in `main.dart` toasts each one — reword it in `sync_status.dart` |',
      '| change the retries | `maxAttempts` and `_backoff` in `sync_service.dart` |',
      '| change how often the background task runs | `registerBackgroundSync()` in `background_sync.dart` (15 minutes is Android\'s minimum) |',
    ],
    '| show the cached list first and refresh behind it | the screen\'s first load: `readAll()`, then `fetchAll()` |',
    '| filter, sort or search a list offline | `moarch create table <feature>`, then a query in its local datasource |',
    '| change a feature table | its model, then `moarch create table <feature>` again |',
    '| add a table holding data the API does not have | `app_database.dart`: skip it in `onUpgrade`, then `fvm dart run drift_dev make-migrations` |',
    '',
  ].join('\n');
}
