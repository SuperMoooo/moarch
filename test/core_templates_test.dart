import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/error_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/riverpod/feature_templates.dart';
import 'package:moarch/src/templates/ui/modals_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/templates/riverpod/app_templates.dart' as riverpod;
import 'package:test/test.dart';

void main() {
  test('mainDart adds notification initialization when requested', () {
    final output = riverpod.AppTemplates.mainDart(
      withRouter: false,
      withNotificationsService: true,
    );

    expect(
        output, contains("import 'core/services/notifications_service.dart';"));
    // Out of the locator, so main() needs no container of its own — one
    // ProviderScope over the app is all Riverpod is here for.
    expect(output, contains('await getIt<NotificationService>().init();'));
    expect(output, contains('await setupInjector();'));
    expect(output, isNot(contains('ProviderContainer')));
    expect(output, contains('const ProviderScope(child: App())'));
    // Guarded: a plugin that throws must not strand the app on the splash.
    expect(output, contains('await _initNotifications();'));
    expect(output, contains('} catch (error, stackTrace) {'));
  });

  test('the notification permission is left for the app to ask', () {
    final output = ServicesTemplates.notificationsService();

    // On iOS a first-launch denial can only be undone in Settings, so init()
    // sets the plugin up and nothing more.
    expect(output, contains('Future<void> init() async {'));
    expect(output, isNot(contains('await requestPermissions();')));
    expect(output, contains('Future<bool> requestPermissions() async {'));
  });

  test('mainDart omits notification initialization by default', () {
    final output = riverpod.AppTemplates.mainDart(withRouter: false);

    expect(output,
        isNot(contains("import 'core/services/notifications_service.dart';")));
    expect(output, isNot(contains('getIt<NotificationService>()')));
    expect(output, isNot(contains('ProviderContainer')));
  });

  test('mainDart wires easy_localization when requested', () {
    final output = riverpod.AppTemplates.mainDart(
      withRouter: false,
      withEasyLocalization: true,
    );

    expect(output,
        contains("import 'package:easy_localization/easy_localization.dart';"));
    expect(output, contains('await EasyLocalization.ensureInitialized();'));
    expect(output, contains('EasyLocalization('));
    expect(output, contains("path: 'assets/translations'"));
    expect(output, contains('locale: context.locale'));
    expect(output,
        contains('localizationsDelegates: context.localizationDelegates'));
    // Must not pull in the flutter_localizations wiring.
    expect(output, isNot(contains('flutter_localizations')));
    expect(output, isNot(contains('AppLocalizations.delegate')));
  });

  test('mainDart prefers easy_localization when both localizations are set',
      () {
    final output = riverpod.AppTemplates.mainDart(
      withRouter: true,
      withLocalization: true,
      withEasyLocalization: true,
    );

    expect(output, contains('EasyLocalization('));
    expect(output, isNot(contains('flutter_localizations')));
    expect(output, isNot(contains('languageProvider')));
  });

  test('mainDart omits easy_localization by default', () {
    final output = riverpod.AppTemplates.mainDart(withRouter: false);

    expect(output, isNot(contains('EasyLocalization')));
    expect(output, contains('runApp(const ProviderScope(child: App()));'));
  });

  test('mainDart adds Firebase notification initialization when requested', () {
    final output = riverpod.AppTemplates.mainDart(
      withRouter: false,
      withFirebaseNotifications: true,
    );

    expect(
        output,
        contains(
            "import 'core/services/firebase_notifications_service.dart';"));
    expect(output,
        contains('await getIt<FirebaseNotificationsService>().init();'));
    expect(output, isNot(contains('ProviderContainer')));
    expect(output, contains('const ProviderScope(child: App())'));
  });

  test('mainDart omits Firebase notification initialization by default', () {
    final output = riverpod.AppTemplates.mainDart(withRouter: false);

    expect(
        output,
        isNot(contains(
            "import 'core/services/firebase_notifications_service.dart';")));
    expect(output, isNot(contains('getIt<FirebaseNotificationsService>()')));
  });

  test('mainDart wires Crashlytics into error handlers when requested', () {
    final output = riverpod.AppTemplates.mainDart(
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
    final output = riverpod.AppTemplates.mainDart(withRouter: false);

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

  test('appLogger fronts the logger package with a façade', () {
    final output = CoreTemplates.appLogger();

    // Call sites bind to AppLogger, so the backend stays swappable.
    expect(output, contains('final appLogger = AppLogger._();'));
    expect(output,
        contains('AppLogger scoped(String name) => AppLogger._(name);'));
    for (final method in ['t', 'd', 'i', 'w', 'e']) {
      expect(
        output,
        contains(
            'void $method(String message, {Object? error, StackTrace? stackTrace})'),
      );
    }
    // The package's own Logger is private to this file.
    expect(output, contains('final _logger = Logger('));
  });

  test('appLogger redacts credentials at the sink', () {
    final output = CoreTemplates.appLogger();

    expect(output, contains('String _redact(String message)'));
    expect(output, contains('accessToken'));
    expect(output, contains("'Bearer ***REDACTED***'"));
    // Applied by the output, not left to call sites.
    expect(output, contains("_redact(event.lines.join('\\n'))"));
  });

  test('appLogger keeps warnings and errors in release builds', () {
    final output = CoreTemplates.appLogger();

    expect(
        output, contains('level: kReleaseMode ? Level.warning : Level.trace'));
  });

  test('appLogger mirrors into Crashlytics when requested', () {
    final output = CoreTemplates.appLogger(withCrashlytics: true);

    expect(
        output,
        contains(
            "import 'package:firebase_crashlytics/firebase_crashlytics.dart';"));
    expect(
        output, contains("import 'package:firebase_core/firebase_core.dart';"));
    expect(output, contains('_CrashlyticsOutput(),'));
    expect(
      output,
      contains('FirebaseCrashlytics.instance.log('),
    );
    // Services log during start-up, before main() initializes Firebase.
    expect(output, contains('if (Firebase.apps.isEmpty) return;'));
  });

  test('appLogger omits Crashlytics by default', () {
    final output = CoreTemplates.appLogger();

    expect(output, isNot(contains('FirebaseCrashlytics')));
    expect(output, isNot(contains('firebase_core')));
    expect(output, contains('final _sinks = <LogOutput>[_DeveloperOutput()];'));
  });

  test('dioClient leaves redaction to the logger', () {
    final output = CoreTemplates.dioClient();

    expect(output, contains("final _log = appLogger.scoped('Dio');"));
    // The interceptor hands over raw bodies; app_logger.dart scrubs them.
    expect(output, isNot(contains('_redactSensitive')));
    expect(output, contains('logPrint: (msg) => _log.d(msg.toString()),'));
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

  test('the paginated envelope parses leniently and keeps the item key open',
      () {
    final output = CoreTemplates.paginated();

    // The item key is the field most likely to be wrong for any given
    // backend — `results`, `items`, `records` — so it is an argument rather
    // than a literal in the body.
    expect(output, contains("String dataKey = 'data',"));
    expect(output, contains('final raw = json[dataKey];'));

    // An unguarded `json['page'] as int` turns a stringified count into a
    // TypeError that safeApiCall reports as an unknown failure. Counts are
    // read through _asInt and fall back rather than throw.
    expect(output, isNot(contains("as int")));
    expect(output, contains("page: _asInt(json['page']) ?? 1,"));
    expect(output, contains('final String v => int.tryParse(v),'));
    // A null or absent list is an empty page, not a cast failure.
    expect(
        output, contains('raw is List ? raw.map(fromJsonT).toList() : <T>[]'));
  });

  test('the paginated envelope carries the members its callers need', () {
    final output = CoreTemplates.paginated();

    // `Object?` rather than Map, so a page of scalars uses the same factory.
    expect(output, contains('T Function(Object? json) fromJsonT,'));
    // Dividing by a missing page size must not loop a load-more forever.
    expect(
        output,
        contains(
            'int get pageCount => limit <= 0 ? 1 : (total / limit).ceil();'));
    expect(output, contains('bool get hasMore => page < pageCount;'));
    // The two members the Clean Architecture boundary is here for.
    expect(output, contains('Paginated<R> map<R>(R Function(T item) toItem)'));
    expect(output, contains('Paginated<T> append(Paginated<T> next)'));
    expect(output, contains('items: [...items, ...next.items],'));
  });
}
