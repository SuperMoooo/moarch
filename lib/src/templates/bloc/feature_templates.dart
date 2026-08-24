/// Generates feature scaffold templates for the flutter_bloc stack.
///
/// The mirror of `templates/riverpod/feature_templates.dart`: same layers,
/// same file names, same state class. What differs is the presentation layer
/// — an event per action and a `Bloc` handling them, instead of an
/// `AsyncNotifier` with methods — and the wiring, which is `get_it` rather
/// than a provider declared beside each class.
class FeatureTemplates {
  FeatureTemplates._();

  // ── Domain — Entity ─────────────────────────────────────────────────────────

  /// Returns the generated entity template.
  ///
  /// [useFirestore] makes `id` a String: a Firestore document id is the
  /// document's name, not a numeric column.
  static String entity(String name, String cls, {bool useFirestore = false}) =>
      '''
import 'package:freezed_annotation/freezed_annotation.dart';

part '${name}_entity.freezed.dart';

/// What the app reasons about, with no idea where it came from.
///
/// Freezed writes the constructor, `copyWith`, `==` and `hashCode` from the
/// field list below, so equality covers every field you add — which is what a
/// bloc state depends on: `emit` drops a state that compares equal to the
/// current one, so a hand-written `==` that misses a field silently loses the
/// change. Its `copyWith` also tells "not passed" from "passed null", which
/// `?? this.x` cannot.
///
/// No JSON here on purpose — parsing is the model's job in `data/`, so a
/// change to the API never reaches `domain/`.
///
/// Run `fvm dart run build_runner build --delete-conflicting-outputs` after
/// editing this file.
@freezed
abstract class ${cls}Entity with _\$${cls}Entity {
  const factory ${cls}Entity({
${useFirestore ? "    /// The Firestore document id.\n    required String id," : '    required int id,'}
    // TODO: add your other fields
  }) = _${cls}Entity;

  /// A blank $cls — what a create form starts from before anything is filled
  /// in. Freezed does not write this one, so it is yours to keep in step with
  /// the fields above.
  factory ${cls}Entity.empty() =>
      const ${cls}Entity(id: ${useFirestore ? "''" : '0'});
}
''';

  // ── Domain — Repository interface ───────────────────────────────────────────

  /// Returns the generated repositoryInterface template.
  ///
  /// [useFirestore] adds `watchAll` — the live read the presentation layer is
  /// built on when the data is in Firestore, with `fetchAll` left for the
  /// one-off cases (an export, a background job) that do not want a
  /// subscription.
  static String repositoryInterface(String name, String cls,
          {bool useFirestore = false}) =>
      '''
import '../entities/${name}_entity.dart';

abstract interface class ${cls}Repository {
  Future<List<${cls}Entity>> fetchAll();
${useFirestore ? '''

  /// A live view of the collection: emits now, and again on every change.
  Stream<List<${cls}Entity>> watchAll();
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
  static String _firestoreModel(String name, String cls) => '''
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/${name}_entity.dart';

part '${name}_model.freezed.dart';
part '${name}_model.g.dart';

$_modelDoc
@freezed
abstract class ${cls}Model with _\$${cls}Model {
  /// Freezed needs a private constructor before a class may declare members
  /// of its own — [toEntity] below is one.
  const ${cls}Model._();

  const factory ${cls}Model({
    /// The document's own name rather than one of its fields.
    ///
    /// `includeToJson: false` keeps it out of the body: `add()` assigns the id
    /// only once the write lands, so a copy stored beside the data is stale
    /// from the moment it is written.
    @JsonKey(includeToJson: false) required String id,
    // TODO: add your other fields, mirroring the entity's. A DateTime belongs
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

$_mappingDoc
  factory ${cls}Model.fromEntity(${cls}Entity entity) => ${cls}Model(
    id: entity.id,
  );

  ${cls}Entity toEntity() => ${cls}Entity(
    id: id,
  );
}
''';

  /// The REST payload's shape.
  static String _restModel(String name, String cls) => '''
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/${name}_entity.dart';

part '${name}_model.freezed.dart';
part '${name}_model.g.dart';

$_modelDoc
@freezed
abstract class ${cls}Model with _\$${cls}Model {
  /// Freezed needs a private constructor before a class may declare members
  /// of its own — [toEntity] below is one.
  const ${cls}Model._();

  const factory ${cls}Model({
    required int id,
    // TODO: add your other fields, mirroring the entity's. Where the payload's
    // key differs from the Dart name, say so once:
    // `@JsonKey(name: 'created_at') DateTime? createdAt,`.
  }) = _${cls}Model;

  factory ${cls}Model.fromJson(Map<String, dynamic> json) =>
      _\$${cls}ModelFromJson(json);

$_mappingDoc
  factory ${cls}Model.fromEntity(${cls}Entity entity) => ${cls}Model(
    id: entity.id,
  );

  ${cls}Entity toEntity() => ${cls}Entity(
    id: id,
  );
}
''';

  /// The header both model variants carry, explaining why the model no longer
  /// extends its entity.
  static const String _modelDoc = '''
/// The wire shape, and the only layer that knows it.
///
/// It does not extend the entity: freezed generates the concrete class, so
/// there is no constructor left to inherit. The fields are declared again here
/// and mapped explicitly below — that duplication is the price of keeping a
/// change to the payload out of `domain/`.
///
/// Run `fvm dart run build_runner build --delete-conflicting-outputs` after
/// editing this file.''';

  /// The note above the two mapping members, which is where a nested field
  /// stops being free.
  static const String _mappingDoc = '''
  // A field holding another entity has to be converted, not assigned: this
  // model holds a `ThingModel` where the entity holds a `ThingEntity`.
  //   thing: ThingModel.fromEntity(entity.thing),      // and thing.toEntity()
  //   things: entity.things.map(ThingModel.fromEntity).toList(),
  // `moarch create model <feature> <name> --from-entity` writes both from the
  // entity's own fields.''';

  // ── Data — Remote datasource ────────────────────────────────────────────────

  /// Returns the generated remoteDatasource template.
  ///
  /// [useFirestore] swaps the Dio client for `FirebaseFirestore` — the same
  /// layer, the same constructor shape, a different backend behind it.
  static String remoteDatasource(String name, String cls, String varName,
      {bool useFirestore = false}) {
    if (useFirestore) return _firestoreDatasource(name, cls, varName);

    return '''
import 'package:dio/dio.dart';

import '../../../../core/network/safe_api_call.dart';
import '../models/${name}_model.dart';

class ${cls}RemoteDataSource {
  const ${cls}RemoteDataSource(this._dio);

  final Dio _dio;

  // TODO: implement methods
  Future<${cls}Model?> fetchOne() async {
    return safeApiCall<${cls}Model>(
      apiCall: () async {
        final response = await _dio.get('/$name');
        return ${cls}Model.fromJson(response.data);
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
import '../models/${name}_model.dart';

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
  static String localDatasource(String name, String cls, String varName) => '''
class ${cls}LocalDataSource {
  // TODO: inject SharedPreferences / Hive / Isar / etc. and register the
  // dependency in config/di/injector.dart.
  // TODO: implement methods
}
''';

  // ── Data — Repository impl ───────────────────────────────────────────────────

  /// Returns the generated repositoryImpl template.
  ///
  /// [useFirestore] is implemented rather than left as a TODO: the Firestore
  /// datasource already returns the models and the live query, so all this
  /// layer has to do is map them to entities.
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
      if (hasLocal) '  final ${cls}LocalDataSource _local;',
    ].join('\n');

    // Without the remote datasource there is nothing to map, so the Firestore
    // methods stay TODOs like the REST one — the layer the user declined is
    // not invented for them.
    final methods = useFirestore && hasRemote
        ? '''
  @override
  Future<List<${cls}Entity>> fetchAll() async {
    final models = await _remote.fetchAll();
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Stream<List<${cls}Entity>> watchAll() {
    return _remote.watchAll().map(
          (models) => models.map((model) => model.toEntity()).toList(),
        );
  }'''
        : '''
  @override
  Future<List<${cls}Entity>> fetchAll() {
    // TODO: implement using the datasource(s) above
    throw UnimplementedError();
  }${useFirestore ? '''

  @override
  Stream<List<${cls}Entity>> watchAll() {
    // TODO: implement using the datasource(s) above
    throw UnimplementedError();
  }''' : ''}''';

    return '''
${hasRemote ? "import '../datasources/${name}_remote_datasource.dart';\n" : ''}${hasLocal ? "import '../datasources/${name}_local_datasource.dart';\n" : ''}import '../../domain/entities/${name}_entity.dart';
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
  /// Four states and nothing else: `Initial`, `Loading`, `Success`, `Failure`.
  /// What `Success` carries is the screen's business — the scaffold does not
  /// guess at a list of entities the feature may never show — so it starts
  /// empty, with a TODO saying where the fields and their `props` go.
  static String state(String name, String cls) => '''
import 'package:equatable/equatable.dart';

/// Every state the $cls screen can be in. Sealed, so the view's `switch` has
/// to cover all of them.
sealed class ${cls}State extends Equatable {
  const ${cls}State();

  @override
  List<Object?> get props => const [];
}

final class ${cls}Initial extends ${cls}State {
  const ${cls}Initial();
}

final class ${cls}Loading extends ${cls}State {
  const ${cls}Loading();
}

final class ${cls}Success extends ${cls}State {
  const ${cls}Success();

  // TODO: add what the screen shows, e.g.
  // `final List<${cls}Entity> items;`, and list it in `props` — without
  // that, two Success states compare equal and the second emit is dropped.
}

final class ${cls}Failure extends ${cls}State {
  const ${cls}Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
''';

  // ── Presentation — Events ───────────────────────────────────────────────────

  /// Returns the generated event template — one sealed family per bloc.
  ///
  /// Just `Started`. A refresh and a retry are the same load, so they dispatch
  /// it again rather than each getting an event of their own.
  static String event(String name, String cls) => '''
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

    final handlerTodo = '''
    // TODO: one handler per action, e.g.
    // on<${cls}Deleted>(_onDeleted, transformer: droppable());
    // `transformer:` is how events queue before the handler sees them —
    // droppable, restartable, sequential, concurrent, from bloc_concurrency.''';

    if (!hasRepository) {
      return '''
import 'package:bloc/bloc.dart';

import '${name}_event.dart';
import '${name}_state.dart';

class ${cls}Bloc extends Bloc<${cls}Event, ${cls}State> {
  ${cls}Bloc() : super(const ${cls}Initial()) {
    on<${cls}Started>(_onStarted);

$handlerTodo
  }

  Future<void> _onStarted(
    ${cls}Started event,
    Emitter<${cls}State> emit,
  ) async {
    emit(const ${cls}Loading());
    // TODO: load what the screen needs, then emit
    // ${cls}Success — or ${cls}Failure with a message.
    emit(const ${cls}Success());
  }
}
''';
    }

    return '''
import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/${repoName}_repository.dart';
import '${name}_event.dart';
import '${name}_state.dart';

class ${cls}Bloc extends Bloc<${cls}Event, ${cls}State> {
  ${cls}Bloc(this._repo) : super(const ${cls}Initial()) {
    on<${cls}Started>(_onStarted);

$handlerTodo
  }

  final ${repoCls}Repository _repo;

  Future<void> _onStarted(
    ${cls}Started event,
    Emitter<${cls}State> emit,
  ) async {
    emit(const ${cls}Loading());
    try {
      // TODO: put what this returns into ${cls}Success —
      // add a field for it there, and pass it here.
      await _repo.fetchAll();
      emit(const ${cls}Success());
    } on AppException catch (e) {
      emit(${cls}Failure(e.message));
    }
  }
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
  static String page(String name, String cls) => '''
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
  /// Plain `flutter_bloc` widgets and a `switch` over the sealed state — no
  /// wrapper of moarch's own. The bloc is provided above it by [page], so this
  /// reads it off the context and never builds one.
  static String view(String name, String cls, String varName,
      {required bool hasBloc}) {
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
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../shared/widgets/error_view.dart';
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
        listenWhen: (previous, current) => previous != current,
        listener: (context, state) {
          switch (state) {
            case ${cls}Failure(:final message):
              AppToast.error(context, message);
            // TODO: what should happen once on success — a toast, a pop.
            case ${cls}Success():
            case ${cls}Initial():
            case ${cls}Loading():
              break;
          }
        },
        builder: (context, state) => switch (state) {
          // Skeletonizer shimmers the tree it is handed, so loading traces
          // `_body` over a stand-in ${cls}Success.
          //
          // TODO: as you add fields to ${cls}Success, give them fake values
          // here — a field left empty shimmers as a blank line. `BoneMock`
          // (skeletonizer) hands out fake strings, names and dates.
          ${cls}Initial() || ${cls}Loading() => Skeletonizer(
              child: _body(context, const ${cls}Success()),
            ),
          ${cls}Failure(:final message) => ErrorView(
              message: message,
              onRetry: () =>
                  context.read<${cls}Bloc>().add(const ${cls}Started()),
            ),
          ${cls}Success() => _body(context, state),
        },
      ),
    );
  }

  // TODO: build the screen from `state`.
  Widget _body(BuildContext context, ${cls}Success state) {
    return const SizedBox.shrink();
  }
}
''';
  }
}
