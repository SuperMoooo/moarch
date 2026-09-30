import '../core/cache_templates.dart';

/// Generates feature scaffold templates for the flutter_bloc stack.
///
/// The mirror of `templates/riverpod/feature_templates.dart`: same layers,
/// same file names, and — since the status enum landed — the same one state
/// class per screen, carrying its data and the one-shot
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
  ///
  /// [withWrites] declares the queued `create` / `update` / `delete` of a
  /// synced feature.
  static String repositoryInterface(
    String name,
    String cls, {
    bool useFirestore = false,
    bool withWrites = false,
  }) =>
      '''
import '../models/${name}_model.dart';

abstract interface class ${cls}Repository {
  Future<List<${cls}Model>> fetchAll();
${useFirestore ? '''

  /// A live view of the collection: emits now, and again on every change.
  Stream<List<${cls}Model>> watchAll();
''' : ''}${withWrites ? CacheTemplates.interfaceWrites(cls) : ''}
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
  const ${cls}Model._();

  const factory ${cls}Model({
    /// The document id, kept out of `toJson` so it is not stored twice.
    @JsonKey(includeToJson: false) required String id,
    // TODO: add your fields. Annotate a DateTime with `@TimestampConverter()`
    // (core/network/timestamp_converter.dart).
  }) = _${cls}Model;

  factory ${cls}Model.fromJson(Map<String, dynamic> json) =>
      _\$${cls}ModelFromJson(json);

  /// Folds the document id into the payload.
  factory ${cls}Model.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ${cls}Model.fromJson({...?doc.data(), 'id': doc.id});

  /// A blank $cls for create forms. Keep it in step with the fields.
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
  const ${cls}Model._();

  const factory ${cls}Model({
    required int id,
    // TODO: add your fields. Keys are snake_case on the wire (build.yaml).
  }) = _${cls}Model;

  factory ${cls}Model.fromJson(Map<String, dynamic> json) =>
      _\$${cls}ModelFromJson(json);

  /// A blank $cls for create forms. Keep it in step with the fields.
  factory ${cls}Model.empty() => const ${cls}Model(id: 0);
}
''';

  /// The header both model variants carry: the one class a feature uses, on
  /// the wire and on the screen.
  static const String _modelDoc = '''
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
    bool withApiConstant = false,
    bool withSync = false,
  }) {
    if (useFirestore) return _firestoreDatasource(name, cls, varName);

    // The path is `ApiConstants.<varName>` when `create feature` could add it
    // there, and the literal otherwise.
    final constantsImport = withApiConstant
        ? "import '../../../../core/constants/api_constants.dart';\n"
        : '';
    final endpoint = withApiConstant ? 'ApiConstants.$varName' : "'/$name'";
    final todo = withApiConstant
        ? '// TODO: point ApiConstants.$varName at your endpoint, and add the\n'
              '  // others beside it in api_constants.dart.'
        : '// TODO: point this at your endpoint, and add the others beside it.';

    return '''
import 'package:dio/dio.dart';

${constantsImport}import '../../../../core/network/safe_api_call.dart';
${withSync ? "import '../../../../core/sync/sync_queue.dart';\n" : ''}import '../../domain/models/${name}_model.dart';

class ${cls}RemoteDataSource {
  const ${cls}RemoteDataSource(this._dio);

  final Dio _dio;

  $todo
  Future<List<${cls}Model>> fetchAll() {
    return safeApiCall<List<${cls}Model>>(
      apiCall: () async {
        final response = await _dio.get<List<dynamic>>($endpoint);
        return [
          for (final json in response.data ?? const <dynamic>[])
            ${cls}Model.fromJson(json as Map<String, dynamic>),
        ];
      },
    );
  }${withSync ? CacheTemplates.remoteWrites(cls, endpoint) : ''}
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

  Future<${cls}Model?> fetchOne({required String id}) {
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

  Future<void> delete({required String id}) {
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

class ${cls}State extends Equatable implements StatusState<${cls}State> {
  const ${cls}State({
    this.status = AppStatus.initial,
    this.errorMessage,
    this.successMessage,
  });

  @override
  final AppStatus status;

  /// One-shot: [copyWith] clears it unless it is passed again.
  final String? errorMessage;

  /// One-shot, like [errorMessage].
  final String? successMessage;

  // TODO: add the screen's fields, e.g. `final List<${cls}Model> items;`,
  // and add each one to the constructor, `copyWith` and `props`.

  ${cls}State copyWith({
    AppStatus? status,
    String? errorMessage,
    String? successMessage,
  }) {
    return ${cls}State(
      status: status ?? this.status,
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
    // TODO: one handler per action, each wrapped in runAction (transformers
    // come from bloc_concurrency):
    //
    // on<${cls}Deleted>(_onDeleted, transformer: droppable());
    //
    // Future<void> _onDeleted(${cls}Deleted event, Emitter<${cls}State> emit) =>
    //     runAction(emit, (current) async {
    //       ${hasRepository ? 'await _repo.delete(id: event.id);' : '// do the work, then'}
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
        // TODO: put the result on the state.
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

/// Owns the bloc: leaving the route closes it.
class ${cls}Page extends StatelessWidget {
  const ${cls}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
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
import '../widgets/${name}_skeleton.dart';

class ${cls}View extends StatelessWidget {
  const ${cls}View({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$cls')),
      body: BlocConsumer<${cls}Bloc, ${cls}State>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage ||
            previous.successMessage != current.successMessage,
        listener: (context, state) {
          final error = state.errorMessage;
          if (error != null) AppToast.error(context, error);

          final success = state.successMessage;
          if (success != null) AppToast.success(context, success);
          // TODO: other one-shot reactions (a pop, a dialog).
        },
        builder: (context, state) => AppStatusView(
          status: state.status,
          message: state.errorMessage,
          onRetry: () => context.read<${cls}Bloc>().add(const ${cls}Started()),
          // TODO: `isEmpty: state.items.isEmpty,` once the state has a list.
          skeleton: (context) => const ${cls}Skeleton(),
          builder: (context) => _body(context, state),
        ),
      ),
    );
  }

  // TODO: build the screen from `state`.
  Widget _body(BuildContext context, ${cls}State state) {
    return const SizedBox.shrink();
  }
}
''';
  }
}
