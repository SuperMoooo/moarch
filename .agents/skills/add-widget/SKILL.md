---
name: add-widget
description: "Add a widget to moarch's UI kit (what `moarch create widget` generates): the template, its WidgetSpec, dependencies, the design-system preview and tests. Use for any new or changed widget under lib/shared/widgets/ in generated projects."
---

# Add a UI-kit widget

## Steps

1. **The template** — a static function in `lib/src/templates/ui/` (the
   file for its family, or a new `<family>_templates.dart`). The generated
   widget follows the rules it asks of app code: sizes, spacing, radii and
   durations from `AppConstants`, colors from `Theme.of(context).colorScheme`
   (and `context.statusColors` for success / warning / info), private widget
   classes rather than `_buildX()` methods, `const` constructors.

2. **The spec** — a `WidgetSpec` in `WidgetCatalog` (`utils/widget_catalog.dart`):
   - `name` — the CLI slug, unique across widget *and* scaffold slugs.
   - `title` (the class), `file` (relative to `lib/shared/widgets/`),
     `category` from `WidgetCatalog.categories`, a one-line `description`.
   - `deps` — other kit widgets it imports; `create widget` pulls them in.
   - `packages` — pub entries it needs; add each package's constraint to
     `PackageVersions` (`utils/package_versions.dart`).
   - `variantTemplate` — only if it varies with the project; the variant is
     detected by a `WidgetVariants` getter, never passed in.
   - `common` if `init` generates it; `needsRouter` if it imports the
     router; `stacks` if it exists for one stack only.
   - Never join `shared/widgets` by hand: `spec.pathIn(libPath)` /
     `spec.libFile`. A widget that moved carries `movedFrom`.

3. **The preview** — render it in the design-system screen
   (`SharedTemplates.designSystemView`), or add it to `_notPreviewed` in
   `test/widget_catalog_test.dart` with the reason. The test fails otherwise.

4. **Tests** — assert on the generated source in the family's
   `test/<family>_templates_test.dart`. `widget_catalog_test.dart` already
   checks that every relative import resolves to a file moarch generates.

5. **Docs** — `docs/UI_KIT.md` in generated projects is built from the
   catalog, so it needs nothing. Mention a notable widget in `README.md` and
   `CHANGELOG.md`.

## Done when

```bash
dart format .
dart analyze --fatal-infos
dart test
```

Then `try-scaffold` with `moarch create widget <name>` on the scaffolded
project, so the widget is seen to compile.
