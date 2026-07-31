/// Templates for the calendar family: the inline month grid, as opposed to the
/// platform date picker `AppDateInput` opens.
class CalendarTemplates {
  /// Returns the generated appCalendar template.
  static String appCalendar() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';

import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';

/// How much of the month [AppCalendar] shows at once.
enum AppCalendarFormat { month, twoWeeks, week }

/// The column a week starts in. Monday outside the US, Sunday inside it,
/// Saturday across much of the Middle East.
enum AppCalendarWeekStart { monday, saturday, sunday }

/// An inline month calendar — the sibling of `AppDateInput`, which opens the
/// platform picker instead of showing the grid.
///
/// Reach for this when the month itself is the content: an agenda, a booking
/// screen, a streak. Reach for `AppDateInput` when a date is one answer in a
/// form.
///
/// ```dart
/// AppCalendar(
///   selected: _day,
///   onSelected: (day) => setState(() => _day = day),
/// )
/// ```
///
/// With events, and loading them as the month turns:
///
/// ```dart
/// AppCalendar(
///   selected: _day,
///   events: {for (final a in appointments) a.startsAt: 1},
///   onSelected: (day) => setState(() => _day = day),
///   onMonthChanged: (first, last) => ref.read(p.notifier).load(first, last),
/// )
/// ```
///
/// Leaving [onSelected] null makes it a read-only display — an availability
/// month with nothing to tap.
class AppCalendar extends StatefulWidget {
  const AppCalendar({
    super.key,
    this.selected,
    this.onSelected,
    this.events = const <DateTime, int>{},
    this.onMonthChanged,
    this.firstDate,
    this.lastDate,
    this.focusedMonth,
    this.format = AppCalendarFormat.month,
    this.canChangeFormat = false,
    this.weekStart = AppCalendarWeekStart.monday,
    this.selectableDay,
    this.variant,
    this.locale,
    this.rowHeight = 46,
  });

  /// The day drawn as selected. Null selects nothing.
  final DateTime? selected;

  /// Called with the tapped day. Null makes the calendar read-only.
  final ValueChanged<DateTime>? onSelected;

  /// Day → how many dots to draw under it, capped at three.
  ///
  /// The keys are re-keyed to the day they fall on, so you can hand this map
  /// whatever `DateTime` your data already carries — two appointments at
  /// 09:00 and 14:00 count as two dots on one day rather than missing the
  /// grid entirely, which is what a raw `DateTime` key does.
  final Map<DateTime, int> events;

  /// Called with the first and last day now on screen, whenever the page
  /// turns or the format changes — the range to fetch [events] for. For
  /// [AppCalendarFormat.month] that is the month's own bounds, not the six
  /// weeks drawn around it.
  final void Function(DateTime first, DateTime last)? onMonthChanged;

  /// Defaults to five years back.
  final DateTime? firstDate;

  /// Defaults to five years on.
  final DateTime? lastDate;

  /// The month to open on. Defaults to [selected], then today.
  final DateTime? focusedMonth;

  /// How much is shown at once. The calendar remembers what the user swipes
  /// to from here, so this is the starting point rather than a fixed setting.
  final AppCalendarFormat format;

  /// Shows the format button and lets a vertical swipe collapse the month to
  /// two weeks or one. Off by default: most screens want one shape.
  final bool canChangeFormat;

  final AppCalendarWeekStart weekStart;

  /// Days this returns false for are greyed and refuse a tap — booked-out
  /// dates, weekends on a business calendar.
  final bool Function(DateTime day)? selectableDay;

  /// Colors the selected day, today's ring and the event dots. Null follows
  /// [AppInputConfig.defaults], like every other field in the kit.
  final AppInputVariant? variant;

  /// A locale tag such as `'pt_PT'`. Null uses the app's.
  ///
  /// Anything other than `en_US` needs
  /// `initializeDateFormatting()` from `package:intl` called once at startup.
  final String? locale;

  final double rowHeight;

  @override
  State<AppCalendar> createState() => _AppCalendarState();
}

class _AppCalendarState extends State<AppCalendar> {
  /// The one instance handed to `eventLoader` per dot. `TableCalendar` only
  /// counts what it gets back, so there is nothing to carry.
  static const Object _dot = Object();

  static const double _todayFill = 0.12;
  static const double _disabledOpacity = 0.38;
  static const int _maxDots = 3;
  static const double _dotSize = 5;

  late DateTime _focused;
  late AppCalendarFormat _format;

  @override
  void initState() {
    super.initState();
    _focused = widget.focusedMonth ?? widget.selected ?? DateTime.now();
    _format = widget.format;
  }

  @override
  void didUpdateWidget(AppCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A selection made from outside — a "jump to today" button, a restored
    // draft — has to bring the page with it, or it lands on a month that is
    // not on screen.
    final selected = widget.selected;
    if (selected != null && !isSameDay(selected, oldWidget.selected)) {
      _focused = selected;
    }
    final focusedMonth = widget.focusedMonth;
    if (focusedMonth != null && focusedMonth != oldWidget.focusedMonth) {
      _focused = focusedMonth;
    }
    if (widget.format != oldWidget.format) _format = widget.format;
  }

  /// [AppCalendar.events] re-keyed to the day each entry falls on.
  ///
  /// Two `DateTime`s in the same day are not equal, so a map keyed on the
  /// instants the data carries never matches the midnight key the grid looks
  /// up. Counts on the same day are added rather than the last one winning.
  Map<DateTime, int> get _markers {
    final byDay = <DateTime, int>{};
    widget.events.forEach((day, count) {
      if (count <= 0) return;
      final key = DateTime.utc(day.year, day.month, day.day);
      byDay[key] = (byDay[key] ?? 0) + count;
    });
    return byDay;
  }

  int get _weekStartIndex => switch (widget.weekStart) {
        AppCalendarWeekStart.monday => DateTime.monday,
        AppCalendarWeekStart.saturday => DateTime.saturday,
        AppCalendarWeekStart.sunday => DateTime.sunday,
      };

  DateTime _startOfWeek(DateTime day) {
    final offset = (day.weekday - _weekStartIndex + 7) % 7;
    return DateTime(day.year, day.month, day.day - offset);
  }

  /// The first and last day on screen for the current format — what
  /// [AppCalendar.onMonthChanged] reports.
  (DateTime, DateTime) _visibleRange(DateTime focused) {
    switch (_format) {
      case AppCalendarFormat.month:
        // Day zero of the next month is the last day of this one.
        return (
          DateTime(focused.year, focused.month, 1),
          DateTime(focused.year, focused.month + 1, 0),
        );
      case AppCalendarFormat.twoWeeks:
        final start = _startOfWeek(focused);
        return (start, DateTime(start.year, start.month, start.day + 13));
      case AppCalendarFormat.week:
        final start = _startOfWeek(focused);
        return (start, DateTime(start.year, start.month, start.day + 6));
    }
  }

  void _reportRange() {
    final onMonthChanged = widget.onMonthChanged;
    if (onMonthChanged == null) return;
    final (first, last) = _visibleRange(_focused);
    onMonthChanged(first, last);
  }

  CalendarFormat get _tableFormat => switch (_format) {
        AppCalendarFormat.month => CalendarFormat.month,
        AppCalendarFormat.twoWeeks => CalendarFormat.twoWeeks,
        AppCalendarFormat.week => CalendarFormat.week,
      };

  StartingDayOfWeek get _tableWeekStart => switch (widget.weekStart) {
        AppCalendarWeekStart.monday => StartingDayOfWeek.monday,
        AppCalendarWeekStart.saturday => StartingDayOfWeek.saturday,
        AppCalendarWeekStart.sunday => StartingDayOfWeek.sunday,
      };

  static AppCalendarFormat _formatFrom(CalendarFormat format) =>
      switch (format) {
        CalendarFormat.month => AppCalendarFormat.month,
        CalendarFormat.twoWeeks => AppCalendarFormat.twoWeeks,
        CalendarFormat.week => AppCalendarFormat.week,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = AppInputStyle.accentOf(context, widget.variant);
    final onAccent = AppInputStyle.onAccentOf(context, widget.variant);

    final body = theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: AppConstants.fontSize14);
    final label = theme.textTheme.labelSmall ??
        const TextStyle(fontSize: AppConstants.fontSize12);

    final markers = _markers;
    final today = DateTime.now();
    final enabled = widget.onSelected != null;

    return TableCalendar<Object>(
      firstDay: widget.firstDate ?? DateTime(today.year - 5, 1, 1),
      lastDay: widget.lastDate ?? DateTime(today.year + 5, 12, 31),
      focusedDay: _focused,
      locale: widget.locale,
      rowHeight: widget.rowHeight,
      startingDayOfWeek: _tableWeekStart,
      calendarFormat: _tableFormat,
      // A vertical swipe is what changes the format, so it is only offered
      // when the format can change at all.
      availableGestures: widget.canChangeFormat
          ? AvailableGestures.all
          : AvailableGestures.horizontalSwipe,
      availableCalendarFormats: widget.canChangeFormat
          ? const {
              CalendarFormat.month: 'Month',
              CalendarFormat.twoWeeks: '2 weeks',
              CalendarFormat.week: 'Week',
            }
          : {_tableFormat: ''},
      selectedDayPredicate: (day) => isSameDay(widget.selected, day),
      enabledDayPredicate: widget.selectableDay,
      eventLoader: (day) {
        final count = markers[DateTime.utc(day.year, day.month, day.day)] ?? 0;
        return List<Object>.filled(count, _dot);
      },
      onDaySelected: enabled
          ? (selectedDay, focusedDay) {
              HapticFeedback.selectionClick();
              setState(() => _focused = focusedDay);
              widget.onSelected!(selectedDay);
            }
          : null,
      onPageChanged: (focusedDay) {
        // Not setState: TableCalendar has already moved, and rebuilding here
        // fights its own page animation.
        _focused = focusedDay;
        _reportRange();
      },
      onFormatChanged: (format) {
        setState(() => _format = _formatFrom(format));
        _reportRange();
      },
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: widget.canChangeFormat,
        formatButtonShowsNext: false,
        headerPadding:
            const EdgeInsets.symmetric(vertical: AppConstants.space8),
        titleTextStyle: theme.textTheme.titleMedium ??
            const TextStyle(
              fontSize: AppConstants.fontSize16,
              fontWeight: FontWeight.w600,
            ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: colorScheme.onSurfaceVariant,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ),
        formatButtonDecoration: BoxDecoration(
          color: accent.withValues(alpha: _todayFill),
          borderRadius: AppConstants.borderRadiusFull,
        ),
        formatButtonTextStyle: TextStyle(
          color: accent,
          fontSize: AppConstants.fontSize13,
          fontWeight: FontWeight.w600,
        ),
        decoration: const BoxDecoration(),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: label.copyWith(color: colorScheme.onSurfaceVariant),
        weekendStyle: label.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      calendarStyle: CalendarStyle(
        isTodayHighlighted: true,
        // The greyed-out spill from the neighbouring months reads as tappable
        // when it is not; the grid is easier to scan without it.
        outsideDaysVisible: false,
        cellMargin: const EdgeInsets.all(AppConstants.space4),
        defaultTextStyle: body,
        weekendTextStyle: body.copyWith(color: colorScheme.onSurfaceVariant),
        disabledTextStyle: body.copyWith(
          color: colorScheme.onSurface.withValues(alpha: _disabledOpacity),
        ),
        selectedTextStyle: body.copyWith(
          color: onAccent,
          fontWeight: FontWeight.w600,
        ),
        selectedDecoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
        ),
        todayTextStyle: body.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
        todayDecoration: BoxDecoration(
          color: accent.withValues(alpha: _todayFill),
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
        ),
        markersMaxCount: _maxDots,
        markerSize: _dotSize,
        markersAlignment: Alignment.bottomCenter,
        markerMargin: const EdgeInsets.symmetric(horizontal: 1),
      ),
    );
  }
}
''';
}
