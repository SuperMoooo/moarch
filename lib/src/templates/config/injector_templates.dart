import '../../utils/injector_utils.dart';
import '../../utils/state_management.dart';

/// The `lib/config/di/` service locator, for both stacks.
///
/// Dependency injection is get_it's job whichever stack the project took:
/// clients, services, datasources and repositories are all
/// constructed once and handed out by type, and none of that has anything to
/// do with how state is held.
///
/// What differs is only what a *state holder* is. On bloc it is a `Bloc` or a
/// `Cubit`, so it is registered here like anything else — in
/// `presentation_module.dart`. On Riverpod it is a `Notifier` that needs a
/// `Ref` Riverpod owns, so it stays behind its provider and reaches in here
/// for what it depends on, and the project has no presentation module at all.
///
/// The registrations are split one file per layer, mirroring `lib/` itself:
///
/// - `injector.dart` — [injector]: `getIt` and `setupInjector()`, and nothing
///   else, so it is the same length in a one-feature app and a fifty-feature
///   one.
/// - `external_module.dart` — [externalModule]: Dio, Firebase, storage.
/// - `core_module.dart` — [coreModule]: the services under `lib/core`.
/// - `data_module.dart` — [dataModule]: datasources and repositories.
///   `create feature` writes here.
/// - `presentation_module.dart` — [presentationModule]: blocs. Bloc projects
///   only; `create feature` and `create bloc` write here.
///
/// [singleFileInjector] is the pre-split layout, kept for projects generated
/// before the split so `moarch update` refreshes them as what they are.
abstract final class InjectorTemplates {
  /// The root `lib/config/di/injector.dart`: `getIt`, and `setupInjector()`
  /// calling one registrar per layer.
  ///
  /// Takes no options — which layer holds what varies, but that the layers
  /// exist does not. The one thing [stateManagement] decides is whether there
  /// is a presentation module to call.
  ///
  /// [withFeatureModule] calls `registerFeatureServices()` from
  /// `feature_module.dart`. Read off disk: a project from before 9.0.0 has no
  /// such file, and refreshing its root must not start calling one.
  static String injector({
    required StateManagement stateManagement,
    bool withFeatureModule = false,
  }) {
    final isBloc = stateManagement.isBloc;

    final imports = <String>[
      "import 'package:get_it/get_it.dart';",
      '',
      "import 'core_module.dart';",
      "import 'data_module.dart';",
      "import 'external_module.dart';",
      if (withFeatureModule) "import 'feature_module.dart';",
      if (isBloc) "import 'presentation_module.dart';",
    ].join('\n');

    final layers = <String>[
      '/// - `external_module.dart` — Dio, Firebase, secure storage.',
      '/// - `core_module.dart` — the services under `lib/core`.',
      '/// - `data_module.dart` — datasources and repositories.',
      if (withFeatureModule)
        '/// - `feature_module.dart` — long-lived services a feature owns.',
      if (isBloc) '/// - `presentation_module.dart` — blocs.',
    ].join('\n');

    // What the reader most needs to know about the layout, which is not the
    // same thing in the two stacks.
    final holderNote = isBloc
        ? '''
/// Feature blocs are factories (one per screen); session-wide ones are
/// singletons.'''
        : '''
/// Notifiers are not registered here: they read their dependencies with
/// `getIt<OrdersRepository>()`.''';

    return '''
$imports

/// The service locator. Registrations live in one file per layer:
///
$layers
///
$holderNote
final getIt = GetIt.instance;

/// Called from `main()` before `runApp`. In tests, `getIt.reset()` and
/// register fakes instead.
Future<void> setupInjector() async {
  registerExternals();
  registerCoreServices();
  registerDataLayer();${withFeatureModule ? '\n  registerFeatureServices();' : ''}${isBloc ? '\n  registerBlocs();' : ''}

  // Needed once you register an async singleton.
  await getIt.allReady();
}
''';
  }

  /// `lib/config/di/external_module.dart` — the third-party instances the
  /// rest of the app is built on.
  static String externalModule({
    bool withDio = false,
    bool withFirestore = false,
    bool withFirebaseAuth = false,
    bool withAuthFeature = false,
    bool withFirebaseAuthFeature = false,
  }) {
    final imports = <String>[
      if (withFirestore)
        "import 'package:cloud_firestore/cloud_firestore.dart';",
      if (withDio) "import 'package:dio/dio.dart';",
      if (withFirebaseAuth)
        "import 'package:firebase_auth/firebase_auth.dart';",
      "import 'package:flutter_secure_storage/flutter_secure_storage.dart';",
      if (withFirebaseAuthFeature)
        "import 'package:google_sign_in/google_sign_in.dart';",
      '',
      if (withDio) "import '../../core/network/dio_client.dart';",
      "import '../../core/security/secure_storage.dart';",
      if (withDio && withAuthFeature && !withFirebaseAuthFeature)
        "import '../../features/auth/domain/repositories/auth_repository.dart';",
      "import 'injector.dart';",
    ].join('\n');

    final entries = <String>[
      if (withFirebaseAuth)
        '''
    ..registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance)''',
      if (withFirestore)
        '    ..registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance)',
      if (withFirebaseAuthFeature)
        '    ..registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance)',
      '    ..registerLazySingleton<FlutterSecureStorage>(\n        () => const FlutterSecureStorage())',
      '    ..registerLazySingleton<TokenStorage>(\n        () => TokenStorage(getIt<FlutterSecureStorage>()))',
      if (withDio && withAuthFeature && !withFirebaseAuthFeature)
        '''
    // One client for the whole app, so the auth interceptor sees every call.
    ..registerLazySingleton<Dio>(
      () => buildDioClient(
        getIt<TokenStorage>(),
        // Resolved on a 401, not now: the repository is built on this client.
        refreshSession: () => getIt<AuthRepository>().refresh(),
      ),
    )'''
      else if (withDio)
        '''
    // One client for the whole app, so the auth interceptor sees every call.
    ..registerLazySingleton<Dio>(() => buildDioClient(getIt<TokenStorage>()))''',
    ];

    return '''
$imports

/// Third-party instances: the HTTP client, Firebase, the keystore.
void registerExternals() {
  getIt
${entries.join('\n')};
}
''';
  }

  /// `lib/config/di/core_module.dart` — the services under `lib/core`.
  static String coreModule({
    bool withMedia = false,
    bool withUrlLauncher = false,
    bool withNotifications = false,
    bool withFirebaseNotifications = false,
    bool withDebouncer = false,
    bool withBiometric = false,
    bool withConnectivity = false,
    bool withAppLifecycle = false,
    bool withPreferences = false,
  }) {
    final imports = <String>[
      if (withBiometric) "import '../../core/security/biometric_service.dart';",
      if (withAppLifecycle)
        "import '../../core/services/app_lifecycle_service.dart';",
      if (withConnectivity)
        "import '../../core/services/connectivity_service.dart';",
      if (withDebouncer) "import '../../core/services/debouncer_service.dart';",
      if (withFirebaseNotifications)
        "import '../../core/services/firebase_notifications_service.dart';",
      if (withMedia) "import '../../core/services/media_service.dart';",
      if (withNotifications)
        "import '../../core/services/notifications_service.dart';",
      "import '../../core/services/permission_service.dart';",
      if (withPreferences)
        "import '../../core/services/preferences_service.dart';",
      if (withUrlLauncher)
        "import '../../core/services/url_launcher_service.dart';",
      "import 'injector.dart';",
    ].join('\n');

    final entries = <String>[
      '    ..registerLazySingleton<PermissionService>(PermissionService.new)',
      if (withPreferences) _preferencesEntry,
      if (withMedia)
        '    ..registerLazySingleton<MediaService>(\n        () => MediaService(getIt<PermissionService>()))',
      if (withUrlLauncher)
        '    ..registerLazySingleton<UrlLauncherService>(UrlLauncherService.new)',
      if (withNotifications)
        '    ..registerLazySingleton<NotificationService>(NotificationService.new)',
      if (withFirebaseNotifications)
        '    ..registerLazySingleton<FirebaseNotificationsService>(\n        FirebaseNotificationsService.new)',
      if (withDebouncer)
        '    ..registerFactory<DebouncerService>(DebouncerService.new)',
      if (withBiometric)
        '    ..registerLazySingleton<BiometricService>(BiometricService.new)',
      if (withConnectivity)
        '    ..registerLazySingleton<ConnectivityService>(ConnectivityService.new)',
      if (withAppLifecycle)
        '    ..registerLazySingleton<AppLifecycleService>(\n'
            '        AppLifecycleService.new,\n'
            '        dispose: (service) => service.dispose())',
    ];

    return '''
$imports

/// The app's cross-cutting services, under `lib/core`.
void registerCoreServices() {
  getIt
${entries.join('\n')};
}
''';
  }

  /// [PreferencesService] is the one async registration: it reads the stored
  /// values once, and `setupInjector()` waits for that through `allReady()`.
  static const String _preferencesEntry =
      '    // Async: loaded before runApp, so the first frame has saved values.\n'
      '    ..registerSingletonAsync<PreferencesService>(PreferencesService.create)';

  /// `lib/config/di/feature_module.dart` — the long-lived services a feature
  /// owns, and the scope helpers for what only one flow owns.
  ///
  /// Generated empty of registrations: which features hold a socket or an
  /// engine is the app's business. It exists so that there is a place for them
  /// that is not `core_module.dart` — a chat socket is not cross-cutting, it
  /// belongs to chat — and not `data_module.dart`, which is repositories.
  static String featureModule() => r'''
import 'package:get_it/get_it.dart';

import 'injector.dart';

/// Long-lived services owned by one feature (a chat socket, a sync worker),
/// from `lib/features/<feature>/data/services/`. Give anything holding a
/// connection a `dispose`:
///
/// ```dart
/// getIt.registerLazySingleton<ChatSocket>(
///   () => ChatSocket(getIt<TokenStorage>()),
///   dispose: (socket) => socket.close(),
/// );
/// ```
void registerFeatureServices() {
  // Nothing yet — register a feature's long-lived services here.
}

// ── Scopes ────────────────────────────────────────────────────────────────────
// For what one flow owns (a call's audio engine, a checkout's cart): opened
// when the flow starts, shared by its screens, disposed when it ends.
//
//   openScope('call', (scope) {
//     scope.registerSingleton<CallEngine>(
//       CallEngine(),
//       dispose: (engine) => engine.release(),
//     );
//   });
//
//   await closeScope('call');

/// Opens the scope [name] with what [init] registers. No-op if already open.
void openScope(String name, void Function(GetIt scope) init) {
  if (getIt.hasScope(name)) return;
  getIt.pushNewScope(scopeName: name, init: init);
}

/// Drops the scope [name] and disposes what is in it. No-op if not open.
Future<void> closeScope(String name) async {
  if (!getIt.hasScope(name)) return;
  await getIt.dropScope(name);
}
''';

  /// `lib/config/di/data_module.dart` — datasources and repositories.
  ///
  /// This is where `moarch create feature` writes, so it carries the anchor
  /// even in a project with no feature yet.
  static String dataModule({
    bool withDio = false,
    bool withFirestore = false,
    bool withAuthFeature = false,
    bool withFirebaseAuthFeature = false,
    bool withFirebaseNotifications = false,
  }) {
    // Every `getIt<T>()` below needs T in scope, so the imports follow what
    // the auth registrations actually name rather than what the project has.
    final imports = <String>[
      if (withAuthFeature && withFirebaseAuthFeature && withFirestore)
        "import 'package:cloud_firestore/cloud_firestore.dart';",
      if (withAuthFeature && !withFirebaseAuthFeature && withDio)
        "import 'package:dio/dio.dart';",
      if (withAuthFeature && withFirebaseAuthFeature) ...[
        "import 'package:firebase_auth/firebase_auth.dart';",
        "import 'package:google_sign_in/google_sign_in.dart';",
      ],
      '',
      if (withAuthFeature && !withFirebaseAuthFeature)
        "import '../../core/security/secure_storage.dart';",
      if (withAuthFeature && withFirebaseNotifications)
        "import '../../core/services/firebase_notifications_service.dart';",
      if (withAuthFeature) ...[
        "import '../../features/auth/data/datasources/auth_remote_datasource.dart';",
        "import '../../features/auth/data/repositories/auth_repository_impl.dart';",
        "import '../../features/auth/domain/repositories/auth_repository.dart';",
      ],
      "import 'injector.dart';",
    ].join('\n');

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

    final entries = <String>[
      if (withAuthFeature) ...[authDatasource, authRepository],
    ];

    return '''
$imports

/// Each feature's datasources and repositories, as lazy singletons.
void registerDataLayer() {
${_body(entries, _dataAnchor)}}
''';
  }

  /// `lib/config/di/presentation_module.dart` — the blocs.
  ///
  /// Bloc projects only. A Riverpod notifier needs the `Ref` Riverpod owns, so
  /// it lives behind its provider and there is nothing here to hold it.
  static String presentationModule({
    bool withAuthFeature = false,
    bool withLocalization = false,
  }) {
    final imports = <String>[
      if (withLocalization)
        "import '../../core/services/language_service.dart';",
      if (withAuthFeature) ...[
        "import '../../features/auth/domain/repositories/auth_repository.dart';",
        "import '../../features/auth/presentation/blocs/auth_bloc.dart';",
      ],
      "import 'injector.dart';",
    ].join('\n');

    final entries = <String>[
      if (withAuthFeature)
        '''    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(getIt<AuthRepository>()),
    )''',
      if (withLocalization)
        '    ..registerLazySingleton<LanguageCubit>(LanguageCubit.new)',
    ];

    return '''
$imports

/// The blocs. Feature blocs are factories (one per screen); session-wide ones
/// (auth, locale) are singletons.
void registerBlocs() {
${_body(entries, _holderAnchor)}}
''';
  }

  /// A registrar body: the cascade when there is anything to register, then
  /// the [anchor] `moarch create` writes above.
  ///
  /// An empty module is a real state — a project scaffolded without the auth
  /// feature has no data layer yet — and a `getIt` with no cascade after it
  /// would not compile, so the cascade is dropped rather than left empty.
  static String _body(List<String> entries, String anchor) {
    final cascade = entries.isEmpty
        ? ''
        : '  getIt\n${entries.join('\n')};\n\n';
    return '$cascade$anchor\n';
  }

  /// The anchor comment written into `data_module.dart`.
  static const String _dataAnchor =
      '  ${InjectorUtils.anchor} — `moarch create feature` inserts above this\n'
      '  // line. Keep it.';

  /// The anchor comment written into `presentation_module.dart`.
  static const String _holderAnchor =
      '  ${InjectorUtils.anchor} — `moarch create feature` / `create bloc`\n'
      '  // insert above this line. Keep it.';

  /// The pre-split `lib/config/di/injector.dart`: every registration in one
  /// file.
  ///
  /// Kept because projects scaffolded before the split still have it, and
  /// `moarch update injector` has to refresh such a project as what it is
  /// rather than replacing it with a root that calls modules the project does
  /// not have. New projects get [injector] plus the four modules.
  static String singleFileInjector({
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
    ..registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance)''',
      if (withFirestore)
        '    ..registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance)',
      if (withFirebaseAuthFeature)
        '    ..registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance)',
      '    ..registerLazySingleton<FlutterSecureStorage>(\n        () => const FlutterSecureStorage())',
      '    ..registerLazySingleton<TokenStorage>(\n        () => TokenStorage(getIt<FlutterSecureStorage>()))',
      if (withDio && withAuthFeature && !withFirebaseAuthFeature)
        '''
    // One client for the whole app, so the auth interceptor sees every call.
    ..registerLazySingleton<Dio>(
      () => buildDioClient(
        getIt<TokenStorage>(),
        // Resolved on a 401, not now: the repository is built on this client.
        refreshSession: () => getIt<AuthRepository>().refresh(),
      ),
    )'''
      else if (withDio)
        '''
    // One client for the whole app, so the auth interceptor sees every call.
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
/// Feature blocs are factories (one per screen); session-wide ones are
/// singletons.'''
        : '''///
/// Notifiers are not registered here: they read their dependencies with
/// `getIt<OrdersRepository>()`.''';

    return '''
$imports

/// The service locator.
$holderNote
final getIt = GetIt.instance;

/// Called from `main()` before `runApp`. In tests, `getIt.reset()` and
/// register fakes instead.
Future<void> setupInjector() async {
  getIt${section('Externals', externals)}${section('Services', services)}${section('Features', auth)};

  ${InjectorUtils.anchor} — `moarch create feature` inserts above this
  // line. Keep it.

  // Needed once you register an async singleton.
  await getIt.allReady();
}
''';
  }
}
