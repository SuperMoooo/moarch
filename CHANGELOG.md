# [2.1.0]

## Features

- UI kit expanded with nine widgets: `AppIconButton`, `AppAppBar`,
  `AppBanner`, `AppProgressBar`, `AppSearchField`, `AppStepper`,
  `AppSectionHeader`, `AppExpansionTile` and `AppStepIndicator`
- `AppDateInput` / `AppTimeInput` gained an `onChanged` callback — the picked
  value no longer has to be read back out of a controller
- `DesignSystemView` now previews the whole kit, including the widgets that had
  no section before (avatar, image, card tile, date/time, checkbox, empty view,
  loading overlay), and uses `AppAppBar` as its own chrome
- `moarch create widget button` emits the biometric-aware `AppButton` when the
  project has `core/security/biometric_service.dart`, matching `moarch init`
- `moarch init` now points at `build_runner`, which has to run before
  `config/env/app_env.g.dart` exists

## Fixes

- `moarch create widget` reported every file as created even when an existing
  file was left untouched; created and skipped are now listed separately
- generated `analysis_options.yaml` dropped the removed `strong-mode:
implicit-dynamic` analyzer option and is no longer emitted indented
- a scaffolded project now analyzes clean: removed unused imports in
  `AppSwitch` / `AppSlider`, fixed dangling doc comments that tripped
  `unintended_html_in_doc_comment`, added the missing `const`s in
  `DesignSystemView`, and replaced `(_, __, ___)` builder parameters
- `BiometricService.verifyUserLocalAuth` resolves its `ScaffoldMessenger`
  before awaiting the prompt instead of using the context afterwards
- `moarch init` backs up an existing `analysis_options.yaml` so a failed run
  restores it
- the `design-system` dependency list is derived from the catalog, so it can no
  longer drift out of date as widgets are added
