# [2.4.0]

## Features

- `AppPhoneInput` (`moarch create widget phone-input`) — a phone field that
  masks what is typed for the country it is set to, with a searchable country
  picker in its prefix. The field holds only the national number, so the
  calling code cannot be typed twice or deleted; read the joined-up value from
  `AppPhoneNumber.e164`. Changing country re-masks the existing digits rather
  than clearing them.
- `AppCountry` (`moarch create widget country`) — a table of 238 countries with
  ISO code, calling code and every mask their numbering plan allows. Plans with
  more than one shape are kept as a list, so the mask widens as the number grows
  (Hungary 8–9 digits, Germany 10–13), and validation holds a number to those
  exact lengths instead of a 7-to-15 range. Flags are derived from the ISO code,
  so no assets ship with it.
- `SearchPickerSheet` (`moarch create widget search-sheet`) — a bottom sheet
  that picks one row out of a long list, with a search field above it. Opens
  scrolled to the current selection.
- `AppDropdownInput` — swaps the menu for that sheet once the list passes
  `AppInputConfig.searchableThreshold` (30), which `searchable: true`/`false`
  overrules per field. Both forms now validate: `required: true` is enforced by
  `Form.validate()` rather than only marking the label, and `validator` /
  `autovalidateMode` work as they do on `AppInput`. Also gains `onSelected`
  (the picked entity, not just its id), `onCleared` (which puts a clear button
  in the field), and the sheet's `leadingOf`, `trailingLabelOf`, `filter` and
  `emptyLabel`.
- `moarch update` — refreshes generated UI-kit widgets against the current
  templates. Files you never touched are refreshed automatically; files you
  edited are listed, diffed and left alone unless you pass `--force`.
- `.moarch.yaml` — a manifest written by `init` and `create widget` recording
  the moarch version, the selected stack and a hash of every generated file.
  It is what lets `update` tell an untouched file from an edited one.
- `moarch doctor --fix` — applies the fixes that don't need a decision.

## Fixes

- `AppDateInput` / `AppTimeInput` showed nothing without a caller-supplied
  controller: every value, `initialValue` and each picked one alike, was written
  only to `widget.controller?.text`. They now own a controller when none is
  passed (and dispose it), so the simplest possible usage displays its value.
  A controller that already holds text is no longer overwritten by
  `initialValue` either — the caller's value wins, as it does on `AppInput`.
- `required: true` on `AppDateInput` and `AppTimeInput` only drew an asterisk;
  `Form.validate()` passed an empty field. Both now validate, and take a
  `validator` / `autovalidateMode` like the rest of the family.
- `AppLoadingActionOverlay` started its message timers only on a false-to-true
  change, so a screen that mounted with a request already in flight showed a
  bare spinner forever. They now start in `initState` too.
- `AppSegmented` and `AppChoiceChip` drew their selected foreground in
  `colorScheme.surface`, which is only the right answer in a light theme. Both
  now use the new `AppInputStyle.onAccentOf`, which `AppCheckbox` and
  `AppSwitch` share.

## Improvements

- Selection controls validate. `AppCheckboxLabel(required: true)` is the
  "accept the terms" checkbox a `Form` can enforce, and
  `AppRadioGroup(required: true)` refuses to validate until one option is
  chosen. Both render the error under the control through the new
  `SelectionFormField`, which is exposed for wrapping any control of your own.
- `AppSegmented` and `AppRadioGroup` assert that the current selection is
  actually one of the options, instead of silently rendering with nothing
  highlighted.
- `AppCheckboxLabel`, `AppRadioGroup`, `AppSegmented` and `AppChoiceChip` all
  take a null callback to disable themselves, matching `AppCheckbox`,
  `AppSwitch`, `AppSlider` and `AppStepper`. `AppDateInput` and `AppTimeInput`
  gain `enabled` alongside their existing `readOnly`.
- `AppStepper`'s − and + carry tooltips and semantics, and meet the 48px
  minimum tap target.

- `moarch doctor` now checks what the scaffold actually depends on: whether
  `build_runner` has generated `app_env.g.dart`, whether both localization
  approaches ended up installed, whether every generated widget's
  dependencies and pub packages are present, and whether router-dependent
  widgets have a router. Findings carry hints, and say which are fixable.
