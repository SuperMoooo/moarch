/// Generates core scaffold file templates.
class CoreTemplates {
  CoreTemplates._();

  /// Returns the generated appLogger template.
  ///
  /// [withCrashlytics] adds a sink that mirrors records into Crashlytics.
  static String appLogger({bool withCrashlytics = false}) {
    final crashlyticsImport = withCrashlytics
        ? "\nimport 'package:firebase_core/firebase_core.dart';"
              "\nimport 'package:firebase_crashlytics/firebase_crashlytics.dart';"
        : '';

    final sinks = withCrashlytics
        ? r'''
final _sinks = <LogOutput>[
  _DeveloperOutput(),
  _CrashlyticsOutput(),
];

/// Mirrors records into Crashlytics as breadcrumbs.
///
/// Breadcrumbs only — reporting a caught error stays an explicit
/// `FirebaseCrashlytics.instance.recordError(...)` at the call site.
class _CrashlyticsOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Anything logged before Firebase.initializeApp() would throw on `instance`.
    if (Firebase.apps.isEmpty) return;
    FirebaseCrashlytics.instance.log(_redact(event.lines.join('\n')));
  }
}
'''
        : r'''
final _sinks = <LogOutput>[_DeveloperOutput()];
''';

    return '''
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';$crashlyticsImport

$_appLoggerBody$sinks''';
  }

  /// The part of `app_logger.dart` that never varies with the selected stack.
  static const String _appLoggerBody = r'''
/// The app's logger — call sites talk to this, not to the `logger` package.
final appLogger = AppLogger._();

class AppLogger {
  AppLogger._([this._tag]);

  final String? _tag;

  /// A logger that stamps every record with `[name]`, so logs stay filterable.
  ///
  /// ```dart
  /// final _log = appLogger.scoped('FCM');
  /// _log.i('Token refreshed'); // [FCM] Token refreshed
  /// ```
  AppLogger scoped(String name) => AppLogger._(name);

  /// The noisiest level — debug builds only.
  void t(String message, {Object? error, StackTrace? stackTrace}) =>
      _write(Level.trace, message, error, stackTrace);

  void d(String message, {Object? error, StackTrace? stackTrace}) =>
      _write(Level.debug, message, error, stackTrace);

  void i(String message, {Object? error, StackTrace? stackTrace}) =>
      _write(Level.info, message, error, stackTrace);

  void w(String message, {Object? error, StackTrace? stackTrace}) =>
      _write(Level.warning, message, error, stackTrace);

  void e(String message, {Object? error, StackTrace? stackTrace}) =>
      _write(Level.error, message, error, stackTrace);

  void _write(
    Level level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    _logger.log(
      level,
      _tag == null ? message : '[$_tag] $message',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

final _logger = Logger(
  // One line per record in release, for breadcrumbs and device logs.
  printer: kReleaseMode
      ? SimplePrinter(printTime: true, colors: false)
      : PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 12,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
  output: MultiOutput(_sinks),
  // Warnings and errors survive into release; use Level.off to silence it.
  level: kReleaseMode ? Level.warning : Level.trace,
);

/// Writes through `dart:developer`, for DevTools' Logging view.
class _DeveloperOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    developer.log(
      _redact(event.lines.join('\n')),
      name: 'app',
      time: event.origin.time,
      level: _developerLevels[event.level] ?? 0,
    );
  }
}

/// Maps [Level] to package:logging's severity scale.
const _developerLevels = <Level, int>{
  Level.trace: 300,
  Level.debug: 500,
  Level.info: 800,
  Level.warning: 900,
  Level.error: 1000,
  Level.fatal: 1200,
};

/// Redacts credentials; every sink runs this.
final _sensitiveKeyPattern = RegExp(
  r'("?(?:password|newPassword|token|authorization|refreshToken|accessToken)"?\s*:\s*)'
  r'("[^"]*"|[^,}\]\n]+)',
  caseSensitive: false,
);

final _bearerPattern = RegExp(r'Bearer\s+\S+', caseSensitive: false);

String _redact(String message) => message
    .replaceAllMapped(
      _sensitiveKeyPattern,
      (match) => '${match.group(1)}***REDACTED***',
    )
    .replaceAll(_bearerPattern, 'Bearer ***REDACTED***');

''';

  /// Returns the generated extensions template.
  static String extensions() => r'''
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  Orientation get orientation => MediaQuery.orientationOf(this);

  /// Notch, status bar and home indicator insets.
  EdgeInsets get safeInsets => MediaQuery.viewPaddingOf(this);

  /// How much of the screen the keyboard is covering right now.
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;
  bool get isKeyboardOpen => keyboardInset > 0;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// The 600dp breakpoint, on the short side so it survives rotation.
  bool get isTablet => MediaQuery.sizeOf(this).shortestSide >= 600;

  /// Drops focus and closes the keyboard.
  void unfocus() => FocusScope.of(this).unfocus();
}

extension FormX on GlobalKey<FormState> {
  /// Runs every validator under the form: `if (_formKey.isValid) submit();`.
  /// False when the form is not mounted.
  bool get isValid => currentState?.validate() ?? false;
}

extension TextEditingControllerX on TextEditingController {
  /// The text without surrounding whitespace:
  /// `login(email: _email.trimmed, password: _password.text)`. Leave passwords
  /// untrimmed.
  String get trimmed => text.trim();

  /// [trimmed], or null when blank.
  String? get trimmedOrNull {
    final value = text.trim();
    return value.isEmpty ? null : value;
  }
}

extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(this);

  bool? isValidUrl() {
    if (isEmpty) return null;
    final uri = Uri.tryParse(this);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  /// Empty once whitespace is discounted — the check `isEmpty` misses on '  '.
  bool get isBlank => trim().isEmpty;

  /// This string, or null when blank — for API fields better omitted than ''.
  String? get nullIfBlank => isBlank ? null : this;

  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Capitalises every word: 'ana maria' -> 'Ana Maria'.
  String get capitalizeWords =>
      split(' ').map((word) => word.isEmpty ? word : word.capitalize).join(' ');

  /// Up to two initials for an avatar: 'Ana Maria Silva' -> 'AS'.
  String get initials {
    final words = trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '';
    if (words.length == 1) {
      final word = words.first;
      return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  /// Cuts to at most [max] characters, ellipsis included.
  String truncate(int max, {String ellipsis = '…'}) {
    if (length <= max) return this;
    if (max <= ellipsis.length) return substring(0, max);
    return '${substring(0, max - ellipsis.length).trimRight()}$ellipsis';
  }

  bool get isNumeric => num.tryParse(this) != null;

  String get digitsOnly => replaceAll(RegExp(r'\D'), '');

  /// Strips accents: 'São Paulo' -> 'Sao Paulo'.
  String get withoutDiacritics {
    final buffer = StringBuffer();
    for (final char in split('')) {
      final index = _accented.indexOf(char);
      buffer.write(index == -1 ? char : _unaccented[index]);
    }
    return buffer.toString();
  }

  /// Lower case and accent-free, so 'sao' matches 'São'.
  String get searchKey => withoutDiacritics.toLowerCase().trim();

  /// True when [query] appears in this string, ignoring case and accents.
  bool matchesSearch(String query) => searchKey.contains(query.searchKey);

  int? get toIntOrNull => int.tryParse(this);
  double? get toDoubleOrNull => double.tryParse(this);

  /// Parses `#RGB`, `#RRGGBB` or `#AARRGGBB`; null when it is not a hex color.
  Color? toColor() {
    var hexColor = replaceAll('#', '').trim();
    if (hexColor.length == 3) {
      hexColor = hexColor.split('').map((c) => '$c$c').join();
    }
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    if (hexColor.length != 8) return null;

    final value = int.tryParse(hexColor, radix: 16);
    return value == null ? null : Color(value);
  }

  /// Parses this string as a date; returns null when no known format matches.
  DateTime? toDateTime() {
    final formats = [
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'd/M/yyyy',
      'M/d/yyyy',
      'dd-MM-yyyy',
      'MM-dd-yyyy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseStrict(this);
      } catch (_) {}
    }

    final parts = split(RegExp(r'[/\-]'));
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);

      if (a != null && b != null && c != null) {
        // c is year if > 31, assume d/M/yyyy
        if (c > 31) return DateTime(c, b, a);
        // a is year if > 31, assume yyyy/M/d
        if (a > 31) return DateTime(a, b, c);
      }
    }
    return null;
  }
}

extension NullableStringX on String? {
  /// Null, empty, or whitespace — the check you actually want on an API field.
  bool get isNullOrBlank => this?.trim().isEmpty ?? true;

  bool get isNotNullOrBlank => !isNullOrBlank;

  /// This string, or '' when it is null — for feeding a Text widget.
  String get orEmpty => this ?? '';
}

extension DateTimeX on DateTime {
  String get formattedDate =>
      '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  String get formattedDateTime => '$formattedDate $formattedTime';

  /// yyyy-MM-ddTHH:mm:ss.mmmZ, converted to UTC.
  String get formatedDateTimeToDatabase => toUtc().toIso8601String();

  // yyyy-MM-dd
  String get formattedDateToDatabase =>
      "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";

  /// Formats with any [DateFormat] pattern: `format('EEE, d MMM')`.
  String format(String pattern, [String? locale]) =>
      DateFormat(pattern, locale).format(this);

  bool get isToday => isSameDay(DateTime.now());

  bool get isYesterday =>
      isSameDay(DateTime.now().subtract(const Duration(days: 1)));

  bool get isTomorrow => isSameDay(DateTime.now().add(const Duration(days: 1)));

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool isSameMonth(DateTime other) =>
      year == other.year && month == other.month;

  bool get isPast => isBefore(DateTime.now());
  bool get isFuture => isAfter(DateTime.now());

  /// Midnight on this date — the value to compare or group days by.
  DateTime get startOfDay => DateTime(year, month, day);

  /// The last instant of this date, for an inclusive range end.
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  DateTime get startOfMonth => DateTime(year, month);

  /// Day 0 of the next month is the last day of this one.
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  /// Whole years since this date — an age, or how long ago something happened.
  int get yearsSince {
    final now = DateTime.now();
    final had = now.month > month || (now.month == month && now.day >= day);
    return now.year - year - (had ? 0 : 1);
  }

  TimeOfDay get toTimeOfDay => TimeOfDay(hour: hour, minute: minute);

  String timeAgo() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'just now';
    }
  }
}

extension TimeOfDayX on TimeOfDay {
  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Minutes since midnight — the number to sort or compare two times by.
  int get minutesOfDay => hour * 60 + minute;

  bool isBefore(TimeOfDay other) => minutesOfDay < other.minutesOfDay;
  bool isAfter(TimeOfDay other) => minutesOfDay > other.minutesOfDay;

  /// This time of day on [date] — merges a separate date and time field.
  DateTime onDate(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);
}

extension DurationX on Duration {
  /// `m:ss`, or `h:mm:ss` once it passes an hour — media and timer style.
  String get formatted {
    final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');
    if (inHours > 0) {
      final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
      return '$inHours:$minutes:$seconds';
    }
    return '${inMinutes.remainder(60)}:$seconds';
  }
}

extension NumX on num {
  String formatCurrency(String code) {
    return NumberFormat.simpleCurrency(name: code).format(this);
  }

  /// Fixed decimals with locale grouping: `1234.5.formatDecimal()` -> '1,234.50'.
  String formatDecimal({int decimals = 2}) =>
      NumberFormat.decimalPatternDigits(decimalDigits: decimals).format(this);

  /// Short form for counters and charts: 1200 -> '1.2K'.
  String get formatCompact => NumberFormat.compact().format(this);

  /// Formats as a percentage. Give it a ratio, not a number out of 100:
  /// `0.42.formatPercent()` -> '42%'.
  String formatPercent({int decimals = 0}) =>
      '${(this * 100).toStringAsFixed(decimals)}%';
}

extension NullableListX<T> on List<T>? {
  bool get isNullOrEmpty => this?.isEmpty ?? true;
  bool get isNotNullOrEmpty => !isNullOrEmpty;
}

// Accented characters and their plain equivalents, index for index.
const _accented = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÑñÇç';
const _unaccented = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuNnCc';
''';

  /// Returns the generated appConstants template.
  ///
  /// [withDark] adds the second palette `AppTheme.dark` is built from. Without
  /// it the file holds one brand palette and nothing else — see
  /// `moarch create theme --dark` for adding the dark half later.
  static String appConstants({bool withDark = false}) {
    final darkPalette = withDark
        ? r'''

  // ── Palette (dark) ────────────────────────────────────────────────────────
  // Counterparts of the tokens above; AppTheme.dark reads these.
  static const Color primaryDark   = Color(0xFFFFFFFF);
  static const Color secondaryDark = Color(0xFFFFFFFF);
  static const Color tertiaryDark  = Color(0xFFFFFFFF);
  static const Color surfaceDark   = Color(0xFF121212);
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color onSurfaceMutedDark = Color(0xFFB3B3B3);
  static const Color outlineDark   = Color(0xFFFFFFFF);
  static const Color errorDark     = Color(0xFFffb4ab);

  static const Color onPrimaryDark   = surfaceDark;
  static const Color onSecondaryDark = surfaceDark;
  static const Color onTertiaryDark  = surfaceDark;

  static const Color surfaceContainerLowestDark  = Color(0xFF0A0A0A);
  static const Color surfaceContainerLowDark     = Color(0xFF1E1E1E);
  static const Color surfaceContainerHighestDark = Color(0xFF2C2C2C);

  static const Color successDark = Color(0xFF66BB6A);
  static const Color warningDark = Color(0xFFFFA726);
  static const Color infoDark    = Color(0xFF29B6F6);
'''
        : '';

    return '''
import 'package:flutter/material.dart';

abstract final class AppConstants {
  // ── Brand palette — 60-30-10 ──────────────────────────────────────────────
  // 60  surface: the scaffold, the large calm background.
  // 30  surfaceContainer*, onSurfaceMuted, outline: cards, bars, inputs,
  //     secondary text — the structure around the content.
  // 10  primary: primary actions, selected and focused states, progress.
  //     The only accent; secondary and tertiary are for charts and
  //     illustrations, not for competing buttons.
  // Contrast to check when you fill these in (WCAG AA):
  //   onPrimary on primary, onSurface and onSurfaceMuted on surface and on
  //   every surfaceContainer — 4.5:1. primary on surface — 4.5:1 (text
  //   buttons, links). outline on surface — 3:1 (input and checkbox edges).
  static const Color primary   = Color(0xFF000000);
  static const Color secondary = Color(0xFF000000);
  static const Color tertiary  = Color(0xFF000000);
  static const Color surface   = Color(0xFF000000);
  static const Color onSurface = Color(0xFF000000);
  static const Color onSurfaceMuted = Color(0xFF000000); // secondary text, hints
  static const Color outline   = Color(0xFF000000);
  static const Color error     = Color(0xFFba1a1a);

  // What reads on top of each accent. Point them at a dark color when the
  // accent is light (yellow, lime, cyan).
  static const Color onPrimary   = surface;
  static const Color onSecondary = surface;
  static const Color onTertiary  = surface;

  // ── Surface layers ────────────────────────────────────────────────────────
  static const Color surfaceContainerLowest  = Color(0xFF000000);
  static const Color surfaceContainerLow     = Color(0xFF000000);
  static const Color surfaceContainerHighest = Color(0xFF000000);

  // ── Status colors ─────────────────────────────────────────────────────────
  // Outside the palette, so they survive a rebrand. Deep enough to pass
  // 4.5:1 as text on white and on their own 12% tint (AppTag, AppBanner).
  static const Color success = Color(0xFF2A6B2E);
  static const Color warning = Color(0xFF9A4A00);
  static const Color info    = Color(0xFF0265A8);
$darkPalette
  // ── Type ──────────────────────────────────────────────────────────────────
  // Null uses the platform default. Name a font declared in pubspec.yaml here.
  static const String? fontFamily = null;

  // ── Avatar background fallbacks ───────────────────────────────────────────
  static const List<Color> avatarPalette = [
    Color(0xFFEF5350), Color(0xFFAB47BC), Color(0xFF5C6BC0),
    Color(0xFF29B6F6), Color(0xFF26A69A), Color(0xFF9CCC65),
    Color(0xFFFFCA28), Color(0xFFFF7043), Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];

  // ── Spacing — 4pt grid ────────────────────────────────────────────────────
  static const double space4  = 4;
  static const double space8  = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ── Padding helpers ───────────────────────────────────────────────────────
  static const padding4  = EdgeInsets.all(space4);
  static const padding12 = EdgeInsets.all(space12);
  static const padding16 = EdgeInsets.all(space16);
  static const padding24 = EdgeInsets.all(space24);

  static const paddingV8 = EdgeInsets.symmetric(vertical: space8);

  static const paddingPage = EdgeInsets.symmetric(
    horizontal: space12,
    vertical: space12,
  );

  // ── Icon sizes ────────────────────────────────────────────────────────────
  static const double iconSmall = 16;
  static const double iconMedium = 24;
  static const double iconLarge = 32;

  // ── Text sizes — the TextTheme's scale (app_theme.dart) ───────────────────
  // Prefer the theme's roles (`textTheme.bodyMedium`) over these; they are
  // for the few places a size is computed rather than picked.
  static const double fontSize11 = 11; // labelSmall
  static const double fontSize12 = 12; // labelMedium / bodySmall
  static const double fontSize13 = 13; // calendar cells
  static const double fontSize14 = 14; // labelLarge / bodyMedium / titleSmall
  static const double fontSize16 = 16; // bodyLarge / titleMedium
  static const double fontSize22 = 22; // titleLarge
  static const double fontSize28 = 28; // headlineMedium

  // ── Touch targets — iOS HIG 44pt minimum, Material 48dp ───────────────────
  static const double touchTarget = 48;

  // ── Border radius — Material medium = 12, iOS cards ≈ 10–13 ──────────────
  static const double radius4  = 4;
  static const double radius8  = 8;
  static const double radius12 = 12; // Material medium / iOS card
  static const double radius16 = 16; // Material large
  static const double radius24 = 24; // bottom sheets, large cards
  static const double radiusFull = 999; // pills / chips

  static final borderRadius4    = BorderRadius.circular(radius4);
  static final borderRadius8    = BorderRadius.circular(radius8);
  static final borderRadius12   = BorderRadius.circular(radius12);
  static final borderRadius16   = BorderRadius.circular(radius16);
  static final borderRadiusFull = BorderRadius.circular(radiusFull);

  // ── Animation durations ───────────────────────────────────────────────────
  static const Duration duration200 = Duration(milliseconds: 200);
  static const Duration duration300 = Duration(milliseconds: 300);
  static const Duration duration500 = Duration(milliseconds: 500);

  // ── Motion curves ─────────────────────────────────────────────────────────
  static const Curve curveStandard = Curves.easeInOut;
  static const Curve curveEnter = Curves.easeOutCubic;
  static const Curve curveExit = Curves.easeInCubic;
}
''';
  }

  /// The `AppConstants` tokens a widget may read that older projects lack, and
  /// the literal each one stands for.
  ///
  /// `app_constants.dart` is the first file a team edits — it holds the
  /// palette — so `update` almost never refreshes it, while the widgets
  /// reading it are refreshed freely. A widget written against a token the
  /// project's constants do not declare would not compile, so
  /// [inlineMissingTokens] writes these literals in their place: the same
  /// value, just not shared.
  static const Map<String, String> tokenLiterals = {
    'AppConstants.curveStandard': 'Curves.easeInOut',
    'AppConstants.curveEnter': 'Curves.easeOutCubic',
    'AppConstants.curveExit': 'Curves.easeInCubic',
  };

  /// [source] with every [tokenLiterals] token replaced by its literal — for
  /// a project whose `AppConstants` predates them.
  static String inlineMissingTokens(String source) {
    var out = source;
    tokenLiterals.forEach((token, literal) {
      out = out.replaceAll(token, literal);
    });
    return out;
  }

  /// The color roles `AppTheme` reads that an `AppConstants` from before 9.9.0
  /// lacks, and the token each one fell back to then.
  ///
  /// `app_theme.dart` is refreshed by `update` while the constants it reads
  /// are almost never, so a theme written against these roles would not
  /// compile in a project whose palette predates them. The fallbacks are the
  /// colors the old theme used, so the refreshed theme looks the way the old
  /// one did. Every literal is const, as the theme reads some of them in a
  /// const context.
  static const Map<String, String> colorRoleLiterals = {
    'AppConstants.onPrimaryDark': 'AppConstants.surfaceDark',
    'AppConstants.onSecondaryDark': 'AppConstants.surfaceDark',
    'AppConstants.onTertiaryDark': 'AppConstants.surfaceDark',
    'AppConstants.onSurfaceMutedDark': 'AppConstants.onSurfaceDark',
    'AppConstants.onPrimary': 'AppConstants.surface',
    'AppConstants.onSecondary': 'AppConstants.surface',
    'AppConstants.onTertiary': 'AppConstants.surface',
    'AppConstants.onSurfaceMuted': 'AppConstants.onSurface',
  };

  /// [source] with every [colorRoleLiterals] role replaced by its fallback —
  /// for a project whose `AppConstants` predates them.
  ///
  /// The `*Dark` roles come first in the map so `onPrimary` never matches
  /// the front of `onPrimaryDark`.
  static String inlineMissingColorRoles(String source) {
    var out = source;
    colorRoleLiterals.forEach((role, literal) {
      out = out.replaceAll(role, literal);
    });
    return out;
  }

  /// Whether [constantsSource] (an `app_constants.dart`) declares the color
  /// roles in [colorRoleLiterals]. Matches the declaration, not a mention —
  /// the palette's own comment names the role.
  static bool declaresColorRoles(String constantsSource) =>
      RegExp(r'\bColor\s+onSurfaceMuted\b').hasMatch(constantsSource);

  /// The comment `moarch create feature` inserts each feature's endpoint
  /// above. Load-bearing: the generated source says so.
  static const String endpointsAnchor = '// moarch:endpoints';

  /// Returns the generated apiConstants template.
  ///
  /// Every path the app calls is declared here rather than at its call site,
  /// so a changed route is one edit. [withAuthFeature] adds the `/auth/*`
  /// paths — `dio_client.dart` also reads the public ones, as the routes that
  /// go out without an `Authorization` header — and [withDeviceToken] the one
  /// the push token is registered at. [withMaintenanceGate] and
  /// [withUpdateGate] add the config paths the Dio-backed gates poll.
  static String apiConstants({
    bool withAuthFeature = false,
    bool withDeviceToken = false,
    bool withMaintenanceGate = false,
    bool withUpdateGate = false,
  }) {
    final deviceToken = withDeviceToken
        ? '''


  /// Where this device's push token is registered for the signed-in user.
  static const authDeviceToken = '/auth/device-token';'''
        : '';

    final authEndpoints = withAuthFeature
        ? '''


  // ── Auth ──────────────────────────────────────────────────────────────────
  // Also used by `dio_client.dart` for its public (no token) routes.
  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';

  /// The signed-in account: GET reads the user, DELETE deletes the account.
  static const authAccount = '/auth/me';$deviceToken'''
        : '';

    final maintenance = withMaintenanceGate
        ? "\n  static const configMaintenance = '/config/maintenance';"
        : '';
    final appVersion = withUpdateGate
        ? "\n  static const configAppVersion = '/config/app-version';"
        : '';
    final configEndpoints = withMaintenanceGate || withUpdateGate
        ? '''


  // ── Config ────────────────────────────────────────────────────────────────
  // Polled by the gates in `shared/widgets/`, signed in or not — add them to
  // `_kPublicEndpoints` in `dio_client.dart`.$maintenance$appVersion'''
        : '';

    return '''
abstract final class ApiConstants {
  // BASE_URL comes from envied
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);$authEndpoints$configEndpoints

  // ── Features ──────────────────────────────────────────────────────────────
  // Every endpoint lives here. `moarch create feature` adds each new feature's
  // path above this anchor — keep it:
  $endpointsAnchor
}
''';
  }

  /// The paths a template may reach through `ApiConstants` that an older
  /// project's `api_constants.dart` does not declare, by constant name.
  ///
  /// The same problem [tokenLiterals] solves for `AppConstants`: the
  /// constants file is edited by every team, so `update` rarely refreshes it,
  /// while the files reading it are refreshed freely. [inlineMissingEndpoints]
  /// writes these in place of an undeclared constant.
  static const Map<String, String> endpointLiterals = {
    'authDeviceToken': '/auth/device-token',
    'configMaintenance': '/config/maintenance',
    'configAppVersion': '/config/app-version',
  };

  /// The constant names [apiConstants] source declares.
  static Set<String> declaredEndpoints(String apiConstants) => {
    for (final match in RegExp(
      r'static const (?:\w+ )?(\w+)\s*=',
    ).allMatches(apiConstants))
      match[1]!,
  };

  /// [source] with every [endpointLiterals] constant that [declared] lacks
  /// replaced by its path — and the `api_constants.dart` import dropped when
  /// nothing uses it any more.
  static String inlineMissingEndpoints(String source, Set<String> declared) {
    var out = source;
    endpointLiterals.forEach((name, path) {
      if (!declared.contains(name)) {
        out = out.replaceAll('ApiConstants.$name', "'$path'");
      }
    });
    if (out != source && !out.contains('ApiConstants.')) {
      out = out.replaceAll(
        RegExp(
          r"^import '[./]*core/constants/api_constants\.dart';\n",
          multiLine: true,
        ),
        '',
      );
    }
    return out;
  }

  /// Returns the generated safeApiCall template.
  ///
  /// There is no connectivity pre-flight: `connectivity_plus` reports which
  /// interface is up, not whether the request can reach anything, so a
  /// captive portal or a VPN reads as online while the call still fails — and
  /// asking cost a platform round-trip on every request. The failure itself
  /// says it better, so an offline call is recognised from what Dio throws.
  static String safeApiCall() => '''
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/errors/app_exception.dart';

/// Whether [error] means the request never reached the server.
bool _isOffline(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    // Dio leaves a bare socket failure unclassified.
    (error.type == DioExceptionType.unknown && error.error is SocketException);

Future<T> safeApiCall<T>({
  required Future<T> Function() apiCall,
  FutureOr<T>? Function()? onNoInternet, // optional cache fallback
}) async {
  try {
    return await apiCall();
  } on DioException catch (e) {
    if (_isOffline(e)) {
      if (onNoInternet != null) {
        final fallback = await onNoInternet();
        if (fallback != null) return fallback;
      }
      throw AppException.noInternet();
    }
    throw AppException.fromDioError(e);
  } catch (e, s) {
    throw AppException.fromError(e, s);
  }
}
''';

  /// Returns the generated Paginated template.
  ///
  /// A page of items plus the key of the page after it. The key is whatever
  /// the backend pages by — a page number, an offset, a cursor string — and
  /// nothing past the datasource reads it: the repository hands it back up,
  /// the notifier or bloc stores it in a `PagedList`, and passes it down again
  /// for the next page. That is what lets one type cover all three APIs, and
  /// why `next` is an `Object?` rather than an `int`.
  ///
  /// One factory per envelope shape, each reading its keys leniently, since
  /// the shape is the backend's choice rather than the app's. A page-number
  /// or offset API without a `total` ends on the first short page — the rule
  /// mo_infinite_scroll used, kept as the fallback.
  ///
  /// Written whenever Dio is, alongside `safeApiCall` and `PagedList`.
  static String paginated() => r'''
/// A page of [T] as the API returned it, and the key of the page after it.
///
/// [next] is what the backend pages by — a page number, an offset or a cursor
/// — and null on the last page. Only the datasource reads it; everything above
/// passes it back unopened, so switching an endpoint from pages to cursors
/// touches the datasource alone:
///
/// ```dart
/// Future<Paginated<OrderModel>> fetchOrders({Object? next}) => safeApiCall(
///   apiCall: () async {
///     final response = await _dio.get(
///       ApiConstants.orders,
///       queryParameters: {'cursor': next, 'limit': 20},
///     );
///     return Paginated.fromCursorJson(
///       response.data as Map<String, dynamic>,
///       (e) => OrderModel.fromJson(e! as Map<String, dynamic>),
///     );
///   },
/// );
/// ```
///
/// Edit the factories' default keys to match your envelope.
class Paginated<T> {
  const Paginated({required this.items, this.next, this.total});

  /// A response that was never paginated server-side, read as the only page.
  factory Paginated.single(List<T> items) =>
      Paginated(items: items, total: items.length);

  /// The empty last page.
  const Paginated.empty() : items = const [], next = null, total = 0;

  /// `{page, limit, total, data}` — [next] is the following page number.
  ///
  /// Ask for the first page with `next ?? 1`.
  factory Paginated.fromPageJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT, {
    String dataKey = 'data',
    String pageKey = 'page',
    String limitKey = 'limit',
    String totalKey = 'total',
  }) {
    final items = _itemsOf(json[dataKey], fromJsonT);
    final page = _asInt(json[pageKey]) ?? 1;
    final limit = _asInt(json[limitKey]);
    final total = _asInt(json[totalKey]);
    return Paginated(
      items: items,
      total: total,
      next: _hasMore(items, limit, total, seen: page * (limit ?? items.length))
          ? page + 1
          : null,
    );
  }

  /// `{offset, limit, total, data}` — [next] is the following offset.
  ///
  /// Ask for the first page with `next ?? 0`.
  factory Paginated.fromOffsetJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT, {
    String dataKey = 'data',
    String offsetKey = 'offset',
    String limitKey = 'limit',
    String totalKey = 'total',
  }) {
    final items = _itemsOf(json[dataKey], fromJsonT);
    final seen = (_asInt(json[offsetKey]) ?? 0) + items.length;
    final limit = _asInt(json[limitKey]);
    final total = _asInt(json[totalKey]);
    return Paginated(
      items: items,
      total: total,
      next: _hasMore(items, limit, total, seen: seen) ? seen : null,
    );
  }

  /// `{data, next_cursor}` — [next] is the cursor the server sent.
  ///
  /// A missing, null or empty cursor is the last page. Ask for the first page
  /// by leaving the cursor out.
  factory Paginated.fromCursorJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT, {
    String dataKey = 'data',
    String cursorKey = 'next_cursor',
    String totalKey = 'total',
  }) {
    final cursor = json[cursorKey];
    return Paginated(
      items: _itemsOf(json[dataKey], fromJsonT),
      total: _asInt(json[totalKey]),
      next: cursor == null || cursor == '' ? null : cursor,
    );
  }

  /// The items on this page.
  final List<T> items;

  /// The key of the page after this one, or null when this is the last.
  final Object? next;

  /// How many items exist across every page, when the backend says.
  final int? total;

  /// Whether a page exists after this one.
  bool get hasMore => next != null;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  /// The same page with every item mapped.
  Paginated<R> map<R>(R Function(T item) toItem) => Paginated<R>(
    items: items.map(toItem).toList(),
    next: next,
    total: total,
  );
}

/// The item list under a page's data key. A null or absent list is an empty
/// page, not a cast failure.
List<T> _itemsOf<T>(Object? raw, T Function(Object? json) fromJsonT) =>
    raw is List ? raw.map(fromJsonT).toList() : <T>[];

/// Whether a page-number or offset API has more after [seen] items: the
/// [total] when the backend sends one, otherwise a full page.
bool _hasMore<T>(List<T> items, int? limit, int? total, {required int seen}) {
  if (items.isEmpty) return false;
  if (total != null) return seen < total;
  return limit == null || items.length >= limit;
}

/// Reads a count sent as a number, a numeric string, or not at all.
int? _asInt(Object? value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  final String v => int.tryParse(v),
  _ => null,
};
''';

  /// The `PagedList` class both stacks' `paged_list.dart` open with.
  ///
  /// Stack-neutral on purpose: it is a value a state holds, and only the mixin
  /// that writes it differs between a notifier and a bloc. Kept here, once, so
  /// the two files cannot drift.
  static const String pagedListState = r'''
/// A list that loads in pages, as a notifier's or a bloc's state holds it.
///
/// The first page is loaded like any other screen data — the skeleton, the
/// error screen and the empty state are `AppAsyncView` / `AppStatusView`'s.
/// This tracks what comes after: the key of the next page, whether one
/// exists, and whether loading it is running or has failed. `AppPagedList`
/// draws those last two as the row at the end of the list.
class PagedList<T> {
  const PagedList({
    this.items = const [],
    this.next,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.error,
  });

  /// The list holding [page] as its first page.
  factory PagedList.first(Paginated<T> page) =>
      PagedList(items: page.items, next: page.next, hasMore: page.hasMore);

  /// Every item loaded so far.
  final List<T> items;

  /// The key to ask for the next page with. Only the datasource opens it.
  final Object? next;

  /// Whether a page exists after the last one loaded.
  final bool hasMore;

  /// Whether the next page is loading.
  final bool isLoadingMore;

  /// Why the next page failed to load, or null. Loading again clears it.
  final String? error;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  /// This list, loading its next page.
  PagedList<T> loading() => PagedList(
    items: items,
    next: next,
    hasMore: hasMore,
    isLoadingMore: true,
  );

  /// This list with [page] appended.
  PagedList<T> append(Paginated<T> page) => PagedList(
    items: [...items, ...page.items],
    next: page.next,
    hasMore: page.hasMore,
  );

  /// This list, its next page having failed with [message].
  PagedList<T> failed(String message) =>
      PagedList(items: items, next: next, hasMore: hasMore, error: message);

  /// This list with its items replaced — after an edit or a delete, without
  /// losing the place it has paged to.
  PagedList<T> withItems(List<T> items) => PagedList(
    items: items,
    next: next,
    hasMore: hasMore,
    isLoadingMore: isLoadingMore,
    error: error,
  );
}
''';

  /// Returns the generated safeFirebaseCall template.
  ///
  /// [withAuth] adds the `FirebaseAuthException` arm, which must come first —
  /// it is a subtype of `FirebaseException`.
  static String safeFirebaseCall({bool withAuth = false}) {
    final authImport = withAuth
        ? "import 'package:firebase_auth/firebase_auth.dart';\n"
        : '';

    final authCatch = withAuth
        ? '\n  } on FirebaseAuthException catch (e) {'
              '\n    // Before FirebaseException — it is a subtype of it.'
              '\n    throw AppException.fromFirebaseAuthError(e);'
        : '';

    final authStreamCatch = withAuth
        ? '''
    if (error is FirebaseAuthException) {
      throw AppException.fromFirebaseAuthError(error);
    }
'''
        : '';

    return '''
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
$authImport
import '../errors/app_exception.dart';

/// Anything that comes back wrong arrives as an [AppException], the same as
/// `safeApiCall`.
///
/// Unlike it, this one still asks about connectivity before the call. Keep
/// that in mind if you turn on Firestore's offline persistence: the cache can
/// answer a read with no network at all, and the check below would refuse it
/// first. Drop the check for those calls, or pass `onNoInternet`.
Future<T> safeFirebaseCall<T>({
  required Future<T> Function() call,
  FutureOr<T>? Function()? onNoInternet, // optional cache fallback
}) async {
  final connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult.contains(ConnectivityResult.none)) {
    if (onNoInternet != null) {
      final fallback = await onNoInternet();
      if (fallback != null) return fallback;
    }
    throw AppException.noInternet();
  }

  try {
    return await call();
  } on AppException {
    // Already mapped by an inner call — re-wrapping it would bury the message.
    rethrow;$authCatch
  } on FirebaseException catch (e) {
    throw AppException.fromFirebaseError(e);
  } catch (e, s) {
    throw AppException.fromError(e, s);
  }
}

/// The same mapping for a Firestore stream.
///
/// Connectivity is not checked here — Firestore serves its local cache while
/// offline and catches up when the connection returns.
Stream<T> safeFirebaseStream<T>(Stream<T> Function() stream) {
  return stream().handleError((Object error, StackTrace stackTrace) {
    if (error is AppException) throw error;
$authStreamCatch    if (error is FirebaseException) {
      throw AppException.fromFirebaseError(error);
    }
    throw AppException.fromError(error, stackTrace);
  });
}
''';
  }

  /// Returns the generated timestampConverter template.
  ///
  /// Firestore's own date type is `Timestamp`, and json_serializable knows
  /// nothing about it — left alone it would write a `DateTime` out as an ISO
  /// string, which sorts as text and takes a range query with it. This is the
  /// translation, and it belongs to the model layer alone: `domain/` keeps
  /// plain `DateTime`s.
  static String timestampConverter() => r'''
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// Keeps a `DateTime` field stored as a Firestore `Timestamp`.
///
/// Annotate the field on the model:
///
///   const factory OrderModel({
///     @TimestampConverter() required DateTime placedAt,
///     @NullableTimestampConverter() DateTime? shippedAt,
///   }) = _OrderModel;
///
/// Why it matters: without it json_serializable writes the date as an ISO
/// string. Firestore then sorts and ranges it as text, so `where('placedAt',
/// isGreaterThan: ...)` compares character by character and an index on the
/// field is useless. A `Timestamp` is a real point in time to the server.
///
/// **Everything comes back in UTC**, so keep your dates in UTC too —
/// `DateTime.now().toUtc()`. `Timestamp.toDate()` hands back the device's
/// local time, which means the same document reads as a different `DateTime`
/// on two phones. That is not cosmetic: a freezed model compares dates with
/// `==`, and `DateTime` counts its UTC flag as part of equality — so a state
/// rebuilt from a fresh read would differ from the one already on screen for
/// no reason a user could see. Call `.toLocal()` where you *display* a date.
class TimestampConverter implements JsonConverter<DateTime, Object?> {
  /// Creates the converter. `const` so it can be used as an annotation.
  const TimestampConverter();

  @override
  DateTime fromJson(Object? json) {
    if (json is Timestamp) return json.toDate().toUtc();
    // Documents written by a seed script, an export or another SDK often hold
    // the date as a string or as epoch millis. Reading those costs nothing and
    // saves a migration.
    if (json is String) return DateTime.parse(json).toUtc();
    if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json, isUtc: true);
    }
    throw FormatException('Not a Firestore timestamp', json);
  }

  @override
  Object toJson(DateTime date) => Timestamp.fromDate(date);
}

/// [TimestampConverter] for a field that may be absent.
///
/// A separate class because a `JsonConverter<DateTime, …>` cannot be applied
/// to a `DateTime?` field — the types have to line up.
class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  /// Creates the converter. `const` so it can be used as an annotation.
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? json) =>
      json == null ? null : const TimestampConverter().fromJson(json);

  @override
  Object? toJson(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
}
''';

  /// Returns the generated dioClient template.
  ///
  /// The same client in both stacks: `buildDioClient` takes the
  /// `TokenStorage` the locator holds, and `injector.dart` registers the
  /// result as a lazy singleton. Nothing about a REST client depends on how
  /// state is held, so there is one of these rather than two.
  static String dioClient({bool withAuthFeature = false}) {
    final publicEndpoints = withAuthFeature
        ? r'''
  // Routes that never get the Authorization header or a refresh retry.
  ApiConstants.authLogin,
  ApiConstants.authRegister,
  ApiConstants.authRefresh,'''
        : r'''
  // Routes that never receive the Authorization header (and are never
  // retried after a token refresh). Add your API's sign-in routes here.''';

    // Only the auth feature has a session to refresh; without it a 401 is
    // just a 401.
    final refreshParam = withAuthFeature
        ? r'''
Dio buildDioClient(
  TokenStorage storage, {
  // Trades the refresh token for a new session; throws an AppException when it
  // cannot. A callback, since the auth repository is built on this client.
  required Future<void> Function() refreshSession,
}) {'''
        : 'Dio buildDioClient(TokenStorage storage) {';

    final exceptionImport = withAuthFeature
        ? "import '../errors/app_exception.dart';\n"
        : '';

    final refreshOnError = withAuthFeature
        ? r'''
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final alreadyRetried =
              error.requestOptions.extra[_kRetriedAfterRefresh] == true;
          if (status != 401 ||
              alreadyRetried ||
              _isPublicPath(error.requestOptions.path)) {
            return handler.next(error);
          }

          // Session expired: refresh, then retry once.
          try {
            await refreshSession();
          } on NetworkException {
            // Offline says nothing about the session: keep the tokens.
            return handler.next(error);
          } catch (_) {
            // Refresh token gone or rejected: clear the session (back to login).
            await storage.clearSession();
            return handler.next(error);
          }

          try {
            final options = error.requestOptions
              ..extra[_kRetriedAfterRefresh] = true;
            // Re-entering the chain lets onRequest attach the new token.
            final response = await dio.fetch<dynamic>(options);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },'''
        : r'''
        onError: (error, handler) => handler.next(error),''';

    final retryConst = withAuthFeature
        ? "\n\nconst _kRetriedAfterRefresh = '__retried_after_refresh__';"
        : '';

    return '''
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';

import '../../config/env/app_env.dart';
import '../constants/api_constants.dart';
${exceptionImport}import '../security/secure_storage.dart';
import '../utils/app_logger.dart';

final _log = appLogger.scoped('Dio');

const _kPublicEndpoints = <String>[
$publicEndpoints
];

bool _isPublicPath(String path) {
  final cleanPath = path.split('?').first;
  return _kPublicEndpoints.any(
    (endpoint) => cleanPath == endpoint || cleanPath.startsWith('\$endpoint/'),
  );
}

/// Builds the app's one Dio client (a lazy singleton in the injector).
$refreshParam
  final dio = Dio(
    BaseOptions(
      baseUrl: AppEnv.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  _configureHttpClient(dio);

  dio
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isPublicEndpoint = _isPublicPath(options.path);
          if (!isPublicEndpoint) {
            final token = await storage.accessToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer \$token';
            }
          }
          handler.next(options);
        },
$refreshOnError
      ),
    )
    ..interceptors.add(
      RetryInterceptor(dio: dio, logPrint: (msg) => _log.d(msg.toString())),
    );

  // Debug only, so release builds never serialise bodies. Credentials are
  // redacted by app_logger.dart.
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (msg) => _log.d(msg.toString()),
      ),
    );
  }

  return dio;
}$retryConst

void _configureHttpClient(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      if (kDebugMode) {
        client.badCertificateCallback = (cert, host, port) {
          _log.w(
            'Certificate verification skipped for \$host (debug mode)',
          );
          return true;
        };
      }
      return client;
    },
  );
}
''';
  }
}
