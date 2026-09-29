import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/core/security_templates.dart';
import 'package:moarch/src/templates/riverpod/app_templates.dart' as riverpod;
import 'package:moarch/src/templates/riverpod/auth_templates.dart';
import 'package:moarch/src/templates/riverpod/feature_templates.dart';
import 'package:test/test.dart';

void main() {
  test('secureStorage exposes a TokenStorage with session handling', () {
    final output = SecurityTemplates.secureStorage();

    expect(output, contains('class TokenStorage'));
    // The locator holds it — nothing is declared beside the class.
    expect(output, isNot(contains('Provider')));
    expect(output, isNot(contains('flutter_riverpod')));
    expect(output, contains('Future<void> saveSession'));
    expect(output, contains('Future<void> clearSession'));
    // Who is signed in comes from GET /auth/me, not from the token.
    expect(output, isNot(contains('_userIdFromJwt')));
    expect(output, isNot(contains('get userId')));
    expect(output, isNot(contains('dart:convert')));
    // What older builds stored is still wiped on logout.
    expect(output, contains('await _storage.delete(key: _legacyUserIdKey);'));
  });

  test('dioClient refreshes the session on 401 and retries once', () {
    final output = CoreTemplates.dioClient(withAuthFeature: true);

    // The client takes its storage rather than reading a provider — the
    // locator holds both, in either stack.
    expect(output, contains('await storage.accessToken'));
    expect(output, contains('onError: (error, handler) async'));
    expect(output, contains('status != 401'));
    expect(output, contains('handler.resolve(response)'));
    // A retried request is never retried again.
    expect(output, contains('_kRetriedAfterRefresh'));
    // Auth routes are public: no Authorization header, no refresh loop. The
    // paths come from ApiConstants so the datasource cannot drift from them.
    expect(output, contains('ApiConstants.authLogin'));
    expect(output, contains('ApiConstants.authRegister'));
    expect(output, contains('ApiConstants.authRefresh'));
    expect(output, isNot(contains("'/auth/login'")));
  });

  test('dioClient calls back for the refresh rather than doing it itself', () {
    final output = CoreTemplates.dioClient(withAuthFeature: true);

    // One implementation of the refresh protocol, in the auth repository.
    // This client only asks for it — a callback, because the repository is
    // built on this client and resolving it eagerly would be a cycle.
    expect(output, contains('required Future<void> Function() refreshSession'));
    expect(output, contains('await refreshSession();'));
    // The endpoint, the JSON keys and the bare retry client used to live here
    // as a second copy of what the datasource already does.
    expect(output, isNot(contains('_doRefresh')));
    expect(output, isNot(contains('refreshDio')));
    expect(output, isNot(contains("data['accessToken']")));
  });

  test('dioClient clears the session only when the refresh really failed', () {
    final output = CoreTemplates.dioClient(withAuthFeature: true);

    // A refresh that failed offline says nothing about the session, so the
    // tokens survive it and the next attempt can use them. Every other
    // failure falls through to the clearing branch.
    expect(output, contains('} on NetworkException {'));
    expect(output, contains('await storage.clearSession();'));
    expect(output, isNot(contains('AppExceptionType')));
  });

  test('dioClient without the auth feature has nothing to refresh', () {
    final output = CoreTemplates.dioClient();

    expect(output, contains('Dio buildDioClient(TokenStorage storage) {'));
    expect(output, isNot(contains('refreshSession')));
    expect(output, isNot(contains('_kRetriedAfterRefresh')));
    // No session to expire means no reason to import the exception type.
    expect(output, isNot(contains("import '../errors/app_exception.dart';")));
  });

  test('dioClient logs bodies in debug builds only', () {
    final output = CoreTemplates.dioClient(withAuthFeature: true);

    // `msg.toString()` runs at the call site, so an unguarded LogInterceptor
    // serialises every response body in release before appLogger drops it.
    expect(output, contains('if (kDebugMode) {'));
    expect(
      output.indexOf('LogInterceptor('),
      greaterThan(output.indexOf('if (kDebugMode) {')),
    );
  });

  test('appException exposes a sessionExpired factory', () {
    final output = ErrorTemplates.appException();

    expect(output, contains('factory AppException.sessionExpired()'));
  });

  test('auth remote datasource covers the five auth methods', () {
    final output = AuthTemplates.remoteDatasource();

    expect(output, contains('Future<AuthTokensModel> login'));
    expect(output, contains('Future<AuthTokensModel> register'));
    expect(output, contains('Future<AuthTokensModel> refresh'));
    expect(output, contains('Future<void> logout'));
    expect(output, contains('Future<void> delete'));
    expect(output, contains('safeApiCall<'));
  });

  test('auth datasource fetches the user from GET /auth/me', () {
    final output = AuthTemplates.remoteDatasource();

    expect(output, contains('Future<UserModel> me()'));
    expect(output, contains('_dio.get<dynamic>(ApiConstants.authAccount)'));
    expect(output, contains('UserModel.fromJson('));
    expect(output, contains("import '../../domain/models/user_model.dart';"));
  });

  test('auth payloads are snake_case, like the models', () {
    final output = AuthTemplates.remoteDatasource();

    expect(output, contains("'refresh_token': refreshToken"));
    expect(output, contains("data['access_token'] as String"));
    expect(output, contains("data['refresh_token'] as String?"));
    expect(output, isNot(contains("'refreshToken'")));
    expect(output, isNot(contains("'accessToken'")));
  });

  test('the user model is freezed and snake_case through build.yaml', () {
    final output = AuthTemplates.userModel();

    expect(output, contains('abstract class UserModel with _\$UserModel'));
    expect(output, contains("part 'user_model.freezed.dart';"));
    expect(output, contains("part 'user_model.g.dart';"));
    expect(output, contains('required String id,'));
    expect(output, contains('required String email,'));
  });

  test('auth repository saves the session on login and restores it', () {
    final interface = AuthTemplates.repositoryInterface();
    final impl = AuthTemplates.repositoryImpl();

    expect(interface, contains('Future<bool> isLoggedIn()'));
    expect(interface, contains('Future<UserModel> login('));
    expect(interface, contains('Future<UserModel> register('));
    expect(interface, contains('Future<UserModel> me();'));
    expect(interface, isNot(contains('currentUserId')));
    // Constructor injection, resolved in injector.dart.
    expect(impl, contains('AuthRepositoryImpl(this._remote, this._tokens)'));
    expect(impl, isNot(contains('Provider')));
    expect(impl, contains('await _tokens.saveSession'));
    // isLoggedIn: refresh token present → refresh() → logged in.
    expect(impl, contains('if (refreshToken == null) return false;'));
    expect(impl, contains('await refresh();'));
    // Login and register save the tokens, then ask who they belong to — and
    // a failed /auth/me leaves no half session behind.
    expect(impl, contains('return _startSession(tokens);'));
    expect(impl, contains('return await _remote.me();'));
    expect(impl, contains('await _tokens.clearSession();\n      rethrow;'));
    expect(impl, isNot(contains('_tokens.userId')));
  });

  test('auth views are generated as bare skeletons', () {
    expect(AuthTemplates.loginView(), contains('class LoginView'));
    expect(AuthTemplates.registerView(), contains('class RegisterView'));
  });

  test('auth notifier restores the session in build()', () {
    final output = AuthTemplates.notifier();

    expect(output, contains('FutureOr<AuthState> build() async'));
    expect(output, contains('await _repo.isLoggedIn();'));
    expect(output, contains('authenticated: true'));
  });

  test('auth notifier carries the user from /auth/me', () {
    final notifier = AuthTemplates.notifier();
    final state = AuthTemplates.state();

    expect(state, contains('final UserModel? user;'));
    expect(state, isNot(contains('userId')));
    expect(
      notifier,
      contains('return AuthState(authenticated: true, user: user);'),
    );
    // A restored session whose user cannot be fetched stays signed in.
    expect(notifier, contains('user = await _repo.me();'));
    expect(
      notifier,
      contains('return AuthState(authenticated: true, user: user);'),
    );
    expect(notifier, contains('Future<void> reloadUser()'));
    expect(notifier, isNot(contains('currentUserId')));
  });

  group('device token registration', () {
    test('the notifier registers the device on restore, login and register', () {
      final output = AuthTemplates.notifier(withPushNotifications: true);

      // The two moments a session starts: app open and sign-in.
      expect(
        'unawaited(_repo.syncDeviceToken());'.allMatches(output).length,
        equals(3),
      );
      // Never before the session exists, or the request goes out unauthorized.
      expect(
        output.indexOf('await _repo.login(email: email, password: password);'),
        lessThan(
          output.indexOf(
            'unawaited(_repo.syncDeviceToken());',
            output.indexOf('Future<void> login('),
          ),
        ),
      );
    });

    test(
      'the repository reads the FCM token and hands it to the datasource',
      () {
        final interface = AuthTemplates.repositoryInterface(
          withPushNotifications: true,
        );
        final impl = AuthTemplates.repositoryImpl(withPushNotifications: true);
        final datasource = AuthTemplates.remoteDatasource(
          withPushNotifications: true,
        );

        expect(interface, contains('Future<void> syncDeviceToken();'));
        expect(
          impl,
          contains(
            'AuthRepositoryImpl(this._remote, this._tokens, this._push)',
          ),
        );
        expect(impl, contains('await _push.getDeviceToken();'));
        expect(
          impl,
          contains('await _remote.saveDeviceToken(token: deviceToken)'),
        );
        // A device that cannot register must not fail the sign-in.
        expect(impl, contains('} on AppException catch (e) {'));
        expect(datasource, contains('Future<void> saveDeviceToken({'));
        expect(datasource, contains('ApiConstants.authDeviceToken'));
      },
    );

    test('a project without FCM keeps the auth feature as it was', () {
      for (final output in [
        AuthTemplates.repositoryInterface(),
        AuthTemplates.repositoryImpl(),
        AuthTemplates.remoteDatasource(),
        AuthTemplates.notifier(),
      ]) {
        expect(output, isNot(contains('syncDeviceToken')));
        expect(output, isNot(contains('saveDeviceToken')));
        expect(output, isNot(contains('firebase_notifications_service')));
      }
    });
  });

  test('notifiers share the global runAction helper', () {
    final helper = riverpod.AppTemplates.actionNotifier();
    expect(helper, contains('mixin ActionNotifierMixin'));
    expect(helper, contains('Future<void> runAction'));
    expect(helper, contains('abstract interface class ActionState<T>'));

    // Auth templates use it.
    expect(
      AuthTemplates.notifier(),
      contains('with ActionNotifierMixin<AuthState>'),
    );
    expect(AuthTemplates.notifier(), contains('return runAction((_) async {'));
    // The callback receives the pre-action state so the next state never
    // carries isLoadingAction: true forward.
    expect(helper, contains('Future<S> Function(S current) action'));
    expect(helper, contains('await action(current)'));
    expect(
      AuthTemplates.state(),
      contains('implements ActionState<AuthState>'),
    );

    // Generic feature templates use it too.
    expect(
      FeatureTemplates.notifier('sample', 'Sample', 'sample'),
      contains('with ActionNotifierMixin<SampleState>'),
    );
    expect(
      FeatureTemplates.state('sample', 'Sample'),
      contains('implements ActionState<SampleState>'),
    );
  });

  test('the repository owns the single-flight refresh guard', () {
    final impl = AuthTemplates.repositoryImpl();

    // It moved here from dio_client.dart, where it was a top-level mutable
    // global beside a second copy of the refresh call. The repository is a
    // lazySingleton, so there is still exactly one refresh in flight.
    expect(impl, contains('Future<void>? _refreshing;'));
    expect(
      impl,
      contains(
        '_refreshing ??= _refresh().whenComplete(() => _refreshing = null)',
      ),
    );
    // A guard needs a field, so the constructor cannot be const any more.
    expect(impl, isNot(contains('const AuthRepositoryImpl')));
  });

  test('the auth datasource reads its paths from ApiConstants', () {
    final output = AuthTemplates.remoteDatasource();

    // The same constants dio_client.dart builds its public-route list from,
    // so the two cannot disagree about what /auth/refresh is called.
    expect(output, contains('ApiConstants.authLogin'));
    expect(output, contains('ApiConstants.authRefresh'));
    expect(output, contains('ApiConstants.authAccount'));
    expect(output, isNot(contains("'/auth/login'")));
    expect(output, isNot(contains("'/auth/refresh'")));
    expect(
      output,
      contains("import '../../../../core/constants/api_constants.dart';"),
    );
  });

  test('apiConstants declares the auth paths only with the auth feature', () {
    final withAuth = CoreTemplates.apiConstants(withAuthFeature: true);
    final without = CoreTemplates.apiConstants();

    expect(withAuth, contains("static const authRefresh = '/auth/refresh';"));
    expect(without, isNot(contains('authRefresh')));
    // The timeouts are there either way.
    expect(without, contains('connectTimeout'));
  });

  test('apiConstants declares every endpoint the options call', () {
    final all = CoreTemplates.apiConstants(
      withAuthFeature: true,
      withDeviceToken: true,
      withMaintenanceGate: true,
      withUpdateGate: true,
    );

    expect(
      all,
      contains("static const authDeviceToken = '/auth/device-token';"),
    );
    expect(
      all,
      contains("static const configMaintenance = '/config/maintenance';"),
    );
    expect(
      all,
      contains("static const configAppVersion = '/config/app-version';"),
    );
    expect(
      CoreTemplates.apiConstants(withAuthFeature: true),
      isNot(contains('authDeviceToken')),
    );
    // The anchor create feature inserts above, with or without options.
    expect(CoreTemplates.apiConstants(), contains('  // moarch:endpoints\n}'));
  });

  group('inlineMissingEndpoints', () {
    test('keeps a constant the project declares', () {
      final source = AuthTemplates.remoteDatasource(
        withPushNotifications: true,
      );
      final out = CoreTemplates.inlineMissingEndpoints(
        source,
        CoreTemplates.declaredEndpoints(
          CoreTemplates.apiConstants(
            withAuthFeature: true,
            withDeviceToken: true,
          ),
        ),
      );

      expect(out, source);
    });

    test('writes the path for a constant an older project lacks', () {
      final out = CoreTemplates.inlineMissingEndpoints(
        AuthTemplates.remoteDatasource(withPushNotifications: true),
        CoreTemplates.declaredEndpoints(
          CoreTemplates.apiConstants(withAuthFeature: true),
        ),
      );

      expect(out, contains("_dio.post<dynamic>('/auth/device-token'"));
      expect(out, isNot(contains('ApiConstants.authDeviceToken')));
      // Still used by the other calls.
      expect(out, contains('core/constants/api_constants.dart'));
    });

    test('drops the import once nothing reads ApiConstants', () {
      const source =
          "import '../../core/constants/api_constants.dart';\n"
          "import 'error_view.dart';\n"
          'final path = ApiConstants.configMaintenance;\n';

      final out = CoreTemplates.inlineMissingEndpoints(source, const {});

      expect(
        out,
        "import 'error_view.dart';\nfinal path = '/config/maintenance';\n",
      );
    });
  });

  group('safeApiCall', () {
    test('recognises offline from the failure rather than a pre-flight', () {
      final output = CoreTemplates.safeApiCall();

      // connectivity_plus reports which interface is up, not whether the
      // request can reach anything — and asking cost a platform round-trip
      // per call.
      expect(output, isNot(contains('connectivity_plus')));
      expect(output, isNot(contains('checkConnectivity')));

      expect(output, contains('DioExceptionType.connectionError'));
      expect(output, contains('DioExceptionType.connectionTimeout'));
      expect(output, contains('error.error is SocketException'));
      expect(output, contains('throw AppException.noInternet();'));
    });

    test('the cache fallback still runs when the call fails offline', () {
      final output = CoreTemplates.safeApiCall();

      expect(output, contains('if (onNoInternet != null) {'));
      expect(output, contains('if (fallback != null) return fallback;'));
    });
  });

  test('appException drops the types nothing ever produced', () {
    final output = ErrorTemplates.appException(hasDio: true);

    expect(output, contains('network'));
    expect(output, contains('notFound'));
    // `cache` and `parsing` were never constructed anywhere, and `test()` was
    // a test helper shipped in lib/.
    expect(output, isNot(contains('cache')));
    expect(output, isNot(contains('parsing')));
    expect(output, isNot(contains('factory AppException.test()')));
  });
}
