/// Generates the auth feature scaffold (login / register / refresh /
/// logout / delete) wired to the Dio client and TokenStorage, for the
/// flutter_bloc stack.
///
/// The mirror of `templates/riverpod/auth_templates.dart`. The domain and
/// data layers are the same code with the providers taken off — get_it wires
/// them in `config/di/injector.dart` — and the notifier becomes an
/// event-driven `AuthBloc` registered as a singleton, since the router's
/// redirect and every screen have to read the same session.
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
  /// [withPushNotifications] adds the device-token contract the bloc calls on
  /// login, on register and when a stored session is restored.
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
  /// new access token could be obtained from it. Called by the auth bloc
  /// when AuthStarted is dispatched at app start.
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

import '../../../../core/network/safe_api_call.dart';
import '../models/auth_tokens_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  // Adjust endpoints and payload keys to your API contract. The auth routes
  // are listed as public endpoints in dio_client.dart, so they are sent
  // without an Authorization header.

  Future<AuthTokensModel> login({
    required String email,
    required String password,
  }) {
    return safeApiCall<AuthTokensModel>(
      apiCall: () async {
        final response = await _dio.post<dynamic>('/auth/login', data: {
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
        final response = await _dio.post<dynamic>('/auth/register', data: {
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
        final response = await _dio.post<dynamic>('/auth/refresh', data: {
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
        await _dio.post<dynamic>('/auth/logout', data: {
          'refreshToken': refreshToken,
        });
      },
    );
  }

  Future<void> delete() {
    return safeApiCall<void>(
      apiCall: () async {
        await _dio.delete<dynamic>('/auth/me');
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
  const AuthRepositoryImpl(this._remote, this._tokens$pushCtorParam);

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

  @override
  Future<void> refresh() async {
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
import 'package:equatable/equatable.dart';

/// Whether this app has a session, as a sealed family.
///
/// The router reads it: [AuthInitial] is what holds it on the splash route,
/// so neither login nor home flashes before the stored session is checked.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const [];
}

/// Session restore is still running. Nothing has been decided yet.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A sign-in or sign-up is in flight.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Signed in.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({this.userId});

  final String? userId;

  @override
  List<Object?> get props => [userId];
}

/// Signed out, and nothing went wrong getting here.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An attempt failed. Still signed out — the login screen shows [message].
final class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
''';

  // ── Presentation — Events ───────────────────────────────────────────────────

  /// Returns the generated auth event template.
  static String event() => r'''
import 'package:equatable/equatable.dart';

/// Everything that can happen to the session, as values.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

/// App start: restore the session from the stored refresh token. Dispatched
/// by the `BlocProvider` in main.dart, and nothing else.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

final class AuthAccountDeleted extends AuthEvent {
  const AuthAccountDeleted();
}
''';

  // ── Presentation — Views ────────────────────────────────────────────────────

  /// Returns the generated login view template.
  static String loginView() => r'''
import 'package:flutter/material.dart';

// TODO: build your login UI and dispatch
// context.read<AuthBloc>().add(AuthLoginRequested(email: ..., password: ...))

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

// TODO: build your register UI and dispatch
// context.read<AuthBloc>().add(AuthRegisterRequested(email: ..., password: ...))

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

  // ── Presentation — Bloc ─────────────────────────────────────────────────────

  /// Returns the generated auth bloc template.
  ///
  /// [withPushNotifications] registers this device with the backend at the two
  /// moments a session starts: opening the app on a restored session, and
  /// signing in or up.
  static String bloc({bool withPushNotifications = false}) {
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

import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import '../states/auth_state.dart';
import 'auth_event.dart';

/// The session, as the whole app sees it.
///
/// Registered as a **singleton** in `config/di/injector.dart`, unlike feature
/// blocs: the router's redirect and every screen have to read the same one.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthAccountDeleted>(_onDeleteAccount);
  }

  final AuthRepository _repo;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    // App start: restore the session from the stored refresh token
    // (isLoggedIn refreshes the access token when one exists). The router
    // holds on splash until this leaves AuthInitial.
    try {
      final loggedIn = await _repo.isLoggedIn();
      if (!loggedIn) {
        emit(const AuthUnauthenticated());
        return;
      }
$syncOnRestore
      emit(AuthAuthenticated(userId: await _repo.currentUserId()));
    } on AppException catch (_) {
      // A failed restore is a signed-out app, not an error screen — the user
      // can still log in.
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.login(email: event.email, password: event.password);$syncAfterAuth
      emit(AuthAuthenticated(userId: await _repo.currentUserId()));
    } on AppException catch (e) {
      // Still signed out, now with a reason the login screen can show.
      emit(AuthFailure(e.message));
    }
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repo.register(email: event.email, password: event.password);$syncAfterAuth
      emit(AuthAuthenticated(userId: await _repo.currentUserId()));
    } on AppException catch (e) {
      emit(AuthFailure(e.message));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Logout always succeeds locally, so there is no failure branch to draw.
    await _repo.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onDeleteAccount(
    AuthAccountDeleted event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthAuthenticated) return;

    // No AuthLoading and no AuthFailure around this one, deliberately: the
    // router keys on this state, so either would read as "not signed in" and
    // bounce a user who still is. The screen showing the confirm dialog owns
    // the spinner and the error message; the bloc only reports the one
    // outcome that changes the session.
    try {
      await _repo.deleteAccount();
      emit(const AuthUnauthenticated());
    } on AppException catch (_) {
      // The account is still there, so the session is. Nothing to change.
    }
  }
}
''';
  }
}
