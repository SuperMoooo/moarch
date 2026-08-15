import '../../utils/state_management.dart';

/// The `lib/config/di/injector.dart` service locator, for both stacks.
///
/// Dependency injection is get_it's job whichever stack the project took:
/// clients, services, datasources, repositories and use cases are all
/// constructed once and handed out by type, and none of that has anything to
/// do with how state is held.
///
/// What differs is only what a *state holder* is. On bloc it is a `Bloc` or a
/// `Cubit`, so it is registered here like anything else. On Riverpod it is a
/// `Notifier` that needs a `Ref` Riverpod owns, so it stays behind its
/// provider and reaches in here for what it depends on.
abstract final class InjectorTemplates {
  /// Returns the service locator for [stateManagement].
  ///
  /// The anchor comment is load-bearing: `moarch create feature` inserts new
  /// registrations directly above it, so a generated feature is wired up
  /// without the developer editing this file.
  static String injector({
    required StateManagement stateManagement,
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
    final isBloc = stateManagement.isBloc;

    // The state holders are the one thing the locator does not hold on
    // Riverpod: `AuthNotifier` lives behind `authNotifierProvider` and
    // `LanguageService` behind `languageProvider`, both of which need the
    // `Ref` only Riverpod can hand them.
    final withAuthHolder = withAuthFeature && isBloc;
    final withLanguageHolder = withLocalization && isBloc;

    final imports = <String>[
      if (withFirestore)
        "import 'package:cloud_firestore/cloud_firestore.dart';",
      if (withDio) "import 'package:dio/dio.dart';",
      if (withFirebaseAuth)
        "import 'package:firebase_auth/firebase_auth.dart';",
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
      if (withLanguageHolder)
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
        if (withAuthHolder)
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
        if (withAuthHolder)
          // A singleton, unlike feature blocs: the router's redirect and every
          // screen have to read the same session.
          '''    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(getIt<AuthRepository>()),
    )''',
      ],
      if (withLanguageHolder)
        '    ..registerLazySingleton<LanguageCubit>(LanguageCubit.new)',
    ];

    String section(String heading, List<String> lines) => lines.isEmpty
        ? ''
        : '\n    // ── $heading ${'─' * (56 - heading.length)}\n${lines.join('\n')}';

    // What the reader most needs to know about this file, which is not the
    // same thing in the two stacks.
    final holderNote = isBloc
        ? '''///
/// Blocs are the exception worth knowing: a feature bloc is registered as a
/// **factory**, so each screen gets its own and closing the route disposes
/// it. Only session-wide blocs (auth) are singletons.'''
        : '''///
/// Notifiers are not here: an `AsyncNotifier` needs the `Ref` Riverpod hands
/// it, so it stays behind its provider and reads what it depends on out of
/// this locator — `getIt<OrdersRepository>()` rather than
/// `ref.watch(ordersRepositoryProvider)`. Riverpod holds the state; get_it
/// holds everything the state is built from.''';

    return '''
$imports

/// The service locator. Everything long-lived is registered in
/// [setupInjector] and pulled out with `getIt<Thing>()`.
$holderNote
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
}
