# 🧱 moarch

A Flutter CLI tool to scaffold Clean Architecture projects with Riverpod — your conventions, your structure, no code generation required.

[![pub version](https://img.shields.io/pub/v/moarch.svg)](https://pub.dev/packages/moarch)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

---

## Features

- ⚡ **One command setup** — `moarch init` scaffolds your full `lib/` structure with routing, theme, security, and shared widgets
- 🎯 **Layered feature generation** — `moarch create feature <n>` generates Clean Architecture with an interactive checklist
- ✨ **Zero boilerplate** — No `build_runner`, `freezed`, or `riverpod_annotation` — everything compiles immediately
- 🏗️ **Your conventions** — Fully customizable templates, pre-configured with proven patterns
- 🔒 **Security included** — Secure storage integration with `flutter_secure_storage`
- 📍 **Router ready** — GoRouter setup out of the box
- 🎨 **Reusable widgets** — Pre-built button, input, loading, and error view components
- 📦 **Environment-aware** — `.env` and `.fvmrc` generated at project root

---

## Installation

```bash
dart pub global activate moarch
```

Make sure `~/.pub-cache/bin` is in your `PATH`:

```bash
# macOS / Linux — add to .zshrc or .bashrc
export PATH="$PATH:$HOME/.pub-cache/bin"

# Windows — add %APPDATA%\Pub\Cache\bin to your PATH via Environment Variables
```

---

## Quick start

```bash
# 1. create your Flutter project
flutter create my_app && cd my_app

# 2. add dependencies to pubspec.yaml (see below)
flutter pub get

# 3. remove the generated main.dart
rm lib/main.dart

# 4. scaffold the project structure
moarch init

# 5. create your first feature
moarch create feature auth
```

---

## Required dependencies

```yaml
dependencies:
    flutter:
        sdk: flutter
    flutter_riverpod: ^2.5.1
    envied: ^1.3.3
    dio: ^5.4.3
    go_router: ^14.0.0
    flutter_secure_storage: ^9.2.2
```

## Dev dependencies (for build_runner + envied_generator)

```yaml
dev_dependencies:
    lints: ^3.0.0
    test: ^1.24.0
    build_runner: ^2.4.0
    envied_generator: ^1.0.0
```

## Envied support (added by moarch init)

When you run `moarch init`, it scaffolds:

- `lib/config/env/app_env.dart` with `@Envied(... obfuscate: true)`
- `.env` entries: `BASE_URL=` (auto-generated)
- `.gitignore` entry `.env`

In your app, execute codegen:

```bash
fvm flutter pub add envied
fvm flutter pub add --dev build_runner envied_generator
dart run build_runner build --delete-conflicting-outputs
```

Then use `AppEnv` values safely:

```dart
final baseUrl = AppEnv.baseUrl;
```

---

## moarch init

Generates a complete, production-ready project structure:

```
.env                             ← BASE_URL=
.fvmrc                           ← { "flutter": "stable" }
lib/
├── main.dart                    ← App with routing & theme setup
├── core/
│   ├── constants/
│   │   ├── app_constants.dart   ← spacing (4pt), text sizes, touch targets, radii, durations
│   │   └── api_constants.dart   ← API timeout, BASE_URL from .env
│   ├── errors/
│   │   └── app_exception.dart   ← unified error handling
│   ├── network/
│   │   └── dio_client.dart      ← HTTP client with interceptors
│   ├── security/
│   │   └── secure_storage.dart  ← flutter_secure_storage wrapper
│   └── utils/
│       ├── extensions.dart      ← ContextX, StringX, DateTimeX
│       └── logger.dart          ← single log() function
├── config/
│   ├── router/
│   │   └── app_router.dart      ← GoRouter setup with routes
│   └── theme/
│       └── app_theme.dart       ← Material 3 theme, light/dark modes
├── shared/widgets/
│   ├── buttons/
│   │   └── app_button.dart      ← filled / outlined / text variants
│   ├── inputs/
│   │   └── app_input.dart       ← themed text input field
│   ├── loadings/
│   │   ├── app_loading_data.dart    ← progress indicators for data loading
│   │   └── app_loading_action.dart  ← indicators for actions (submit, delete)
│   └── error_view.dart          ← error display component
└── features/                    ← your features go here
```

**What you get:**

- ✅ Routing configured with GoRouter
- ✅ Secure storage integration ready
- ✅ DIO client with error handling
- ✅ Theme system with Material 3 support
- ✅ Reusable widgets library
- ✅ Environment variables (.env) support
- ✅ Extension methods for common operations

## moarch create feature

Generates a complete feature with Clean Architecture layers and an interactive checklist.

```bash
moarch create feature auth
moarch create feature user_profile
moarch create feature ProductCatalog    # casing doesn't matter
moarch create feature auth --all        # skip checklist, generate all layers
```

### Interactive Checklist

The CLI presents a checklist to select which layers to generate:

```
  Select layers for "Auth" (space = toggle, enter = confirm):
▶ [✓]  Remote Datasource
  [ ]  Local/Cache Datasource        ← optional, default: off
  [✓]  Repository (interface + impl)
  [ ]  Use Cases                     ← optional, default: off
  [✓]  State + Notifier
  [✓]  View
```

This lets you generate only what you need — skip local datasources if your feature is API-only, or skip use cases if your logic fits in the notifier.

### Generated Structure

```
lib/features/auth/
├── domain/
│   ├── entities/
│   │   └── auth_entity.dart
│   ├── repositories/
│   │   └── auth_repository.dart     ← interface
│   └── usecases/
│       └── get_auth.dart            ← if selected
├── data/
│   ├── datasources/
│   │   ├── auth_remote_datasource.dart
│   │   └── auth_local_datasource.dart  ← if selected
│   ├── models/
│   │   └── auth_model.dart          ← copyWith, fromJson, toJson
│   └── repositories/
│       └── auth_repository_impl.dart
└── presentation/
    ├── states/
    │   └── auth_state.dart
    ├── notifiers/
    │   └── auth_notifier.dart       ← StateNotifier with error handling
    ├── views/
    │   └── auth_view.dart
    └── widgets/
```

### State Management Pattern

Your state uses a simple, flexible model with `copyWith`:

```dart
class AuthState {
  const AuthState({
    this.isLoadingAction = false,
    this.error,
    this.success,
  });

  final bool isLoadingAction;
  final String? error;
  final String? success;

  AuthState copyWith({
    bool? isLoadingAction,
    String? error,
    String? success,
  }) {
    return AuthState(
      isLoadingAction: isLoadingAction ?? false,
      error: error,
      success: success,
    );
  }
}
```

Error handling in views uses `state.value?.error` — your `AppException` message from the repository, not the `AsyncValue` error:

```dart
ref.listen(authNotifierProvider, (_, next) {
  final value = next.value;
  if (value?.error != null) {
    // show snackbar with value.error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value!.error!)),
    );
  }
});
```

### Tips

- **Remote datasource only?** Unselect "Local/Cache Datasource" in the checklist
- **No use cases?** Skip them if your feature is simple — the repository covers most cases
- **Reuse widgets?** Put shared feature widgets in `shared/widgets/`, not in the feature folder
- **Models with JSON?** The generated model includes `fromJson()` and `toJson()`

---

## Customizing moarch

moarch templates are generated from production-ready code that matches default Flutter best practices. If you want to customize what gets generated, clone the repository and modify the templates:

### Template files

| File                     | Generates                                                                                 |
| ------------------------ | ----------------------------------------------------------------------------------------- |
| `core_templates.dart`    | `main.dart`, `dio_client`, `secure_storage`, constants, errors, utils, extensions, logger |
| `config_templates.dart`  | `app_theme.dart`, `app_router.dart`                                                       |
| `shared_templates.dart`  | `app_button`, `app_input`, `app_loading_action`, `app_loading_data`, `error_view`         |
| `feature_templates.dart` | entity, model, datasources, repository, state, notifier, view                             |

### Steps to customize

1. **Clone the repository**

    ```bash
    git clone https://github.com/SuperMoooo/moarch.git
    cd moarch
    ```

2. **Edit templates** in `lib/src/templates/`
    - Each method returns a string of Dart code
    - Your changes will be inserted as-is into generated files

3. **Re-activate locally**

    ```bash
    dart pub global activate --source path ./
    ```

4. **Test your changes**
    ```bash
    moarch init
    moarch create feature test_feature
    ```

### Pro Tips

- Keep method signatures consistent — users expect certain class names and patterns
- Use triple-quoted strings (`r'''...'''`) to avoid escaping special characters
- Test across different feature names (snake_case, PascalCase, UPPER_CASE)
- If you change core templates, test `moarch init` first before features
- Pull requests for improvements are welcome!

---

## Common use cases

### Starting fresh

```bash
# Quick start with all layers
moarch create feature user --all
```

### API-only feature

```bash
# Skip local datasource and use cases, generate only remote
moarch create feature products
# Then unselect "Local/Cache Datasource" and "Use Cases" in the checklist
```

### Feature with offline support

```bash
# Select "Local/Cache Datasource" in the checklist
moarch create feature downloads
```

### Add routing to your features

Your `app_router.dart` is ready for GoRouter routes. Add them under a new screen route:

```dart
GoRoute(
  path: '/auth',
  builder: (context, state) => const AuthView(),
),
```

---

## Troubleshooting

**Command not found: `moarch`**

- Check that `~/.pub-cache/bin` (or `%APPDATA%\Pub\Cache\bin` on Windows) is in your `PATH`
- Try: `dart pub global activate moarch` again

**Feature already exists**

- moarch won't overwrite existing features — delete or rename the folder first

**Wrong package imports after init**

- All generated files use relative imports for core/config/shared — verify your lib structure matches

**Customization not working**

- After editing templates, run: `dart pub global activate --source path ./`
- Make sure you've saved the file and are using the updated version

---

## License

MIT © [André Montoito](https://github.com/SuperMoooo)
