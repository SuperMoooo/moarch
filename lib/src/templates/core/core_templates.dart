/// Generates core scaffold file templates.
class CoreTemplates {
  CoreTemplates._();

  /// Returns the generated mainDart template.
  static String mainDart({
    bool withRouter = true,
    bool withLocalization = false,
    bool withNotificationsService = false,
  }) {
    final localizationImports = withLocalization
        ? "\nimport 'l10n/app_localizations.dart';\nimport 'l10n/l10n.dart';\nimport  'core/services/language_service.dart';\nimport 'package:flutter_localizations/flutter_localizations.dart';\n"
        : '';
    final notificationImport = withNotificationsService
        ? "\nimport 'core/services/notifications_service.dart';"
        : '';

    final notificationInit = withNotificationsService
        ? "\n await NotificationService.instance.init();"
        : '';

    final localizationConfig = withLocalization
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

    final localizationWatch = withLocalization
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
import 'package:flutter_riverpod/flutter_riverpod.dart';$localizationImports$notificationImport
import 'core/utils/app_logger.dart';
import '../shared/widgets/error_view.dart';
import 'config/theme/app_theme.dart';
import 'config/router/app_router.dart';

Future<void> main() async {
  // Preserve the splash BEFORE anything else runs
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  $notificationInit

  //::::::::::ERROR MANAGEMENT::::::::::
  PlatformDispatcher.instance.onError = (error, st) {
    appLogger.e('[Uncaught error]', error: error, stackTrace: st);
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    appLogger.e('[Flutter error]', error: details.exception, stackTrace: details.stack);
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

  runApp(const ProviderScope(child: App()));
}
 
class App extends ConsumerWidget {
  const App({super.key});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    $localizationWatch
 
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
            textScaler: TextScaler.noScaling,
            alwaysUse24HourFormat: true,
          ),
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
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';$localizationImports$notificationImport
import '../../core/utils/app_logger.dart';
import 'config/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();$notificationInit

  //::::::::::ERROR MANAGEMENT::::::::::
  PlatformDispatcher.instance.onError = (error, st) {
    appLogger.e('[Uncaught error]', error: error, stackTrace: st);
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    appLogger.e('[Flutter error]', error: details.exception, stackTrace: details.stack);
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

    //::::::::::ERROR MANAGEMENT::::::::::
  runApp(const ProviderScope(child: App()));
}
 
class App extends StatelessWidget {
  const App({super.key});
 
  @override
  Widget build(BuildContext context) {
  $localizationWatch
    return MaterialApp(
      title: 'App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
$localizationConfig      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
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
import '../../../core/errors/app_exception.dart';

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

  dynamic toColor() {
    var hexColor = replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    if (hexColor.length == 8) {
      return int.parse('0x$hexColor');
    }
    return null;
  }

 DateTime formatToDateTime(String dateStr) {
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
        return DateFormat(fmt).parseStrict(dateStr);
      } catch (_) {}
    }

    DateTime date = DateTime.now();

    // Fallback: manual split for d/M/yyyy or M/d/yyyy ambiguous cases
    final parts = dateStr.split(RegExp(r'[/\-]'));
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);

      if (a != null && b != null && c != null) {
        // c is year if > 31, assume d/M/yyyy
        if (c > 31) date = DateTime(c, b, a);
        // a is year if > 31, assume yyyy/M/d
        if (a > 31) date = DateTime(a, b, c);
      }
    }
    return date;
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
 // ── Palette ─────────────────────────────────────────────────
static const Color primary   = Color(0xFF000000);
static const Color secondary = Color(0xFF000000);
static const Color tertiary  = Color(0xFF000000);
static const Color surface   = Color(0xFF000000);
static const Color onSurface = Color(0xFF000000);
static const Color outline   = Color(0xFF000000);
static const Color error = Color(0xFFba1a1a);

// ── Accent tokens ────────────────────────────────────────────
static const Color accentActive      = Color(0xFF000000);
static const Color accentRestorative = Color(0xFF000000);
static const Color accentEnergetic   = Color(0xFF000000);


// ── Surface layers (tonal depth — no borders) ───────────────
static const Color surfaceContainerLowest  = Color(0xFF000000);
static const Color surfaceContainerLow     = Color(0xFF000000);
static const Color surfaceContainerHighest = Color(0xFF000000);

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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../config/env/app_env.dart';
import '../constants/api_constants.dart';
import '../security/secure_storage.dart';
import '../utils/app_logger.dart';

final _kPublicEndpoints = [
  // Add public routes here
];

final dioClientProvider = Provider<Dio>((ref) => _buildDioClient(ref));

// ─────────────────────────────────────────────────────────────────────────────
Dio _buildDioClient(Ref ref) {
  final storage = ref.watch(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: appFlavor == "prod" ? AppEnv.prodBaseUrl : AppEnv.devBaseUrl,
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
          final isPublicEndpoint = _kPublicEndpoints.any(
            (endpoint) => options.path.contains(endpoint),
          );
          if (!isPublicEndpoint) {
            final token = await storage.read(key: 'token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
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
        logPrint: (msg) => appLogger.d(msg.toString()),
      ),
    );

  return dio;
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
  static String safeApiCall() => '''~
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
