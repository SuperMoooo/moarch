# [2.6.0]

## Features

- `AppCalendar` (`moarch create widget calendar`) — the inline month grid, for
  when the month itself is the content rather than one answer in a form.
  `AppDateInput` still opens the platform picker; this is its sibling for
  agendas, booking screens and streaks. A wrapper over
  [table_calendar](https://pub.dev/packages/table_calendar) that keeps its
  parameters out of your screens: colors come from `AppInputVariant` like the
  rest of the family, and the package is added to `pubspec.yaml` for you.
  - `events` is **re-keyed to the day** each entry falls on. Two `DateTime`s in
    one day are not equal, which is the usual reason a marker never appears —
    so you can pass the instants your data already carries, and two
    appointments at 09:00 and 14:00 count as two dots on one day rather than
    missing the grid.
  - `onMonthChanged` reports the month's own bounds, not the six weeks drawn
    around it — the range to fetch events for. For the two-week and week
    formats it reports their own span.
  - `canChangeFormat` offers the month/2-week/week toggle, and only then is a
    vertical swipe live; without it a swipe means one thing.
  - No `onSelected` makes it a read-only display, and `selectableDay` greys out
    the days that refuse a tap.
  - It lives in its own `lib/shared/widgets/calendar/` folder rather than
    alongside the fields.
- `AppActionSheet` (`moarch create widget action-sheet`) — the sheet behind a
  three-dot button or a long press. Material rows on Android and the iOS
  grouped cards elsewhere, off the same platform split `AppDateInput` uses for
  its pickers; either shape can be forced.
  - Rows resolve to a value, so `show<T>` hands back what was picked and `null`
    when it was dismissed — one honest "the user backed out" branch.
  - A row's `onTap` runs **after** the sheet has closed, rather than while it
    is closing, where a handler that pushes a route fights the navigator for
    it.
  - `AppSheetAction.destructive` draws in the theme's error color. It confirms
    nothing on its own — pair it with `AppConfirmDialog` when the answer should
    be deliberate.
  - It takes a `BuildContext` rather than the router's navigator key, unlike
    `AppDialogs` and `AppBottomModals`, so it costs the project no GoRouter.

## Fixes

- **`moarch create model --empty` generated a factory that could not compile.**
  It patches `<model>_entity.dart`, whose class is `<Model>Entity`, but named the
  factory after the model alone — `factory LoginResponse.empty() =>
  LoginResponse(...)` inside `class LoginResponseEntity`. The guard that was
  meant to stop a second run looked for that same wrong name, so it never
  matched and every re-run stacked another broken factory into the file.
- **A field whose type carries a comma was silently dropped** from `.empty()`
  and from `copyWith`. The type was matched with a character class holding
  neither a comma nor a space, so `Map<String, dynamic> meta;` was not a field
  as far as the parser was concerned — and the factory it built came out missing
  a required argument. Types are now read up to the last identifier on the line
  and then validated, which also ends the false positives that class allowed:
  `return value;` in a method body was being read as a field named `value` of
  type `return`, and `String get title;` as a field named `title`.
- **An entity file declaring a second class had the two spliced together.** The
  parser took a class name and ignored it, reading every field in the file, so
  `AddressEntity`'s fields turned up in `UserEntity`'s `copyWith`. It now scopes
  to the named class's body — and so does the injection: `create entity-copys`
  appended `copyWith` and the `==` / `hashCode` pair at the file's *last* closing
  brace, landing them on whichever class was written last, after stripping the
  existing equality members from every class in the file.
- **`create empty-factories` reported replacements it had not made.** Its
  pattern only matches an arrow-bodied `.empty()`, so a hand-written block-bodied
  one fell through `replaceFirst` unchanged while the log claimed it had been
  replaced. It now leaves that factory alone and says so, and a factory already
  matching what would be written is reported as skipped — which is what the
  `Skipped :` line in the summary always claimed to count and never did.
