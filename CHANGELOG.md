# [2.3.0]

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
- `AppDropdownInput(searchable: true)` — swaps the menu for that sheet. Same
  widget, same callback; the menu form is unchanged.
- `moarch update` — refreshes generated UI-kit widgets against the current
  templates. Files you never touched are refreshed automatically; files you
  edited are listed, diffed and left alone unless you pass `--force`.
- `.moarch.yaml` — a manifest written by `init` and `create widget` recording
  the moarch version, the selected stack and a hash of every generated file.
  It is what lets `update` tell an untouched file from an edited one.
- `moarch doctor --fix` — applies the fixes that don't need a decision.

## Improvements

- `moarch doctor` now checks what the scaffold actually depends on: whether
  `build_runner` has generated `app_env.g.dart`, whether both localization
  approaches ended up installed, whether every generated widget's
  dependencies and pub packages are present, and whether router-dependent
  widgets have a router. Findings carry hints, and say which are fixable.
