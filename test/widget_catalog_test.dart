import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

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
