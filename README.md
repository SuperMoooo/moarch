# 🧱 moarch

Flutter CLI — scaffold Clean Architecture projects with Riverpod and your own conventions. No code generation required.

---

## Install

```bash
# from pub.dev (once published)
dart pub global activate moarch

# local development
dart pub global activate --source path /path/to/moarch
```

Make sure `~/.pub-cache/bin` is in your `PATH`.

---

## Required Flutter project dependencies

Only two runtime dependencies needed:

```yaml
dependencies:
    flutter_riverpod: ^2.5.1
    dio: ^5.4.3
```

No `build_runner`, no `freezed`, no `riverpod_annotation`, no `go_router` — everything generated compiles immediately.

---

## Commands

### `moarch init`

Scaffolds the full `lib/` structure in the current Flutter project.

```bash
moarch init
moarch init --path /path/to/my_app
```

```
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   ├── app_constants.dart   ← spacing, text sizes, padding helpers, radii, durations
│   │   └── api_constants.dart
│   ├── errors/
│   │   ├── app_exception.dart
│   │   └── failure.dart         ← sealed: Server / Network / Cache / Unknown
│   ├── network/
│   │   └── dio_client.dart      ← provider at top, auth interceptor stub
│   ├── usecases/
│   │   └── usecase.dart
│   └── utils/
│       ├── extensions.dart      ← ContextX, StringX, DateTimeX
│       └── logger.dart
├── config/
│   ├── env/env.dart
│   ├── router/app_router.dart   ← Navigator 2.0, no go_router
│   └── theme/app_theme.dart     ← Material 3 light + dark
├── shared/widgets/
│   ├── app_button.dart          ← filled / outlined / text variants
│   ├── app_loading.dart
│   └── error_view.dart
└── features/
```

---

### `moarch create feature <n>`

Interactive checklist to pick exactly what you need. Always generated: entity, view. Toggle on/off the rest.

```bash
moarch create feature auth
moarch create feature user_profile
moarch create feature ProductCatalog    # any casing works

moarch create feature auth --all        # skip checklist, generate everything
```

```
  Select layers for "Auth":
▶ [✓]  Remoarchte Datasource
  [ ]  Local/Cache Datasource
  [✓]  Repository (interface + impl)
  [ ]  Use Cases
  [✓]  State + Notifier
  [✓]  View
```

**Generated structure:**

```
lib/features/auth/
├── domain/
│   ├── entities/auth_entity.dart             ← plain immutable class + copyWith + ==
│   ├── repositories/auth_repository.dart     ← abstract interface
│   └── usecases/get_auth.dart                ← provider at top (if selected)
├── data/
│   ├── datasources/
│   │   ├── auth_remoarchte_datasource.dart       ← provider at top, manual fromJson
│   │   └── auth_local_datasource.dart        ← provider at top (if selected)
│   └── repositories/
│       └── auth_repository_impl.dart         ← provider at top, error handling
└── presentation/
    ├── states/auth_state.dart                ← sealed class (Dart 3 native)
    ├── notifiers/auth_notifier.dart          ← NotifierProvider at top
    ├── views/auth_view.dart                  ← ConsumerStatefulWidget + switch on state
    └── widgets/
```

---

## Design tokens (AppConstants)

```dart
// Spacing
AppConstants.spaceMd          // 16
AppConstants.spaceLg          // 24

// Padding shortcuts
AppConstants.paddingPage      // horizontal 24 + vertical 16
AppConstants.paddingMd        // EdgeInsets.all(16)
AppConstants.paddingPageH     // horizontal 24 only

// Text sizes
AppConstants.textMd           // 15
AppConstants.text2xl          // 24

// Border radius
AppConstants.borderRadiusMd   // BorderRadius.circular(12)
AppConstants.borderRadiusFull // BorderRadius.circular(999)

// Durations
AppConstants.animationNormal  // 300ms
```
