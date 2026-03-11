# 🧱 moarch

A Flutter CLI tool to scaffold Clean Architecture projects with Riverpod — your conventions, your structure, no code generation required.

[![pub version](https://img.shields.io/pub/v/moarch.svg)](https://pub.dev/packages/moarch)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

---

## Features

- `moarch init` — scaffolds your full `lib/` structure in seconds
- `moarch create feature <n>` — generates Clean Architecture layers with an interactive checklist
- No `build_runner`, no `freezed`, no `riverpod_annotation` — everything compiles immediately
- Providers live at the top of their own file, no separate DI file
- State pattern matches your own style: plain class with safe `copyWith`, `AsyncNotifier`, `ref.listen`
- `.env` and `.fvmrc` generated at project root

---

## Installation

```bash
dart pub global activate moarch
```

Make sure `~/.pub-cache/bin` is in your `PATH`:

```bash
# add to .zshrc or .bashrc
export PATH="$PATH:$HOME/.pub-cache/bin"
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

# 4. scaffold
moarch init

# 5. create your first feature
moarch create feature auth
```

---

## Required project dependencies

```yaml
dependencies:
    flutter:
        sdk: flutter
    flutter_riverpod: ^2.5.1
    dio: ^5.4.3
    flutter_dotenv: ^5.1.0
    flutter_secure_storage: ^9.2.2
```

Also register `.env` in your `pubspec.yaml` assets:

```yaml
flutter:
    assets:
        - .env
```

---

## moarch init

Generates the full project structure:

```
.env                             ← BASE_URL=
.fvmrc                           ← { "flutter": "stable" }
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   ├── app_constants.dart   ← spacing (4pt grid), text sizes, touch targets, radii, durations
│   │   └── api_constants.dart   ← timeouts only, BASE_URL comes from .env
│   ├── errors/
│   │   └── app_exception.dart
│   ├── network/
│   │   └── dio_client.dart      ← dotenv baseUrl, secure storage auth token, all status codes pass through
│   ├── usecases/
│   │   └── usecase.dart
│   └── utils/
│       ├── extensions.dart      ← ContextX, StringX, DateTimeX
│       └── logger.dart          ← single log() function, kDebugMode only
├── config/
│   └── theme/
│       └── app_theme.dart       ← useMaterial3, you fill in the rest
├── shared/widgets/
│   ├── app_button.dart          ← filled / outlined / text variants
│   ├── app_loading.dart
│   └── error_view.dart
└── features/
```

---

## moarch create feature \<n\>

Generates Clean Architecture layers with an interactive checklist in the terminal.

```bash
moarch create feature auth
moarch create feature user_profile
moarch create feature ProductCatalog    # any casing works

moarch create feature auth --all        # skip checklist, generate all layers
```

**Checklist** — toggle with space, confirm with enter:

```
  Select layers for "Auth":
▶ [✓]  Remote Datasource
  [ ]  Local/Cache Datasource        ← off by default
  [✓]  Repository (interface + impl)
  [ ]  Use Cases                     ← off by default
  [✓]  State + Notifier
  [✓]  View
```

**Generated structure:**

```
lib/features/auth/
├── domain/
│   ├── entities/auth_entity.dart
│   ├── repositories/auth_repository.dart
│   └── usecases/get_auth.dart          ← if selected
├── data/
│   ├── datasources/
│   │   ├── auth_remote_datasource.dart
│   │   └── auth_local_datasource.dart  ← if selected
│   ├── models/
│   │    └── auth_model.dart
│   └── repositories/
│       └── auth_repository_impl.dart
└── presentation/
    ├── states/auth_state.dart
    ├── notifiers/auth_notifier.dart
    ├── views/auth_view.dart
    └── widgets/
```

**State pattern used:**

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

Error handling in the view uses `state.value?.error` — your `AppException` message from the repository — not the `AsyncValue` error:

```dart
ref.listen(authNotifierProvider, (_, next) {
  final value = next.value;
  if (value?.error != null) {
    // show snackbar with value.error
  }
});
```

---

## Customizing moarch

All customization is in `lib/src/templates/` — edit the string inside any method to change what gets generated:

| File                     | Controls                                                      |
| ------------------------ | ------------------------------------------------------------- |
| `core_templates.dart`    | `main.dart`, `dio_client`, constants, errors, utils           |
| `config_templates.dart`  | theme                                                         |
| `shared_templates.dart`  | `app_button`, `app_loading`, `error_view`                     |
| `feature_templates.dart` | entity, model, datasources, repository, state, notifier, view |

After any change, re-activate:

```bash
dart pub global activate --source path /path/to/moarch
```

---

## License

MIT © [your name](https://github.com/your-username)
