import 'package:moarch/src/templates/bloc/app_templates.dart' as bloc;
import 'package:moarch/src/templates/bloc/async_templates.dart' as bloc;
import 'package:moarch/src/templates/bloc/auth_templates.dart' as bloc;
import 'package:moarch/src/templates/bloc/feature_templates.dart' as bloc;
import 'package:moarch/src/templates/bloc/maintenance_templates.dart' as bloc;
import 'package:moarch/src/templates/misc/dev_templates.dart';
import 'package:moarch/src/templates/riverpod/feature_templates.dart'
    as riverpod;
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/injector_utils.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('StateManagement.fromPubspec', () {
    test('reads bloc off a flutter_bloc entry', () {
      const pubspec = 'dependencies:\n  flutter_bloc: ^9.0.0\n  get_it: \n';

      expect(StateManagement.fromPubspec(pubspec), StateManagement.bloc);
    });

    test('a project with neither is riverpod, which is what predates the '
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

  group('each stack has a shared state vocabulary', () {
    test('both declare an action base, and they are different files', () {
      const riverpod = StackTemplates(StateManagement.riverpod);
      const blocStack = StackTemplates(StateManagement.bloc);

      expect(riverpod.hasActionBase, isTrue);
      expect(blocStack.hasActionBase, isTrue);
      expect(riverpod.actionBaseFile, 'action_notifier.dart');
      expect(blocStack.actionBaseFile, 'app_status.dart');

      // Bloc's is the status enum; Riverpod's is the runAction contract.
      expect(blocStack.actionBase(), contains('enum AppStatus {'));
      expect(riverpod.actionBase(), contains('ActionState'));
    });

    test('the status is shared so a widget can switch over it', () {
      // One enum for every screen rather than one per feature: AppStatusView
      // cannot switch over a type it does not know.
      final output = bloc.FeatureTemplates.state('orders', 'Orders');

      expect(
        output,
        contains("import '../../../../core/utils/app_status.dart';"),
      );
      expect(output, contains('final AppStatus status;'));
      expect(output, contains('this.status = AppStatus.initial,'));
      // Not declared per feature any more.
      expect(output, isNot(contains('enum OrdersStatus')));
      expect(output, isNot(contains('isLoadingAction')));
      // Still one class, so the view's `_body` takes the same thing always.
      expect(
        output,
        contains(
          'class OrdersState extends Equatable '
          'implements StatusState<OrdersState> {',
        ),
      );
      expect(output, isNot(contains('extends OrdersState')));
    });

    test('AppStatus names the four screens and nothing screen-specific', () {
      final output = bloc.AsyncTemplates.appStatus();

      expect(output, contains('enum AppStatus {'));
      for (final value in ['initial', 'loading', 'success']) {
        expect(
          output,
          contains('  $value,'),
          reason: '$value should be one of the four',
        );
      }
      // Last, and followed by the getters rather than another value.
      expect(output, contains('  failure;'));
      // A phase one screen alone has is a field on that screen's state —
      // adding it here would ask every other feature to handle it. Named in
      // the doc comment as the thing not to do, never as a value.
      expect(output, isNot(contains('  submitting,')));
      expect(output, isNot(contains('  refreshing,')));
      // The getters that save every caller a `== AppStatus.x`.
      expect(output, contains('bool get isLoading =>'));
      expect(output, contains('bool get isFailure =>'));
    });

    test('runAction sits beside the status it chooses between', () {
      final output = bloc.AsyncTemplates.appStatus();

      expect(output, contains('abstract interface class StatusState<S> {'));
      expect(
        output,
        contains(
          'mixin ActionBlocMixin<E, S extends StatusState<S>> '
          'on Bloc<E, S> {',
        ),
      );
      expect(output, contains("import '../errors/app_exception.dart';"));
      // Over data already on screen: no loading, and a failure keeps the
      // body — a toast rather than the error screen.
      expect(output, contains('final loaded = current.status.isSuccess;'));
      expect(
        output,
        contains('if (!loaded) emit(current.withStatus(AppStatus.loading));'),
      );
      expect(
        output,
        contains(
          'final failed = loaded ? AppStatus.success : AppStatus.failure;',
        ),
      );
      expect(output, contains('} on AppException catch (e) {'));
      // The unexpected still reaches onError and the BlocObserver.
      expect(output, contains('addError(error, stackTrace);'));
    });

    test('a stale app_status.dart is told apart from a current one', () {
      const blocStack = StackTemplates(StateManagement.bloc);
      const riverpodStack = StackTemplates(StateManagement.riverpod);

      expect(blocStack.isStaleActionBase(blocStack.actionBase()), isFalse);
      expect(blocStack.isStaleActionBase('enum AppStatus { initial }'), isTrue);
      expect(riverpodStack.isStaleActionBase(''), isFalse);
    });
  });

  group('feature', () {
    test('the event family is sealed and carries one event', () {
      final output = bloc.FeatureTemplates.event('orders', 'Orders');

      expect(output, contains('sealed class OrdersEvent extends Equatable {'));
      expect(
        output,
        contains('final class OrdersStarted extends OrdersEvent {'),
      );
      // A refresh and a retry are the same load, so they re-dispatch Started
      // rather than each getting an event of their own.
      expect(output, isNot(contains('OrdersRefreshed')));
      expect(output, isNot(contains('OrdersItemsUpdated')));
      expect(output, isNot(contains('OrdersFailed')));
      // No model is named, so nothing has to exist for this to compile.
      expect(output, isNot(contains('OrdersModel')));
    });

    test('the state starts empty and says where its fields go', () {
      // What the screen shows is the screen's business — a scaffolded list of
      // models would be a guess, and one the user then has to delete.
      final output = bloc.FeatureTemplates.state('orders', 'Orders');

      expect(output, contains('this.status = AppStatus.initial,'));
      // The list only appears as the TODO's example, never as a declaration.
      expect(output, isNot(contains('\n  final List<')));
      // Nothing is imported for a field that is not there, so a feature
      // scaffolded without a data layer still compiles.
      expect(output, isNot(contains("import '../../domain/models/")));
      // The four places a new field has to reach, all named in one TODO.
      expect(output, contains('OrdersState copyWith({'));
      expect(
        output,
        contains(
          'List<Object?> get props => '
          '[status, errorMessage, successMessage];',
        ),
      );
      expect(output, contains('static const placeholder ='));
      expect(output, contains('A field has to reach four places'));
    });

    test('both messages are one-shot, so copyWith drops them', () {
      // The `_seq` counter the sealed states needed is gone with them: a retry
      // passes through loading, so a second identical failure is never equal
      // to the first and the emit is not dropped.
      final output = bloc.FeatureTemplates.state('orders', 'Orders');

      expect(output, contains('final String? errorMessage;'));
      expect(output, contains('final String? successMessage;'));
      // Assigned straight through rather than `?? this.x` — that is what
      // makes them fire once and then clear themselves.
      expect(output, contains('      errorMessage: errorMessage,'));
      expect(output, contains('      successMessage: successMessage,'));
      expect(output, isNot(contains('errorMessage ?? this.errorMessage')));
      expect(output, isNot(contains('_seq')));
    });

    test('the state is a StatusState, so runAction can move it', () {
      final output = bloc.FeatureTemplates.state('orders', 'Orders');

      expect(output, contains('  @override\n  final AppStatus status;'));
      expect(
        output,
        contains(
          'OrdersState withStatus(AppStatus status, '
          '{String? errorMessage}) =>\n'
          '      copyWith(status: status, errorMessage: errorMessage);',
        ),
      );
    });

    test('the state is the same whatever the backend is', () {
      // `useFirestore` reaches the data layer, not this: a bloc's state
      // carries nothing the backend decides.
      const blocStack = StackTemplates(StateManagement.bloc);

      expect(
        blocStack.featureState('orders', 'Orders', useFirestore: true),
        blocStack.featureState('orders', 'Orders'),
      );
    });

    test('the one-off load is the only shape there is', () {
      final output = bloc.FeatureTemplates.bloc('orders', 'Orders', 'orders');

      expect(output, contains('await _repo.fetchAll();'));
      // Loading and AppException are runAction's, not the handler's.
      expect(
        output,
        contains('with ActionBlocMixin<OrdersEvent, OrdersState> {'),
      );
      expect(output, contains('runAction(emit, (current) async {'));
      expect(
        output,
        contains('return current.copyWith(status: AppStatus.success);'),
      );
      expect(output, isNot(contains('try {')));
      expect(output, isNot(contains('app_exception.dart')));
      // The subscription variant is gone — a live query is the project's to
      // wire, not the scaffold's to assume.
      expect(output, isNot(contains('watchAll()')));
      expect(output, isNot(contains('StreamSubscription')));
      expect(output, isNot(contains('Future<void> close()')));
    });

    test('the handler is registered for Started alone', () {
      final output = bloc.FeatureTemplates.bloc('orders', 'Orders', 'orders');

      expect(output, contains('on<OrdersStarted>(_onStarted);'));
      expect(output, isNot(contains('on<OrdersRefreshed>')));
      expect(output, isNot(contains('on<OrdersItemsUpdated>')));
    });

    test('the view draws from the state it is handed, not a guessed list', () {
      final output = bloc.FeatureTemplates.view(
        'orders',
        'Orders',
        'orders',
        hasBloc: true,
      );

      expect(output, contains('return const SizedBox.shrink();'));
      expect(output, isNot(contains('ListView.builder(')));
      // `items` is named once, in the TODO that says where `isEmpty` goes —
      // never as something the body actually draws.
      expect(output, contains('// `isEmpty: state.items.isEmpty,`.'));
      expect(output, isNot(contains('for (final')));
    });

    test('the skeleton is traced from the placeholder state', () {
      // Skeletonizer shimmers the tree it is handed, so loading has to render
      // the same body over *something*. AppStatusView owns the Skeletonizer
      // now; the view only says what shape to trace.
      final output = bloc.FeatureTemplates.view(
        'orders',
        'Orders',
        'orders',
        hasBloc: true,
      );

      expect(
        output,
        contains(
          'skeleton: (context) => _body(context, OrdersState.placeholder)',
        ),
      );
      // The package moved into the widget with the Skeletonizer itself.
      expect(
        output,
        isNot(contains("import 'package:skeletonizer/skeletonizer.dart';")),
      );
      expect(output, isNot(contains('Skeletonizer(')));
      expect(output, contains('BoneMock'));
      // One body for every status, so a phase drawn over loaded data needs no
      // second one.
      expect(
        output,
        contains('Widget _body(BuildContext context, OrdersState state)'),
      );
    });

    test('the bloc takes the repository', () {
      final output = bloc.FeatureTemplates.bloc('orders', 'Orders', 'orders');

      expect(
        output,
        contains('OrdersBloc(this._repo) : super(const OrdersState())'),
      );
      expect(output, contains('final OrdersRepository _repo;'));
      expect(output, contains('await _repo.fetchAll();'));
    });

    test('a bloc scaffolded without a data layer takes nothing', () {
      // `moarch create feature` with the Repository row unticked: the bloc is
      // generated, but nothing it would import was.
      final output = bloc.FeatureTemplates.bloc(
        'orders',
        'Orders',
        'orders',
        hasRepository: false,
      );

      expect(output, contains('OrdersBloc() : super(const OrdersState())'));
      expect(output, isNot(contains('_repo')));
      expect(output, isNot(contains('OrdersRepository')));
      expect(
        output,
        isNot(
          contains(
            "import '../../domain/repositories/orders_repository.dart';",
          ),
        ),
      );
      // Still a working bloc: it just has nothing to load yet.
      expect(output, contains('on<OrdersStarted>(_onStarted);'));
      expect(output, contains('runAction(emit, (current) async {'));
      expect(
        output,
        contains('return current.copyWith(status: AppStatus.success);'),
      );
    });

    test('the bloc points at a transformer rather than a debouncer', () {
      // The one place a bloc throttles events. A DebouncerService in front of
      // add() would debounce without cancelling what is already in flight.
      final output = bloc.FeatureTemplates.bloc('orders', 'Orders', 'orders');

      expect(output, contains('transformer:'));
      expect(output, contains('bloc_concurrency'));
      expect(output, contains('droppable'));
      expect(output, isNot(contains('DebouncerService(')));
    });

    test('a second bloc depends on the feature\'s repository', () {
      final output = bloc.FeatureTemplates.bloc(
        'order_feed',
        'OrderFeed',
        'orderFeed',
        repositoryName: 'orders',
        repositoryClass: 'Orders',
      );

      expect(
        output,
        contains("import '../../domain/repositories/orders_repository.dart';"),
      );
      expect(output, contains('final OrdersRepository _repo;'));
      expect(
        output,
        contains(
          'class OrderFeedBloc extends Bloc<OrderFeedEvent, OrderFeedState>',
        ),
      );
    });

    test('the page owns the bloc so the route closes it', () {
      final output = bloc.FeatureTemplates.page('orders', 'Orders');

      expect(output, contains('class OrdersPage extends StatelessWidget'));
      expect(
        output,
        contains(
          'create: (_) => getIt<OrdersBloc>()..add(const OrdersStarted())',
        ),
      );
      expect(output, contains('child: const OrdersView(),'));
      // It is a file of its own, so it imports the view it wraps.
      expect(output, contains("import '../views/orders_view.dart';"));
      expect(output, contains("import '../../../../config/di/injector.dart';"));
    });

    test('the view only reads the bloc the page provides', () {
      final output = bloc.FeatureTemplates.view(
        'orders',
        'Orders',
        'orders',
        hasBloc: true,
      );

      // The provider and the locator belong to the page now.
      expect(output, isNot(contains('class OrdersPage')));
      expect(output, isNot(contains('BlocProvider(')));
      expect(
        output,
        isNot(contains("import '../../../../config/di/injector.dart';")),
      );
      // A plain BlocConsumer whose builder is one AppStatusView call — the
      // three shells live in the widget, not repeated in every feature.
      expect(output, contains('BlocConsumer<OrdersBloc, OrdersState>'));
      expect(output, contains('builder: (context, state) => AppStatusView('));
      expect(output, contains('status: state.status,'));
      expect(output, contains('message: state.errorMessage,'));
      expect(output, isNot(contains('switch (state.status)')));
      expect(output, isNot(contains('ErrorView(')));
      expect(
        output,
        contains("import '../../../../shared/widgets/app_status_view.dart';"),
      );
      // Retry re-dispatches the one event there is.
      expect(output, contains('add(const OrdersStarted())'));
      expect(output, isNot(contains('OrdersRefreshed')));
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
      // every rebuild, so a toast raised there repeats. It watches the two
      // one-shot fields rather than the whole state, which changes on every
      // load as well.
      expect(output, contains('listenWhen: (previous, current) =>'));
      expect(
        output,
        contains('previous.errorMessage != current.errorMessage ||'),
      );
      expect(
        output,
        contains('previous.successMessage != current.successMessage,'),
      );
      expect(output, contains('listener: (context, state) {'));
      expect(output, contains('AppToast.error(context, error);'));
      expect(output, contains('AppToast.success(context, success);'));
      expect(
        output,
        contains(
          "import '../../../../shared/widgets/overlays/app_toast.dart';",
        ),
      );
    });

    test('the bloc, its events and its state are imported as neighbours', () {
      final blocOutput = bloc.FeatureTemplates.bloc(
        'orders',
        'Orders',
        'orders',
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
      final output = bloc.FeatureTemplates.remoteDatasource(
        'orders',
        'Orders',
        'orders',
      );

      expect(output, contains('const OrdersRemoteDataSource(this._dio);'));
      expect(output, isNot(contains('riverpod')));
      expect(output, isNot(contains('Provider<')));
    });
  });

  group('a holder without a repository', () {
    test('the Riverpod notifier drops the locator with it', () {
      final output = riverpod.FeatureTemplates.notifier(
        'orders',
        'Orders',
        'orders',
        hasRepository: false,
      );

      expect(output, isNot(contains('OrdersRepository')));
      expect(output, isNot(contains('getIt')));
      expect(
        output,
        isNot(contains("import '../../../../config/di/injector.dart';")),
      );
      expect(output, contains('FutureOr<OrdersState> build() async {'));
      expect(output, contains('return const OrdersState();'));
    });

    test('the bloc is still registered, taking nothing', () {
      final output = InjectorUtils.registrationsFor(
        featureName: 'orders',
        className: 'Orders',
        hasRemote: false,
        hasLocal: false,
        hasRepository: false,
        hasBloc: true,
        useFirestore: false,
      );

      // A bloc is a state holder, so it goes in the presentation module and
      // the data module is left with nothing to add.
      expect(
        output.holders,
        contains('getIt.registerFactory<OrdersBloc>(OrdersBloc.new);'),
      );
      expect(output.holders, isNot(contains('OrdersRepository')));
      expect(output.data, isEmpty);
    });

    test('a second bloc is registered with the feature\'s repository', () {
      // `moarch create bloc orders order_feed` — the feature has one, this
      // bloc does not declare one of its own.
      final output = InjectorUtils.registrationsFor(
        featureName: 'orders',
        className: 'OrderFeed',
        hasRemote: false,
        hasLocal: false,
        hasRepository: false,
        hasBloc: true,
        useFirestore: false,
        blocRepositoryClass: 'Orders',
        blocFileName: 'order_feed',
      );

      expect(output.holders, contains('getIt.registerFactory<OrderFeedBloc>('));
      expect(
        output.holders,
        contains('() => OrderFeedBloc(getIt<OrdersRepository>()),'),
      );
      // Its own file, under the feature it belongs to.
      expect(
        output.holderImports,
        contains(
          "import '../../features/orders/presentation/blocs/order_feed_bloc.dart';",
        ),
      );
      expect(
        output.holderImports,
        contains(
          "import '../../features/orders/domain/repositories/orders_repository.dart';",
        ),
      );
    });
  });

  group('auth', () {
    test('the bloc is event-driven and restores the session on start', () {
      final output = bloc.AuthTemplates.bloc();

      expect(output, contains('on<AuthStarted>(_onStarted);'));
      expect(output, contains('on<AuthLoginRequested>(_onLogin);'));
      expect(output, contains('await _repo.isLoggedIn()'));
      expect(
        output,
        contains('class AuthBloc extends Bloc<AuthEvent, AuthState>'),
      );
      // A failed restore is a signed-out app, not an error screen.
      expect(output, contains('emit(const AuthUnauthenticated());'));
    });

    test('the events carry what the screens submit', () {
      final output = bloc.AuthTemplates.event();

      expect(output, contains('sealed class AuthEvent extends Equatable {'));
      expect(
        output,
        contains('final class AuthLoginRequested extends AuthEvent {'),
      );
      expect(
        output,
        contains('final class AuthAccountDeleted extends AuthEvent {'),
      );
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
        hasBloc: true,
        useFirestore: false,
      );

      // The two halves land in different files: the repository in the data
      // module, the bloc in the presentation module.
      expect(
        output.dataBlock,
        contains('getIt.registerLazySingleton<OrdersRepository>('),
      );
      expect(output.dataBlock, isNot(contains('OrdersBloc')));
      expect(
        output.holderBlock,
        contains('getIt.registerFactory<OrdersBloc>('),
      );
      expect(
        output.holderBlock,
        contains('OrdersBloc(getIt<OrdersRepository>())'),
      );
      // Each block carries the heading that makes re-registering a no-op —
      // and the single-file layout takes both under one.
      expect(output.dataBlock, contains('// ── Orders '));
      expect(output.holderBlock, contains('// ── Orders '));
      expect('// ── Orders '.allMatches(output.combined).length, 1);
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
          "import '../../features/orders/presentation/blocs/orders_bloc.dart';",
        ),
      );
      // Already there — adding it twice would not compile.
      expect(
        "import 'package:get_it/get_it.dart';".allMatches(patched).length,
        1,
      );
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

      expect(
        output,
        contains('class MaintenanceCubit extends Cubit<MaintenanceStatus>'),
      );
      expect(output, contains('super(const MaintenanceStatus.up())'));
      expect(
        output,
        contains('onError: (Object _) => emit(const MaintenanceStatus.up())'),
      );
      // The gate creates and closes its own cubit.
      expect(output, contains('create: (_) => _createMaintenanceCubit()'));
      expect(output, contains('class MaintenanceGate extends StatelessWidget'));
    });

    test('the stub variant needs nothing registered', () {
      final output = bloc.MaintenanceTemplates.maintenanceGate();

      expect(
        output,
        contains('MaintenanceCubit() : super(const MaintenanceStatus.up());'),
      );
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

    test('a refresh keeps the ruleset a bloc project already has', () {
      // The catalog spec used to call analysisOptions() with no arguments, so
      // it defaulted to Riverpod: `moarch update` rewrote a bloc project's
      // analysis_options.yaml without the `bloc:` block it came with.
      final spec = ScaffoldCatalog.all.firstWhere(
        (spec) => spec.name == 'analysis-options',
      );
      const context = ScaffoldContext(
        projectRoot: 'unused',
        pubspec: 'dependencies:\n  flutter_bloc: ^9.1.1\n',
      );

      expect(spec.template(context), contains('bloc:'));
      expect(spec.template(context), contains('- avoid_flutter_imports'));
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
        contains("import 'features/auth/presentation/blocs/auth_event.dart';"),
      );
      expect(output, isNot(contains('ProviderScope')));
    });

    test('the auth bloc is built with the tree, not on first read', () {
      final output = bloc.AppTemplates.mainDart(withAuthFeature: true);

      // Nothing reads this provider through the widget tree — the router's
      // redirect and its refreshListenable both take the bloc out of the
      // locator — so a lazy provider would never run its create, and the
      // AuthStarted that begins session restore would never be added.
      expect(output, contains('lazy: false,'));
    });

    test('the native splash is removed after runApp', () {
      final output = bloc.AppTemplates.mainDart(withAuthFeature: true);

      // Removing it before the first frame is painted shows a blank window
      // for as long as the first build takes.
      expect(
        output.indexOf('runApp('),
        lessThan(output.indexOf('FlutterNativeSplash.remove();')),
      );
    });

    test('with nothing app-wide to provide there is no MultiBlocProvider', () {
      final output = bloc.AppTemplates.mainDart(withRouter: false);

      expect(output, contains('class App extends StatelessWidget'));
      expect(output, isNot(contains('MultiBlocProvider')));
    });

    test('the error handlers are up before anything that can throw', () {
      final output = bloc.AppTemplates.mainDart(
        withRouter: false,
        withNotificationsService: true,
      );

      // A locator or a plugin that throws is reported rather than lost.
      expect(
        output.indexOf('PlatformDispatcher.instance.onError'),
        lessThan(output.indexOf('await setupInjector();')),
      );
      expect(
        output.indexOf('ErrorWidget.builder'),
        lessThan(output.indexOf('await _initNotifications();')),
      );
    });

    test('a notification plugin that throws still reaches runApp', () {
      final output = bloc.AppTemplates.mainDart(
        withRouter: false,
        withNotificationsService: true,
        withFirebaseNotifications: true,
      );

      // One guard each, so a failing local plugin does not cost the FCM one.
      expect(
        '} catch (error, stackTrace) {'.allMatches(output).length,
        equals(2),
      );
      expect(output, contains("appLogger.e(\n      '[Notifications] init"));
      expect(output, contains("appLogger.e(\n      '[FCM] init failed'"));
      expect(
        output.indexOf('await _initNotifications();'),
        lessThan(output.indexOf('FlutterNativeSplash.remove();')),
      );
    });

    test('no notification bootstrap without a notification service', () {
      final output = bloc.AppTemplates.mainDart(withRouter: false);

      expect(output, isNot(contains('_initNotifications')));
      expect(output, isNot(contains('} catch (error, stackTrace) {')));
    });
  });

  group('the kit follows the stack', () {
    test('the page beside the view is bloc-only', () {
      // Riverpod reads a notifier through a provider wherever it is needed,
      // so there is nothing to wrap the screen in.
      const riverpod = StackTemplates(StateManagement.riverpod);
      const blocStack = StackTemplates(StateManagement.bloc);

      expect(blocStack.hasPage, isTrue);
      expect(riverpod.hasPage, isFalse);
      expect(blocStack.pageFile('orders'), 'orders_page.dart');
      expect(
        blocStack.featurePage('orders', 'Orders'),
        contains('class OrdersPage extends StatelessWidget'),
      );
    });

    test('the async-view pair is Riverpod-only', () {
      // A bloc screen draws its state with one switch over `state.status`
      // inside a plain BlocBuilder, so these two would be wrappers over
      // nothing.
      const riverpod = StackTemplates(StateManagement.riverpod);
      const blocStack = StackTemplates(StateManagement.bloc);

      expect(riverpod.hasAsyncViewWidgets, isTrue);
      expect(blocStack.hasAsyncViewWidgets, isFalse);

      for (final name in ['async-view', 'action-listener']) {
        final spec = WidgetCatalog.byName(name)!;
        expect(spec.supports(StateManagement.riverpod), isTrue);
        expect(
          spec.supports(StateManagement.bloc),
          isFalse,
          reason: '$name should not be generated into a bloc project',
        );
      }
    });

    test('the design-system preview shows each stack its own renderer', () {
      // Previewing AppAsyncView on bloc imported two files that never existed
      // and the screen did not compile. Each stack now previews the widget it
      // actually has.
      final blocPreview = SharedTemplates.designSystemView(
        stateManagement: StateManagement.bloc,
      );
      final riverpodPreview = SharedTemplates.designSystemView(
        stateManagement: StateManagement.riverpod,
      );

      expect(blocPreview, contains('AppStatusView('));
      expect(
        blocPreview,
        contains("import '../widgets/app_status_view.dart';"),
      );
      expect(
        blocPreview,
        contains("import '../../core/utils/app_status.dart';"),
      );
      // Riverpod's half, and the file moarch never wrote for it.
      expect(blocPreview, isNot(contains('AppAsyncView')));
      expect(blocPreview, isNot(contains('action_bloc.dart')));
      expect(blocPreview, isNot(contains('app_exception.dart')));
      expect(blocPreview, isNot(contains('flutter_riverpod')));

      expect(riverpodPreview, contains('AppAsyncView<List<String>>'));
      expect(
        riverpodPreview,
        contains("import '../widgets/app_async_view.dart';"),
      );
      expect(riverpodPreview, isNot(contains('AppStatusView')));
      expect(riverpodPreview, isNot(contains('app_status.dart')));
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

    test('the search field sends each stack to its own debounce', () {
      final spec = WidgetCatalog.byName('search-field')!;

      final forBloc = WidgetCatalog.sourceFor(
        spec,
        const WidgetVariants(stateManagement: StateManagement.bloc),
      );
      final forRiverpod = WidgetCatalog.sourceFor(spec, const WidgetVariants());

      expect(forBloc, contains('`EventTransformer`'));
      // The service stays available for widget-level timers, but it is off by
      // default and it is not where a bloc search belongs — so the bloc doc
      // does not send anyone to it.
      expect(forBloc, isNot(contains('debouncer_service.dart')));
      expect(forRiverpod, contains('debouncer_service.dart'));
      expect(forRiverpod, isNot(contains('EventTransformer')));
      // Only the doc differs — the widget itself is one implementation.
      expect(forBloc, contains('class AppSearchField extends StatefulWidget'));
    });

    test('init generates the common set minus what the stack lacks', () {
      final blocCommon = WidgetCatalog.commonFor(
        StateManagement.bloc,
      ).map((s) => s.name);
      final riverpodCommon = WidgetCatalog.commonFor(
        StateManagement.riverpod,
      ).map((s) => s.name);

      expect(riverpodCommon, contains('async-view'));
      expect(blocCommon, isNot(contains('async-view')));
      expect(blocCommon, contains('error-view'));
    });
  });

  group('AuthFailure carries the session', () {
    test('the state records the user it failed for', () {
      final output = bloc.AuthTemplates.state();

      expect(
        output,
        contains('AuthFailure(this.message, {this.userId}) : id = ++_seq;'),
      );
      expect(output, contains('bool get authenticated => userId != null;'));
      expect(
        output,
        contains('List<Object?> get props => [message, userId, id];'),
      );
      // Same reason as a feature's Failure: a second wrong password must not
      // compare equal to the first and be dropped.
      expect(output, isNot(contains('const AuthFailure(')));
    });

    test('a failed delete is reported instead of swallowed', () {
      final output = bloc.AuthTemplates.bloc();

      // The screen showing the confirm dialog had no way to know the delete
      // failed: the handler caught the exception and emitted nothing.
      expect(
        output,
        contains('emit(AuthFailure(e.message, userId: current.userId));'),
      );
      expect(
        output,
        isNot(contains('// The account is still there, so the session is.')),
      );
    });

    test('the redirect keeps a still-signed-in user where they are', () {
      final output = bloc.AppTemplates.appRouter(withAuth: true);

      expect(
        output,
        contains(
          'auth is AuthAuthenticated || '
          '(auth is AuthFailure && auth.authenticated)',
        ),
      );
    });
  });

  test('the router logs its diagnostics in debug builds only', () {
    final output = bloc.AppTemplates.appRouter(withAuth: true);

    expect(output, contains('debugLogDiagnostics: kDebugMode'));
    expect(output, contains("import 'package:flutter/foundation.dart';"));
  });
}
