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

    // The notification services are Riverpod providers that hold a `Ref`, so
    // they must be initialized through a container that also backs the widget
    // tree. When either is enabled we build that container in main() and hand
    // it to an UncontrolledProviderScope.
    final needsContainer =
        withNotificationsService || withFirebaseNotifications;

    final rootScope = needsContainer
        ? 'UncontrolledProviderScope(container: container, child: const App())'
        : 'const ProviderScope(child: App())';

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
      // With a plain ProviderScope the whole tree is const, so the const
      // keyword moves to MoAdapt; with a container it cannot be const at all.
      runAppCall = needsContainer
          ? '''runApp(
    MoAdapt(
      // The frame the UI is designed against; every fixed dimension scales
      // proportionally from it. Tune with scaleMode / minScale / maxScale.
      designSize: const Size(412, 924),
      child: $rootScope,
    ),
  );'''
          : '''runApp(
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

    final containerSetup =
        needsContainer ? '\n  final container = ProviderContainer();\n' : '';

    final notificationImport = withNotificationsService
        ? "\nimport 'core/services/notifications_service.dart';"
        : '';

    final notificationInit = withNotificationsService
        ? '\n  await container.read(notificationServiceProvider).init();'
        : '';

    final firebaseNotificationImport = withFirebaseNotifications
        ? "\nimport 'core/services/firebase_notifications_service.dart';"
        : '';

    // Placed after the Crashlytics block so its unguarded
    // Firebase.initializeApp() runs first; the FCM service only initializes
    // Firebase itself when no one else has.
    final firebaseNotificationInit = withFirebaseNotifications
        ? '\n  await container.read(firebaseNotificationsServiceProvider).init();'
        : '';

    final firebaseImports = [
      if (needsFirebaseInit)
        "\nimport 'package:firebase_core/firebase_core.dart';",
      if (withCrashlytics)
        "\nimport 'package:firebase_crashlytics/firebase_crashlytics.dart';",
    ].join();

    // One initializeApp for every Firebase service the project selected.
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
import 'core/utils/app_logger.dart';
import 'shared/widgets/error_view.dart';$maintenanceImport$moAdaptImport
import 'config/theme/app_theme.dart';
import 'config/router/app_router.dart';

Future<void> main() async {
  // Preserve the splash before anything else runs.
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
$easyLocalizationInit$containerSetup$notificationInit
$firebaseInit$firebaseNotificationInit
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

  // Move this after your own async init if you have any.
  FlutterNativeSplash.remove();

  $runAppCall
}

class App extends ConsumerWidget {
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
                  // Follow the system font size, capped so it can't break
                  // fixed layouts.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.1),
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
import 'core/utils/app_logger.dart';
import 'shared/widgets/error_view.dart';$maintenanceImport$moAdaptImport
import 'config/theme/app_theme.dart';

Future<void> main() async {
  // Preserve the splash before anything else runs.
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
$easyLocalizationInit$containerSetup$notificationInit
$firebaseInit$firebaseNotificationInit
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

  // Move this after your own async init if you have any.
  FlutterNativeSplash.remove();

  $runAppCall
}

class App extends ConsumerWidget {
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
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.1),
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
///     await ref.read(myRepositoryProvider).doSomething();
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
    debugLogDiagnostics: true,
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

  /// Returns the generated firebaseProviders template.
  static String firebaseProviders({bool hasAuth = false, bool hasDb = false}) {
    final imports = [
      if (hasDb) "import 'package:cloud_firestore/cloud_firestore.dart';",
      if (hasAuth) "import 'package:firebase_auth/firebase_auth.dart';",
      "import 'package:flutter_riverpod/flutter_riverpod.dart';",
    ].join('\n');

    final providers = [
      if (hasAuth)
        'final firebaseAuthProvider = Provider((ref) => FirebaseAuth.instance);',
      if (hasDb)
        'final firebaseDbProvider = Provider((ref) => FirebaseFirestore.instance);',
    ].join('\n\n');

    return '''
$imports

$providers
''';
  }

  /// Returns the generated dioClient template.
  ///
  /// The client is a `Provider<Dio>` reading `tokenStorageProvider`; the bloc
  /// flavor builds the same client from a `TokenStorage` argument instead.
  static String dioClient() => r'''
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../config/env/app_env.dart';
import '../constants/api_constants.dart';
import '../security/secure_storage.dart';
import '../utils/app_logger.dart';

final _log = appLogger.scoped('Dio');

const _kPublicEndpoints = <String>[
  // Routes that never receive the Authorization header (and are never
  // retried after a token refresh). Adjust to your API contract.
  '/auth/login',
  '/auth/register',
  '/auth/refresh',
];

bool _isPublicPath(String path) {
  final cleanPath = path.split('?').first;
  return _kPublicEndpoints.any(
    (endpoint) => cleanPath == endpoint || cleanPath.startsWith('$endpoint/'),
  );
}

final dioClientProvider = Provider<Dio>((ref) => _buildDioClient(ref));

Dio _buildDioClient(Ref ref) {
  final storage = ref.watch(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppEnv.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  _configureHttpClient(dio);

  dio
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isPublicEndpoint = _isPublicPath(options.path);
          if (!isPublicEndpoint) {
            final token = await storage.accessToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final alreadyRetried =
              error.requestOptions.extra[_kRetriedAfterRefresh] == true;
          if (status != 401 ||
              alreadyRetried ||
              _isPublicPath(error.requestOptions.path)) {
            return handler.next(error);
          }

          // Session expired — refresh the access token, then retry once.
          final refreshed = await _refreshSession(storage);
          if (!refreshed) {
            // Refresh token missing/expired: clear the session so the auth
            // notifier / router redirect can send the user back to login.
            await storage.clearSession();
            return handler.next(error);
          }

          try {
            final options = error.requestOptions
              ..extra[_kRetriedAfterRefresh] = true;
            // Re-entering the chain lets onRequest attach the new token.
            final response = await dio.fetch<dynamic>(options);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
      ),
    )
    ..interceptors.add(
      RetryInterceptor(dio: dio, logPrint: (msg) => _log.d(msg.toString())),
    )
    // Bodies and headers are safe to hand over whole: app_logger.dart redacts
    // credentials at the sink, so nothing here has to remember to.
    ..interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (msg) => _log.d(msg.toString()),
      ),
    );

  return dio;
}

const _kRetriedAfterRefresh = '__retried_after_refresh__';

/// Single-flight guard: concurrent 401s share one refresh call instead of
/// racing each other with the same refresh token.
Future<bool>? _ongoingRefresh;

Future<bool> _refreshSession(TokenStorage storage) {
  return _ongoingRefresh ??= _doRefresh(storage).whenComplete(() {
    _ongoingRefresh = null;
  });
}

Future<bool> _doRefresh(TokenStorage storage) async {
  final refreshToken = await storage.refreshToken;
  if (refreshToken == null) return false;
  try {
    // Bare client (no interceptors), so a failing refresh can't loop back
    // into the 401 handler above.
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: AppEnv.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _configureHttpClient(refreshDio);
    final response = await refreshDio.post<dynamic>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data as Map<String, dynamic>;
    // Adjust the keys to your API contract. Backends that don't rotate the
    // refresh token only return a new access token.
    final newAccessToken = data['accessToken'] as String?;
    final newRefreshToken = data['refreshToken'] as String? ?? refreshToken;
    if (newAccessToken == null) return false;
    await storage.saveSession(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );
    return true;
  } catch (error) {
    _log.w('Session refresh failed', error: error);
    return false;
  }
}

void _configureHttpClient(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      if (kDebugMode) {
        client.badCertificateCallback = (cert, host, port) {
          _log.w(
            'Certificate verification skipped for $host (debug mode)',
          );
          return true;
        };
      }
      return client;
    },
  );
}

''';

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
