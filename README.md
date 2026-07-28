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
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # generates app_env.g.dart
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
moarch create entity-copys <featureName> # inject copyWith into the feature's entities (omit name for all features)
moarch create widget <name>        # add a UI-kit widget on demand (e.g. switch, otp, list-tile)
moarch create widget all           # generate the whole UI kit + the preview screen
moarch create widget --list        # list every available widget
```

## What it generates

- `lib/main.dart`, `core/`, `config/`, `shared/`, and `features/`
- Riverpod + optional GoRouter setup
- Envied-based `.env` support
- secure storage, logger, helpers, and a full shared UI kit / design system (see below)
- optional services such as notifications (local or Firebase push), URL launcher, media, debounce
- optional localization: flutter_localizations (`lib/l10n/` + `.arb` files) or easy_localization (`assets/translations/` JSON files) — pick one, the checklist keeps them mutually exclusive

### Input validation

`core/security/validation_service.dart` checks a value against an `InputType`
(email, url, phone, password, username, number, creditCard, cardExpiry, cvv,
filePath, text) and hands back the cleaned form. It is what `AppInput` calls, and
what `AppInputFormat` maps onto.

It deliberately does **not** blocklist SQL keywords and does **not** HTML-escape
what it returns: `O'Brien` is a name, `Create the report` is a note, and escaping
on the way in is how `Tom & Jerry` ends up stored as `Tom &amp; Jerry`. Injection
belongs to parameterised queries on the server; escaping belongs to
`ValidationService.escapeHtml` at the point you build HTML. What it does enforce
is scoped: shape per type, control characters stripped everywhere, markup in free
text, path traversal in a file path, and an http/https allowlist on a URL.

The password rule is one assignment at startup:

```dart
ValidationService.passwordPolicy = PasswordPolicy.lengthOnly;      // 12+ chars
ValidationService.passwordPolicy = const PasswordPolicy(minLength: 8);
```

### Extensions

`core/utils/extensions.dart` carries the small helpers every screen reaches for:
`context.theme` / `colorScheme` / `isDarkMode` / `isTablet` / `isKeyboardOpen` /
`unfocus()`, string helpers (`initials`, `capitalizeWords`, `truncate`,
`withoutDiacritics`, `searchKey`, `matchesSearch`, `isBlank`, `digitsOnly`),
date and time helpers (`startOfDay`, `endOfMonth`, `isTomorrow`, `yearsSince`,
`format(pattern)`, `timeAgo()`, `TimeOfDay.onDate`), `Duration.formatted`, and
number formatting (`formatCurrency`, `formatDecimal`, `formatCompact`,
`formatPercent`) — alongside the `formattedDateToDatabase` /
`formatedDateTimeToDatabase` pair the API layer uses.

## Design system

`moarch init` sets up the design foundation — tokens (spacing, radius, a wired-up
type scale, colors) in `core/constants/app_constants.dart`, a light/dark `AppTheme`,
and a **lean common set** of widgets under `lib/shared/widgets/`: inputs (`AppInput`,
`AppInputFormat`, `AppInputStyle`, `InputTitle`), `AppButton`, `AppLeadingIcon`, the
state screens (`ErrorView`, `EmptyView`, `AppLoadingData`) and overlays (`AppToast`,
`AppConfirmDialog`, dialog/bottom-sheet helpers).

`AppInput` is driven by an `AppInputFormat`: one enum that picks the keyboard, the
input formatters that shape the value as it is typed, the autofill hints and the
validation rule together.

```dart
AppInput(label: 'Amount', format: AppInputFormat.money)      // 1,234.50
AppInput(label: 'Card', format: AppInputFormat.creditCard)   // 4111 1111 1111 1111
AppInput(label: 'Expiry', format: AppInputFormat.cardExpiry) // 12/25

AppInputFormat.money.unformat(controller.text)               // '1234.50'
```

Everything else in the kit is one command away, catalogued in the generated
`docs/UI_KIT.md`:

```bash
moarch create widget switch        # AppSwitch (+ any widgets it depends on)
moarch create widget otp           # AppOtpInput (adds the mo_2fa_code package)
moarch create widget all           # the whole kit + the DesignSystemView preview
moarch create widget --list        # print the catalog in the terminal
```

Widget dependencies are pulled in automatically, and any pub package a widget needs
([mo_2fa_code](https://pub.dev/packages/mo_2fa_code) for OTP, `cached_network_image`
for avatars/images) is added to `pubspec.yaml`.

The kit covers:

- **inputs** — switch, segmented, choice chips, radio group, slider, date/time,
  dropdown, checkbox, OTP, `AppSearchField`, `AppStepper` (quantity −/+)
- **buttons & icons** — `AppButton`, `AppLeadingIcon`, `AppIconButton`
- **layout** — `AppListTile`, `AppCard`, `AppCardTile`, `AppTag`, `AppBadge`,
  `AppSectionHeader`, `AppExpansionTile`
- **feedback** — `AppBanner`, `AppProgressBar`, `AppScreenLock`, skeleton list,
  loading overlay, `ErrorView`, `EmptyView`
- **media** — `AppAvatar`, `AppImage`
- **navigation** — `AppAppBar`, `AppBottomNav`, `AppStepIndicator`

Every control shares one vocabulary — `variant`, `type`, `shape`, `size` — and
`moarch create widget design-system` (or `all`) generates a screen previewing them
all in light/dark. Set `AppConstants.fontFamily` (or swap in `google_fonts`) to
restyle the whole app's typography from one place.

## Local development

```bash
git clone https://github.com/SuperMoooo/moarch.git
cd moarch
dart pub global activate --source path ./
```

## License

MIT © André Montoito
