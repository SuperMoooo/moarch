# AGENTS.md

Guidance for coding agents (Claude Code, Codex, Cursor, Copilot, Gemini CLI)
working in this repository. `CLAUDE.md` imports this file; step-by-step
procedures for the common changes are in `.agents/skills/` (see
[Skills](#skills)).

## What this is

`moarch` is a Dart CLI (published on pub.dev) that scaffolds Clean Architecture
Flutter apps — Riverpod or flutter_bloc, FVM, get_it. There is no Flutter code
here: every file the CLI generates is a **Dart string** in `lib/src/templates/`.
Editing a template changes what other people's projects get, so treat template
text as production code.

The templates encode one team's conventions on purpose. The intended path for
someone whose conventions differ is to clone and edit the templates, not to add
a flag for every taste (`README.md` → "Make it your own").

## Commands

```bash
dart pub get
dart test                                  # all tests
dart test test/scaffold_catalog_test.dart  # one file
dart test test/update_command_test.dart -n 'refreshes'   # one test by name
dart format .
dart analyze --fatal-infos

dart run bin/main.dart <args>              # run the CLI without installing
dart pub global activate --source path ./  # install this checkout as `moarch`
```

CI (`.github/workflows/ci.yml`) gates on, in order: `dart format
--output=none --set-exit-if-changed .`, `dart analyze --fatal-infos`,
`lib/src/version.dart` matching `pubspec.yaml`'s `version:`, `dart test`, and
`dart pub publish --dry-run` (pub score). A release bumps **both** the pubspec
version and `packageVersion` in `lib/src/version.dart` — the constant is
duplicated because the pubspec is unreadable at runtime once globally
activated — plus a newest-first entry in `CHANGELOG.md`. Every push that
carries a new version publishes it, so if the last commit already bumped the
version, a new change bumps it again rather than joining that entry
(`.agents/skills/release/SKILL.md`).

`analysis_options.yaml` turns on `public_member_api_docs`, so every public
member needs a doc comment or `analyze --fatal-infos` fails. `avoid_print` is
on too: user-facing output goes through the `mason_logger` `Logger` that each
command is constructed with.

## Architecture

`bin/main.dart` → `MoarchRunner` (`lib/src/runner.dart`) → four `args`
subcommands in `lib/src/commands/`: `init`, `create` (with the subcommands in
`commands/create/`), `update`, `doctor`.

### Two stacks, one facade

Every state-bearing file exists twice: `lib/src/templates/riverpod/` and
`lib/src/templates/bloc/`. Generators must go through `StackTemplates`
(`lib/src/templates/stack_templates.dart`) rather than importing either folder
— it resolves both the template *and* the differing paths (`presentation/
notifiers/` + `states/` vs. `presentation/blocs/`, and bloc's extra
`pages/<x>_page.dart`). Keep the two folders at parity when adding anything;
`hasActionBase` is the pattern for "this stack has no equivalent".

State management is the only axis that forks. DI is get_it in both.

### The catalogs are the registry

Two lists decide what exists:

- `lib/src/utils/scaffold_catalog.dart` — every file `init` writes outside
  `lib/shared/widgets/`, as `ScaffoldSpec`s (slug, path, template fn, group).
- `lib/src/utils/widget_catalog.dart` — the UI kit, which is also created on
  demand by `moarch create widget`. A spec's `dir` says which folder under
  `lib/shared/` it lands in: `widgets` for the kit, `views` for the one entry
  that is a whole route (the design-system preview). Never join
  `shared/widgets` by hand — go through `spec.pathIn(libPath)` / `spec.libFile`.
  A spec that has moved carries `movedFrom`, and `update` reads it to relocate
  a project's file rather than leave a second copy behind.

`moarch update <name|group|all>`, `--list`, and `doctor` are all driven from
these. **A new generated file is a template function plus a catalog entry** —
miss the entry and `update` can never refresh it. Slugs share one namespace:
`test/scaffold_catalog_test.dart` fails if a slug collides with another slug, a
group slug, or `all`. A new widget must also be rendered by the generated
design-system preview screen or listed with a reason in `_notPreviewed` in
`test/widget_catalog_test.dart`.

### Options are detected, never remembered

`ScaffoldContext` (in `scaffold_catalog.dart`) and `WidgetVariants` (in
`widget_catalog.dart`) read a project's options back off disk — pubspec entries
matched as whole entries, and marker files (`dio_client.dart`, a `dark` getter
in `app_theme.dart`, `biometric_service.dart`…). `init` gets them from its
checklist; every later command detects them, because the project outlives the
checklist and gets hand-edited. When adding a variant, add a getter here rather
than threading a flag through call sites.

### The manifest is what makes `update` safe

`init` writes `.moarch.yaml` (`lib/src/utils/project_manifest.dart`) recording
an FNV-1a hash per generated file. `update` compares it against disk:
untouched files refresh silently, **edited files are never overwritten** without
`--force`, and a project with no manifest treats everything as possibly-edited.
`lib/src/utils/text_diff.dart` renders `update --diff`. Hashes normalize line
endings so a CRLF checkout isn't misread as an edit.

### Writing and patching

`FileUtils` (`lib/src/utils/file_utils.dart`) wraps all writes: per-command
session tracking, `rollback()` on failure, dry-run, and a hard rule that
existing files are never clobbered (`analysis_options.yaml` is the blanket
exception; `overwriteWhen` the narrow one, for files `flutter create` wrote).

Files moarch does not own are patched, not rewritten, by one util per format:
`gradle_utils`, `kotlin_utils`, `manifest_utils`, `plist_utils`,
`podfile_utils`, `swift_utils`, `pubspec_utils`. Generated files that get
patched later carry an anchor comment — `injector_utils.dart` inserts get_it
registrations above `// moarch:registrations`; the anchor is load-bearing and
says so in the generated source.

### The locator is one file per layer

`lib/config/di/` is six files, not one: `injector.dart` holds `getIt` and a
`setupInjector()` calling one registrar per layer, and the registrations live
in `external_module.dart`, `core_module.dart`, `data_module.dart`,
`feature_module.dart` (a feature's long-lived services, plus the
`openScope`/`closeScope` helpers — since 9.0.0, and called only when present:
`ScaffoldContext.hasFeatureModule`) and — bloc only — `presentation_module.dart`. So `injector.dart` does not grow with the
app, and Riverpod's lack of a presentation module is the layout stating the
rule: notifiers are the one thing get_it does not hold.

`create feature` writes each half of a feature into its own module, so
`InjectorUtils.registrationsFor` returns an `InjectorRegistrations` split into
`data`/`holders` rather than one string. Projects scaffolded before the split
still have everything in `injector.dart`; which layout a project has is
**detected** (`InjectorUtils.isSplit`, `ScaffoldContext.hasSplitDi`), and both
are supported — `InjectorTemplates.singleFileInjector` exists so
`moarch update injector` refreshes an old project as what it is instead of
handing it a root that calls modules it does not have. Do not delete it
without a migration.

### The test generator reads the project, it does not template it

`moarch create tests` (`commands/create/create_tests_command.dart`) is the one
command that is not string templates: `lib/src/testgen/` parses the project's
own source with `analyzer` (unresolved `parseString`, no build) and writes
tests from what it finds. `unit/` covers notifiers, blocs and cubits.
`integration/` covers remote datasources' GET calls. Both were the standalone
mogen packages; `testgen_conventions.dart` holds what makes them moarch's (the
`GENERATED BY moarch` marker, the thrown `ServerException`, the injector
import). `analyzer` is supported from 10 to 14, so AST access goes through
`testgen/ast_helpers.dart`: arguments became `Argument` nodes and the
parameter classes were folded together in 13, so never match
`SimpleFormalParameter` / `FieldFormalParameter` or call `argumentExpression`
directly. Orchestrators return a `TestGenResult` and print nothing; the
command owns the `Logger`. Tests: `test/testgen/`, where
`moarch_conventions_test.dart` covers the moarch-specific shapes.

`ProjectInspector` (`lib/src/utils/project_inspector.dart`) is the checks
behind `doctor`, each `Diagnostic` optionally carrying a fix for `doctor --fix`.

### The generated agent guide

The "AI agent guide" `init` option writes the generated project's instructions
for coding agents, in the same form this repo uses for its own:

- `AGENTS.md` (`templates/misc/agents_templates.dart`): the rules. Codex,
  Cursor, Copilot and Gemini (through `.gemini/settings.json`) read it as-is.
  `CLAUDE.md` is only `@AGENTS.md`.
- `.agents/skills/moarch-<slug>/SKILL.md` (`templates/misc/skills_templates.dart`):
  one procedure per common task, varying with the stack and options through
  `SkillOptions`. Claude Code reads only `.claude/skills/`, so each skill also
  gets a pointer there with the same frontmatter, rather than a second copy of
  the body that could drift.
- `.claude/settings.json` (allows the checks, denies `.env` and the generated
  files) and `.gemini/settings.json`.

All of it is in the catalog's `ai` group (`moarch update ai`). AGENTS.md
lists the skills only when `ScaffoldContext.hasAgentSkills` finds them on disk,
and `doctor` offers them to projects from before 9.1.0. **When a template
changes a convention an agent follows** (a path, a command, a state pattern),
update `agents_templates.dart` and `skills_templates.dart` in the same change.
A skill describes commands and files that exist, so it is tested like any
other template (`test/skills_templates_test.dart`), including that its
frontmatter parses as YAML.

### Template string conventions

Templates are Dart string functions returning generated source. Use `r'''…'''`
when the generated code contains `$` and nothing needs substituting; use plain
`'''…'''` with `${…}` when the template interpolates, and escape `\$` for
dollars meant to survive into the generated file. Conditional chunks are
inline ternaries inside the string.

Tests mirror this: one `test/<thing>_test.dart` per template group or util,
asserting against the generated source text.

## Generated project shape

What the templates produce, since most changes here are about it:

```
lib/config/di/{injector,external_module,core_module,data_module,feature_module,
               presentation_module}.dart
lib/config/{env,theme,router,firebase}
lib/core/{constants,errors,network,security,services,utils}
lib/features/<feature>/{data/{datasources,models,repositories},
                        domain/{models,repositories},
                        presentation/{notifiers|blocs,states,views,pages}}
lib/shared/{widgets,views}/      README.md   docs/*.md   .moarch.yaml   .fvmrc
AGENTS.md   CLAUDE.md   .agents/skills/   .claude/{skills,settings.json}   .gemini/
```

There is no entity layer: a feature's one data type is the freezed model in
`domain/models/`, which the repository interfaces, the state and the screens all
use directly. (Before 8.0.0 it lived in `data/models/`; the two auth model
specs carry `movedFrom` so `update` relocates them.) Do not reintroduce a `domain/entities/` or `toEntity`/`fromEntity`
mapping.

Generated projects are FVM-pinned, so their commands run as `fvm flutter …` /
`fvm dart …`, and model/env codegen is `build_runner`.

## Skills

Procedures for the changes this repo gets most, in `.agents/skills/` (Claude
Code: `.claude/skills/`, which point there). Read the matching one before
starting that kind of change.

| Skill | For |
|---|---|
| [`add-template`](.agents/skills/add-template/SKILL.md) | A new file `init` generates, or a change to one |
| [`add-widget`](.agents/skills/add-widget/SKILL.md) | A new widget in the UI kit |
| [`add-init-option`](.agents/skills/add-init-option/SKILL.md) | A new checklist option in `moarch init` |
| [`try-scaffold`](.agents/skills/try-scaffold/SKILL.md) | Generate a real project from this checkout and build it |
| [`release`](.agents/skills/release/SKILL.md) | Bump the version, write the changelog, pass CI |
