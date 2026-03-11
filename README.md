# 🧱 moarch

Flutter CLI — scaffold Clean Architecture projects with Riverpod and your own conventions. No code generation required.

---

## Install

```bash
dart pub global activate --source path /path/to/moarch
```

Make sure `~/.pub-cache/bin` is in your `PATH`. Add to `.zshrc` or `.bashrc`:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Verify it works:

```bash
moarch --version
```

After any change to `moarch` itself, re-run the activate command to pick up the changes.

---

## Setting up a new Flutter project

```bash
# 1. create the Flutter project (Empty Application in VS Code, or via CLI)
flutter create my_app
cd my_app

# 2. add required dependencies to pubspec.yaml (see below) then:
flutter pub get

# 3. delete the generated main.dart so moarch can write its own
rm lib/main.dart

# 4. scaffold the full structure
moarch init
```

---

## Required Flutter project dependencies

```yaml
dependencies:
    flutter:
        sdk: flutter
    flutter_riverpod: ^2.5.1
    dio: ^5.4.3
    flutter_dotenv: ^5.1.0
    flutter_secure_storage: ^9.2.2
```

Also add your `.env` to `pubspec.yaml` assets:

```yaml
flutter:
    assets:
        - .env
```

No `build_runner`, no `freezed`, no `riverpod_annotation` — everything generated compiles immediately.

---

## Commands

### `moarch init`

Scaffolds the full `lib/` structure and creates `.env` and `.fvmrc` at the project root.

```bash
moarch init
moarch init --path /path/to/my_app
```

```
.env                             ← BASE_URL=   (fill in your value)
.fvmrc                           ← { "flutter": "stable" }
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   ├── app_constants.dart   ← spacing, text sizes, touch targets, radii, durations
│   │   └── api_constants.dart   ← timeouts only (BASE_URL comes from .env)
│   ├── errors/
│   │   └── app_exception.dart
│   ├── network/
│   │   └── dio_client.dart      ← dotenv baseUrl, secure storage token, all status codes pass through
│   ├── usecases/
│   │   └── usecase.dart
│   └── utils/
│       ├── extensions.dart      ← ContextX, StringX, DateTimeX
│       └── logger.dart          ← single log() function, kDebugMode only
├── config/
│   └── theme/
│       └── app_theme.dart       ← useMaterial3 only, you fill in the rest
├── shared/widgets/
│   ├── app_button.dart
│   ├── app_loading.dart
│   └── error_view.dart
└── features/
```

---

### `moarch create feature <n>`

Interactive checklist — pick exactly the layers you need.

```bash
moarch create feature auth
moarch create feature user_profile
moarch create feature ProductCatalog    # any casing works

moarch create feature auth --all        # skip checklist, generate everything
```

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
│   ├── entities/auth_entity.dart             ← structure only, you add fields
│   ├── repositories/auth_repository.dart     ← abstract interface, you add methods
│   └── usecases/get_auth.dart                ← if selected
├── data/
│   ├── datasources/
│   │   ├── auth_remote_datasource.dart       ← provider + Dio, structure only
│   │   └── auth_local_datasource.dart        ← if selected
│   └── repositories/
│       └── auth_repository_impl.dart         ← provider, DioException → AppException comment
└── presentation/
    ├── states/auth_state.dart                ← isLoadingAction, error, success + safe copyWith
    ├── notifiers/auth_notifier.dart          ← AsyncNotifierProvider, example action commented
    ├── views/auth_view.dart                  ← async.when, ref.listen stub, no microtask
    └── widgets/
```

**State pattern:**

```dart
// copyWith resets to false/null when not passed — intentional:
// calling copyWith(isLoadingAction: true) clears error and success automatically
state.copyWith(isLoadingAction: true)           // loading, clears error+success
state.copyWith(error: e.message)                // sets error, resets loading
state.copyWith(success: 'Done!')                // sets success, resets loading

// In the view, listen for errors from state.value (your ApiException message)
// not from the AsyncValue error (which is an unhandled exception):
ref.listen(authNotifierProvider, (_, next) {
  final value = next.value;
  if (value?.error != null) { /* show snackbar */ }
});
```

---

## Customizing moarch

All customization is in `lib/src/` — no other files need to be touched.

**Change generated file content**
Open `lib/src/templates/` and edit the string inside the method you want to change:

```
core_templates.dart      ← main.dart, dio_client, constants, errors, utils
config_templates.dart    ← theme
shared_templates.dart    ← app_button, app_loading, error_view
feature_templates.dart   ← entity, model, datasources, repository, state, notifier, view
```

**Add a new file to every feature**

1. Add a method to `feature_templates.dart`
2. Call `FileUtils.writeFile(...)` for it in `create_command.dart`

**Add a new subcommand** (e.g. `moarch create widget <n>`)

1. Create `lib/src/commands/create_widget_command.dart`
2. Register with `addSubcommand(...)` in `create_command.dart`
