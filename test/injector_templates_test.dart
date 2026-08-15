import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/templates/riverpod/feature_templates.dart'
    as riverpod;
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

void main() {
  group('the locator is shared by both stacks', () {
    test('each one registers the same externals and services', () {
      for (final stateManagement in StateManagement.values) {
        final output = InjectorTemplates.injector(
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
        // The anchor `moarch create feature` writes above.
        expect(output, contains('// moarch:registrations'),
            reason: '$stateManagement');
      }
    });

    test('the state holders are the only difference', () {
      String injector(StateManagement sm) => InjectorTemplates.injector(
            stateManagement: sm,
            withDio: true,
            withAuthFeature: true,
            withLocalization: true,
          );

      final bloc = injector(StateManagement.bloc);
      final riverpod = injector(StateManagement.riverpod);

      // The data layer under auth is registered in both.
      for (final output in [bloc, riverpod]) {
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

      expect(riverpod, isNot(contains('AuthBloc')));
      expect(riverpod, isNot(contains('LanguageCubit')));
      expect(riverpod, isNot(contains('language_service.dart')));
      expect(riverpod, contains('Notifiers are not here'));
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
        riverpod.FeatureTemplates.usecase('orders', 'Orders', 'orders'),
      ];

      for (final output in outputs) {
        expect(output, isNot(contains('Provider<')));
        expect(output, isNot(contains('flutter_riverpod')));
        expect(output, isNot(contains('ref.watch')));
      }

      // Constructor injection all the way down — injector.dart resolves it.
      expect(
          outputs.first, contains('const OrdersRemoteDataSource(this._dio);'));
      expect(outputs.last, contains('const GetOrders(this._repository);'));
    });

    test('the notifier is the seam: a provider that reads getIt', () {
      final output = riverpod.FeatureTemplates.notifier(
          'orders', 'Orders', 'orders',
          hasUseCase: false);

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

    test('a use case is what the notifier takes when there is one', () {
      final withUseCase = riverpod.FeatureTemplates.notifier(
          'orders', 'Orders', 'orders',
          hasUseCase: true);

      expect(withUseCase,
          contains('GetOrders get _getOrders => getIt<GetOrders>();'));
      expect(withUseCase,
          contains("import '../../domain/usecases/get_orders.dart';"));
      // Two ways into the same data is one too many.
      expect(withUseCase, isNot(contains('OrdersRepository')));
    });

    test('the live variant takes the repository, use case or not', () {
      // watchAll() is the repository's; a use case wraps the one-off fetch.
      final output = riverpod.FeatureTemplates.notifier(
        'orders',
        'Orders',
        'orders',
        hasUseCase: true,
        useFirestore: true,
      );

      expect(output,
          contains('OrdersRepository get _repo => getIt<OrdersRepository>();'));
      expect(output, contains('_repo.watchAll()'));
      expect(output, isNot(contains('GetOrders')));
    });
  });
}
