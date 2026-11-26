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
      // firebase_auth re-exports FirebaseException; importing firebase_core
      // beside it is an `unnecessary_import`, which fails `flutter analyze`.
      if (withFirebase && !hasFirebaseAuth)
        "import 'package:firebase_core/firebase_core.dart';",
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

    // Reads the error body. The moarch-py shape is `{"error": {"code",
    // "message"}}`; a flat `{"message", "code"}` is read too, so other
    // backends keep working. The body is untyped: a value counts only when it
    // is a string, so an HTML error page keeps its status code.
    final serverErrorParser = hasDio
        ? r'''

/// The `message` and `code` an error response carries, where it has them.
final class _ServerError {
  const _ServerError({this.message, this.code});

  factory _ServerError.from(Object? body) {
    if (body is! Map) return const _ServerError();
    final Object? nested = body['error'];
    final Map<Object?, Object?> fields = nested is Map ? nested : body;
    final Object? message = fields['message'];
    final Object? code = fields['code'];
    return _ServerError(
      message: message is String ? message : null,
      code: code is String ? code : null,
    );
  }

  final String? message;
  final String? code;
}
'''
        : '';

    final dioFactory =
        '''
  factory AppException.fromDioError(DioException dioError) {
    try {
      final error = _ServerError.from(dioError.response?.data);
      final message = error.message ?? dioError.message ?? 'Unknown error';
      final statusCode = dioError.response?.statusCode;
      final code = error.code;
      appLogger.e('[AppException] — \$message (\${code ?? 'no code'})', error: dioError, stackTrace: dioError.stackTrace);$crashlyticsDio
      return switch (statusCode) {
        404 => NotFoundException(message: message, statusCode: statusCode, code: code),
        // Not signed in, not allowed, or the account is locked (423):
        // all cases the auth flow handles, told apart by [code].
        401 || 403 || 423 => AuthException(message: message, statusCode: statusCode, code: code),
        _ => ServerException(message: message, statusCode: statusCode, code: code),
      };
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
  const AppException({required this.message, this.statusCode, this.code});

  /// Safe to show as-is.
  final String message;

  /// The HTTP status behind the failure, where there was one.
  final int? statusCode;

  /// The API's own name for the failure (`account_locked`,
  /// `invalid_credentials`, `weak_password`…), where it sent one. Branch on
  /// this rather than on [message], which is worded for people.
  final String? code;

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
      '\$runtimeType(message: \$message, statusCode: \$statusCode, code: \$code)';

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
  const ServerException({required super.message, super.statusCode, super.code});
}

/// A 404, or a document that does not exist.
final class NotFoundException extends AppException {
  const NotFoundException({required super.message, super.statusCode, super.code});
}

/// Not signed in, not allowed, or refused credentials.
final class AuthException extends AppException {
  const AuthException({required super.message, super.statusCode, super.code});
}

/// The user backed out (a dismissed sheet, a closed popup).
final class CancelledException extends AppException {
  const CancelledException({required super.message});
}

/// Anything else. [message] is the raw error, so prefer your own wording.
final class UnknownException extends AppException {
  const UnknownException({required super.message});
}
$serverErrorParser''';
  }
}
