# 🧱 moarch

A Dart/Flutter CLI package for scaffolding Clean Architecture apps with Riverpod, GoRouter, secure env support, and production-ready templates.

[![pub version](https://img.shields.io/pub/v/moarch.svg)](https://pub.dev/packages/moarch)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

---

## Install

```bash
dart pub global activate moarch
```

Make sure the global pub cache bin folder is on your `PATH`:

```bash
# macOS / Linux
export PATH="$PATH:$HOME/.pub-cache/bin"

# Windows
setx PATH "%PATH%;%APPDATA%\Pub\Cache\bin"
```

---

## Quick start

```bash
flutter create my_app
cd my_app
moarch init
moarch create feature auth
```

### Common commands

```bash
moarch init             # scaffold a complete Flutter app structure
moarch init --all       # generate the default app without prompts
moarch create feature auth
moarch create feature auth --all
```

---

## What moarch generates

- app structure with `lib/main.dart`, `core/`, `config/`, `shared/widgets/`, and `features/`
- `GoRouter` routing setup
- `flutter_secure_storage` wrappers
- `.env` support with `Envied` code generation
- GitHub Actions CI workflow scaffold
- reusable UI widgets, loading states, and error handling
- feature scaffolding with Clean Architecture layers
- Test scaffolding is not included; use the `mogen_unit_tests` package on pub.dev to generate tests for features

---

## Feature generation

`moarch create feature <name>` generates a feature folder with:

- `domain/` (entities, repository interfaces, optional use cases)
- `data/` (remote/local datasources, models, repository implementations)
- `presentation/` (state, notifier, view)

The CLI uses an interactive checklist so you can generate only the layers you need.

---

## Customize templates

Templates are defined in `lib/src/templates/`:

- `core_templates.dart`
- `config_templates.dart`
- `feature_templates.dart`
- `shared_templates.dart`
- `checklist_templates.dart`
- `workflow_templates.dart`

To use local template changes:

```bash
git clone https://github.com/SuperMoooo/moarch.git
cd moarch
dart pub global activate --source path ./
```

---

## Package details

- name: `moarch`
- license: MIT
- repository: https://github.com/SuperMoooo/moarch

---

## Troubleshooting

- If `moarch` is not found, confirm the global pub cache bin folder is on your `PATH`.
- If a feature already exists, rename or remove the existing folder first.
- After changing templates locally, re-activate with `dart pub global activate --source path ./`.

## License

MIT © [André Montoito](https://github.com/SuperMoooo)
