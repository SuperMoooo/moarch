import '../utils/state_management.dart';
import 'bloc/app_templates.dart' as bloc;
import 'config/config_templates.dart';
import 'config/injector_templates.dart';
import 'core/core_templates.dart';
import 'bloc/auth_templates.dart' as bloc;
import 'bloc/feature_templates.dart' as bloc;
import 'bloc/firebase_auth_templates.dart' as bloc;
import 'bloc/maintenance_templates.dart' as bloc;
import 'riverpod/app_templates.dart' as riverpod;
import 'riverpod/async_templates.dart' as riverpod;
import 'riverpod/auth_templates.dart' as riverpod;
import 'riverpod/feature_templates.dart' as riverpod;
import 'riverpod/firebase_auth_templates.dart' as riverpod;
import 'riverpod/maintenance_templates.dart' as riverpod;

/// The one place that knows which stack a template comes from.
///
/// `templates/riverpod/` and `templates/bloc/` hold a matching class per
/// state-bearing file. Every generator goes through this facade rather than
/// importing either folder directly, so adding a third stack is a case here
/// and a folder there — and no caller has to grow an `if`.
///
/// The file *paths* differ too (`presentation/notifiers/x_notifier.dart`
/// versus `presentation/blocs/x_bloc.dart`), so those live here as well.
class StackTemplates {
  /// Creates the facade for [stateManagement]. `sm.templates` is usually
  /// tidier at the call site.
  const StackTemplates(this.stateManagement);

  /// Which stack this facade resolves to.
  final StateManagement stateManagement;

  /// Whether this is the bloc stack.
  bool get isBloc => stateManagement.isBloc;

  // ── Paths ───────────────────────────────────────────────────────────────────

  /// Whether the stack has a shared action base to generate at all.
  ///
  /// Riverpod does — `ActionState` and the `runAction` mixin, which every
  /// notifier leans on. Bloc does not: its states are a sealed family per
  /// feature, so the family *is* the status and there is nothing central left
  /// to declare.
  bool get hasActionBase => !isBloc;

  /// The shared action base's file name. Riverpod only — see [hasActionBase].
  String get actionBaseFile => 'action_notifier.dart';

  /// The presentation folder holding the state holder — `notifiers/` or
  /// `blocs/`.
  String get holderDir => isBloc ? 'blocs' : 'notifiers';

  /// The presentation folder holding the state.
  ///
  /// On bloc that is `blocs/`, beside the events and the bloc itself: the
  /// three are one unit — the bloc's `on<Event>` handlers emit the states, and
  /// a change to any of them is usually a change to all three. Riverpod keeps
  /// `states/` of its own, since the notifier is the only thing that touches
  /// it.
  String get stateDir => isBloc ? 'blocs' : 'states';

  /// The state holder's file name for a feature, e.g. `orders_bloc.dart`.
  String holderFile(String name) =>
      isBloc ? '${name}_bloc.dart' : '${name}_notifier.dart';

  /// The event file's name, or null on Riverpod — there are no events there.
  String? eventFile(String name) => isBloc ? '${name}_event.dart' : null;

  /// Whether the stack generates a page beside the view.
  ///
  /// Bloc does: something has to build the bloc and provide it above the
  /// screen, and keeping that out of the view leaves the view a plain widget.
  /// Riverpod does not — a notifier is read through a provider wherever it is
  /// needed, so there is nothing to wrap the screen in.
  bool get hasPage => isBloc;

  /// The page's file name, e.g. `orders_page.dart`. Bloc only — see [hasPage].
  String pageFile(String name) => '${name}_page.dart';

  /// What the state holder is called in CLI output: "bloc" or "notifier".
  String get holderLabel => isBloc ? 'bloc' : 'notifier';

  /// The layer checklist's label for the state holder.
  String get holderChecklistItem =>
      isBloc ? 'State + Bloc' : 'State + Notifier';

  // ── App-level ───────────────────────────────────────────────────────────────

  /// The entry point.
  ///
  /// [withAuthFeature] only matters on bloc, where the auth bloc has to be
  /// provided above the router; Riverpod reads it through a provider.
  String mainDart({
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
  }) =>
      isBloc
          ? bloc.AppTemplates.mainDart(
              withRouter: withRouter,
              withLocalization: withLocalization,
              withEasyLocalization: withEasyLocalization,
              withNotificationsService: withNotificationsService,
              withFirebaseNotifications: withFirebaseNotifications,
              withCrashlytics: withCrashlytics,
              withFirebase: withFirebase,
              withMaintenanceGate: withMaintenanceGate,
              withMoAdapt: withMoAdapt,
              withDarkTheme: withDarkTheme,
              withAuthFeature: withAuthFeature,
            )
          : riverpod.AppTemplates.mainDart(
              withRouter: withRouter,
              withLocalization: withLocalization,
              withEasyLocalization: withEasyLocalization,
              withNotificationsService: withNotificationsService,
              withFirebaseNotifications: withFirebaseNotifications,
              withCrashlytics: withCrashlytics,
              withFirebase: withFirebase,
              withMaintenanceGate: withMaintenanceGate,
              withMoAdapt: withMoAdapt,
              withDarkTheme: withDarkTheme,
            );

  /// The `ActionState` contract and the `runAction` mixin every notifier
  /// leans on. Riverpod only — see [hasActionBase].
  String actionBase() => riverpod.AppTemplates.actionNotifier();

  /// The GoRouter setup.
  String appRouter({bool withAuth = false}) => isBloc
      ? bloc.AppTemplates.appRouter(withAuth: withAuth)
      : riverpod.AppTemplates.appRouter(withAuth: withAuth);

  /// Where the Firebase instances come from — a signpost to the locator, in
  /// both stacks.
  String firebaseProviders({bool hasAuth = false, bool hasDb = false}) =>
      ConfigTemplates.firebaseProviders(hasAuth: hasAuth, hasDb: hasDb);

  /// The locale holder — a `Notifier` on Riverpod, a `Cubit` on bloc.
  String languageService() => isBloc
      ? bloc.AppTemplates.languageService()
      : riverpod.AppTemplates.languageService();

  /// The REST client. One body for both stacks — see [CoreTemplates.dioClient].
  String dioClient({bool withAuthFeature = false}) =>
      CoreTemplates.dioClient(withAuthFeature: withAuthFeature);

  /// Whether this stack has a `config/di/presentation_module.dart`.
  ///
  /// Bloc does: a bloc is an ordinary dependency, constructed from a
  /// repository and handed out by type. Riverpod does not — a notifier needs
  /// the `Ref` Riverpod owns, so it lives behind its provider and there is
  /// nothing about it for get_it to hold.
  bool get hasPresentationModule => isBloc;

  /// The root of the get_it service locator: `getIt`, and `setupInjector()`
  /// calling one registrar per layer.
  ///
  /// Both stacks have one: DI is get_it's job either way. What varies is only
  /// whether there is a presentation module among the layers — see
  /// [InjectorTemplates].
  String injector() =>
      InjectorTemplates.injector(stateManagement: stateManagement);

  /// The locator's external layer — Dio, Firebase, secure storage. Same in
  /// both stacks.
  String externalModule({
    bool withDio = false,
    bool withFirestore = false,
    bool withFirebaseAuth = false,
    bool withAuthFeature = false,
    bool withFirebaseAuthFeature = false,
  }) =>
      InjectorTemplates.externalModule(
        withDio: withDio,
        withFirestore: withFirestore,
        withFirebaseAuth: withFirebaseAuth,
        withAuthFeature: withAuthFeature,
        withFirebaseAuthFeature: withFirebaseAuthFeature,
      );

  /// The locator's core-services layer. Same in both stacks.
  String coreModule({
    bool withMedia = false,
    bool withUrlLauncher = false,
    bool withNotifications = false,
    bool withFirebaseNotifications = false,
    bool withDebouncer = false,
    bool withBiometric = false,
    bool withConnectivity = false,
  }) =>
      InjectorTemplates.coreModule(
        withMedia: withMedia,
        withUrlLauncher: withUrlLauncher,
        withNotifications: withNotifications,
        withFirebaseNotifications: withFirebaseNotifications,
        withDebouncer: withDebouncer,
        withBiometric: withBiometric,
        withConnectivity: withConnectivity,
      );

  /// The locator's data layer — datasources and repositories. Same in both
  /// stacks, and where `moarch create feature` writes.
  String dataModule({
    bool withDio = false,
    bool withFirestore = false,
    bool withAuthFeature = false,
    bool withFirebaseAuthFeature = false,
    bool withFirebaseNotifications = false,
  }) =>
      InjectorTemplates.dataModule(
        withDio: withDio,
        withFirestore: withFirestore,
        withAuthFeature: withAuthFeature,
        withFirebaseAuthFeature: withFirebaseAuthFeature,
        withFirebaseNotifications: withFirebaseNotifications,
      );

  /// The locator's presentation layer — the blocs.
  ///
  /// Only meaningful when [hasPresentationModule]; callers guard on that
  /// rather than this returning something empty.
  String presentationModule({
    bool withAuthFeature = false,
    bool withLocalization = false,
  }) =>
      InjectorTemplates.presentationModule(
        withAuthFeature: withAuthFeature,
        withLocalization: withLocalization,
      );

  /// The pre-split single-file locator, for projects that still have one.
  ///
  /// See [InjectorTemplates.singleFileInjector] — nothing new is generated
  /// with this, but `moarch update` has to be able to refresh a project as
  /// the shape it actually is.
  String singleFileInjector({
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
  }) =>
      InjectorTemplates.singleFileInjector(
        stateManagement: stateManagement,
        withDio: withDio,
        withFirestore: withFirestore,
        withFirebaseAuth: withFirebaseAuth,
        withAuthFeature: withAuthFeature,
        withFirebaseAuthFeature: withFirebaseAuthFeature,
        withMedia: withMedia,
        withUrlLauncher: withUrlLauncher,
        withNotifications: withNotifications,
        withFirebaseNotifications: withFirebaseNotifications,
        withDebouncer: withDebouncer,
        withBiometric: withBiometric,
        withLocalization: withLocalization,
        withConnectivity: withConnectivity,
      );

  // ── Shared widgets ──────────────────────────────────────────────────────────

  /// Whether this stack has the `AppAsyncView` / action-listener pair.
  ///
  /// Riverpod does: `AsyncValue` is one opaque type, so something has to map
  /// it to the four screens. Bloc does not — its states are a sealed family a
  /// `switch` inside a plain `BlocBuilder` covers, and wrapping that in a
  /// widget of our own would hide the one thing bloc already does well.
  bool get hasAsyncViewWidgets => !isBloc;

  /// `AppAsyncView` — the four-state renderer. Riverpod only.
  String appAsyncView() => riverpod.AsyncTemplates.appAsyncView();

  /// `ref.listenAction(...)`, which turns a notifier's one-shot outcome into
  /// a toast, and `ref.listenChange(...)`, which hands the screen whatever
  /// else the action left on the state. Riverpod only; a bloc screen uses
  /// `BlocConsumer`'s listener.
  String actionListener() => riverpod.AsyncTemplates.actionListener();

  /// The maintenance gate.
  String maintenanceGate({bool withFirestore = false, bool withDio = false}) =>
      isBloc
          ? bloc.MaintenanceTemplates.maintenanceGate(
              withFirestore: withFirestore,
              withDio: withDio,
            )
          : riverpod.MaintenanceTemplates.maintenanceGate(
              withFirestore: withFirestore,
              withDio: withDio,
            );

  // ── Feature ─────────────────────────────────────────────────────────────────

  /// The domain entity.
  String featureEntity(String name, String cls, {bool useFirestore = false}) =>
      isBloc
          ? bloc.FeatureTemplates.entity(name, cls, useFirestore: useFirestore)
          : riverpod.FeatureTemplates.entity(name, cls,
              useFirestore: useFirestore);

  /// The repository contract.
  String featureRepositoryInterface(String name, String cls,
          {bool useFirestore = false}) =>
      isBloc
          ? bloc.FeatureTemplates.repositoryInterface(name, cls,
              useFirestore: useFirestore)
          : riverpod.FeatureTemplates.repositoryInterface(name, cls,
              useFirestore: useFirestore);

  /// The data model.
  String featureModel(String name, String cls, {bool useFirestore = false}) =>
      isBloc
          ? bloc.FeatureTemplates.model(name, cls, useFirestore: useFirestore)
          : riverpod.FeatureTemplates.model(name, cls,
              useFirestore: useFirestore);

  /// The remote datasource.
  String featureRemoteDatasource(String name, String cls, String varName,
          {bool useFirestore = false}) =>
      isBloc
          ? bloc.FeatureTemplates.remoteDatasource(name, cls, varName,
              useFirestore: useFirestore)
          : riverpod.FeatureTemplates.remoteDatasource(name, cls, varName,
              useFirestore: useFirestore);

  /// The local/cache datasource.
  String featureLocalDatasource(String name, String cls, String varName) =>
      isBloc
          ? bloc.FeatureTemplates.localDatasource(name, cls, varName)
          : riverpod.FeatureTemplates.localDatasource(name, cls, varName);

  /// The repository implementation.
  String featureRepositoryImpl(
    String name,
    String cls,
    String varName, {
    required bool hasRemote,
    required bool hasLocal,
    bool useFirestore = false,
  }) =>
      isBloc
          ? bloc.FeatureTemplates.repositoryImpl(
              name,
              cls,
              varName,
              hasRemote: hasRemote,
              hasLocal: hasLocal,
              useFirestore: useFirestore,
            )
          : riverpod.FeatureTemplates.repositoryImpl(
              name,
              cls,
              varName,
              hasRemote: hasRemote,
              hasLocal: hasLocal,
              useFirestore: useFirestore,
            );

  /// The feature state.
  ///
  /// [useFirestore] is Riverpod's alone: its state is built from the live
  /// query. A bloc's four states carry nothing the backend decides.
  String featureState(
    String name,
    String cls, {
    bool useFirestore = false,
  }) =>
      isBloc
          ? bloc.FeatureTemplates.state(name, cls)
          : riverpod.FeatureTemplates.state(name, cls,
              useFirestore: useFirestore);

  /// The feature's sealed event family — bloc only.
  String featureEvent(String name, String cls) =>
      bloc.FeatureTemplates.event(name, cls);

  /// The state holder: an `AsyncNotifier` or a `Bloc`.
  ///
  /// [hasRepository] is false when the feature was scaffolded without a data
  /// layer: the holder then loads nothing and leaves a TODO, rather than
  /// importing a repository that was never generated.
  ///
  /// [repositoryName] / [repositoryClass] point the holder at a repository
  /// other than the one named after it — what `moarch create bloc` needs when
  /// adding a second bloc to an existing feature. Bloc-only; the Riverpod
  /// notifier reads its repository through a provider.
  String featureHolder(
    String name,
    String cls,
    String varName, {
    bool useFirestore = false,
    bool hasRepository = true,
    String? repositoryName,
    String? repositoryClass,
  }) =>
      isBloc
          ? bloc.FeatureTemplates.bloc(
              name,
              cls,
              varName,
              hasRepository: hasRepository,
              repositoryName: repositoryName,
              repositoryClass: repositoryClass,
            )
          : riverpod.FeatureTemplates.notifier(
              name,
              cls,
              varName,
              useFirestore: useFirestore,
              hasRepository: hasRepository,
            );

  /// The page that creates the bloc and provides it above the view. Bloc
  /// only — see [hasPage].
  String featurePage(String name, String cls) =>
      bloc.FeatureTemplates.page(name, cls);

  /// The screen.
  String featureView(
    String name,
    String cls,
    String varName, {
    required bool hasHolder,
    bool useFirestore = false,
  }) =>
      isBloc
          ? bloc.FeatureTemplates.view(
              name,
              cls,
              varName,
              hasBloc: hasHolder,
            )
          : riverpod.FeatureTemplates.view(
              name,
              cls,
              varName,
              hasNotifier: hasHolder,
              useFirestore: useFirestore,
            );

  // ── Auth feature (REST) ─────────────────────────────────────────────────────

  /// The token-pair entity.
  String authEntity() =>
      isBloc ? bloc.AuthTemplates.entity() : riverpod.AuthTemplates.entity();

  /// The auth repository contract.
  String authRepositoryInterface({bool withPushNotifications = false}) => isBloc
      ? bloc.AuthTemplates.repositoryInterface(
          withPushNotifications: withPushNotifications)
      : riverpod.AuthTemplates.repositoryInterface(
          withPushNotifications: withPushNotifications);

  /// The token-pair model.
  String authModel() =>
      isBloc ? bloc.AuthTemplates.model() : riverpod.AuthTemplates.model();

  /// The auth datasource.
  String authRemoteDatasource({bool withPushNotifications = false}) => isBloc
      ? bloc.AuthTemplates.remoteDatasource(
          withPushNotifications: withPushNotifications)
      : riverpod.AuthTemplates.remoteDatasource(
          withPushNotifications: withPushNotifications);

  /// The auth repository implementation.
  String authRepositoryImpl({bool withPushNotifications = false}) => isBloc
      ? bloc.AuthTemplates.repositoryImpl(
          withPushNotifications: withPushNotifications)
      : riverpod.AuthTemplates.repositoryImpl(
          withPushNotifications: withPushNotifications);

  /// The auth state.
  String authState() =>
      isBloc ? bloc.AuthTemplates.state() : riverpod.AuthTemplates.state();

  /// The auth event family — bloc only.
  String authEvent() => bloc.AuthTemplates.event();

  /// The auth state holder.
  String authHolder({bool withPushNotifications = false}) => isBloc
      ? bloc.AuthTemplates.bloc(withPushNotifications: withPushNotifications)
      : riverpod.AuthTemplates.notifier(
          withPushNotifications: withPushNotifications);

  /// The login screen.
  String authLoginView() => isBloc
      ? bloc.AuthTemplates.loginView()
      : riverpod.AuthTemplates.loginView();

  /// The register screen.
  String authRegisterView() => isBloc
      ? bloc.AuthTemplates.registerView()
      : riverpod.AuthTemplates.registerView();

  // ── Auth feature (Firebase) ─────────────────────────────────────────────────

  /// The signed-in-user entity.
  String firebaseAuthEntity() => isBloc
      ? bloc.FirebaseAuthTemplates.entity()
      : riverpod.FirebaseAuthTemplates.entity();

  /// The Firebase auth repository contract.
  String firebaseAuthRepositoryInterface({
    bool withPushNotifications = false,
  }) =>
      isBloc
          ? bloc.FirebaseAuthTemplates.repositoryInterface(
              withPushNotifications: withPushNotifications)
          : riverpod.FirebaseAuthTemplates.repositoryInterface(
              withPushNotifications: withPushNotifications,
            );

  /// The signed-in-user model.
  String firebaseAuthModel({bool withFirestore = false}) => isBloc
      ? bloc.FirebaseAuthTemplates.model(withFirestore: withFirestore)
      : riverpod.FirebaseAuthTemplates.model(withFirestore: withFirestore);

  /// The FirebaseAuth + Google datasource.
  String firebaseAuthRemoteDatasource({
    bool withFirestore = false,
    bool withPushNotifications = false,
  }) =>
      isBloc
          ? bloc.FirebaseAuthTemplates.remoteDatasource(
              withFirestore: withFirestore,
              withPushNotifications: withPushNotifications,
            )
          : riverpod.FirebaseAuthTemplates.remoteDatasource(
              withFirestore: withFirestore,
              withPushNotifications: withPushNotifications,
            );

  /// The Firebase auth repository implementation.
  String firebaseAuthRepositoryImpl({
    bool withFirestore = false,
    bool withPushNotifications = false,
  }) =>
      isBloc
          ? bloc.FirebaseAuthTemplates.repositoryImpl(
              withFirestore: withFirestore,
              withPushNotifications: withPushNotifications,
            )
          : riverpod.FirebaseAuthTemplates.repositoryImpl(
              withFirestore: withFirestore,
              withPushNotifications: withPushNotifications,
            );

  /// The Firebase auth state.
  String firebaseAuthState() => isBloc
      ? bloc.FirebaseAuthTemplates.state()
      : riverpod.FirebaseAuthTemplates.state();

  /// The Firebase auth event family — bloc only.
  String firebaseAuthEvent() => bloc.FirebaseAuthTemplates.event();

  /// The Firebase auth state holder.
  String firebaseAuthHolder({bool withPushNotifications = false}) => isBloc
      ? bloc.FirebaseAuthTemplates.bloc(
          withPushNotifications: withPushNotifications)
      : riverpod.FirebaseAuthTemplates.notifier(
          withPushNotifications: withPushNotifications);

  /// The Firebase login screen.
  String firebaseAuthLoginView() => isBloc
      ? bloc.FirebaseAuthTemplates.loginView()
      : riverpod.FirebaseAuthTemplates.loginView();

  /// The Firebase register screen.
  String firebaseAuthRegisterView() => isBloc
      ? bloc.FirebaseAuthTemplates.registerView()
      : riverpod.FirebaseAuthTemplates.registerView();
}

/// The facade for this stack.
extension StateManagementTemplates on StateManagement {
  /// The templates that belong to this stack.
  StackTemplates get templates => StackTemplates(this);
}
