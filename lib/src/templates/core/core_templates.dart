/// Generates core scaffold file templates.
class CoreTemplates {
  CoreTemplates._();

  /// Returns the generated mainDart template.
  ///
  /// [withLocalization] (flutter_localizations) and [withEasyLocalization]
  /// are mutually exclusive; if both are set, easy_localization wins.
  static String mainDart({
    bool withRouter = true,
    bool withLocalization = false,
    bool withEasyLocalization = false,
    bool withNotificationsService = false,
    bool withFirebaseNotifications = false,
    bool withCrashlytics = false,
  }) {
    if (withEasyLocalization) withLocalization = false;

    final localizationImports = withEasyLocalization
        ? "\nimport 'package:easy_localization/easy_localization.dart';\n"
        : withLocalization
            ? "\nimport 'l10n/app_localizations.dart';\nimport 'l10n/l10n.dart';\nimport 'core/services/language_service.dart';\nimport 'package:flutter_localizations/flutter_localizations.dart';\n"
            : '';

    final easyLocalizationInit = withEasyLocalization
        ? '\n  await EasyLocalization.ensureInitialized();\n'
        : '';

    // The notification services are Riverpod providers that hold a `Ref`, so
    // they must be initialized through a container that also backs the widget
    // tree. When either is enabled we build that container in main() and hand
    // it to an UncontrolledProviderScope.
    final needsContainer =
        withNotificationsService || withFirebaseNotifications;

    final rootScope = needsContainer
        ? 'UncontrolledProviderScope(container: container, child: const App())'
        : 'const ProviderScope(child: App())';

    final runAppCall = withEasyLocalization
        ? '''runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('pt')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: $rootScope,
    ),
  );'''
        : 'runApp($rootScope);';

    final containerSetup =
        needsContainer ? '\n  final container = ProviderContainer();\n' : '';

    final notificationImport = withNotificationsService
        ? "\nimport 'core/services/notifications_service.dart';"
        : '';

    final notificationInit = withNotificationsService
        ? '\n  await container.read(notificationServiceProvider).init();'
        : '';

    final firebaseNotificationImport = withFirebaseNotifications
        ? "\nimport 'core/services/firebase_notifications_service.dart';"
        : '';

    // Placed after the Crashlytics block so its unguarded
    // Firebase.initializeApp() runs first; the FCM service only initializes
    // Firebase itself when no one else has.
    final firebaseNotificationInit = withFirebaseNotifications
        ? '\n  await container.read(firebaseNotificationsServiceProvider).init();'
        : '';

    final crashlyticsImports = withCrashlytics
        ? "\nimport 'package:firebase_core/firebase_core.dart';\nimport 'package:firebase_crashlytics/firebase_crashlytics.dart';"
        : '';

    final crashlyticsInit = withCrashlytics
        ? '''

  // Requires Firebase setup — run `flutterfire configure`, then pass the
  // generated options: Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
  await Firebase.initializeApp();
  // Only report crashes from release builds.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
'''
        : '';

    final crashlyticsUncaught = withCrashlytics
        ? '\n    FirebaseCrashlytics.instance.recordError(error, st, fatal: true);'
        : '';

    final crashlyticsFlutterError = withCrashlytics
        ? '\n    FirebaseCrashlytics.instance.recordFlutterFatalError(details);'
        : '';

    final localizationConfig = withEasyLocalization
        ? '''
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
'''
        : withLocalization
            ? '''
      locale: locale,
      supportedLocales: L10n.all,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
'''
            : '';

    final localizationWatch = withEasyLocalization
        ? '''
// Translate with 'welcome'.tr()
// Switch language with context.setLocale(const Locale('pt'));
'''
        : withLocalization
            ? '''
final locale = ref.watch(languageProvider).locale;
//final l10n = AppLocalizations.of(context);
'''
            : '';

    if (withRouter) {
      return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';$localizationImports$notificationImport$firebaseNotificationImport$crashlyticsImports
import 'core/utils/app_logger.dart';
import 'shared/widgets/error_view.dart';
import 'config/theme/app_theme.dart';
import 'config/router/app_router.dart';

Future<void> main() async {
  // Preserve the splash BEFORE anything else runs
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
$easyLocalizationInit$containerSetup$notificationInit
$crashlyticsInit$firebaseNotificationInit
  //::::::::::ERROR MANAGEMENT::::::::::
  PlatformDispatcher.instance.onError = (error, st) {
    appLogger.e('[Uncaught error]', error: error, stackTrace: st);$crashlyticsUncaught
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    appLogger.e('[Flutter error]', error: details.exception, stackTrace: details.stack);$crashlyticsFlutterError
    if (kDebugMode) {
      // default behaviour — shows red screen in dev
      FlutterError.presentError(details);
    }
    // in prod: logged but no red screen, app continues
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception); // red screen in dev
    return const Scaffold(body: ErrorView()); // your nice screen in prod
  };

  // OR REMOVE AFTER SOME ASYNC INIT IN A ROOT WIDGET
  FlutterNativeSplash.remove();

  $runAppCall
}
 
class App extends ConsumerWidget {
  const App({super.key});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    $localizationWatch

    // To reset ALL app state on logout, key a ProviderScope by your session.
    // Once you have an auth feature, uncomment and adapt:
    // final sessionKey = ref.watch(
    //   authNotifierProvider.select((s) => s.value?.authenticated ?? ''),
    // );

    return MaterialApp.router(
      title: 'App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      $localizationConfig
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
                  // Respect the system font-size setting but cap it so large
                  // scales don't break fixed layouts.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.35),
                  alwaysUse24HourFormat: true,
                ),
          //   ProviderScope(key: ValueKey(sessionKey), child: child!)
          child: child!,
        );
      },
    );
  }
}
''';
    }

    return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';$localizationImports$notificationImport$firebaseNotificationImport$crashlyticsImports
import 'core/utils/app_logger.dart';
import 'shared/widgets/error_view.dart';
import 'config/theme/app_theme.dart';

Future<void> main() async {
  // Preserve the splash BEFORE anything else runs
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
$easyLocalizationInit$containerSetup$notificationInit
$crashlyticsInit$firebaseNotificationInit
  //::::::::::ERROR MANAGEMENT::::::::::
  PlatformDispatcher.instance.onError = (error, st) {
    appLogger.e('[Uncaught error]', error: error, stackTrace: st);$crashlyticsUncaught
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    appLogger.e('[Flutter error]', error: details.exception, stackTrace: details.stack);$crashlyticsFlutterError
    if (kDebugMode) {
      // default behaviour — shows red screen in dev
      FlutterError.presentError(details);
    }
    // in prod: logged but no red screen, app continues
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception); // red screen in dev
    return const Scaffold(body: ErrorView()); // your nice screen in prod
  };

  // OR REMOVE AFTER SOME ASYNC INIT IN A ROOT WIDGET
  FlutterNativeSplash.remove();

  $runAppCall
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    $localizationWatch

    // To reset ALL app state on logout, key a ProviderScope by your session.
    // Once you have an auth feature, uncomment and adapt:
    // final sessionKey = ref.watch(
    //   authNotifierProvider.select((s) => s.value?.authenticated ?? ''),
    // );

    return MaterialApp(
      title: 'App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
$localizationConfig      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.35),
            alwaysUse24HourFormat: true,
          ),
          //   ProviderScope(key: ValueKey(sessionKey), child: child!)
          child: child!,
        );
      },
      // TODO: set your home widget
    );
  }
}
''';
  }

  /// Returns the generated appLogger template.
  ///
  /// [withCrashlytics] adds a second sink that mirrors records into Crashlytics
  /// as breadcrumbs, so a crash report arrives with the lines that led up to it.
  static String appLogger({bool withCrashlytics = false}) {
    final crashlyticsImport = withCrashlytics
        ? "\nimport 'package:firebase_core/firebase_core.dart';"
            "\nimport 'package:firebase_crashlytics/firebase_crashlytics.dart';"
        : '';

    // Kept at the tail of the file so the invariant body above has no seams:
    // the sink list is the only place the Crashlytics choice shows up.
    final sinks = withCrashlytics
        ? r'''
final _sinks = <LogOutput>[
  _DeveloperOutput(),
  _CrashlyticsOutput(),
];

/// Mirrors records into Crashlytics as breadcrumbs, so a crash report carries
/// the log lines that preceded it.
///
/// Breadcrumbs only — reporting a caught error stays an explicit
/// `FirebaseCrashlytics.instance.recordError(...)` at the call site, which is
/// the only place `reason` and `fatal` can actually be decided.
class _CrashlyticsOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Anything logged before main() reaches Firebase.initializeApp() — service
    // start-up, mostly — would otherwise throw on `instance`.
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

$_appLoggerBody// ─── Sinks ───────────────────────────────────────────────────────────────────

$sinks''';
  }

  /// The part of `app_logger.dart` that never varies with the selected stack.
  static const String _appLoggerBody = r'''
/// The app's logger.
///
/// Call sites talk to [AppLogger] rather than to the `logger` package, so how
/// logging works — where it goes, what it hides, when it stays quiet — is a
/// decision this one file owns.
final appLogger = AppLogger._();

class AppLogger {
  AppLogger._([this._tag]);

  final String? _tag;

  /// A logger that stamps every record with `[name]`.
  ///
  /// Prefer this over writing the prefix into each message by hand — the tag
  /// comes out spelled the same way every time, which is what makes a log
  /// filterable after the fact.
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

// ─── Backend ─────────────────────────────────────────────────────────────────

final _logger = Logger(
  // Release output is one line per record: it is headed for Crashlytics
  // breadcrumbs and device logs, where PrettyPrinter's box art is only noise.
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
  // Warnings and errors survive into release so a crash has context leading up
  // to it; everything below them is stripped. Set this to Level.off to silence
  // release builds completely.
  level: kReleaseMode ? Level.warning : Level.trace,
);

/// Writes through `dart:developer` rather than `print`, so DevTools' Logging
/// view gets one record per event with its severity attached — filterable,
/// instead of a wall of console text.
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

/// `dart:developer` grades severity on package:logging's scale, which [Level]
/// does not line up with on its own.
const _developerLevels = <Level, int>{
  Level.trace: 300,
  Level.debug: 500,
  Level.info: 800,
  Level.warning: 900,
  Level.error: 1000,
  Level.fatal: 1200,
};

// ─── Redaction ───────────────────────────────────────────────────────────────

/// Every sink runs this, rather than each call site remembering to — which is
/// what stops a stray `appLogger.d(response.data.toString())` from putting a
/// credential in the logs.
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

  /// Notch, status bar and home indicator — what a full-bleed layout has to
  /// keep clear of.
  EdgeInsets get safeInsets => MediaQuery.viewPaddingOf(this);

  /// How much of the screen the keyboard is covering right now.
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;
  bool get isKeyboardOpen => keyboardInset > 0;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// The 600dp Material breakpoint, measured on the short side so it survives
  /// rotation.
  bool get isTablet => MediaQuery.sizeOf(this).shortestSide >= 600;

  /// Drops focus and closes the keyboard — the "tap the background to dismiss"
  /// move, and what you want before pushing a route off a form.
  void unfocus() => FocusScope.of(this).unfocus();
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

  /// This string, or null when there is nothing in it. Handy for optional API
  /// fields that should be omitted rather than sent as ''.
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

  /// Cuts to [max] characters, ellipsis included, so the result never exceeds
  /// [max]. Returns the string untouched when it already fits.
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

  /// Lower case and accent-free — the form to compare against a search box so
  /// 'sao' matches 'São'.
  String get searchKey => withoutDiacritics.toLowerCase().trim();

  /// True when [query] appears in this string, ignoring case and accents.
  bool matchesSearch(String query) => searchKey.contains(query.searchKey);

  // Safe Parsers
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
    // Try standard formats first
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

    // Fallback: manual split for ambiguous cases
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

  /// yyyy-MM-ddTHH:mm:ss.mmmZ, in UTC — the `Z` says UTC, so the value is
  /// converted rather than relabelled.
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

  /// This time of day on [date] — how a separate date field and time field are
  /// combined into the single DateTime an API wants.
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

  // Material & Cupertino guidelines:
  // Spacing: 4pt grid (4, 8, 12, 16, 24, 32, 48)
  // Text: iOS SF / Material type scale — body 17, callout 16, subhead 15, footnote 13, caption 12
  // Touch targets: min 44pt (iOS HIG) / 48dp (Material)
  // Border radius: iOS uses 10-13 for cards, Material uses 12 (medium)
  /// Returns the generated appConstants template.
  static String appConstants() => r'''
import 'package:flutter/material.dart';

/// | NAME           | SIZE |  HEIGHT |  WEIGHT |  SPACING |             |
/// |----------------|------|---------|---------|----------|-------------|
/// | displayLarge   | 57.0 |   64.0  | regular | -0.25    |             |
/// | displayMedium  | 45.0 |   52.0  | regular |  0.0     |             |
/// | displaySmall   | 36.0 |   44.0  | regular |  0.0     |             |
/// | headlineLarge  | 32.0 |   40.0  | regular |  0.0     |             |
/// | headlineMedium | 28.0 |   36.0  | regular |  0.0     |             |
/// | headlineSmall  | 24.0 |   32.0  | regular |  0.0     |             |
/// | titleLarge     | 22.0 |   28.0  | regular |  0.0     |             |
/// | titleMedium    | 16.0 |   24.0  | medium  |  0.15    |             |
/// | titleSmall     | 14.0 |   20.0  | medium  |  0.1     |             |
/// | bodyLarge      | 16.0 |   24.0  | regular |  0.5     |             |
/// | bodyMedium     | 14.0 |   20.0  | regular |  0.25    |             |
/// | bodySmall      | 12.0 |   16.0  | regular |  0.4     |             |
/// | labelLarge     | 14.0 |   20.0  | medium  |  0.1     |             |
/// | labelMedium    | 12.0 |   16.0  | medium  |  0.5     |             |
/// | labelSmall     | 11.0 |   16.0  | medium  |  0.5     |             |

abstract final class AppConstants {
 // ── Palette (light) ────────────────────────────────────────────
static const Color primary   = Color(0xFF000000);
static const Color secondary = Color(0xFF000000);
static const Color tertiary  = Color(0xFF000000);
static const Color surface   = Color(0xFF000000);
static const Color onSurface = Color(0xFF000000);
static const Color outline   = Color(0xFF000000);
static const Color error = Color(0xFFba1a1a);

// ── Palette (dark) — same hues, tuned for a dark surface ───────
static const Color primaryDark   = Color(0xFFFFFFFF);
static const Color secondaryDark = Color(0xFFFFFFFF);
static const Color tertiaryDark  = Color(0xFFFFFFFF);
static const Color surfaceDark   = Color(0xFF121212);
static const Color onSurfaceDark = Color(0xFFFFFFFF);
static const Color outlineDark   = Color(0xFFFFFFFF);
static const Color errorDark = Color(0xFFffb4ab);

// ── Status colors (feedback: toasts, banners, tags) ───────────
// Kept apart from the variant palette so success/warning/info read the same
// whatever the brand colors become.
static const Color success = Color(0xFF2E7D32);
static const Color warning = Color(0xFFED6C02);
static const Color info    = Color(0xFF0288D1);

static const Color successDark = Color(0xFF66BB6A);
static const Color warningDark = Color(0xFFFFA726);
static const Color infoDark    = Color(0xFF29B6F6);

// ── Accent tokens ────────────────────────────────────────────
static const Color accentActive      = Color(0xFF000000);
static const Color accentRestorative = Color(0xFF000000);
static const Color accentEnergetic   = Color(0xFF000000);

// ── Type ──────────────────────────────────────────────────────
// App-wide font family used by [AppTheme]'s TextTheme. Leave null for the
// platform default (Roboto / SF). To use a custom font, declare it under
// `flutter: fonts:` in pubspec.yaml and set its family name here, e.g.
// `static const String? fontFamily = 'Inter';`. For Google Fonts, add the
// google_fonts package and swap AppTheme's textTheme for
// GoogleFonts.interTextTheme(...).
static const String? fontFamily = null;


// ── Surface layers (tonal depth — no borders) ───────────────
static const Color surfaceContainerLowest  = Color(0xFF000000);
static const Color surfaceContainerLow     = Color(0xFF000000);
static const Color surfaceContainerHighest = Color(0xFF000000);

// ── Surface layers (dark) ────────────────────────────────────
static const Color surfaceContainerLowestDark  = Color(0xFF0A0A0A);
static const Color surfaceContainerLowDark     = Color(0xFF1E1E1E);
static const Color surfaceContainerHighestDark = Color(0xFF2C2C2C);

// ── Flat colors for avatar bg fallback ───────────────
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
  static const padding8  = EdgeInsets.all(space8);
  static const padding12 = EdgeInsets.all(space12);
  static const padding16 = EdgeInsets.all(space16);
  static const padding24 = EdgeInsets.all(space24);

  static const paddingH16 = EdgeInsets.symmetric(horizontal: space16);
  static const paddingH24 = EdgeInsets.symmetric(horizontal: space24);
  static const paddingV8  = EdgeInsets.symmetric(vertical: space8);
  static const paddingV16 = EdgeInsets.symmetric(vertical: space16);

  // common page inset (Material: 16dp sides, iOS: 16-20pt sides)
  static const paddingPage = EdgeInsets.symmetric(
    horizontal: space16,
    vertical: space16,
  );

  // ── Icons Sizes ───────────────────────────────────────────────────

  static const double iconSmall = 16;
  static const double iconMedium = 24;
  static const double iconLarge = 32;

  // ── Text sizes — Material type scale / iOS HIG ────────────────────────────
  // iOS: largeTitle 34, title1 28, title2 22, title3 20, headline 17,
  //      body 17, callout 16, subheadline 15, footnote 13, caption1/2 12/11
  // Material: displayL 57, displayM 45, displayS 36, headlineL 32,
  //           headlineM 28, headlineS 24, titleL 22, titleM 16, titleS 14,
  //           bodyL 16, bodyM 14, bodyS 12, labelL 14, labelM 12, labelS 11
  static const double fontSize11 = 11; // caption2 / label small
  static const double fontSize12 = 12; // caption1 / body small
  static const double fontSize13 = 13; // footnote
  static const double fontSize14 = 14; // label / body medium (Material)
  static const double fontSize15 = 15; // subheadline
  static const double fontSize16 = 16; // callout / body large
  static const double fontSize17 = 17; // body / headline (iOS default)
  static const double fontSize20 = 20; // title3
  static const double fontSize22 = 22; // title2 / titleL
  static const double fontSize28 = 28; // title1 / headlineM
  static const double fontSize34 = 34; // largeTitle (iOS)

  // ── Touch targets ─────────────────────────────────────────────────────────
  // iOS HIG: 44pt minimum, Material: 48dp minimum
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
  static final borderRadius24   = BorderRadius.circular(radius24);
  static final borderRadiusFull = BorderRadius.circular(radiusFull);

  // ── Animation durations ───────────────────────────────────────────────────
  // Material motion: 100ms micro, 200ms simple, 300ms complex, 500ms dramatic
  static const Duration duration100 = Duration(milliseconds: 100);
  static const Duration duration200 = Duration(milliseconds: 200);
  static const Duration duration300 = Duration(milliseconds: 300);
  static const Duration duration500 = Duration(milliseconds: 500);
}
''';

  /// Returns the generated actionNotifier template — the shared runAction
  /// helper used by all feature notifiers.
  static String actionNotifier() => r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';

/// Contract for states usable with [ActionNotifierMixin.runAction]: the
/// state must know how to flag its loading and error cases.
abstract interface class ActionState<T> {
  T copyWithLoading();
  T copyWithError(String message);
}

/// Shared loading/error handling for AsyncNotifier actions.
///
/// ```dart
/// class MyNotifier extends AsyncNotifier<MyState>
///     with ActionNotifierMixin<MyState> {
///   Future<void> doSomething() => runAction((current) async {
///     await ref.read(myRepositoryProvider).doSomething();
///     return current.copyWith(success: 'Done!');
///   });
/// }
/// ```
mixin ActionNotifierMixin<S extends ActionState<S>> on AsyncNotifier<S> {
  /// Runs [action] with the shared loading/error handling; [action] returns
  /// the next state. [action] receives the pre-action state (loading off) —
  /// build the next state from it, not from `state.value`, which holds the
  /// loading flag while the action runs. Errors reset the state to how it
  /// was before the action, with the message in `error`.
  Future<void> runAction(Future<S> Function(S current) action) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWithLoading());
    try {
      state = AsyncData(await action(current));
    } on AppException catch (e) {
      state = AsyncData(current.copyWithError(e.message));
    } catch (_) {
      state = AsyncData(current.copyWithError('Unknown error'));
    }
  }
}
''';

  /// Returns the generated apiConstants template.
  static String apiConstants() => r'''
abstract final class ApiConstants {
  // BASE_URL comes from envied
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
''';

  /// Returns the generated dioClient template.
  static String dioClient() => r'''
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../config/env/app_env.dart';
import '../constants/api_constants.dart';
import '../security/secure_storage.dart';
import '../utils/app_logger.dart';

final _log = appLogger.scoped('Dio');

const _kPublicEndpoints = <String>[
  // Routes that never receive the Authorization header (and are never
  // retried after a token refresh). Adjust to your API contract.
  '/auth/login',
  '/auth/register',
  '/auth/refresh',
];

bool _isPublicPath(String path) {
  final cleanPath = path.split('?').first;
  return _kPublicEndpoints.any(
    (endpoint) => cleanPath == endpoint || cleanPath.startsWith('$endpoint/'),
  );
}

final dioClientProvider = Provider<Dio>((ref) => _buildDioClient(ref));

// ─────────────────────────────────────────────────────────────────────────────
Dio _buildDioClient(Ref ref) {
  final storage = ref.watch(tokenStorageProvider);

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

  // Configure certificate verification
  _configureHttpClient(dio);

  dio
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isPublicEndpoint = _isPublicPath(options.path);
          if (!isPublicEndpoint) {
            final token = await storage.accessToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final alreadyRetried =
              error.requestOptions.extra[_kRetriedAfterRefresh] == true;
          if (status != 401 ||
              alreadyRetried ||
              _isPublicPath(error.requestOptions.path)) {
            return handler.next(error);
          }

          // Session expired — refresh the access token, then retry once.
          final refreshed = await _refreshSession(storage);
          if (!refreshed) {
            // Refresh token missing/expired: clear the session so the auth
            // notifier / router redirect can send the user back to login.
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
        },
      ),
    )
    ..interceptors.add(
      RetryInterceptor(dio: dio, logPrint: (msg) => _log.d(msg.toString())),
    )
    // Bodies and headers are safe to hand over whole: app_logger.dart redacts
    // credentials at the sink, so nothing here has to remember to.
    ..interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (msg) => _log.d(msg.toString()),
      ),
    );

  return dio;
}

// ── Token refresh ────────────────────────────────────────────────────────────

const _kRetriedAfterRefresh = '__retried_after_refresh__';

/// Single-flight guard: concurrent 401s share one refresh call instead of
/// racing each other with the same refresh token.
Future<bool>? _ongoingRefresh;

Future<bool> _refreshSession(TokenStorage storage) {
  return _ongoingRefresh ??= _doRefresh(storage).whenComplete(() {
    _ongoingRefresh = null;
  });
}

Future<bool> _doRefresh(TokenStorage storage) async {
  final refreshToken = await storage.refreshToken;
  if (refreshToken == null) return false;
  try {
    // Bare client (no interceptors), so a failing refresh can't loop back
    // into the 401 handler above.
    final refreshDio = Dio(
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
    _configureHttpClient(refreshDio);
    final response = await refreshDio.post<dynamic>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data as Map<String, dynamic>;
    // Adjust the keys to your API contract. Backends that don't rotate the
    // refresh token only return a new access token.
    final newAccessToken = data['accessToken'] as String?;
    final newRefreshToken = data['refreshToken'] as String? ?? refreshToken;
    if (newAccessToken == null) return false;
    await storage.saveSession(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );
    return true;
  } catch (error) {
    _log.w('Session refresh failed', error: error);
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
void _configureHttpClient(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      if (kDebugMode) {
        client.badCertificateCallback = (cert, host, port) {
          _log.w(
            'Certificate verification skipped for $host (debug mode)',
          );
          return true;
        };
      }
      return client;
    },
  );
}

''';

  /// SAFE API CALL
  static String safeApiCall() => '''
import 'dart:async';
import '../../core/errors/app_exception.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


Future<T> safeApiCall<T>({
  required Future<T> Function() apiCall,
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
    return await apiCall();
  } on DioException catch (e) {
    throw AppException.fromDioError(e);
  } catch (e, s) {
    throw AppException.fromError(e, s);
  }
}


''';
}
