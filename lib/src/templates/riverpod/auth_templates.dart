/// Generates the auth feature scaffold (login / register / refresh /
/// logout / delete) wired to the Dio client and TokenStorage.
class AuthTemplates {
  AuthTemplates._();

  // ── Domain — Entity ─────────────────────────────────────────────────────────

  /// Returns the generated auth tokens entity template.
  static String entity() => r'''
class AuthTokensEntity {
  const AuthTokensEntity({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}
''';

  // ── Domain — Repository interface ───────────────────────────────────────────

  /// Returns the generated auth repository interface template.
  ///
  /// [withPushNotifications] adds the device-token contract the notifier calls
  /// on login, on register and when a stored session is restored.
  static String repositoryInterface({bool withPushNotifications = false}) {
    final syncDeviceToken = withPushNotifications
        ? '''
  /// Reads this device's push token and sends it to the backend, so it can
  /// target the signed-in user. Safe to call repeatedly — the token only
  /// changes when the install does.
  Future<void> syncDeviceToken();

'''
        : '';

    return '''
abstract interface class AuthRepository {
  /// True when a session can be restored: a refresh token is stored and a
  /// new access token could be obtained from it. Called by the auth
  /// notifier's build() when the app starts.
  Future<bool> isLoggedIn();

  /// Authenticates and saves access token, refresh token and user id in
  /// secure storage.
  Future<void> login({required String email, required String password});

  /// Creates the account and saves the returned session in secure storage.
  Future<void> register({required String email, required String password});

  /// Exchanges the stored refresh token for a new access token.
  Future<void> refresh();

  /// Revokes the session on the backend (best effort) and always clears the
  /// local session.
  Future<void> logout();

  /// Deletes the account on the backend and clears the local session.
  Future<void> deleteAccount();

$syncDeviceToken  /// User id extracted from the access token when the session was saved.
  Future<String?> currentUserId();
}
''';
  }

  // ── Data — Model ────────────────────────────────────────────────────────────

  /// Returns the generated auth tokens model template.
  static String model() => r'''
import '../../domain/entities/auth_tokens_entity.dart';

class AuthTokensModel extends AuthTokensEntity {
  const AuthTokensModel({
    required super.accessToken,
    required super.refreshToken,
  });

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    // Adjust the keys to your API contract.
    return AuthTokensModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}
''';

  // ── Data — Remote datasource ────────────────────────────────────────────────

  /// Returns the generated auth remote datasource template.
  ///
  /// [withPushNotifications] adds the call that registers this device's FCM
  /// token against the signed-in user.
  static String remoteDatasource({bool withPushNotifications = false}) {
    final saveDeviceToken = withPushNotifications
        ? '''

  /// Registers this device's push token against the signed-in user — the
  /// access token on the request is what says who that is.
  ///
  /// Adapt the endpoint and the payload: most backends also want the platform,
  /// a device id or the app version so they can clean up stale tokens.
  Future<void> saveDeviceToken({required String token}) {
    return safeApiCall<void>(
      apiCall: () async {
        await _dio.post<dynamic>('/auth/device-token', data: {
          'token': token,
        });
      },
    );
  }
'''
        : '';

    return '''
import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/safe_api_call.dart';
import '../models/auth_tokens_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  // The paths live in ApiConstants, which is also where dio_client.dart reads
  // the three that go out without an Authorization header. Adjust the payload
  // keys below to your API contract.

  Future<AuthTokensModel> login({
    required String email,
    required String password,
  }) {
    return safeApiCall<AuthTokensModel>(
      apiCall: () async {
        final response = await _dio.post<dynamic>(ApiConstants.authLogin, data: {
          'email': email,
          'password': password,
        });
        return AuthTokensModel.fromJson(response.data as Map<String, dynamic>);
      },
    );
  }

  Future<AuthTokensModel> register({
    required String email,
    required String password,
  }) {
    return safeApiCall<AuthTokensModel>(
      apiCall: () async {
        final response = await _dio.post<dynamic>(ApiConstants.authRegister, data: {
          'email': email,
          'password': password,
        });
        return AuthTokensModel.fromJson(response.data as Map<String, dynamic>);
      },
    );
  }

  Future<AuthTokensModel> refresh({required String refreshToken}) {
    return safeApiCall<AuthTokensModel>(
      apiCall: () async {
        final response = await _dio.post<dynamic>(ApiConstants.authRefresh, data: {
          'refreshToken': refreshToken,
        });
        final data = response.data as Map<String, dynamic>;
        // Backends that don't rotate the refresh token only return a new
        // access token — keep the current one in that case.
        return AuthTokensModel(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String? ?? refreshToken,
        );
      },
    );
  }

  Future<void> logout({required String refreshToken}) {
    return safeApiCall<void>(
      apiCall: () async {
        // Lets the backend revoke the refresh token; local cleanup happens
        // in the repository even when this call fails.
        await _dio.post<dynamic>(ApiConstants.authLogout, data: {
          'refreshToken': refreshToken,
        });
      },
    );
  }

  Future<void> delete() {
    return safeApiCall<void>(
      apiCall: () async {
        await _dio.delete<dynamic>(ApiConstants.authAccount);
      },
    );
  }
$saveDeviceToken}
''';
  }

  // ── Data — Repository impl ──────────────────────────────────────────────────

  /// Returns the generated auth repository implementation template.
  ///
  /// [withPushNotifications] hands the FCM service to the repository, so a
  /// signed-in session can register the device with the backend.
  static String repositoryImpl({bool withPushNotifications = false}) {
    final pushImport = withPushNotifications
        ? "import '../../../../core/services/firebase_notifications_service.dart';\n"
        : '';

    final pushCtorParam = withPushNotifications ? ', this._push' : '';

    final pushField = withPushNotifications
        ? '\n  final FirebaseNotificationsService _push;'
        : '';

    final syncDeviceToken = withPushNotifications
        ? '''

  @override
  Future<void> syncDeviceToken() async {
    final deviceToken = await _push.getDeviceToken();
    if (deviceToken == null) return;
    try {
      await _remote.saveDeviceToken(token: deviceToken);
    } on AppException catch (e) {
      // Best effort: the session is valid either way, this device just goes
      // without push until the next login or app start.
      appLogger.w('Device token not registered', error: e);
    }
  }
'''
        : '';

    return '''
import '../../../../core/errors/app_exception.dart';
import '../../../../core/security/secure_storage.dart';
${pushImport}import '../../../../core/utils/app_logger.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._tokens$pushCtorParam);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;$pushField

  @override
  Future<bool> isLoggedIn() async {
    final refreshToken = await _tokens.refreshToken;
    if (refreshToken == null) return false;
    try {
      // Session restore: trade the stored refresh token for fresh tokens.
      await refresh();
      return true;
    } on AppException catch (e) {
      // Offline: keep the stored session instead of logging the user out.
      if (e.type == AppExceptionType.network) return true;
      appLogger.w('Stored session is no longer valid', error: e);
      await _tokens.clearSession();
      return false;
    }
  }

  @override
  Future<void> login({required String email, required String password}) async {
    final tokens = await _remote.login(email: email, password: password);
    await _tokens.saveSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    final tokens = await _remote.register(email: email, password: password);
    await _tokens.saveSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }

  /// The refresh currently in flight, if any.
  ///
  /// Single-flight guard: the Dio interceptor calls this on every 401, so a
  /// screen that fires three requests at once would otherwise burn the
  /// refresh token three times over. They share this one call instead.
  Future<void>? _refreshing;

  @override
  Future<void> refresh() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    final refreshToken = await _tokens.refreshToken;
    if (refreshToken == null) throw AppException.sessionExpired();
    final tokens = await _remote.refresh(refreshToken: refreshToken);
    await _tokens.saveSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokens.refreshToken;
    try {
      if (refreshToken != null) {
        await _remote.logout(refreshToken: refreshToken);
      }
    } on AppException catch (e) {
      // Logout must always succeed locally, even if revocation fails.
      appLogger.w('Remote logout failed', error: e);
    } finally {
      await _tokens.clearSession();
    }
  }

  @override
  Future<void> deleteAccount() async {
    await _remote.delete();
    await _tokens.clearSession();
  }
$syncDeviceToken
  @override
  Future<String?> currentUserId() => _tokens.userId;
}
''';
  }

  // ── Presentation — State ────────────────────────────────────────────────────

  /// Returns the generated auth state template.
  static String state() => r'''
import '../../../../core/utils/action_notifier.dart';

class AuthState implements ActionState<AuthState> {
  const AuthState({
    this.authenticated = false,
    this.userId,
    this.isLoadingAction = false,
    this.error,
    this.success,
  });

  final bool authenticated;
  final String? userId;
  final bool isLoadingAction;

  /// One-shot UI event fields: any copyWith call that omits them clears
  /// them, so a message is only surfaced once.
  final String? error;
  final String? success;

  AuthState copyWith({
    bool? authenticated,
    String? userId,
    bool? isLoadingAction,
    String? error,
    String? success,
  }) {
    return AuthState(
      authenticated: authenticated ?? this.authenticated,
      userId: userId ?? this.userId,
      isLoadingAction: isLoadingAction ?? this.isLoadingAction,
      error: error,
      success: success,
    );
  }

  @override
  AuthState copyWithLoading() => copyWith(isLoadingAction: true);

  @override
  AuthState copyWithError(String message) => copyWith(error: message);
}
''';

  // ── Presentation — Views ────────────────────────────────────────────────────

  /// Returns the generated login view template.
  static String loginView() => r'''
import 'package:flutter/material.dart';

// TODO: build your login UI and call
// ref.read(authNotifierProvider.notifier).login(email: ..., password: ...)

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const SizedBox.shrink(),
    );
  }
}
''';

  /// Returns the generated register view template.
  static String registerView() => r'''
import 'package:flutter/material.dart';

// TODO: build your register UI and call
// ref.read(authNotifierProvider.notifier).register(email: ..., password: ...)

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: const SizedBox.shrink(),
    );
  }
}
''';

  // ── Presentation — Notifier ─────────────────────────────────────────────────

  /// Returns the generated auth notifier template.
  ///
  /// [withPushNotifications] registers this device with the backend at the two
  /// moments a session starts: opening the app on a restored session, and
  /// signing in or up.
  static String notifier({bool withPushNotifications = false}) {
    final syncOnRestore = withPushNotifications
        ? '''

    // Opened on a session that was already signed in — the FCM token can have
    // changed since (reinstall, restore, token rotation), so register it again.
    unawaited(_repo.syncDeviceToken());

'''
        : '';

    final syncAfterAuth = withPushNotifications
        ? '\n      // Not awaited: registering the device must not hold up the UI.'
            '\n      unawaited(_repo.syncDeviceToken());'
        : '';

    return '''
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injector.dart';
import '../../../../core/utils/action_notifier.dart';
import '../../domain/repositories/auth_repository.dart';
import '../states/auth_state.dart';

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState>
    with ActionNotifierMixin<AuthState> {
  // Out of the locator, not off another provider: the data layer is wired in
  // `config/di/injector.dart`, and this notifier is the seam between it and
  // Riverpod.
  AuthRepository get _repo => getIt<AuthRepository>();

  @override
  FutureOr<AuthState> build() async {
    // App start: restore the session from the stored refresh token
    // (isLoggedIn refreshes the access token when one exists).
    final loggedIn = await _repo.isLoggedIn();
    if (!loggedIn) return const AuthState();
$syncOnRestore    return AuthState(
      authenticated: true,
      userId: await _repo.currentUserId(),
    );
  }

  Future<void> login({required String email, required String password}) {
    return runAction((_) async {
      await _repo.login(email: email, password: password);$syncAfterAuth
      return AuthState(
        authenticated: true,
        userId: await _repo.currentUserId(),
      );
    });
  }

  Future<void> register({required String email, required String password}) {
    return runAction((_) async {
      await _repo.register(email: email, password: password);$syncAfterAuth
      return AuthState(
        authenticated: true,
        userId: await _repo.currentUserId(),
      );
    });
  }

  Future<void> logout() {
    return runAction((_) async {
      await _repo.logout();
      return const AuthState();
    });
  }

  Future<void> deleteAccount() {
    return runAction((_) async {
      await _repo.deleteAccount();
      return const AuthState(success: 'Account deleted');
    });
  }
}
''';
  }
}
