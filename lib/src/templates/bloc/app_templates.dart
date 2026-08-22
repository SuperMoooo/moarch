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
          // Built with the tree rather than on first read: the router's
          // redirect reads the bloc out of the locator, so nothing would ever
          // touch this provider and session restore would never start.
          lazy: false,
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

  // Registers every repository, datasource, service and bloc. Firebase is up
  // by this point, so the locator can hand out its instances.
  await setupInjector();
$notificationInit
  $runAppCall

  // After runApp, so the native splash gives way to a painted first frame
  // rather than a blank window. Push it later still — into your own async
  // init, or a post-frame callback — if something has to land before the app
  // is on screen.
  FlutterNativeSplash.remove();
}

$notificationsBootstrap$appBody''';
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
    final routerConfig = withRouter
        ? '      routerConfig: appRouter,\n'
        : '      // TODO: set your home widget\n';

    return '''$languageWatch    return $constructor(
      title: 'App',
$themeConfig
$localizationConfig$routerConfig      debugShowCheckedModeBanner: false,
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
          child: ${maintenanceOpen}child!$maintenanceClose,
        );
      },
    );
''';
  }

  /// Returns the generated appRouter template.
  ///
  /// [withAuth] wires the redirect to the app-wide `AuthBloc` and parks the
  /// router on a splash route until the session is restored, so neither login
  /// nor home flashes on startup.
  static String appRouter({bool withAuth = false}) {
    final imports = withAuth
        ? "import 'package:flutter/foundation.dart';\n"
            "import 'package:flutter/material.dart';\n"
            "import 'package:go_router/go_router.dart';\n"
            '\n'
            "import '../../features/auth/presentation/blocs/auth_bloc.dart';\n"
            "import '../../features/auth/presentation/blocs/auth_state.dart';\n"
            "import '../../features/auth/presentation/views/login_view.dart';\n"
            "import '../../features/auth/presentation/views/register_view.dart';\n"
            "import '../../shared/widgets/loadings/app_loading_data.dart';\n"
            "import '../di/injector.dart';\n"
            "import './app_routes.dart';"
        : "import 'package:flutter/foundation.dart';\n"
            "import 'package:flutter/material.dart';\n"
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

  // AuthFailure carries the session it failed from: a delete or a password
  // reset the backend refused leaves the user signed in, and bouncing them to
  // login over it would be a worse lie than the error itself.
  final isAuthenticated =
      auth is AuthAuthenticated || (auth is AuthFailure && auth.authenticated);
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
  // Debug builds only: the route log is noise in release, and the locations
  // it prints can carry path parameters worth not logging.
  debugLogDiagnostics: kDebugMode,
  routes: [
$authRoutes    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Home — replace me!')),
      ),
    ),

    // A screen with its own bloc points at its page, which creates the bloc —
    // so closing the route closes it.
    // GoRoute(
    //   path: AppRoutes.orders,
    //   builder: (context, state) => const OrdersPage(),
    // ),

    // Path parameter — build the location with AppRoutes.featureDetailOf(id).
    // GoRoute(
    //   path: AppRoutes.featureDetail,
    //   builder: (context, state) =>
    //       FeatureDetailPage(id: state.pathParameters['id']!),
    // ),
  ],
);$authGuard
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
}
