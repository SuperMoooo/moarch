/// Error templates
class ErrorTemplates {
  ErrorTemplates._();

  /// Returns the generated appException template.
  ///
  /// Imports and mapping factories follow the stack options actually selected,
  /// so the file always compiles.
  static String appException({
    bool hasDio = true,
    bool hasFirebase = false,
    bool hasFirebaseAuth = false,
    bool hasCrashlytics = false,
  }) {
    // firebase_auth brings firebase_core with it.
    final withFirebase = hasFirebase || hasFirebaseAuth;

    const catchError =
        r"    appLogger.e('[AppException] — $message', error: error, stackTrace: stackTrace);";
    final imports = [
      if (hasDio) "import 'package:dio/dio.dart';",
      if (withFirebase) "import 'package:firebase_core/firebase_core.dart';",
      if (hasFirebaseAuth) "import 'package:firebase_auth/firebase_auth.dart';",
      if (hasCrashlytics)
        "import 'package:firebase_crashlytics/firebase_crashlytics.dart';",
    ].join('\n');

    // Collection is toggled off for debug builds in main.dart, so these are
    // safe to leave unconditional.
    final crashlyticsFromError = hasCrashlytics
        ? '\n    FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);'
        : '';
    final crashlyticsDio = hasCrashlytics
        ? '\n      FirebaseCrashlytics.instance.recordError(dioError, dioError.stackTrace, reason: message);'
        : '';
    final crashlyticsDioCatch = hasCrashlytics
        ? '\n      FirebaseCrashlytics.instance.recordError(error, dioError.stackTrace);'
        : '';
    final crashlyticsFirebase = hasCrashlytics
        ? '\n    FirebaseCrashlytics.instance.recordError(error, error.stackTrace, reason: message);'
        : '';

    final dioFactory =
        '''
  factory AppException.fromDioError(DioException dioError) {
    try {
      final message = dioError.response?.data?['message'] as String? ??
          dioError.message ??
          'Unknown error';
      final statusCode = dioError.response?.statusCode;
      appLogger.e('[AppException] — \$message', error: dioError, stackTrace: dioError.stackTrace);$crashlyticsDio
      return statusCode == 404
          ? NotFoundException(message: message, statusCode: statusCode)
          : ServerException(message: message, statusCode: statusCode);
    } catch (error) {
      appLogger.e('[AppException] — \$error', error: error, stackTrace: dioError.stackTrace);$crashlyticsDioCatch
      return const UnknownException(message: 'Unknown error');
    }
  }
''';

    // Firestore/Storage codes. Auth codes are in the factory below — catching
    // FirebaseException first would swallow them.
    final firebaseFactory =
        '''
  factory AppException.fromFirebaseError(FirebaseException error) {
    final message = error.message ?? 'Unknown error';

    appLogger.e(
      '[AppException] — \${error.plugin}/\${error.code}',
      error: error,
      stackTrace: error.stackTrace,
    );$crashlyticsFirebase

    switch (error.code) {
      case 'permission-denied':
        return const AuthException(
          message: "You don't have access to this data",
        );
      case 'unauthenticated':
        return const AuthException(message: 'Please sign in to continue');
      case 'not-found':
        return const NotFoundException(message: 'Not found');
      case 'already-exists':
        return const ServerException(message: 'That record already exists');
      case 'unavailable':
      case 'deadline-exceeded':
        return const NetworkException(
          message: 'Could not reach the server. Check your connection',
        );
      case 'resource-exhausted':
        return const ServerException(
          message: 'Quota exceeded. Try again later',
        );
      case 'cancelled':
        return const CancelledException(message: 'Cancelled');
      default:
        return ServerException(message: message);
    }
  }
''';

    final firebaseAuthFactory =
        '''
  /// FirebaseAuth failures as user-facing messages. Catch these before
  /// [AppException.fromFirebaseError].
  factory AppException.fromFirebaseAuthError(FirebaseAuthException error) {
    appLogger.e(
      '[AppException] — auth/\${error.code}',
      error: error,
      stackTrace: error.stackTrace,
    );$crashlyticsFirebase

    switch (error.code) {
      // Older SDKs still send user-not-found / wrong-password.
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return const AuthException(message: 'Wrong email or password');
      case 'invalid-email':
        return const AuthException(message: 'Invalid email address');
      case 'user-disabled':
        return const AuthException(message: 'This account has been disabled');
      case 'email-already-in-use':
        return const AuthException(
          message: 'That email is already registered',
        );
      case 'weak-password':
        return const AuthException(message: 'Password is too weak');
      case 'operation-not-allowed':
        // Enable the provider in Firebase console → Authentication.
        return const AuthException(
          message: 'This sign-in method is not enabled',
        );
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return const AuthException(
          message: 'That account is already linked to another sign-in method',
        );
      case 'requires-recent-login':
        return const AuthException(
          message: 'Please sign in again to finish this action',
        );
      case 'too-many-requests':
        return const AuthException(
          message: 'Too many attempts. Try again later',
        );
      case 'network-request-failed':
        return AppException.noInternet();
      case 'web-context-canceled':
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return AppException.cancelled();
      default:
        return AuthException(message: error.message ?? 'Authentication failed');
    }
  }
''';

    final factories = [
      if (hasDio) dioFactory,
      if (withFirebase) firebaseFactory,
      if (hasFirebaseAuth) firebaseAuthFactory,
    ].join('\n');

    return '''
$imports
import '../../core/utils/app_logger.dart';

/// The kind of a failure as a value. Prefer switching on the exception itself;
/// delete this and [AppException.type] if nothing reads `.type`.
enum AppExceptionType { network, server, notFound, auth, cancelled, unknown }

/// Every failure worth showing a user. `safeApiCall` / `safeFirebaseCall`
/// build these at the datasource boundary, so the layers above see nothing
/// else.
///
/// Catch the base class to show [message]; catch a subclass where one failure
/// needs its own path (`on NetworkException { ... }`).
sealed class AppException implements Exception {
  const AppException({required this.message, this.statusCode});

  /// Safe to show as-is.
  final String message;

  /// The HTTP status behind the failure, where there was one.
  final int? statusCode;

  /// Which kind this is, as a value.
  AppExceptionType get type => switch (this) {
        NetworkException() => AppExceptionType.network,
        ServerException() => AppExceptionType.server,
        NotFoundException() => AppExceptionType.notFound,
        AuthException() => AppExceptionType.auth,
        CancelledException() => AppExceptionType.cancelled,
        UnknownException() => AppExceptionType.unknown,
      };

  @override
  String toString() =>
      '\$runtimeType(message: \$message, statusCode: \$statusCode)';

  factory AppException.noInternet() =>
      const NetworkException(message: 'No internet connection');

  factory AppException.sessionExpired() =>
      const ServerException(message: 'Session expired', statusCode: 401);

  /// The user dismissed the flow. Nothing failed, so usually show nothing.
  factory AppException.cancelled() =>
      const CancelledException(message: 'Cancelled');

  factory AppException.fromError(Object error, StackTrace stackTrace) {
    final message = error.toString();
$catchError$crashlyticsFromError
    return UnknownException(message: message);
  }

$factories
}

/// The request never reached the server.
final class NetworkException extends AppException {
  const NetworkException({required super.message});
}

/// The server answered, and the answer was a failure.
final class ServerException extends AppException {
  const ServerException({required super.message, super.statusCode});
}

/// A 404, or a document that does not exist.
final class NotFoundException extends AppException {
  const NotFoundException({required super.message, super.statusCode});
}

/// Not signed in, not allowed, or refused credentials.
final class AuthException extends AppException {
  const AuthException({required super.message, super.statusCode});
}

/// The user backed out (a dismissed sheet, a closed popup).
final class CancelledException extends AppException {
  const CancelledException({required super.message});
}

/// Anything else. [message] is the raw error, so prefer your own wording.
final class UnknownException extends AppException {
  const UnknownException({required super.message});
}
''';
  }
}
