---
name: add-template
description: "Add a new file that `moarch init` generates, or change what an existing one generates: the template function, both stacks, the catalog entry, init, tests and docs. Use for any change under lib/src/templates/ outside the UI kit."
---

# Add or change a generated file

Template text is production code: it lands in other people's projects. Read
`AGENTS.md` first — the catalog, detection and manifest sections are why the
steps below exist.

## A new file

1. **The template** — a static function in `lib/src/templates/<area>/`
   returning the file's source. `r'''…'''` when the output contains `$` and
   nothing is interpolated; `'''…'''` with `${…}` when it is, and `\$` for a
   dollar the generated file keeps. Optional chunks are inline ternaries.
   Remember a `'''` string drops a newline that directly follows the opening
   quotes.

2. **Both stacks** — if the file holds state or differs between Riverpod and
   bloc, write it in `templates/riverpod/` *and* `templates/bloc/` and expose
   it through `StackTemplates` (`templates/stack_templates.dart`). Nothing
   outside the facade imports either folder. A file one stack has no
   equivalent for follows the `hasActionBase` pattern.

3. **Options** — a variant that depends on the project reads it through a
   getter on `ScaffoldContext` (`utils/scaffold_catalog.dart`) that detects it
   off disk (a pubspec entry, a marker file). Do not thread a flag through
   call sites.

4. **The catalog entry** — a `ScaffoldSpec` in `ScaffoldCatalog.all`: a slug
   unique across scaffold slugs, widget slugs and group slugs, a
   forward-slash project-relative `path` (`blocPath` if bloc differs), a
   `category` from `ScaffoldCatalog.categories`, `template: (c) => …` and a
   one-line `description`. Without it, `moarch update` can never refresh the
   file.

5. **`init` writes it** — in `commands/init_command.dart`, under the checklist
   option it belongs to, through `FileUtils.writeFile` (never clobbers; use
   `overwriteWhen` only for a file `flutter create` wrote). The manifest
   records it automatically.

6. **Files moarch does not own** (gradle, manifest, plist, Podfile, Swift,
   Kotlin, pubspec) are patched by the matching `utils/*_utils.dart`, never
   rewritten. A generated file patched later carries an anchor comment that
   says it is load-bearing.

7. **Existing projects** — `update` never adds a file. If existing projects
   should get it, add a `ProjectInspector` diagnostic with a fix (see
   `_skills` / `_theme` in `utils/project_inspector.dart`), gated on the
   manifest version so newer projects that opted out are not nagged.

## Changing an existing template

- Check who else renders the same idea: the other stack, `README` templates
  (`templates/misc/readme_templates.dart`), `AGENTS.md` and the skills
  (`templates/misc/agents_templates.dart`, `skills_templates.dart`). A changed
  path, command or pattern has to change in all of them.
- A file that moves gets `movedFrom` on its spec, so `update` relocates it.

## Tests and docs

- `test/<thing>_test.dart` asserts on the generated source text: the
  options that add or remove chunks, both stacks, and that nothing leaks
  between them.
- `README.md` (the package's) describes what `init` generates; the generated
  project's README comes from `readme_templates.dart`.
- A `CHANGELOG.md` entry — see the `release` skill.

## Done when

```bash
dart format .
dart analyze --fatal-infos
dart test
```

For anything that changes generated Dart code, also run the `try-scaffold`
skill: the templates' tests check text, not that it compiles.
