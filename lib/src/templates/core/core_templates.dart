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
    bool withFirebase = false,
    bool withMaintenanceGate = false,
    bool withMoAdapt = false,
    bool withDarkTheme = false,
  }) {
    if (withEasyLocalization) withLocalization = false;

    // Crashlytics has always initialized Firebase on its own; Firestore and
    // Firebase Auth need the same call, or the first provider read throws
    // "No Firebase App '[DEFAULT]' has been created".
    final needsFirebaseInit = withFirebase || withCrashlytics;

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

    // MoAdapt is the outermost widget so the entire app — EasyLocalization,
    // provider scopes, MaterialApp — renders in design-space coordinates.
    final String runAppCall;
    if (withEasyLocalization && withMoAdapt) {
      runAppCall = '''runApp(
    MoAdapt(
      // The frame the UI is designed against; every fixed dimension scales
      // proportionally from it. Tune with scaleMode / minScale / maxScale.
      designSize: const Size(412, 924),
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('pt')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: $rootScope,
      ),
    ),
  );''';
    } else if (withEasyLocalization) {
      runAppCall = '''runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('pt')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: $rootScope,
    ),
  );''';
    } else if (withMoAdapt) {
      // With a plain ProviderScope the whole tree is const, so the const
      // keyword moves to MoAdapt; with a container it cannot be const at all.
      runAppCall = needsContainer
          ? '''runApp(
    MoAdapt(
      // The frame the UI is designed against; every fixed dimension scales
      // proportionally from it. Tune with scaleMode / minScale / maxScale.
      designSize: const Size(412, 924),
      child: $rootScope,
    ),
  );'''
          : '''runApp(
    const MoAdapt(
      // The frame the UI is designed against; every fixed dimension scales
      // proportionally from it. Tune with scaleMode / minScale / maxScale.
      designSize: Size(412, 924),
      child: ProviderScope(child: App()),
    ),
  );''';
    } else {
      runAppCall = 'runApp($rootScope);';
    }

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

    final firebaseImports = [
      if (needsFirebaseInit)
        "\nimport 'package:firebase_core/firebase_core.dart';",
      if (withCrashlytics)
        "\nimport 'package:firebase_crashlytics/firebase_crashlytics.dart';",
    ].join();

    // One initializeApp for every Firebase service the project selected.
    final firebaseInit = needsFirebaseInit
        ? '''

  // Run `flutterfire configure`, then pass the generated options:
  // Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
  await Firebase.initializeApp();${withCrashlytics ? '''

  // Only report crashes from release builds.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);''' : ''}
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

    final maintenanceImport = withMaintenanceGate
        ? "\nimport 'shared/widgets/maintenance_gate.dart';"
        : '';

    final moAdaptImport =
        withMoAdapt ? "\nimport 'shared/widgets/mo_adapt.dart';" : '';

    // With one palette there is no second ThemeData to hand MaterialApp, and
    // no themeMode worth setting: every mode would resolve to the same theme.
    final themeConfig = withDarkTheme
        ? '''
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,'''
        : '''
      // One brand theme. `moarch create theme --dark` adds the dark half.
      theme: AppTheme.light,''';

    // Inside `builder`, so it wraps the Navigator rather than sitting in a
    // route: a gate below the Navigator could be pushed on top of.
    final maintenanceOpen =
        withMaintenanceGate ? 'MaintenanceGate(child: ' : '';
    final maintenanceClose = withMaintenanceGate ? ')' : '';

    if (withRouter) {
      return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';$localizationImports$notificationImport$firebaseNotificationImport$firebaseImports
import 'core/utils/app_logger.dart';
import 'shared/widgets/error_view.dart';$maintenanceImport$moAdaptImport
import 'config/theme/app_theme.dart';
import 'config/router/app_router.dart';

Future<void> main() async {
  // Preserve the splash before anything else runs.
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
$easyLocalizationInit$containerSetup$notificationInit
$firebaseInit$firebaseNotificationInit
  PlatformDispatcher.instance.onError = (error, st) {
    appLogger.e('[Uncaught error]', error: error, stackTrace: st);$crashlyticsUncaught
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    appLogger.e('[Flutter error]', error: details.exception, stackTrace: details.stack);$crashlyticsFlutterError
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const Scaffold(body: ErrorView());
  };

  // Move this after your own async init if you have any.
  FlutterNativeSplash.remove();

  $runAppCall
}
 
class App extends ConsumerWidget {
  const App({super.key});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    $localizationWatch

    // To reset ALL app state on logout, key a ProviderScope by your session:
    // final sessionKey = ref.watch(
    //   authNotifierProvider.select((s) => s.value?.authenticated ?? ''),
    // );

    return MaterialApp.router(
      title: 'App',
$themeConfig
$localizationConfig      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
                  // Follow the system font size, capped so it can't break
                  // fixed layouts.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.1),
                  alwaysUse24HourFormat: true,
                ),
          //   ProviderScope(key: ValueKey(sessionKey), child: child!)
          child: ${maintenanceOpen}child!$maintenanceClose,
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
import 'package:flutter_riverpod/flutter_riverpod.dart';$localizationImports$notificationImport$firebaseNotificationImport$firebaseImports
import 'core/utils/app_logger.dart';
import 'shared/widgets/error_view.dart';$maintenanceImport$moAdaptImport
import 'config/theme/app_theme.dart';

Future<void> main() async {
  // Preserve the splash before anything else runs.
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
$easyLocalizationInit$containerSetup$notificationInit
$firebaseInit$firebaseNotificationInit
  PlatformDispatcher.instance.onError = (error, st) {
    appLogger.e('[Uncaught error]', error: error, stackTrace: st);$crashlyticsUncaught
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    appLogger.e('[Flutter error]', error: details.exception, stackTrace: details.stack);$crashlyticsFlutterError
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const Scaffold(body: ErrorView());
  };

  // Move this after your own async init if you have any.
  FlutterNativeSplash.remove();

  $runAppCall
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    $localizationWatch

    // To reset ALL app state on logout, key a ProviderScope by your session:
    // final sessionKey = ref.watch(
    //   authNotifierProvider.select((s) => s.value?.authenticated ?? ''),
    // );

    return MaterialApp(
      title: 'App',
$themeConfig
$localizationConfig      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.1),
            alwaysUse24HourFormat: true,
          ),
          //   ProviderScope(key: ValueKey(sessionKey), child: child!)
          child: ${maintenanceOpen}child!$maintenanceClose,
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
  // One line per record in release — it is headed for Crashlytics breadcrumbs
  // and device logs, where PrettyPrinter's box art is only noise.
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

/// Writes through `dart:developer`, so DevTools' Logging view gets one
/// filterable record per event instead of a wall of console text.
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
/// does not line up with.
const _developerLevels = <Level, int>{
  Level.trace: 300,
  Level.debug: 500,
  Level.info: 800,
  Level.warning: 900,
  Level.error: 1000,
  Level.fatal: 1200,
};

/// Every sink runs this, so a stray `appLogger.d(response.data.toString())`
/// cannot put a credential in the logs.
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

  /// Drops focus and closes the keyboard.
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
  // Every token above has a counterpart here; AppTheme.dark reads this half.
  static const Color primaryDark   = Color(0xFFFFFFFF);
  static const Color secondaryDark = Color(0xFFFFFFFF);
  static const Color tertiaryDark  = Color(0xFFFFFFFF);
  static const Color surfaceDark   = Color(0xFF121212);
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color outlineDark   = Color(0xFFFFFFFF);
  static const Color errorDark     = Color(0xFFffb4ab);

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
  // ── Brand palette ─────────────────────────────────────────────────────────
  static const Color primary   = Color(0xFF000000);
  static const Color secondary = Color(0xFF000000);
  static const Color tertiary  = Color(0xFF000000);
  static const Color surface   = Color(0xFF000000);
  static const Color onSurface = Color(0xFF000000);
  static const Color outline   = Color(0xFF000000);
  static const Color error     = Color(0xFFba1a1a);

  // ── Surface layers ────────────────────────────────────────────────────────
  static const Color surfaceContainerLowest  = Color(0xFF000000);
  static const Color surfaceContainerLow     = Color(0xFF000000);
  static const Color surfaceContainerHighest = Color(0xFF000000);

  // ── Status colors ─────────────────────────────────────────────────────────
  // Kept out of the palette so they read the same whatever the brand becomes.
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color info    = Color(0xFF0288D1);
$darkPalette
  // ── Type ──────────────────────────────────────────────────────────────────
  // Null uses the platform default. Declare a font under `flutter: fonts:` in
  // pubspec.yaml and name it here, or add google_fonts and swap AppTheme's
  // textTheme for GoogleFonts.interTextTheme(...).
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

  // ── Text sizes — Material type scale / iOS HIG ────────────────────────────
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
}
''';
  }

  /// Returns the generated actionNotifier template — the shared runAction
  /// helper used by all feature notifiers.
  static String actionNotifier() => r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';

/// Contract for states usable with [ActionNotifierMixin.runAction].
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
  /// Runs [action] with shared loading/error handling.
  ///
  /// [action] receives the pre-action state — build the next state from that,
  /// not from `state.value`, which carries the loading flag while it runs.
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

  /// Returns the generated safeApiCall template.
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

  /// Returns the generated safeFirebaseCall template.
  ///
  /// [withAuth] adds the `FirebaseAuthException` arm, which must come first —
  /// it is a subtype of `FirebaseException`.
  static String safeFirebaseCall({bool withAuth = false}) {
    final authImport =
        withAuth ? "import 'package:firebase_auth/firebase_auth.dart';\n" : '';

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

/// Same contract as `safeApiCall`: offline is caught before the request
/// leaves, and anything that comes back wrong arrives as an [AppException].
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
}
