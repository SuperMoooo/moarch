/// Templates for the table family: rows and columns sized for a phone.
abstract final class TableTemplates {
  /// Returns the generated appTable template.
  static String appTable() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';

/// How tightly rows are packed.
enum AppTableDensity { compact, standard, comfortable }

/// One column: its heading, how wide it is, and how its cells align.
class AppTableColumn {
  const AppTableColumn({
    required this.label,
    this.width,
    this.flex = 1,
    this.minWidth = 72,
    this.align = TextAlign.start,
    this.numeric = false,
    this.tooltip,
  });

  /// A column holding numbers: right-aligned and tabular, because a column of
  /// figures is read down rather than across.
  const AppTableColumn.numeric({
    required this.label,
    this.width,
    this.flex = 1,
    this.minWidth = 72,
    this.tooltip,
  })  : align = TextAlign.end,
        numeric = true;

  final String label;

  /// A fixed width. Takes priority over [flex] — use it for a column whose
  /// content never varies (a quantity, a status chip).
  final double? width;

  /// This column's share of what is left once the fixed columns are placed.
  final int flex;

  /// The width a flexible column will not go below. Past the point where
  /// every column is at its minimum, the table scrolls sideways instead of
  /// squeezing further.
  final double minWidth;

  final TextAlign align;

  /// Renders cells with `FontFeature.tabularFigures`, so digits line up
  /// column-wise instead of jittering by glyph width.
  final bool numeric;

  /// Shown on a long-press of the heading — room for the full name of a
  /// column abbreviated to fit.
  final String? tooltip;
}

/// One row of cells.
///
/// Cells are `String`s by default, which covers most of a table. Pass
/// [widgets] instead when a cell is a chip, an avatar or a button — the two
/// are exclusive, and [widgets] wins if both are given.
class AppTableRow {
  const AppTableRow({
    this.cells = const [],
    this.widgets,
    this.onTap,
    this.selected = false,
    this.color,
  });

  final List<String> cells;

  /// Arbitrary cell content. Must be the same length as the column list, as
  /// [cells] must.
  final List<Widget>? widgets;

  final VoidCallback? onTap;

  /// Tints the row with the accent — a current selection, a highlighted
  /// result.
  final bool selected;

  /// Tints the row with something of your own. Overrides striping.
  final Color? color;
}

/// Rows and columns, sized for a screen narrower than the data.
///
/// ```dart
/// AppTable(
///   columns: const [
///     AppTableColumn(label: 'Item', flex: 2),
///     AppTableColumn.numeric(label: 'Qty', width: 56),
///     AppTableColumn.numeric(label: 'Total'),
///   ],
///   rows: const [
///     AppTableRow(cells: ['Coffee', '2', '€7.00']),
///     AppTableRow(cells: ['Pastry', '1', '€2.40']),
///   ],
///   footer: AppTableRow(cells: ['Total', '3', '€9.40']),
/// )
/// ```
///
/// **It does not scroll vertically.** A table that owns a vertical scroll
/// cannot sit in a page that also scrolls without one of them being wrong, so
/// this one lays out at its full height and lets the page it is in do the
/// scrolling — drop it into `AppSingleScrollView` or a `ListView`. It *does*
/// scroll sideways, on its own, once the columns no longer fit: every
/// flexible column drops to its [AppTableColumn.minWidth] and the whole table
/// pans.
class AppTable extends StatelessWidget {
  const AppTable({
    super.key,
    required this.columns,
    required this.rows,
    this.footer,
    this.showHeader = true,
    this.density = AppTableDensity.standard,
    this.striped = false,
    this.showRowDividers = true,
    this.showColumnDividers = false,
    this.showBorder = true,
    this.emptyLabel = 'Nothing to show',
    this.emptyBuilder,
    this.horizontalPadding = AppConstants.space12,
    this.variant,
  });

  final List<AppTableColumn> columns;
  final List<AppTableRow> rows;

  /// A row pinned under the body, drawn in the heading's weight — a total, a
  /// count. Not striped and not tappable.
  final AppTableRow? footer;

  final bool showHeader;
  final AppTableDensity density;

  /// Tints every other row. Prefer it over [showRowDividers] on a wide table,
  /// where a stripe tracks the eye across better than a line does.
  final bool striped;

  final bool showRowDividers;

  /// Vertical rules between columns. Off by default: alignment usually
  /// separates columns better than lines, and lines make a small table look
  /// like a spreadsheet.
  final bool showColumnDividers;

  /// The outline and rounded corners around the whole table.
  final bool showBorder;

  final String emptyLabel;

  /// Replaces the whole empty state. [emptyLabel] is ignored when given.
  final WidgetBuilder? emptyBuilder;

  final double horizontalPadding;

  /// Colors the selected-row tint and the header text. Null follows
  /// [AppInputConfig.defaults].
  final AppInputVariant? variant;

  static const double _stripeOpacity = 0.04;
  static const double _selectedOpacity = 0.10;

  /// What sits between two columns — a plain gap, or a rule with a gap
  /// either side of it. Counted in the width maths: a row whose gaps are not
  /// budgeted for overflows by exactly this much per column.
  double get _columnGap => showColumnDividers
      ? AppConstants.space8 * 2 + 1
      : AppConstants.space8;

  double get _rowPadding => switch (density) {
        AppTableDensity.compact => AppConstants.space8,
        AppTableDensity.standard => AppConstants.space12,
        AppTableDensity.comfortable => AppConstants.space16,
      };

  /// The width each column gets, given [available].
  ///
  /// Fixed columns take theirs first; the rest share what is left by [flex],
  /// but never below their own minimum. When the minimums alone overflow, the
  /// caller scrolls — so this returns widths that may total more than
  /// [available], deliberately.
  List<double> _resolveWidths(double available) {
    final widths = List<double>.filled(columns.length, 0);
    var fixedTotal = 0.0;
    var flexTotal = 0;

    for (var i = 0; i < columns.length; i++) {
      final width = columns[i].width;
      if (width != null) {
        widths[i] = width;
        fixedTotal += width;
      } else {
        flexTotal += columns[i].flex < 1 ? 1 : columns[i].flex;
      }
    }

    final remaining = available - fixedTotal;
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].width != null) continue;
      final flex = columns[i].flex < 1 ? 1 : columns[i].flex;
      final share = flexTotal == 0 ? 0.0 : remaining * flex / flexTotal;
      widths[i] = share < columns[i].minWidth ? columns[i].minWidth : share;
    }

    return widths;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = AppInputStyle.accentOf(context, variant);

    assert(
      columns.isNotEmpty,
      'AppTable needs at least one column to lay anything out.',
    );

    final table = LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded width means an unconstrained parent (a Row, a horizontal
        // list). Fall back to the minimums rather than dividing infinity.
        final gaps = _columnGap * (columns.length - 1);
        final available = constraints.hasBoundedWidth
            ? constraints.maxWidth - horizontalPadding * 2 - gaps
            : 0.0;
        final widths = _resolveWidths(available);
        final total = widths.fold<double>(0, (sum, w) => sum + w);
        final overflows = total > available;

        final content = SizedBox(
          width: overflows ? total + gaps + horizontalPadding * 2 : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader) ...[
                _header(theme, accent, widths),
                Divider(height: 1, color: colorScheme.outlineVariant),
              ],
              if (rows.isEmpty)
                _empty(context, theme)
              else
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0 && showRowDividers)
                    Divider(height: 1, color: colorScheme.outlineVariant),
                  _row(theme, accent, widths, rows[i], index: i),
                ],
              if (footer != null) ...[
                Divider(height: 1, color: colorScheme.outlineVariant),
                _row(
                  theme,
                  accent,
                  widths,
                  footer!,
                  index: -1,
                  bold: true,
                ),
              ],
            ],
          ),
        );

        if (!overflows) return content;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: content,
        );
      },
    );

    if (!showBorder) return table;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: AppConstants.borderRadius12,
      ),
      child: ClipRRect(
        borderRadius: AppConstants.borderRadius12,
        child: table,
      ),
    );
  }

  Widget _empty(BuildContext context, ThemeData theme) {
    final builder = emptyBuilder;
    if (builder != null) return builder(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: AppConstants.space24,
      ),
      child: Text(
        emptyLabel,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, Color accent, List<double> widths) {
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: _rowPadding,
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0 && showColumnDividers)
              _columnDivider(theme)
            else if (i > 0)
              const SizedBox(width: AppConstants.space8),
            SizedBox(
              width: widths[i],
              child: _headingCell(columns[i], style),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headingCell(AppTableColumn column, TextStyle? style) {
    final text = Text(
      column.label,
      textAlign: column.align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    final tooltip = column.tooltip;
    if (tooltip == null) return text;
    return Tooltip(message: tooltip, child: text);
  }

  Widget _row(
    ThemeData theme,
    Color accent,
    List<double> widths,
    AppTableRow row, {
    required int index,
    bool bold = false,
  }) {
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w600 : null,
    );

    final background = row.color ??
        (row.selected
            ? accent.withValues(alpha: _selectedOpacity)
            : (striped && index.isOdd
                ? colorScheme.onSurface.withValues(alpha: _stripeOpacity)
                : null));

    final cells = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: _rowPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0 && showColumnDividers)
              _columnDivider(theme)
            else if (i > 0)
              const SizedBox(width: AppConstants.space8),
            SizedBox(
              width: widths[i],
              child: _cell(row, i, columns[i], baseStyle),
            ),
          ],
        ],
      ),
    );

    if (row.onTap == null) {
      return background == null ? cells : ColoredBox(color: background, child: cells);
    }

    return Material(
      // Its own Material so the ripple paints over the row tint rather than
      // under it.
      color: background ?? Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          row.onTap!();
        },
        child: cells,
      ),
    );
  }

  /// A cell's content: the widget if one was given, otherwise the string —
  /// and an empty box when the row is shorter than the column list, which is
  /// a ragged row rather than a crash.
  Widget _cell(
    AppTableRow row,
    int index,
    AppTableColumn column,
    TextStyle? style,
  ) {
    final widgets = row.widgets;
    if (widgets != null) {
      if (index >= widgets.length) return const SizedBox.shrink();
      return Align(
        alignment: switch (column.align) {
          TextAlign.end => Alignment.centerRight,
          TextAlign.center => Alignment.center,
          _ => Alignment.centerLeft,
        },
        child: widgets[index],
      );
    }

    if (index >= row.cells.length) return const SizedBox.shrink();
    return Text(
      row.cells[index],
      textAlign: column.align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: column.numeric
          ? style?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            )
          : style,
    );
  }

  Widget _columnDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: AppConstants.space16,
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.space8),
      color: theme.colorScheme.outlineVariant,
    );
  }
}
''';
}
