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
moarch create entity-copys <featureName> # inject copyWith into the feature's entities (omit name for all features)
```

## What it generates

- `lib/main.dart`, `core/`, `config/`, `shared/`, and `features/`
- Riverpod + optional GoRouter setup
- Envied-based `.env` support
- secure storage, logger, helpers, and a full shared UI kit / design system (see below)
- optional services such as notifications (local or Firebase push), URL launcher, media, debounce
- optional localization: flutter_localizations (`lib/l10n/` + `.arb` files) or easy_localization (`assets/translations/` JSON files) — pick one, the checklist keeps them mutually exclusive

## Design system

`moarch init` scaffolds a themed widget library under `lib/shared/widgets/`, plus
design tokens (spacing, radius, a wired-up type scale, colors) in
`core/constants/app_constants.dart` and a light/dark `AppTheme`. Every control
shares one vocabulary — `variant` (primary/secondary/tertiary/danger), `type`,
`shape` and `size`.

- **Buttons** — `AppButton` with filled/outlined/ghost types, plus loading + disabled states
- **Inputs** — `AppInput` (with a built-in password eye), date/time pickers, dropdown,
  `AppCheckbox`, `AppSwitch`, `AppRadioGroup`, `AppSlider`, `AppSegmented`,
  `AppChoiceChip`, and `AppOtpInput` (powered by [mo_2fa_code](https://pub.dev/packages/mo_2fa_code))
- **Layout & content** — `AppListTile`, `AppCard`, `AppLeadingIcon`, `AppAvatar`,
  `AppImage`, `AppTag`, `AppBadge`
- **Feedback & overlays** — `AppToast`, confirm dialog, bottom sheet with a drag handle,
  `AppScreenLock` (PopScope + AbsorbPointer), loading overlay, skeleton list, error/empty views
- **Navigation** — `AppBottomNav`

A `DesignSystemView` screen is generated too — add it to your router to preview
every widget in light and dark. Set `AppConstants.fontFamily` (or swap in
`google_fonts`) to restyle the whole app's typography from one place.

## Local development

```bash
git clone https://github.com/SuperMoooo/moarch.git
cd moarch
dart pub global activate --source path ./
```

## License

MIT © André Montoito
