/// Generates the auth feature scaffold (login / register / refresh /
/// logout / delete) wired to the Dio client and TokenStorage.
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
  /// new access token could be obtained from it. Called by the auth
  /// notifier's build() when the app starts.
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
import '../../../../core/utils/action_notifier.dart';
import '../../data/models/user_model.dart';

class AuthState implements ActionState<AuthState> {
  const AuthState({
    this.authenticated = false,
    this.user,
    this.isLoadingAction = false,
    this.error,
    this.success,
  });

  final bool authenticated;

  /// The signed-in user from `GET /auth/me`. Null when signed out — and after
  /// an offline start on a kept session, until `reloadUser()` succeeds.
  final UserModel? user;
  final bool isLoadingAction;

  /// Whether the address is verified. The router holds a signed-in user on
  /// the verify screen until it is; `reloadUser()` picks the change up.
  bool get emailVerified => {{email_verified}};

  /// One-shot: cleared by any copyWith that omits them.
  final String? error;
  final String? success;

  AuthState copyWith({
    bool? authenticated,
    UserModel? user,
    bool? isLoadingAction,
    String? error,
    String? success,
  }) {
    return AuthState(
      authenticated: authenticated ?? this.authenticated,
      user: user ?? this.user,
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

  /// Returns the generated forgot-password view template: a code by email,
  /// then a new password with it.
  static String forgotPasswordView() => r'''
import 'package:flutter/material.dart';

// TODO: build the two steps and call
// 1. ref.read(authNotifierProvider.notifier).requestPasswordReset(email: ...)
// 2. ref.read(authNotifierProvider.notifier).resetPassword(code: ..., newPassword: ...)
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
import 'package:flutter/material.dart';

// TODO: say where the email went, and call
// ref.read(authNotifierProvider.notifier).resendVerificationEmail()
// ref.read(authNotifierProvider.notifier).reloadUser()  ("I've verified it")
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

  // ── Presentation — Notifier ─────────────────────────────────────────────────

  /// Returns the generated auth notifier template.
  ///
  /// [withPushNotifications] registers this device with the backend at the two
  /// moments a session starts: opening the app on a restored session, and
  /// signing in or up.
  static String notifier({
    bool withPushNotifications = false,
    bool withAppleSignIn = false,
  }) {
    final apple = withAppleSignIn
        ? '''

  Future<void> signInWithApple() {
    return runAction((current) async {
      try {
        final user = await _repo.signInWithApple();${withPushNotifications ? '\n        unawaited(_repo.syncDeviceToken());' : ''}
        return AuthState(authenticated: true, user: user);
      } on CancelledException {
        // Dismissing the Apple sheet is not a failure worth showing.
        return current;
      }
    });
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injector.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/action_notifier.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../states/auth_state.dart';

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState>
    with ActionNotifierMixin<AuthState> {
  AuthRepository get _repo => getIt<AuthRepository>();

  @override
  FutureOr<AuthState> build() async {
    // App start: restore the session from the stored refresh token
    // (isLoggedIn refreshes the access token when one exists).
    final loggedIn = await _repo.isLoggedIn();
    if (!loggedIn) return const AuthState();
$syncOnRestore
    // The session survived (e.g. an offline start): the user stays null until
    // reloadUser() fills it in.
    UserModel? user;
    try {
      user = await _repo.me();
    } on AppException catch (e) {
      appLogger.w('Signed-in user not loaded', error: e);
    }
    return AuthState(authenticated: true, user: user);
  }

  Future<void> login({required String email, required String password}) {
    return runAction((_) async {
      final user = await _repo.login(email: email, password: password);$syncAfterAuth
      return AuthState(authenticated: true, user: user);
    });
  }

  Future<void> register({required String email, required String password}) {
    return runAction((_) async {
      final user = await _repo.register(email: email, password: password);$syncAfterAuth
      return AuthState(authenticated: true, user: user);
    });
  }

  /// Fetches the signed-in user again — after the profile changed, or when
  /// the app started offline and [AuthState.user] is still null.
  Future<void> reloadUser() {
    return runAction((current) async {
      return current.copyWith(user: await _repo.me());
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
  }$apple

  /// Emails [email] a reset code.
  Future<void> requestPasswordReset({required String email}) {
    return runAction((current) async {
      await _repo.requestPasswordReset(email: email);
      return current.copyWith(success: 'Check your email for the reset code');
    });
  }

  /// Sets [newPassword] with the emailed [code].
  Future<void> resetPassword({
    required String code,
    required String newPassword,
  }) {
    return runAction((current) async {
      await _repo.resetPassword(code: code, newPassword: newPassword);
      return current.copyWith(success: 'Password changed — sign in with it');
    });
  }

  /// Sends the verification email again.
  Future<void> resendVerificationEmail() {
    return runAction((current) async {
      await _repo.resendVerificationEmail();
      return current.copyWith(success: 'Verification email sent');
    });
  }
}
''';
  }
}
