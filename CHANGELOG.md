# Changelog

All notable changes to this package are documented in this file, newest first.

## 7.1.1

- **The get_it registrations are split one file per layer.** `moarch init` now
  writes `lib/config/di/` as five files rather than one: `injector.dart` holds
  `getIt` and a `setupInjector()` that calls one registrar per layer, and the
  registrations live beside the layer they belong to —
  `external_module.dart` (Dio, the Firebase handles, secure storage),
  `core_module.dart` (the services under `lib/core`), `data_module.dart`
  (datasources and repositories) and, on bloc, `presentation_module.dart` (the
  blocs). `injector.dart` is the same length in a one-feature app and a
  fifty-feature one.

    On Riverpod there is no presentation module at all, which is the layout
    saying out loud what was already true: a notifier needs the `Ref` Riverpod
    owns, so it lives behind its provider and reads what it depends on out of
    the locator. Everything else — clients, services, datasources,
    repositories — is in get_it in both stacks.

- **`AppButton` gains `isDisabled`.** The same end state as `onPressed: null`,
  said the other way round — `isDisabled: !form.isValid` rather than
  `onPressed: form.isValid ? _submit : null` — so the handler stays visible
  at the call site. Both routes work and they compose. A loading button still
  keeps its full color, because busy is not the same as unavailable; a
  disabled one fades, and stays faded even while it loads.

## 7.1.0

- `moarch create feature` and `moarch create bloc` now write each half of a
  feature into the module it belongs to: the datasource and repository into
  `data_module.dart`, the bloc into `presentation_module.dart`. Both files
  carry the `// moarch:registrations` anchor.

- `moarch update` gains four slugs — `di-external`, `di-core`, `di-data`
  and `di-presentation` — all under the `config` group.

- **Projects generated before this release keep working, untouched.** Which
  layout a project has is detected off disk, not remembered: `create feature`
  patches the single `injector.dart` when that is what the project has, and
  `moarch update injector` refreshes it as the single file rather than
  replacing it with a root that calls modules the project does not have.
  `moarch doctor` notes the older layout as information — nothing is
  wrong, and it exits 0.

- `moarch doctor` no longer fails over an informational finding. `info`
  severity is printed and does not count towards the exit code; errors and
  warnings are unchanged.

## 7.0.1

- For Failure bloc states, failure is unique

## 7.0.0

### Breaking

- **Entities and models are now `freezed` classes, and models add
  `json_serializable`.** Every generated entity and model changes shape, and a
  generated project gains four dependencies (`freezed_annotation` and
  `json_annotation` at runtime, `freezed` and `json_serializable` in dev). The
  entity/model split is unchanged: `domain/entities/` stays JSON-free,
  `data/models/` keeps `fromEntity()` / `toEntity()`. What is gone is
  `class XModel extends XEntity` — freezed generates the concrete class, so
  there is no constructor left to inherit. The model declares its own fields
  and maps them explicitly.

            This does **not** migrate a project that already exists: `moarch update`
            compares hashes and refuses to overwrite an edited file, and it never touches
            `pubspec.yaml`. In particular, refreshing the auth feature (`moarch update

    auth`) on a project scaffolded before this release writes freezed sources
    into a project that has no freezed. Add the four dependencies first.

- `moarch create entity-copys` is removed. It injected `copyWith`, `==` and
  `hashCode` into an entity; freezed writes all three, and injecting them on
  top is a duplicate-member compile error. `moarch create model <feature>
<name> --from-entity` is what replaces it — see below.
  `moarch create empty-factories` stays: `.empty()` is a hand-written
  convenience freezed does not produce.

### Fixed

- **A hand-written `==` keyed on `id` alone silently dropped state.** Both
  stacks' entity templates, and `create model --from-json`, generated
  `other is XEntity && other.id == id`. A multi-step create form builds drafts
  that all share an empty id, so every draft compared equal to the last —
  `Bloc.emit` short-circuits on `state == _state`, and a Riverpod notifier only
  rebuilds listeners on a changed state, so every update after the first was
  dropped and the form quietly lost what had been typed into it. The same
  equality was on `AuthUserEntity`, where a changed display name or photo never
  reached the UI. Freezed's equality covers every field and compares
  collections by content.
- **A hand-written `copyWith` could not set a nullable field back to `null`.**
  `x ?? this.x` cannot tell "not passed" from "passed null". Freezed uses a
  sentinel and gets it right.
- **The Firestore model wrote a stale `id` into the document body.** `add()`
  assigns the id only once the write lands, so the copy stored beside the data
  was wrong from the moment it was written. The id now carries
  `@JsonKey(includeToJson: false)` and is read back off the snapshot —
  `fromDoc` folds `doc.id` into the payload before parsing.
- **A Firestore `DateTime` was stored as an ISO string**, which the server
  sorts and ranges as text, so a range query compared character by character
  and an index on the field bought nothing. A generated `TimestampConverter`
  (`lib/core/network/timestamp_converter.dart`) stores it as a real
  `Timestamp`, and reads it back in UTC so the same document does not decode to
  a different `DateTime` on two devices.

### Added

- `moarch create model <feature> <name> --from-entity` — writes the model for
  an entity you wrote by hand, mapping its fields in both directions. A field
  whose type is another entity is **converted, not assigned**:
  `DatasModel.fromEntity(entity.datas)` one way and `datas.toEntity()` the
  other, element-wise for a `List<XEntity>`, null-guarded when the field can be
  absent. It also imports the sibling models it maps to and names the ones that
  do not exist yet.
- `--doc` marks a Firestore document root, on `--from-entity` and `--from-json`
  alike: the model gets `fromDoc` and keeps its id out of the body. Leave it off
  for a value object nested inside a document, which can carry an `id` of its
  own and still be a plain map. On `--from-json` it also supplies the `String
id` the sample could not — a document's id is its name, so an exported payload
  does not carry one — and retypes an `id` the sample inferred as something
  else, since `doc.id` is always a String.
- `build.yaml` is now generated, carrying `explicit_to_json: true`. Without it
  json_serializable leaves a nested model in `toJson()`'s map as the object it
  is rather than as a map — `jsonEncode` papers over that, but
  `FirebaseFirestore.add(model.toJson())` throws on it.
- `*.freezed.dart` and `*.g.dart` are added to `.gitignore`. CI already runs
  `build_runner build` before `analyze` and `test`, so they are a command away.

### Changed

- `moarch create model` now reads Firestore off the project like every other
  command — on the plain scaffold and on `--from-json` — so a Firestore project
  gets the document-shaped model rather than a REST one its own datasource
  cannot use, and its dates are stored as `Timestamp`s.
- `bloc_lint` is floored at `^0.4.1` rather than `^0.4.2`. 0.4.2 needs
  `_fe_analyzer_shared >=100`, which only analyzer 13 brings, while freezed 3.x
  caps analyzer below 11 — the two do not resolve together, and a bloc project
  simply failed `pub get`. 0.4.1 accepts what analyzer 10 ships.
- `freezed` is pinned below 4 on purpose: 4.0.0 raised its floor to Dart 3.13,
  which no released Flutter stable ships yet. The class shape moarch writes is
  the same in both, so this is a floor to raise, not a rewrite.

### Inputs

- **A validation error is drawn flush with the field** instead of indented by
  the decoration's content padding, which left it out of line with the label
  above it. `AppInputStyle.decorationError` is the one place that cancels the
  indent, and every field in the kit goes through it — `TextFormField` and
  `DropdownButtonFormField` via `errorBuilder`, the `FormField`-based pickers
  via `InputDecoration.error`, and the controls that draw their own line
  (checkbox, radio, slider, file picker) via `AppInputStyle.errorStyle`.
- **"This field is required" is declared once**, as
  `AppInputConfig.requiredMessage`. It was spelled out in nine widgets;
  translating it is now a one-line assignment to `AppInputConfig.defaults`.

## 6.5.0

### Fixed

- **`moarch init --all` did not resolve on either stack.** `file_picker: ^11`
  pins `win32 ^5.9`, and `flutter_secure_storage: ^11` reaches `win32 ^6.0.1`
  through `flutter_secure_storage_windows` — the two cannot both be installed.
  file_picker is now `^12.0.0`, which is where it stopped depending on win32
  directly. 12 also dropped the `FilePickerResult` wrapper (`pickFiles` returns
  `List<PlatformFile>`) and deprecated `pickFiles(allowMultiple: false)`, so
  `media_service.dart` now branches to `FilePicker.pickFile` for a single pick.
- **A Riverpod project could not install `mogen_integration_tests`.** 1.1.2
  needs `analyzer >=13`, which a Riverpod app cannot reach: riverpod 3.4.2
  declares `test` as a regular dependency, and `test` resolved against
  flutter_test's pinned `matcher`/`test_api` caps analyzer below 13. The
  constraint is now `^1.1.1`, which gives pub somewhere to back off to — a bloc
  project still installs 1.1.2, a Riverpod one takes 1.1.1. (The real fix is
  upstream: `mogen_unit_tests` declares `analyzer >=10 <15` and never
  conflicts; `mogen_integration_tests` narrowed its floor to 13.)
- **The generated Riverpod project did not compile against flutter_riverpod 3.**
  `ProviderListenable` — the type every `ref.listen` takes, and the one
  `listenAction` is declared with — left the main barrel in Riverpod 3.
  `action_listener.dart` now imports `package:flutter_riverpod/misc.dart`,
  where it lives.
- `AppAsyncView` built its stream/future states with `AsyncValue.copyWithPrevious`,
  which went `@internal` in Riverpod 3 and warned in every generated project.
  It now tracks `hasValue` / `value` / `error` / `isLoading` itself and adapts
  the provider's `AsyncValue` through public getters only. Behaviour is
  unchanged: a reload or a failed refresh still leaves loaded data on screen.
- `moarch create feature` generated the repository, its implementation, the
  entity and the model even when the Repository row was left unticked —
  the state holder was assumed to need one, so the layer was silently added
  back. The checklist is now taken literally: unticking Repository generates a
  bloc that takes nothing and loads nothing until you point it somewhere, and
  a Riverpod notifier whose `build()` is a TODO with no locator behind it.
  Both are registered and both compile.

### Changed

- **The generated bloc is four states and one event.** `Initial`, `Loading`,
  `Success`, `Failure`, and `Started` — dispatched when the screen opens and
  again to refresh or retry. `Refreshed` is gone: a retry is the same load,
  and two names for it is one too many.
- **`Success` is generated empty.** It carried a `List<XEntity> items`, a
  `copyWith` and a `placeholder` of fake rows. What a screen shows is the
  screen's business, and a scaffolded list half the features do not want is a
  line to delete rather than a head start — so it ships as `const XSuccess()`
  with a TODO saying where the fields and their `props` go. The state no
  longer names an entity at all, which is what lets a feature without a data
  layer compile.
- **The Firestore live variant of the bloc is gone**, and with it
  `create bloc --firestore`. It brought two events of its own
  (`ItemsUpdated`, `Failed`), a `StreamSubscription` and a `close()` override.
  Every bloc is now the one-off `await _repo.fetchAll()` shape whatever the
  backend is; a live query is the project's to wire. The _data_ layer is
  untouched — a Firestore datasource still has `watchAll()` and the repository
  still declares it.
- The view still shimmers while loading, traced over a stand-in
  `const XSuccess()` instead of a `placeholder` static, with a comment saying
  to give the fields fake values as they are added. It no longer imports
  `EmptyView`, which only the live variant had a use for.
- Comments across the generated bloc, event, state, page and view are cut back
  to what is load-bearing.
- `moarch create bloc` registers the bloc even when the feature has no
  repository — it takes nothing, so there is nothing to wait for.

## 6.4.0

### Features

- `AppBottomNav` takes a `borderColor`. Floating, it is a hairline around the
  card, drawn as part of the shape Material already cuts the corner with;
  docked, it replaces the `outlineVariant` line between the bar and the
  content, and gives Material's own bar a top edge it never drew. Null is the
  bar every project had before this — a flat dark theme is where it earns its
  place, since the shadow holding a floating card up is invisible there.
- `AppBottomNav` takes a `floatingWidth`. `AppBottomNavWidth.hug` sizes the
  floating card to its destinations and centers it, instead of spanning the
  screen — two or three tabs stretched across a phone is mostly empty card.
  `floatingMaxWidth` caps the width of either, which is how a `fill` bar stops
  short of the edges on a tablet. Both are only read when `floating`: a docked
  bar is the bottom edge.
    - The styles the widget draws itself hug by way of a min-size row; Material's
      own `NavigationBar` divides whatever width it is handed, so hugging
      measures it with an `IntrinsicWidth` instead.
- `AppAdaptiveNav` hands the phone layout the three new knobs as
  `bottomNavBorderColor`, `bottomNavWidth` and `bottomNavMaxWidth`.
- The generated design-system screen previews the new looks: a hugging
  bordered pill bar, a capped Material one, and a docked bar with a colored
  top edge.

## 6.3.1

### Features

- `core/utils/extensions.dart` gains `FormX.isValid` on
  `GlobalKey<FormState>`, so a submit reads `if (_formKey.isValid)` instead of
  `_formKey.currentState?.validate() ?? false`. An unmounted form reports
  invalid, which is the safe half of that `??`.

## 6.3.0

### Features

- `core/utils/extensions.dart` gains `FormX.isValid` on
  `GlobalKey<FormState>`, so a submit reads `if (_formKey.isValid)` instead of
  `_formKey.currentState?.validate() ?? false`. An unmounted form reports
  invalid, which is the safe half of that `??`.

### Fixed

- The generated `main.dart` now removes the native splash _after_ `runApp()`
  rather than before it. Removing it first hands the screen back to the
  framework before a single frame has been painted, which is a blank window
  for as long as the first build takes — on a cold start with a router that
  parks on a loading route, that flash is visible. The comment above the call
  says how to push it later still (your own async init, or a post-frame
  callback) if something has to land before the app is on screen.

- flutter*bloc: the app-wide `BlocProvider<AuthBloc>` is now `lazy: false`.
  A lazy provider builds its bloc on the first read \_from the widget tree*,
  and nothing reads this one that way — the router's redirect and its
  `refreshListenable` both take the bloc out of the locator. So the
  `..add(const AuthStarted())` in `create` never ran, session restore never
  started, and the router sat on the splash route waiting for a state change
  that could not arrive.

## 6.2.0

### Features

- `init` now writes `lib/core/network/paginated.dart` alongside
  `safe_api_call.dart` whenever Dio is part of the stack — `Paginated<T>`, the
  envelope a REST list endpoint answers with. It exists so the first feature
  to paginate has one shape to share rather than one per repository.

    Shaped for the common `{page, limit, total, data}` response, but written to
    be edited: the envelope is the backend's choice, not the app's. The item key
    is a `dataKey` argument rather than a literal, and the counts are read
    leniently — a missing or stringified `total`, which a last page or a PHP
    backend will hand you, costs a fallback instead of a `TypeError` that
    `safeApiCall` can only report as an unknown failure. A null item list reads
    as an empty page for the same reason. `fromJsonT` takes an `Object?` rather
    than a `Map`, so a page of scalars parses through the same factory as a page
    of models.

    What survives renaming the fields is the arithmetic and the two members the
    Clean Architecture boundary is there for: `map`, so a repository hands the
    domain a page of entities instead of a page of models, and `append`, which
    is the whole of "load more" — the state holds one `Paginated` and replaces
    it with `state.append(page)`. `pageCount` treats a zero `limit` as a single
    page, so an envelope that carried no page size cannot loop a load-more
    forever.

    Nothing generated consumes it yet: `fetchAll()` still returns a whole list
    and the feature states still hold a plain `List`. Wiring a `loadMore` path
    through the notifier and bloc templates is a separate change; a project
    whose API never pages can delete the file.

- `paginated` is a catalog entry, so `moarch update paginated` refreshes it,
  `moarch update network` includes it, and `--diff` shows what a refresh would
  change.

## 6.1.0

### Features

- `init` now writes the project's own `README.md` — the one generated document
  aimed at a person rather than a task, written for someone who has never
  worked on a Clean Architecture Flutter app. Thirteen sections: what the
  project is and why the dependency rule shapes the folders; a first-run
  walkthrough from installing FVM through `.env` and `build_runner` to
  `fvm flutter run`, with a table of what to do when each step fails; the
  tooling and the packages that shape how the code is written; an annotated
  tree; one piece of data traced entity → model → repository → get_it →
  `AppException`; the state stack the project actually took; `moarch create
feature` and the five steps that are still yours; flavors; the build
  commands and where the artefacts land; the workflows and every secret they
  read; the conventions the analyzer cannot check; contacts and access; and
  where the rest of `docs/` picks up.

                        It replaces the README `flutter create` leaves behind and only that one —
                        matched on two of its own sentences, the same way `main.dart` and
                        `widget_test.dart` already are, so a README you wrote is never touched.

- The README is a catalog entry, so `moarch update readme` refreshes it and
  `--diff` shows what a refresh would change. Like every other template it
  reads its options back off the project rather than remembering them: the
  state stack, the packages, the workflows, and now the flavors — `init` runs
  before `moarch create flavors` exists, so a fresh project gets the flavor
  setup walkthrough, and the same file rewrites itself with the real flavor
  names, run commands and artefact paths once `flavorizr.yaml` is on disk.

    Two sections are `[bracketed]` placeholders instead: the owner line and
    **Contacts & access**, which no detection can fill in.

- `ScaffoldContext` gained `projectName`, `flavorNames` and `hasWorkflows`.
  `flavorNames` scans `flavorizr.yaml` rather than parsing it as YAML: that
  file is edited by hand, and a malformed one should cost the README its
  flavor list, not make every template in the catalog throw.

## 6.0.0

**Breaking on update, not on init.** A project scaffolded with 6.0.0 is fine.
An existing 5.x project is only affected if you run `moarch update` — and then
in one specific way: `buildDioClient` takes a new required `refreshSession:`
argument, and `injector.dart` is the file that passes it. `update` refreshes
`dio_client.dart` silently (you almost certainly never edited it) but leaves
`injector.dart` alone, because `moarch create feature` writes into it and that
counts as edited. The two then disagree and the project stops compiling.

Refreshing both together is the fix:

```bash
moarch update dio-client
moarch update injector --force   # only if you have no hand-edits to keep
```

Or add the argument by hand:

```dart
..registerLazySingleton<Dio>(
  () => buildDioClient(
    getIt<TokenStorage>(),
    refreshSession: () => getIt<AuthRepository>().refresh(),
  ),
)
```

Two smaller ones in the same shape:

- `auth_remote_datasource.dart` now calls `ApiConstants.authLogin` and friends,
  so refresh `api-constants` alongside it or the datasource will not resolve
  them.
- Refreshing a state holder switches it from `GetX` to `XRepository`. That
  compiles as-is — the repository was always registered too — but leaves
  `domain/usecases/get_x.dart` and its `registerLazySingleton<GetX>` orphaned.
  Both can be deleted.

### Changed

- Generated `pubspec.yaml` now carries a caret constraint on every dependency
  instead of `any`, from one table in `lib/src/utils/package_versions.dart`
  that is bumped per release. `intl` stays unconstrained on purpose:
  `flutter_localizations` pins it exactly from the SDK.
- **Use cases are no longer generated.** A `GetX` that only forwarded
  `_repository.fetchAll()` added a name and no behaviour, and the auth feature
  `init` scaffolds never had one — so the two halves of the generator
  disagreed about whether the layer existed. State holders take the
  repository in both stacks.
- The refresh-token protocol is written once. `dio_client.dart` no longer
  carries its own bare Dio, endpoint and JSON keys beside the datasource's:
  the 401 interceptor takes a `refreshSession` callback, `injector.dart`
  passes the auth repository's `refresh` (as a callback, since the repository
  is built on that same client), and the repository — a lazy singleton —
  owns the single-flight guard that used to be a top-level mutable global.
- `/auth/*` paths moved into `ApiConstants`, so the datasource and the Dio
  client's public-route list read the same strings.
- `safeApiCall` recognises offline from what Dio throws rather than asking
  `connectivity_plus` before every request — that cost a platform round-trip
  per call and reported a captive portal as online. `safeFirebaseCall` keeps
  its pre-flight; its doc comment now says so.
- Every `moarch create` subcommand accepts either a `lib/` or the project
  root for `--path`.

### Fixed

- `moarch create feature` in a bloc project scaffolded Riverpod when `--path`
  pointed at the project root: `StateManagement.detect` only looked one
  directory up for `pubspec.yaml`, and falls back to Riverpod when it finds
  none. It now walks up until it finds one.
- `moarch update` rewrote a bloc project's `analysis_options.yaml` as the
  Riverpod one, dropping the `bloc:` ruleset — the catalog spec called
  `analysisOptions()` without the stack.
- A failed account deletion is reported instead of swallowed. `AuthFailure`
  now carries the session it failed from (`userId`), so the router redirect
  can tell "signed out, with a reason" from "still signed in, and something
  went wrong" — which is what made the failure unemittable before. The same
  change gives the Firebase password-reset handler distinct states for two
  identical failures in a row, where Equatable had deduped the second emit
  and shown nothing.
- `debugLogDiagnostics` and Dio's `LogInterceptor` are debug-only. `appLogger`
  already dropped the log records in release, but `msg.toString()` runs at the
  call site, so every response body in the app was still serialised in full
  first.

### Removed

- `AppRoutes.designView` (pointed at a screen `init` does not generate) and
  `AppRoutes.forgotPassword` (unrouted, and silently in `publicRoutes`).
- `AppExceptionType.cache` and `.parsing`, which nothing ever constructed,
  and the `AppException.test()` factory — a test helper shipped in `lib/`.

### Added

- `.env.example`, committed beside the gitignored `.env`. Without it a fresh
  clone had no `.env` at all and `build_runner` failed on `app_env.dart`
  before a new developer could run anything.

## 5.0.4

- Adjustments

## 5.0.3

- Adjustments

## 5.0.2

- Transformers on bloc

## 5.0.1

### A bloc's page is a file of its own

`moarch create feature` on the bloc stack writes
`presentation/pages/<x>_page.dart` beside `presentation/views/<x>_view.dart`.
The page is the `BlocProvider` — it builds the bloc out of the locator, opens
it with its first event, and is what a `GoRoute` points at. The view is left a
plain widget that reads the bloc off the context, so a widget test can pump it
with a bloc of its own without the locator being set up.

Riverpod generates no page: a notifier is read through a provider wherever it
is needed, so there would be nothing to wrap the screen in. The auth screens
are unchanged in both stacks — their holder is provided once, above the router.

## 5.0.0

**Breaking for both stacks.** A project generated with 5.0.0 does not look like
one generated with 4.x. Nothing migrates an existing project: `moarch update`
refreshes a file where the current templates put it, so a 4.x bloc project
keeps its `presentation/states/` folder — and `update` stops refreshing what is
in it — until the files are moved by hand. A 4.x Riverpod project keeps its
providers and is not touched.

### Riverpod uses get_it for dependency injection

Riverpod declared a provider beside every class it built. It no longer does.
`lib/config/di/injector.dart` — the file the bloc stack has had since 4.0.0 —
is now generated for **both** stacks, and holds the same things in both:
clients, services, datasources, repositories and use cases.

- Gone from a Riverpod project: `dioClientProvider`, `secureStorageProvider`,
  `tokenStorageProvider`, `firebaseAuthProvider`, `firebaseDbProvider`,
  `permissionProvider`, `mediaServiceProvider`, `urlLauncherProvider`,
  `notificationServiceProvider`, `firebaseNotificationsServiceProvider`,
  `biometricServiceProvider`, `connectivityProvider`, `debouncerProvider`,
  `dialogProvider`, `modalProvider`, and the per-feature
  `<x>RemoteDataSourceProvider` / `<x>LocalDataSourceProvider` /
  `<x>RepositoryProvider` / `get<X>Provider`. Each is a `getIt<Thing>()` now.
- **Riverpod holds the state; get_it holds everything the state is built
  from.** What stays a provider is what actually holds state: the feature
  notifiers, `authNotifierProvider`, `languageProvider`, `routerProvider`,
  `hasInternetProvider` and `maintenanceStatusProvider` — and those read their
  dependencies out of the locator.
- A notifier is the seam between the two. `AsyncNotifier` needs the `Ref` only
  Riverpod can hand it, so it is not registered in get_it; it declares
  `OrdersRepository get _repo => getIt<OrdersRepository>();` in place of
  `ref.watch(ordersRepositoryProvider)`.
- `moarch create feature` now registers what it generated in a Riverpod
  project too — the datasource, the repository and the use case, at the
  `// moarch:registrations` anchor. The notifier is the only thing it leaves
  out, because there is nothing to register.
- `main.dart` calls `await setupInjector()` before `runApp` in both stacks.
  The `ProviderContainer` / `UncontrolledProviderScope` dance a Riverpod
  project needed when a service held a `Ref` is gone with the services: it is
  a plain `ProviderScope` again, whatever is selected.
- `get_it` is a dependency of both stacks. `moarch doctor` checks for it and
  for the locator in both.
- The services that only differed in how they were reached — secure storage,
  biometrics, permissions, media, URL launcher, notifications, FCM, debouncer,
  dialogs, modals, `AppButton` — now have one body instead of two.
  `config/firebase/firebase_providers.dart` and `core/network/dio_client.dart`
  are the same file in both stacks and moved out of the per-stack
  `AppTemplates`.

### A bloc's state lives with its bloc

`presentation/states/<x>_state.dart` moves to `presentation/blocs/<x>_state.dart`
on the bloc stack, beside the events and the bloc. The three are one unit — the
handlers emit the states — and a change to any of them is usually a change to
all three. Riverpod is unchanged: `presentation/states/` beside
`presentation/notifiers/`.

### Bloc views are `BlocConsumer`

The generated view is a `BlocConsumer` rather than a `BlocBuilder`, with a
`listener` prepared for the states the feature has and
`listenWhen: (previous, current) => previous != current`. It is the bloc answer
to `ref.listen`: `listener` runs once per new state — where a toast, a dialog
or a `context.push` belongs — while `builder` runs on every rebuild.

### Fixes

- `moarch create bloc` wrote Riverpod's `core/utils/action_notifier.dart` into
  a bloc project, importing `flutter_riverpod` in a project that does not have
  it. It also named a mixin (`ActionBlocMixin`) that has never existed. The
  file is no longer written.
- The Riverpod feature notifier declared a repository getter it never called,
  which the analyzer reports as an unused element, and imported the use case
  without using it. It now calls its dependency in `build()` and takes the use
  case when there is one — the same rule the bloc has followed since 4.0.0
  (the repository regardless on the Firestore variant, whose live query no use
  case wraps).
- The Riverpod repository implementation imported `app_exception.dart` without
  using it, and the local datasource imported its model without using it.
- The bloc feature state's `--firestore` variant declared its constructor as
  `const OrdersSuccess{...}` — no parentheses around the parameter list, so
  the generated file did not parse. It is `const OrdersSuccess({...})` now.

## 4.0.0

**Riverpod projects are unaffected by this release** — every template, field
and file path on that side is unchanged. Everything below is the new stack.

### Features

- **flutter_bloc is a supported stack.** `moarch init` now asks which state
  management the project uses before anything else — Riverpod, as before, or
  flutter_bloc with `get_it` for dependency injection. Every state-bearing
  template exists in both, under `lib/src/templates/riverpod/` and
  `lib/src/templates/bloc/`: the feature scaffold, both auth features,
  `AppAsyncView`, the action listener, the maintenance gate, the router, the
  Dio client and `main.dart`. Same layers, same file names, same layer
  boundaries — a project reads the same way whichever it took.
- A bloc feature is **sealed on both sides**: a `<Feature>Event` family, and a
  `<Feature>State` family of `Initial` / `Loading` / `Success` / `Failure`, so
  the view is a `switch` the compiler checks for completeness. The family is
  the status — there is no flag or enum on top of it. States and events extend
  `Equatable`, which is load-bearing: bloc drops an emit equal to the current
  state and `BlocBuilder` rebuilds on the same test, so without it every emit
  repaints.
- `AuthState` follows the same shape: `AuthInitial` (restoring, which is what
  parks the router on splash), `AuthLoading`, `AuthAuthenticated`,
  `AuthUnauthenticated`, `AuthFailure`.
- Bloc views are **plain flutter_bloc**: `BlocProvider` in a `Page`,
  `BlocBuilder` and a `switch` in the `View`. `AppAsyncView`,
  `ref.listenAction` and any shared action base are not generated into a bloc
  project — they exist to map Riverpod's opaque `AsyncValue` onto four
  screens, and a sealed family needs no wrapper. `moarch create widget
async-view` says so rather than writing a file that cannot compile.
- `moarch create feature` reads the stack off `pubspec.yaml` and generates for
  it — no new flag. In a bloc project it also **registers what it generated**
  in `lib/config/di/injector.dart`, at the `// moarch:registrations` anchor.
- `moarch create bloc <feature> <name>` adds a state + event + bloc trio to a
  feature that already exists, wired to that feature's repository.
- `moarch init --state riverpod|bloc` picks the stack without the checklist,
  so `--all` can reach either one.
- Generated bloc projects get `bloc_lint` in dev dependencies, the recommended
  ruleset in `analysis_options.yaml`, and a `bloc lint` step in the CI
  workflow. A freshly scaffolded project passes it with no findings.
- `moarch doctor` checks what the project's own stack needs: `get_it` and a
  locator with its anchor comment for bloc, `flutter_riverpod` otherwise.

### Changes

- `main.dart`, `action_notifier.dart`, `app_router.dart`, `dio_client.dart`,
  `firebase_providers.dart` and `language_service.dart` moved out of
  `CoreTemplates` / `ConfigTemplates` / `ServicesTemplates` into the per-stack
  `AppTemplates`. Nothing changes in what a Riverpod project generates.
- Templates that differ only in how a service is reached — the services, secure
  storage, the biometric service, `AppButton`, the dialog and modal helpers,
  the design-system preview — take the stack as a parameter instead of being
  duplicated, so there is one body to maintain.

## 3.2.2

### Fixes

- `moarch create widget` recorded only the files it wrote this run, so a widget
  already on disk stayed out of `.moarch.yaml` — and `moarch update` then read
  it as a file it could not vouch for. `create widget <name>` and
  `create widget all` now also record a widget they skipped when its content is
  still exactly what the current templates generate, whether it got there from
  an earlier run, a copy, or a run that stopped before saving. A file that
  differs is still left out: that content is yours.

## 3.2.1

### Features

- `AppBottomNav` takes two more looks apart from its `style`. `labels`
  (`auto` / `below` / `none`) says where the destination names are written, so
  the pill can stack over its label instead of opening sideways, the dot can
  carry one at all, and any style can drop to icons only — a label that is not
  drawn still reaches a screen reader and still names its icon on a long press.
  `floatingShape` (`full` / `rounded` / `square`) cuts the floating card's
  corner, and `pillShape` the corner of the fill behind the selection — which
  Material's own bar reads too, as its indicator. Both take a
  `BorderRadius` of the project's own (`floatingBorderRadius`,
  `pillBorderRadius`) where the three names are not the number wanted.
  `AppAdaptiveNav` passes all four down as `bottomNavLabels`,
  `bottomNavShape`, `bottomNavPillShape` and their radius pair. Defaults are
  what the bar drew before.
- The dark theme is now a choice. `init` asks for it (**Dark theme**, off by
  default): with it off, `AppConstants` declares one brand palette and
  `AppTheme` one `light` getter — around 290 fewer lines in the files you
  actually edit. With it on, every color token gains its `*Dark` counterpart,
  `AppTheme.dark` is generated, and `main.dart` gets `darkTheme` +
  `themeMode: ThemeMode.system`.
- `moarch create theme --dark` adds the dark half to a project scaffolded
  without it, and `--no-dark` takes it away again. The palette, the theme,
  `main.dart`, `AppToast` and the design-system preview are generated against
  each other, so the switch is all of them at once: files moarch wrote and
  nobody edited are rewritten silently, and an edited one stops the run with a
  diff instead (`--diff`, `--dry-run`, `--force`, `--yes`).
- The scope is read off `app_theme.dart` rather than remembered, so
  `moarch update` and `moarch create widget` follow what the project actually
  is — including after switching.

### Fixes

- `main.dart` shipped `darkTheme: AppTheme.dark` commented out, so a generated
  app was light-only whatever the palette said. The design-system preview had
  the same line commented out under a working brightness toggle, leaving a
  button that did nothing. Both are now wired when the project takes dark.

### Changes

- `AppConstants` drops the tokens nothing in the kit read: `accentActive`,
  `accentRestorative`, `accentEnergetic` (the tab indicator uses `primary`),
  `padding8`, `paddingH16`, `paddingH24`, `paddingV16`, `borderRadius24` and
  `duration100`. The remaining colors are grouped brand → surfaces → status,
  with the dark palette (when present) in one block rather than three.

### Upgrading

An existing project keeps its dark theme — the scope is read off
`app_theme.dart`, so `moarch update` sees what is already there. Two things to
look at in the diff it offers:

- `moarch update constants` removes the tokens listed above. If your own code
  reads one of them, keep it: it is your palette now.
- `moarch update main` uncomments `darkTheme` and sets `themeMode`, which is
  what the dark palette was always for — but it does mean the app starts
  following the system brightness. `moarch create theme --no-dark` is the way
  out if it was never meant to.

## 3.1.9

### Fixes

- Maintence Gate

## 3.1.8

### Fixes

- `AppTextButton` alignment now moves the label: it reaches the row and the
  text, and claims the parent's width to align inside of

### Features

- `AppTextButton` gains `bare`, dropping the button box around the label

## 3.1.7

### Features

- Padding page to 12

## 3.1.6

### Features

- Adjustments

## 3.1.5

### Features

- Adapt widget for size dimensions

## 3.1.4

### Fixes

- **The design-system preview renders in the app's real theme.** It built its
  own `ThemeData(useMaterial3: true)` behind a `TODO`, so the one screen whose
  job is showing what the kit looks like was the one screen not showing it —
  every widget previewed in stock Material colors and type instead of the
  project's. It now uses `AppTheme.light` / `AppTheme.dark`, the same themes
  `main.dart` mounts, so editing `lib/config/theme/app_theme.dart` moves the
  preview with it. `app_theme.dart` is written unconditionally by `init`, so
  the new import needs nothing the scaffold did not already have.

- **`init` and `doctor` now surface the `fvm use` step.** `init` writes a
  `.vscode/settings.json` pointing `dart.flutterSdkPath` at `.fvm/flutter_sdk`,
  but only `fvm use` creates that symlink and `.fvm/` is gitignored — so on a
  fresh scaffold or a fresh clone the path did not exist. Nothing reports that:
  the Dart extension silently falls back to the first Flutter on `PATH`, and
  debug, hot reload and the analyzer all run the SDK the `.fvmrc` pin exists to
  avoid. The only symptom is analyzer output that disagrees with
  `fvm flutter analyze`. `init` now prints `fvm use` as the first step, ahead of
  `pub get`, and `moarch doctor` grew a check for it:
    - `dart.flutterSdkPath` pointing at a path that does not exist — **error**,
      with the `fvm use` fix.
    - the symlink present but dangling, the pinned SDK not installed — **error**,
      pointing at `fvm install`.
    - a versioned `.fvm/versions/<version>` path, which is what `fvm use` rewrites
      the setting to and which stops following `.fvmrc` — **warning**, and
      `doctor --fix` points it back at `.fvm/flutter_sdk`.
    - `settings.json` missing, or carrying no `dart.flutterSdkPath` — **warning**.

                                                                                                      An absolute path is left alone as a deliberate override, and a project with no
                                                                                                      `.fvmrc` gets none of these findings.

- The README documents that the generated `.fvmrc` pins the `stable` _alias_
  rather than a version, so `fvm install` on CI or a teammate's machine can
  resolve to a different SDK than your cache holds, and how to pin for real once
  the project ships.

## 3.1.3

### Features

- AppCard adjustment

## 3.1.2

### Features

- **`MaintenanceGate`** — a kill switch the backend owns. While a flag says
  maintenance, it replaces the whole app with a screen carrying the title and
  message the backend sent, so the team taking the API down can empty the app,
  and reword the notice, without a release. Mounted in `MaterialApp.builder` so
  it wraps the Navigator: above every route the router can reach, including
  anything pushed after the flag flips. It replaces rather than covers, so
  nothing is left to tap and the back button has nothing to pop.
  **It fails open** — loading, offline, endpoint down or rules denied all read
  as "up", because a fault in the check must not lock out every user at once.
  The provider follows the project's backend: a live Firestore `snapshots()`
  listener, a polled Dio endpoint (five minutes, plus on resume), or a stub to
  point at your own source. Available in the `init` checklist and as
  `moarch create widget maintenance-gate`.
- Widgets whose source varies with the project are now resolved in one place,
  `WidgetCatalog.sourceFor`, instead of being special-cased separately in
  `init`, `create widget` and `update` — three copies that had to agree, or
  `update` would report a file as edited the moment it was generated.

- **`init` writes `android/app/proguard-rules.pro`** — the keep rules that were
  until now only printed in `docs/SECURITY_BEFORE_DEPLOYMENT.md` for you to
  copy across: the Flutter engine, Play Core, Firebase, OkHttp, coroutines,
  enums, native methods, and `SourceFile,LineNumberTable` so a release stack
  trace still de-obfuscates. The file is inert until the release build type
  turns R8 on, so enabling minification before a release is now just that
  gradle block rather than that block plus a round of release-only crashes.
  The doc renders the same template, so the two cannot drift. Refreshable with
  `moarch update proguard` (new `android` group).

### Docs

- **`CHECKLIST_BEFORE_DEPLOYMENT.md` and `SECURITY_BEFORE_DEPLOYMENT.md`
  reconciled with what the scaffold actually does.** Both were generic
  checklists that asked you to do work `init` had already done. Items the
  scaffold handles now arrive ticked and name the file that handles them
  (`config/env/app_env.dart`, `TokenStorage`, `ValidationService`,
  `app_logger.dart`, the CI jobs), so the OWASP mapping stays complete but you
  can see at a glance what is left. Everything unticked is genuinely yours.
- Gaps the checklists implied were covered are now called out as gaps, with the
  exact steps: no `.env.example`, no `network_security_config.xml`, R8 rules
  written but not enabled, `build/debug-info/` never uploaded by the Android
  workflow, and `build_ipa.yml` archiving through `xcodebuild` without carrying
  the Dart obfuscation flags.
- Corrected content that no longer matched the generator: the `envied` example
  pointed at `lib/core/env/env.dart` and class `Env` (the scaffold generates
  `lib/config/env/app_env.dart` and `AppEnv`), the R8 block was Groovy
  `build.gradle` where the scaffold patches `build.gradle.kts`, and two code
  examples had Portuguese UI strings in an otherwise English doc.

## 3.1.1

### Features

- AppHeading

## 3.1.0

### Features

- **`moarch create flavors`** — sets a project up for `dev` / `staging` /
  `prod` flavors (or the names you pass) through
  [flutter_flavorizr](https://pub.dev/packages/flutter_flavorizr), configured
  so the project keeps **one `main.dart`** — yours, untouched. It writes a
  `flavorizr.yaml` whose `instructions` run only the native-side processors
  (`android:flavorizrGradle`, `android:buildGradle`, `android:androidManifest`,
  `ios:xcconfig`, `ios:plist`) plus `flutter:flavors`, and adds the dev
  dependency — so `dart run flutter_flavorizr` patches the native side and
  generates `lib/flavors.dart`, and nothing else. No per-flavor
  `main_<flavor>.dart` entry points. The Android application id and iOS bundle
  id are read from the project, non-production flavors get suffixed ids so the
  builds install side by side, and the flavored entries `init` already writes
  into `.vscode/launch.json` start working.
- **`moarch create model --from-json <file>`** — hands the command a sample of
  the payload the API actually returns, and the entity and model come out with
  real fields instead of TODOs: a complete `fromJson` / `toJson` keyed on the
  original JSON keys, `fromEntity` / `toEntity`, and `==` / `hashCode`.
  ISO-dated strings become `DateTime`, doubles parse through `num` so an int
  in the payload doesn't crash them, homogeneous lists keep their element
  type, snake_case keys become camelCase fields, and a top-level JSON list is
  sampled at its first element. A `null` in the sample can only type as
  `dynamic`, and is called out so you can tighten it by hand.

### Fixes

- The `.vscode/launch.json` template carried a trailing comma that strict
  JSONC parsers flag, introduced in 3.0.0 — removed, and the template tests
  brought back in line with the 3.0.0 template rewrite.
- `moarch init --dry-run` listed every file, including ones a real run would
  have skipped because they already exist. The preview now makes the same
  decision against the same disk as a real run.
- A failed scaffold's rollback removed the files it created but left their
  empty directory chains behind — the directories are now removed too
  (only ever ones the run itself created, and only when empty).
- `moarch update` failing partway through a refresh left the project half on
  the old templates and half on the new. The files already refreshed are now
  restored to what they held before.

### Meta

- **The changelog accumulates again.** Each release used to replace the whole
  file, so pub.dev only ever showed the latest entry — the full release
  history below was restored from git.
- `topics` and `issue_tracker` added to `pubspec.yaml`.
- CI now verifies `lib/src/version.dart` matches `pubspec.yaml`.
- `example/example.dart` rewritten to match the current CLI.

## 3.0.0

### Features

- comment reduction, and adjustments

## 2.9.4

### Features

- placeholder and other things

## 2.9.3

### Features

- fcm token

## 2.9.2

### Features

- app toast adjustment

## 2.9.1

### Features

- new widgets

## 2.9.0

### Features

- Firebase Auth is now a backend choice, not just a provider. Selecting it with
  the auth feature generates that feature against Firebase instead of REST:
  email/password, **Google sign-in**, password reset, account deletion, and a
  session restored from `authStateChanges()`. Same layers and provider names, no
  token storage, and Dio is no longer pulled in for it.
- `moarch create feature` follows the project's backend: in a Firestore project
  the datasource holds `_firestore` instead of `_dio`, with
  `fetchAll`/`fetchOne`/`watchAll`/`create`/`save`/`delete` over one collection
  and a `String` document id. With both backends installed, the layer checklist
  asks which one the feature talks to.
- `AppException` maps the Firebase failures an app actually hits: a
  `fromFirebaseAuthError` factory for the auth codes (`invalid-credential`,
  `email-already-in-use`, `weak-password`, `requires-recent-login`,
  `too-many-requests`…) and the Firestore codes (`permission-denied`,
  `unavailable`…) in `fromFirebaseError`. New `auth` and `cancelled` types, plus
  `AppException.cancelled()` for a dismissed sign-in sheet.
- New `core/network/safe_firebase_call.dart` — the Firebase counterpart of
  `safeApiCall`, for one-off calls and for streams.
- New `docs/FIREBASE_SETUP.md` covering the work that lives outside Dart:
  `flutterfire configure`, enabling the sign-in providers, the Android
  SHA-1/SHA-256 fingerprints, the iOS `GIDClientID` and `REVERSED_CLIENT_ID` URL
  scheme, the web client id, and a starting set of Firestore rules.
- `init` writes the two iOS Google sign-in keys into `Info.plist`, taking the
  real values from `GoogleService-Info.plist` when it is already there and
  leaving documented placeholders when it isn't. Existing URL types are kept.

### Fixes

- `main.dart` now calls `Firebase.initializeApp()` for Firestore and Firebase
  Auth, not only for Crashlytics — a project with either selected used to throw
  "No Firebase App '[DEFAULT]' has been created" on its first provider read.

### Doctor

- New checks for a half-wired Firebase project: missing `firebase_core` or
  `google_sign_in`, no `Firebase.initializeApp()` in `main.dart`, a missing
  `google-services.json` / `GoogleService-Info.plist`, and `Info.plist` still
  carrying the placeholder Google client ids — which `--fix` fills in from
  `GoogleService-Info.plist`.

## 2.8.1

### Features

- app async view supports stream and future

## 2.8.0

### Features

- **`moarch update` now refreshes everything the CLI generates, not just the
  widget kit.** The gap it closed for widgets was the same gap `core/`,
  `config/`, the auth feature, the docs and the workflows had all along: a
  project scaffolded two versions ago still carries the old
  `validation_service.dart`, and nothing told you which improvements you were
  missing or which changes were your own.
    - **Every file is addressable on its own** — `moarch update validation`,
      `moarch update extensions`, `moarch update theme`, `moarch update logger`.
      With no arguments the whole project is considered, exactly as before.
    - **Or by group**, when a whole area has drifted: `widgets`, `core`,
      `network`, `security`, `services`, `config`, `auth`, `docs`, `workflows`,
      `project`, `ios`. They combine freely —
      `moarch update security docs extensions`.
    - `moarch update --list` prints every name and group with the file it maps
      to, so the slugs don't have to be guessed.
    - **Templates that vary are rebuilt against the project they land in**, not
      against a default: `app_logger.dart` keeps its Crashlytics branch,
      `main.dart` keeps the router, localization and notification services the
      project actually has, `app_exception.dart` keeps its Dio and Firebase
      mappings, and `build_ipa.yml` keeps its Firebase steps. The options are
      read back off the generated files and `pubspec.yaml` — the record that
      stays true as the project is edited.
    - **It refreshes, it never scaffolds.** A file the project declined at
      `init` is not missing, so naming it does nothing rather than generating
      it. `moarch update biometric` in a project without biometrics is a no-op.
    - The three buckets are unchanged, and now apply to all of it: untouched
      files refresh silently, edited ones are listed and diffed and never
      written without `--force`.

### Improvements

- **`moarch init` now records every file it writes in `.moarch.yaml`**, where it
  previously recorded only the widgets. That record is the whole basis for
  telling an untouched generated file from one you edited — without it the rest
  of the scaffold could only ever be reported as _needs review_.
    - A project scaffolded before 2.8.0 has no record of its non-widget files,
      so the first `moarch update` lists them as needing review even where they
      are untouched. Refreshing or confirming them re-records them, and
      subsequent runs are exact. That is the safe direction: nothing is
      overwritten on the strength of a guess.
- `.fvmrc` and `flutter_native_splash.yaml` are generated from `DevTemplates`
  rather than from literals inside the init command, so what `init` writes and
  what `update` compares against cannot drift apart.

## 2.7.1

### Features

- `AppAudioPlayer` (`moarch create widget audio-player`) — an audio player over
  [just_audio](https://pub.dev/packages/just_audio) that a screen configures
  rather than wires. It owns the `AudioPlayer`, loads the source and disposes
  both. One `AppAudioSource` covers url, asset and file.
    - **Every part is a switch**, so the same widget is a podcast screen and a
      voice-note bubble: `showControls`, `showSkip`, `showProgress`, `allowScrub`,
      `showTimes`, `showRemaining` and `showSpeed` are independent, and
      `AppAudioPlayerStyle.compact` is the one-row arrangement.
    - The skip buttons take **durations, not a fixed 15/30** — the number is drawn
      inside the arrow, so any interval works without an icon per value.
    - Buffered progress rides in the bar's secondary track; a scrub is not dragged
      back by the position stream mid-drag; a finished clip restarts on the next
      tap rather than sitting at the end; and `onCompleted` fires once per
      play-through rather than on every frame the player sits in `completed`.
- `AppDragSection` (`moarch create widget drag-section`) — a section whose
  children drag into a new order, vertical or horizontal, with no dependency.
    - It **reports the move rather than owning the list**, so the order can live
      in a notifier, in storage or on a server without the widget holding a
      second copy of it. `AppDragSection.reorder` does the remove-and-insert.
    - Each item declares its own size — `AppDragSize.small/medium/large` off a
      shared `AppDragSizes`, or an exact `extent` — and whether it can be moved.
    - **A pinned item is a wall**, not merely un-draggable: it carries no drag
      listener at all, and nothing can be dropped past it, so an "add" tile keeps
      the last slot however the rest are shuffled.
    - `onReorder` arrives already corrected for the `ReorderableListView`
      off-by-one and for any pinned item in the way.
    - A long press starts the drag, because an immediate listener over the whole
      item fights the scroll; `AppDragTrigger.handle` puts a grip on the trailing
      edge instead.
- `AppTable` (`moarch create widget table`) — rows and columns sized for a
  phone, with no dependency.
    - Columns are fixed (`width`) or flexible (`flex`), and a flexible one never
      squeezes below its `minWidth`. Past the point where the minimums no longer
      fit, the table **pans sideways** rather than crushing the columns.
    - `AppTableColumn.numeric` right-aligns and switches on tabular figures.
    - Rows take `onTap`, `selected` and a colour of their own; `striped`,
      `showRowDividers`, `showColumnDividers`, `showBorder` and `density` decide
      the rest. Cells are strings, or `widgets` for a chip or an avatar.
    - It deliberately **owns no vertical scroll** — a table that scrolls
      vertically cannot sit in a page that also does. Put it in
      `AppSingleScrollView` or a `ListView`.
- `AppCountryPicker` (`moarch create widget country-picker`) — the 238-country
  `AppCountry` table as a field of its own, validating like the rest of the
  family, or as `AppCountryPicker.show(context)` from anywhere that is not a
  form.
    - It hands back the whole `AppCountry` rather than a code, since the caller
      usually wants the dial code or the flag too. `display` picks what the closed
      field reads as, and `countries` narrows the list.

### Improvements

- **The country sheet is configured in one place.** `AppPhoneInput` carried its
  own `SearchPickerSheet` setup — the flag leading each row, the calling code
  trailing it, the ranked search that makes `PT` find Portugal rather than the
  first name containing those letters. That configuration now lives in
  `AppCountryPicker.show`, and the phone field opens it, so a standalone country
  field and a phone prefix cannot drift apart. `phone-input` gains
  `country-picker` as a dependency; the search sheet still arrives with it.

## 2.7.0

### Features

- `AppAudioPlayer` (`moarch create widget audio-player`) — an audio player over
  [just_audio](https://pub.dev/packages/just_audio) that a screen configures
  rather than wires. It owns the `AudioPlayer`, loads the source and disposes
  both. One `AppAudioSource` covers url, asset and file.
    - **Every part is a switch**, so the same widget is a podcast screen and a
      voice-note bubble: `showControls`, `showSkip`, `showProgress`, `allowScrub`,
      `showTimes`, `showRemaining` and `showSpeed` are independent, and
      `AppAudioPlayerStyle.compact` is the one-row arrangement.
    - The skip buttons take **durations, not a fixed 15/30** — the number is drawn
      inside the arrow, so any interval works without an icon per value.
    - Buffered progress rides in the bar's secondary track; a scrub is not dragged
      back by the position stream mid-drag; a finished clip restarts on the next
      tap rather than sitting at the end; and `onCompleted` fires once per
      play-through rather than on every frame the player sits in `completed`.
- `AppDragSection` (`moarch create widget drag-section`) — a section whose
  children drag into a new order, vertical or horizontal, with no dependency.
    - It **reports the move rather than owning the list**, so the order can live
      in a notifier, in storage or on a server without the widget holding a
      second copy of it. `AppDragSection.reorder` does the remove-and-insert.
    - Each item declares its own size — `AppDragSize.small/medium/large` off a
      shared `AppDragSizes`, or an exact `extent` — and whether it can be moved.
    - **A pinned item is a wall**, not merely un-draggable: it carries no drag
      listener at all, and nothing can be dropped past it, so an "add" tile keeps
      the last slot however the rest are shuffled.
    - `onReorder` arrives already corrected for the `ReorderableListView`
      off-by-one and for any pinned item in the way.
    - A long press starts the drag, because an immediate listener over the whole
      item fights the scroll; `AppDragTrigger.handle` puts a grip on the trailing
      edge instead.
- `AppTable` (`moarch create widget table`) — rows and columns sized for a
  phone, with no dependency.
    - Columns are fixed (`width`) or flexible (`flex`), and a flexible one never
      squeezes below its `minWidth`. Past the point where the minimums no longer
      fit, the table **pans sideways** rather than crushing the columns.
    - `AppTableColumn.numeric` right-aligns and switches on tabular figures.
    - Rows take `onTap`, `selected` and a colour of their own; `striped`,
      `showRowDividers`, `showColumnDividers`, `showBorder` and `density` decide
      the rest. Cells are strings, or `widgets` for a chip or an avatar.
    - It deliberately **owns no vertical scroll** — a table that scrolls
      vertically cannot sit in a page that also does. Put it in
      `AppSingleScrollView` or a `ListView`.
- `AppCountryPicker` (`moarch create widget country-picker`) — the 238-country
  `AppCountry` table as a field of its own, validating like the rest of the
  family, or as `AppCountryPicker.show(context)` from anywhere that is not a
  form.
    - It hands back the whole `AppCountry` rather than a code, since the caller
      usually wants the dial code or the flag too. `display` picks what the closed
      field reads as, and `countries` narrows the list.

### Improvements

- **The country sheet is configured in one place.** `AppPhoneInput` carried its
  own `SearchPickerSheet` setup — the flag leading each row, the calling code
  trailing it, the ranked search that makes `PT` find Portugal rather than the
  first name containing those letters. That configuration now lives in
  `AppCountryPicker.show`, and the phone field opens it, so a standalone country
  field and a phone prefix cannot drift apart. `phone-input` gains
  `country-picker` as a dependency; the search sheet still arrives with it.

## 2.6.0

### Features

- `AppCalendar` (`moarch create widget calendar`) — the inline month grid, for
  when the month itself is the content rather than one answer in a form.
  `AppDateInput` still opens the platform picker; this is its sibling for
  agendas, booking screens and streaks. A wrapper over
  [table_calendar](https://pub.dev/packages/table_calendar) that keeps its
  parameters out of your screens: colors come from `AppInputVariant` like the
  rest of the family, and the package is added to `pubspec.yaml` for you.
    - `events` is **re-keyed to the day** each entry falls on. Two `DateTime`s in
      one day are not equal, which is the usual reason a marker never appears —
      so you can pass the instants your data already carries, and two
      appointments at 09:00 and 14:00 count as two dots on one day rather than
      missing the grid.
    - `onMonthChanged` reports the month's own bounds, not the six weeks drawn
      around it — the range to fetch events for. For the two-week and week
      formats it reports their own span.
    - `canChangeFormat` offers the month/2-week/week toggle, and only then is a
      vertical swipe live; without it a swipe means one thing.
    - No `onSelected` makes it a read-only display, and `selectableDay` greys out
      the days that refuse a tap.
    - It lives in its own `lib/shared/widgets/calendar/` folder rather than
      alongside the fields.
- `AppActionSheet` (`moarch create widget action-sheet`) — the sheet behind a
  three-dot button or a long press. Material rows on Android and the iOS
  grouped cards elsewhere, off the same platform split `AppDateInput` uses for
  its pickers; either shape can be forced.
    - Rows resolve to a value, so `show<T>` hands back what was picked and `null`
      when it was dismissed — one honest "the user backed out" branch.
    - A row's `onTap` runs **after** the sheet has closed, rather than while it
      is closing, where a handler that pushes a route fights the navigator for
      it.
    - `AppSheetAction.destructive` draws in the theme's error color. It confirms
      nothing on its own — pair it with `AppConfirmDialog` when the answer should
      be deliberate.
      `AppDialogs` and `AppBottomModals`, so it costs the project no GoRouter.

### Fixes

- **`moarch create model --empty` generated a factory that could not compile.**
  It patches `<model>_entity.dart`, whose class is `<Model>Entity`, but named the
  factory after the model alone — `factory LoginResponse.empty() =>
LoginResponse(...)` inside `class LoginResponseEntity`. The guard that was
  meant to stop a second run looked for that same wrong name, so it never
  matched and every re-run stacked another broken factory into the file.
- **A field whose type carries a comma was silently dropped** from `.empty()`
  and from `copyWith`. The type was matched with a character class holding
  neither a comma nor a space, so `Map<String, dynamic> meta;` was not a field
  as far as the parser was concerned — and the factory it built came out missing
  a required argument. Types are now read up to the last identifier on the line
  and then validated, which also ends the false positives that class allowed:
  `return value;` in a method body was being read as a field named `value` of
  type `return`, and `String get title;` as a field named `title`.
- **An entity file declaring a second class had the two spliced together.** The
  parser took a class name and ignored it, reading every field in the file, so
  `AddressEntity`'s fields turned up in `UserEntity`'s `copyWith`. It now scopes
  to the named class's body — and so does the injection: `create entity-copys`
  appended `copyWith` and the `==` / `hashCode` pair at the file's _last_ closing
  brace, landing them on whichever class was written last, after stripping the
  existing equality members from every class in the file.
- **`create empty-factories` reported replacements it had not made.** Its
  pattern only matches an arrow-bodied `.empty()`, so a hand-written block-bodied
  one fell through `replaceFirst` unchanged while the log claimed it had been
  replaced. It now leaves that factory alone and says so, and a factory already
  matching what would be written is reported as skipped — which is what the
  `Skipped :` line in the summary always claimed to count and never did.

## 2.5.4

### Features

- logger update

## 2.5.3

### Features

- btn fix

## 2.5.2

### Features

- bottom nav upgrade

## 2.5.1

### Features

- `AppAsyncView` (`moarch create widget async-view`, generated by `init`) — takes
  one `AsyncValue` and draws the four states it can be in: a shimmered shape
  while the first load runs, `ErrorView` with a retry, `EmptyView` when the
  screen says its data counts as empty, and your body when there is something to
  show. A reload over existing data leaves that data on screen rather than
  replacing a list mid-read with a spinner, and an error carrying no message of
  its own shows no detail instead of a stringified exception.
- `ref.listenAction(...)` (`moarch create widget action-listener`, generated by
  `init`) — surfaces the one-shot `error` / `success` fields a generated state
  already carries as an `AppToast`. Pass `onError` / `onSuccess` to navigate or
  log instead; providing one replaces the toast for that outcome rather than
  adding to it, and a single action only ever reports one of the two.
- **The generated feature view is built on both.** `moarch create feature` used
  to write a `.when(...)` mapping by hand and leave `// SHOW UI ERROR` and
  `// SHOW UI SUCCESS` as comments in every feature. It now wires the two
  widgets up, passes its own body as the skeleton shape, and offers the retry
  `ErrorView` draws a button for. It also writes both widgets if the project
  predates them, so the view it generates always compiles.
- `AppMultiSelectInput` (`moarch create widget multi-select`) —
  `AppDropdownInput`'s plural: the same id/label entity list, any number
  selected, ticked in the search sheet with a per-row checkbox and a Done
  button. Shows its picks as removable chips, as labels, or as "3 selected";
  enforces `required`, `minSelected` and `maxSelected`, and stops the unticked
  rows at the ceiling rather than letting the form refuse the pick afterwards.
- `SearchPickerSheet.showMulti(...)` — the multi-select half of the sheet the
  dropdown and the country picker already open. It works on its own copy of the
  selection, so a dismissed sheet changes nothing and an empty result is a
  deliberate "none of them".
- `AppDateRangeInput` (`moarch create widget date-range-input`) — a read-only
  field holding a start and an end date, with a `maxDays` rule the picker itself
  cannot express. It holds a `DateTimeRange` rather than the text of one.
- `AppFilePickerField` (`moarch create widget file-input`) — an attachment
  field: an area that opens whichever picker the app already uses, and a row per
  file with a thumbnail, a readable size and a remove button. It imports no
  picker package, so it costs the project no dependency it had not already
  chosen.
- `AppRating` (`moarch create widget rating`) — stars both ways round: tappable
  with `onChanged`, a read-only score without it. Halves come from tapping the
  left half of a star, and a display-only rating stays out of `Form.validate()`.
- `AppTabs` / `AppTabBar` (`moarch create widget tabs`) — `AppTabs` owns the
  controller and puts the views under the bar, replacing it when the tab count
  changes; `AppTabBar` is the `PreferredSizeWidget` half that drops into
  `AppAppBar`'s `bottom` slot. Underline or pill indicator.
- `AppDrawer` (`moarch create widget drawer`) — the side menu, reading
  `AppBottomNav`'s destination list, with header and footer slots. It closes
  itself after a pick, and does nothing when the same widget is pinned beside
  the content instead.
- `AppNavRail` and `AppAdaptiveNav` (`moarch create widget nav-rail`) — the
  vertical navigation a tablet shows instead of a bottom bar, and the scaffold
  that picks between them off the 600dp short-side breakpoint. All three nav
  widgets read one `AppNavDestination` list.
- `AppFab` (`moarch create widget fab`) — the screen's floating action,
  circular or extended off one parameter, wearing `AppButtonVariant` /
  `AppButtonType` rather than a vocabulary of its own. `isLoading` swaps the
  icon for a spinner without resizing the button, and `heroTag` is exposed for
  the two-FABs-on-one-screen case.
- `AppTimeline` (`moarch create widget timeline`) — a vertical sequence of
  events joined by a connector, with done/current/pending/failed nodes.
  `AppTimeline.entryBuilder` hands you one row for a lazy list.
- `AppCarousel` (`moarch create widget carousel`) — swipeable pages with
  stretching dots, optional peek and auto-advance. The timer stops for good on
  the first swipe and never starts when the platform asks for reduced motion;
  `AppCarouselDots` is usable on its own.

### Fixes

- **`moarch init` never wrote its own `lib/main.dart`.** `flutter create` leaves
  one behind and generated files are never clobbered, so on the documented quick
  start (`flutter create` → `moarch init`) the counter demo survived and the
  scaffold's main.dart — the one that installs `ProviderScope` and initialises
  the selected services — was silently skipped. Every scaffolded app was missing
  its provider root. The counter demo is now replaced, matched on the two
  private names only that template declares; a main.dart you wrote is still left
  alone, and init says so instead of passing over it in silence. The counter
  `widget_test.dart` that pumped it is replaced on the same terms, so
  `flutter test` passes on a fresh project.
- **`file_picker` resolved to 3.0.4** (2021) whenever the media service was
  selected, and 3.0.4 predates AGP's `namespace` requirement — so the Android
  build failed with "Namespace not specified" before the app could run. The
  entry was unversioned, and pub is free to resolve _backwards_: `file_picker`
  11 wants `win32 ^5`, `flutter_secure_storage_windows` wants `win32 ^6`, and
  walking `file_picker` back to 3.0.4 settled that Windows-only conflict. It now
  carries a `^11.0.0` floor, and `MediaService` calls the static
  `FilePicker.pickFiles` that version moved to.
- Three widgets used null-aware elements (`?header`), which need the _project's_
  pubspec to ask for Dart 3.8+ — not merely a recent SDK to be installed — so
  they failed to compile in a project scaffolded a while ago. Rewritten to
  constructs with no language-version floor, and a test now fails if a template
  reaches for one again.

### Improvements

- **`AppToast` was redrawn.** It was a grey `surfaceContainerHighest` bar with a
  4px accent stripe and an icon beside it — a Material 2 snackbar with a
  decoration. It is now a card: a surface tinted 7% with the status color, a
  status-colored outline, a soft shadow, and the icon in a tonal chip matching
  `AppLeadingIcon`'s. The outline is what the old one could not have — a
  `SnackBar` takes a color and a shape but not a border — so the toast now draws
  its own card inside a transparent, unelevated SnackBar.
  It also gains a `title` over the detail line, an optional close button, a
  `warning` / `info` helper to go with `success` / `error`, `AppToast.dismiss`,
  a 480px ceiling so it stays a card rather than a banner on a tablet, and
  sideways swipe-to-dismiss. In dark themes it now sits on
  `surfaceContainerHighest` — an overlay has to be lighter than the page it
  covers, and the old bar was darker than the content behind it.
- `AppButton`'s `hint` moved inside the button, centered under the label, in the
  button's own foreground color; the button grows to fit it. It used to be a
  left-aligned line floating above the button, which read as a caption for
  whatever was above it rather than as part of the action.
- The design-system preview covers `AppPhoneInput` and `AppAsyncView` — the
  phone field has been in the kit since 2.4.0 without a preview, and the async
  view's four states are steppable in it. A new test fails if a widget joins the
  catalog without either a preview section or an explicit, reasoned exemption,
  so the screen can no longer fall behind the kit unnoticed.
- `moarch create feature` records what it writes into `shared/widgets/` in
  `.moarch.yaml`, so `moarch update` can tell those files apart from ones you
  have since edited.

## 2.5.0

### Features

- `AppAsyncView` (`moarch create widget async-view`, generated by `init`) — takes
  one `AsyncValue` and draws the four states it can be in: a shimmered shape
  while the first load runs, `ErrorView` with a retry, `EmptyView` when the
  screen says its data counts as empty, and your body when there is something to
  show. A reload over existing data leaves that data on screen rather than
  replacing a list mid-read with a spinner, and an error carrying no message of
  its own shows no detail instead of a stringified exception.
- `ref.listenAction(...)` (`moarch create widget action-listener`, generated by
  `init`) — surfaces the one-shot `error` / `success` fields a generated state
  already carries as an `AppToast`. Pass `onError` / `onSuccess` to navigate or
  log instead; providing one replaces the toast for that outcome rather than
  adding to it, and a single action only ever reports one of the two.
- **The generated feature view is built on both.** `moarch create feature` used
  to write a `.when(...)` mapping by hand and leave `// SHOW UI ERROR` and
  `// SHOW UI SUCCESS` as comments in every feature. It now wires the two
  widgets up, passes its own body as the skeleton shape, and offers the retry
  `ErrorView` draws a button for. It also writes both widgets if the project
  predates them, so the view it generates always compiles.
- `AppMultiSelectInput` (`moarch create widget multi-select`) —
  `AppDropdownInput`'s plural: the same id/label entity list, any number
  selected, ticked in the search sheet with a per-row checkbox and a Done
  button. Shows its picks as removable chips, as labels, or as "3 selected";
  enforces `required`, `minSelected` and `maxSelected`, and stops the unticked
  rows at the ceiling rather than letting the form refuse the pick afterwards.
- `SearchPickerSheet.showMulti(...)` — the multi-select half of the sheet the
  dropdown and the country picker already open. It works on its own copy of the
  selection, so a dismissed sheet changes nothing and an empty result is a
  deliberate "none of them".
- `AppDateRangeInput` (`moarch create widget date-range-input`) — a read-only
  field holding a start and an end date, with a `maxDays` rule the picker itself
  cannot express. It holds a `DateTimeRange` rather than the text of one.
- `AppFilePickerField` (`moarch create widget file-input`) — an attachment
  field: an area that opens whichever picker the app already uses, and a row per
  file with a thumbnail, a readable size and a remove button. It imports no
  picker package, so it costs the project no dependency it had not already
  chosen.
- `AppRating` (`moarch create widget rating`) — stars both ways round: tappable
  with `onChanged`, a read-only score without it. Halves come from tapping the
  left half of a star, and a display-only rating stays out of `Form.validate()`.
- `AppTabs` / `AppTabBar` (`moarch create widget tabs`) — `AppTabs` owns the
  controller and puts the views under the bar, replacing it when the tab count
  changes; `AppTabBar` is the `PreferredSizeWidget` half that drops into
  `AppAppBar`'s `bottom` slot. Underline or pill indicator.
- `AppDrawer` (`moarch create widget drawer`) — the side menu, reading
  `AppBottomNav`'s destination list, with header and footer slots. It closes
  itself after a pick, and does nothing when the same widget is pinned beside
  the content instead.
- `AppNavRail` and `AppAdaptiveNav` (`moarch create widget nav-rail`) — the
  vertical navigation a tablet shows instead of a bottom bar, and the scaffold
  that picks between them off the 600dp short-side breakpoint. All three nav
  widgets read one `AppNavDestination` list.
- `AppFab` (`moarch create widget fab`) — the screen's floating action,
  circular or extended off one parameter, wearing `AppButtonVariant` /
  `AppButtonType` rather than a vocabulary of its own. `isLoading` swaps the
  icon for a spinner without resizing the button, and `heroTag` is exposed for
  the two-FABs-on-one-screen case.
- `AppTimeline` (`moarch create widget timeline`) — a vertical sequence of
  events joined by a connector, with done/current/pending/failed nodes.
  `AppTimeline.entryBuilder` hands you one row for a lazy list.
- `AppCarousel` (`moarch create widget carousel`) — swipeable pages with
  stretching dots, optional peek and auto-advance. The timer stops for good on
  the first swipe and never starts when the platform asks for reduced motion;
  `AppCarouselDots` is usable on its own.

### Improvements

- The design-system preview covers `AppPhoneInput` and `AppAsyncView` — the
  phone field has been in the kit since 2.4.0 without a preview, and the async
  view's four states are steppable in it. A new test fails if a widget joins the
  catalog without either a preview section or an explicit, reasoned exemption,
  so the screen can no longer fall behind the kit unnoticed.
- `moarch create feature` records what it writes into `shared/widgets/` in
  `.moarch.yaml`, so `moarch update` can tell those files apart from ones you
  have since edited.

## 2.4.0

### Features

- `AppPhoneInput` (`moarch create widget phone-input`) — a phone field that
  masks what is typed for the country it is set to, with a searchable country
  picker in its prefix. The field holds only the national number, so the
  calling code cannot be typed twice or deleted; read the joined-up value from
  `AppPhoneNumber.e164`. Changing country re-masks the existing digits rather
  than clearing them.
- `AppCountry` (`moarch create widget country`) — a table of 238 countries with
  ISO code, calling code and every mask their numbering plan allows. Plans with
  more than one shape are kept as a list, so the mask widens as the number grows
  (Hungary 8–9 digits, Germany 10–13), and validation holds a number to those
  exact lengths instead of a 7-to-15 range. Flags are derived from the ISO code,
  so no assets ship with it.
- `SearchPickerSheet` (`moarch create widget search-sheet`) — a bottom sheet
  that picks one row out of a long list, with a search field above it. Opens
  scrolled to the current selection.
- `AppDropdownInput` — swaps the menu for that sheet once the list passes
  `AppInputConfig.searchableThreshold` (30), which `searchable: true`/`false`
  overrules per field. Both forms now validate: `required: true` is enforced by
  `Form.validate()` rather than only marking the label, and `validator` /
  `autovalidateMode` work as they do on `AppInput`. Also gains `onSelected`
  (the picked entity, not just its id), `onCleared` (which puts a clear button
  in the field), and the sheet's `leadingOf`, `trailingLabelOf`, `filter` and
  `emptyLabel`.
- `moarch update` — refreshes generated UI-kit widgets against the current
  templates. Files you never touched are refreshed automatically; files you
  edited are listed, diffed and left alone unless you pass `--force`.
- `.moarch.yaml` — a manifest written by `init` and `create widget` recording
  the moarch version, the selected stack and a hash of every generated file.
  It is what lets `update` tell an untouched file from an edited one.
- `moarch doctor --fix` — applies the fixes that don't need a decision.

### Fixes

- `AppDateInput` / `AppTimeInput` showed nothing without a caller-supplied
  controller: every value, `initialValue` and each picked one alike, was written
  only to `widget.controller?.text`. They now own a controller when none is
  passed (and dispose it), so the simplest possible usage displays its value.
  A controller that already holds text is no longer overwritten by
  `initialValue` either — the caller's value wins, as it does on `AppInput`.
- `required: true` on `AppDateInput` and `AppTimeInput` only drew an asterisk;
  `Form.validate()` passed an empty field. Both now validate, and take a
  `validator` / `autovalidateMode` like the rest of the family.
- `AppLoadingActionOverlay` started its message timers only on a false-to-true
  change, so a screen that mounted with a request already in flight showed a
  bare spinner forever. They now start in `initState` too.
- `AppSegmented` and `AppChoiceChip` drew their selected foreground in
  `colorScheme.surface`, which is only the right answer in a light theme. Both
  now use the new `AppInputStyle.onAccentOf`, which `AppCheckbox` and
  `AppSwitch` share.

### Improvements

- Selection controls validate. `AppCheckboxLabel(required: true)` is the
  "accept the terms" checkbox a `Form` can enforce, and
  `AppRadioGroup(required: true)` refuses to validate until one option is
  chosen. Both render the error under the control through the new
  `SelectionFormField`, which is exposed for wrapping any control of your own.
- `AppSegmented` and `AppRadioGroup` assert that the current selection is
  actually one of the options, instead of silently rendering with nothing
  highlighted.
- `AppCheckboxLabel`, `AppRadioGroup`, `AppSegmented` and `AppChoiceChip` all
  take a null callback to disable themselves, matching `AppCheckbox`,
  `AppSwitch`, `AppSlider` and `AppStepper`. `AppDateInput` and `AppTimeInput`
  gain `enabled` alongside their existing `readOnly`.
- `AppStepper`'s − and + carry tooltips and semantics, and meet the 48px
  minimum tap target.

- `moarch doctor` now checks what the scaffold actually depends on: whether
  `build_runner` has generated `app_env.g.dart`, whether both localization
  approaches ended up installed, whether every generated widget's
  dependencies and pub packages are present, and whether router-dependent
  widgets have a router. Findings carry hints, and say which are fixable.

## 2.3.0

### Features

- `AppPhoneInput` (`moarch create widget phone-input`) — a phone field that
  masks what is typed for the country it is set to, with a searchable country
  picker in its prefix. The field holds only the national number, so the
  calling code cannot be typed twice or deleted; read the joined-up value from
  `AppPhoneNumber.e164`. Changing country re-masks the existing digits rather
  than clearing them.
- `AppCountry` (`moarch create widget country`) — a table of 238 countries with
  ISO code, calling code and every mask their numbering plan allows. Plans with
  more than one shape are kept as a list, so the mask widens as the number grows
  (Hungary 8–9 digits, Germany 10–13), and validation holds a number to those
  exact lengths instead of a 7-to-15 range. Flags are derived from the ISO code,
  so no assets ship with it.
- `SearchPickerSheet` (`moarch create widget search-sheet`) — a bottom sheet
  that picks one row out of a long list, with a search field above it. Opens
  scrolled to the current selection.
- `AppDropdownInput` — swaps the menu for that sheet once the list passes
  `AppInputConfig.searchableThreshold` (30), which `searchable: true`/`false`
  overrules per field. Both forms now validate: `required: true` is enforced by
  `Form.validate()` rather than only marking the label, and `validator` /
  `autovalidateMode` work as they do on `AppInput`. Also gains `onSelected`
  (the picked entity, not just its id), `onCleared` (which puts a clear button
  in the field), and the sheet's `leadingOf`, `trailingLabelOf`, `filter` and
  `emptyLabel`.
- `moarch update` — refreshes generated UI-kit widgets against the current
  templates. Files you never touched are refreshed automatically; files you
  edited are listed, diffed and left alone unless you pass `--force`.
- `.moarch.yaml` — a manifest written by `init` and `create widget` recording
  the moarch version, the selected stack and a hash of every generated file.
  It is what lets `update` tell an untouched file from an edited one.
- `moarch doctor --fix` — applies the fixes that don't need a decision.

### Fixes

- `AppDateInput` / `AppTimeInput` showed nothing without a caller-supplied
  controller: every value, `initialValue` and each picked one alike, was written
  only to `widget.controller?.text`. They now own a controller when none is
  passed (and dispose it), so the simplest possible usage displays its value.
  A controller that already holds text is no longer overwritten by
  `initialValue` either — the caller's value wins, as it does on `AppInput`.
- `required: true` on `AppDateInput` and `AppTimeInput` only drew an asterisk;
  `Form.validate()` passed an empty field. Both now validate, and take a
  `validator` / `autovalidateMode` like the rest of the family.
- `AppLoadingActionOverlay` started its message timers only on a false-to-true
  change, so a screen that mounted with a request already in flight showed a
  bare spinner forever. They now start in `initState` too.
- `AppSegmented` and `AppChoiceChip` drew their selected foreground in
  `colorScheme.surface`, which is only the right answer in a light theme. Both
  now use the new `AppInputStyle.onAccentOf`, which `AppCheckbox` and
  `AppSwitch` share.

### Improvements

- Selection controls validate. `AppCheckboxLabel(required: true)` is the
  "accept the terms" checkbox a `Form` can enforce, and
  `AppRadioGroup(required: true)` refuses to validate until one option is
  chosen. Both render the error under the control through the new
  `SelectionFormField`, which is exposed for wrapping any control of your own.
- `AppSegmented` and `AppRadioGroup` assert that the current selection is
  actually one of the options, instead of silently rendering with nothing
  highlighted.
- `AppCheckboxLabel`, `AppRadioGroup`, `AppSegmented` and `AppChoiceChip` all
  take a null callback to disable themselves, matching `AppCheckbox`,
  `AppSwitch`, `AppSlider` and `AppStepper`. `AppDateInput` and `AppTimeInput`
  gain `enabled` alongside their existing `readOnly`.
- `AppStepper`'s − and + carry tooltips and semantics, and meet the 48px
  minimum tap target.

- `moarch doctor` now checks what the scaffold actually depends on: whether
  `build_runner` has generated `app_env.g.dart`, whether both localization
  approaches ended up installed, whether every generated widget's
  dependencies and pub packages are present, and whether router-dependent
  widgets have a router. Findings carry hints, and say which are fixable.

## 2.2.2

### Features

- widget adjustments

## 2.2.1

### Features

- input config

## 2.2.0

### Features

- input formatters, extensions, validation service refactor

## 2.1.1

### Features

- added return on listen if loading

## 2.1.0

### Features

- added return on listen if loading

## 2.0.3

### Features

- widget catalog adjustment

## 2.0.2

### Features

- widget catalog

## 2.0.1

### Features

- bug fixes

## 2.0.0

### Features

- UI kit, UX improvements, app theme improvements

## 1.8.10

### Features

- biometric service

## 1.8.9

### Features

- checkbox, confirmDialog

## 1.8.8

### Features

- button style

## 1.8.7

### Features

- override in entity for ==

## 1.8.6

### Features

- input size and textAlign

## 1.8.5

### Features

- input type and variant

## 1.8.4

### Features

- notifications tap handling reaches flutter

## 1.8.3

### Features

- copy with for entitys

## 1.8.2

### Features

- added splash for loading

## 1.8.1

### Features

- added flags for datasource

## 1.8.0

### Features

- deps for gradle and other fixes

## 1.7.11

### Features

- main file fix

## 1.7.10

### Features

- Podfile

## 1.7.9

### Features

- easy_localization option (mutually exclusive with flutter_localizations)
- ios/Runner/Info.plist auto-patched: CFBundleLocalizations for localization
  options, camera/photo library/microphone usage descriptions for the media
  service, LSApplicationQueriesSchemes for the URL launcher, and
  UIBackgroundModes (fetch, remote-notification) for Firebase push
  (existing keys are never overwritten; rolled back on failure)
- ios/Runner/AppDelegate.swift auto-patched: UNUserNotificationCenter
  delegate wiring for the local notifications service (skipped when already
  present or customized; rolled back on failure)
- Firebase push generates Runner.entitlements + RunnerProfile.entitlements
  (aps-environment), and the build_ipa workflow signs the archive with them
- any Firebase option generates add_files_to_xcode.rb at the project root;
  build_ipa registers GoogleService-Info.plist in the Xcode project before
  compiling
- docs templates rewritten/corrected: GENERATE_JKS_FILE and
  STEPS_FOR_WORKFLOW are proper markdown (kts imports, secrets table, FCM
  push steps); security checklist pinning + logger examples fixed

## 1.7.8

### Features

- easy_localization option (mutually exclusive with flutter_localizations)

## 1.7.7

### Fixes

- firebase notifications

## 1.7.6

### Fixes

- notifier action

## 1.7.5

### Fixes

- ACESSABILITY FIXES

## 1.7.4

### Fixes

- WORFLOW ADJUSTMENTS

## 1.7.3

### Fixes

- WORFLOW ADJUSTMENT

## 1.7.2

### Fixes

- ADJUSTMENTS

## 1.7.1

### Fixes

- APP IMAGE ADJUSTMENT

## 1.7.0

### Fixes

- ADJUSTMENTS AND BUG FIXES

## 1.6.9

### Fixes

- FIXES

## 1.6.8

### Fixes

- Deploy workflow fix

## 1.6.7

### Fixes

- Router fixes

## 1.6.6

### Fixes

- Parent Provider

## 1.6.5

### Fixed

Found by actually running `moarch init --all` + `moarch create feature --all` against a real `flutter create` project and checking `flutter pub get` / `flutter analyze` — several of these meant the documented quick-start flow didn't compile out of the box.

- **`PubspecUtils._ensureSection` corrupted `pubspec.yaml`.** It misread the nested `sdk: flutter` line under `flutter:` (present in every `flutter create` project) as the end of the `dependencies:` section, so all new dependencies were inserted in the wrong place and produced a duplicate YAML key that made `flutter pub get` fail outright.
- Generated `app_router.dart` referenced an undefined `authNotifierProvider` and `AppRoutes.login` (which is commented out by default) — a fresh `moarch init --all` project never compiled. The auth-guard redirect is now documented as an opt-in commented example instead of active code.
- Generated `dio_client.dart` referenced `AppEnv.prodBaseUrl` / `AppEnv.devBaseUrl`, which don't exist on the generated `AppEnv` (only `baseUrl` does).
- Generated `safe_api_call.dart` had a stray `~` character right after the opening string literal, which was a syntax error.
- Generated `connectivity_service.dart` imported a garbled path (`core/utils/appappLogger.iger.dart`) and called an undefined top-level `log()` instead of `appLogger`.
- Generated `media_service.dart` called `FilePicker.pickFiles(...)` statically; `pickFiles` is an instance method on `FilePicker.platform`.
- Generated use case (`get_<name>.dart`) imported a `core/usecases/usecase.dart` base class that is never generated anywhere, and its import path to `repository_impl.dart` had one extra `../`. Use cases are now self-contained (no missing base class) with corrected import depth.
- Generated repository interface/impl never declared the `getAll()` method that the generated use case called against it.
- Generated notifier (`<name>_notifier.dart`) only imported the repository provider when "Use Cases" was _not_ selected, so `authRepositoryProvider` was undefined whenever use cases were included (the notifier's `_repo` getter needs it either way).
- Generated `<name>_remote_datasource.dart` called `safeApiCall` without importing the file that defines it.
- `create feature <name>` with the "Local/Cache Datasource" layer selected wrote the connectivity service to the wrong path and passed the wrong variable name into the generated datasource (swapped arguments).
- Generated `AppImage` widget had a syntax error (`?.isValidUrl != null` with no receiver).
- Generated `AppAvatar` / `AppImage` widgets checked a method tear-off instead of calling `isValidUrl()`, so an invalid URL was never actually detected.

### Added

- CI workflow (`dart analyze`, `dart format --set-exit-if-changed`, `dart test`, `dart pub publish --dry-run`) on push/PR to `main`.
- `moarch doctor` command to sanity-check an existing scaffolded project.
- `--dry-run` flag on `moarch init` to preview generated files without writing them.
- `--verbose` flag to print stack traces on unexpected errors.
- Per-item descriptions and a quit option (`q`) in the interactive checklist prompt.
- Real dark theme (`AppTheme.dark`) instead of an empty stub, with matching dark color tokens in `AppConstants`.
- Dark-mode variant in the generated `flutter_native_splash.yaml`.

### Changed

- `init` and `create feature`/`create model` now roll back files they created if scaffolding fails partway through, instead of leaving the target project in a half-generated state. `init` also restores the original `pubspec.yaml` on failure.
- CLI version string is now read from a single source (`lib/src/version.dart`) instead of being hardcoded in `runner.dart`.

### Known gaps (not addressed this round — out of scope)

- The generated `test/test_helper.dart` references `mocktail`, which isn't declared as a dependency, so it doesn't compile as-is. Left untouched since testing scaffolding is handled by the separate `mogen_unit_tests`/`mogen_integration_tests` packages.

## 1.6.4

### UPDATE

- FIXES

## 1.6.3

### UPDATE

- ERROR MANAGEMENT

## 1.6.2

### UPDATE

- FIXED GO ROUTER

## 1.6.1

### UPDATE

- ADJUSTMENTS

## 1.6.0

### UPDATE

- NEW WORKFLOWS

## 1.5.14

### UPDATE

- REDIRECT IN GO ROUTER

## 1.5.13

### UPDATE

- NEW FEATURES

## 1.5.12

### UPDATE

- FIXED WORKFLOW

## 1.5.11

### UPDATE

- FIXED EMPTY GENERATION

## 1.5.10

### UPDATE

- FIXED EMPTY GENERATION

## 1.5.9

### UPDATE

- Readme

## 1.5.8

### UPDATE

- GENERATE model.EMPTY() for the whole project

## 1.5.7

### UPDATE

- GENERATE model.EMPTY() for the whole project

## 1.5.6

### UPDATE

- FIXES

## 1.5.5

### UPDATE

- SAFE API CALL

## 1.5.4

### UPDATE

- SAFE API CALL

## 1.5.3

### UPDATE

- STATE IMPORT IN VIEW

## 1.5.2

### UPDATE

- NEW CREATE COMMAND FOR MODEL

## 1.5.1

### UPDATE

- WORKFLOWS, JKS FILE INSTRUCTIONS

## 1.5.0

### UPDATE

- FIX FINAL ISSUES

## 1.4.15

### UPDATE

- NATIVE SPLASH SCREEN ADDED

## 1.4.14

### UPDATE

- CORRECT USE OF FLUTTER_LOCALIZATIONS, FLUTTER LINTS, PUBSPEC FIX

## 1.4.13

### UPDATE

- CORRECT USE OF FLUTTER_LOCALIZATIONS

## 1.4.12

### UPDATE

- CORRECT USE OF FLUTTER_LOCALIZATIONS

## 1.4.11

### UPDATE

- CORRECT USE OF FLUTTER_LOCALIZATIONS

## 1.4.10

### UPDATE

- FIX ERRORS

## 1.4.9

### UPDATE

- MORE COMPLEXT NOTIFICATIONS

## 1.4.8

### UPDATE

- FIX FILES

## 1.4.7

### UPDATE

- CREATING PUBSPEC WITH DEPS. FIX SOME OUTPUTS AND MINOR ERRORS. ADDED NOTIFICATIONS SERVICE AND LOCALIZATION CONFIG. README UPDATED

## 1.4.6

### UPDATE

- SKELETONIZER FOR LOADING

## 1.4.5

### UPDATE

- COMBINED WORKFLOW FOR PROD PIPELINE

## 1.4.4

### UPDATE

- HELPER IN CORE FOLDER

## 1.4.3

### UPDATE

- APP AVATAR and APP IMAGE AND GENERAL FIXES

## 1.4.2

### ADDED

- NEW SERVICES AND HELPERS

### ADJUSTMENTS

- PACKAGE FOLDER SEPARATION, SOME CORE ADJUSTMENTS

## 1.4.1

### ADDED

- ANALYSIS OPTIONS

## 1.4.0

### ADDED

- ANALYSIS OPTIONS

## 1.3.12

### ADJUSTMENTS

- TESTS REMOVED, CORE AND CONFIG NEW THINGS

## 1.3.11

### Fix

- STATIC ANALYSIS

## 1.3.10

### Fix

- STATIC ANALYSIS

### Added

- Example file

## 1.3.9

- added: documentation - public api

## 1.3.8

- added: documentation - public api

## 1.3.7

- fix: some ui adjustments. feat: 2 new security workflows. refactor: logger name for easy import

## 1.3.6

- feat: security checklist, loading action with messages

## 1.3.5

- feat: retry for dio

## 1.3.4

- fix: input, validation and dio adjustments

## 1.3.3

- fix: validation service

## 1.3.2

- feat: validation service (security)

## 1.3.1

- fix: throw app exception when this is private

## 1.3.0

- feat: media, urllauncher, connectivity service. firebase providers. option list on init command

## 1.2.3

- fix: app loading data for view

## 1.2.2

- fix: tests notifier

## 1.2.1

- fix: tests notifier

## 1.2.0

- fix: readme. fix: tests

## 1.1.20

- fix: readme. feat: simplifing tests using moktail

## 1.1.19

- fix: readme

## 1.1.18

- fix: imports

## 1.1.17

- fix: dio status code, test throws

## 1.1.16

- feat: flags for both unit and integration tests

## 1.1.15

- fix: imports, and other errors

## 1.1.14

- feat: hint, and icons for dropdown

## 1.1.13

- update: readme

## 1.1.12

- feat: text theme and loading action overlay

## 1.1.11

- feat: continue on error for integration pipeline, and dont block merge if warnings on analyze

## 1.1.10

- feat: logs, and error management

## 1.1.9

- feat: user interaction if want tests or not

## 1.1.8

- fix: imports on design system, wrong color on app theme. tests adjustments

## 1.1.7

- feat: separate the tests by folder

## 1.1.6

- fix: imports, and create command

## 1.1.5

- fix: not creating the integration test

## 1.1.4

- feat: flag for tests, fix: imports on test file

## 1.1.3

- feat: unit tests and integration tests (beta)

## 1.1.2

- feat: design system for preview, refactor: hint to hintText

## 1.1.1

- remove: hint style

## 1.1.0

- fix: colors, theme, sizes

## 1.0.15

- feat: new inputs (date, time, dropdown), new time extension. fix: minor bugs

## 1.0.14

- feat: app exception from dio error. fix: brightness on theme data

## 1.0.13

- feat: prod checklist file for better app development

## 1.0.12

- fix: readme

## 1.0.11

- fix: envied file and readme

## 1.0.10

- feat: new env package for security

## 1.0.9

- fix: readme

## 1.0.8

- feat: router

## 1.0.7

- fix: colors

## 1.0.6

- fix: input theme label

## 1.0.5

- fix: theme and constants

## 1.0.4

- fix: dio config

## 1.0.3

- fix: import in view and param in error view

## 1.0.2

- fix: input and btn the size of touch target

## 1.0.1

- feat: transparent type on btn, palette section for constants, theme light has brightness. refactor: error view for optional message.

## 1.0.0

- fix: shared widget import

## 0.1.9

- fix: view widget builder

## 0.1.8

- fix: model to entity -> from entity, refactor: some of the widgets folder structure and files

## 0.1.7

- fix: shared import

## 0.1.6

- fix: Notifier fixed import

## 0.1.5

- fix: Model cant be empty, AppInput missing app constants and wrong construct, on notifier fixed import

## 0.1.4

- fix: Model not writting, remove routepath from view. feat: added repo in notifier. refactor: removed abstract datasources for simplicity

## 0.1.3

- fix: Dio client, and create command checklist

## 0.1.2

- fix: AppButton imports and using wrong constants
- Added AppInput

## 0.1.1

- Readme adjustments

## 0.1.0

- Initial release

## 0.0.1

- TODO: Describe initial release.
