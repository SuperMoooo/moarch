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

moarch update        # refresh generated widgets against the current templates
moarch doctor        # check the project for common scaffolding issues
moarch doctor --fix  # ...and apply the ones that don't need a decision
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

### Phone numbers mask themselves, per country

`moarch create widget phone-input` adds `AppPhoneInput`: a field that punctuates
what is typed the way the selected country writes numbers, with a searchable
country picker built into its prefix.

```dart
AppPhoneInput(
  initialCountry: 'PT',
  onChanged: (number) => _phone = number.e164,   // '+351912345678'
)
```

The field holds only the *national* number — `912 345 678` in Portugal,
`(555) 010 9999` in the US — so the calling code can never be typed twice or
deleted by accident. Changing country re-masks what is already there instead of
clearing it.

It ships a table of **238 countries** (`AppCountry`), each carrying every shape
its numbering plan allows rather than one mask: Hungary takes 8 or 9 digits,
Germany 10 through 13, so the mask widens as the number grows. Validation holds
a number to those exact lengths — Armenia accepts 8 or 10 digits and refuses the
9 in between, which a generic 7-to-15 check would pass. Flags are derived from
the ISO code, so there are no assets to ship.

```dart
AppCountries.byIso('PT')!.format('912345678')  // '912 345 678'
AppCountries.split('+351912345678')            // (Portugal, '912345678')
AppCountries.initial = AppCountries.byIso('PT')!;  // move the default
```

Numbering plans are a good description of how numbers are *written*, not a
replacement for libphonenumber — validate server-side too if you need
carrier-level correctness.

### Long lists get a search instead of a menu

Any `AppDropdownInput` becomes searchable with one flag. A menu stops being
usable somewhere around thirty options; past that the field opens a
`SearchPickerSheet` — the same field, the same callback, a list you can type
into.

```dart
AppDropdownInput<CategoryEntity>(
  label: 'Category',
  items: categories,
  idOf: (c) => c.id,
  labelOf: (c) => c.name,
  searchable: true,
  onChanged: (id) => setState(() => _categoryId = id),
)
```

### One file decides how every input looks

`shared/widgets/inputs/app_input_config.dart` is the whole family's answer to
"where does the label go, and what does a field look like by default?" — read by
`AppInput`, the date/time/dropdown/OTP fields, and the checkbox, switch,
segmented, chips, radio, slider, stepper and search widgets alike.

Edit the literal in that file and you are done — no wiring, no `main()`:

```dart
// app_input_config.dart
static AppInputConfig defaults = const AppInputConfig(
  labelMode: AppInputLabelMode.floating,   // above | floating | placeholder | none
  type: AppInputType.outlined,
  shape: AppInputShape.pill,
  requiredMarker: ' (required)',
  autovalidateMode: AutovalidateMode.onUserInteraction,
);
```

It stays assignable for what a literal can't do — a flavor or white-label build
picking at startup (`AppInputConfig.defaults = ...` before `runApp`).

Any field still overrides it: `AppInput(label: 'Email', labelMode: AppInputLabelMode.above)`.

It also owns the numbers that used to be private constants — border widths, the
resting-border and fill opacities, and the font/icon/padding metrics behind
`small` / `medium` / `large`. What it deliberately does **not** own is color:
that comes from `ColorScheme` so it can differ between light and dark, and the
fill tint blends into the theme's `inputDecorationTheme.fillColor`. Raw sizes
stay in `AppConstants`; the config decides which token each input size picks.

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
  dropdown (searchable on request), checkbox, OTP, `AppSearchField`,
  `AppStepper` (quantity −/+), `AppPhoneInput` (per-country masking)
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

## Staying up to date

Generated code goes stale: the UI kit keeps improving, and a project scaffolded
two versions ago still has the old `app_input.dart`. `moarch update` closes that
gap without ever gambling with your edits.

```bash
moarch update                # refresh what's safe, review the rest
moarch update --dry-run      # report only, write nothing
moarch update --diff         # show what would change, line by line
moarch update input button   # limit it to specific widgets
```

It sorts every generated widget into one of three buckets:

| | |
| --- | --- |
| **up to date** | already matches the current template — nothing to do |
| **can be refreshed** | moarch wrote it, you never touched it, the template has since changed |
| **needs review** | the template changed *and* so did your copy — listed and diffed, never overwritten |

The distinction comes from `.moarch.yaml`, a manifest written at generation time
recording the moarch version, your init selections, and a hash of every file the
CLI wrote. **Commit it.** Without it moarch can't prove a file is untouched, so
it falls back to treating everything as needing review — safe, just less useful.

Nothing in the third bucket is written unless you pass `--force`, which discards
those edits. Run `git diff` after any update before committing.

> `update` covers the `lib/shared/widgets/` kit — the part that actually churns
> between releases. Features, core and config are yours once generated.

## Checking a project

`moarch doctor` looks for the things that break a scaffolded project in practice:

- `build_runner` never run, so `config/env/app_env.g.dart` doesn't exist yet
  (the most common first-run failure)
- both localization approaches installed, leaving `MaterialApp` with two
  competing sets of delegates
- a generated widget whose dependency or pub package was never added — a
  broken import either way
- `go_router` and `config/router/` out of sync

Each finding says what to do about it, and `moarch doctor --fix` applies the
mechanical ones — generating a missing widget dependency, adding a missing
package. Anything that's a genuine choice (which localization package to drop)
is reported and left to you.

## Local development

```bash
git clone https://github.com/SuperMoooo/moarch.git
cd moarch
dart pub global activate --source path ./
```

## License

MIT © André Montoito
