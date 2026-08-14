/// The flutter_bloc flavor of the app-level templates — the mirror of
/// `templates/riverpod/app_templates.dart`.
///
/// Everything Riverpod got from providers is split in two here: `get_it`
/// resolves dependencies (`lib/config/di/injector.dart`), and `BlocProvider`
/// puts a bloc in the widget tree. The file names, class names and layer
/// boundaries are the same in both stacks, so a project can be read the same
/// way whichever one it took.
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
    bool withAuthFeature = false,
  }) {
    if (withEasyLocalization) withLocalization = false;

    // Crashlytics has always initialized Firebase on its own; Firestore and
    // Firebase Auth need the same call, or the first `getIt` read of a
    // Firebase instance throws "No Firebase App '[DEFAULT]' has been created".
    final needsFirebaseInit = withFirebase || withCrashlytics;

    final localizationImports = withEasyLocalization
        ? "\nimport 'package:easy_localization/easy_localization.dart';\n"
        : withLocalization
            ? "\nimport 'l10n/app_localizations.dart';\nimport 'l10n/l10n.dart';\nimport 'core/services/language_service.dart';\nimport 'package:flutter_localizations/flutter_localizations.dart';\n"
            : '';

    final easyLocalizationInit = withEasyLocalization
        ? '\n  await EasyLocalization.ensureInitialized();\n'
        : '';

    final notificationInit = withNotificationsService
        ? '\n  await getIt<NotificationService>().init();'
        : '';

    // Placed after the Crashlytics block so its unguarded
    // Firebase.initializeApp() runs first; the FCM service only initializes
    // Firebase itself when no one else has.
    final firebaseNotificationInit = withFirebaseNotifications
        ? '\n  await getIt<FirebaseNotificationsService>().init();'
        : '';

    final notificationImport = withNotificationsService
        ? "\nimport 'core/services/notifications_service.dart';"
        : '';

    final firebaseNotificationImport = withFirebaseNotifications
        ? "\nimport 'core/services/firebase_notifications_service.dart';"
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

    final maintenanceImport = withMaintenanceGate
        ? "\nimport 'shared/widgets/maintenance_gate.dart';"
        : '';

    final moAdaptImport =
        withMoAdapt ? "\nimport 'shared/widgets/mo_adapt.dart';" : '';

    // Both halves: the bloc to create, and the event to open it with.
    final authImport = withAuthFeature
        ? "\nimport 'features/auth/presentation/blocs/auth_bloc.dart';"
            "\nimport 'features/auth/presentation/blocs/auth_event.dart';"
        : '';

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

    // The blocs that outlive any one screen. The auth bloc is the reason this
    // exists: the router's redirect reads it, so it has to be above the
    // router, not inside a route. Feature blocs stay in their own routes.
    final appBlocs = <String>[
      if (withAuthFeature)
        '''        BlocProvider<AuthBloc>(
          // ..add(AuthStarted()) here, not in the constructor: a bloc that
          // emits during its own construction has no listener yet.
          create: (_) => getIt<AuthBloc>()..add(const AuthStarted()),
        ),''',
      if (withLocalization)
        '        BlocProvider<LanguageCubit>(create: (_) => getIt<LanguageCubit>()),',
    ];

    final languageWatch = withLocalization
        ? '''
    final locale = context.watch<LanguageCubit>().state.locale;
    //final l10n = AppLocalizations.of(context);
'''
        : withEasyLocalization
            ? '''
    // Translate with 'welcome'.tr()
    // Switch language with context.setLocale(const Locale('pt'));
'''
            : '';

    // MoAdapt is the outermost widget so the entire app — EasyLocalization,
    // the bloc providers, MaterialApp — renders in design-space coordinates.
    const rootWidget = 'const App()';
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
        child: $rootWidget,
      ),
    ),
  );''';
    } else if (withEasyLocalization) {
      runAppCall = '''runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('pt')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: $rootWidget,
    ),
  );''';
    } else if (withMoAdapt) {
      runAppCall = '''runApp(
    const MoAdapt(
      // The frame the UI is designed against; every fixed dimension scales
      // proportionally from it. Tune with scaleMode / minScale / maxScale.
      designSize: Size(412, 924),
      child: App(),
    ),
  );''';
    } else {
      runAppCall = 'runApp($rootWidget);';
    }

    // With nothing app-wide to provide, MultiBlocProvider is a wrapper around
    // nothing — the app widget is the MaterialApp itself.
    final String appBody;
    if (appBlocs.isEmpty) {
      appBody = '''
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
${_materialApp(
        withRouter: withRouter,
        themeConfig: themeConfig,
        localizationConfig: localizationConfig,
        languageWatch: languageWatch,
        maintenanceOpen: maintenanceOpen,
        maintenanceClose: maintenanceClose,
        indent: '    ',
      )}  }
}
''';
    } else {
      appBody = '''
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // Provided above the router so a redirect can read them, and so they
    // survive every route change. Feature blocs belong in their own route.
    return MultiBlocProvider(
      providers: [
${appBlocs.join('\n')}
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
${_materialApp(
        withRouter: withRouter,
        themeConfig: themeConfig,
        localizationConfig: localizationConfig,
        languageWatch: languageWatch,
        maintenanceOpen: maintenanceOpen,
        maintenanceClose: maintenanceClose,
        indent: '    ',
      )}  }
}
''';
    }

    final routerImport =
        withRouter ? "\nimport 'config/router/app_router.dart';" : '';

    return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';$localizationImports$notificationImport$firebaseNotificationImport$firebaseImports
import 'config/di/injector.dart';
import 'core/utils/app_logger.dart';
import 'shared/widgets/error_view.dart';$maintenanceImport$moAdaptImport$authImport
import 'config/theme/app_theme.dart';$routerImport

Future<void> main() async {
  // Preserve the splash before anything else runs.
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
$easyLocalizationInit$firebaseInit
  // Registers every repository, datasource, service and bloc. Firebase is up
  // by this point, so the locator can hand out its instances.
  await setupInjector();
$notificationInit$firebaseNotificationInit

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

$appBody''';
  }

  /// The `MaterialApp` both shapes of `App` return — identical either way, so
  /// it is written once rather than kept in step by hand.
  static String _materialApp({
    required bool withRouter,
    required String themeConfig,
    required String localizationConfig,
    required String languageWatch,
    required String maintenanceOpen,
    required String maintenanceClose,
    required String indent,
  }) {
    final constructor = withRouter ? 'MaterialApp.router' : 'MaterialApp';
    final routerConfig =
        withRouter ? '      routerConfig: appRouter,\n' : '      // TODO: set your home widget\n';

    return '''$languageWatch    return $constructor(
      title: 'App',
$themeConfig
$localizationConfig$routerConfig      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Follow the system font size, capped so it can't break fixed
            // layouts.
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.1),
            alwaysUse24HourFormat: true,
          ),
          child: ${maintenanceOpen}child!$maintenanceClose,
        );
      },
    );
''';
  }

  /// Returns the `lib/config/di/injector.dart` service locator.
  ///
  /// The anchor comments are load-bearing: `moarch create feature` inserts new
  /// registrations directly above them, so a generated feature is wired up
  /// without the developer editing this file.
  static String injector({
    bool withDio = false,
    bool withFirestore = false,
    bool withFirebaseAuth = false,
    bool withAuthFeature = false,
    bool withFirebaseAuthFeature = false,
    bool withMedia = false,
    bool withUrlLauncher = false,
    bool withNotifications = false,
    bool withFirebaseNotifications = false,
    bool withDebouncer = false,
    bool withBiometric = false,
    bool withLocalization = false,
    bool withConnectivity = false,
  }) {
    final imports = <String>[
      if (withFirestore) "import 'package:cloud_firestore/cloud_firestore.dart';",
      if (withDio) "import 'package:dio/dio.dart';",
      if (withFirebaseAuth) "import 'package:firebase_auth/firebase_auth.dart';",
      "import 'package:flutter_secure_storage/flutter_secure_storage.dart';",
      "import 'package:get_it/get_it.dart';",
      if (withFirebaseAuthFeature)
        "import 'package:google_sign_in/google_sign_in.dart';",
      '',
      if (withDio) "import '../../core/network/dio_client.dart';",
      "import '../../core/security/secure_storage.dart';",
      if (withBiometric) "import '../../core/security/biometric_service.dart';",
      if (withConnectivity)
        "import '../../core/services/connectivity_service.dart';",
      if (withDebouncer) "import '../../core/services/debouncer_service.dart';",
      if (withFirebaseNotifications)
        "import '../../core/services/firebase_notifications_service.dart';",
      if (withLocalization)
        "import '../../core/services/language_service.dart';",
      if (withMedia) "import '../../core/services/media_service.dart';",
      if (withNotifications)
        "import '../../core/services/notifications_service.dart';",
      "import '../../core/services/permission_service.dart';",
      if (withUrlLauncher)
        "import '../../core/services/url_launcher_service.dart';",
      if (withAuthFeature) ...[
        "import '../../features/auth/data/datasources/auth_remote_datasource.dart';",
        "import '../../features/auth/data/repositories/auth_repository_impl.dart';",
        "import '../../features/auth/domain/repositories/auth_repository.dart';",
        "import '../../features/auth/presentation/blocs/auth_bloc.dart';",
      ],
    ].join('\n');

    // ── Externals ─────────────────────────────────────────────────────────
    final externals = <String>[
      if (withFirebaseAuth)
        '''
    // Firebase.initializeApp() has already run in main(), so reading
    // `.instance` here is safe.
    ..registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance)''',
      if (withFirestore)
        '    ..registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance)',
      if (withFirebaseAuthFeature)
        '    ..registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance)',
      '    ..registerLazySingleton<FlutterSecureStorage>(\n        () => const FlutterSecureStorage())',
      '    ..registerLazySingleton<TokenStorage>(\n        () => TokenStorage(getIt<FlutterSecureStorage>()))',
      if (withDio)
        '''
    // One client for the whole app: the auth interceptor and the
    // single-flight refresh guard only work if everyone shares it.
    ..registerLazySingleton<Dio>(() => buildDioClient(getIt<TokenStorage>()))''',
    ];

    // ── Services ──────────────────────────────────────────────────────────
    final services = <String>[
      '    ..registerLazySingleton<PermissionService>(PermissionService.new)',
      if (withMedia)
        '    ..registerLazySingleton<MediaService>(\n        () => MediaService(getIt<PermissionService>()))',
      if (withUrlLauncher)
        '    ..registerLazySingleton<UrlLauncherService>(UrlLauncherService.new)',
      if (withNotifications)
        '    ..registerLazySingleton<NotificationService>(NotificationService.new)',
      if (withFirebaseNotifications)
        '    ..registerLazySingleton<FirebaseNotificationsService>(\n        FirebaseNotificationsService.new)',
      if (withDebouncer)
        // Not a singleton: two screens sharing one debouncer would cancel
        // each other's pending action.
        '    ..registerFactory<DebouncerService>(DebouncerService.new)',
      if (withBiometric)
        '    ..registerLazySingleton<BiometricService>(BiometricService.new)',
      if (withConnectivity)
        '    ..registerLazySingleton<ConnectivityService>(ConnectivityService.new)',
    ];

    // ── Auth feature ──────────────────────────────────────────────────────
    final authDatasource = withFirebaseAuthFeature
        ? '''    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(
        getIt<FirebaseAuth>(),
        getIt<GoogleSignIn>(),${withFirestore ? '\n        getIt<FirebaseFirestore>(),' : ''}
      ),
    )'''
        : '''    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(getIt<Dio>()),
    )''';

    final authRepository = withFirebaseAuthFeature
        ? '''    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        getIt<AuthRemoteDataSource>(),${withFirebaseNotifications ? '\n        getIt<FirebaseNotificationsService>(),' : ''}
      ),
    )'''
        : '''    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        getIt<AuthRemoteDataSource>(),
        getIt<TokenStorage>(),${withFirebaseNotifications ? '\n        getIt<FirebaseNotificationsService>(),' : ''}
      ),
    )''';

    final auth = <String>[
      if (withAuthFeature) ...[
        authDatasource,
        authRepository,
        // A singleton, unlike feature blocs: the router's redirect and every
        // screen have to read the same session.
        '''    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(getIt<AuthRepository>()),
    )''',
      ],
      if (withLocalization)
        '    ..registerLazySingleton<LanguageCubit>(LanguageCubit.new)',
    ];

    String section(String heading, List<String> lines) =>
        lines.isEmpty ? '' : '\n    // ── $heading ${'─' * (56 - heading.length)}\n${lines.join('\n')}';

    return '''
$imports

/// The service locator. Everything long-lived is registered in
/// [setupInjector] and pulled out with `getIt<Thing>()`.
///
/// Blocs are the exception worth knowing: a feature bloc is registered as a
/// **factory**, so each screen gets its own and closing the route disposes
/// it. Only session-wide blocs (auth) are singletons.
final getIt = GetIt.instance;

/// Wires the app up. Called from `main()` after `Firebase.initializeApp()`
/// and before `runApp`.
///
/// In a widget test, call `getIt.reset()` first and register fakes for the
/// pieces under test — nothing here reaches for a real service on its own.
Future<void> setupInjector() async {
  getIt${section('Externals', externals)}${section('Services', services)}${section('Features', auth)};

  // moarch:registrations — `moarch create feature` inserts new registrations
  // directly above this line. Move them into the block above if you prefer;
  // only the comment itself has to stay.

  // Everything above is lazy, so nothing has been constructed yet. Await this
  // if you later register an async singleton (registerSingletonAsync).
  await getIt.allReady();
}
''';
  }

  /// Returns the generated appRouter template.
  ///
  /// [withAuth] wires the redirect to the app-wide `AuthBloc` and parks the
  /// router on a splash route until the session is restored, so neither login
  /// nor home flashes on startup.
  static String appRouter({bool withAuth = false}) {
    final imports = withAuth
        ? "import 'package:flutter/material.dart';\n"
            "import 'package:go_router/go_router.dart';\n"
            '\n'
            "import '../../features/auth/presentation/blocs/auth_bloc.dart';\n"
            "import '../../features/auth/presentation/states/auth_state.dart';\n"
            "import '../../features/auth/presentation/views/login_view.dart';\n"
            "import '../../features/auth/presentation/views/register_view.dart';\n"
            "import '../../shared/widgets/loadings/app_loading_data.dart';\n"
            "import '../di/injector.dart';\n"
            "import './app_routes.dart';"
        : "import 'package:flutter/material.dart';\n"
            "import 'package:go_router/go_router.dart';\n"
            '\n'
            "import './app_routes.dart';";

    final options = withAuth
        ? '''  initialLocation: AppRoutes.splash,
  // The bloc is a singleton in the locator, so this is the same instance the
  // MultiBlocProvider in main.dart hands to the widget tree.
  refreshListenable: GoRouterRefreshStream(getIt<AuthBloc>().stream),
  redirect: _redirect,'''
        : '  initialLocation: AppRoutes.home,';

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

String? _redirect(BuildContext context, GoRouterState state) {
  final auth = getIt<AuthBloc>().state;
  final onSplash = state.matchedLocation == AppRoutes.splash;

  // Session restore is still running — hold on splash so nothing flashes.
  // The refreshListenable re-runs this once it completes.
  if (auth is AuthInitial) return onSplash ? null : AppRoutes.splash;

  final isAuthenticated = auth is AuthAuthenticated;
  if (onSplash) return isAuthenticated ? AppRoutes.home : AppRoutes.login;

  final onPublicRoute = AppRoutes.publicRoutes.contains(state.matchedLocation);
  if (!isAuthenticated && !onPublicRoute) return AppRoutes.login;
  if (isAuthenticated && onPublicRoute) return AppRoutes.home;
  return null;
}

/// Bridges a bloc's `Stream` to the `Listenable` GoRouter refreshes on.
///
/// It notifies once up front, because the stream only emits on *changes* —
/// a router built after the first state would otherwise never hear about it.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<Object?> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}'''
        : '';

    final asyncImport = withAuth ? "import 'dart:async';\n\n" : '';

    return '''
$asyncImport$imports

/// Navigate without a BuildContext: `appRouter.go(...)`.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's router. A plain top-level value rather than something resolved
/// from the locator: `MaterialApp.router` needs the same instance for the
/// life of the app, and rebuilding it would drop the navigation stack.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
$options
  debugLogDiagnostics: true,
  routes: [
$authRoutes    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Home — replace me!')),
      ),
    ),

    // A screen with its own bloc creates it here, so closing the route closes
    // the bloc. The locator hands out a new one per call (registerFactory).
    // GoRoute(
    //   path: AppRoutes.orders,
    //   builder: (context, state) => BlocProvider(
    //     create: (_) => getIt<OrdersBloc>()..add(const OrdersStarted()),
    //     child: const OrdersView(),
    //   ),
    // ),

    // Path parameter — build the location with AppRoutes.featureDetailOf(id).
    // GoRoute(
    //   path: AppRoutes.featureDetail,
    //   builder: (context, state) =>
    //       FeatureDetailView(id: state.pathParameters['id']!),
    // ),
  ],
);$authGuard
''';
  }

  /// Returns the Firebase instance registrations note.
  ///
  /// Riverpod puts `FirebaseAuth` / `FirebaseFirestore` behind providers in
  /// `config/firebase/firebase_providers.dart`; the bloc stack registers them
  /// in the locator instead, so this file only documents where they went —
  /// there is nowhere else a reader of the Riverpod layout would look.
  static String firebaseProviders({bool hasAuth = false, bool hasDb = false}) {
    final instances = [
      if (hasAuth) 'FirebaseAuth',
      if (hasDb) 'FirebaseFirestore',
    ];

    return '''
// Firebase instances are registered in the service locator, not here.
//
// See `lib/config/di/injector.dart`:
//
${instances.map((i) => '//   getIt<$i>()').join('\n')}
//
// This file exists so the layout matches the Riverpod flavor of the scaffold.
// Delete it if you have no use for the signpost.
''';
  }

  /// Returns the language cubit — the bloc counterpart of Riverpod's
  /// `languageProvider`.
  static String languageService() => '''
import 'dart:ui';

import 'package:bloc/bloc.dart';

class LanguageState {
  const LanguageState({required this.locale});

  final Locale locale;
}

/// One value and no vocabulary of events, so a Cubit rather than a Bloc.
///
/// The file keeps the name its Riverpod counterpart has, so the two layouts
/// line up — which is the naming rule this waives.
// ignore: prefer_file_naming_conventions
class LanguageCubit extends Cubit<LanguageState> {
  // TODO: load the saved locale (e.g. from secure storage) if you persist it.
  LanguageCubit() : super(const LanguageState(locale: Locale('en')));

  Future<void> changeLanguage(String languageCode) async {
    emit(LanguageState(locale: Locale(languageCode)));
  }
}
''';

  /// Returns the generated dioClient template.
  ///
  /// The same client as the Riverpod flavor with the provider taken off the
  /// front: [buildDioClient] takes the `TokenStorage` the locator holds, and
  /// `injector.dart` registers the result as a lazy singleton.
  static String dioClient() => r'''
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';

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

/// Builds the app's one Dio client. Registered as a lazy singleton in
/// `config/di/injector.dart` — the auth interceptor and the single-flight
/// refresh guard below only work if every call shares the same instance.
Dio buildDioClient(TokenStorage storage) {
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
            // bloc / router redirect can send the user back to login.
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
}
