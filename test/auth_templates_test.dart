import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/core/security_templates.dart';
import 'package:moarch/src/templates/ui/auth_templates.dart';
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

    expect(output, contains('final storage = ref.watch(tokenStorageProvider);'));
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

  test('auth notifier restores the session in build()', () {
    final output = AuthTemplates.notifier();

    expect(output, contains('FutureOr<AuthState> build() async'));
    expect(output, contains('await _repo.isLoggedIn();'));
    expect(output, contains('authenticated: true'));
  });
}
