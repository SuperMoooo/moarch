import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Widgets the preview screen deliberately does not import, and why.
///
/// The design-system screen is hand-written, so a new catalog entry does not
/// appear in it on its own — this list is what makes that a decision rather
/// than an oversight. Adding a widget to the catalog fails
/// `the preview screen covers the kit` until it is either previewed or listed
/// here.
/// Relative imports in generated widgets that point at a file moarch does
/// not generate, keyed `<stack> <slug> <import>` with why they are tolerated.
///
/// Empty is the goal: a generated file importing something that is never
/// written does not compile. Each entry here is a known bug, not a design.
const _unresolvedImports = {
  'bloc design-system ../../core/utils/action_bloc.dart':
      'the bloc stack declares no AsyncState — moarch generates no '
          'core/utils/action_bloc.dart, so the bloc preview screen does not '
          'compile. Pre-existing; the preview needs a bloc branch that drops '
          'the AppAsyncView section entirely.',
  'bloc design-system ../widgets/app_async_view.dart':
      'AppAsyncView is riverpod-only (see its `stacks`), so a bloc project '
          'never has this file. Same bug as the entry above.',
};

const _notPreviewed = {
  // Read by every field in the family; there is nothing to look at on its own.
  'input-config': 'configuration, not a widget',
  'input-title': 'drawn by every labeled field already on the screen',
  // Opened by the widgets that use them, which the screen does preview.
  'picker-sheet': 'opened by the date and time fields',
  'search-sheet': 'opened by the dropdown and multi-select fields',
  'country': 'a data table, not a widget',
  'action-listener': 'an extension on WidgetRef — nothing to render',
  // Context-free helpers: they need a rootNavigatorKey the preview's own
  // MaterialApp does not install.
  'dialogs': 'needs the app router\'s navigator key',
  'modals': 'needs the app router\'s navigator key',
  // Replaces the app instead of rendering into it, so there is no way to show
  // it inside the preview — and what it draws is ErrorView, already covered.
  'maintenance-gate': 'replaces the whole app; its screen is ErrorView',
  // Wraps the whole app from main.dart; inside the preview it would only
  // rescale the widgets already on screen, showing nothing of its own.
  'mo-adapt': 'mounted above MaterialApp; draws nothing of its own',
};

void main() {
  group('WidgetCatalog', () {
    test('slugs are unique', () {
      final names = WidgetCatalog.names;
      expect(names.toSet(), hasLength(names.length));
    });

    test('output paths are unique', () {
      final files = WidgetCatalog.all.map((w) => w.file).toList();
      expect(files.toSet(), hasLength(files.length));
    });

    test('every dep points at a real slug', () {
      final names = WidgetCatalog.names.toSet();
      for (final spec in WidgetCatalog.all) {
        for (final dep in spec.deps) {
          expect(
            names,
            contains(dep),
            reason: '${spec.name} depends on unknown widget "$dep"',
          );
        }
      }
    });

    test('every widget belongs to a known category', () {
      for (final spec in WidgetCatalog.all) {
        expect(
          WidgetCatalog.categories,
          contains(spec.category),
          reason: '${spec.name} has uncatalogued category "${spec.category}"',
        );
      }
    });

    test('nothing depends on the preview screen', () {
      for (final spec in WidgetCatalog.all) {
        expect(spec.deps, isNot(contains('design-system')));
      }
    });

    test('design-system pulls in the whole kit', () {
      // Its description promises a preview of everything, so its dependency
      // closure has to stay complete as widgets are added.
      final resolved =
          WidgetCatalog.resolve(['design-system']).map((w) => w.name).toSet();
      expect(resolved, equals(WidgetCatalog.names.toSet()));
    });

    test('resolve pulls in transitive deps and de-duplicates', () {
      // confirm-dialog -> button, leading-icon, dialogs
      final resolved =
          WidgetCatalog.resolve(['confirm-dialog', 'confirm-dialog'])
              .map((w) => w.name)
              .toList();
      expect(resolved.toSet(), hasLength(resolved.length));
      expect(
        resolved,
        containsAll(['confirm-dialog', 'button', 'leading-icon', 'dialogs']),
      );
    });

    test('resolve ignores unknown names', () {
      expect(WidgetCatalog.resolve(['not-a-widget']), isEmpty);
    });

    test('the common set is self-contained', () {
      // `moarch init` writes only WidgetCatalog.common, so a common widget may
      // not import one that init never generates.
      final common = WidgetCatalog.common.map((w) => w.name).toSet();
      for (final spec in WidgetCatalog.common) {
        for (final dep in spec.deps) {
          expect(
            common,
            contains(dep),
            reason:
                '${spec.name} is generated on init but depends on "$dep", which is not',
          );
        }
      }
    });

    test('the preview screen covers the kit', () {
      final preview = SharedTemplates.designSystemView();
      for (final spec in WidgetCatalog.all) {
        if (spec.name == 'design-system') continue;
        if (_notPreviewed.containsKey(spec.name)) continue;
        expect(
          preview,
          contains("/${spec.file}'"),
          reason:
              '${spec.name} is in the kit but DesignSystemView never imports '
              'it. Add a preview section, or add it to _notPreviewed with the '
              'reason.',
        );
      }
    });

    test('every relative import resolves to a file moarch generates', () {
      // The catalogs know where each generated file lands, so a relative
      // import can be resolved against them — which is the only check there
      // is that a file moved between directories still points at its
      // neighbours. Nothing else in CI parses the code inside a template.
      final unresolved = <String>[];

      for (final stack in StateManagement.values) {
        for (final spec in WidgetCatalog.all) {
          if (!spec.supports(stack)) continue;
          final source = WidgetCatalog.sourceFor(
            spec,
            WidgetVariants(stateManagement: stack, hasDarkTheme: true),
          );
          final dir = p.posix.dirname('lib/${spec.libFile}');

          for (final match in RegExp(r"^import '([^:']+)';", multiLine: true)
              .allMatches(source)) {
            final import = match.group(1)!;
            final target = p.posix.normalize(p.posix.join(dir, import));
            final generated =
                WidgetCatalog.all.any((s) => 'lib/${s.libFile}' == target) ||
                    ScaffoldCatalog.all
                        .any((s) => s.path == target || s.blocPath == target);
            if (generated) continue;

            final key = '${stack.name} ${spec.name} $import';
            if (_unresolvedImports.containsKey(key)) continue;
            unresolved.add('$key -> $target');
          }
        }
      }

      expect(
        unresolved,
        isEmpty,
        reason: 'These generated files import something no catalog writes, so '
            'they will not compile. Fix the import, or record it in '
            '_unresolvedImports with the reason.',
      );
    });

    test('nothing is excused from an import that now resolves', () {
      // Otherwise a fixed import keeps its excuse, and the excuse goes on
      // covering for whatever breaks next in the same file.
      for (final key in _unresolvedImports.keys) {
        final parts = key.split(' ');
        final stack = StateManagement.values
            .firstWhere((value) => value.name == parts.first);
        final spec = WidgetCatalog.byName(parts[1]);
        expect(spec, isNotNull, reason: '$key names no catalog entry');
        expect(
          spec!.supports(stack),
          isTrue,
          reason: '$key excuses an import in a stack that never gets the file',
        );
        expect(
          WidgetCatalog.sourceFor(
            spec,
            WidgetVariants(stateManagement: stack, hasDarkTheme: true),
          ),
          contains("import '${parts[2]}';"),
          reason: '$key is no longer imported — drop the excuse',
        );
      }
    });

    test('nothing is excused from the preview that no longer exists', () {
      // Otherwise a renamed or dropped widget leaves an excuse behind that
      // silently covers for the next widget to take its slug.
      final names = WidgetCatalog.names.toSet();
      for (final name in _notPreviewed.keys) {
        expect(names, contains(name), reason: '$name is no longer in the kit');
      }
    });

    test('no template needs a language feature the project may not have', () {
      // A generated file lands in whatever project moarch is run in, and the
      // language version comes from *its* pubspec — not from the SDK the
      // developer has installed. Null-aware elements (`?header` in a collection)
      // need that pubspec to ask for Dart 3.8+, and a project scaffolded a while
      // ago does not, so the file fails to compile rather than merely linting.
      //
      // The rest of what the kit uses — RadioGroup, `spacing:`, `withValues` —
      // only needs a recent Flutter installed, which is a lower bar.
      //
      // A wrapped ternary is `? value` with a space; an element is `?value`.
      final nullAwareElement = RegExp(r'^\s*\?[A-Za-z_]', multiLine: true);
      for (final spec in WidgetCatalog.all) {
        expect(
          nullAwareElement.hasMatch(spec.template()),
          isFalse,
          reason: '${spec.name} uses a null-aware element. Write it as '
              '`x ?? const SizedBox.shrink()` or `if (x != null) ...[x]` so it '
              'compiles under an older language version.',
        );
      }
    });

    test('markdown lists every widget under its category heading', () {
      final markdown = WidgetCatalog.markdown();
      for (final spec in WidgetCatalog.all) {
        expect(markdown, contains('`${spec.name}`'));
        expect(markdown, contains('`${spec.title}`'));
      }
      for (final category in WidgetCatalog.categories) {
        expect(markdown, contains('## $category'));
      }
    });
  });
}
