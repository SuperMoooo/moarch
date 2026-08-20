# moarch

A simple Dart/Flutter CLI for scaffolding Clean Architecture-style apps.

[![pub version](https://img.shields.io/pub/v/moarch.svg)](https://pub.dev/packages/moarch)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Built first as a helper for me and the people I work with — it encodes the
conventions *our* projects share. Anyone is welcome to it: if the conventions
match yours, use it as-is; if they *almost* do, [clone it and make them
yours](#make-it-your-own) — every template is a plain Dart string meant to be
edited.

## Install

```bash
dart pub global activate moarch
```

If `moarch` is not found, make sure your Pub bin folder is on your `PATH`.

## Quick start

```bash
flutter create my_app
cd my_app
moarch init
fvm use          # creates .fvm/flutter_sdk — see below, do this before opening the editor
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs  # generates app_env.g.dart
moarch create feature auth
moarch create model auth login_response
```

`init` writes a `.fvmrc` pin and a `.vscode/settings.json` that points
`dart.flutterSdkPath` at `.fvm/flutter_sdk` — the symlink `fvm use` creates.
`.fvm/` is gitignored, so **every fresh clone has to run `fvm use` once**.
Skip it and nothing errors: the Dart extension quietly falls back to the first
Flutter on your `PATH`, so debug, hot reload and the analyzer all run the SDK
the pin exists to avoid. `moarch doctor` flags it if you forget.

The generated `.fvmrc` says `"flutter": "stable"` so a new project starts on the
current stable. That is an alias, not a pin — `fvm install` on CI or a
teammate's machine resolves it to whatever `stable` is *that day*, which can be
a different SDK than your cache holds. Once the project ships, pin it for real:

```bash
fvm use 3.41.4   # rewrites .fvmrc to that exact version
```

`fvm use` also rewrites `.vscode/settings.json` to a versioned path and strips
its comments. Put `".fvm/flutter_sdk"` back — it follows `.fvmrc`, so later SDK
switches never touch the editor config. `moarch doctor --fix` does exactly that.

## Commands

```bash
moarch init          # interactive scaffold
moarch init --all    # generate the default structure without prompts
moarch init --state bloc   # pick the stack without the checklist (riverpod | bloc)
moarch create feature <featureName>
moarch create model <featureName> <modelName> # generate the model and entity
moarch create model <featureName> <modelName> --from-json sample.json # infer the fields from a JSON payload
moarch create model --empty <featureName> <modelName> # Inject a .empty() factory into an existing entity.
moarch create flavors # dev/staging/prod via flutter_flavorizr — one main.dart, untouched
moarch create empty-factories # generate .empty() in all entities
moarch create entity-copys <featureName> # inject copyWith into the feature's entities (omit name for all features)
moarch create bloc <featureName> <blocName> # add a state+event+bloc trio to an existing feature
moarch create widget <name>        # add a UI-kit widget on demand (e.g. switch, otp, list-tile)
moarch create widget all           # generate the whole UI kit + the preview screen
moarch create widget --list        # list every available widget
moarch create theme --dark         # add the dark palette + AppTheme.dark to a one-theme project
moarch create theme --no-dark      # ...and drop back to the single brand theme

moarch update        # refresh every generated file against the current templates
moarch update <name> # ...or just one (e.g. validation, extensions, theme)
moarch update <group># ...or one group (widgets, core, security, config, docs...)
moarch update --list # list every name and group update accepts
moarch doctor        # check the project for common scaffolding issues
moarch doctor --fix  # ...and apply the ones that don't need a decision
```

## What it generates

- `lib/main.dart`, `core/`, `config/`, `shared/`, and `features/`
- Riverpod **or** flutter_bloc (see below) + optional GoRouter setup
- Envied-based `.env` support
- secure storage, logger, helpers, and a full shared UI kit / design system (see below)
- optional services such as notifications (local or Firebase push), URL launcher, media, debounce
- an optional maintenance gate — a backend flag that empties the app (see below)
- optional localization: flutter_localizations (`lib/l10n/` + `.arb` files) or easy_localization (`assets/translations/` JSON files) — pick one, the checklist keeps them mutually exclusive
- a backend: Dio against a REST API, Firebase (Firestore / Auth), or both (see below)
- `.vscode/` — `settings.json` pointing the Dart extension at the fvm SDK `.fvmrc` pins, and `launch.json` with debug/profile/release entries plus a flavored pair for `dev`, `staging` and `prod` (ready for when the native side declares them)
- `android/app/proguard-rules.pro` — the R8 keep rules for the Flutter engine, Firebase, OkHttp and coroutines. Inert until you enable minification for the release build type, so it costs the debug build nothing; the gradle block that turns it on is in `docs/SECURITY_BEFORE_DEPLOYMENT.md`

## Riverpod or flutter_bloc

The first question `moarch init` asks. It decides the shape of every
state-bearing file, and nothing else about the architecture moves: the same
layers, the same file names, the same `AppException` reaching the same
`AppAsyncView`.

| | Riverpod | flutter_bloc |
| --- | --- | --- |
| state holder | `AsyncNotifier<OrdersState>` | `Bloc<OrdersEvent, OrdersState>` |
| lives in | `presentation/notifiers/orders_notifier.dart` | `presentation/blocs/orders_bloc.dart` (+ `orders_event.dart`) |
| the state | one class inside `AsyncValue`, in `presentation/states/` | a sealed family: `Initial` / `Loading` / `Success` / `Failure`, in `presentation/blocs/` beside the bloc |
| you call | `ref.read(p.notifier).refresh()` | `context.read<OrdersBloc>().add(const OrdersRefreshed())` |
| the screen | `presentation/views/orders_view.dart` | `presentation/pages/orders_page.dart` provides the bloc, `presentation/views/orders_view.dart` draws it |
| the view uses | `AppAsyncView` + `ref.listenAction` | `BlocConsumer` + a `switch` |
| dependencies | `get_it`, in `config/di/injector.dart` | `get_it`, in `config/di/injector.dart` |
| extra packages | `get_it` | `flutter_bloc`, `bloc`, `equatable`, `get_it`, `bloc_lint` |

Every command reads the choice back off `pubspec.yaml`, so there is no flag to
remember: `moarch create feature orders` in a bloc project generates a bloc.

### The state a screen is in

The two stacks answer this differently on purpose, because they already
disagree about it.

**Riverpod** has `AsyncValue`, which is the four states, so the generated
`OrdersState` is only the data plus the one-shot action fields — unchanged
from previous versions:

```dart
class OrdersState implements ActionState<OrdersState> {
  final bool isLoadingAction;
  final String? error;      // cleared by every copyWith, so it toasts once
  final String? success;
}
```

**Bloc** gets a sealed family, the same shape as its events — which is what
makes the view a `switch` the compiler checks:

```dart
sealed class OrdersState extends Equatable { const OrdersState(); }

final class OrdersInitial extends OrdersState {}
final class OrdersLoading extends OrdersState {}
final class OrdersSuccess extends OrdersState { final List<OrderEntity> items; }
final class OrdersFailure extends OrdersState { final String message; }
```

There is no status flag or enum on top of that. **The family is the status** —
a second way to say what the screen is doing is one way too many, and the
whole point of sealing it is that the compiler can check you handled every
case.

`Equatable` is load-bearing rather than decorative: bloc drops an emit whose
state equals the current one, and `BlocConsumer` rebuilds — and fires its
listener — on the same test.
Without value equality every emit is a new object, so every emit repaints —
including the Firestore snapshots that changed nothing.

### A bloc feature

```dart
sealed class OrdersEvent extends Equatable {}
final class OrdersStarted   extends OrdersEvent {}   // dispatched by the route
final class OrdersRefreshed extends OrdersEvent {}   // the retry button
// TODO: one per action the screen can take

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc(this._repo) : super(const OrdersInitial()) {
    on<OrdersStarted>(_onStarted);
    on<OrdersRefreshed>(_onStarted);

    on<OrdersDeleted>((event, emit) async {
      emit(const OrdersLoading());
      try {
        await _repo.delete(event.id);
        emit(const OrdersSuccess());
      } on AppException catch (e) {
        emit(OrdersFailure(e.message));
      }
    });
  }
}
```

No mixin and no base class of moarch's own — that is the whole handler.

The screen is plain `flutter_bloc`, split across two files. `pages/orders_page.dart`
owns the bloc so leaving the route closes it, and with it any Firestore
subscription — it is what a `GoRoute` points at. `views/orders_view.dart` draws
the state with one `switch` and reacts to it with one `listener`, and never
touches the locator, so a widget test can pump it with a bloc of its own:

```dart
// presentation/pages/orders_page.dart
class OrdersPage extends StatelessWidget {
  Widget build(context) => BlocProvider(
    create: (_) => getIt<OrdersBloc>()..add(const OrdersStarted()),
    child: const OrdersView(),
  );
}

// presentation/views/orders_view.dart — inside OrdersView
BlocConsumer<OrdersBloc, OrdersState>(
  // Only on an actual change — the states are Equatable.
  listenWhen: (previous, current) => previous != current,
  listener: (context, state) {
    switch (state) {
      case OrdersFailure(:final message):
        AppToast.error(context, message);
      case OrdersSuccess():
        // TODO: what should happen once — a toast, a pop, a redirect.
        break;
      case OrdersInitial():
      case OrdersLoading():
        break;
    }
  },
  builder: (context, state) => switch (state) {
    OrdersInitial() || OrdersLoading() =>
        Skeletonizer(child: _body(context, OrdersSuccess.placeholder)),
    OrdersFailure(:final message) => ErrorView(message: message, onRetry: ...),
    OrdersSuccess(:final items) when items.isEmpty => const EmptyView(),
    OrdersSuccess() => _body(context, state),
  },
)
```

Add a state and that `switch` stops compiling until it is drawn.

`listener` is the bloc answer to `ref.listen`: it runs **once** per new state,
which is where a toast, a dialog or a `context.push` belongs. `builder` runs on
every rebuild, so the same toast raised there would repeat.

`AppAsyncView` and `ref.listenAction` are **not** generated into a bloc
project, and neither is any shared action base. They exist because Riverpod's
`AsyncValue` is one opaque type that something has to map onto four screens; a
sealed family needs no such wrapper. `moarch create widget async-view` in a
bloc project says so rather than writing a file that cannot compile.

`AuthState` follows the same shape: `AuthInitial` (restoring — what parks the
router on splash), `AuthLoading`, `AuthAuthenticated`, `AuthUnauthenticated`
and `AuthFailure`.

### Dependencies live in one file

`lib/config/di/injector.dart` holds every dependency, **in both stacks**:
clients, services, datasources and repositories are constructed once and
handed out by type. `moarch create feature` **writes into it** at the
`// moarch:registrations` anchor:

```dart
getIt.registerLazySingleton<OrdersRepository>(
  () => OrdersRepositoryImpl(getIt<OrdersRemoteDataSource>()),
);
// bloc only. A factory, not a singleton: the screen's BlocProvider creates it
// and closing the route closes it, subscriptions and all.
getIt.registerFactory<OrdersBloc>(() => OrdersBloc(getIt<OrdersRepository>()));
```

What differs is only the **state holder**. A bloc is registered like anything
else. A Riverpod notifier is not: an `AsyncNotifier` needs the `Ref` Riverpod
hands it, so it stays behind its provider and reaches into the locator from
there —

```dart
final ordersNotifierProvider =
    AsyncNotifierProvider<OrdersNotifier, OrdersState>(OrdersNotifier.new);

class OrdersNotifier extends AsyncNotifier<OrdersState>
    with ActionNotifierMixin<OrdersState> {
  OrdersRepository get _repo => getIt<OrdersRepository>();
}
```

**Riverpod holds the state; get_it holds everything the state is built from.**
So `hasInternetProvider`, `maintenanceStatusProvider`, `languageProvider`,
`routerProvider` and the feature notifiers are still providers — they are
state — while the services beneath them come out of `getIt`.

That anchor comment is load-bearing. Delete it and `create feature` still
generates the feature but says it could not register it; `moarch doctor`
flags it too.

`AuthBloc` is the one bloc registered as a **singleton**: the router's redirect
and every screen have to read the same session.

### bloc_lint

A bloc project gets `bloc_lint` as a dev dependency and the recommended
ruleset in `analysis_options.yaml`. Those rules are read by the bloc analysis
server rather than by `dart analyze`, so they need their own run:

```bash
dart pub global activate bloc_tools   # once
bloc lint .
```

The generated CI workflow runs it alongside `flutter analyze`, and a freshly
scaffolded project passes with no findings.

`prefer_bloc` and `prefer_cubit` are deliberately left out of the generated
ruleset. Features scaffold as event-driven Blocs, but a holder with one value
and no vocabulary of events — the locale, the maintenance flag — is a Cubit on
purpose, and neither rule can tell the two cases apart.

### Dio or Firebase

The backend you pick in the first checklist decides what the data layer is made
of. Nothing else about the architecture moves: the same layers, the same class
names, the same `AppException` reaching the same `AppAsyncView`.

| | Dio | Firebase |
| --- | --- | --- |
| datasource holds | `final Dio _dio;` | `final FirebaseFirestore _firestore;` |
| calls go through | `safeApiCall` | `safeFirebaseCall` / `safeFirebaseStream` |
| entity `id` | `int` | `String` — a document id |
| errors mapped by | `AppException.fromDioError` | `fromFirebaseError` + `fromFirebaseAuthError` |
| auth feature | tokens in secure storage, refresh interceptor | Firebase Auth, email/password + Google |

`moarch create feature <name>` follows the same choice. In a Firestore project
the datasource comes out with `fetchAll` / `fetchOne` / `watchAll` /
`create` / `save` / `delete` over one collection; in a project with **both**
backends installed, the layer checklist asks which one this feature talks to.

**A Firestore feature is live end to end.** `watchAll` is not left on the
datasource for you to wire up: the repository exposes it, the notifier
subscribes to it in `build()` and the view renders `state.items` — so the screen
redraws whenever the collection changes, on this device or another, with no
pull-to-refresh and no `invalidate` anywhere. One subscription serves both the
first frame and every change after it (taking `.first` for the initial load and
then listening would register the query twice — twice the billed reads), and
Riverpod cancels it with the provider. Writes don't touch `items` either:
Firestore applies them to the local cache before the server confirms, and the
subscription re-emits. The REST feature is unchanged — a `Future`, and a `TODO`
where the fetch goes.

Selecting **Firebase Auth** together with the auth feature generates it against
Firebase instead of REST: email/password, Google sign-in, password reset, account
deletion, and a session restored from `authStateChanges()` rather than from a
stored refresh token. With Firestore also selected it keeps a `users/{uid}`
profile document in step with the account. Dio is not pulled in for it, and no
tokens are stored — Firebase persists the session itself.

Google sign-in needs work outside Dart that nothing in the build will remind you
about, so `init` writes **`docs/FIREBASE_SETUP.md`** with all of it: enabling the
providers, the Android SHA-1/SHA-256 fingerprints, and the two iOS `Info.plist`
keys (`GIDClientID` and the `REVERSED_CLIENT_ID` URL scheme). Those two are
written into `Info.plist` for you when `GoogleService-Info.plist` already exists;
otherwise placeholders go in and `moarch doctor --fix` copies the real values
across once `flutterfire configure` has run.

### Input validation

`core/security/validation_service.dart` checks a value against an `InputType`
(email, url, phone, password, username, number, creditCard, cardExpiry, cvv,
filePath, text) and hands back the cleaned form. It is what `AppInput` calls, and
what `AppInputFormat` maps onto.

It deliberately does **not** blocklist SQL keywords and does **not** HTML-escape
what it returns: `O'Brien` is a name, `Create the report` is a note, and escaping
on the way in is how `Tom & Jerry` ends up stored as `Tom &amp; Jerry`. Injection
belongs to parameterised queries on the server; escaping belongs to
`ValidationService.escapeHtml` at the point you build HTML. What it does enforce
is scoped: shape per type, control characters stripped everywhere, markup in free
text, path traversal in a file path, and an http/https allowlist on a URL.

The password rule is one assignment at startup:

```dart
ValidationService.passwordPolicy = PasswordPolicy.lengthOnly;      // 12+ chars
ValidationService.passwordPolicy = const PasswordPolicy(minLength: 8);
```

### Maintenance gate

A kill switch your backend owns. `MaintenanceGate` watches a flag and, while it
is on, replaces the entire app with a screen carrying whatever title and message
the backend sent — so the team taking the API down can empty the app without an
app release, and change the wording without one either.

```dart
MaterialApp.router(
  builder: (context, child) => MaintenanceGate(child: child!),
  routerConfig: router,
)
```

It goes in `MaterialApp.builder`, which wraps the Navigator — so it sits above
every route the router can reach, including anything pushed after the flag
flips. And it *replaces* the app rather than covering it: with no Navigator
mounted there is nothing left to tap, nothing for the back button to pop, and no
route that can push itself on top of the gate.

**It fails open.** While the first read is in flight, and if the flag cannot be
read at all — offline, endpoint down, Firestore rules denied — the app runs
normally. A fault in the check itself must not be able to lock out every user at
once. The trade-off runs the other way: a backend that is completely unreachable
shows your usual error states rather than the maintenance screen.

The source follows the backend you picked. Firestore gets a live `snapshots()`
listener on `config/maintenance`, so flipping the flag empties every open app
within a second. Dio gets the endpoint polled every five minutes and again on
resume. With neither, you get a stub provider to point at whatever you use.
Either way it is one provider, and the gate above it is identical:

```json
{ "active": true, "title": "Back at 14:00", "message": "Upgrading the database." }
```

> Whichever source you use, make it readable **without a token**. A signed-out
> user, or one whose session expired during the outage, still has to be told the
> app is down — and a permission denial fails open.

```bash
moarch create widget maintenance-gate   # or take it in the init checklist
```

### Extensions

`core/utils/extensions.dart` carries the small helpers every screen reaches for:
`context.theme` / `colorScheme` / `isDarkMode` / `isTablet` / `isKeyboardOpen` /
`unfocus()`, string helpers (`initials`, `capitalizeWords`, `truncate`,
`withoutDiacritics`, `searchKey`, `matchesSearch`, `isBlank`, `digitsOnly`),
date and time helpers (`startOfDay`, `endOfMonth`, `isTomorrow`, `yearsSince`,
`format(pattern)`, `timeAgo()`, `TimeOfDay.onDate`), `Duration.formatted`, and
number formatting (`formatCurrency`, `formatDecimal`, `formatCompact`,
`formatPercent`) — alongside the `formattedDateToDatabase` /
`formatedDateTimeToDatabase` pair the API layer uses.

## Design system

`moarch init` sets up the design foundation — tokens (spacing, radius, a wired-up
type scale, colors) in `core/constants/app_constants.dart`, an `AppTheme` built
from them, and a **lean common set** of widgets under `lib/shared/widgets/`: inputs (`AppInput`,
`AppInputFormat`, `AppInputStyle`, `InputTitle`), `AppButton`, `AppLeadingIcon`, the
state screens (`AppAsyncView`, `ErrorView`, `EmptyView`, `AppLoadingData`) and
overlays (`AppToast`, `AppConfirmDialog`, dialog/bottom-sheet helpers).

`AppInput` is driven by an `AppInputFormat`: one enum that picks the keyboard, the
input formatters that shape the value as it is typed, the autofill hints and the
validation rule together.

```dart
AppInput(label: 'Amount', format: AppInputFormat.money)      // 1,234.50
AppInput(label: 'Card', format: AppInputFormat.creditCard)   // 4111 1111 1111 1111
AppInput(label: 'Expiry', format: AppInputFormat.cardExpiry) // 12/25

AppInputFormat.money.unformat(controller.text)               // '1234.50'
```

### A screen describes its content once

Every generated feature used to hand-roll the same mapping: `.when(...)`, a
`Skeletonizer` over a nullable body, an `ErrorView`, and a `ref.listen` with
`// SHOW UI ERROR` left in it. `AppAsyncView` and `ref.listenAction` are that
mapping, so the view is only the part that differs:

```dart
@override
Widget build(BuildContext context) {
  ref.listenAction<OrdersState>(
    context,
    ordersNotifierProvider,
    errorOf: (state) => state.error,
    successOf: (state) => state.success,
  );

  return Scaffold(
    appBar: AppAppBar(title: 'Orders'),
    body: AppAsyncView<OrdersState>(
      value: ref.watch(ordersNotifierProvider),
      onRetry: () => ref.invalidate(ordersNotifierProvider),
      isEmpty: (state) => state.orders.isEmpty,
      skeleton: (context) => _body(context, OrdersState.placeholder),
      builder: _body,
    ),
  );
}
```

`AppAsyncView` draws whichever of the four states the value is in, and **a reload
does not blank the screen**: once there is data, a later loading or error state
leaves it on screen instead of replacing a list mid-read with a spinner. It
builds inline, so the `Scaffold` keeps its app bar throughout. An error that
carries no message of its own shows no detail — a stringified exception tells the
user nothing and leaks how the app is put together.

The skeleton is the screen's own body, shimmered — which means it has to be
handed **fake data, not an empty state**. Skeletonizer traces the widget tree it
is given, so `_body(context, const OrdersState())` is a `ListView.builder` over
nothing and shimmers as a blank screen. Every generated state carries a
`placeholder` for this, holding a few stand-in rows whose text length is the
width of the bones drawn over them (that is what skeletonizer's `BoneMock` is
for). Keep it in step with `_body` and the loading state stays the real layout
arriving rather than a spinner interrupting:

```dart
static final placeholder = OrdersState(
  orders: List.filled(3, OrderEntity(id: BoneMock.name)),
);
```

The value can come from anywhere. A notifier, a `FutureProvider` and a
`StreamProvider` all hand back an `AsyncValue`; for the sources that never became
a provider — a Firestore query, a socket, a one-off fetch — there are two more
constructors that take the source itself:

```dart
AppAsyncView<List<Order>>.stream(
  stream: repository.watchOrders(),
  isEmpty: (orders) => orders.isEmpty,
  builder: (context, orders) => OrderList(orders),
)

AppAsyncView<Order>.future(
  future: repository.fetchOrder(id),
  builder: (context, order) => OrderDetail(order),
)
```

Same four states, same copy, same retry — only where the data comes from
changes. The subscription is the widget's: it starts with the element, is
cancelled with it, and is swapped when a different stream is passed. It holds
the same line on refreshes too, so a stream that errors, or one replaced by
another, keeps what it had already emitted on screen. A `Future` that completes
after the screen moved on is dropped rather than drawn over what came next.

`listenAction` reads the one-shot `error` / `success` fields the generated state
already clears on every `copyWith`, and toasts whichever arrived — one outcome
per action, never both. Pass `onError` / `onSuccess` to navigate or log instead;
that *replaces* the toast, so a screen that pops on success does not also flash a
message on the way out.

Both are part of `moarch init`, and `moarch create feature` writes them into an
older project rather than generating a view that cannot compile.

### Phone numbers mask themselves, per country

`moarch create widget phone-input` adds `AppPhoneInput`: a field that punctuates
what is typed the way the selected country writes numbers, with a searchable
country picker built into its prefix.

```dart
AppPhoneInput(
  initialCountry: 'PT',
  onChanged: (number) => _phone = number.e164,   // '+351912345678'
)
```

The field holds only the *national* number — `912 345 678` in Portugal,
`(555) 010 9999` in the US — so the calling code can never be typed twice or
deleted by accident. Changing country re-masks what is already there instead of
clearing it.

It ships a table of **238 countries** (`AppCountry`), each carrying every shape
its numbering plan allows rather than one mask: Hungary takes 8 or 9 digits,
Germany 10 through 13, so the mask widens as the number grows. Validation holds
a number to those exact lengths — Armenia accepts 8 or 10 digits and refuses the
9 in between, which a generic 7-to-15 check would pass. Flags are derived from
the ISO code, so there are no assets to ship.

```dart
AppCountries.byIso('PT')!.format('912345678')  // '912 345 678'
AppCountries.split('+351912345678')            // (Portugal, '912345678')
AppCountries.initial = AppCountries.byIso('PT')!;  // move the default
```

Numbering plans are a good description of how numbers are *written*, not a
replacement for libphonenumber — validate server-side too if you need
carrier-level correctness.

### When the month is the content, not an answer in a form

`AppDateInput` opens the platform picker, which is what a date-shaped *field*
wants. An agenda, a booking screen or a streak wants the grid itself, and that
is `moarch create widget calendar` — a wrapper over
[table_calendar](https://pub.dev/packages/table_calendar) that keeps its sixty
parameters out of your screens.

```dart
AppCalendar(
  selected: _day,
  events: {for (final a in appointments) a.startsAt: 1},   // dots under the day
  onSelected: (day) => setState(() => _day = day),
  onMonthChanged: (first, last) => ref.read(p.notifier).load(first, last),
)
```

Two `DateTime`s in the same day are not equal, which is the usual reason a
marker never appears — so `events` is **re-keyed to the day** each entry falls
on. Pass the instants your data already carries; two appointments at 09:00 and
14:00 count as two dots on one day rather than missing the grid entirely.

`onMonthChanged` reports the *month's* own bounds, not the six weeks drawn
around it — the range you actually want to fetch events for. Colors come from
`AppInputVariant` like the rest of the family, `canChangeFormat` offers the
month/2-week/week toggle (and only then is a vertical swipe live), and leaving
`onSelected` off makes it a read-only display.

### One sheet for "what do you want to do with this?"

`moarch create widget action-sheet` adds `AppActionSheet` — the thing behind a
three-dot button or a long press. Material rows on Android, the iOS grouped
cards everywhere else, off the same split `AppDateInput` uses for its pickers.

```dart
final picked = await AppActionSheet.show<String>(
  context,
  title: 'Order #1042',
  actions: [
    const AppSheetAction(label: 'Edit', icon: Icons.edit_outlined, value: 'edit'),
    const AppSheetAction(label: 'Share', icon: Icons.ios_share, value: 'share'),
    const AppSheetAction.destructive(
      label: 'Delete',
      icon: Icons.delete_outline,
      value: 'delete',
    ),
  ],
);
```

Dismissing resolves to `null`, so a `switch` on the result has one honest "the
user backed out" branch. A row can carry an `onTap` instead of a `value`, and
it runs **after** the sheet has closed — a handler that pushes a route while
the sheet is still closing otherwise fights the navigator for it. Destructive
rows are drawn in the theme's error color and confirm nothing on their own:
pair one with `AppConfirmDialog` when the answer should be deliberate.

Unlike `AppDialogs` and `AppBottomModals` it takes a `BuildContext` rather than
the router's navigator key, so it costs the project no GoRouter.

### Audio you configure rather than wire

`moarch create widget audio-player` adds `AppAudioPlayer` over
[just_audio](https://pub.dev/packages/just_audio). It owns the `AudioPlayer`,
loads the source and disposes both, so a screen never holds a controller.

```dart
AppAudioPlayer(
  source: const AppAudioSource.url('https://example.com/episode.mp3'),
  title: 'Episode 12',
  showSpeed: true,
)
```

**Every part is a switch**, which is what makes one widget serve a podcast
screen and a voice note in a chat bubble:

```dart
AppAudioPlayer(
  source: AppAudioSource.file(recording.path),
  style: AppAudioPlayerStyle.compact,   // one row
  showSkip: false,                      // a 6-second note has nothing to skip
  showSpeed: false,
  showRemaining: true,                  // -0:04 rather than the total
)
```

`showControls`, `showProgress`, `allowScrub`, `showTimes` and `showSpeed` are
independent, and the skip buttons take **durations rather than a fixed 15/30** —
the number is drawn inside the arrow, so any interval works without an icon per
value:

```dart
AppAudioPlayer(
  source: ...,
  skipBackward: const Duration(seconds: 10),
  skipForward: const Duration(seconds: 10),
)
```

Buffered progress rides in the bar's secondary track, a scrub is not dragged
back by the position stream mid-drag, and a finished clip restarts on the next
tap rather than sitting at the end. It plays audio and nothing else — the same
split `just_audio` makes; lock-screen controls are `just_audio_background`'s
job and adding it changes nothing here.

### Children you can drag into a new order

`moarch create widget drag-section` adds `AppDragSection`. It reports the move
and nothing else — the list stays yours, so it can live in a notifier, in
storage, or on a server without the widget holding a second copy of the truth.

```dart
AppDragSection(
  items: [
    for (final card in _cards)
      AppDragItem(id: card.id, child: DashboardCard(card)),
  ],
  onReorder: (from, to) => setState(
    () => _cards = AppDragSection.reorder(_cards, from, to),
  ),
)
```

Each item says how big it is and whether it moves; the section says which way
it runs:

```dart
AppDragSection(
  orientation: Axis.horizontal,
  items: [
    AppDragItem(id: 'a', size: AppDragSize.large, child: ChartCard()),
    AppDragItem(id: 'b', size: AppDragSize.small, child: TotalCard()),
    AppDragItem(id: 'new', draggable: false, child: AddTile()),   // pinned
  ],
  onReorder: _move,
)
```

**A pinned item is a wall, not just an item that cannot be picked up** —
nothing can be dropped past it, so the "add" tile above keeps the last slot
however the rest are shuffled. `AppDragSize.small/medium/large` come from
`AppDragSizes` (retune the whole section at once), or give one item an exact
`extent`.

A long press starts the drag by default, because an immediate listener over the
item's whole surface fights the scroll; `trigger: AppDragTrigger.handle` puts a
grip on the trailing edge instead, for an item that is already tappable.

`onReorder` hands you indices **already corrected** for both the
`ReorderableListView` off-by-one and any pinned item in the way, and
`AppDragSection.reorder` does the remove-and-insert.

### A table that fits a phone

`moarch create widget table` adds `AppTable` — no dependency, and sized for a
screen narrower than the data.

```dart
AppTable(
  columns: const [
    AppTableColumn(label: 'Item', flex: 2),
    AppTableColumn.numeric(label: 'Qty', width: 56),
    AppTableColumn.numeric(label: 'Total'),
  ],
  rows: const [
    AppTableRow(cells: ['Coffee', '2', '€7.00']),
    AppTableRow(cells: ['Pastry', '1', '€2.40']),
  ],
  footer: const AppTableRow(cells: ['Total', '3', '€9.40']),
)
```

Columns are fixed (`width`) or flexible (`flex`), and a flexible one never
squeezes below its `minWidth`. Past the point where the minimums no longer fit,
**the table pans sideways** instead of crushing the columns further.

`AppTableColumn.numeric` right-aligns and switches on tabular figures, so a
column of money reads down cleanly. Rows take `onTap`, `selected` and a colour
of their own; `striped`, `showRowDividers`, `showColumnDividers`, `showBorder`
and `density` decide the rest. Cells are strings by default, or pass `widgets`
for a chip or an avatar.

It deliberately **does not scroll vertically** — a table that owns a vertical
scroll cannot sit in a page that also scrolls without one of them being wrong.
Drop it into `AppSingleScrollView` or a `ListView`.

### One country list, two ways in

`moarch create widget country-picker` adds `AppCountryPicker` over the same
238-country `AppCountry` table `AppPhoneInput` reads. As a field:

```dart
AppCountryPicker(
  label: 'Country',
  selectedIso: _iso,
  required: true,
  onChanged: (country) => setState(() => _iso = country.iso),
)
```

Or as a sheet on its own, from anywhere that is not a form:

```dart
final country = await AppCountryPicker.show(context, selectedIso: _iso);
```

`show` is **the single place the country sheet is configured** — the flag
leading each row, the calling code trailing it, and the ranked search that makes
`PT` find Portugal rather than the first country whose name contains those
letters. `AppPhoneInput` now opens that same sheet for its prefix instead of
carrying its own copy, so the two cannot drift apart.

It hands back the whole `AppCountry` rather than a code, since the caller
usually wants the dial code or the flag too. `display` picks what the closed
field reads as — `🇵🇹 Portugal`, the name alone, `🇵🇹 +351`, or just the flag —
and `countries` narrows the list to the ones you ship to.

### Long lists get a search instead of a menu

A menu stops being usable somewhere around thirty options, so past that an
`AppDropdownInput` opens a `SearchPickerSheet` instead — the same field, the
same callback, a list you can type into. It counts its own options and decides;
`searchable: true` or `false` overrules it for one field, and
`AppInputConfig.searchableThreshold` moves the line for the whole app.

```dart
AppDropdownInput<CategoryEntity>(
  label: 'Category',
  items: categories,
  idOf: (c) => c.id,
  labelOf: (c) => c.name,
  required: true,
  selectedId: _categoryId,
  onChanged: (id) => setState(() => _categoryId = id),
  onSelected: (category) => _prefillFrom(category),
  onCleared: () => setState(() => _categoryId = null),
)
```

Either form is a real form field: `required: true` is rejected by
`Form.validate()`, and `validator` replaces the rule.

`AppMultiSelectInput` is the same field in the plural — the same entity list,
the same sheet with a checkbox on every row, and a `maxSelected` the sheet
enforces as you tick rather than leaving to the form to refuse afterwards:

```dart
AppMultiSelectInput<TagEntity>(
  label: 'Tags',
  items: tags,
  idOf: (t) => t.id,
  labelOf: (t) => t.name,
  selectedIds: _tagIds,
  maxSelected: 3,
  required: true,
  onChanged: (ids) => setState(() => _tagIds = ids),
)
```

It hands back the whole selection in `items` order, and shows it as removable
chips, as labels, or as "3 selected".

### `required` means the form actually refuses

Every input that takes `required` enforces it — the text, phone, dropdown, date
and time fields, and the controls that carry a selection rather than text:

```dart
AppCheckboxLabel(
  label: 'Accept the terms',
  value: _accepted,
  required: true,          // Form.validate() fails until it is ticked
  onChanged: (v) => setState(() => _accepted = v),
)

AppRadioGroup<Plan>(
  values: Plan.values,
  groupValue: _plan,
  labelOf: (p) => p.name,
  required: true,          // ...until one is chosen
  onChanged: (p) => setState(() => _plan = p),
)
```

A checkbox has no border to turn red and no helper line to explain itself, so
these render the message underneath through `SelectionFormField` — which is
exposed, if you want to put a control of your own into a form the same way.

### One file decides how every input looks

`shared/widgets/inputs/app_input_config.dart` is the whole family's answer to
"where does the label go, and what does a field look like by default?" — read by
`AppInput`, the date/time/dropdown/OTP fields, and the checkbox, switch,
segmented, chips, radio, slider, stepper and search widgets alike.

Edit the literal in that file and you are done — no wiring, no `main()`:

```dart
// app_input_config.dart
static AppInputConfig defaults = const AppInputConfig(
  labelMode: AppInputLabelMode.floating,   // above | floating | placeholder | none
  type: AppInputType.outlined,
  shape: AppInputShape.pill,
  requiredMarker: ' (required)',
  autovalidateMode: AutovalidateMode.onUserInteraction,
);
```

It stays assignable for what a literal can't do — a flavor or white-label build
picking at startup (`AppInputConfig.defaults = ...` before `runApp`).

Any field still overrides it: `AppInput(label: 'Email', labelMode: AppInputLabelMode.above)`.

It also owns the numbers that used to be private constants — border widths, the
resting-border and fill opacities, and the font/icon/padding metrics behind
`small` / `medium` / `large`. What it deliberately does **not** own is color:
that comes from `ColorScheme` so it can differ between light and dark, and the
fill tint blends into the theme's `inputDecorationTheme.fillColor`. Raw sizes
stay in `AppConstants`; the config decides which token each input size picks.

Everything else in the kit is one command away, catalogued in the generated
`docs/UI_KIT.md`:

```bash
moarch create widget switch        # AppSwitch (+ any widgets it depends on)
moarch create widget otp           # AppOtpInput (adds the mo_2fa_code package)
moarch create widget all           # the whole kit + the DesignSystemView preview
moarch create widget --list        # print the catalog in the terminal
```

Widget dependencies are pulled in automatically, and any pub package a widget needs
([mo_2fa_code](https://pub.dev/packages/mo_2fa_code) for OTP, `cached_network_image`
for avatars/images) is added to `pubspec.yaml`.

The kit covers:

- **inputs** — switch, segmented, choice chips, radio group, slider, date/time,
  date range, dropdown (searchable on request), multi-select, checkbox, OTP,
  rating, file picker, `AppSearchField`, `AppStepper` (quantity −/+),
  `AppPhoneInput` (per-country masking), `AppCalendar` (inline month),
  `AppCountryPicker` (238 countries)
- **overlays** — `AppActionSheet` (platform-shaped), `AppToast`,
  `AppConfirmDialog`, `AppBottomSheetScaffold`, dialog/bottom-sheet helpers
- **buttons & icons** — `AppButton`, `AppTextButton` (the quiet, text-first
  action), `AppLeadingIcon`, `AppIconButton`, `AppFab`
- **layout** — `AppListTile`, `AppCard`, `AppCardTile`, `AppTag`, `AppBadge`,
  `AppSectionHeader`, `AppExpansionTile`, `AppTimeline`, `AppTable`,
  `AppDragSection`, `AppRichText` (a style and a tap handler per span, with the
  recognizers handled for you)
- **feedback** — `AppAsyncView`, `ref.listenAction`, `AppBanner`,
  `AppProgressBar`, `AppScreenLock`, skeleton list, loading overlay,
  `ErrorView`, `EmptyView`
- **media** — `AppAvatar`, `AppImage`, `AppCarousel`, `AppAudioPlayer`
- **navigation** — `AppAppBar`, `AppBottomNav` (Material 3, classic, pill or
  dot; labels beside, below or nowhere; each of which can float as a stadium,
  rounded or square card), `AppTabs`, `AppDrawer`,
  `AppNavRail` / `AppAdaptiveNav`, `AppStepIndicator`

Every control shares one vocabulary — `variant`, `type`, `shape`, `size` — and
`moarch create widget design-system` (or `all`) generates a screen previewing them
all. It renders with the same `AppTheme` `main.dart` uses — so what you see there
is what ships: edit `lib/config/theme/app_theme.dart` and the preview follows
(with a light/dark toggle in its app bar when the project has both themes). Set
`AppConstants.fontFamily` (or swap in `google_fonts`) to restyle the whole app's
typography from one place.

### One theme, or two

A project scaffolds with **one brand palette**: `AppConstants` declares a single
set of colors and `AppTheme` has a single `light` getter that `main.dart` hands
to `MaterialApp`. That is the common case, and it keeps the file you actually
edit — the palette — half the size.

Tick **Dark theme** in the `init` checklist to get the other half: a `*Dark`
counterpart for every color token, an `AppTheme.dark` built from them, and
`darkTheme` + `themeMode: ThemeMode.system` wired into `main.dart`. `AppToast`
then picks its status color per brightness, and the design-system preview gets
its toggle.

Either way it is reversible, and moarch reads the scope off `app_theme.dart`
rather than remembering it, so `moarch update` keeps regenerating what the
project actually is:

```bash
moarch create theme --dark      # add the dark half to a one-theme project
moarch create theme --no-dark   # drop it again
moarch create theme --dark -d   # ...or just print the diff first
```

The palette and everything reading it are generated against each other, so the
switch is all of those files at once. Files moarch wrote and nobody edited are
rewritten silently; if you have edited one, nothing is written and the diffs are
yours to apply (or `--force`).

## Models from a JSON sample

`moarch create model` writes an entity + model with an `id` and TODOs where
the fields go. Hand it a sample of the payload the API actually returns and it
fills them in:

```bash
moarch create model orders order --from-json sample.json
```

```dart
// from {"id": 7, "customer_name": "Ana", "total": 12.5,
//       "created_at": "2026-08-01T10:30:00Z", "tags": ["vip"]}
final int id;
final String customerName;   // fromJson reads json['customer_name']
final double total;          // parsed through num — an int in the payload is fine
final DateTime createdAt;    // ISO-dated strings become DateTime
final List<String> tags;     // homogeneous lists keep their element type
```

`fromJson` / `toJson` keep the original JSON keys, and `fromEntity` /
`toEntity` and `==` / `hashCode` come out complete. A top-level JSON *list* is
sampled at its first element — the common shape of a list endpoint's response.
A `null` in the sample can only type as `dynamic` (a null says nothing about
its type), and the command calls those fields out so you can tighten them.

## Flavors

`moarch create flavors` sets up `dev` / `staging` / `prod` — or the names you
pass — through [flutter_flavorizr](https://pub.dev/packages/flutter_flavorizr),
configured so the project keeps **one `main.dart`**: yours, untouched.

It writes `flavorizr.yaml` with the app name and the Android/iOS ids read from
the project (non-production flavors get suffixed ids, so the builds install
side by side) and adds the dev dependency. The `instructions` list in that
file is the point: flavorizr runs only the processors that patch the native
side and generate `lib/flavors.dart` — no `main_<flavor>.dart` entry points,
no replaced `main.dart`.

```bash
moarch create flavors
flutter pub get
dart run flutter_flavorizr    # applies the instructions in flavorizr.yaml
flutter run --flavor dev
```

That one run is equivalent to applying the processors by hand:

```bash
dart run flutter_flavorizr -p android:flavorizrGradle,android:buildGradle,android:androidManifest
dart run flutter_flavorizr -p ios:xcconfig,ios:plist
dart run flutter_flavorizr -p flutter:flavors
```

The app reads the current flavor off the generated `lib/flavors.dart`, and the
flavored entries `init` writes into `.vscode/launch.json` (a debug/release
pair per flavor) work as soon as the native side is patched.

With Firebase, each suffixed application id is its own app in the Firebase
console — register them there and re-run `flutterfire configure`.

## Staying up to date

Generated code goes stale: the templates keep improving, and a project scaffolded
two versions ago still has the old `app_input.dart` and the old
`validation_service.dart`. `moarch update` closes that gap without ever gambling
with your edits.

```bash
moarch update                # the whole project — refresh what's safe, review the rest
moarch update --list         # every name and group update accepts
moarch update --dry-run      # report only, write nothing
moarch update --diff         # show what would change, line by line
moarch update validation     # one file, on its own
moarch update input button   # or several
moarch update core docs      # or whole groups
```

It covers everything the CLI generates, not just widgets — each addressable on
its own:

| group | what's in it |
| --- | --- |
| `widgets` | the whole `lib/shared/widgets/` kit (`input`, `button`, `toast`…) |
| `core` | `extensions`, `logger`, `constants`, `api-constants`, `action-notifier` / `action-bloc`, `exception`, `main` |
| `network` | `dio-client`, `safe-api-call`, `safe-firebase-call` |
| `security` | `validation`, `secure-storage`, `biometric` |
| `services` | `media-service`, `notifications-service`, `permission-service`, `debouncer`… |
| `config` | `theme`, `env`, `router`, `routes`, `firebase-providers`, `injector` |
| `auth` | the generated auth feature, REST or Firebase, notifier or bloc |
| `docs` | `ui-kit`, `deploy-checklist`, `security-checklist`, `jks-doc`, `workflow-doc`, `firebase-doc` |
| `workflows` | the five GitHub Actions workflows |
| `project` | `analysis-options`, `splash`, `fvmrc`, `widget-test`, `vscode-settings`, `vscode-launch` |
| `ios` | `ios-entitlements`, `ios-profile-entitlements`, `xcode-script` |
| `android` | `proguard` |

Only files your project actually has are ever touched: `update` refreshes what is
there, it never scaffolds what you chose not to generate. Templates that vary
with your setup — `app_logger.dart` with Crashlytics, `main.dart` with the router
and localization, the auth feature against REST or Firebase — are rebuilt against
the project they're being written into.

It sorts every generated file into one of three buckets:

| | |
| --- | --- |
| **up to date** | already matches the current template — nothing to do |
| **can be refreshed** | moarch wrote it, you never touched it, the template has since changed |
| **needs review** | the template changed *and* so did your copy — listed and diffed, never overwritten |

The distinction comes from `.moarch.yaml`, a manifest written at generation time
recording the moarch version, your init selections, and a hash of every file the
CLI wrote. **Commit it.** Without it moarch can't prove a file is untouched, so
it falls back to treating everything as needing review — safe, just less useful.

Nothing in the third bucket is written unless you pass `--force`, which discards
those edits. Run `git diff` after any update before committing.

> A project scaffolded by an older moarch has no record of the non-widget files,
> so they report as *needs review* until the first `update` re-records them.
> That's the safe direction: nothing is overwritten on the strength of a guess.

## Checking a project

`moarch doctor` looks for the things that break a scaffolded project in practice:

- `build_runner` never run, so `config/env/app_env.g.dart` doesn't exist yet
  (the most common first-run failure)
- both localization approaches installed, leaving `MaterialApp` with two
  competing sets of delegates
- a generated widget whose dependency or pub package was never added — a
  broken import either way
- `go_router` and `config/router/` out of sync
- Firebase half-wired: no `Firebase.initializeApp()` in `main.dart`, a missing
  `google-services.json` / `GoogleService-Info.plist`, `firebase_core` or
  `google_sign_in` absent from `pubspec.yaml`, or `Info.plist` still carrying
  the placeholder Google client ids — each of which fails at runtime, on the
  first call, with an error that doesn't name the step that was missed

Each finding says what to do about it, and `moarch doctor --fix` applies the
mechanical ones — generating a missing widget dependency, adding a missing
package, copying `CLIENT_ID` and `REVERSED_CLIENT_ID` out of
`GoogleService-Info.plist` into `Info.plist`. Anything that's a genuine choice
(which localization package to drop) is reported and left to you.

## Make it your own

moarch is a helper built first for my own projects and my coworkers' — the
templates are *our* conventions, and the pub.dev package will keep following
them. When your conventions differ, the intended move is not a feature
request: clone it and make the templates yours.

```bash
git clone https://github.com/SuperMoooo/moarch.git
cd moarch
# edit lib/src/templates/** — every generated file is a plain Dart string
dart pub global activate --source path ./
```

Every template lives under `lib/src/templates/`, one function per generated
file, and the catalogs (`lib/src/utils/widget_catalog.dart` and
`scaffold_catalog.dart`) are the lists of what exists — add an entry there and
`init`, `create widget` and `update` all pick it up. Once activated from your
path, `moarch update` in your projects refreshes toward *your* templates: the
manifest machinery doesn't care whose they are.

## License

MIT © André Montoito
