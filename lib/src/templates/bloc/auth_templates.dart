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

  /// Returns the generated auth tokens model template.
  static String model() => r'''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_tokens_model.freezed.dart';
part 'auth_tokens_model.g.dart';

/// The token pair as the API sends it. Keys are snake_case (`build.yaml`).
@freezed
abstract class AuthTokensModel with _$AuthTokensModel {
  const factory AuthTokensModel({
    required String accessToken,
    required String refreshToken,
  }) = _AuthTokensModel;

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensModelFromJson(json);
}
''';

  /// Returns the generated signed-in user model template — what
  /// `GET /auth/me` answers with.
  static String userModel() => r'''
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// The signed-in user, as `GET /auth/me` returns it. Keys are snake_case
/// (`build.yaml`); add the fields your API sends.
@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    String? name,

    /// The API's `email_verified`. True when it sends none, so an API without
    /// email verification never holds anyone on the verify screen.
    @Default(true) bool emailVerified,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// A blank user, e.g. for test stubs. Keep it in step with the fields.
  factory UserModel.empty() => const UserModel(id: '', email: '');
}
''';

  // ── Data — Remote datasource ────────────────────────────────────────────────

  /// Returns the generated auth remote datasource template.
  ///
  /// [withPushNotifications] adds the call that registers this device's FCM
  /// token against the signed-in user.
  ///
  /// [withAppleSignIn] adds Sign in with Apple: the Apple sheet, then its
  /// identity token traded for a session at `POST /auth/apple`.
  static String remoteDatasource({
    bool withPushNotifications = false,
    bool withAppleSignIn = false,
  }) {
    final appleImports = withAppleSignIn
        ? "import 'package:sign_in_with_apple/sign_in_with_apple.dart';\n"
        : '';
    final appleExceptionImport = withAppleSignIn
        ? "import '../../../../core/errors/app_exception.dart';\n"
        : '';
    final appleOptions = withAppleSignIn ? _appleWebOptions : '';
    final apple = withAppleSignIn ? _appleSignIn : '';
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
        await _dio.post<dynamic>(ApiConstants.authDeviceToken, data: {
          'token': token,
        });
      },
    );
  }
'''
        : '';

    return '''
import 'package:dio/dio.dart';
$appleImports
import '../../../../core/constants/api_constants.dart';
${appleExceptionImport}import '../../../../core/network/safe_api_call.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';
$appleOptions
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  // The paths live in ApiConstants, which is also where dio_client.dart reads
  // the three that go out without an Authorization header. Payload keys are
  // snake_case, like the models' — adjust them to your API contract.

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
          'refresh_token': refreshToken,
        });
        final data = response.data as Map<String, dynamic>;
        // Without a rotated refresh token, keep the current one.
        return AuthTokensModel(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String? ?? refreshToken,
        );
      },
    );
  }

  /// The signed-in user, identified by the request's access token.
  Future<UserModel> me() {
    return safeApiCall<UserModel>(
      apiCall: () async {
        final response = await _dio.get<dynamic>(ApiConstants.authAccount);
        return UserModel.fromJson(response.data as Map<String, dynamic>);
      },
    );
  }

  Future<void> logout({required String refreshToken}) {
    return safeApiCall<void>(
      apiCall: () async {
        // Lets the backend revoke the refresh token; local cleanup happens anyway.
        await _dio.post<dynamic>(ApiConstants.authLogout, data: {
          'refresh_token': refreshToken,
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

  /// Asks the API to email [email] a reset code. It should answer the same
  /// whether or not the address has an account, so it cannot be probed.
  Future<void> requestPasswordReset({required String email}) {
    return safeApiCall<void>(
      apiCall: () async {
        await _dio.post<dynamic>(ApiConstants.authPasswordForgot, data: {
          'email': email,
        });
      },
    );
  }

  /// Sets [newPassword] with the [code] the reset email carried.
  Future<void> resetPassword({
    required String code,
    required String newPassword,
  }) {
    return safeApiCall<void>(
      apiCall: () async {
        await _dio.post<dynamic>(ApiConstants.authPasswordReset, data: {
          'code': code,
          'password': newPassword,
        });
      },
    );
  }

  /// Sends the signed-in user's verification email again.
  Future<void> resendVerificationEmail() {
    return safeApiCall<void>(
      apiCall: () async {
        await _dio.post<dynamic>(ApiConstants.authEmailResend);
      },
    );
  }
$apple$saveDeviceToken}
''';
  }

  static const String _appleWebOptions = r"""

/// Android and the web have no native Apple sheet: they sign in through
/// Apple's website, which needs a Services ID and a redirect URL your backend
/// serves (docs/AUTH.md). Null on iOS and macOS, where the native sheet is
/// used.
const WebAuthenticationOptions? kAppleWebAuthentication = null;
""";

  static const String _appleSignIn = r"""

  /// The Apple sheet, then its identity token traded for a session.
  ///
  /// Your API verifies the token against Apple's public keys
  /// (https://appleid.apple.com/auth/keys). Apple sends the name on the first
  /// sign-in only, so it travels with that request.
  Future<AuthTokensModel> signInWithApple() async {
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: kAppleWebAuthentication,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw AppException.cancelled();
      }
      throw AppException.fromError(error, StackTrace.current);
    }

    final identityToken = credential.identityToken;
    if (identityToken == null) {
      throw AppException.fromError(
        'Apple returned no identity token',
        StackTrace.current,
      );
    }

    return safeApiCall<AuthTokensModel>(
      apiCall: () async {
        final response = await _dio.post<dynamic>(ApiConstants.authApple, data: {
          'identity_token': identityToken,
          'authorization_code': credential.authorizationCode,
          if (credential.givenName != null) 'given_name': credential.givenName,
          if (credential.familyName != null)
            'family_name': credential.familyName,
        });
        return AuthTokensModel.fromJson(response.data as Map<String, dynamic>);
      },
    );
  }
""";

  // ── Data — Repository ───────────────────────────────────────────────────────

  /// Returns the generated auth repository template: the one class the
  /// state holder calls, over the datasource and secure storage.
  ///
  /// [withPushNotifications] hands the FCM service to the repository, so a
  /// signed-in session can register the device with the backend.
  static String repository({
    bool withPushNotifications = false,
    bool withLocalCache = false,
    bool withAppleSignIn = false,
  }) {
    final apple = withAppleSignIn
        ? '''

  /// Sign in with Apple: the Apple sheet, then a session like a login.
  ///
  /// Throws a `CancelledException` when the user dismisses the sheet —
  /// nothing failed, so there is nothing to report.
  Future<UserModel> signInWithApple() async {
    final tokens = await _remote.signInWithApple();
    return _startSession(tokens);
  }'''
        : '';
    // The offline-first cache holds the signed-in account's data, so every
    // way a session ends or changes hands empties it.
    final cacheImport = withLocalCache
        ? '''import '../../../../core/database/local_cache.dart';
'''
        : '';
    final cacheCtorParam = withLocalCache ? ', this._cache' : '';
    final cacheField = withLocalCache
        ? '''

  final LocalCache _cache;'''
        : '';
    final clearCache = withLocalCache
        ? '''

      await _cache.clearAll();'''
        : '';
    final clearCacheOnDelete = withLocalCache
        ? '''

    await _cache.clearAll();'''
        : '';
    final clearCacheOnStart = withLocalCache
        ? '''

    // Whoever was signed in before, their cached data goes.
    await _cache.clearAll();'''
        : '';

    final pushImport = withPushNotifications
        ? "import '../../../../core/services/firebase_notifications_service.dart';\n"
        : '';

    final pushCtorParam = withPushNotifications ? ', this._push' : '';

    final pushField = withPushNotifications
        ? '\n  final FirebaseNotificationsService _push;'
        : '';

    final syncDeviceToken = withPushNotifications
        ? '''

  /// Reads this device's push token and sends it to the backend, so it can
  /// target the signed-in user. Safe to call repeatedly — the token only
  /// changes when the install does.
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
${cacheImport}import '../../../../core/errors/app_exception.dart';
import '../../../../core/security/secure_storage.dart';
${pushImport}import '../../../../core/utils/app_logger.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepository {
  AuthRepository(this._remote, this._tokens$pushCtorParam$cacheCtorParam);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;$pushField$cacheField

  /// True when a session can be restored: a refresh token is stored and a
  /// new access token could be obtained from it. Called by the auth bloc
  /// when AuthStarted is dispatched at app start.
  Future<bool> isLoggedIn() async {
    final refreshToken = await _tokens.refreshToken;
    if (refreshToken == null) return false;
    try {
      // Session restore: trade the stored refresh token for fresh tokens.
      await refresh();
      return true;
    } on NetworkException {
      // Offline says nothing about the session: keep it.
      return true;
    } on AppException catch (e) {
      appLogger.w('Stored session is no longer valid', error: e);
      await _tokens.clearSession();
      return false;
    }
  }

  /// Authenticates, saves the access and refresh tokens in secure storage,
  /// and returns the signed-in user from `GET /auth/me`.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _remote.login(email: email, password: password);
    return _startSession(tokens);
  }

  /// Creates the account, saves the returned session in secure storage, and
  /// returns the new user from `GET /auth/me`.
  Future<UserModel> register({
    required String email,
    required String password,
  }) async {
    final tokens = await _remote.register(email: email, password: password);
    return _startSession(tokens);
  }

  /// The signed-in user, as `GET /auth/me` returns it.
  Future<UserModel> me() => _remote.me();

  /// Saves [tokens], then fetches their user. A failed `GET /auth/me` undoes
  /// the save.
  Future<UserModel> _startSession(AuthTokensModel tokens) async {$clearCacheOnStart
    await _tokens.saveSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    try {
      return await _remote.me();
    } on AppException {
      await _tokens.clearSession();
      rethrow;
    }
  }

  /// The refresh in flight, shared by concurrent 401s so the refresh token is
  /// spent once.
  Future<void>? _refreshing;

  /// Exchanges the stored refresh token for a new access token.
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

  /// Revokes the session on the backend (best effort) and always clears the
  /// local session.
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
      await _tokens.clearSession();$clearCache
    }
  }

  /// Deletes the account on the backend and clears the local session.
  Future<void> deleteAccount() async {
    await _remote.delete();
    await _tokens.clearSession();$clearCacheOnDelete
  }
$apple
  /// Emails [email] a reset code. No session involved.
  Future<void> requestPasswordReset({required String email}) =>
      _remote.requestPasswordReset(email: email);

  /// Sets [newPassword] with the emailed [code]. The user then signs in
  /// with it.
  Future<void> resetPassword({
    required String code,
    required String newPassword,
  }) => _remote.resetPassword(code: code, newPassword: newPassword);

  /// Sends the verification email again. Reload the user afterwards to see
  /// whether the address has been verified.
  Future<void> resendVerificationEmail() => _remote.resendVerificationEmail();
$syncDeviceToken}
''';
  }

  // ── Presentation — State ────────────────────────────────────────────────────

  /// Returns the generated auth state template.
  ///
  /// [withEmailVerification] reads `emailVerified` off the user — only when
  /// the project's `UserModel` declares it, since that file is the team's.
  static String state({bool withEmailVerification = false}) =>
      _state.replaceFirst(
        '{{email_verified}}',
        withEmailVerification ? 'user?.emailVerified ?? true' : 'true',
      );

  static const String _state = r'''
import 'package:equatable/equatable.dart';

import '../../data/models/user_model.dart';

/// Whether the app has a session. The router holds on splash while
/// [AuthInitial].
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
  const AuthAuthenticated({this.user});

  /// The user from `GET /auth/me`. Null after an offline start, until
  /// `AuthUserReloadRequested` succeeds.
  final UserModel? user;

  /// Whether the address is verified. The router holds the user on the
  /// verify screen until it is; reload the user to see the change.
  bool get emailVerified => {{email_verified}};

  @override
  List<Object?> get props => [user];
}

/// Signed out, and nothing went wrong getting here.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An attempt failed. A non-null [session] means the user is still signed in
/// (a refused delete or reload); null means signed out.
final class AuthFailure extends AuthState {
  /// Each failure gets its own [id], so a repeated error is still emitted.
  AuthFailure(this.message, {this.session}) : id = ++_seq;

  static int _seq = 0;

  final int id;

  final String message;

  /// The session that survived the failure, or null when signed out.
  final AuthAuthenticated? session;

  /// The still-signed-in user, if there is one.
  UserModel? get user => session?.user;

  /// Whether the session outlived the failure. Read by the router redirect.
  bool get authenticated => session != null;

  @override
  List<Object?> get props => [message, session, id];
}
''';

  // ── Presentation — Events ───────────────────────────────────────────────────

  /// Returns the generated auth event template. [withAppleSignIn] adds
  /// `AuthAppleSignInRequested`.
  static String event({bool withAppleSignIn = false}) =>
      _event + (withAppleSignIn ? _appleEvent : '');

  static const String _appleEvent = r'''

final class AuthAppleSignInRequested extends AuthEvent {
  const AuthAppleSignInRequested();
}
''';

  static const String _event = r'''
import 'package:equatable/equatable.dart';

/// Everything that can happen to the session, as values.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

/// App start: restore the session. Dispatched by main.dart only.
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

/// Fetch the signed-in user again (after a profile change, or an offline
/// start).
final class AuthUserReloadRequested extends AuthEvent {
  const AuthUserReloadRequested();
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

final class AuthAccountDeleted extends AuthEvent {
  const AuthAccountDeleted();
}

/// Email [email] a reset code. Signed out; the screen confirms the send.
final class AuthPasswordResetRequested extends AuthEvent {
  const AuthPasswordResetRequested({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Set [newPassword] with the emailed [code].
final class AuthPasswordResetConfirmed extends AuthEvent {
  const AuthPasswordResetConfirmed({
    required this.code,
    required this.newPassword,
  });

  final String code;
  final String newPassword;

  @override
  List<Object?> get props => [code, newPassword];
}

/// Send the verification email again.
final class AuthVerificationEmailRequested extends AuthEvent {
  const AuthVerificationEmailRequested();
}
''';

  // ── Presentation — Views ────────────────────────────────────────────────────

  /// Returns the generated forgot-password view template: a code by email,
  /// then a new password with it.
  static String forgotPasswordView() => r'''
import 'package:material_ui/material_ui.dart';

// TODO: build the two steps and call
// 1. context.read<AuthBloc>().add(AuthPasswordResetRequested(email: ...))
// 2. context.read<AuthBloc>().add(AuthPasswordResetConfirmed(code: ..., newPassword: ...))
// then send the user back to the login screen.

class ForgotPasswordView extends StatelessWidget {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: const SizedBox.shrink(),
    );
  }
}
''';

  /// Returns the generated verify-email view template — where the router
  /// holds a signed-in user whose address is not verified yet.
  static String verifyEmailView() => r'''
import 'package:material_ui/material_ui.dart';

// TODO: say where the email went, and call
// context.read<AuthBloc>().add(const AuthVerificationEmailRequested())
// context.read<AuthBloc>().add(const AuthUserReloadRequested())  ("I've verified it")
// The router moves on by itself once the address is verified.

class VerifyEmailView extends StatelessWidget {
  const VerifyEmailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: const SizedBox.shrink(),
    );
  }
}
''';

  /// Returns the generated login view template.
  static String loginView() => r'''
import 'package:material_ui/material_ui.dart';

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
import 'package:material_ui/material_ui.dart';

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
  /// Rewrites [source]'s `on<Event>(_handler);` registrations for [events] to
  /// drop a repeat while the first is still running, and adds the import.
  ///
  /// A double-tapped "Log in" otherwise sends two requests, and the second
  /// one's failure can land after the first one's success. `droppable()` is
  /// the answer for anything the user submits: the tap that arrives mid-flight
  /// is ignored, not queued. Session restore and the auth stream keep the
  /// default, since every one of those events has to be seen.
  static String withDroppable(String source, List<String> events) {
    var out = source.replaceFirst(
      "import 'package:bloc/bloc.dart';",
      "import 'package:bloc/bloc.dart';\n"
          "import 'package:bloc_concurrency/bloc_concurrency.dart';",
    );
    for (final event in events) {
      out = out.replaceFirstMapped(
        RegExp(
          'on<$event>'
          r'\((_\w+)\);',
        ),
        (m) => 'on<$event>(${m[1]}, transformer: droppable());',
      );
    }
    return out;
  }

  /// The auth bloc. [withConcurrency] drops a repeated submit while the
  /// first is in flight — see [withDroppable]. It is read off the pubspec
  /// (`bloc_concurrency`), so a project without the package refreshes into a
  /// bloc that still compiles.
  static String bloc({
    bool withPushNotifications = false,
    bool withConcurrency = false,
    bool withAppleSignIn = false,
  }) {
    final source = _bloc(
      withPushNotifications: withPushNotifications,
      withAppleSignIn: withAppleSignIn,
    );
    return withConcurrency
        ? withDroppable(source, [
            'AuthLoginRequested',
            'AuthRegisterRequested',
            if (withAppleSignIn) 'AuthAppleSignInRequested',
            'AuthUserReloadRequested',
            'AuthPasswordResetRequested',
            'AuthPasswordResetConfirmed',
            'AuthVerificationEmailRequested',
            'AuthLogoutRequested',
            'AuthAccountDeleted',
          ])
        : source;
  }

  static String _bloc({
    bool withPushNotifications = false,
    bool withAppleSignIn = false,
  }) {
    final appleRegistration = withAppleSignIn
        ? '\n    on<AuthAppleSignInRequested>(_onAppleSignIn);'
        : '';
    final appleHandler = withAppleSignIn
        ? '''

  Future<void> _onAppleSignIn(
    AuthAppleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    emit(const AuthLoading());
    try {
      final user = await _repo.signInWithApple();${withPushNotifications ? '\n      unawaited(_repo.syncDeviceToken());' : ''}
      emit(AuthAuthenticated(user: user));
    } on CancelledException {
      // Dismissing the Apple sheet is not a failure worth showing.
      emit(current);
    } on AppException catch (e) {
      emit(AuthFailure(e.message));
    }
  }'''
        : '';
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
import '../../../../core/utils/app_logger.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// The session, as the whole app sees it. A singleton, unlike feature blocs.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthUserReloadRequested>(_onUserReload);$appleRegistration
    on<AuthPasswordResetRequested>(_onPasswordReset);
    on<AuthPasswordResetConfirmed>(_onPasswordResetConfirmed);
    on<AuthVerificationEmailRequested>(_onVerificationEmail);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthAccountDeleted>(_onDeleteAccount);
  }

  final AuthRepository _repo;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    // App start: restore the session. The router holds on splash until this
    // leaves AuthInitial.
    try {
      final loggedIn = await _repo.isLoggedIn();
      if (!loggedIn) {
        emit(const AuthUnauthenticated());
        return;
      }
$syncOnRestore
      // The session survived (e.g. an offline start): the user stays null until
      // AuthUserReloadRequested fills it in.
      UserModel? user;
      try {
        user = await _repo.me();
      } on AppException catch (e) {
        appLogger.w('Signed-in user not loaded', error: e);
      }
      emit(AuthAuthenticated(user: user));
    } on AppException catch (_) {
      // A failed restore just means signed out.
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repo.login(
        email: event.email,
        password: event.password,
      );$syncAfterAuth
      emit(AuthAuthenticated(user: user));
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
      final user = await _repo.register(
        email: event.email,
        password: event.password,
      );$syncAfterAuth
      emit(AuthAuthenticated(user: user));
    } on AppException catch (e) {
      emit(AuthFailure(e.message));
    }
  }

  Future<void> _onUserReload(
    AuthUserReloadRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthAuthenticated) return;

    // No AuthLoading, for the reason given in _onDeleteAccount.
    try {
      emit(AuthAuthenticated(user: await _repo.me()));
    } on AppException catch (e) {
      emit(AuthFailure(e.message, session: current));
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
    final current = state;
    if (current is! AuthAuthenticated) return;

    // No AuthLoading here: the router would read it as signed out. A failure
    // carries the session, so the redirect keeps the user in.
    try {
      await _repo.deleteAccount();
      emit(const AuthUnauthenticated());
    } on AppException catch (e) {
      emit(AuthFailure(e.message, session: current));
    }
  }$appleHandler

  // The three below do not change the session, so only a failure is a state;
  // the screen confirms the send itself. A failure carries the session it
  // found, so a signed-in user stays signed in.

  Future<void> _onPasswordReset(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    try {
      await _repo.requestPasswordReset(email: event.email);
    } on AppException catch (e) {
      emit(AuthFailure(e.message, session: _sessionOf(current)));
    }
  }

  Future<void> _onPasswordResetConfirmed(
    AuthPasswordResetConfirmed event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    try {
      await _repo.resetPassword(
        code: event.code,
        newPassword: event.newPassword,
      );
    } on AppException catch (e) {
      emit(AuthFailure(e.message, session: _sessionOf(current)));
    }
  }

  Future<void> _onVerificationEmail(
    AuthVerificationEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    try {
      await _repo.resendVerificationEmail();
    } on AppException catch (e) {
      emit(AuthFailure(e.message, session: _sessionOf(current)));
    }
  }

  AuthAuthenticated? _sessionOf(AuthState state) => switch (state) {
    AuthAuthenticated() => state,
    AuthFailure(:final session) => session,
    _ => null,
  };
}
''';
  }
}
