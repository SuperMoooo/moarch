class CoreTemplates {
  CoreTemplates._();

  static String mainDart() => r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
''';

  static String appException() => r'''
class AppException implements Exception {
  const AppException({
    required this.message,
    this.statusCode,
    this.stackTrace,
  });

  final String message;
  final int? statusCode;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException(message: $message, statusCode: $statusCode)';
}
''';

  static String failure() => r'''
sealed class Failure {
  const Failure({required this.message});
  final String message;
}

final class ServerFailure extends Failure {
  const ServerFailure({required super.message, this.statusCode});
  final int? statusCode;
}

final class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

final class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

final class UnknownFailure extends Failure {
  const UnknownFailure({required super.message});
}
''';

  static String extensions() => r'''
import 'package:flutter/material.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
      ),
    );
  }
}

extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension DateTimeX on DateTime {
  String get formattedDate => '$day/$month/$year';
  bool get isToday {
    final now = DateTime.now();
    return day == now.day && month == now.month && year == now.year;
  }
}
''';

  static String logger() => r'''
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void debug(String message, [Object? error, StackTrace? st]) {
    if (kDebugMode) _log('DEBUG', message, error, st);
  }

  static void info(String message, [Object? error, StackTrace? st]) {
    _log('INFO', message, error, st);
  }

  static void warning(String message, [Object? error, StackTrace? st]) {
    _log('WARNING', message, error, st);
  }

  static void error(String message, [Object? error, StackTrace? st]) {
    _log('ERROR', message, error, st);
  }

  static void _log(String level, String message, Object? error, StackTrace? st) {
    final ts = DateTime.now().toIso8601String();
    debugPrint('[$ts][$level] $message');
    if (error != null) debugPrint('  Error: $error');
    if (st != null) debugPrint('  StackTrace: $st');
  }
}
''';

  static String appConstants() => r'''
import 'package:flutter/material.dart';

abstract final class AppConstants {
  // ── Spacing ────────────────────────────────────────────────────────────────
  static const paddingPage  = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );
  

  // ── Text sizes ─────────────────────────────────────────────────────────────
  static const double label  = 12;
  static const double subtext  = 14;
  static const double text  = 16;
  static const double title  = 20;
  static const double bigTitle = 24;
  static const double biggerTitle = 36;

  // ── Border radius ──────────────────────────────────────────────────────────
  static const double radiusSmall   = 8;
  static const double radius   = 12;
  static const double radiusFull = 999;

  static final borderRadiusSmall   = BorderRadius.circular(radiusSm);
  static final borderRadius   = BorderRadius.circular(radius);
  static final borderRadiusFull = BorderRadius.circular(radiusFull);

  // ── Durations ──────────────────────────────────────────────────────────────
  static const Duration animationFast   = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow   = Duration(milliseconds: 500);
  static const Duration splashDuration  = Duration(seconds: 2);
}
''';

  static String apiConstants() => r'''
abstract final class ApiConstants {
  

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
''';

  static String dioClient() => r'''
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants/api_constants.dart';
import '../errors/app_exception.dart';
import '../utils/logger.dart';

final dioClientProvider = Provider<DioClient>((ref) => DioClient());

// ─────────────────────────────────────────────────────────────────────────────

class DioClient {
  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.get('BASE_URL'),,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    )
      ..interceptors.add(_authInterceptor())
      ..interceptors.add(_loggingInterceptor());
  }

  late final Dio _dio;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // TODO: inject token from secure storage
        // options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // TODO: handle token refresh
        }
        handler.next(error);
      },
    );
  }

  LogInterceptor _loggingInterceptor() => LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => AppLogger.debug(o.toString()),
      );

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: params);
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) async {
    try {
      return await _dio.post<T>(path, data: data);
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    try {
      return await _dio.put<T>(path, data: data);
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  Future<Response<T>> delete<T>(String path) async {
    try {
      return await _dio.delete<T>(path);
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  AppException _wrap(DioException e) => AppException(
        message: e.response?.data?['message'] as String? ??
            e.message ??
            'Unknown error',
        statusCode: e.response?.statusCode,
        stackTrace: e.stackTrace,
      );
}
''';

  static String usecaseBase() => r'''
abstract interface class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

abstract interface class NoParamsUseCase<Type> {
  Future<Type> call();
}

class NoParams {
  const NoParams();
}
''';
}
