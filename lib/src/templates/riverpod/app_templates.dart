/// The Riverpod flavor of the app-level templates: the entry point, the
/// shared runAction notifier base, the GoRouter setup and the DI wiring that
/// Riverpod itself provides. `templates/bloc/app_templates.dart` mirrors this
/// class for flutter_bloc + get_it projects.
class AppTemplates {
  AppTemplates._();

  /// Returns the generated mainDart template.
  ///
  /// [withLocalization] (flutter_localizations) and [withEasyLocalization]
  /// are mutually exclusive; if both are set, easy_localization wins.
  static String mainDart({
    bool withRouter = true,
    bool withLocalization = false,
    bool withEasyLocalization = false,
    bool withNotificationsService = false,
    bool withFirebaseNotifications = false,
    bool withCrashlytics = false,
    bool withFirebase = false,
    bool withMaintenanceGate = false,
    bool withMoAdapt = false,
    bool withDarkTheme = false,
  }) {
    if (withEasyLocalization) withLocalization = false;

    // Crashlytics has always initialized Firebase on its own; Firestore and
    // Firebase Auth need the same call, or the first provider read throws
    // "No Firebase App '[DEFAULT]' has been created".
    final needsFirebaseInit = withFirebase || withCrashlytics;

    final localizationImports = withEasyLocalization
        ? "\nimport 'package:easy_localization/easy_localization.dart';\n"
        : withLocalization
            ? "\nimport 'l10n/app_localizations.dart';\nimport 'l10n/l10n.dart';\nimport 'core/services/language_service.dart';\nimport 'package:flutter_localizations/flutter_localizations.dart';\n"
            : '';

    final easyLocalizationInit = withEasyLocalization
        ? '\n  await EasyLocalization.ensureInitialized();\n'
        : '';

    // The services come out of the locator now, so nothing in main() needs a
    // container of its own: one `ProviderScope` over the whole app is all
    // Riverpod is here for.
    const rootScope = 'const ProviderScope(child: App())';

    // MoAdapt is the outermost widget so the entire app — EasyLocalization,
    // provider scopes, MaterialApp — renders in design-space coordinates.
    final String runAppCall;
    if (withEasyLocalization && withMoAdapt) {
      runAppCall = '''runApp(
    MoAdapt(
      // The frame the UI is designed against; every fixed dimension scales
      // proportionally from it. Tune with scaleMode / minScale / maxScale.
      designSize: const Size(412, 924),
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('pt')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: $rootScope,
      ),
    ),
  );''';
    } else if (withEasyLocalization) {
      runAppCall = '''runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('pt')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: $rootScope,
    ),
  );''';
    } else if (withMoAdapt) {
      // The whole tree is const, so the const keyword moves to MoAdapt.
      runAppCall = '''runApp(
    const MoAdapt(
      // The frame the UI is designed against; every fixed dimension scales
      // proportionally from it. Tune with scaleMode / minScale / maxScale.
      designSize: Size(412, 924),
      child: ProviderScope(child: App()),
    ),
  );''';
    } else {
      runAppCall = 'runApp($rootScope);';
    }

    final notificationImport = withNotificationsService
        ? "\nimport 'core/services/notifications_service.dart';"
        : '';

    final firebaseNotificationImport = withFirebaseNotifications
        ? "\nimport 'core/services/firebase_notifications_service.dart';"
        : '';

    final withAnyNotifications =
        withNotificationsService || withFirebaseNotifications;

    // Called after the Firebase block so the FCM service finds an app already
    // there; it only initializes Firebase itself when no one else has.
    final notificationInit =
        withAnyNotifications ? '\n  await _initNotifications();\n' : '';

    final notificationsBootstrap = withAnyNotifications
        ? '''
/// Notifications are not worth blocking the boot on, so a failure is logged
/// and the app carries on without them — better than a throw past runApp()
/// stranding it on the preserved splash.
///
/// Permission is deliberately not asked here: on iOS a first-launch denial can
/// only be undone in Settings, so call `requestPermissions()` once onboarding
/// has explained what the notifications are for.${withFirebaseNotifications ? '\n/// On iOS FCM has no device token to hand out until that ask is accepted.' : ''}
Future<void> _initNotifications() async {
${[
            if (withNotificationsService)
              _guardedInit('NotificationService', 'Notifications'),
            if (withFirebaseNotifications)
              _guardedInit('FirebaseNotificationsService', 'FCM'),
          ].join('\n\n')}
}

'''
        : '';

    final firebaseImports = [
      if (needsFirebaseInit)
        "\nimport 'package:firebase_core/firebase_core.dart';",
      if (withCrashlytics)
        "\nimport 'package:firebase_crashlytics/firebase_crashlytics.dart';",
    ].join();

    // One initializeApp for every Firebase service the project selected. It
    // runs before setupInjector() so the locator can register the instances.
    final firebaseInit = needsFirebaseInit
        ? '''

  // Run `flutterfire configure`, then pass the generated options:
  // Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
  await Firebase.initializeApp();${withCrashlytics ? '''

  // Only report crashes from release builds.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);''' : ''}
'''
        : '';

    final crashlyticsUncaught = withCrashlytics
        ? '\n    FirebaseCrashlytics.instance.recordError(error, st, fatal: true);'
        : '';

    final crashlyticsFlutterError = withCrashlytics
        ? '\n    FirebaseCrashlytics.instance.recordFlutterFatalError(details);'
        : '';

    final localizationConfig = withEasyLocalization
        ? '''
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
'''
        : withLocalization
            ? '''
      locale: locale,
      supportedLocales: L10n.all,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
'''
            : '';

    final localizationWatch = withEasyLocalization
        ? '''
// Translate with 'welcome'.tr()
// Switch language with context.setLocale(const Locale('pt'));
'''
        : withLocalization
            ? '''
final locale = ref.watch(languageProvider).locale;
//final l10n = AppLocalizations.of(context);
'''
            : '';

    final maintenanceImport = withMaintenanceGate
        ? "\nimport 'shared/widgets/maintenance_gate.dart';"
        : '';

    final moAdaptImport =
        withMoAdapt ? "\nimport 'shared/widgets/mo_adapt.dart';" : '';

    // With one palette there is no second ThemeData to hand MaterialApp, and
    // no themeMode worth setting: every mode would resolve to the same theme.
    final themeConfig = withDarkTheme
        ? '''
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,'''
        : '''
      // One brand theme. `moarch create theme --dark` adds the dark half.
      theme: AppTheme.light,''';

    // Inside `builder`, so it wraps the Navigator rather than sitting in a
    // route: a gate below the Navigator could be pushed on top of.
    final maintenanceOpen =
        withMaintenanceGate ? 'MaintenanceGate(child: ' : '';
    final maintenanceClose = withMaintenanceGate ? ')' : '';

    if (withRouter) {
      return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';$localizationImports$notificationImport$firebaseNotificationImport$firebaseImports
import 'config/di/injector.dart';
import 'core/utils/app_logger.dart';
import 'shared/widgets/error_view.dart';$maintenanceImport$moAdaptImport
import 'config/theme/app_theme.dart';
import 'config/router/app_router.dart';

Future<void> main() async {
  // Preserve the splash before anything else runs.
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
$easyLocalizationInit$firebaseInit
  // Installed before the first await that can fail, so nothing on the way to
  // runApp() dies unreported.
  PlatformDispatcher.instance.onError = (error, st) {
    appLogger.e('[Uncaught error]', error: error, stackTrace: st);$crashlyticsUncaught
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    appLogger.e('[Flutter error]', error: details.exception, stackTrace: details.stack);$crashlyticsFlutterError
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const Scaffold(body: ErrorView());
  };

  // Registers every repository, datasource and service. Firebase is up by
  // this point, so the locator can hand out its instances.
  await setupInjector();
$notificationInit
  $runAppCall

  // After runApp, so the native splash gives way to a painted first frame
  // rather than a blank window. Push it later still — into your own async
  // init, or a post-frame callback — if something has to land before the app
  // is on screen.
  FlutterNativeSplash.remove();
}

${notificationsBootstrap}class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    $localizationWatch

    // To reset ALL app state on logout, key a ProviderScope by your session:
    // final sessionKey = ref.watch(
    //   authNotifierProvider.select((s) => s.value?.authenticated ?? ''),
    // );

    return MaterialApp.router(
      title: 'App',
$themeConfig
$localizationConfig      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
                  // Follow the system font size. The cap keeps fixed-height
                  // rows and buttons from breaking; it also overrides an
                  // accessibility setting, so raise it as far as your
                  // layouts survive rather than lowering it.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.3),
                  alwaysUse24HourFormat: true,
                ),
          //   ProviderScope(key: ValueKey(sessionKey), child: child!)
          child: ${maintenanceOpen}child!$maintenanceClose,
        );
      },
    );
  }
}
''';
    }

    return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';$localizationImports$notificationImport$firebaseNotificationImport$firebaseImports
import 'config/di/injector.dart';
import 'core/utils/app_logger.dart';
import 'shared/widgets/error_view.dart';$maintenanceImport$moAdaptImport
import 'config/theme/app_theme.dart';

Future<void> main() async {
  // Preserve the splash before anything else runs.
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
$easyLocalizationInit$firebaseInit
  // Installed before the first await that can fail, so nothing on the way to
  // runApp() dies unreported.
  PlatformDispatcher.instance.onError = (error, st) {
    appLogger.e('[Uncaught error]', error: error, stackTrace: st);$crashlyticsUncaught
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    appLogger.e('[Flutter error]', error: details.exception, stackTrace: details.stack);$crashlyticsFlutterError
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const Scaffold(body: ErrorView());
  };

  // Registers every repository, datasource and service. Firebase is up by
  // this point, so the locator can hand out its instances.
  await setupInjector();
$notificationInit
  $runAppCall

  // After runApp, so the native splash gives way to a painted first frame
  // rather than a blank window. Push it later still — into your own async
  // init, or a post-frame callback — if something has to land before the app
  // is on screen.
  FlutterNativeSplash.remove();
}

${notificationsBootstrap}class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    $localizationWatch

    // To reset ALL app state on logout, key a ProviderScope by your session:
    // final sessionKey = ref.watch(
    //   authNotifierProvider.select((s) => s.value?.authenticated ?? ''),
    // );

    return MaterialApp(
      title: 'App',
$themeConfig
$localizationConfig      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Follow the system font size. The cap keeps fixed-height rows
            // and buttons from breaking; it also overrides an accessibility
            // setting, so raise it as far as your layouts survive rather
            // than lowering it.
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.3),
            alwaysUse24HourFormat: true,
          ),
          //   ProviderScope(key: ValueKey(sessionKey), child: child!)
          child: ${maintenanceOpen}child!$maintenanceClose,
        );
      },
      // TODO: set your home widget
    );
  }
}
''';
  }

  /// One `init()` call wrapped in its own guard, so a plugin that throws only
  /// costs its own service rather than every one after it.
  static String _guardedInit(String type, String scope) => '''  try {
    await getIt<$type>().init();
  } catch (error, stackTrace) {
    appLogger.e(
      '[$scope] init failed',
      error: error,
      stackTrace: stackTrace,
    );
  }''';

  /// Returns the generated actionNotifier template — the shared runAction
  /// helper used by all feature notifiers.
  static String actionNotifier() => r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';

/// Contract for states usable with [ActionNotifierMixin.runAction].
abstract interface class ActionState<T> {
  T copyWithLoading();
  T copyWithError(String message);
}

/// Shared loading/error handling for AsyncNotifier actions.
///
/// ```dart
/// class MyNotifier extends AsyncNotifier<MyState>
///     with ActionNotifierMixin<MyState> {
///   Future<void> doSomething() => runAction((current) async {
///     await getIt<MyRepository>().doSomething();
///     return current.copyWith(success: 'Done!');
///   });
/// }
/// ```
mixin ActionNotifierMixin<S extends ActionState<S>> on AsyncNotifier<S> {
  /// Runs [action] with shared loading/error handling.
  ///
  /// [action] receives the pre-action state — build the next state from that,
  /// not from `state.value`, which carries the loading flag while it runs.
  Future<void> runAction(Future<S> Function(S current) action) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWithLoading());
    try {
      state = AsyncData(await action(current));
    } on AppException catch (e) {
      state = AsyncData(current.copyWithError(e.message));
    } catch (_) {
      state = AsyncData(current.copyWithError('Unknown error'));
    }
  }
}
''';

  /// Returns the generated appRouter template.
  ///
  /// [withAuth] wires the redirect to `authNotifierProvider` and parks the
  /// router on a splash route until the session is restored, so neither login
  /// nor home flashes on startup.
  static String appRouter({bool withAuth = false}) {
    final relativeImports = withAuth
        ? "import '../../features/auth/presentation/notifiers/auth_notifier.dart';\n"
            "import '../../features/auth/presentation/views/login_view.dart';\n"
            "import '../../features/auth/presentation/views/register_view.dart';\n"
            "import '../../shared/widgets/loadings/app_loading_data.dart';\n"
            "import './app_routes.dart';"
        : "import './app_routes.dart';";

    final options = withAuth
        ? '''    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) => _redirect(ref, state),'''
        : '    initialLocation: AppRoutes.home,';

    final authRoutes = withAuth
        ? '''
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const AppLoadingData(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterView(),
      ),
'''
        : '';

    final authGuard = withAuth
        ? r'''


/// Re-runs [_redirect] whenever the auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

String? _redirect(Ref ref, GoRouterState state) {
  final auth = ref.read(authNotifierProvider);
  final onSplash = state.matchedLocation == AppRoutes.splash;

  // Session restore is still running — hold on splash so nothing flashes.
  // The refreshListenable re-runs this once it completes.
  if (auth.isLoading) return onSplash ? null : AppRoutes.splash;

  final isAuthenticated = auth.value?.authenticated ?? false;
  if (onSplash) return isAuthenticated ? AppRoutes.home : AppRoutes.login;

  final onPublicRoute = AppRoutes.publicRoutes.contains(state.matchedLocation);
  if (!isAuthenticated && !onPublicRoute) return AppRoutes.login;
  if (isAuthenticated && onPublicRoute) return AppRoutes.home;
  return null;
}'''
        : '';

    return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

$relativeImports

/// Navigate without a BuildContext: `ref.read(routerProvider).go(...)`.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
$options
    // Debug builds only: the route log is noise in release, and the
    // locations it prints can carry path parameters worth not logging.
    debugLogDiagnostics: kDebugMode,
    routes: [
$authRoutes      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home — replace me!')),
        ),
      ),

      // Path parameter — build the location with AppRoutes.groupDetailOf(id).
      // GoRoute(
      //   path: AppRoutes.groupDetail,
      //   builder: (context, state) =>
      //       GroupDetailView(id: state.pathParameters['id']!),
      // ),

      // Whole object, passed as `extra` instead of through the URL.
      // GoRoute(
      //   path: '/recipe/detail',
      //   builder: (context, state) =>
      //       RecipeDetailView(recipe: state.extra! as RecipeEntity),
      // ),
    ],
  );
});$authGuard
''';
  }

  /// Returns a language service scaffold.
  static String languageService() => '''
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final languageProvider = NotifierProvider<LanguageService, LanguageState>(
  LanguageService.new,
);

class LanguageState {
  const LanguageState({required this.locale});

  final Locale locale;
}

class LanguageService extends Notifier<LanguageState> {
  @override
  LanguageState build() {
    // TODO: load the saved locale (e.g. from secure storage) if you persist it.
    return const LanguageState(locale: Locale('en'));
  }

  Future<void> changeLanguage(String languageCode) async {
    state = LanguageState(locale: Locale(languageCode));
  }
}
''';
}
