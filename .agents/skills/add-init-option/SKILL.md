---
name: add-init-option
description: "Add a checklist option to `moarch init` end to end: the checklist item, the files and packages it adds, how later commands detect it, the docs and a doctor fix for existing projects. Use when a new capability should be opt-in at init."
---

# Add an init option

Options are chosen once, at `init`, and **detected** by every later command —
never remembered. Both halves are needed.

## Steps

1. **The checklist item** — in `commands/init_command.dart`: a `_kX` label
   constant, a `ChecklistItem(_kX, defaultOn: …, description: …, excludes: {…})`
   in the right `Checklist.prompt` ("Backend / networking" or "What to
   generate"), and — if it is on by default — the `--all` set near the top of
   `run`. The label is what the manifest records, so keep it stable once
   released.

2. **What it generates** — each file is the `add-template` skill: a template,
   a catalog entry, and a `FileUtils.writeFile` guarded by
   `stack.contains(_kX)`. Packages go into the pubspec list through
   `PackageVersions.entry(...)` with a constraint in `PackageVersions`.

3. **Detection** — a getter on `ScaffoldContext` that reads the option off
   disk (whole-entry `hasPackage`, or a marker file with `hasFile`), and on
   `WidgetVariants` if widgets vary with it. Every template that varies
   with the option takes it from the getter in the catalog, and from
   `stack.contains(_kX)` in `init`.

4. **Everything that describes the project** — the generated README
   (`readme_templates.dart`), `AGENTS.md` and the skills
   (`agents_templates.dart`, `skills_templates.dart` — a new `SkillOptions`
   field if a procedure changes), and `ProjectInspector` if the option can be
   half-installed.

5. **Existing projects** — if it should reach them, a doctor diagnostic with
   a fix, gated on the manifest version (the `_skills` pattern).

6. **Tests** — the templates' tests for both values of the option;
   `scaffold_catalog_test.dart` for a new detection getter.

7. **Docs** — the option in `README.md`'s init section, and `CHANGELOG.md`.

## Done when

```bash
dart format .
dart analyze --fatal-infos
dart test
```

and `try-scaffold` passes with the option both on and off.
