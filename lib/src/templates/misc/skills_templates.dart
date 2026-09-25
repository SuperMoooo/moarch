import '../../utils/state_management.dart';

/// The procedures a coding agent follows for the tasks it gets asked most.
///
/// `AGENTS.md` states the rules; a skill is the step-by-step for one task —
/// add a feature, add an action, add an env key — with the moarch command
/// that starts it and the files it has to reach. Agents load a skill's body
/// only when its description matches the task, so this is where the detail
/// lives that would make `AGENTS.md` too long to read on every turn.
///
/// Each skill is written once, to `.agents/skills/<name>/SKILL.md`: the
/// directory Codex, Cursor, Gemini CLI and Copilot read. Claude Code reads
/// only `.claude/skills/`, so it gets [claudeSkill] — the same name and
/// description over a pointer to the `.agents` copy, the way `CLAUDE.md`
/// imports `AGENTS.md` — rather than a second body that drifts.
abstract final class SkillsTemplates {
  /// Every skill a project ships, in the order `AGENTS.md` lists them.
  static const List<AgentSkill> all = [
    AgentSkill._(
      'add-feature',
      'Add a new feature to this moarch Flutter project — a screen backed by '
          'its own data. Scaffolds every layer with `moarch create feature`, '
          'then fills in the model, the data layer, the state and the screen. '
          'Use when asked to add a feature, module, section or screen that '
          'needs its own data.',
    ),
    AgentSkill._(
      'add-endpoint',
      'Add or change a backend call in this moarch project: the datasource '
          'method, the repository interface and its implementation. Use when '
          'a feature needs to fetch, create, update or delete something it '
          'does not yet reach.',
    ),
    AgentSkill._(
      'add-action',
      'Add a user action to an existing screen in this moarch project — a '
          'save, delete, submit, refresh or toggle — through the state '
          "holder's runAction, with its loading, toast and navigation. Use "
          'when a button or gesture has to do something.',
    ),
    AgentSkill._(
      'add-model',
      'Add or change a freezed model in this moarch project, from a sample '
          'JSON payload or by hand, and regenerate its code. Use when a '
          'feature needs a new data type or a field added, renamed or '
          'retyped.',
    ),
    AgentSkill._(
      'build-screen',
      'Build or change a screen in this moarch project from the UI kit and '
          'design tokens, with its skeleton, its route and its strings. Use '
          'for any UI work: a new view, a layout change, a widget, a sheet or '
          'a dialog.',
    ),
    AgentSkill._(
      'add-env-key',
      'Add a configuration value or secret (API key, URL, feature flag) to '
          'this moarch project through .env and AppEnv. Use whenever code '
          'needs a value that differs per environment or must not be '
          'committed.',
    ),
    AgentSkill._(
      'write-tests',
      'Write or update tests in this moarch project: generate them with '
          '`moarch create tests`, then complete them. Use when asked for '
          'tests, after adding a state-holder method or an endpoint, or when '
          'a generated test fails.',
    ),
    AgentSkill._(
      'update-scaffold',
      "Refresh this project's moarch-generated files against newer moarch "
          'templates and fix what `moarch doctor` reports, without losing '
          'local edits. Use when asked to update moarch, sync the scaffold, '
          'or when a generated file looks out of date.',
    ),
    AgentSkill._(
      'review',
      "Review a change in this moarch project against the project's "
          'architecture rules (layers, state, DI, UI kit, tokens, codegen) '
          'and report every violation with file and line. Use when asked to '
          'review a diff, a branch or a PR, and before calling your own '
          'change done.',
    ),
  ];

  /// The skill named [slug] (`add-feature`), or `null`.
  static AgentSkill? bySlug(String slug) {
    for (final skill in all) {
      if (skill.slug == slug) return skill;
    }
    return null;
  }

  /// Returns `.agents/skills/<name>/SKILL.md` for [skill].
  static String skill(AgentSkill skill, SkillOptions o) {
    final body = switch (skill.slug) {
      'add-feature' => _addFeature(o),
      'add-endpoint' => _addEndpoint(o),
      'add-action' => o.bloc ? _addActionBloc(o) : _addActionRiverpod(o),
      'add-model' => _addModel(o),
      'build-screen' => _buildScreen(o),
      'add-env-key' => _addEnvKey(o),
      'write-tests' => _writeTests(o),
      'update-scaffold' => _updateScaffold(),
      'review' => _review(o),
      _ => throw ArgumentError.value(skill.slug, 'skill', 'unknown skill'),
    };
    return '${_frontmatter(skill)}\n$body';
  }

  /// Returns `.claude/skills/<name>/SKILL.md` for [skill]: the name and
  /// description Claude Code matches on, over a pointer to the one body in
  /// `.agents/skills/`.
  static String claudeSkill(AgentSkill skill) =>
      '''
${_frontmatter(skill)}
Read `${skill.agentsPath}` and follow it.

<!-- The steps live in .agents/skills/, which every other coding agent reads;
     Claude Code only looks in .claude/skills/, so this file points there.
     Both are generated by moarch — `moarch update ai` refreshes them, and
     never overwrites one you have edited. -->
''';

  /// Returns `.claude/settings.json`: the checks every change runs, allowed
  /// without a prompt, and the files the project's rules say never to touch,
  /// denied — so the rule is enforced rather than only stated.
  static String claudeSettings({required bool bloc}) =>
      '''
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(fvm flutter pub get)",
      "Bash(fvm flutter analyze *)",
      "Bash(fvm flutter test *)",
      "Bash(fvm dart format *)",
      "Bash(fvm dart run build_runner build *)",${bloc ? '\n      "Bash(bloc lint *)",' : ''}
      "Bash(moarch create widget --list)",
      "Bash(moarch update --list)",
      "Bash(moarch doctor)"
    ],
    "deny": [
      "Read(./.env)",
      "Edit(**/*.g.dart)",
      "Edit(**/*.freezed.dart)",
      "Edit(./.moarch.yaml)"
    ]
  }
}
''';

  /// Returns `.gemini/settings.json`, which points Gemini CLI at `AGENTS.md`
  /// — it reads only `GEMINI.md` unless told otherwise.
  static String geminiSettings() => '''
{
  "context": {
    "fileName": ["AGENTS.md", "GEMINI.md"]
  }
}
''';

  /// The `AGENTS.md` section listing the skills, for agents that do not
  /// discover them on their own.
  static String agentsMdSection() {
    final rows = [
      for (final skill in all)
        '| [`${skill.name}`](${skill.agentsPath}) | ${skill.summary} |',
    ].join('\n');
    return '''
## Skills

Step-by-step procedures for the common tasks live in `.agents/skills/`
(Claude Code: `.claude/skills/`, which point there). Agents that support
skills load them on their own; otherwise, read the matching `SKILL.md` before
starting the task.

| Skill | For |
|---|---|
$rows

Generic Flutter skills (for example `flutter-fix-layout-issues` from
`flutter/skills`) can be installed beside these. Where one disagrees with this
file — a ViewModel on `ChangeNotifier`, hand-written `fromJson`, `http`
instead of the project's client, a model-to-entity mapper — this file wins.
''';
  }

  static String _frontmatter(AgentSkill skill) =>
      '''
---
name: ${skill.name}
description: ${_yaml(skill.description)}
---
''';

  /// [value] as a double-quoted YAML scalar. A description holds `: ` and
  /// backticks, which a plain scalar cannot, and an agent that fails to parse
  /// the frontmatter drops the skill without a word.
  static String _yaml(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  /// The header every body opens with.
  static String _intro(String title) =>
      '''
# $title

Generated by moarch; `moarch update ai` refreshes it. Every rule in
`AGENTS.md` applies — this is the procedure, not a replacement for them.
''';

  static String _done(SkillOptions o) =>
      '''
## Done when

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```${o.bloc ? '\n\nand `bloc lint .` reports nothing new.' : ''}
''';

  static const _buildRunner =
      'fvm dart run build_runner build --delete-conflicting-outputs';

  // ── add-feature ────────────────────────────────────────────────────────────

  static String _addFeature(SkillOptions o) {
    final holder = o.bloc
        ? '`presentation/blocs/<name>_bloc.dart` (+ `_event`, `_state`), '
              '`presentation/pages/<name>_page.dart`'
        : '`presentation/notifiers/<name>_notifier.dart`, '
              '`presentation/states/<name>_state.dart`';
    final scaffold = o.withDio && o.withFirestore
        ? '''

   It asks which layers to generate on stdin. This project has both Dio and
   Firestore; the first item is the Dio datasource:

   ```bash
   echo | moarch create feature <name>              # Dio datasource
   printf '2\\n\\n' | moarch create feature <name>   # Firestore datasource
   ```'''
        : '''

   It asks which layers to generate on stdin; an empty line takes the
   defaults (remote datasource, repository, ${o.bloc ? 'bloc' : 'notifier'}, view):

   ```bash
   echo | moarch create feature <name>
   ```

   `--all` also adds a local cache datasource.''';
    final stateFields = o.bloc
        ? 'the constructor, `copyWith`, `props` and `placeholder`'
        : 'the constructor, `copyWith` (with `?? this.x`) and `placeholder`';
    return '''
${_intro('Add a feature')}
A feature is one folder under `lib/features/<name>/` with every layer in it.
If the feature already exists, use `moarch-add-endpoint`, `moarch-add-action`
or `moarch-build-screen` instead.

## Steps

1. **Scaffold it** — never create the folders by hand. `<name>` is
   snake_case (`order_history`).
$scaffold

   It writes `domain/models/<name>_model.dart`, the repository interface and
   implementation, the datasource(s), $holder and `presentation/views/<name>_view.dart`,
   and registers the data layer in `lib/config/di/data_module.dart`${o.bloc ? ' and the bloc\n   in `presentation_module.dart`' : ''} above `// moarch:registrations`.
   Read what it printed before going on.

2. **The model** — fields on `domain/models/<name>_model.dart`, then
   `$_buildRunner`. Follow `moarch-add-model`.

3. **The data layer** — the generated `fetchAll` implementation throws
   `UnimplementedError`, and the ${o.bloc ? 'bloc calls it on `Started`' : "notifier's `build` calls it"}, so the
   screen fails until it is written. Implement it, and any other call, with
   `moarch-add-endpoint`.

4. **The state** — add what the screen draws to the state class: $stateFields.
   ${o.bloc ? 'Set it in `_onStarted`.' : 'Return it from `build()`.'}
   `placeholder` needs *fake* values — it is what the skeleton is traced from.

5. **The screen** — `_body` in the view, from the UI kit. Follow
   `moarch-build-screen`${o.withRouter ? ', which also adds the route' : ''}.

6. **Actions** — every button that does something: `moarch-add-action`.

7. **Tests** — `moarch create tests <name>`, then `moarch-write-tests`.

${_done(o)}''';
  }

  // ── add-endpoint ───────────────────────────────────────────────────────────

  static String _addEndpoint(SkillOptions o) {
    final dio = o.withDio
        ? '''
**Dio.** Wrap the call in `safeApiCall` (`core/network/safe_api_call.dart`),
which turns every transport error into an `AppException`:

```dart
Future<List<OrderModel>> fetchAll() {
  return safeApiCall<List<OrderModel>>(
    apiCall: () async {
      final response = await _dio.get('/orders');
      return (response.data as List)
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    },
  );
}
```

The path is relative: the base URL is `AppEnv.baseUrl`, set on the client in
`core/network/`. Auth headers and refresh are the client's interceptors' job,
not the datasource's.
'''
        : '';
    final firestore = o.withFirestore
        ? '''
**Firestore.** Wrap the call in `safeFirebaseCall` (streams:
`safeFirebaseStream`) from `core/network/safe_firebase_call.dart`, and build
models with `Model.fromDoc(doc)` so the id comes from the document, not the
payload. A screen that shows a collection watches it (`watchAll`) rather
than fetching it once.
'''
        : '';
    final neither = !o.withDio && !o.withFirestore
        ? '''
The datasource is where the bytes come from. Whatever it calls, it throws only
`AppException` (`core/errors/`): catch the client's own errors there and
rethrow them as one.
'''
        : '';
    return '''
${_intro('Add a backend call')}
Three files, always in this order, all under `lib/features/<feature>/`.

## 1. The datasource — `data/datasources/<feature>_remote_datasource.dart`

$dio$firestore$neither
The datasource returns the feature's freezed model(s) from `domain/models/`.
There is no separate DTO and no mapper — if the payload has a shape the model
does not, change the model (`moarch-add-model`).

## 2. The interface — `domain/repositories/<feature>_repository.dart`

Add the method signature. `domain/` imports nothing from `data/`, no Flutter${o.withDio ? ', no\nDio' : ''}${o.withFirestore ? ', no Firebase' : ''}: it takes and returns models and plain Dart types only.

## 3. The implementation — `data/repositories/<feature>_repository_impl.dart`

Delegate to the datasource. If the feature has a local datasource, this is
where cache-then-network is decided. Do **not** catch here: the
`AppException` the datasource throws goes up to `runAction`, which shows it.

## After

- A new datasource or repository class (not a method) is registered in
  `lib/config/di/data_module.dart`, above `// moarch:registrations`.
- The state holder calls the new method — `moarch-add-action`.
${o.withDio ? '- `moarch create tests <feature>` adds an integration test for each GET a\n  Dio datasource makes; it calls the real API at `BASE_URL`.' : '- `moarch create tests <feature>` covers the state holder that calls it.'}

${_done(o)}''';
  }

  // ── add-action ─────────────────────────────────────────────────────────────

  static String _addActionRiverpod(SkillOptions o) =>
      '''
${_intro('Add an action (Riverpod)')}
An action is one notifier method run through `runAction`, and the view
calling it. The one-shot `error` / `success` fields on the state do the rest.

## Steps

1. **The call** — if it needs one the repository does not have yet, add it
   first with `moarch-add-endpoint`.

2. **The method** — on the notifier in
   `presentation/notifiers/<feature>_notifier.dart`:

   ```dart
   Future<void> deleteOrder(int id) {
     return runAction((current) async {
       await _repo.delete(id);
       return current.copyWith(
         orders: current.orders.where((o) => o.id != id).toList(),
         success: 'Order deleted',
       );
     });
   }
   ```

   `runAction` (`ActionNotifierMixin`) sets `isLoadingAction`, catches
   `AppException` into `error`, and hands you the state as it was before the
   action. Never write `try` / `catch` or `state = AsyncError(...)` here.

3. **The state** — a new field goes in the constructor, `copyWith` (with
   `?? this.x`) and `placeholder`. `error` and `success` are cleared by every
   `copyWith` on purpose: that is what makes a toast fire once.

4. **The view** — call it from a callback, never from `build`:

   ```dart
   AppButton(
     label: 'Delete',
     isLoading: state.isLoadingAction,
     onPressed: () =>
         ref.read(orderNotifierProvider.notifier).deleteOrder(order.id),
   )
   ```

   The toast comes from the `ref.listenAction(...)` already in the view. To
   navigate or close a sheet on success, pass `onSuccess:` to it — side
   effects go in the listener, not in `build` and not in the notifier.

5. **Tests** — `moarch create tests <feature>` picks up the new method; then
   `moarch-write-tests`.

${_done(o)}''';

  static String _addActionBloc(SkillOptions o) =>
      '''
${_intro('Add an action (Bloc)')}
An action is one event, one handler run through `runAction`, and the view
adding the event. The one-shot `errorMessage` / `successMessage` fields on the
state do the rest.

## Steps

1. **The call** — if it needs one the repository does not have yet, add it
   first with `moarch-add-endpoint`.

2. **The event** — in `presentation/blocs/<feature>_event.dart`, a
   `final class` in the sealed family, named for what happened:

   ```dart
   final class OrderDeleted extends OrderEvent {
     const OrderDeleted(this.id);

     final int id;

     @override
     List<Object?> get props => [id];
   }
   ```

3. **The handler** — in the bloc's constructor and body:

   ```dart
   on<OrderDeleted>(_onDeleted${o.blocConcurrency ? ', transformer: droppable()' : ''});

   Future<void> _onDeleted(OrderDeleted event, Emitter<OrderState> emit) =>
       runAction(emit, (current) async {
         await _repo.delete(event.id);
         return current.copyWith(
           orders: current.orders.where((o) => o.id != event.id).toList(),
           successMessage: 'Order deleted',
         );
       });
   ```

   `runAction` (`ActionBlocMixin`) moves the status to loading, catches
   `AppException` into `errorMessage`, and hands you the state as it was
   before. Never write `try` / `on AppException` in a handler.${o.blocConcurrency ? '\n   `transformer:` (bloc_concurrency) decides what a second tap does while the\n   first runs: `droppable()` ignores it, `restartable()` cancels the first\n   (`import \'package:bloc_concurrency/bloc_concurrency.dart\';`).' : ''}

4. **The state** — one `Equatable` class; a new field goes in the
   constructor, `copyWith`, `props` (or two states compare equal and the
   emit is dropped) and `placeholder`. Never split it into a sealed class per
   phase.

5. **The view** — add the event from a callback:

   ```dart
   onPressed: () => context.read<OrderBloc>().add(OrderDeleted(order.id)),
   ```

   The toast comes from the `BlocConsumer` listener already in the view. To
   navigate or close a sheet on success, extend that `listener` — never do it
   in `builder`.

6. **Another screen needs this bloc** — a pushed route, sheet or dialog
   cannot `context.read` it (they are siblings in the Navigator). Use
   `moarch create scope <feature> <name>` and pass the scope; never create a
   second instance. A second, independent bloc in the same feature is
   `moarch create bloc <feature> <name>`.

7. **Tests** — `moarch create tests <feature>` picks up the new event; then
   `moarch-write-tests`.

${_done(o)}''';

  // ── add-model ──────────────────────────────────────────────────────────────

  static String _addModel(SkillOptions o) =>
      '''
${_intro('Add or change a model')}
A feature's data type is the freezed model in `domain/models/`, used as-is by
the datasource, the repository, the state and the view. There is no entity
layer: never add `domain/entities/`, a DTO, or `toEntity()` / `fromEntity()`.

## A new model

With a sample payload (preferred — the fields come out real):

```bash
moarch create model <feature> <name> --from-json sample.json${o.withFirestore ? '\n# Firestore: add --doc when the type is a document root (gets fromDoc and the id)' : ''}
```

Write the sample to a temporary file first and delete it afterwards. Without
a sample, `moarch create model <feature> <name>` writes the skeleton and you
add the fields.

## Changing fields

- Fields live in the `const factory` constructor. Optional fields are
  nullable or have `@Default(...)`.
- Check `build.yaml`: with `field_rename: snake`, `createdAt` reads
  `created_at` already — only a key that does not follow the rule needs
  `@JsonKey(name: ...)`.
- A nested object is its own freezed model with `fromJson`; a list of them is
  `List<ItemModel>`.${o.withFirestore ? '\n- A `DateTime` stored in Firestore is annotated `@TimestampConverter()`\n  (`core/network/timestamp_converter.dart`).' : ''}
- Something the screen needs derived from the fields is a getter on the
  model (the `const Model._();` constructor allows members), not a second
  class.
- Keep the `.empty()` factory in step with the fields.
  `moarch create empty-factories <feature>` adds missing ones.

## Then

```bash
$_buildRunner
```

Never edit `*.freezed.dart` or `*.g.dart`; they are gitignored and
regenerated. Fix every state `placeholder` and test fixture the change broke.

${_done(o)}''';

  // ── build-screen ───────────────────────────────────────────────────────────

  static String _buildScreen(SkillOptions o) {
    final holderTarget = o.bloc ? 'page' : 'view';
    final route = o.withRouter
        ? '''

## The route

1. The path in `lib/config/router/app_routes.dart`. A path parameter gets a
   pattern constant plus an `…Of(id)` helper that builds the location, like
   `featureDetail` / `featureDetailOf`.
2. A `GoRoute` in `lib/config/router/app_router.dart` whose builder returns
   the $holderTarget${o.bloc ? ' (which provides the bloc)' : ''}.
3. Navigate with `context.go(AppRoutes.x)` / `context.push(...)` — never a
   raw string.
'''
        : '';
    final strings = o.withEasyLocalization
        ? '\n- Every user-facing string is a key in **every**\n  `assets/translations/*.json`, read with `\'key\'.tr()`.'
        : o.withLocalization
        ? '\n- Every user-facing string is a key in **every** `lib/l10n/app_*.arb`,\n  read with `AppLocalizations.of(context)`; `fvm flutter gen-l10n` after.'
        : '';
    final colors = o.withStatusColors
        ? '`Theme.of(context).colorScheme`, and `context.statusColors` for\n  success / warning / info'
        : '`Theme.of(context).colorScheme`';
    final newScreen = o.bloc
        ? 'a new screen in an existing feature gets its own bloc with\n'
              '`moarch create bloc <feature> <name>`, plus a `pages/<name>_page.dart` and\n'
              'a `views/<name>_view.dart` written like the feature\'s first pair'
        : 'a new screen in an existing feature gets a notifier + state written like\n'
              'the feature\'s first pair, in `notifiers/` and `states/`';
    return '''
${_intro('Build a screen')}
A screen is `presentation/views/<name>_view.dart` in its feature — or
`lib/shared/views/` when it belongs to no feature. A new feature starts with
`moarch-add-feature`; $newScreen.

## Building it

- **UI kit first.** Read `docs/UI_KIT.md`. Use `AppButton`, `AppInput`,
  `AppAppBar`, `AppToast`, `ErrorView`, `EmptyView`… over raw Material. A
  widget the kit lists but `lib/shared/widgets/` lacks is added with
  `moarch create widget <name>` (`--list` shows them) — never written from
  scratch.
- **Tokens, not numbers.** Spacing, padding, radii, icon sizes, durations,
  curves and shadows come from `AppConstants` (`space16`, `padding16`,
  `borderRadius12`, `duration300`, `curveStandard`, `shadowCard`…).
- **Theme, not colors.** Read $colors. A literal `Color` is a bug${o.withDarkTheme ? ' in one of\n  the two themes' : ''}.
- **One widget per file.** Split the screen into public widget classes, each
  in its own file in the feature's `presentation/widgets/`
  (`order_header.dart` → `OrderHeader`) — or `lib/shared/widgets/` for a
  screen in `lib/shared/views/`, or once a second feature needs it. Never a
  private `_Header` class in the view file, never a `Widget _buildHeader()`
  method. `const` wherever it compiles.
- **The skeleton.** The view draws `_body` from the real state and, while
  loading, from `XState.placeholder`. Every field `_body` reads needs a
  *fake* value there (`BoneMock.name`, `BoneMock.words(3)`) or it shimmers as
  a blank line.
- **Side effects** — toasts, navigation, dialogs — go in the ${o.bloc ? '`BlocConsumer`\n  `listener`' : '`ref.listenAction`\n  callbacks'}, never in `build`.$strings
- **Sheets and dialogs** use the kit's helpers.${o.bloc ? ' One that needs the screen\'s\n  bloc gets it through a scope (`moarch create scope <feature> <name>`), not\n  `context.read` and not a second instance.' : ''}
$route
## Layout errors

Constraints go down, sizes go up. An unbounded-height error is a scrollable
inside a `Column` (wrap it in `Expanded`); an overflow is a `Row` child that
needs `Flexible`/`Expanded` or text that needs `overflow:`. Fix the
constraint — never paper over it with a fixed `SizedBox` height.

${_done(o)}''';
  }

  // ── add-env-key ────────────────────────────────────────────────────────────

  static String _addEnvKey(SkillOptions o) =>
      '''
${_intro('Add an env key')}
Configuration reaches code through one class: `AppEnv`
(`lib/config/env/app_env.dart`, envied). Never read `.env` any other way,
never hard-code the value, never log it.

## Steps

1. **`.env`** (gitignored — ask the user for the real value, do not invent
   one) and **`.env.example`** (committed — the key with an empty or dummy
   value). Both get the key:

   ```
   PAYMENTS_KEY=
   ```

2. **`AppEnv`** — a field per key:

   ```dart
   @EnviedField(varName: 'PAYMENTS_KEY', obfuscate: true)
   static final String paymentsKey = _AppEnv.paymentsKey;
   ```

   `static final`, not `const`: an obfuscated value is decoded at runtime.

3. **Generate** — `$_buildRunner`.
   `app_env.g.dart` is gitignored; until it is generated the project does not
   analyze.${o.withWorkflows ? '''

4. **CI** — the workflows in `.github/workflows/` write `.env` from GitHub
   secrets before building. Add the key to every `cat <<EOF > .env` block, as
   `PAYMENTS_KEY=\${{ secrets.PAYMENTS_KEY }}`, and tell the user to create
   the secret.''' : ''}

${_done(o)}''';

  // ── write-tests ────────────────────────────────────────────────────────────

  static String _writeTests(SkillOptions o) {
    final widget = o.bloc
        ? '''
A view reads its bloc from context, so a widget test provides a mock:

```dart
class MockOrderBloc extends MockBloc<OrderEvent, OrderState>
    implements OrderBloc {}

await tester.pumpWidget(MaterialApp(
  home: BlocProvider<OrderBloc>.value(value: bloc, child: const OrderView()),
));
```'''
        : '''
A notifier reads its repository with `getIt<T>()`, so a widget test registers
a mock there and lets the real notifier run:

```dart
setUp(() => getIt.registerSingleton<OrderRepository>(repository));
tearDown(getIt.reset);

await tester.pumpWidget(
  const ProviderScope(child: MaterialApp(home: OrderView())),
);
```''';
    return '''
${_intro('Write tests')}
Generate first, then complete. The generator reads the project's own source,
so re-running it after adding methods is how the new ones get covered.

## Generate

```bash
moarch create tests [feature]      # --dry-run to preview
```

- `test/unit/` — one test file per ${o.bloc ? 'bloc and cubit' : 'notifier'}, with `mocktail`${o.bloc ? ' and\n  `bloc_test`' : ''}, mocking the repository **interface**.
${o.withDio ? '- `test/integration/` — one test per GET in each Dio datasource. These\n  call the real API at `BASE_URL` from `.env`.' : ''}

A generated test you edited is kept on the next run (`--force` overwrites
it — only when the user agrees).

## Complete

- Read each generated file and fill in what it marks `TODO`: fixtures built
  from the model's `.empty()` + `copyWith`, and the expected states.
- Test through the public surface: ${o.bloc ? 'events in, states out (`blocTest`)' : 'notifier methods in, state out'}.
  Cover the success path and the `AppException` path of every action.
- Mock the repository interface, never the `_impl` and never a datasource.

## Widget tests

$widget

${_done(o)}''';
  }

  // ── update-scaffold ────────────────────────────────────────────────────────

  static String _updateScaffold() =>
      '''
${_intro('Update the scaffold')}
`.moarch.yaml` records a hash of every file moarch generated, so `moarch
update` can tell an untouched file (refreshed silently) from one someone
edited (never overwritten without `--force`). Never edit `.moarch.yaml`.

## Steps

1. **Where things stand:**

   ```bash
   moarch --version
   moarch update --list          # every refreshable file, and its state
   moarch doctor                 # known problems, and which have a fix
   ```

   Upgrading moarch itself (`dart pub global activate moarch`) changes the
   user's machine — ask first.

2. **Preview** — `moarch update <name|group|all> --dry-run --diff`. Groups
   are listed by `--list` (`core`, `config`, `widgets`, `docs`, `ai`…).

3. **Refresh the untouched files** — `moarch update <name|group|all> -y`.
   Without `-y` it prompts, which an agent cannot answer.

4. **Edited files** are reported, not overwritten. For each: read the
   `--diff`, then either port the template's change into the edited file by
   hand, or — only if the user agrees to lose the edit — `--force` it.

5. **Fixes** — `moarch doctor --fix` applies the ones that need no decision.
   Report the rest to the user.

6. **After** — `fvm flutter pub get`, then
   `$_buildRunner`, then the checks below. A refreshed file can need
   imports or calls updated in code that uses it.

## Done when

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
```
''';

  // ── review ─────────────────────────────────────────────────────────────────

  static String _review(SkillOptions o) {
    final state = o.bloc
        ? '''
- [ ] Blocs import `package:bloc/bloc.dart`, never Flutter.
- [ ] Events are `final class`es in the sealed family, one per action.
- [ ] One `Equatable` state class with `AppStatus`; every field in the
      constructor, `copyWith`, `props` and `placeholder`.
- [ ] Every handler goes through `runAction`; no hand-written
      `try` / `on AppException`.
- [ ] Only pages touch `getIt`; views read the bloc from context.
- [ ] Side effects in the `BlocConsumer` `listener` (with `listenWhen`), not
      in `builder`.
- [ ] Blocs are `registerFactory` in `presentation_module.dart`, never
      singletons; no second instance of a bloc a screen already has — a scope
      carries it.'''
        : '''
- [ ] State holders are `AsyncNotifier`s with `ActionNotifierMixin`; every
      action goes through `runAction`; no `try` / `catch` or
      `state = AsyncError(...)`.
- [ ] Every state field in the constructor, `copyWith` and `placeholder`.
- [ ] `ref.watch` in `build`, `ref.read` in callbacks.
- [ ] Views draw through `AppAsyncView`; side effects in `ref.listenAction`,
      not in `build`.
- [ ] Notifiers are not registered in get_it.''';
    return '''
${_intro('Review a change')}
Read the diff (`git diff`, `git diff main...HEAD`, or the PR), then check it
against every item below. Report each violation as `path:line — rule — what
to do instead`, most serious first. Do not fix anything unless asked.

## Architecture

- [ ] No `domain/entities/`, DTOs, `toEntity()` / `fromEntity()`, or a class
      mirroring a model. No use-case classes.
- [ ] `domain/` imports no Flutter, no SDK client, nothing from `data/`.
- [ ] State holders depend on the repository **interface**, never a
      datasource or `*_repository_impl.dart`.
- [ ] Transport errors become `AppException` in the datasource; nothing
      catches and swallows, nothing shows a raw exception.
- [ ] New classes are registered in the right `lib/config/di/` module; the
      `// moarch:registrations` anchors are untouched.
- [ ] Config comes from `AppEnv`; `.env` is not committed, and a new key is
      in `.env.example` too.
- [ ] Files that should come from moarch (`create feature/model/widget/bloc`)
      were not written by hand.

## State

$state

## UI

- [ ] Built from `lib/shared/widgets/` before raw Material.
- [ ] No magic numbers — `AppConstants` tokens; no literal `Color`s.
- [ ] Private widget classes, not `_buildX()` methods; `const` where it
      compiles.
- [ ] Every field the view draws has a fake value in `placeholder`.${o.withLocalization || o.withEasyLocalization ? '\n- [ ] No hard-coded user-facing strings; every new key in every language.' : ''}

## Hygiene

- [ ] No edits to `*.g.dart`, `*.freezed.dart` or `.moarch.yaml`.
- [ ] Tests generated / updated for new state-holder methods and endpoints.
- [ ] `fvm dart format .`, `fvm flutter analyze` and `fvm flutter test`
      pass${o.bloc ? '; `bloc lint .` reports nothing new' : ''}.
''';
  }
}

/// One skill: its slug, and where its two files live.
class AgentSkill {
  const AgentSkill._(this.slug, this.description);

  /// Short name, e.g. `add-feature`.
  final String slug;

  /// What the skill is for and when to use it — what an agent matches a task
  /// against to decide whether to load the body.
  final String description;

  /// The skill's name, which is also its directory: `moarch-add-feature`.
  String get name => 'moarch-$slug';

  /// The first sentence of [description], for the `AGENTS.md` table.
  String get summary => description.split('. ').first;

  /// Where the skill's body lives, for every agent but Claude Code.
  String get agentsPath => '.agents/skills/$name/SKILL.md';

  /// Where Claude Code finds it: a pointer to [agentsPath].
  String get claudePath => '.claude/skills/$name/SKILL.md';
}

/// What a project has that changes what its skills say.
class SkillOptions {
  /// Creates the options.
  const SkillOptions({
    required this.stateManagement,
    this.withDio = false,
    this.withFirestore = false,
    this.withRouter = false,
    this.withLocalization = false,
    this.withEasyLocalization = false,
    this.withDarkTheme = false,
    this.withStatusColors = false,
    this.withWorkflows = false,
    this.blocConcurrency = false,
  });

  /// Riverpod or bloc.
  final StateManagement stateManagement;

  /// The project talks to a REST API through Dio.
  final bool withDio;

  /// Features may keep their data in Firestore.
  final bool withFirestore;

  /// The GoRouter setup was generated.
  final bool withRouter;

  /// flutter_localizations (`.arb`) is installed.
  final bool withLocalization;

  /// easy_localization (JSON assets) is installed.
  final bool withEasyLocalization;

  /// The app has a dark theme.
  final bool withDarkTheme;

  /// `AppStatusColors` exists, read as `context.statusColors`.
  final bool withStatusColors;

  /// The GitHub Actions workflows were generated.
  final bool withWorkflows;

  /// `bloc_concurrency` is installed, so a handler may use `droppable()`.
  final bool blocConcurrency;

  /// Whether the project uses flutter_bloc.
  bool get bloc => stateManagement.isBloc;
}
