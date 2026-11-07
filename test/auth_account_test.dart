import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/misc/ios_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

void main() {
  const stacks = [
    StackTemplates(StateManagement.riverpod),
    StackTemplates(StateManagement.bloc),
  ];

  group('REST auth', () {
    test('password reset and verification resend on every project', () {
      for (final t in stacks) {
        final datasource = t.authRemoteDatasource();
        expect(datasource, contains('ApiConstants.authPasswordForgot'));
        expect(datasource, contains('ApiConstants.authPasswordReset'));
        expect(datasource, contains('ApiConstants.authEmailResend'));
        final repo = t.authRepository();
        expect(repo, contains('Future<void> requestPasswordReset('));
        expect(repo, contains('Future<void> resetPassword({'));
        expect(repo, contains('Future<void> resendVerificationEmail()'));
      }
    });

    test('Sign in with Apple only when asked for', () {
      for (final t in stacks) {
        expect(t.authRemoteDatasource(), isNot(contains('sign_in_with_apple')));
        final apple = t.authRemoteDatasource(withAppleSignIn: true);
        expect(
          apple,
          contains(
            "import 'package:sign_in_with_apple/sign_in_with_apple.dart';",
          ),
        );
        expect(apple, contains('SignInWithApple.getAppleIDCredential('));
        expect(apple, contains('ApiConstants.authApple'));
        // A dismissed sheet is a cancel, not an error.
        expect(apple, contains('throw AppException.cancelled();'));
        expect(
          t.authRepository(withAppleSignIn: true),
          contains('Future<UserModel> signInWithApple() async {'),
        );
        expect(
          t.authHolder(withAppleSignIn: true),
          contains('on CancelledException'),
        );
      }
      expect(
        const StackTemplates(
          StateManagement.bloc,
        ).authEvent(withAppleSignIn: true),
        contains('final class AuthAppleSignInRequested extends AuthEvent'),
      );
    });

    test(
      'the model carries emailVerified, and the state reads it only if so',
      () {
        for (final t in stacks) {
          expect(
            t.authUserModel(),
            contains('@Default(true) bool emailVerified'),
          );
          expect(
            t.authState(withEmailVerification: true),
            contains('bool get emailVerified => user?.emailVerified ?? true;'),
          );
          // A team's UserModel without the field still compiles.
          expect(t.authState(), contains('bool get emailVerified => true;'));
        }
      },
    );

    test('ApiConstants declares the new paths, Apple only with Apple', () {
      final constants = CoreTemplates.apiConstants(withAuthFeature: true);
      expect(
        constants,
        contains("authPasswordForgot = '/auth/password/forgot'"),
      );
      expect(constants, contains("authEmailResend = '/auth/email/resend'"));
      expect(constants, isNot(contains('authApple')));
      expect(
        CoreTemplates.apiConstants(
          withAuthFeature: true,
          withAppleSignIn: true,
        ),
        contains("authApple = '/auth/apple'"),
      );
      // Signed out, so no token and no refresh retry.
      final dio = CoreTemplates.dioClient(
        withAuthFeature: true,
        withAppleSignIn: true,
      );
      expect(dio, contains('ApiConstants.authPasswordForgot,'));
      expect(dio, contains('ApiConstants.authApple,'));
    });

    test('an older ApiConstants gets the literal paths instead', () {
      final source = CoreTemplates.inlineMissingEndpoints(
        stacks.first.authRemoteDatasource(),
        {
          'authLogin',
          'authRegister',
          'authRefresh',
          'authLogout',
          'authAccount',
        },
      );
      expect(source, contains("'/auth/password/forgot'"));
      expect(source, isNot(contains('ApiConstants.authPasswordForgot')));
    });
  });

  group('Firebase auth', () {
    test('Sign in with Apple, always, through FirebaseAuth', () {
      for (final t in stacks) {
        final datasource = t.firebaseAuthRemoteDatasource();
        expect(datasource, contains('_auth.signInWithProvider(provider)'));
        expect(datasource, isNot(contains('sign_in_with_apple')));
        // App Store review: the Apple grant is revoked with the account.
        expect(
          datasource,
          contains('_auth.revokeTokenWithAuthorizationCode(code)'),
        );
        expect(
          t.firebaseAuthRepository(),
          contains('Future<AuthUserModel> signInWithApple() async {'),
        );
      }
    });

    test('a new account is sent the verification email', () {
      for (final t in stacks) {
        final datasource = t.firebaseAuthRemoteDatasource();
        expect(datasource, contains('await user.sendEmailVerification();'));
        expect(datasource, contains('Future<AuthUserModel?> reloadUser()'));
      }
    });

    test('the state carries emailVerified from the user', () {
      expect(
        const StackTemplates(StateManagement.riverpod).firebaseAuthHolder(),
        contains('emailVerified: user.emailVerified,'),
      );
      expect(
        const StackTemplates(StateManagement.bloc).firebaseAuthState(),
        contains('this.emailVerified = true,'),
      );
    });
  });

  group('the router', () {
    test('routes to the account screens and holds the unverified', () {
      for (final t in stacks) {
        final router = t.appRouter(withAuth: true, withAccountScreens: true);
        expect(router, contains('path: AppRoutes.forgotPassword,'));
        expect(router, contains('path: AppRoutes.verifyEmail,'));
        expect(
          router,
          contains(
            'if (isAuthenticated && !verified && !onVerify) '
            'return AppRoutes.verifyEmail;',
          ),
        );
        expect(router, contains('final signedInHome = verified'));
      }
    });

    test('a project without the screens is left as it was', () {
      for (final t in stacks) {
        final router = t.appRouter(withAuth: true);
        expect(router, isNot(contains('verifyEmail')));
        expect(router, isNot(contains('{{')));
        expect(router, contains('return from ?? AppRoutes.home;'));
      }
    });
  });

  group('entitlements', () {
    test('Apple sign-in and push each add only their own key', () {
      final apple = IosTemplates.runnerEntitlements(
        withPush: false,
        withAppleSignIn: true,
      );
      expect(apple, contains('com.apple.developer.applesignin'));
      expect(apple, isNot(contains('aps-environment')));

      final push = IosTemplates.runnerEntitlements();
      expect(push, contains('aps-environment'));
      expect(push, isNot(contains('applesignin')));

      expect(
        IosTemplates.runnerProfileEntitlements(
          withPush: false,
          withAppleSignIn: true,
        ),
        contains('<string>Default</string>'),
      );
    });
  });
}
