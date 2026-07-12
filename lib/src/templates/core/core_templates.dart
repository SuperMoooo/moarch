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

    final runAppCall = withEasyLocalization
        ? '''runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('pt')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(child: App()),
    ),
  );'''
        : 'runApp(const ProviderScope(child: App()));';
    final notificationImport = withNotificationsService
        ? "\nimport 'core/services/notifications_service.dart';"
        : '';

    final notificationInit = withNotificationsService
        ? "\n await NotificationService.instance.init();"
        : '';

    final firebaseNotificationImport = withFirebaseNotifications
        ? "\nimport 'core/services/firebase_notifications_service.dart';"
        : '';

    // Placed after the Crashlytics block so its unguarded
    // Firebase.initializeApp() runs first; the FCM service only initializes
    // Firebase itself when no one else has.
    final firebaseNotificationInit = withFirebaseNotifications
        ? '\n  await FirebaseNotificationsService.instance.init();'
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
$easyLocalizationInit
  $notificationInit
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
    return const ErrorView(); // your nice screen in prod
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
                  ).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.35),
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
$easyLocalizationInit
  $notificationInit
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
    return const ErrorView(); // your nice screen in prod
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
            ).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.35),
            alwaysUse24HourFormat: true,
          ),
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
  static String appLogger() => r'''
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 12,
    colors: true,
    printEmojis: true,
  ),
  level: kReleaseMode ? Level.off : Level.trace,
);

''';

  /// Returns the generated extensions template.
  static String extensions() => r'''
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
}

extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);

  bool? isValidUrl() {
    if (isEmpty) return null;
    final uri = Uri.tryParse(this);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }


  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  // Safe Parsers
  int? get toIntOrNull => int.tryParse(this);
  double? get toDoubleOrNull => double.tryParse(this);

  Color? toColor() {
    var hexColor = replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    if (hexColor.length == 8) {
      return Color(int.parse('0x$hexColor'));
    }
    return null;
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


extension DateTimeX on DateTime {
  String get formattedDate => '$day/$month/$year';
  String get formattedTime => '$hour:$minute';
  String get formattedDateTime => '$formattedDate $formattedTime';

  
   // yyyy-MM-ddTHH:mm:ss.mmmuuuZ
  String get formatedDateTimeToDatabase =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}.${millisecond.toString().padLeft(3, '0')}Z';

  // yyyy-MM-dd
  String get formattedDateToDatabase =>
      "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";

  bool get isToday {
    final now = DateTime.now();
    return day == now.day && month == now.month && year == now.year;
  }

   bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

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
}

extension NumX on num {
 
  String formatCurrency(String code) {
    return NumberFormat.simpleCurrency(
      name: code,
    ).format(this);
  }
}
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

// ── Accent tokens ────────────────────────────────────────────
static const Color accentActive      = Color(0xFF000000);
static const Color accentRestorative = Color(0xFF000000);
static const Color accentEnergetic   = Color(0xFF000000);


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
      RetryInterceptor(dio: dio, logPrint: (msg) => appLogger.d(msg)),
    )
    ..interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (msg) => appLogger.d(_redactSensitive(msg.toString())),
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
    appLogger.w('Session refresh failed', error: error);
    return false;
  }
}

final _kSensitiveKeyPattern = RegExp(
  r'("?(?:password|newPassword|Password|token|Authorization|refreshToken|accessToken)"?\s*:\s*)'
  r'("[^"]*"|[^,}\]\n]+)',
  caseSensitive: false,
);

String _redactSensitive(String message) {
  var redacted = message.replaceAllMapped(
    _kSensitiveKeyPattern,
    (m) => '${m.group(1)}***REDACTED***',
  );
  redacted = redacted.replaceAll(
    RegExp(r'Bearer\s+\S+', caseSensitive: false),
    'Bearer ***REDACTED***',
  );
  return redacted;
}

// ─────────────────────────────────────────────────────────────────────────────
void _configureHttpClient(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      if (kDebugMode) {
        client.badCertificateCallback = (cert, host, port) {
          appLogger.w(
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
