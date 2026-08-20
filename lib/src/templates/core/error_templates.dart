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
      return AppException._(
        message: message,
        statusCode: statusCode,
        type: statusCode == 404 ? AppExceptionType.notFound : AppExceptionType.server,
      );
    } catch (error) {
      appLogger.e('[AppException] — \$error', error: error, stackTrace: dioError.stackTrace);$crashlyticsDioCatch
      return const AppException._(message: 'Unknown error');
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
        return const AppException._(
          message: "You don't have access to this data",
          type: AppExceptionType.auth,
        );
      case 'unauthenticated':
        return const AppException._(
          message: 'Please sign in to continue',
          type: AppExceptionType.auth,
        );
      case 'not-found':
        return const AppException._(
          message: 'Not found',
          type: AppExceptionType.notFound,
        );
      case 'already-exists':
        return const AppException._(
          message: 'That record already exists',
          type: AppExceptionType.server,
        );
      case 'unavailable':
      case 'deadline-exceeded':
        // Firestore reports both when it cannot reach the backend.
        return const AppException._(
          message: 'Could not reach the server. Check your connection',
          type: AppExceptionType.network,
        );
      case 'resource-exhausted':
        return const AppException._(
          message: 'Quota exceeded. Try again later',
          type: AppExceptionType.server,
        );
      case 'cancelled':
        return const AppException._(
          message: 'Cancelled',
          type: AppExceptionType.cancelled,
        );
      default:
        return AppException._(message: message, type: AppExceptionType.server);
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
        return const AppException._(
          message: 'Wrong email or password',
          type: AppExceptionType.auth,
        );
      case 'invalid-email':
        return const AppException._(
          message: 'Invalid email address',
          type: AppExceptionType.auth,
        );
      case 'user-disabled':
        return const AppException._(
          message: 'This account has been disabled',
          type: AppExceptionType.auth,
        );
      case 'email-already-in-use':
        return const AppException._(
          message: 'That email is already registered',
          type: AppExceptionType.auth,
        );
      case 'weak-password':
        return const AppException._(
          message: 'Password is too weak',
          type: AppExceptionType.auth,
        );
      case 'operation-not-allowed':
        // The provider is off in Firebase console → Authentication →
        // Sign-in method.
        return const AppException._(
          message: 'This sign-in method is not enabled',
          type: AppExceptionType.auth,
        );
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return const AppException._(
          message: 'That account is already linked to another sign-in method',
          type: AppExceptionType.auth,
        );
      case 'requires-recent-login':
        // Deleting an account or changing an email needs a fresh session.
        return const AppException._(
          message: 'Please sign in again to finish this action',
          type: AppExceptionType.auth,
        );
      case 'too-many-requests':
        return const AppException._(
          message: 'Too many attempts. Try again later',
          type: AppExceptionType.auth,
        );
      case 'network-request-failed':
        return AppException.noInternet();
      case 'web-context-canceled':
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return AppException.cancelled();
      default:
        return AppException._(
          message: error.message ?? 'Authentication failed',
          type: AppExceptionType.auth,
        );
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

enum AppExceptionType { network, server, notFound, auth, cancelled, unknown }

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

  factory AppException.noInternet() => const AppException._(
        message: 'No internet connection',
        type: AppExceptionType.network,
  );

  factory AppException.sessionExpired() => const AppException._(
        message: 'Session expired',
        statusCode: 401,
        type: AppExceptionType.server,
  );

  /// The user dismissed the flow. Nothing failed, so usually show nothing.
  factory AppException.cancelled() => const AppException._(
        message: 'Cancelled',
        type: AppExceptionType.cancelled,
  );

  factory AppException.fromError(Object error, StackTrace stackTrace) {
    final message = error.toString();
    $catchError$crashlyticsFromError
    return AppException._(message: message, type: AppExceptionType.unknown);
  }

$factories
}
''';
  }
}
