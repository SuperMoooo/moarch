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
  static String repositoryInterface() => r'''
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

  /// User id extracted from the access token when the session was saved.
  Future<String?> currentUserId();
}
''';

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
  static String remoteDatasource() => r'''
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/safe_api_call.dart';
import '../models/auth_tokens_model.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioClientProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────

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

  Future<AuthTokensModel> refresh(String refreshToken) {
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

  Future<void> logout(String refreshToken) {
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
}
''';

  // ── Data — Repository impl ──────────────────────────────────────────────────

  /// Returns the generated auth repository implementation template.
  static String repositoryImpl() => r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/security/secure_storage.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(tokenStorageProvider),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._tokens);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

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
    final tokens = await _remote.refresh(refreshToken);
    await _tokens.saveSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokens.refreshToken;
    try {
      if (refreshToken != null) await _remote.logout(refreshToken);
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

  @override
  Future<String?> currentUserId() => _tokens.userId;
}
''';

  // ── Presentation — State ────────────────────────────────────────────────────

  /// Returns the generated auth state template.
  static String state() => r'''
class AuthState {
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
}
''';

  // ── Presentation — Notifier ─────────────────────────────────────────────────

  /// Returns the generated auth notifier template.
  static String notifier() => r'''
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../states/auth_state.dart';

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  FutureOr<AuthState> build() async {
    // App start: restore the session from the stored refresh token
    // (isLoggedIn refreshes the access token when one exists).
    final loggedIn = await _repo.isLoggedIn();
    if (!loggedIn) return const AuthState();
    return AuthState(
      authenticated: true,
      userId: await _repo.currentUserId(),
    );
  }

  Future<void> login({required String email, required String password}) {
    return _runAction(() async {
      await _repo.login(email: email, password: password);
      return AuthState(
        authenticated: true,
        userId: await _repo.currentUserId(),
      );
    });
  }

  Future<void> register({required String email, required String password}) {
    return _runAction(() async {
      await _repo.register(email: email, password: password);
      return AuthState(
        authenticated: true,
        userId: await _repo.currentUserId(),
      );
    });
  }

  Future<void> logout() {
    return _runAction(() async {
      await _repo.logout();
      return const AuthState();
    });
  }

  Future<void> deleteAccount() {
    return _runAction(() async {
      await _repo.deleteAccount();
      return const AuthState(success: 'Account deleted');
    });
  }

  /// Runs [action] with shared loading/error handling; [action] returns the
  /// next state.
  Future<void> _runAction(Future<AuthState> Function() action) async {
    final current = state.value ?? const AuthState();
    state = AsyncData(current.copyWith(isLoadingAction: true));
    try {
      state = AsyncData(await action());
    } on AppException catch (e) {
      state = AsyncData(current.copyWith(error: e.message));
    } catch (_) {
      state = AsyncData(current.copyWith(error: 'Unknown error'));
    }
  }
}
''';
}
