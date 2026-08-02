# [2.8.0]

## Features

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

## Improvements

- **`moarch init` now records every file it writes in `.moarch.yaml`**, where it
  previously recorded only the widgets. That record is the whole basis for
  telling an untouched generated file from one you edited — without it the rest
  of the scaffold could only ever be reported as *needs review*.
    - A project scaffolded before 2.8.0 has no record of its non-widget files,
      so the first `moarch update` lists them as needing review even where they
      are untouched. Refreshing or confirming them re-records them, and
      subsequent runs are exact. That is the safe direction: nothing is
      overwritten on the strength of a guess.
- `.fvmrc` and `flutter_native_splash.yaml` are generated from `DevTemplates`
  rather than from literals inside the init command, so what `init` writes and
  what `update` compares against cannot drift apart.
