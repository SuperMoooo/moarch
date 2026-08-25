import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/templates/riverpod/feature_templates.dart'
    as riverpod;
import 'package:moarch/src/utils/injector_utils.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

void main() {
  group('the locator is one file per layer', () {
    test('injector.dart holds getIt and the calls, and nothing else', () {
      for (final stateManagement in StateManagement.values) {
        final output =
            InjectorTemplates.injector(stateManagement: stateManagement);

        expect(output, contains('final getIt = GetIt.instance;'),
            reason: '$stateManagement');
        expect(output, contains('Future<void> setupInjector() async {'),
            reason: '$stateManagement');
        for (final call in [
          'registerExternals();',
          'registerCoreServices();',
          'registerDataLayer();',
        ]) {
          expect(output, contains(call), reason: '$stateManagement');
        }

        // Nothing is registered here — that is the whole point of the split.
        expect(output, isNot(contains('registerLazySingleton')),
            reason: '$stateManagement');
        expect(output, isNot(contains(InjectorUtils.anchor)),
            reason: '$stateManagement');
      }
    });

    test('the presentation module is bloc\'s alone', () {
      final bloc =
          InjectorTemplates.injector(stateManagement: StateManagement.bloc);
      final riverpodRoot =
          InjectorTemplates.injector(stateManagement: StateManagement.riverpod);

      expect(bloc, contains('registerBlocs();'));
      expect(bloc, contains("import 'presentation_module.dart';"));

      // A notifier needs the Ref Riverpod owns, so there is no module for it
      // and nothing to call.
      expect(riverpodRoot, isNot(contains('registerBlocs')));
      expect(riverpodRoot, isNot(contains('presentation_module.dart')));
      expect(riverpodRoot, contains('There is no presentation module'));
    });

    test('every module resolves getIt from injector.dart', () {
      final modules = [
        InjectorTemplates.externalModule(withDio: true),
        InjectorTemplates.coreModule(withMedia: true),
        InjectorTemplates.dataModule(withDio: true, withAuthFeature: true),
        InjectorTemplates.presentationModule(withAuthFeature: true),
      ];

      for (final output in modules) {
        expect(output, contains("import 'injector.dart';"));
        // `getIt` is the project's, not the package's: importing get_it here
        // would shadow nothing and register into a different instance.
        expect(output, isNot(contains('package:get_it/get_it.dart')));
      }
    });
  });

  group('the external layer', () {
    test('holds the third-party instances and the storage wrapper', () {
      final output = InjectorTemplates.externalModule(
        withDio: true,
        withFirestore: true,
        withFirebaseAuth: true,
      );

      expect(output, contains('void registerExternals() {'));
      expect(
        output,
        contains(
            '..registerLazySingleton<Dio>(() => buildDioClient(getIt<TokenStorage>()))'),
      );
      expect(output, contains('..registerLazySingleton<FirebaseAuth>('));
      expect(output, contains('..registerLazySingleton<FirebaseFirestore>('));
      expect(output, contains('..registerLazySingleton<TokenStorage>('));
    });

    test('the auth-aware client resolves the repository lazily', () {
      final output = InjectorTemplates.externalModule(
        withDio: true,
        withAuthFeature: true,
      );

      expect(output, contains('refreshSession: () => getIt<AuthRepository>()'));
      // The type has to be in scope for `getIt<AuthRepository>()` to compile.
      expect(
        output,
        contains(
            "import '../../features/auth/domain/repositories/auth_repository.dart';"),
      );
    });
  });

  group('the core layer', () {
    test('holds the services under lib/core, and only those', () {
      final output = InjectorTemplates.coreModule(
        withMedia: true,
        withBiometric: true,
        withDebouncer: true,
      );

      expect(output, contains('void registerCoreServices() {'));
      expect(output, contains('..registerLazySingleton<PermissionService>('));
      expect(output, contains('..registerLazySingleton<MediaService>('));
      expect(output, contains('..registerLazySingleton<BiometricService>('));
      // Not a singleton: two screens sharing one debouncer would cancel each
      // other's pending action.
      expect(output, contains('..registerFactory<DebouncerService>('));
      expect(output, isNot(contains('Dio')));
      expect(output, isNot(contains('AuthRepository')));
    });
  });

  group('the data layer', () {
    test('is the same in both stacks and carries the anchor', () {
      final output = InjectorTemplates.dataModule(
        withDio: true,
        withAuthFeature: true,
      );

      expect(output, contains('void registerDataLayer() {'));
      expect(
          output, contains('..registerLazySingleton<AuthRemoteDataSource>('));
      expect(output, contains('..registerLazySingleton<AuthRepository>('));
      // `moarch create feature` writes here, so the anchor is what makes the
      // module usable at all.
      expect(output, contains(InjectorUtils.anchor));
      // No state holder of either kind.
      expect(output, isNot(contains('AuthBloc')));
      expect(output, isNot(contains('Notifier')));
    });

    test('an empty data layer still compiles and still anchors', () {
      final output = InjectorTemplates.dataModule();

      // `getIt;` with no cascade after it would not compile, so the cascade
      // is dropped rather than emitted empty.
      expect(output, isNot(contains('getIt\n')));
      expect(output, contains('void registerDataLayer() {'));
      expect(output, contains(InjectorUtils.anchor));
    });

    test('the Firestore-backed auth datasource takes its handles', () {
      final output = InjectorTemplates.dataModule(
        withFirestore: true,
        withAuthFeature: true,
        withFirebaseAuthFeature: true,
      );

      expect(output, contains('getIt<FirebaseAuth>(),'));
      expect(output, contains('getIt<GoogleSignIn>(),'));
      expect(output, contains('getIt<FirebaseFirestore>(),'));
      expect(output,
          contains("import 'package:google_sign_in/google_sign_in.dart';"));
      // The REST pair has no place here.
      expect(output, isNot(contains('getIt<Dio>()')));
      expect(output, isNot(contains('TokenStorage')));
    });
  });

  group('the presentation layer', () {
    test('registers the session-wide holders as singletons', () {
      final output = InjectorTemplates.presentationModule(
        withAuthFeature: true,
        withLocalization: true,
      );

      expect(output, contains('void registerBlocs() {'));
      // The router's redirect and every screen have to read the same session.
      expect(output, contains('..registerLazySingleton<AuthBloc>('));
      expect(output, contains('..registerLazySingleton<LanguageCubit>('));
      expect(output, contains(InjectorUtils.anchor));
    });

    test('an empty one is still where create bloc writes', () {
      final output = InjectorTemplates.presentationModule();

      expect(output, isNot(contains('getIt\n')));
      expect(output, contains(InjectorUtils.anchor));
    });
  });

  group('the pre-split layout is still generated for projects that have it',
      () {
    test('everything lands in the one file, anchor included', () {
      for (final stateManagement in StateManagement.values) {
        final output = InjectorTemplates.singleFileInjector(
          stateManagement: stateManagement,
          withDio: true,
          withMedia: true,
          withBiometric: true,
        );

        expect(output, contains('final getIt = GetIt.instance;'),
            reason: '$stateManagement');
        expect(output, contains('Future<void> setupInjector() async {'),
            reason: '$stateManagement');
        expect(
          output,
          contains(
              '..registerLazySingleton<Dio>(() => buildDioClient(getIt<TokenStorage>()))'),
          reason: '$stateManagement',
        );
        expect(output, contains('..registerLazySingleton<MediaService>('),
            reason: '$stateManagement');
        expect(output, contains('..registerLazySingleton<BiometricService>('),
            reason: '$stateManagement');
        expect(output, contains(InjectorUtils.anchor),
            reason: '$stateManagement');
        // One file means no modules to call.
        expect(output, isNot(contains('registerExternals')),
            reason: '$stateManagement');
      }
    });

    test('the state holders are the only difference', () {
      String injector(StateManagement sm) =>
          InjectorTemplates.singleFileInjector(
            stateManagement: sm,
            withDio: true,
            withAuthFeature: true,
            withLocalization: true,
          );

      final bloc = injector(StateManagement.bloc);
      final riverpodOutput = injector(StateManagement.riverpod);

      // The data layer under auth is registered in both.
      for (final output in [bloc, riverpodOutput]) {
        expect(
            output, contains('..registerLazySingleton<AuthRemoteDataSource>('));
        expect(output, contains('..registerLazySingleton<AuthRepository>('));
      }

      // A bloc is registered; a notifier needs the Ref only Riverpod can hand
      // it, so it stays behind its provider.
      expect(bloc, contains('..registerLazySingleton<AuthBloc>('));
      expect(bloc, contains('..registerLazySingleton<LanguageCubit>('));
      expect(
          bloc,
          contains(
              "import '../../features/auth/presentation/blocs/auth_bloc.dart';"));

      expect(riverpodOutput, isNot(contains('AuthBloc')));
      expect(riverpodOutput, isNot(contains('LanguageCubit')));
      expect(riverpodOutput, isNot(contains('language_service.dart')));
      expect(riverpodOutput, contains('Notifiers are not here'));
    });
  });

  group('a Riverpod feature resolves its dependencies from the locator', () {
    test('the data layer declares no providers of its own', () {
      final outputs = [
        riverpod.FeatureTemplates.remoteDatasource(
            'orders', 'Orders', 'orders'),
        riverpod.FeatureTemplates.remoteDatasource('orders', 'Orders', 'orders',
            useFirestore: true),
        riverpod.FeatureTemplates.localDatasource('orders', 'Orders', 'orders'),
        riverpod.FeatureTemplates.repositoryImpl('orders', 'Orders', 'orders',
            hasRemote: true, hasLocal: false),
      ];

      for (final output in outputs) {
        expect(output, isNot(contains('Provider<')));
        expect(output, isNot(contains('flutter_riverpod')));
        expect(output, isNot(contains('ref.watch')));
      }

      // Constructor injection all the way down — the data module resolves it.
      expect(
          outputs.first, contains('const OrdersRemoteDataSource(this._dio);'));
      expect(
          outputs.last, contains('const OrdersRepositoryImpl(this._remote);'));
    });

    test('the notifier is the seam: a provider that reads getIt', () {
      final output =
          riverpod.FeatureTemplates.notifier('orders', 'Orders', 'orders');

      expect(
        output,
        contains(
            'AsyncNotifierProvider<OrdersNotifier, OrdersState>(OrdersNotifier.new)'),
      );
      expect(output,
          contains('OrdersRepository get _repo => getIt<OrdersRepository>();'));
      // `getIt` is declared in the project's locator, not exported by the
      // package — importing get_it here would not compile.
      expect(output, contains("import '../../../../config/di/injector.dart';"));
      expect(output, isNot(contains('package:get_it/get_it.dart')));
    });

    test('the live variant subscribes to the repository', () {
      final output = riverpod.FeatureTemplates.notifier(
        'orders',
        'Orders',
        'orders',
        useFirestore: true,
      );

      expect(output,
          contains('OrdersRepository get _repo => getIt<OrdersRepository>();'));
      expect(output, contains('_repo.watchAll()'));
      expect(output, isNot(contains('GetOrders')));
    });
  });
}
