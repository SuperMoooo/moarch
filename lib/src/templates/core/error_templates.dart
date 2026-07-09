/// Error templates
class ErrorTemplates {
  ErrorTemplates._();

  /// Returns the generated appException template.
  ///
  /// Imports and error-mapping factories are generated only for the stack
  /// options the user actually selected, so the file always compiles.
  static String appException({bool hasDio = true, bool hasFirebase = false}) {
    const catchError = r'''
    appLogger.e('[AppException] — $message', error: error, stackTrace: stackTrace);
    ''';
    final imports = [
      if (hasDio) "import 'package:dio/dio.dart';",
      // FirebaseException lives in firebase_core, which both the Firestore
      // and FirebaseAuth options depend on.
      if (hasFirebase) "import 'package:firebase_core/firebase_core.dart';",
    ].join('\n');

    const dioFactory = r'''
  factory AppException.fromDioError(DioException dioError) {
    try {
      final message = dioError.response?.data?['message'] as String? ??
          dioError.message ??
          'Unknown error';
      final statusCode = dioError.response?.statusCode;
      appLogger.e('[AppException] — $message', error: dioError, stackTrace: dioError.stackTrace);
      return AppException._(
        message: message,
        statusCode: statusCode,
        type: statusCode == 404 ? AppExceptionType.notFound : AppExceptionType.server,
      );
    } catch (error) {
      appLogger.e('[AppException] — $error', error: error, stackTrace: dioError.stackTrace);
      return const AppException._(message: 'Unknown error');
    }
  }
''';

    const firebaseFactory = r'''
  factory AppException.fromFirebaseError(FirebaseException error) {
    final message = error.message ?? 'Unknown error';

    appLogger.e(
      '[AppException] — $message',
      error: error,
      stackTrace: error.stackTrace,
    );

    switch (error.code) {
      case "user-not-found":
        return const AppException._(message: "User not found", type: AppExceptionType.server);
      case "wrong-password":
        return const AppException._(message: "Wrong Password", type: AppExceptionType.server);
      case "invalid-email":
        return const AppException._(message: "Invalid Email", type: AppExceptionType.server);
      case "email-already-in-use":
        return const AppException._(message: "Email already in use", type: AppExceptionType.server);
      case "weak-password":
        return const AppException._(message: "Weak Password", type: AppExceptionType.server);
      default:
        return AppException._(message: error.message ?? "Unknown error", type: AppExceptionType.unknown);
    }
  }
''';

    final factories = [
      if (hasDio) dioFactory,
      if (hasFirebase) firebaseFactory,
    ].join('\n');

    return '''
$imports
import '../../core/utils/app_logger.dart';

enum AppExceptionType { network, server, notFound, cache, parsing, unknown }

class AppException implements Exception {
  const AppException._({
    required this.message,
    this.statusCode,
    this.type = AppExceptionType.unknown,
  });

  final String message;
  final int? statusCode;
  final AppExceptionType type;

  @override
  String toString() => 'AppException(message: \$message, statusCode: \$statusCode, type: \$type)';

  factory AppException.test() {
    return const AppException._(message: "Test exception", statusCode: 400, type: AppExceptionType.unknown);
  }

  factory AppException.noInternet() => const AppException._(
        message: 'No internet connection',
        type: AppExceptionType.network,
  );

  factory AppException.fromError(Object error, StackTrace stackTrace) {
    final message = error.toString();
    $catchError
    return AppException._(message: message, type: AppExceptionType.unknown);
  }

$factories
}
''';
  }
}
