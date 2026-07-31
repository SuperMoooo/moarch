import 'package:moarch/src/templates/ui/table_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  final output = TableTemplates.appTable();

  group('appTable', () {
    test('a fixed column keeps its width, a flexible one shares the rest', () {
      expect(output, contains('if (width != null) {'));
      expect(output, contains('final remaining = available - fixedTotal;'));
      expect(
        output,
        contains(
            'final share = flexTotal == 0 ? 0.0 : remaining * flex / flexTotal;'),
      );
    });

    test('a flexible column never squeezes below its floor', () {
      expect(
        output,
        contains(
            'widths[i] = share < columns[i].minWidth ? columns[i].minWidth : share;'),
      );
      expect(output, contains('this.minWidth = 72,'));
    });

    test('the gaps between columns are budgeted, not forgotten', () {
      // A row whose gaps are not counted overflows by exactly one gap per
      // column boundary.
      expect(
          output, contains('final gaps = _columnGap * (columns.length - 1);'));
      expect(
        output,
        contains('? constraints.maxWidth - horizontalPadding * 2 - gaps'),
      );
      expect(
          output,
          contains(
              'width: overflows ? total + gaps + horizontalPadding * 2 : null,'));
    });

    test('a column divider is wider than a plain gap, and says so', () {
      expect(
        output,
        contains('double get _columnGap => showColumnDividers\n'
            '      ? AppConstants.space8 * 2 + 1\n'
            '      : AppConstants.space8;'),
      );
    });

    test('it pans sideways only when it has to', () {
      expect(output, contains('final overflows = total > available;'));
      expect(output, contains('if (!overflows) return content;'));
      expect(output, contains('scrollDirection: Axis.horizontal,'));
    });

    test('it owns no vertical scroll', () {
      // A table that scrolls vertically cannot sit in a page that also does.
      expect(output, isNot(contains('scrollDirection: Axis.vertical')));
      expect('SingleChildScrollView('.allMatches(output).length, 1);
    });

    test('an unbounded width falls back to the minimums', () {
      expect(output, contains('constraints.hasBoundedWidth'));
      expect(output, contains(': 0.0;'));
    });

    test('a ragged row is drawn, not thrown', () {
      expect(
          output,
          contains(
              'if (index >= row.cells.length) return const SizedBox.shrink();'));
      expect(
          output,
          contains(
              'if (index >= widgets.length) return const SizedBox.shrink();'));
    });

    test('widget cells win over string cells', () {
      expect(output, contains('final widgets = row.widgets;'));
      expect(output, contains('if (widgets != null) {'));
    });

    test('a numeric column is right-aligned and tabular', () {
      expect(output, contains('const AppTableColumn.numeric({'));
      expect(output, contains('align = TextAlign.end,'));
      expect(output, contains('numeric = true;'));
      expect(output, contains('FontFeature.tabularFigures()'));
    });

    test('a tinted row inks over its tint, not under it', () {
      expect(output, contains('color: background ?? Colors.transparent,'));
      expect(output, contains('HapticFeedback.selectionClick();'));
    });

    test('an untapped row costs no Material', () {
      expect(output, contains('if (row.onTap == null) {'));
    });

    test('the row tint has a precedence, and it is written down', () {
      // Explicit colour, then selection, then striping.
      expect(output, contains('final background = row.color ??'));
      expect(output, contains('(row.selected'));
      expect(output, contains(': (striped && index.isOdd'));
    });

    test('the footer is not striped — it is given index -1', () {
      expect(output, contains('index: -1,'));
      expect(output, contains('bold: true,'));
    });

    test('an empty table says so, or says what you tell it', () {
      expect(output, contains("this.emptyLabel = 'Nothing to show',"));
      expect(output, contains('final builder = emptyBuilder;'));
      expect(output, contains('if (builder != null) return builder(context);'));
    });

    test('density moves the row padding', () {
      expect(
          output, contains('AppTableDensity.compact => AppConstants.space8,'));
      expect(output,
          contains('AppTableDensity.standard => AppConstants.space12,'));
      expect(output,
          contains('AppTableDensity.comfortable => AppConstants.space16,'));
    });

    test('a table with no columns fails loudly rather than blankly', () {
      expect(output, contains('columns.isNotEmpty,'));
    });

    test('is in the catalog under Layout & content, needing no package', () {
      final spec = WidgetCatalog.all.firstWhere((s) => s.name == 'table');
      expect(spec.file, 'tables/app_table.dart');
      expect(spec.category, 'Layout & content');
      expect(spec.packages, isEmpty);
      expect(spec.deps, ['input-style']);
    });
  });
}
