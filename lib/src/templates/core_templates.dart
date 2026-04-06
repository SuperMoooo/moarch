class CoreTemplates {
  CoreTemplates._();

  static String mainDart() => r'''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traice_flutter_v2/core/utils/logger.dart';
import 'package:traice_flutter_v2/shared/widgets/error_view.dart';

import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  
  //::::::::::ERROR MANAGEMENT::::::::::
  PlatformDispatcher.instance.onError = (error, st) {
    log.e('[Uncaught error]', error: error, stackTrace: st);
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    log.e('[Flutter error]', error: details.exception, stackTrace: details.stack);
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

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
      // TODO: set your initial route/home
    );
  }
}
''';

  static String appException() => r'''
import 'package:dio/dio.dart';
import 'package:traice_flutter_v2/core/utils/logger.dart';

class AppException implements Exception {
  const AppException._({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'AppException(message: $message, statusCode: $statusCode)';

  factory AppException.fromDioError(DioException dioError) {
    final message =
        dioError.response?.data?['message'] as String? ??
        dioError.message ??
        'Unknown error';
    final statusCode = dioError.response?.statusCode;

    log.e('[AppException] — $message', error: dioError);

    return AppException._(message: message, statusCode: statusCode);
  }
}

''';

  static String logger() => r'''
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // no stack trace on normal logs
    errorMethodCount: 8, // stack trace on errors
    colors: true,
    printEmojis: true,
  ),
  // automatically silent in release mode
  level: kReleaseMode ? Level.off : Level.trace,
);

''';

  static String extensions() => r'''
import 'package:flutter/material.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
}

extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension DateTimeX on DateTime {
  String get formattedDate => '$day/$month/$year';
  String get formattedTime => '$hour:$minute';
  String get formattedDateTime => '$formattedDate $formattedTime';

  bool get isToday {
    final now = DateTime.now();
    return day == now.day && month == now.month && year == now.year;
  }
}

extension TimeOfDayX on TimeOfDay {
  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
''';

  // Material & Cupertino guidelines:
  // Spacing: 4pt grid (4, 8, 12, 16, 24, 32, 48)
  // Text: iOS SF / Material type scale — body 17, callout 16, subhead 15, footnote 13, caption 12
  // Touch targets: min 44pt (iOS HIG) / 48dp (Material)
  // Border radius: iOS uses 10-13 for cards, Material uses 12 (medium)
  static String appConstants() => r'''
import 'package:flutter/material.dart';

abstract final class AppConstants {
 // ── Palette ─────────────────────────────────────────────────
static const Color primary   = Color(0xFF000000);
static const Color secondary = Color(0xFF000000);
static const Color tertiary  = Color(0xFF000000);
static const Color surface   = Color(0xFF000000);
static const Color onSurface = Color(0xFF000000);
static const Color outline   = Color(0xFF000000);

// ── Accent tokens ────────────────────────────────────────────
static const Color accentActive      = Color(0xFF000000);
static const Color accentRestorative = Color(0xFF000000);
static const Color accentEnergetic   = Color(0xFF000000);

// ── Surface layers (tonal depth — no borders) ───────────────
static const Color surfaceContainerLowest  = Color(0xFF000000);
static const Color surfaceContainerLow     = Color(0xFF000000);
static const Color surfaceContainerHighest = Color(0xFF000000);


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

  static String apiConstants() => r'''
abstract final class ApiConstants {
  // BASE_URL comes from envied
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
''';

  static String dioClient() => r'''
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env/app_env.dart';
import '../constants/api_constants.dart';
import '../security/secure_storage.dart';
import '../utils/logger.dart';

final dioClientProvider = Provider<Dio>((ref) => buildDioClient(ref));

// ─────────────────────────────────────────────────────────────────────────────

Dio buildDioClient(Ref ref) {
  final storage = ref.watch(secureStorageProvider);

  final dio =
      Dio(
          BaseOptions(
            baseUrl: AppEnv.baseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            // Status that pass: 200-399, all the other will be caught in DioException
            validateStatus: (status) {
              return status != null && status >= 200 && status < 500;
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await storage.read(key: 'token');
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
          ),
        )
        ..interceptors.add(
          LogInterceptor(requestBody: true,
           responseBody: true, 
          logPrint: (o) => log.d(o.toString()),
          ),
        );

  return dio;
}

''';

  static String secureStorage() => r'''
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => FlutterSecureStorage());



''';
}
