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
  ///
  /// The first one is how a project is recognised as having the skills
  /// (`ScaffoldContext.hasAgentSkills`), so a new skill goes after it.
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
      'plan-feature',
      'Plan a feature in this moarch project before any code is written, by '
          'interviewing the user until every decision is settled. Asks about '
          'the data, the screens and their states, the actions, the route and '
          'the platform needs in rounds, each question with a recommended '
          'answer, then lists the moarch commands and skills that build it. '
          'Use only when the user asks to plan, scope, design or be grilled '
          'on a feature — never for a change that is already specified.',
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
      'fix-bug',
      'Find and fix a bug in this moarch project by reproducing it first. '
          'Finds the layer that owns the symptom, writes a test or a command '
          'that fails because of it, fixes the cause there and keeps the '
          'test. Use when something is broken, throws, shows the wrong data '
          'or state, or fails for a reason that is not obvious.',
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
      'plan-feature' => _planFeature(o),
      'add-endpoint' => _addEndpoint(o),
      'add-action' => o.bloc ? _addActionBloc(o) : _addActionRiverpod(o),
      'add-model' => _addModel(o),
      'build-screen' => _buildScreen(o),
      'add-env-key' => _addEnvKey(o),
      'write-tests' => _writeTests(o),
      'fix-bug' => _fixBug(o),
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

Generic skills can be installed beside these: Flutter ones (for example
`flutter-fix-layout-issues` from `flutter/skills`) and process ones (for
example `grill-me`, `domain-modeling` and `handoff` from `mattpocock/skills`).
Where one disagrees with this file — a ViewModel on `ChangeNotifier`,
hand-written `fromJson`, `http` instead of the project's client, a
model-to-entity mapper, dropping a repository interface because it has one
implementation — this file wins.
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
   defaults (remote datasource, ${o.withLocalCache ? 'local cache datasource, ' : ''}repository, ${o.bloc ? 'bloc' : 'notifier'}, view):

   ```bash
   echo | moarch create feature <name>
   ```
${o.withLocalCache ? '''
   With the local datasource, the repository caches: `fetchAll` saves the
   API's list to `LocalCache` and answers from it offline, and `watchAll`
   follows it.${o.withSync ? """ Its `create` / `update` / `delete` change the cache and queue
   the `SyncRequest` the remote datasource describes; point those at the
   real API.""" : ''}''' : '''
   `--all` also adds a local cache datasource.'''}''';
    final stateFields = o.bloc
        ? 'the constructor, `copyWith` and `props`'
        : 'the constructor and `copyWith` (with `?? this.x`)';
    return '''
${_intro('Add a feature')}
A feature is one folder under `lib/features/<name>/` with every layer in it.
If the feature already exists, use `moarch-add-endpoint`, `moarch-add-action`
or `moarch-build-screen` instead. If the user asked to plan it first,
`moarch-plan-feature` comes before this.

## Steps

1. **Scaffold it** — never create the folders by hand. `<name>` is
   snake_case (`order_history`).
$scaffold

   It writes `domain/models/<name>_model.dart`, the repository interface and
   implementation, the datasource(s), $holder and `presentation/views/<name>_view.dart`,
   and registers the data layer in `lib/config/di/data_module.dart`${o.bloc ? ' and the bloc\n   in `presentation_module.dart`' : ''} above `// moarch:registrations`.${o.withRouter ? '\n   It adds the route too: `AppRoutes.<name>` and a `GoRoute` to the\n   ${o.bloc ? 'page' : 'view'}, above `// moarch:routes`.' : ''}${o.withDio ? '\n   With a Dio datasource, the endpoint goes into `ApiConstants` above\n   `// moarch:endpoints`.' : ''}
   Read what it printed before going on.

2. **The model** — fields on `domain/models/<name>_model.dart`, then
   `$_buildRunner`. Follow `moarch-add-model`.

3. **The data layer** — the repository hands `fetchAll` on to the remote
   datasource, whose request is a placeholder (without a remote datasource,
   the repository throws `UnimplementedError`). The ${o.bloc ? 'bloc calls it on `Started`' : "notifier's `build` calls it"}, so
   the screen fails until it is real. Point it at the real endpoint, and add
   any other call, with `moarch-add-endpoint`.

4. **The state** — add what the screen draws to the state class: $stateFields.
   ${o.bloc ? 'Set it in `_onStarted`.' : 'Return it from `build()`.'}

5. **The screen** — `_body` in the view, from the UI kit, and the loading
   skeleton in `presentation/widgets/<name>_skeleton.dart`. Follow
   `moarch-build-screen`.

6. **Actions** — every button that does something: `moarch-add-action`.

7. **Tests** — `moarch create tests <name>`, then `moarch-write-tests`.

${_done(o)}''';
  }

  // ── plan-feature ───────────────────────────────────────────────────────────

  static String _planFeature(SkillOptions o) {
    final holder = o.bloc ? 'bloc' : 'notifier';
    final source = o.withDio && o.withFirestore
        ? '''
- **Where the data lives** — this project has both a REST client (Dio) and
  Firestore, and `moarch create feature` asks which one. For REST: each
  endpoint's method, path and payload. For Firestore: the collection, the
  document's shape, and whether the screen watches it live or fetches once.'''
        : o.withDio
        ? '''
- **The endpoints** — each call's method, path, parameters and payload. Paths
  end up in `ApiConstants`.'''
        : o.withFirestore
        ? '''
- **The collection** — its path, the document's shape, and whether the screen
  watches it live (`watchAll`) or fetches it once.'''
        : '''
- **Where the data comes from** — the project has no generated client, so
  which SDK or API the datasource calls, and what it returns.''';
    final navigation = o.withRouter
        ? '''
- **The route** — its path (`/orders`, `/orders/:id`) and what opens it.
  `moarch create feature` adds the feature's own route; every other screen
  needs one added by hand.
- **What a screen needs to load** — an id in the path, a query. Where
  `AGENTS.md` says any route can be opened from a link, that is all a screen
  may load from: never `extra`, never what the previous screen left behind.'''
        : '''
- **How the user gets there** — what opens each screen, and what it is
  passed.''';
    final scope = o.bloc
        ? '''

- **Who else needs the bloc** — a sheet, dialog or pushed route that reads
  the screen's bloc needs a scope (`moarch create scope <feature> <name>`). A
  second independent screen gets its own bloc (`moarch create bloc`).'''
        : '';
    final strings = o.withLocalization || o.withEasyLocalization
        ? '\n- **Strings** — every label and message is a key in every language '
              'file; ask\n  for the wording in each language the project ships.'
        : '';
    return '''
${_intro('Plan a feature')}
An interview that ends in a plan — no code is written here. Use it when the
user asks to plan, scope or be grilled on a feature. A change that is already
specified goes straight to `moarch-add-feature`.

## How to ask

The decisions form a tree: some can only be put once others are settled.
Work it in rounds.

- **A round is every question that can be answered now.** Number them, and
  give each your recommended answer with its reason in one line, so the user
  can reply `1 yes, 2 no — …`. A question that hangs off one still open waits
  for the next round.
- **Facts are yours to find; decisions are the user's.** What `lib/` already
  has, how a similar feature did it, what a sample payload in the repo holds:
  read it, do not ask. What the feature should do: ask, do not assume.
- **The architecture is not a question.** The layers, the state holder, the
  locator, the UI kit and the tokens are settled in `AGENTS.md`. Never offer
  an entity layer, a use case, another state library or a second HTTP client
  as an option.
- **Skip what the user already said**, and what does not apply.
- **Done when no question is left.** Then write the plan and wait for the
  user to confirm it before building anything.

## The decisions

In the order they unblock each other.

### What it is

- **The name** — snake_case, the folder under `lib/features/`
  (`order_history`).
- **New feature, or part of one** — read `lib/features/` first. A feature
  owns its data; a second screen or a new action on data an existing feature
  already owns is not a new feature.
- **What is out** — what this deliberately does not do yet.

### The data

$source
- **A sample payload** — ask for a real one. The model is generated from it
  (`moarch-add-model`), which beats guessing the fields.
- **The model** — which fields can be missing, which are nested objects or
  lists, which are dates or enums.
- **A local cache** — whether the data is kept on the device
  (`moarch create feature --all` adds the local datasource), and what is
  shown when it is stale.

### The screens

For each screen:

- **What it shows**, and which kit widgets carry it (`docs/UI_KIT.md`).
- **Its four states** — loading (the skeleton in
  `presentation/widgets/<name>_skeleton.dart`), empty (what the text says,
  and whether there is a call to action), error (retry?), and data.
- **Refresh and paging** — pull to refresh, load more, or neither.$strings

### The actions

For each button or gesture that changes something:

- **What it calls**, and what changes in the state when it succeeds.
- **What the user sees** — the success message, the error message if the
  backend's is not good enough, and whether it needs a confirmation first.
- **Where it goes after** — stays, closes a sheet, navigates.${o.bloc ? '\n- **A second tap while the first runs** — ignored or restarted.' : ''}

Each one becomes a $holder ${o.bloc ? 'event and handler' : 'method'} through `runAction`.

### Navigation

$navigation$scope
- **Who may see it** — signed-in users only, a role, everyone.

### Platform and configuration

- **Device capabilities** — camera, photos, location, notifications,
  biometrics. Each needs a declaration in `AndroidManifest.xml` and a usage
  description in `Info.plist`, and a decision on what the screen shows when
  the user refuses.
- **New packages** — name them; check the project does not already have a
  service for it in `lib/core/services/`.
- **Configuration and secrets** — keys, URLs, flags: they go through `AppEnv`
  (`moarch-add-env-key`), and the user supplies the values.
- **Offline** — what the feature does without a connection.

## The plan

Reply with it; write it to a file only if the user asks. It holds:

1. **The decisions**, one line each, in the order above.
2. **What is still unknown** and who can answer it — never a guess dressed
   as a decision.
3. **The build order**, as the skills that do each step:
   `moarch-add-feature` (which runs `moarch create feature <name>`), then
   `moarch-add-model`, `moarch-add-endpoint`, `moarch-build-screen`,
   `moarch-add-action` for each action, and `moarch-write-tests`.

Stop there. Building starts when the user says the plan is right.
''';
  }

  // ── add-endpoint ───────────────────────────────────────────────────────────

  static String _addEndpoint(SkillOptions o) {
    final dio = o.withDio
        ? '''
**Dio.** Declare the path in `ApiConstants`
(`core/constants/api_constants.dart`) above `// moarch:endpoints` —
`static const orders = '/orders';` — never as a string in the datasource.
Wrap the call in `safeApiCall` (`core/network/safe_api_call.dart`), which
turns every transport error into an `AppException`:

```dart
Future<List<OrderModel>> fetchAll() {
  return safeApiCall<List<OrderModel>>(
    apiCall: () async {
      final response = await _dio.get(ApiConstants.orders);
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
where cache-then-network is decided.${o.withLocalCache ? '''

A read the screen should have offline follows `fetchAll`: save the result
through the local datasource, and on `NetworkException` read it back from
there.${o.withSync ? '''

A write goes through the queue: the remote datasource returns a
`SyncRequest` (method, path, body) instead of calling Dio, and the repository
changes the cache (`_local.save` / `_local.remove`) then calls
`_sync.enqueue(collection, request)`. `SyncService` sends it and refetches.''' : ''} Otherwise, do **not** catch here: the''' : ''' Do **not** catch here: the'''}
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
   Future<void> deleteOrder({required int id}) {
     return runAction((current) async {
       await _repo.delete(id: id);
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

3. **The state** — a new field goes in the constructor and `copyWith` (with
   `?? this.x`). `error` and `success` are cleared by every
   `copyWith` on purpose: that is what makes a toast fire once.

4. **The view** — call it from a callback, never from `build`:

   ```dart
   AppButton(
     label: 'Delete',
     isLoading: state.isLoadingAction,
     onPressed: () =>
         ref.read(orderNotifierProvider.notifier).deleteOrder(id: order.id),
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
         await _repo.delete(id: event.id);
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
   emit is dropped). Never split it into a sealed class per phase.

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
regenerated. Fix every skeleton and test fixture the change broke.

${_done(o)}''';

  // ── build-screen ───────────────────────────────────────────────────────────

  static String _buildScreen(SkillOptions o) {
    final holderTarget = o.bloc ? 'page' : 'view';
    final route = o.withRouter
        ? '''

## The route

A feature's own screen already has one: `moarch create feature` adds it. For
any other screen (a detail page, a second screen in the feature):

1. The path in `lib/config/router/app_routes.dart`, above `// moarch:routes`
   (never remove that line). A path parameter gets a
   pattern constant plus an `…Of(id)` helper that builds the location, like
   `featureDetail` / `featureDetailOf`.
2. A `GoRoute` in `lib/config/router/app_router.dart`, above
   `// moarch:routes`, whose builder returns the $holderTarget${o.bloc ? ' (which provides the bloc)' : ''}.
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
- **The skeleton.** While loading, the view draws
  `presentation/widgets/<name>_skeleton.dart`: the same rows as `_body`, over
  fake models whose fields come from `BoneMock` (`BoneMock.name`,
  `BoneMock.words(3)`, `BoneMock.date`). A text's length sets its bone's width;
  an empty field shimmers as nothing.
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

  // ── fix-bug ────────────────────────────────────────────────────────────────

  static String _fixBug(SkillOptions o) {
    final holder = o.bloc ? 'bloc' : 'notifier';
    final boundary = [
      if (o.withDio) '`safeApiCall`',
      if (o.withFirestore) '`safeFirebaseCall`',
    ].join(' / ');
    final stateRows = o.bloc
        ? '''
| An action does nothing, or the screen does not rebuild | The state: a field missing from `props` makes two states equal, and the emit is dropped |
| A toast fires twice or never; loading never ends | The handler: it must go through `runAction`, and the `listenWhen` on the message fields |
| `ProviderNotFoundException` for a bloc | A sheet, dialog or pushed route reading the opener's bloc: it needs a scope |'''
        : '''
| An action does nothing, or the screen does not rebuild | The notifier: the method must go through `runAction` and return a new state from `copyWith` |
| A toast fires twice or never; loading never ends | The state's `copyWith` (it clears `error` / `success`) and the view's `ref.listenAction` |
| The screen rebuilds too often or not at all | `ref.read` in `build`, or `ref.watch` in a callback |''';
    final holderLoop = o.bloc
        ? '''
   ```dart
   blocTest<OrderBloc, OrderState>(
     'a failed delete keeps the order',
     setUp: () => when(() => repository.delete(id: 7))
         .thenThrow(const ServerException(message: 'Order is locked')),
     build: () => OrderBloc(repository),
     seed: () => loaded, // a state holding the order, built in the test
     act: (bloc) => bloc.add(const OrderDeleted(7)),
     verify: (bloc) => expect(bloc.state.orders, loaded.orders),
   );
   ```'''
        : '''
   ```dart
   test('a failed delete keeps the order', () async {
     when(() => repository.fetchAll()).thenAnswer((_) async => [order]);
     when(() => repository.delete(id: 7))
         .thenThrow(const ServerException(message: 'Order is locked'));
     await container.read(orderNotifierProvider.future);

     await container.read(orderNotifierProvider.notifier).deleteOrder(id: 7);

     final state = container.read(orderNotifierProvider).requireValue;
     expect(state.orders, [order]);
   });
   ```''';
    return '''
${_intro('Fix a bug')}
Reproduce before you theorise. One command that fails *because of this bug*,
and will pass once it is fixed, finds the cause faster than reading code —
and without it a fix is a guess nobody can check.

## 1. Find the layer that owns it

Each layer has one job, so the symptom usually names it:

| Symptom | Look at |
|---|---|
| An error toast or error screen with a message | The datasource: the message is the `AppException` it threw${boundary.isEmpty ? '' : ' through $boundary'} |
| A raw exception on screen, or a crash on a failed request | A call that is not translated into `AppException` in the datasource |
| `type 'Null' is not a subtype…`, a field that is always null or empty | The model: its field names against the real payload, and `build.yaml`'s `field_rename` |
| Code that ignores a field you just added | Stale generated code: run `$_buildRunner` |
$stateRows
| A skeleton with blank lines where content should be | The feature's `<name>_skeleton.dart`: a field its rows read has no `BoneMock` value |
| An overflow or an unbounded-height error | The view's constraints — `moarch-build-screen`, "Layout errors" |
| get_it says a type `is not registered` | The module in `lib/config/di/` that should register it |
| It only happens on a device, after a restart or from a link | Platform setup, permissions or lifecycle — step 2, the last loop |

Read the failing layer's file and the one below it. Do not start changing
things yet.

## 2. Make it fail on command

Take the first loop that can reach the bug:

1. **A unit test on the $holder** (`test/unit/`) — mock the repository
   **interface** so it returns the payload, or throws the `AppException`
   (a concrete one: `ServerException`, `NetworkException`…), that sets the
   bug off, then assert on the state:

$holderLoop

   The generated tests in `test/unit/` already set up the mocks${o.bloc ? '' : ' and the\n   container'}; add the case beside them, with fixtures built from the
   model's `.empty()` + `copyWith`. Run only it:

   ```bash
   fvm flutter test test/unit/<file>_test.dart --plain-name 'a failed delete'
   ```

2. **A model test** — `OrderModel.fromJson(<the real payload>)` in a plain
   `test(...)`. Paste the payload that breaks it, with tokens and personal
   data replaced first.

3. **A widget test** — pump the view with the state that breaks it
   (`moarch-write-tests` shows how the ${o.bloc ? 'bloc' : 'repository'} is provided). For a layout
   bug, set the size that shows it:
   `await tester.binding.setSurfaceSize(const Size(320, 568));`
${o.withDio ? '''

4. **An integration test** (`test/integration/`) — when the suspicion is that
   the backend answers something the app does not expect. These call the
   real API at `BASE_URL`.
''' : ''}
${o.withDio ? '5' : '4'}. **On a device** — for what no test reaches: a permission, a platform
   channel, a notification, a deep link, the app coming back from the
   background. You cannot run this yourself. Add temporary `debugPrint`
   lines with one tag (`[bug]`) at each layer's edge, give the user the exact
   steps, and ask for the log from `fvm flutter run`.

Run it and watch it fail **with the symptom the user described** — a
different failure nearby is a different bug. If nothing you build makes it
fail, stop and say so: what you tried, and what you need (a payload, the
steps, a log). Do not ship a fix you could not see fail.

## 3. Fix the cause, where it lives

- One hypothesis at a time: say what you expect to see, change one thing,
  run the loop again.
- Fix it in the layer that owns it. A `try` / `catch` in the $holder, a
  null check in the view hiding a model that parsed wrong, or a second copy of
  the data in the widget is the bug moved, not fixed.
- A wrong `*.g.dart` or `*.freezed.dart` is fixed at its source, then
  regenerated.
- When the cause is in a file moarch generated (`lib/core/`, `lib/config/`,
  `lib/shared/widgets/`), look at
  `moarch update <name> --dry-run --diff` first: a newer template may already
  fix it (`moarch-update-scaffold`).

## 4. Keep the proof

The test that failed stays in the suite, now passing. Remove every
temporary log line. Tell the user the cause in one sentence, and whether the
same mistake can exist elsewhere.

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
      constructor, `copyWith` and `props`.
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
- [ ] Every state field in the constructor and `copyWith`.
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
- [ ] New functions and methods take named `required` parameters
      (`delete({required int id})`, not `delete(int id)`), except where an
      override or typedef fixes the signature.

## State

$state

## UI

- [ ] Built from `lib/shared/widgets/` before raw Material.
- [ ] No magic numbers — `AppConstants` tokens; no literal `Color`s.
- [ ] Private widget classes, not `_buildX()` methods; `const` where it
      compiles.
- [ ] The skeleton draws the same rows as the view, with a `BoneMock` value
      for every field.${o.withLocalization || o.withEasyLocalization ? '\n- [ ] No hard-coded user-facing strings; every new key in every language.' : ''}

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
    this.withLocalCache = false,
    this.withSync = false,
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

  /// The offline-first cache (`lib/core/database/`) was generated.
  final bool withLocalCache;

  /// Offline sync (`lib/core/sync/`) was generated: writes are queued.
  final bool withSync;

  /// Whether the project uses flutter_bloc.
  bool get bloc => stateManagement.isBloc;
}
