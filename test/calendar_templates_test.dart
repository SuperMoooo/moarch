import 'package:moarch/src/templates/ui/calendar_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  final output = CalendarTemplates.appCalendar();

  group('appCalendar', () {
    test('wraps table_calendar rather than re-implementing a month grid', () {
      expect(output,
          contains("import 'package:table_calendar/table_calendar.dart';"));
      expect(output, contains('TableCalendar<_Marker>('));
    });

    test('keeps table_calendar out of the calling screen', () {
      // The point of the wrapper: a screen configures it in the kit's own
      // vocabulary, so swapping the package out later is one file's problem.
      expect(
          output, contains('enum AppCalendarFormat { month, twoWeeks, week }'));
      expect(output, contains('enum AppCalendarWeekStart'));
      expect(output, contains('AppInputVariant? variant'));
      expect(
          output, contains('AppInputStyle.accentOf(context, widget.variant)'));
    });

    test('re-keys events to the day, which is the whole gotcha', () {
      // A DateTime carries a time, and two instants in one day are not equal,
      // so a map keyed on what the data holds never matches the grid's lookup.
      expect(output,
          contains('final key = DateTime.utc(day.year, day.month, day.day);'));
      expect(
        output,
        contains(
            '(byDay[key] ??= <Color?>[]).addAll(List<Color?>.filled(count, null));'),
      );
      expect(
        output,
        contains(
            'final colors = markers[DateTime.utc(day.year, day.month, day.day)];'),
      );
    });

    test('a day with no events loads no markers', () {
      expect(output, contains('if (count <= 0) return;'));
      expect(output, contains('if (colors == null) return const <_Marker>[];'));
    });

    test('a fourth event does not look like a third', () {
      // Stopping at three dots makes a busy day under-report itself, which is
      // the one thing worse than a missing dot.
      expect(output,
          contains('typedef _Marker = ({Color? color, int overflow});'));
      expect(
        output,
        contains('(color: null, overflow: colors.length - _maxDots + 1),'),
      );
      expect(output, contains("'+\${marker.overflow}'"));
    });

    test('the counter takes a dot place, so the row still fits the cell', () {
      // Three dots *plus* a counter is wider than a day cell on a small
      // phone, so _maxDots counts markers, not dots.
      expect(
        output,
        contains('for (final color in colors.take(_maxDots - 1))'),
      );
      expect(output, contains('markersMaxCount: _maxDots,'));
      expect(output, contains('if (colors.length <= _maxDots) {'));
    });

    test('a colored day says how many dots it has by saying what they are', () {
      // eventColors is the count too, so the day is dropped from the count
      // map rather than drawing both rows.
      expect(output, contains('final Map<DateTime, List<Color>> eventColors;'));
      expect(output,
          contains('this.eventColors = const <DateTime, List<Color>>{},'));
      expect(output, contains('(colored[key] ??= <Color?>[]).addAll(colors);'));
      expect(output, contains('if (colored.containsKey(key)) return;'));
      expect(output, contains('return byDay..addAll(colored);'));
    });

    test('colors on the same day stack, like counts do', () {
      // Same re-keying gotcha: two instants in one day are two dots on it.
      expect(
        output,
        contains('final key = DateTime.utc(day.year, day.month, day.day);'),
      );
      expect(output, contains('(colored[key] ??= <Color?>[]).addAll(colors);'));
    });

    test('an empty color list leaves the day to events', () {
      // `{day: []}` names a day without saying anything about it, so the
      // count still applies — the same non-entry a count of zero is, and why
      // neither map can blank a day the other filled.
      expect(output, contains('if (colors.isEmpty) return;'));
      expect(output, contains('if (count <= 0) return;'));
    });

    test('an uncolored dot is still the one CalendarStyle draws', () {
      // Null falls through to markerDecoration, so adding eventColors did not
      // quietly re-implement the default marker.
      expect(output, contains('singleMarkerBuilder: (context, day, marker)'));
      expect(output, contains('if (color == null) return null;'));
      expect(output, contains('markerDecoration: _dotDecoration(accent),'));
      expect(output, contains('markerMargin: _dotMargin,'));
    });

    test('the dot shape is stated once, for both paths', () {
      // The accent dot comes from CalendarStyle and the colored one from the
      // builder; a restyle that only found one of them would split the kit.
      expect(
        output,
        contains('static BoxDecoration _dotDecoration(Color color) =>\n'
            '      BoxDecoration(color: color, shape: BoxShape.circle);'),
      );
      expect(output, contains('decoration: _dotDecoration(color),'));
    });

    test('reports the month bounds, not the six weeks drawn around them', () {
      // Day zero of the next month is the last day of this one.
      expect(output, contains('DateTime(focused.year, focused.month, 1),'));
      expect(output, contains('DateTime(focused.year, focused.month + 1, 0),'));
      expect(
          output, contains('final (first, last) = _visibleRange(_focused);'));
    });

    test('the two short formats report their own span', () {
      expect(output,
          contains('DateTime(start.year, start.month, start.day + 13)'));
      expect(
          output, contains('DateTime(start.year, start.month, start.day + 6)'));
    });

    test('the week starts where the caller says, in range maths too', () {
      expect(output,
          contains('final offset = (day.weekday - _weekStartIndex + 7) % 7;'));
      expect(
          output, contains('AppCalendarWeekStart.monday => DateTime.monday,'));
      expect(output,
          contains('AppCalendarWeekStart.monday => StartingDayOfWeek.monday,'));
    });

    test('follows a selection made from outside onto its page', () {
      expect(
          output,
          contains(
              'if (selected != null && !isSameDay(selected, oldWidget.selected))'));
      expect(output, contains('_focused = selected;'));
    });

    test('a vertical swipe is only offered when the format can change', () {
      expect(
        output,
        contains('availableGestures: widget.canChangeFormat\n'
            '          ? AvailableGestures.all\n'
            '          : AvailableGestures.horizontalSwipe,'),
      );
      expect(output, contains('formatButtonVisible: widget.canChangeFormat,'));
    });

    test('the format list always contains the format in use', () {
      // TableCalendar asserts on this, so a locked-format calendar has to
      // offer exactly the one it is showing.
      expect(output, contains('{_tableFormat: \'\'}'));
    });

    test('no onSelected makes it a read-only display', () {
      expect(output, contains('final enabled = widget.onSelected != null;'));
      expect(output, contains('onDaySelected: enabled'));
    });

    test('turning the page does not fight the page animation', () {
      // TableCalendar has already moved by the time onPageChanged fires;
      // setState here rebuilds it mid-animation.
      expect(
          output, contains('_focused = focusedDay;\n        _reportRange();'));
    });

    test('is in the catalog with the package it needs', () {
      final spec = WidgetCatalog.all.firstWhere((s) => s.name == 'calendar');
      expect(spec.file, 'calendar/app_calendar.dart');
      expect(spec.category, 'Inputs');
      expect(spec.packages, ['table_calendar: ']);
      expect(spec.deps, ['input-style']);
      expect(spec.needsRouter, isFalse);
    });

    test('is not generated by init — it costs a dependency', () {
      final spec = WidgetCatalog.all.firstWhere((s) => s.name == 'calendar');
      expect(spec.common, isFalse);
    });

    test('its import reaches sideways, out of its own folder', () {
      // It lives in calendar/, so the style it shares with the input family
      // is a directory across rather than a sibling.
      expect(output, contains("import '../inputs/app_input_style.dart';"));
      expect(output,
          contains("import '../../../core/constants/app_constants.dart';"));
    });
  });
}
