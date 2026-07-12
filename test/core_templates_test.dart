import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/ui/feature_templates.dart';
import 'package:moarch/src/templates/ui/modals_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:test/test.dart';

void main() {
  test('mainDart adds notification initialization when requested', () {
    final output = CoreTemplates.mainDart(
      withRouter: false,
      withNotificationsService: true,
    );

    expect(
        output, contains("import 'core/services/notifications_service.dart';"));
    expect(output, contains('await NotificationService.instance.init();'));
  });

  test('mainDart omits notification initialization by default', () {
    final output = CoreTemplates.mainDart(withRouter: false);

    expect(output,
        isNot(contains("import 'core/services/notifications_service.dart';")));
    expect(
        output, isNot(contains('await NotificationService.instance.init();')));
  });

  test('mainDart wires easy_localization when requested', () {
    final output = CoreTemplates.mainDart(
      withRouter: false,
      withEasyLocalization: true,
    );

    expect(output,
        contains("import 'package:easy_localization/easy_localization.dart';"));
    expect(output, contains('await EasyLocalization.ensureInitialized();'));
    expect(output, contains('EasyLocalization('));
    expect(output, contains("path: 'assets/translations'"));
    expect(output, contains('locale: context.locale'));
    expect(output, contains('localizationsDelegates: context.localizationDelegates'));
    // Must not pull in the flutter_localizations wiring.
    expect(output, isNot(contains('flutter_localizations')));
    expect(output, isNot(contains('AppLocalizations.delegate')));
  });

  test('mainDart prefers easy_localization when both localizations are set',
      () {
    final output = CoreTemplates.mainDart(
      withRouter: true,
      withLocalization: true,
      withEasyLocalization: true,
    );

    expect(output, contains('EasyLocalization('));
    expect(output, isNot(contains('flutter_localizations')));
    expect(output, isNot(contains('languageProvider')));
  });

  test('mainDart omits easy_localization by default', () {
    final output = CoreTemplates.mainDart(withRouter: false);

    expect(output, isNot(contains('EasyLocalization')));
    expect(output, contains('runApp(const ProviderScope(child: App()));'));
  });

  test('mainDart adds Firebase notification initialization when requested', () {
    final output = CoreTemplates.mainDart(
      withRouter: false,
      withFirebaseNotifications: true,
    );

    expect(
        output,
        contains(
            "import 'core/services/firebase_notifications_service.dart';"));
    expect(output,
        contains('await FirebaseNotificationsService.instance.init();'));
  });

  test('mainDart omits Firebase notification initialization by default', () {
    final output = CoreTemplates.mainDart(withRouter: false);

    expect(
        output,
        isNot(contains(
            "import 'core/services/firebase_notifications_service.dart';")));
    expect(output,
        isNot(contains('await FirebaseNotificationsService.instance.init();')));
  });

  test('mainDart wires Crashlytics into error handlers when requested', () {
    final output = CoreTemplates.mainDart(
      withRouter: false,
      withCrashlytics: true,
    );

    expect(
        output,
        contains(
            "import 'package:firebase_crashlytics/firebase_crashlytics.dart';"));
    expect(output, contains('await Firebase.initializeApp();'));
    expect(
        output,
        contains(
            'FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);'));
    expect(
        output,
        contains(
            'FirebaseCrashlytics.instance.recordError(error, st, fatal: true);'));
    expect(
        output,
        contains(
            'FirebaseCrashlytics.instance.recordFlutterFatalError(details);'));
  });

  test('mainDart omits Crashlytics by default', () {
    final output = CoreTemplates.mainDart(withRouter: false);

    expect(output, isNot(contains('FirebaseCrashlytics')));
    expect(output, isNot(contains('Firebase.initializeApp')));
  });

  test('appException records to Crashlytics when requested', () {
    final output = ErrorTemplates.appException(
      hasDio: true,
      hasFirebase: true,
      hasCrashlytics: true,
    );

    expect(
        output,
        contains(
            "import 'package:firebase_crashlytics/firebase_crashlytics.dart';"));
    expect(
        output,
        contains(
            'FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);'));
    expect(
        output,
        contains(
            'FirebaseCrashlytics.instance.recordError(dioError, dioError.stackTrace, reason: message);'));
    expect(
        output,
        contains(
            'FirebaseCrashlytics.instance.recordError(error, error.stackTrace, reason: message);'));
  });

  test('appException omits Crashlytics by default', () {
    final output = ErrorTemplates.appException(hasDio: true, hasFirebase: true);

    expect(output, isNot(contains('FirebaseCrashlytics')));
  });

  test('generated modals use the interface expected for testability', () {
    final output = ModalsTemplates.appBottomModals();

    expect(output, contains('implements IAppBottomModals'));
  });

  test('generated feature templates favor the safe API flow in datasource', () {
    final output =
        FeatureTemplates.remoteDatasource('sample', 'Sample', 'sample');

    expect(output, contains('safeApiCall<'));
    expect(output, contains('apiCall: () async'));
  });

  test('shared templates expose empty and success states', () {
    expect(SharedTemplates.emptyView(), contains('class EmptyView'));
  });
}
