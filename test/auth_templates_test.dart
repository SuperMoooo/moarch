import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/core/security_templates.dart';
import 'package:moarch/src/templates/ui/auth_templates.dart';
import 'package:moarch/src/templates/ui/feature_templates.dart';
import 'package:test/test.dart';

void main() {
  test('secureStorage exposes a TokenStorage with session handling', () {
    final output = SecurityTemplates.secureStorage();

    expect(output, contains('class TokenStorage'));
    expect(output, contains('final tokenStorageProvider'));
    expect(output, contains('Future<void> saveSession'));
    expect(output, contains('Future<void> clearSession'));
    // User id is decoded from the access token payload at save time.
    expect(output, contains('_userIdFromJwt(accessToken)'));
    expect(output, contains("payload['sub']"));
  });

  test('dioClient refreshes the session on 401 and retries once', () {
    final output = CoreTemplates.dioClient();

    expect(
        output, contains('final storage = ref.watch(tokenStorageProvider);'));
    expect(output, contains('await storage.accessToken'));
    expect(output, contains('onError: (error, handler) async'));
    expect(output, contains('status != 401'));
    expect(output, contains('_refreshSession(storage)'));
    expect(output, contains('handler.resolve(response)'));
    // Failed refresh clears the session so the app can redirect to login.
    expect(output, contains('await storage.clearSession();'));
    // A retried request is never retried again.
    expect(output, contains('_kRetriedAfterRefresh'));
    // Auth routes are public: no Authorization header, no refresh loop.
    expect(output, contains("'/auth/login'"));
    expect(output, contains("'/auth/register'"));
    expect(output, contains("'/auth/refresh'"));
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

  test('auth repository saves the session on login and restores it', () {
    final interface = AuthTemplates.repositoryInterface();
    final impl = AuthTemplates.repositoryImpl();

    expect(interface, contains('Future<bool> isLoggedIn()'));
    expect(impl, contains('ref.watch(tokenStorageProvider)'));
    expect(impl, contains('await _tokens.saveSession'));
    // isLoggedIn: refresh token present → refresh() → logged in.
    expect(impl, contains('if (refreshToken == null) return false;'));
    expect(impl, contains('await refresh();'));
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

  group('device token registration', () {
    test('the notifier registers the device on restore, login and register',
        () {
      final output = AuthTemplates.notifier(withPushNotifications: true);

      // The two moments a session starts: app open and sign-in.
      expect(
        'unawaited(_repo.syncDeviceToken());'.allMatches(output).length,
        equals(3),
      );
      // Never before the session exists, or the request goes out unauthorized.
      expect(
        output.indexOf('await _repo.login(email: email, password: password);'),
        lessThan(output.indexOf('unawaited(_repo.syncDeviceToken());',
            output.indexOf('Future<void> login('))),
      );
    });

    test('the repository reads the FCM token and hands it to the datasource',
        () {
      final interface =
          AuthTemplates.repositoryInterface(withPushNotifications: true);
      final impl = AuthTemplates.repositoryImpl(withPushNotifications: true);
      final datasource =
          AuthTemplates.remoteDatasource(withPushNotifications: true);

      expect(interface, contains('Future<void> syncDeviceToken();'));
      expect(impl, contains('ref.watch(firebaseNotificationsServiceProvider)'));
      expect(impl, contains('await _push.getDeviceToken();'));
      expect(
          impl, contains('await _remote.saveDeviceToken(token: deviceToken)'));
      // A device that cannot register must not fail the sign-in.
      expect(impl, contains('} on AppException catch (e) {'));
      expect(datasource, contains('Future<void> saveDeviceToken({'));
      expect(datasource, contains("'/auth/device-token'"));
    });

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
    final helper = CoreTemplates.actionNotifier();
    expect(helper, contains('mixin ActionNotifierMixin'));
    expect(helper, contains('Future<void> runAction'));
    expect(helper, contains('abstract interface class ActionState<T>'));

    // Auth templates use it.
    expect(AuthTemplates.notifier(),
        contains('with ActionNotifierMixin<AuthState>'));
    expect(AuthTemplates.notifier(), contains('return runAction((_) async {'));
    // The callback receives the pre-action state so the next state never
    // carries isLoadingAction: true forward.
    expect(helper, contains('Future<S> Function(S current) action'));
    expect(helper, contains('await action(current)'));
    expect(
        AuthTemplates.state(), contains('implements ActionState<AuthState>'));

    // Generic feature templates use it too.
    expect(
        FeatureTemplates.notifier('sample', 'Sample', 'sample',
            hasUseCase: false),
        contains('with ActionNotifierMixin<SampleState>'));
    expect(FeatureTemplates.state('sample', 'Sample'),
        contains('implements ActionState<SampleState>'));
  });
}
