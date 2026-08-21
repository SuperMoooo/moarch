# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
activated — plus a newest-first entry in `CHANGELOG.md`.

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
  demand by `moarch create widget`.

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

`ProjectInspector` (`lib/src/utils/project_inspector.dart`) is the checks
behind `doctor`, each `Diagnostic` optionally carrying a fix for `doctor --fix`.

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
lib/config/{di,env,theme,router,firebase}
lib/core/{constants,errors,network,security,services,utils}
lib/features/<feature>/{data/{datasources,models,repositories},
                        domain/{entities,repositories},
                        presentation/{notifiers|blocs,states,views,pages}}
lib/shared/widgets/              README.md   docs/*.md   .moarch.yaml   .fvmrc
```

Generated projects are FVM-pinned, so their commands run as `fvm flutter …` /
`fvm dart …`, and model/env codegen is `build_runner`.
