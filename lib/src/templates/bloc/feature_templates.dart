/// Generates feature scaffold templates for the flutter_bloc stack.
///
/// The mirror of `templates/riverpod/feature_templates.dart`: same layers,
/// same file names, and — since the status enum landed — the same one state
/// class per screen, carrying its data, its `placeholder` and the one-shot
/// `errorMessage` / `successMessage` the other stack keeps on `ActionState`.
/// What differs is the presentation layer — an event per action and a `Bloc`
/// handling them, instead of an `AsyncNotifier` with methods — and the wiring,
/// which is `get_it` rather than a provider declared beside each class.
class FeatureTemplates {
  FeatureTemplates._();

  // ── Domain — Repository interface ───────────────────────────────────────────

  /// Returns the generated repositoryInterface template.
  ///
  /// [useFirestore] adds `watchAll` — the live read the presentation layer is
  /// built on when the data is in Firestore, with `fetchAll` left for the
  /// one-off cases (an export, a background job) that do not want a
  /// subscription.
  static String repositoryInterface(
    String name,
    String cls, {
    bool useFirestore = false,
  }) =>
      '''
import '../models/${name}_model.dart';

abstract interface class ${cls}Repository {
  Future<List<${cls}Model>> fetchAll();
${useFirestore ? '''

  /// A live view of the collection: emits now, and again on every change.
  Stream<List<${cls}Model>> watchAll();
''' : ''}
  // TODO: add your other methods
}
''';

  // ── Data — Model ────────────────────────────────────────────────────────────

  /// Returns the generated model template.
  ///
  /// The [useFirestore] variant reads the id off the document rather than out
  /// of the payload, and leaves it out of `toJson` — writing it back as a
  /// field would store it twice, and the two copies drift.
  static String model(String name, String cls, {bool useFirestore = false}) =>
      useFirestore ? _firestoreModel(name, cls) : _restModel(name, cls);

  /// The Firestore document's shape: the id is the document's own name, and
  /// `fromDoc` puts it back into the payload rather than reading it out of it.
  static String _firestoreModel(String name, String cls) =>
      '''
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '${name}_model.freezed.dart';
part '${name}_model.g.dart';

$_modelDoc
@freezed
abstract class ${cls}Model with _\$${cls}Model {
  /// Freezed needs a private constructor before a class may declare members
  /// of its own — a getter, or a method that reads the fields.
  const ${cls}Model._();

  const factory ${cls}Model({
    /// The document's own name rather than one of its fields.
    ///
    /// `includeToJson: false` keeps it out of the body: `add()` assigns the id
    /// only once the write lands, so a copy stored beside the data is stale
    /// from the moment it is written.
    @JsonKey(includeToJson: false) required String id,
    // TODO: add your other fields. A DateTime belongs
    // on the wire as a Firestore Timestamp — annotate it `@TimestampConverter()`
    // (core/network/timestamp_converter.dart) so it stays queryable
    // server-side; an ISO string sorts as text.
  }) = _${cls}Model;

  factory ${cls}Model.fromJson(Map<String, dynamic> json) =>
      _\$${cls}ModelFromJson(json);

  /// The id lives on the document, so it is folded into the payload before
  /// parsing.
  factory ${cls}Model.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ${cls}Model.fromJson({...?doc.data(), 'id': doc.id});

  /// A blank $cls — what a create form starts from before anything is filled
  /// in. Freezed does not write this one, so it is yours to keep in step with
  /// the fields above.
  factory ${cls}Model.empty() => const ${cls}Model(id: '');
}
''';

  /// The REST payload's shape.
  static String _restModel(String name, String cls) =>
      '''
import 'package:freezed_annotation/freezed_annotation.dart';

part '${name}_model.freezed.dart';
part '${name}_model.g.dart';

$_modelDoc
@freezed
abstract class ${cls}Model with _\$${cls}Model {
  /// Freezed needs a private constructor before a class may declare members
  /// of its own — a getter, or a method that reads the fields.
  const ${cls}Model._();

  const factory ${cls}Model({
    required int id,
    // TODO: add your other fields. build.yaml maps `createdAt` to
    // `created_at`; only a key that is not snake_case needs saying:
    // `@JsonKey(name: 'createdAt') DateTime? createdAt,`.
  }) = _${cls}Model;

  factory ${cls}Model.fromJson(Map<String, dynamic> json) =>
      _\$${cls}ModelFromJson(json);

  /// A blank $cls — what a create form starts from before anything is filled
  /// in. Freezed does not write this one, so it is yours to keep in step with
  /// the fields above.
  factory ${cls}Model.empty() => const ${cls}Model(id: 0);
}
''';

  /// The header both model variants carry: the one class a feature uses, on
  /// the wire and on the screen.
  static const String _modelDoc = '''
/// What the feature reasons about, and the shape it has on the wire.
///
/// Freezed writes the constructor, `copyWith`, `==` and `hashCode` from the
/// field list below, so equality covers every field you add — which is what a
/// bloc state depends on: `emit` drops a state that compares equal to the
/// current one, so a hand-written `==` that misses a field silently loses the
/// change. Its `copyWith` also tells "not passed" from "passed null", which
/// `?? this.x` cannot.
///
/// json_serializable writes `fromJson` / `toJson` from the same field list.
/// The repository hands this class to the presentation layer as it is, so
/// every field is declared once.
///
/// Run `fvm dart run build_runner build --delete-conflicting-outputs` after
/// editing this file.''';

  // ── Data — Remote datasource ────────────────────────────────────────────────

  /// Returns the generated remoteDatasource template.
  ///
  /// [useFirestore] swaps the Dio client for `FirebaseFirestore` — the same
  /// layer, the same constructor shape, a different backend behind it.
  static String remoteDatasource(
    String name,
    String cls,
    String varName, {
    bool useFirestore = false,
  }) {
    if (useFirestore) return _firestoreDatasource(name, cls, varName);

    return '''
import 'package:dio/dio.dart';

import '../../../../core/network/safe_api_call.dart';
import '../../domain/models/${name}_model.dart';

class ${cls}RemoteDataSource {
  const ${cls}RemoteDataSource(this._dio);

  final Dio _dio;

  // TODO: point this at your endpoint, and add the others beside it.
  Future<List<${cls}Model>> fetchAll() {
    return safeApiCall<List<${cls}Model>>(
      apiCall: () async {
        final response = await _dio.get<List<dynamic>>('/$name');
        return [
          for (final json in response.data ?? const <dynamic>[])
            ${cls}Model.fromJson(json as Map<String, dynamic>),
        ];
      },
    );
  }
}
''';
  }

  /// The Firestore-backed remote datasource: one collection, read/write/watch.
  static String _firestoreDatasource(String name, String cls, String varName) =>
      '''
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/network/safe_firebase_call.dart';
import '../../domain/models/${name}_model.dart';

class ${cls}RemoteDataSource {
  const ${cls}RemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  /// TODO: point this at your collection.
  static const String collectionPath = '$name';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionPath);

  Future<List<${cls}Model>> fetchAll() {
    return safeFirebaseCall<List<${cls}Model>>(
      call: () async {
        final snapshot = await _collection.get();
        return snapshot.docs.map(${cls}Model.fromDoc).toList();
      },
    );
  }

  Future<${cls}Model?> fetchOne(String id) {
    return safeFirebaseCall<${cls}Model?>(
      call: () async {
        final doc = await _collection.doc(id).get();
        if (!doc.exists) return null;
        return ${cls}Model.fromDoc(doc);
      },
    );
  }

  /// Live updates. Errors arrive as AppException, like every other call here.
  Stream<List<${cls}Model>> watchAll() {
    return safeFirebaseStream(
      () => _collection.snapshots().map(
            (snapshot) => snapshot.docs.map(${cls}Model.fromDoc).toList(),
          ),
    );
  }

  /// Returns the id Firestore assigned to the new document.
  Future<String> create(${cls}Model model) {
    return safeFirebaseCall<String>(
      call: () async {
        final doc = await _collection.add(model.toJson());
        return doc.id;
      },
    );
  }

  /// `merge: true` so a partial model never blanks the fields it left out.
  Future<void> save(${cls}Model model) {
    return safeFirebaseCall<void>(
      call: () => _collection.doc(model.id).set(
            model.toJson(),
            SetOptions(merge: true),
          ),
    );
  }

  Future<void> delete(String id) {
    return safeFirebaseCall<void>(
      call: () => _collection.doc(id).delete(),
    );
  }
}
''';

  // ── Data — Local/cache datasource ───────────────────────────────────────────

  /// Returns the generated localDatasource template.
  static String localDatasource(String name, String cls, String varName) =>
      '''
class ${cls}LocalDataSource {
  // TODO: inject SharedPreferences / Hive / Isar / etc. and register it in
  // config/di/external_module.dart.
  // TODO: implement methods
}
''';

  // ── Data — Repository impl ───────────────────────────────────────────────────

  /// Returns the generated repositoryImpl template.
  ///
  /// [useFirestore] is implemented rather than left as a TODO: the Firestore
  /// datasource already returns the models and the live query, so this
  /// layer only hands them on.
  static String repositoryImpl(
    String name,
    String cls,
    String varName, {
    required bool hasRemote,
    required bool hasLocal,
    bool useFirestore = false,
  }) {
    final ctorParams = [
      if (hasRemote) 'this._remote',
      if (hasLocal) 'this._local',
    ].join(', ');

    final fields = [
      if (hasRemote) '  final ${cls}RemoteDataSource _remote;',
      if (hasLocal) ...[
        // Nothing reads the cache until it has methods, and the analyzer
        // flags an unread private field.
        '  // TODO: read from / write to the cache once it has methods.',
        '  // ignore: unused_field',
        '  final ${cls}LocalDataSource _local;',
      ],
    ].join('\n');

    // Both remote datasources have `fetchAll`, so the repository hands it on.
    // Without one there is nothing to return, and the layer the user declined
    // is not invented for them: the methods stay TODOs.
    final methods = hasRemote
        ? '''
  @override
  Future<List<${cls}Model>> fetchAll() {
    return _remote.fetchAll();
  }${useFirestore ? '''

  @override
  Stream<List<${cls}Model>> watchAll() {
    return _remote.watchAll();
  }''' : ''}'''
        : '''
  @override
  Future<List<${cls}Model>> fetchAll() {
    // TODO: implement using the datasource above
    throw UnimplementedError();
  }${useFirestore ? '''

  @override
  Stream<List<${cls}Model>> watchAll() {
    // TODO: implement using the datasource above
    throw UnimplementedError();
  }''' : ''}''';

    return '''
${hasRemote ? "import '../datasources/${name}_remote_datasource.dart';\n" : ''}${hasLocal ? "import '../datasources/${name}_local_datasource.dart';\n" : ''}import '../../domain/models/${name}_model.dart';
import '../../domain/repositories/${name}_repository.dart';

class ${cls}RepositoryImpl implements ${cls}Repository {
  const ${cls}RepositoryImpl($ctorParams);

$fields

$methods
}
''';
  }

  // ── Presentation — State ────────────────────────────────────────────────────

  /// Returns the generated state template.
  ///
  /// One class carrying an `AppStatus`, not a sealed state per phase. The
  /// screen's data then lives in one place, so the view's `_body` can be
  /// handed the whole state whatever the status is — a phase that draws over
  /// existing data (submitting, refreshing) is a `copyWith`, not a new class
  /// that has to declare the fields again.
  ///
  /// The status comes from `core/utils/app_status.dart` rather than being
  /// declared per feature, because `AppStatusView` switches over it.
  ///
  /// What the state carries beyond the status is the screen's business — the
  /// scaffold does not guess at a list of models the feature may never show
  /// — so it starts empty, with a TODO saying where a field goes and the four
  /// places it has to reach.
  static String state(String name, String cls) =>
      '''
import 'package:equatable/equatable.dart';

import '../../../../core/utils/app_status.dart';

/// Everything the $cls screen draws from, in one place.
///
/// A status field rather than a sealed state per phase: `_body` in the view is
/// handed this same class whatever the status is, so a field added here is
/// added once and every phase can draw it. Showing a spinner over the list
/// already on screen is a `copyWith` with the status moved to `loading` —
/// there is nothing to re-declare. The status itself is [AppStatus], shared by
/// every screen, which is what lets `AppStatusView` draw it — and being a
/// [StatusState] is what lets the bloc's `runAction` handle its errors.
class ${cls}State extends Equatable implements StatusState<${cls}State> {
  const ${cls}State({
    this.status = AppStatus.initial,
    this.errorMessage,
    this.successMessage,
  });

  /// The state the loading skeleton is traced from.
  ///
  /// TODO: as you add fields, give them fake values here — Skeletonizer
  /// shimmers the tree it is handed, and a body drawn from an empty state
  /// traces to a blank screen. `BoneMock.name` / `BoneMock.words(3)`
  /// (skeletonizer) hand out strings whose length becomes the width of the
  /// bone.
  static const placeholder = ${cls}State(status: AppStatus.success);

  @override
  final AppStatus status;

  /// Why the last attempt failed — and only the last one: [copyWith] drops
  /// this unless it is passed again, so the next emit clears it. That is what
  /// makes it safe to both draw it (the failure screen) and fire it once (a
  /// toast), and it means an action that fails without blanking the screen is
  /// `copyWith(errorMessage: e.message)` with the status left on success.
  final String? errorMessage;

  /// What went right, for the screen to say once — 'Saved', 'Sent'. Dropped
  /// by [copyWith] like [errorMessage], so the toast fires on the emit that
  /// sets it and not on the next one.
  final String? successMessage;

  // TODO: add what the screen shows, e.g.
  // `final List<${cls}Model> items;`. A field has to reach four places: the
  // constructor, `copyWith`, `props` — without which two states compare equal
  // and the second emit is dropped — and `placeholder`.

  ${cls}State copyWith({
    AppStatus? status,
    String? errorMessage,
    String? successMessage,
  }) {
    return ${cls}State(
      status: status ?? this.status,
      // Not `?? this.errorMessage`: see the two fields above. A message not
      // passed here is a message already shown.
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  ${cls}State withStatus(AppStatus status, {String? errorMessage}) =>
      copyWith(status: status, errorMessage: errorMessage);

  @override
  List<Object?> get props => [status, errorMessage, successMessage];
}
''';

  // ── Presentation — Events ───────────────────────────────────────────────────

  /// Returns the generated event template — one sealed family per bloc.
  ///
  /// Just `Started`. A refresh and a retry are the same load, so they dispatch
  /// it again rather than each getting an event of their own.
  static String event(String name, String cls) =>
      '''
import 'package:equatable/equatable.dart';

/// Everything that can happen to $cls, as values. Sealed, so the `on<...>`
/// registrations are checked for completeness when a new one is added.
sealed class ${cls}Event extends Equatable {
  const ${cls}Event();

  @override
  List<Object?> get props => const [];
}

/// Loads the screen. Dispatched when it opens, and again to refresh or retry.
final class ${cls}Started extends ${cls}Event {
  const ${cls}Started();
}

// TODO: one event per action the screen can take.
''';

  // ── Presentation — Bloc ─────────────────────────────────────────────────────

  /// Returns the generated bloc template.
  ///
  /// [hasRepository] is false when the feature was scaffolded without a data
  /// layer. The bloc then takes nothing and its handler is a TODO, rather than
  /// importing a repository that was never generated.
  ///
  /// [repositoryName] / [repositoryClass] point it at a repository other than
  /// the one named after [name]: a second bloc added to an existing feature
  /// (`moarch create bloc orders order_detail`) talks to the *feature's*
  /// repository, not to one of its own.
  static String bloc(
    String name,
    String cls,
    String varName, {
    bool hasRepository = true,
    String? repositoryName,
    String? repositoryClass,
  }) {
    final repoName = repositoryName ?? name;
    final repoCls = repositoryClass ?? cls;

    final handlerTodo =
        '''
    // TODO: one handler per action, e.g.
    // on<${cls}Deleted>(_onDeleted, transformer: droppable());
    // `transformer:` is how events queue before the handler sees them —
    // droppable, restartable, sequential, concurrent, from bloc_concurrency.
    // Wrap each handler's body in runAction (from ActionBlocMixin), which
    // handles loading and AppException for you:
    //
    // Future<void> _onDeleted(${cls}Deleted event, Emitter<${cls}State> emit) =>
    //     runAction(emit, (current) async {
    //       ${hasRepository ? 'await _repo.delete(event.id);' : '// do the work, then'}
    //       return current.copyWith(successMessage: 'Deleted');
    //     });''';

    // The first load returns its state with `status: AppStatus.success` —
    // runAction takes the status from what the action returns, and `current`
    // is still on initial here.
    final header =
        '''
import 'package:bloc/bloc.dart';

import '../../../../core/utils/app_status.dart';
${hasRepository ? "import '../../domain/repositories/${repoName}_repository.dart';\n" : ''}import '${name}_event.dart';
import '${name}_state.dart';

class ${cls}Bloc extends Bloc<${cls}Event, ${cls}State>
    with ActionBlocMixin<${cls}Event, ${cls}State> {''';

    if (!hasRepository) {
      return '''
$header
  ${cls}Bloc() : super(const ${cls}State()) {
    on<${cls}Started>(_onStarted);

$handlerTodo
  }

  Future<void> _onStarted(
    ${cls}Started event,
    Emitter<${cls}State> emit,
  ) =>
      runAction(emit, (current) async {
        // TODO: load what the screen needs and put it on the state.
        return current.copyWith(status: AppStatus.success);
      });
}
''';
    }

    return '''
$header
  ${cls}Bloc(this._repo) : super(const ${cls}State()) {
    on<${cls}Started>(_onStarted);

$handlerTodo
  }

  final ${repoCls}Repository _repo;

  Future<void> _onStarted(
    ${cls}Started event,
    Emitter<${cls}State> emit,
  ) =>
      runAction(emit, (current) async {
        // TODO: put what this returns onto the state — add a field for it in
        // ${cls}State, and pass it in the copyWith below.
        await _repo.fetchAll();
        return current.copyWith(status: AppStatus.success);
      });
}
''';
  }

  // ── Presentation — Page ─────────────────────────────────────────────────────

  /// Returns the generated page template — the bloc's owner.
  ///
  /// Its own file, one folder up from the view: the page is what a route
  /// points at and the only thing that knows the bloc is built from the
  /// locator, so the view under it stays a plain widget a test can pump with
  /// a bloc of its own.
  static String page(String name, String cls) =>
      '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/di/injector.dart';
import '../blocs/${name}_bloc.dart';
import '../blocs/${name}_event.dart';
import '../views/${name}_view.dart';

/// Creates the bloc and owns it: leaving the route closes it.
///
/// Put this in your `GoRoute` builder. If the screen is pushed from another
/// that already has the bloc, use `BlocProvider.value` instead — creating a
/// second one would give the two screens separate states.
class ${cls}Page extends StatelessWidget {
  const ${cls}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // ..add(...) here rather than in the constructor: a bloc that emits
      // during its own construction has no listener yet.
      create: (_) => getIt<${cls}Bloc>()..add(const ${cls}Started()),
      child: const ${cls}View(),
    );
  }
}
''';

  // ── Presentation — View ─────────────────────────────────────────────────────

  /// Returns the generated view template.
  ///
  /// A `BlocConsumer` whose builder is one `AppStatusView` call: the skeleton,
  /// failure and empty shells are the same in every feature anyone scaffolds,
  /// so they live in the widget and the view names only its body. `_body`
  /// takes the whole state rather than a success variant, so every status
  /// hands it the same thing and a phase drawn over already-loaded data needs
  /// no second body. The bloc is provided above this by [page], so the view
  /// reads it off the context and never builds one.
  static String view(
    String name,
    String cls,
    String varName, {
    required bool hasBloc,
  }) {
    if (!hasBloc) {
      return '''
import 'package:flutter/material.dart';

class ${cls}View extends StatelessWidget {
  const ${cls}View({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$cls')),
      body: const SizedBox.shrink(),
    );
  }
}
''';
    }

    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/app_status_view.dart';
import '../../../../shared/widgets/overlays/app_toast.dart';
import '../blocs/${name}_bloc.dart';
import '../blocs/${name}_event.dart';
import '../blocs/${name}_state.dart';

/// The bloc is provided by `${cls}Page`, so this only reads it — which is what
/// lets a widget test pump it with a bloc of its own.
class ${cls}View extends StatelessWidget {
  const ${cls}View({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$cls')),
      // `listener` is for what happens *once* on a new state — a toast, a
      // dialog, a push — and `builder` for what is drawn.
      body: BlocConsumer<${cls}Bloc, ${cls}State>(
        // Both messages are one-shot: the state that sets one is the only
        // state that carries it, so this fires once per message and never
        // replays it on the next rebuild.
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage ||
            previous.successMessage != current.successMessage,
        listener: (context, state) {
          final error = state.errorMessage;
          if (error != null) AppToast.error(context, error);

          final success = state.successMessage;
          if (success != null) AppToast.success(context, success);
          // TODO: what else should happen once — a pop, a dialog, a push.
        },
        // AppStatusView owns the three shells every screen has — skeleton,
        // failure, empty — so all this has to name is the body.
        builder: (context, state) => AppStatusView(
          status: state.status,
          message: state.errorMessage,
          onRetry: () => context.read<${cls}Bloc>().add(const ${cls}Started()),
          // TODO: once the state has a list, say when it counts as empty:
          // `isEmpty: state.items.isEmpty,`.
          skeleton: (context) => _body(context, ${cls}State.placeholder),
          builder: (context) => _body(context, state),
        ),
      ),
    );
  }

  // Handed the whole state whatever the status is, so drawing over data
  // already loaded needs nothing here.
  //
  // TODO: build the screen from `state`. It is also what the skeleton is
  // traced from, so every field you draw needs a fake value in
  // `${cls}State.placeholder` — Skeletonizer shimmers the tree it is handed,
  // and a field left empty shimmers as a blank line. `BoneMock` (skeletonizer)
  // hands out fake strings, names and dates.
  Widget _body(BuildContext context, ${cls}State state) {
    return const SizedBox.shrink();
  }
}
''';
  }
}
