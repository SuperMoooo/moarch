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

## Design system

`moarch init` sets up the design foundation — tokens (spacing, radius, a wired-up
type scale, colors) in `core/constants/app_constants.dart`, a light/dark `AppTheme`,
and a **lean common set** of widgets under `lib/shared/widgets/`: inputs (`AppInput`,
`AppInputStyle`, `InputTitle`), `AppButton`, `AppLeadingIcon`, the state screens
(`ErrorView`, `EmptyView`, `AppLoadingData`) and overlays (`AppToast`,
`AppConfirmDialog`, dialog/bottom-sheet helpers).

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

The kit covers inputs (switch, segmented, choice chips, radio group, slider,
date/time, dropdown, checkbox, OTP), layout (`AppListTile`, `AppCard`, `AppTag`,
`AppBadge`), feedback (`AppScreenLock`, skeleton list, loading overlay), media
(`AppAvatar`, `AppImage`) and navigation (`AppBottomNav`). Every control shares one
vocabulary — `variant`, `type`, `shape`, `size` — and `moarch create widget
design-system` (or `all`) generates a screen previewing them all in light/dark. Set
`AppConstants.fontFamily` (or swap in `google_fonts`) to restyle the whole app's
typography from one place.

## Local development

```bash
git clone https://github.com/SuperMoooo/moarch.git
cd moarch
dart pub global activate --source path ./
```

## License

MIT © André Montoito
