import 'package:moarch/src/templates/bloc/app_templates.dart' as bloc;
import 'package:moarch/src/templates/bloc/auth_templates.dart' as bloc;
import 'package:moarch/src/templates/bloc/feature_templates.dart' as bloc;
import 'package:moarch/src/templates/bloc/maintenance_templates.dart' as bloc;
import 'package:moarch/src/templates/misc/dev_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/injector_utils.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('StateManagement.fromPubspec', () {
    test('reads bloc off a flutter_bloc entry', () {
      const pubspec = 'dependencies:\n  flutter_bloc: ^9.0.0\n  get_it: \n';

      expect(StateManagement.fromPubspec(pubspec), StateManagement.bloc);
    });

    test(
        'a project with neither is riverpod, which is what predates the '
        'choice', () {
      expect(StateManagement.fromPubspec(''), StateManagement.riverpod);
    });

    test('bloc_lint alone does not make it a bloc project', () {
      // Matched as a whole entry, so the substring in `bloc_lint` is not a
      // flutter_bloc dependency.
      const pubspec = 'dev_dependencies:\n  bloc_lint: \n';

      expect(StateManagement.fromPubspec(pubspec), StateManagement.riverpod);
    });
  });

  group('paths follow the stack', () {
    test('the action base and holder are named for the stack', () {
      const riverpod = StackTemplates(StateManagement.riverpod);
      const blocStack = StackTemplates(StateManagement.bloc);

      expect(riverpod.actionBaseFile, 'action_notifier.dart');
      expect(riverpod.holderDir, 'notifiers');
      expect(riverpod.holderFile('orders'), 'orders_notifier.dart');
      expect(riverpod.eventFile('orders'), isNull);

      expect(blocStack.holderDir, 'blocs');
      expect(blocStack.holderFile('orders'), 'orders_bloc.dart');
      expect(blocStack.eventFile('orders'), 'orders_event.dart');
    });

    test('the state sits with the bloc on bloc, on its own on Riverpod', () {
      const riverpod = StackTemplates(StateManagement.riverpod);
      const blocStack = StackTemplates(StateManagement.bloc);

      // State, events and bloc are one unit — a change to any of the three is
      // usually a change to all three, so they live together.
      expect(blocStack.stateDir, 'blocs');
      expect(blocStack.stateDir, blocStack.holderDir);
      expect(riverpod.stateDir, 'states');
    });
  });

  group('the bloc stack declares nothing centrally', () {
    test('there is no shared action base to generate', () {
      // The sealed family per feature is the status. A second way to say it —
      // a flag, an enum, a mixin — would be one too many.
      const riverpod = StackTemplates(StateManagement.riverpod);
      const blocStack = StackTemplates(StateManagement.bloc);

      expect(riverpod.hasActionBase, isTrue);
      expect(blocStack.hasActionBase, isFalse);
    });

    test('a feature state carries no status field of its own', () {
      final output = bloc.FeatureTemplates.state('orders', 'Orders');

      expect(output, isNot(contains('ActionStatus')));
      expect(output, isNot(contains('isLoadingAction')));
      // ...because these say it instead.
      expect(output, contains('final class OrdersInitial extends OrdersState'));
      expect(output, contains('final class OrdersLoading extends OrdersState'));
      expect(output, contains('final class OrdersSuccess extends OrdersState'));
      expect(output, contains('final class OrdersFailure extends OrdersState'));
    });
  });

  group('feature', () {
    test('the event family is sealed and covers start and retry', () {
      final output = bloc.FeatureTemplates.event('orders', 'Orders');

      expect(output, contains('sealed class OrdersEvent extends Equatable {'));
      expect(
          output, contains('final class OrdersStarted extends OrdersEvent {'));
      expect(output,
          contains('final class OrdersRefreshed extends OrdersEvent {'));
      // No snapshot event without a live query to produce one.
      expect(output, isNot(contains('OrdersItemsUpdated')));
    });

    test('the live variant adds the snapshot events and imports the entity',
        () {
      final output = bloc.FeatureTemplates.event(
        'orders',
        'Orders',
        useFirestore: true,
      );

      expect(output,
          contains("import '../../domain/entities/orders_entity.dart';"));
      expect(output,
          contains('final class OrdersItemsUpdated extends OrdersEvent {'));
      expect(
          output, contains('final class OrdersFailed extends OrdersEvent {'));
      expect(output, contains('final List<OrdersEntity> items;'));
    });

    test('a second bloc in a feature names that feature\'s entity', () {
      // `moarch create bloc orders order_feed` — the state lists Orders, not
      // an OrderFeedEntity that was never generated.
      final output = bloc.FeatureTemplates.state(
        'order_feed',
        'OrderFeed',
        useFirestore: true,
        entityName: 'orders',
        entityClass: 'Orders',
      );

      expect(output,
          contains("import '../../domain/entities/orders_entity.dart';"));
      expect(output, contains('final List<OrdersEntity> items;'));
      // The family is named for the bloc, the items for the feature.
      expect(
          output, contains('sealed class OrderFeedState extends Equatable {'));
      expect(output,
          contains('final class OrderFeedSuccess extends OrderFeedState {'));
      expect(output, isNot(contains('OrderFeedEntity')));
    });

    test('the placeholder id follows the entity, not the backend', () {
      // A live query added to a REST-shaped feature still keys on an int, and
      // a fake String id would not compile against it.
      final intId = bloc.FeatureTemplates.state(
        'orders',
        'Orders',
        useFirestore: true,
        entityIdIsString: false,
      );
      expect(intId, contains('OrdersEntity(id: index)'));
      // BoneMock is skeletonizer's, and nothing here uses it.
      expect(intId, isNot(contains('skeletonizer')));

      final stringId = bloc.FeatureTemplates.state(
        'orders',
        'Orders',
        useFirestore: true,
        entityIdIsString: true,
      );
      expect(stringId, contains(r"OrdersEntity(id: '${BoneMock.name}$index')"));
      expect(stringId,
          contains("import 'package:skeletonizer/skeletonizer.dart';"));
    });

    test('the bloc takes the use case when there is one, and nothing else', () {
      final output = bloc.FeatureTemplates.bloc(
        'orders',
        'Orders',
        'orders',
        hasUseCase: true,
      );

      expect(
          output,
          contains(
              'OrdersBloc(this._getOrders) : super(const OrdersInitial())'));
      expect(output, contains('final GetOrders _getOrders;'));
      // Two ways into the same data is one too many.
      expect(output, isNot(contains('final OrdersRepository _repo;')));
      expect(output, contains('await _getOrders();'));
    });

    test('the live bloc keeps the repository even with a use case', () {
      // watchAll is the repository's; a use case wraps the one-off fetch.
      final output = bloc.FeatureTemplates.bloc(
        'orders',
        'Orders',
        'orders',
        hasUseCase: true,
        useFirestore: true,
      );

      expect(output,
          contains('OrdersBloc(this._repo) : super(const OrdersInitial())'));
      expect(output, contains('_repo.watchAll().listen('));
      expect(output, contains('add(OrdersItemsUpdated(items))'));
      // Cancelled with the bloc, or the query outlives the screen and bills.
      expect(output, contains('_subscription?.cancel();'));
      expect(output, contains('Future<void> close() {'));
    });

    test('a second bloc depends on the feature\'s repository', () {
      final output = bloc.FeatureTemplates.bloc(
        'order_feed',
        'OrderFeed',
        'orderFeed',
        hasUseCase: false,
        repositoryName: 'orders',
        repositoryClass: 'Orders',
      );

      expect(
          output,
          contains(
              "import '../../domain/repositories/orders_repository.dart';"));
      expect(output, contains('final OrdersRepository _repo;'));
      expect(
        output,
        contains(
            'class OrderFeedBloc extends Bloc<OrderFeedEvent, OrderFeedState>'),
      );
    });

    test('the view owns the bloc so the route closes it', () {
      final output = bloc.FeatureTemplates.view(
        'orders',
        'Orders',
        'orders',
        hasBloc: true,
      );

      expect(output, contains('class OrdersPage extends StatelessWidget'));
      expect(
          output,
          contains(
              'create: (_) => getIt<OrdersBloc>()..add(const OrdersStarted())'));
      // Plain flutter_bloc widgets and a switch — no wrapper of moarch's own.
      expect(output, contains('BlocConsumer<OrdersBloc, OrdersState>'));
      expect(output, contains('builder: (context, state) => switch (state) {'));
      expect(output,
          contains('OrdersInitial() || OrdersLoading() => Skeletonizer('));
      expect(output, contains('OrdersFailure(:final message) => ErrorView('));
      expect(output, contains('add(const OrdersRefreshed())'));
      expect(output, isNot(contains('AppAsyncView')));
      expect(output, isNot(contains('ActionListener')));
    });

    test('the view listens as well as builds, and only on a change', () {
      final output = bloc.FeatureTemplates.view(
        'orders',
        'Orders',
        'orders',
        hasBloc: true,
      );

      // The listener is the place for what happens once — the builder runs on
      // every rebuild, so a toast raised there repeats.
      expect(output,
          contains('listenWhen: (previous, current) => previous != current'));
      expect(output, contains('listener: (context, state) {'));
      // Prepared for the states that exist, not for a helper of our own.
      expect(output, contains('case OrdersFailure(:final message):'));
      expect(output, contains('AppToast.error(context, message);'));
      expect(output, contains('case OrdersSuccess():'));
      expect(output, contains('case OrdersInitial():'));
      expect(output, contains('case OrdersLoading():'));
      expect(
        output,
        contains(
            "import '../../../../shared/widgets/overlays/app_toast.dart';"),
      );
    });

    test('the bloc, its events and its state are imported as neighbours', () {
      final blocOutput = bloc.FeatureTemplates.bloc(
        'orders',
        'Orders',
        'orders',
        hasUseCase: false,
      );
      final viewOutput = bloc.FeatureTemplates.view(
        'orders',
        'Orders',
        'orders',
        hasBloc: true,
      );

      // All three are in presentation/blocs/, so the bloc reaches its state
      // without climbing out of the folder.
      expect(blocOutput, contains("import 'orders_state.dart';"));
      expect(blocOutput, contains("import 'orders_event.dart';"));
      expect(blocOutput, isNot(contains('../states/')));
      expect(viewOutput, contains("import '../blocs/orders_state.dart';"));
      expect(viewOutput, isNot(contains('../states/')));
    });

    test('the datasource takes its client rather than reading a provider', () {
      final output =
          bloc.FeatureTemplates.remoteDatasource('orders', 'Orders', 'orders');

      expect(output, contains('const OrdersRemoteDataSource(this._dio);'));
      expect(output, isNot(contains('riverpod')));
      expect(output, isNot(contains('Provider<')));
    });
  });

  group('auth', () {
    test('the bloc is event-driven and restores the session on start', () {
      final output = bloc.AuthTemplates.bloc();

      expect(output, contains('on<AuthStarted>(_onStarted);'));
      expect(output, contains('on<AuthLoginRequested>(_onLogin);'));
      expect(output, contains('await _repo.isLoggedIn()'));
      expect(output,
          contains('class AuthBloc extends Bloc<AuthEvent, AuthState>'));
      // A failed restore is a signed-out app, not an error screen.
      expect(output, contains('emit(const AuthUnauthenticated());'));
    });

    test('the events carry what the screens submit', () {
      final output = bloc.AuthTemplates.event();

      expect(output, contains('sealed class AuthEvent extends Equatable {'));
      expect(output,
          contains('final class AuthLoginRequested extends AuthEvent {'));
      expect(output,
          contains('final class AuthAccountDeleted extends AuthEvent {'));
    });
  });

  group('injector', () {
    test('registers a bloc as a factory and a repository as a singleton', () {
      final output = InjectorUtils.registrationsFor(
        featureName: 'orders',
        className: 'Orders',
        hasRemote: true,
        hasLocal: false,
        hasRepository: true,
        hasUseCase: false,
        hasBloc: true,
        useFirestore: false,
      );

      expect(
          output, contains('getIt.registerLazySingleton<OrdersRepository>('));
      expect(output, contains('getIt.registerFactory<OrdersBloc>('));
      expect(output, contains('OrdersBloc(getIt<OrdersRepository>())'));
    });

    test('the bloc resolves the use case when the feature has one', () {
      final output = InjectorUtils.registrationsFor(
        featureName: 'orders',
        className: 'Orders',
        hasRemote: true,
        hasLocal: false,
        hasRepository: true,
        hasUseCase: true,
        hasBloc: true,
        useFirestore: false,
      );

      expect(output, contains('OrdersBloc(getIt<GetOrders>())'));
    });

    test('inserts above the anchor and adds only the missing imports', () {
      const source = '''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupInjector() async {
  // moarch:registrations
}
''';

      final patched = InjectorUtils.insert(
        source,
        registrations:
            '  // ── Orders ──\n  getIt.registerFactory<OrdersBloc>(OrdersBloc.new);',
        imports: [
          "import 'package:get_it/get_it.dart';",
          "import '../../features/orders/presentation/blocs/orders_bloc.dart';",
        ],
        className: 'Orders',
      );

      expect(patched, contains('getIt.registerFactory<OrdersBloc>'));
      expect(
        patched,
        contains(
            "import '../../features/orders/presentation/blocs/orders_bloc.dart';"),
      );
      // Already there — adding it twice would not compile.
      expect(
          "import 'package:get_it/get_it.dart';".allMatches(patched).length, 1);
      expect(
        patched.indexOf('registerFactory'),
        lessThan(patched.indexOf('// moarch:registrations')),
      );
    });

    test('registering the same feature twice is a no-op', () {
      const source = '''
import 'package:get_it/get_it.dart';

Future<void> setupInjector() async {
  // ── Orders ──
  getIt.registerFactory<OrdersBloc>(OrdersBloc.new);

  // moarch:registrations
}
''';

      expect(
        InjectorUtils.insert(
          source,
          registrations:
              '  // ── Orders ──\n  getIt.registerFactory<OrdersBloc>(OrdersBloc.new);',
          imports: const [],
          className: 'Orders',
        ),
        source,
      );
    });

    test('a locator whose anchor was removed is left alone', () {
      const source = 'Future<void> setupInjector() async {}\n';

      expect(
        InjectorUtils.insert(
          source,
          registrations: '  getIt.registerFactory<OrdersBloc>(OrdersBloc.new);',
          imports: const [],
          className: 'Orders',
        ),
        source,
      );
    });
  });

  group('maintenance gate', () {
    test('fails open: the cubit starts up and only leaves on a read flag', () {
      final output = bloc.MaintenanceTemplates.maintenanceGate(
        withFirestore: true,
      );

      expect(output,
          contains('class MaintenanceCubit extends Cubit<MaintenanceStatus>'));
      expect(output, contains('super(const MaintenanceStatus.up())'));
      expect(
          output,
          contains(
              'onError: (Object _) => emit(const MaintenanceStatus.up())'));
      // The gate creates and closes its own cubit.
      expect(output, contains('create: (_) => _createMaintenanceCubit()'));
      expect(output, contains('class MaintenanceGate extends StatelessWidget'));
    });

    test('the stub variant needs nothing registered', () {
      final output = bloc.MaintenanceTemplates.maintenanceGate();

      expect(
          output,
          contains(
              'MaintenanceCubit() : super(const MaintenanceStatus.up());'));
      expect(output, isNot(contains('injector.dart')));
    });
  });

  group('bloc_lint wiring', () {
    test('a bloc project gets the recommended ruleset', () {
      final output = DevTemplates.analysisOptions(
        stateManagement: StateManagement.bloc,
      );

      expect(output, contains('include: package:flutter_lints/flutter.yaml'));
      expect(output, contains('bloc:'));
      expect(output, contains('- avoid_flutter_imports'));
      expect(output, contains('- prefer_file_naming_conventions'));
      // The scaffold ships two deliberate Cubits, so these would fight it.
      expect(output, isNot(contains('- prefer_bloc')));
      expect(output, isNot(contains('- prefer_cubit')));
    });

    test('a riverpod project gets no bloc section', () {
      expect(DevTemplates.analysisOptions(), isNot(contains('bloc:')));
    });
  });

  group('main.dart', () {
    test('sets the locator up before runApp and provides the auth bloc', () {
      final output = bloc.AppTemplates.mainDart(withAuthFeature: true);

      expect(output, contains('await setupInjector();'));
      expect(output, contains('BlocProvider<AuthBloc>('));
      expect(output, contains('getIt<AuthBloc>()..add(const AuthStarted())'));
      // Both halves: the bloc to create and the event to open it with.
      expect(
          output,
          contains(
              "import 'features/auth/presentation/blocs/auth_event.dart';"));
      expect(output, isNot(contains('ProviderScope')));
    });

    test('with nothing app-wide to provide there is no MultiBlocProvider', () {
      final output = bloc.AppTemplates.mainDart(withRouter: false);

      expect(output, contains('class App extends StatelessWidget'));
      expect(output, isNot(contains('MultiBlocProvider')));
    });
  });

  group('the kit follows the stack', () {
    test('the async-view pair is Riverpod-only', () {
      // A bloc screen draws its sealed state with a switch inside a plain
      // BlocBuilder, so these two would be wrappers over nothing.
      const riverpod = StackTemplates(StateManagement.riverpod);
      const blocStack = StackTemplates(StateManagement.bloc);

      expect(riverpod.hasAsyncViewWidgets, isTrue);
      expect(blocStack.hasAsyncViewWidgets, isFalse);

      for (final name in ['async-view', 'action-listener']) {
        final spec = WidgetCatalog.byName(name)!;
        expect(spec.supports(StateManagement.riverpod), isTrue);
        expect(spec.supports(StateManagement.bloc), isFalse,
            reason: '$name should not be generated into a bloc project');
      }
    });

    test('resolving the kit for bloc drops them and keeps the rest', () {
      final forBloc = WidgetCatalog.resolve(
        WidgetCatalog.names,
        stateManagement: StateManagement.bloc,
      ).map((spec) => spec.name);

      expect(forBloc, isNot(contains('async-view')));
      expect(forBloc, isNot(contains('action-listener')));
      // The screens a bloc view does import are still there.
      expect(forBloc, contains('error-view'));
      expect(forBloc, contains('empty-view'));
      expect(forBloc, contains('toast'));
    });

    test('init generates the common set minus what the stack lacks', () {
      final blocCommon =
          WidgetCatalog.commonFor(StateManagement.bloc).map((s) => s.name);
      final riverpodCommon =
          WidgetCatalog.commonFor(StateManagement.riverpod).map((s) => s.name);

      expect(riverpodCommon, contains('async-view'));
      expect(blocCommon, isNot(contains('async-view')));
      expect(blocCommon, contains('error-view'));
    });
  });
}
