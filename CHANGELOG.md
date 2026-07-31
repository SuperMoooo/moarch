# [2.7.0]

## Features

- `AppAudioPlayer` (`moarch create widget audio-player`) — an audio player over
  [just_audio](https://pub.dev/packages/just_audio) that a screen configures
  rather than wires. It owns the `AudioPlayer`, loads the source and disposes
  both. One `AppAudioSource` covers url, asset and file.
  - **Every part is a switch**, so the same widget is a podcast screen and a
    voice-note bubble: `showControls`, `showSkip`, `showProgress`, `allowScrub`,
    `showTimes`, `showRemaining` and `showSpeed` are independent, and
    `AppAudioPlayerStyle.compact` is the one-row arrangement.
  - The skip buttons take **durations, not a fixed 15/30** — the number is drawn
    inside the arrow, so any interval works without an icon per value.
  - Buffered progress rides in the bar's secondary track; a scrub is not dragged
    back by the position stream mid-drag; a finished clip restarts on the next
    tap rather than sitting at the end; and `onCompleted` fires once per
    play-through rather than on every frame the player sits in `completed`.
- `AppDragSection` (`moarch create widget drag-section`) — a section whose
  children drag into a new order, vertical or horizontal, with no dependency.
  - It **reports the move rather than owning the list**, so the order can live
    in a notifier, in storage or on a server without the widget holding a
    second copy of it. `AppDragSection.reorder` does the remove-and-insert.
  - Each item declares its own size — `AppDragSize.small/medium/large` off a
    shared `AppDragSizes`, or an exact `extent` — and whether it can be moved.
  - **A pinned item is a wall**, not merely un-draggable: it carries no drag
    listener at all, and nothing can be dropped past it, so an "add" tile keeps
    the last slot however the rest are shuffled.
  - `onReorder` arrives already corrected for the `ReorderableListView`
    off-by-one and for any pinned item in the way.
  - A long press starts the drag, because an immediate listener over the whole
    item fights the scroll; `AppDragTrigger.handle` puts a grip on the trailing
    edge instead.
- `AppTable` (`moarch create widget table`) — rows and columns sized for a
  phone, with no dependency.
  - Columns are fixed (`width`) or flexible (`flex`), and a flexible one never
    squeezes below its `minWidth`. Past the point where the minimums no longer
    fit, the table **pans sideways** rather than crushing the columns.
  - `AppTableColumn.numeric` right-aligns and switches on tabular figures.
  - Rows take `onTap`, `selected` and a colour of their own; `striped`,
    `showRowDividers`, `showColumnDividers`, `showBorder` and `density` decide
    the rest. Cells are strings, or `widgets` for a chip or an avatar.
  - It deliberately **owns no vertical scroll** — a table that scrolls
    vertically cannot sit in a page that also does. Put it in
    `AppSingleScrollView` or a `ListView`.
- `AppCountryPicker` (`moarch create widget country-picker`) — the 238-country
  `AppCountry` table as a field of its own, validating like the rest of the
  family, or as `AppCountryPicker.show(context)` from anywhere that is not a
  form.
  - It hands back the whole `AppCountry` rather than a code, since the caller
    usually wants the dial code or the flag too. `display` picks what the closed
    field reads as, and `countries` narrows the list.

## Improvements

- **The country sheet is configured in one place.** `AppPhoneInput` carried its
  own `SearchPickerSheet` setup — the flag leading each row, the calling code
  trailing it, the ranked search that makes `PT` find Portugal rather than the
  first name containing those letters. That configuration now lives in
  `AppCountryPicker.show`, and the phone field opens it, so a standalone country
  field and a phone prefix cannot drift apart. `phone-input` gains
  `country-picker` as a dependency; the search sheet still arrives with it.
