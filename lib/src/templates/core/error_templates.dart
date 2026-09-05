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

    const catchError = r'''
    appLogger.e('[AppException] — $message', error: error, stackTrace: stackTrace);
    ''';
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

    final dioFactory = '''
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
    final firebaseFactory = '''
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
        // Firestore reports both when it cannot reach the backend.
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

    final firebaseAuthFactory = '''
  /// FirebaseAuth failures mapped to messages you can show as-is. Must be
  /// caught *before* [AppException.fromFirebaseError].
  factory AppException.fromFirebaseAuthError(FirebaseAuthException error) {
    appLogger.e(
      '[AppException] — auth/\${error.code}',
      error: error,
      stackTrace: error.stackTrace,
    );$crashlyticsFirebase

    switch (error.code) {
      // Recent Firebase versions collapse user-not-found and wrong-password
      // into invalid-credential. The older codes still arrive from some SDKs.
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
        // The provider is off in Firebase console → Authentication →
        // Sign-in method.
        return const AuthException(
          message: 'This sign-in method is not enabled',
        );
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return const AuthException(
          message: 'That account is already linked to another sign-in method',
        );
      case 'requires-recent-login':
        // Deleting an account or changing an email needs a fresh session.
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

/// The kind of a failure, as a value rather than a type.
///
/// [AppException.type] is what hands it out. Switching on the exception itself
/// is exhaustive and reads better, so new code rarely needs this — it is here
/// for code written before [AppException] was sealed. If nothing in the
/// project reads `.type`, delete this enum and the getter with it.
enum AppExceptionType { network, server, notFound, auth, cancelled, unknown }

/// Every failure worth showing a user, as one closed family.
///
/// Sealed, so the subclasses below are the whole list: a `switch` over an
/// AppException is checked for completeness, and a kind added later cannot be
/// silently missed at the places that branch on one. Nothing outside this file
/// can join the family, which is what makes that hold.
///
/// Catch the base class wherever all you do is show [message] — which is most
/// places, and what `runAction` and `AppAsyncView` already do for you. Catch a
/// subclass where one failure needs its own path:
///
/// ```dart
/// try {
///   await _repo.refresh();
/// } on NetworkException {
///   // Offline says nothing about the session — keep it.
///   return true;
/// } on AppException {
///   await _tokens.clearSession();
///   return false;
/// }
/// ```
///
/// Nothing constructs these by hand: the factories below are the way in, and
/// `safeApiCall` / `safeFirebaseCall` call them at the boundary so that every
/// layer above the datasource sees an AppException and nothing else.
sealed class AppException implements Exception {
  const AppException({required this.message, this.statusCode});

  /// Safe to show as-is: each factory below either writes this message itself
  /// or takes one the backend meant for a user.
  final String message;

  /// The HTTP status behind the failure, where there was one.
  final int? statusCode;

  /// Which kind this is, as a value.
  ///
  /// A `switch` on the exception itself is exhaustive and needs none of this.
  /// Adding a subclass makes the switch below incomplete — that is the
  /// compiler asking you to give the new kind an enum value too.
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

/// The request never reached the server — no connection, or it dropped before
/// anything came back. No status code, because there was no response.
final class NetworkException extends AppException {
  const NetworkException({required super.message});
}

/// The server answered, and the answer was a failure.
final class ServerException extends AppException {
  const ServerException({required super.message, super.statusCode});
}

/// What was asked for is not there — a 404, or a document that does not
/// exist. Its own kind because a screen usually draws that as empty rather
/// than as broken.
final class NotFoundException extends AppException {
  const NotFoundException({required super.message, super.statusCode});
}

/// Not signed in, not allowed, or refused credentials — usually the cue to
/// send the user back to login.
final class AuthException extends AppException {
  const AuthException({required super.message, super.statusCode});
}

/// The user backed out: a dismissed sheet, a closed OAuth popup. Nothing
/// failed, so this is the one kind normally shown as nothing at all.
final class CancelledException extends AppException {
  const CancelledException({required super.message});
}

/// Everything the boundary could not identify. [message] is the raw error, so
/// prefer wording of your own over showing it.
final class UnknownException extends AppException {
  const UnknownException({required super.message});
}
''';
  }
}
