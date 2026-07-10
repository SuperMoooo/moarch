# moarch

A simple Dart/Flutter CLI for scaffolding Clean Architecture-style apps.

[![pub version](https://img.shields.io/pub/v/moarch.svg)](https://pub.dev/packages/moarch)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

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
moarch create feature auth
moarch create model auth login_response
```

## Commands

```bash
moarch init          # interactive scaffold
moarch init --all    # generate the default structure without prompts
moarch create feature <featureName>
moarch create model <featureName> <modelName> # generate the model and entity
moarch create model --empty <featureName> <modelName> # Inject a .empty() factory into an existing entity.
moarch create empty-factories # generate .empty() in all entities
```

## What it generates

- `lib/main.dart`, `core/`, `config/`, `shared/`, and `features/`
- Riverpod + optional GoRouter setup
- Envied-based `.env` support
- secure storage, logger, helpers, and reusable widgets
- optional services such as notifications (local or Firebase push), URL launcher, media, debounce
- optional localization with `assets/i18n/` and FlutterLocalization initialization

## Local development

```bash
git clone https://github.com/SuperMoooo/moarch.git
cd moarch
dart pub global activate --source path ./
```

## License

MIT © André Montoito
