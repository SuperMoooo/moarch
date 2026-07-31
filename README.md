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
state screens (`AppAsyncView`, `ErrorView`, `EmptyView`, `AppLoadingData`) and
overlays (`AppToast`, `AppConfirmDialog`, dialog/bottom-sheet helpers).

`AppInput` is driven by an `AppInputFormat`: one enum that picks the keyboard, the
input formatters that shape the value as it is typed, the autofill hints and the
validation rule together.

```dart
AppInput(label: 'Amount', format: AppInputFormat.money)      // 1,234.50
AppInput(label: 'Card', format: AppInputFormat.creditCard)   // 4111 1111 1111 1111
AppInput(label: 'Expiry', format: AppInputFormat.cardExpiry) // 12/25

AppInputFormat.money.unformat(controller.text)               // '1234.50'
```

### A screen describes its content once

Every generated feature used to hand-roll the same mapping: `.when(...)`, a
`Skeletonizer` over a nullable body, an `ErrorView`, and a `ref.listen` with
`// SHOW UI ERROR` left in it. `AppAsyncView` and `ref.listenAction` are that
mapping, so the view is only the part that differs:

```dart
@override
Widget build(BuildContext context) {
  ref.listenAction<OrdersState>(
    context,
    ordersNotifierProvider,
    errorOf: (state) => state.error,
    successOf: (state) => state.success,
  );

  return Scaffold(
    appBar: AppAppBar(title: 'Orders'),
    body: AppAsyncView<OrdersState>(
      value: ref.watch(ordersNotifierProvider),
      onRetry: () => ref.invalidate(ordersNotifierProvider),
      isEmpty: (state) => state.orders.isEmpty,
      skeleton: _body(context, const OrdersState()),   // the shape, shimmered
      builder: _body,
    ),
  );
}
```

`AppAsyncView` draws whichever of the four states the value is in, and **a reload
does not blank the screen**: once there is data, a later loading or error state
leaves it on screen instead of replacing a list mid-read with a spinner. It
builds inline, so the `Scaffold` keeps its app bar throughout. An error that
carries no message of its own shows no detail — a stringified exception tells the
user nothing and leaks how the app is put together.

`listenAction` reads the one-shot `error` / `success` fields the generated state
already clears on every `copyWith`, and toasts whichever arrived — one outcome
per action, never both. Pass `onError` / `onSuccess` to navigate or log instead;
that *replaces* the toast, so a screen that pops on success does not also flash a
message on the way out.

Both are part of `moarch init`, and `moarch create feature` writes them into an
older project rather than generating a view that cannot compile.

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

### When the month is the content, not an answer in a form

`AppDateInput` opens the platform picker, which is what a date-shaped *field*
wants. An agenda, a booking screen or a streak wants the grid itself, and that
is `moarch create widget calendar` — a wrapper over
[table_calendar](https://pub.dev/packages/table_calendar) that keeps its sixty
parameters out of your screens.

```dart
AppCalendar(
  selected: _day,
  events: {for (final a in appointments) a.startsAt: 1},   // dots under the day
  onSelected: (day) => setState(() => _day = day),
  onMonthChanged: (first, last) => ref.read(p.notifier).load(first, last),
)
```

Two `DateTime`s in the same day are not equal, which is the usual reason a
marker never appears — so `events` is **re-keyed to the day** each entry falls
on. Pass the instants your data already carries; two appointments at 09:00 and
14:00 count as two dots on one day rather than missing the grid entirely.

`onMonthChanged` reports the *month's* own bounds, not the six weeks drawn
around it — the range you actually want to fetch events for. Colors come from
`AppInputVariant` like the rest of the family, `canChangeFormat` offers the
month/2-week/week toggle (and only then is a vertical swipe live), and leaving
`onSelected` off makes it a read-only display.

### One sheet for "what do you want to do with this?"

`moarch create widget action-sheet` adds `AppActionSheet` — the thing behind a
three-dot button or a long press. Material rows on Android, the iOS grouped
cards everywhere else, off the same split `AppDateInput` uses for its pickers.

```dart
final picked = await AppActionSheet.show<String>(
  context,
  title: 'Order #1042',
  actions: [
    const AppSheetAction(label: 'Edit', icon: Icons.edit_outlined, value: 'edit'),
    const AppSheetAction(label: 'Share', icon: Icons.ios_share, value: 'share'),
    const AppSheetAction.destructive(
      label: 'Delete',
      icon: Icons.delete_outline,
      value: 'delete',
    ),
  ],
);
```

Dismissing resolves to `null`, so a `switch` on the result has one honest "the
user backed out" branch. A row can carry an `onTap` instead of a `value`, and
it runs **after** the sheet has closed — a handler that pushes a route while
the sheet is still closing otherwise fights the navigator for it. Destructive
rows are drawn in the theme's error color and confirm nothing on their own:
pair one with `AppConfirmDialog` when the answer should be deliberate.

Unlike `AppDialogs` and `AppBottomModals` it takes a `BuildContext` rather than
the router's navigator key, so it costs the project no GoRouter.

### Audio you configure rather than wire

`moarch create widget audio-player` adds `AppAudioPlayer` over
[just_audio](https://pub.dev/packages/just_audio). It owns the `AudioPlayer`,
loads the source and disposes both, so a screen never holds a controller.

```dart
AppAudioPlayer(
  source: const AppAudioSource.url('https://example.com/episode.mp3'),
  title: 'Episode 12',
  showSpeed: true,
)
```

**Every part is a switch**, which is what makes one widget serve a podcast
screen and a voice note in a chat bubble:

```dart
AppAudioPlayer(
  source: AppAudioSource.file(recording.path),
  style: AppAudioPlayerStyle.compact,   // one row
  showSkip: false,                      // a 6-second note has nothing to skip
  showSpeed: false,
  showRemaining: true,                  // -0:04 rather than the total
)
```

`showControls`, `showProgress`, `allowScrub`, `showTimes` and `showSpeed` are
independent, and the skip buttons take **durations rather than a fixed 15/30** —
the number is drawn inside the arrow, so any interval works without an icon per
value:

```dart
AppAudioPlayer(
  source: ...,
  skipBackward: const Duration(seconds: 10),
  skipForward: const Duration(seconds: 10),
)
```

Buffered progress rides in the bar's secondary track, a scrub is not dragged
back by the position stream mid-drag, and a finished clip restarts on the next
tap rather than sitting at the end. It plays audio and nothing else — the same
split `just_audio` makes; lock-screen controls are `just_audio_background`'s
job and adding it changes nothing here.

### Children you can drag into a new order

`moarch create widget drag-section` adds `AppDragSection`. It reports the move
and nothing else — the list stays yours, so it can live in a notifier, in
storage, or on a server without the widget holding a second copy of the truth.

```dart
AppDragSection(
  items: [
    for (final card in _cards)
      AppDragItem(id: card.id, child: DashboardCard(card)),
  ],
  onReorder: (from, to) => setState(
    () => _cards = AppDragSection.reorder(_cards, from, to),
  ),
)
```

Each item says how big it is and whether it moves; the section says which way
it runs:

```dart
AppDragSection(
  orientation: Axis.horizontal,
  items: [
    AppDragItem(id: 'a', size: AppDragSize.large, child: ChartCard()),
    AppDragItem(id: 'b', size: AppDragSize.small, child: TotalCard()),
    AppDragItem(id: 'new', draggable: false, child: AddTile()),   // pinned
  ],
  onReorder: _move,
)
```

**A pinned item is a wall, not just an item that cannot be picked up** —
nothing can be dropped past it, so the "add" tile above keeps the last slot
however the rest are shuffled. `AppDragSize.small/medium/large` come from
`AppDragSizes` (retune the whole section at once), or give one item an exact
`extent`.

A long press starts the drag by default, because an immediate listener over the
item's whole surface fights the scroll; `trigger: AppDragTrigger.handle` puts a
grip on the trailing edge instead, for an item that is already tappable.

`onReorder` hands you indices **already corrected** for both the
`ReorderableListView` off-by-one and any pinned item in the way, and
`AppDragSection.reorder` does the remove-and-insert.

### A table that fits a phone

`moarch create widget table` adds `AppTable` — no dependency, and sized for a
screen narrower than the data.

```dart
AppTable(
  columns: const [
    AppTableColumn(label: 'Item', flex: 2),
    AppTableColumn.numeric(label: 'Qty', width: 56),
    AppTableColumn.numeric(label: 'Total'),
  ],
  rows: const [
    AppTableRow(cells: ['Coffee', '2', '€7.00']),
    AppTableRow(cells: ['Pastry', '1', '€2.40']),
  ],
  footer: const AppTableRow(cells: ['Total', '3', '€9.40']),
)
```

Columns are fixed (`width`) or flexible (`flex`), and a flexible one never
squeezes below its `minWidth`. Past the point where the minimums no longer fit,
**the table pans sideways** instead of crushing the columns further.

`AppTableColumn.numeric` right-aligns and switches on tabular figures, so a
column of money reads down cleanly. Rows take `onTap`, `selected` and a colour
of their own; `striped`, `showRowDividers`, `showColumnDividers`, `showBorder`
and `density` decide the rest. Cells are strings by default, or pass `widgets`
for a chip or an avatar.

It deliberately **does not scroll vertically** — a table that owns a vertical
scroll cannot sit in a page that also scrolls without one of them being wrong.
Drop it into `AppSingleScrollView` or a `ListView`.

### One country list, two ways in

`moarch create widget country-picker` adds `AppCountryPicker` over the same
238-country `AppCountry` table `AppPhoneInput` reads. As a field:

```dart
AppCountryPicker(
  label: 'Country',
  selectedIso: _iso,
  required: true,
  onChanged: (country) => setState(() => _iso = country.iso),
)
```

Or as a sheet on its own, from anywhere that is not a form:

```dart
final country = await AppCountryPicker.show(context, selectedIso: _iso);
```

`show` is **the single place the country sheet is configured** — the flag
leading each row, the calling code trailing it, and the ranked search that makes
`PT` find Portugal rather than the first country whose name contains those
letters. `AppPhoneInput` now opens that same sheet for its prefix instead of
carrying its own copy, so the two cannot drift apart.

It hands back the whole `AppCountry` rather than a code, since the caller
usually wants the dial code or the flag too. `display` picks what the closed
field reads as — `🇵🇹 Portugal`, the name alone, `🇵🇹 +351`, or just the flag —
and `countries` narrows the list to the ones you ship to.

### Long lists get a search instead of a menu

A menu stops being usable somewhere around thirty options, so past that an
`AppDropdownInput` opens a `SearchPickerSheet` instead — the same field, the
same callback, a list you can type into. It counts its own options and decides;
`searchable: true` or `false` overrules it for one field, and
`AppInputConfig.searchableThreshold` moves the line for the whole app.

```dart
AppDropdownInput<CategoryEntity>(
  label: 'Category',
  items: categories,
  idOf: (c) => c.id,
  labelOf: (c) => c.name,
  required: true,
  selectedId: _categoryId,
  onChanged: (id) => setState(() => _categoryId = id),
  onSelected: (category) => _prefillFrom(category),
  onCleared: () => setState(() => _categoryId = null),
)
```

Either form is a real form field: `required: true` is rejected by
`Form.validate()`, and `validator` replaces the rule.

`AppMultiSelectInput` is the same field in the plural — the same entity list,
the same sheet with a checkbox on every row, and a `maxSelected` the sheet
enforces as you tick rather than leaving to the form to refuse afterwards:

```dart
AppMultiSelectInput<TagEntity>(
  label: 'Tags',
  items: tags,
  idOf: (t) => t.id,
  labelOf: (t) => t.name,
  selectedIds: _tagIds,
  maxSelected: 3,
  required: true,
  onChanged: (ids) => setState(() => _tagIds = ids),
)
```

It hands back the whole selection in `items` order, and shows it as removable
chips, as labels, or as "3 selected".

### `required` means the form actually refuses

Every input that takes `required` enforces it — the text, phone, dropdown, date
and time fields, and the controls that carry a selection rather than text:

```dart
AppCheckboxLabel(
  label: 'Accept the terms',
  value: _accepted,
  required: true,          // Form.validate() fails until it is ticked
  onChanged: (v) => setState(() => _accepted = v),
)

AppRadioGroup<Plan>(
  values: Plan.values,
  groupValue: _plan,
  labelOf: (p) => p.name,
  required: true,          // ...until one is chosen
  onChanged: (p) => setState(() => _plan = p),
)
```

A checkbox has no border to turn red and no helper line to explain itself, so
these render the message underneath through `SelectionFormField` — which is
exposed, if you want to put a control of your own into a form the same way.

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
  date range, dropdown (searchable on request), multi-select, checkbox, OTP,
  rating, file picker, `AppSearchField`, `AppStepper` (quantity −/+),
  `AppPhoneInput` (per-country masking), `AppCalendar` (inline month),
  `AppCountryPicker` (238 countries)
- **overlays** — `AppActionSheet` (platform-shaped), `AppToast`,
  `AppConfirmDialog`, `AppBottomSheetScaffold`, dialog/bottom-sheet helpers
- **buttons & icons** — `AppButton`, `AppLeadingIcon`, `AppIconButton`, `AppFab`
- **layout** — `AppListTile`, `AppCard`, `AppCardTile`, `AppTag`, `AppBadge`,
  `AppSectionHeader`, `AppExpansionTile`, `AppTimeline`, `AppTable`,
  `AppDragSection`
- **feedback** — `AppAsyncView`, `ref.listenAction`, `AppBanner`,
  `AppProgressBar`, `AppScreenLock`, skeleton list, loading overlay,
  `ErrorView`, `EmptyView`
- **media** — `AppAvatar`, `AppImage`, `AppCarousel`, `AppAudioPlayer`
- **navigation** — `AppAppBar`, `AppBottomNav` (Material 3, classic, pill or
  dot, each of which can float), `AppTabs`, `AppDrawer`,
  `AppNavRail` / `AppAdaptiveNav`, `AppStepIndicator`

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
