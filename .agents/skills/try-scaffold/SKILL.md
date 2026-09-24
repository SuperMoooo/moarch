---
name: try-scaffold
description: "Generate a real Flutter project from this moarch checkout and check that it builds, analyzes and tests clean, on both stacks. Use after changing templates that produce Dart code, before a release, or to reproduce a bug a user reported in a generated project."
---

# Scaffold a real project

The template tests check text; only a real project checks that the text
compiles. Work outside the repository (the system temp directory), never
inside it.

## Steps

1. **A fresh app** per stack:

   ```bash
   cd "$(mktemp -d)"
   flutter create --org dev.moarch.check demo_riverpod
   flutter create --org dev.moarch.check demo_bloc
   ```

2. **Scaffold** from this checkout (`<repo>` is the moarch repository):

   ```bash
   dart run <repo>/bin/main.dart init -p demo_riverpod --all --state riverpod
   dart run <repo>/bin/main.dart init -p demo_bloc --all --state bloc
   ```

   `--all` takes every default-on option; to check an option that is off by
   default, run `init` without `--all` and answer the checklist on stdin
   (item numbers, then an empty line).

3. **Build** each one:

   ```bash
   cd demo_riverpod
   fvm use --force            # needs FVM; creates .fvm/flutter_sdk
   fvm flutter pub get
   fvm dart run build_runner build --delete-conflicting-outputs
   fvm flutter analyze
   fvm flutter test
   ```

   Without FVM, use the same commands with a bare `flutter` / `dart` and say
   so in the report. `.env` is written by `init`; if `build_runner` fails on
   `app_env.dart`, check it has `BASE_URL`.

4. **Exercise the commands** you changed, on the scaffolded project:
   `dart run <repo>/bin/main.dart create feature orders --all -p lib`,
   `create widget <name>`, `create tests`, `update --list`, `doctor` — then
   analyze again.

5. **Report** each failure with the generated file and line and the
   template it came from. Fix the template, not the generated file, and
   re-run from step 2.

Delete the temp directory when done.
