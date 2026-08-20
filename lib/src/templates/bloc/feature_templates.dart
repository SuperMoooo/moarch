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
class ${cls}Entity {
  const ${cls}Entity({
    required this.id,
  });

  ${useFirestore ? '/// The Firestore document id.\n  final String id;' : 'final int id;'}

  // TODO: add copyWith if needed

  @override
  bool operator ==(Object other) =>
      other is ${cls}Entity && other.id == id;

  @override
  int get hashCode => id.hashCode;
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
  static String model(String name, String cls, {bool useFirestore = false}) {
    if (useFirestore) {
      return '''
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/${name}_entity.dart';

class ${cls}Model extends ${cls}Entity {
  const ${cls}Model({
    required super.id,
  });

  factory ${cls}Model.fromJson(Map<String, dynamic> json, {required String id}) {
    return ${cls}Model(
      id: id,
      // TODO: parse your other fields
    );
  }

  /// The id lives on the document, not in its data.
  factory ${cls}Model.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ${cls}Model.fromJson(doc.data() ?? const <String, dynamic>{}, id: doc.id);

  Map<String, dynamic> toJson() {
    return {
      // TODO: add your other fields — not `id`, Firestore keys the document by it
    };
  }

  factory ${cls}Model.fromEntity(${cls}Entity entity) => ${cls}Model(
    id: entity.id,
  );

  ${cls}Entity toEntity() =>
      ${cls}Entity(
        id: id,
      );
}
''';
    }

    return '''
import '../../domain/entities/${name}_entity.dart';

class ${cls}Model extends ${cls}Entity{
   const ${cls}Model({
    required super.id,
  });

  factory ${cls}Model.fromJson(Map<String, dynamic> json) {
    return ${cls}Model(
      id: json['id'] as int,
      // TODO: parse your other fields
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // TODO: add your other fields
    };
  }

  factory ${cls}Model.fromEntity(${cls}Entity entity) => ${cls}Model(
    id: entity.id,
  );

  ${cls}Entity toEntity() =>
      ${cls}Entity(
        id: id,
      );
}
''';
  }

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
  /// Both variants carry `items` and the `placeholder` the loading skeleton is
  /// traced from: the repository's `fetchAll()` returns a list of the entity
  /// whichever backend the feature was generated against, so the state that
  /// holds the result has the same shape either way. Only how it gets filled
  /// differs — a subscription under [useFirestore], a one-off fetch otherwise,
  /// and that is the datasource's business rather than the state's.
  ///
  /// [entityName] / [entityClass] name the entity the items are, when that is
  /// not the one named after [name] — a second bloc in a feature lists the
  /// feature's entity, not one of its own.
  ///
  /// [entityIdIsString] is what the placeholder's fake ids are built from. It
  /// tracks the entity, not the backend: a Firestore-shaped entity keys on a
  /// document name, a REST one on a column. Defaults to [useFirestore], which
  /// is right for a feature whose entity was generated alongside this state.
  static String state(
    String name,
    String cls, {
    bool useFirestore = false,
    String? entityName,
    String? entityClass,
    bool? entityIdIsString,
  }) {
    final itemName = entityName ?? name;
    final itemCls = entityClass ?? cls;
    // A string id gets a fake name whose length sets the bone's width; an int
    // id has no width to fake, so the row index does.
    final idIsString = entityIdIsString ?? useFirestore;
    // Raw: this is interpolated into the template, so it has to already read
    // as the Dart the generated file should contain.
    final fakeId = idIsString ? r"'${BoneMock.name}$index'" : 'index';
    // BoneMock is skeletonizer's, so the import follows the id that uses it —
    // the entity's key type, not the backend sitting behind it.
    final skeletonizerImport =
        idIsString ? "import 'package:skeletonizer/skeletonizer.dart';\n" : '';

    // Where the items come from is the only thing the two variants disagree
    // on; that they are there is not.
    final itemsDoc = useFirestore
        ? 'The collection as Firestore last reported it.'
        : 'The collection as the last load returned it.';

    return '''
import 'package:equatable/equatable.dart';
$skeletonizerImport
import '../../domain/entities/${itemName}_entity.dart';

/// Every state the $cls screen can be in. Sealed, so the view's `switch` has
/// to handle all of them.
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
  const ${cls}Success({
    this.items = const [],
  });

  /// Fake rows the loading skeleton is traced from.
  ///
  /// TODO: give new entity fields fake values here too — an empty row
  /// shimmers as a blank line. `BoneMock.name` hands out fake strings.
  static final placeholder = ${cls}Success(
    items: List.generate(3, (index) => ${itemCls}Entity(id: $fakeId)),
  );

  /// $itemsDoc
  final List<${itemCls}Entity> items;

  ${cls}Success copyWith({List<${itemCls}Entity>? items}) =>
      ${cls}Success(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}

final class ${cls}Failure extends ${cls}State {
  const ${cls}Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
''';
  }

  // ── Presentation — Events ───────────────────────────────────────────────────

  /// Returns the generated event template — one sealed family per feature.
  ///
  /// Sealed, so `on<...>` registrations and any `switch` over an event are
  /// checked for completeness when a new one is added.
  ///
  /// [entityClass] names the entity a snapshot carries, when that is not the
  /// one named after [name].
  static String event(
    String name,
    String cls, {
    bool useFirestore = false,
    String? entityName,
    String? entityClass,
  }) {
    final itemName = entityName ?? name;
    final itemCls = entityClass ?? cls;

    // Only the live variant names an entity — the snapshot event carries one.
    final entityImport = useFirestore
        ? "import '../../domain/entities/${itemName}_entity.dart';\n\n"
        : '';

    return '''
import 'package:equatable/equatable.dart';
$entityImport
/// Everything that can happen to $cls, as values.
///
/// [Equatable] so two of the same event compare equal — what an
/// `EventTransformer` like `distinct()` needs, and what a test asserts on.
/// It does not dedupe on its own: every event added is still handled.
sealed class ${cls}Event extends Equatable {
  const ${cls}Event();

  @override
  List<Object?> get props => const [];
}

/// Dispatched once when the screen opens${useFirestore ? ' — subscribes to the collection' : ''}.
final class ${cls}Started extends ${cls}Event {
  const ${cls}Started();
}
${useFirestore ? '''
/// One snapshot from the collection. The bloc adds it to itself from its
/// subscription, and nothing else should.
final class ${cls}ItemsUpdated extends ${cls}Event {
  const ${cls}ItemsUpdated(this.items);

  final List<${itemCls}Entity> items;

  @override
  List<Object?> get props => [items];
}

/// The subscription failed — the collection could not be read.
final class ${cls}Failed extends ${cls}Event {
  const ${cls}Failed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;

  @override
  List<Object?> get props => [error, stackTrace];
}
''' : ''}
/// Re-runs the load. What the error state's retry button dispatches.
final class ${cls}Refreshed extends ${cls}Event {
  const ${cls}Refreshed();
}

// TODO: add an event per action the screen can take, e.g.
// final class ${cls}Deleted extends ${cls}Event {
//   const ${cls}Deleted(this.id);
//   final ${useFirestore ? 'String' : 'int'} id;
//   @override
//   List<Object?> get props => [id];
// }
''';
  }

  // ── Presentation — Bloc ─────────────────────────────────────────────────────

  /// Returns the generated bloc template.
  ///
  /// [useFirestore] subscribes to `watchAll()` and feeds every snapshot back
  /// in as an event, so the screen tracks the collection for as long as the
  /// bloc lives. The subscription is the bloc's: `close()` cancels it.
  ///
  /// [repositoryName] names the repository this bloc depends on, when that is
  /// not the one named after [name]: a second bloc added to an existing
  /// feature (`moarch create bloc orders order_detail`) talks to the
  /// *feature's* repository, not to one of its own.
  static String bloc(
    String name,
    String cls,
    String varName, {
    bool useFirestore = false,
    String? repositoryName,
    String? repositoryClass,
  }) {
    final repoName = repositoryName ?? name;
    final repoCls = repositoryClass ?? cls;

    final repoDependency =
        '  ${cls}Bloc(this._repo) : super(const ${cls}Initial()) {';

    final fields = '  final ${repoCls}Repository _repo;';

    final repoImport =
        "import '../../domain/repositories/${repoName}_repository.dart';\n";

    if (useFirestore) {
      return '''
import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/${repoName}_entity.dart';
import '../../domain/repositories/${repoName}_repository.dart';
import '${name}_event.dart';
import '${name}_state.dart';

class ${cls}Bloc extends Bloc<${cls}Event, ${cls}State> {
  ${cls}Bloc(this._repo) : super(const ${cls}Initial()) {
    on<${cls}Started>(_onStarted);
    on<${cls}Refreshed>(_onStarted);
    on<${cls}ItemsUpdated>(_onItemsUpdated);
    on<${cls}Failed>(_onFailed);

    // TODO: one handler per action. A write does not emit on success and does
    // not touch `items` — the subscription below re-emits with the change.
    //
    // on<${cls}Deleted>((event, emit) async {
    //   try {
    //     await _repo.delete(event.id);
    //   } on AppException catch (e) {
    //     emit(${cls}Failure(e.message));
    //   }
    // }, transformer: droppable());
  }

  final ${repoCls}Repository _repo;

  StreamSubscription<List<${repoCls}Entity>>? _subscription;

  void _onStarted(${cls}Event event, Emitter<${cls}State> emit) {
    // Re-subscribing on a refresh would leave the old query open and billing.
    _subscription?.cancel();
    // Only blank the screen when there is nothing on it: a refresh over a
    // loaded list keeps the list.
    if (state is! ${cls}Success) emit(const ${cls}Loading());

    // Events rather than `emit` directly: an emit from a callback outliving
    // its handler throws.
    _subscription = _repo.watchAll().listen(
          (items) => add(${cls}ItemsUpdated(items)),
          onError: (Object error, StackTrace stackTrace) =>
              add(${cls}Failed(error, stackTrace)),
        );
  }

  void _onItemsUpdated(${cls}ItemsUpdated event, Emitter<${cls}State> emit) {
    final current = state;
    emit(
      current is ${cls}Success
          ? current.copyWith(items: event.items)
          : ${cls}Success(items: event.items),
    );
  }

  void _onFailed(${cls}Failed event, Emitter<${cls}State> emit) {
    final error = event.error;
    emit(
      ${cls}Failure(
        error is AppException ? error.message : 'Could not read $cls',
      ),
    );
  }

  @override
  Future<void> close() {
    // Without this the query outlives the screen and goes on billing reads.
    _subscription?.cancel();
    return super.close();
  }
}
''';
    }

    return '''
import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_exception.dart';
${repoImport}import '${name}_event.dart';
import '${name}_state.dart';

class ${cls}Bloc extends Bloc<${cls}Event, ${cls}State> {
$repoDependency
    on<${cls}Started>(_onStarted);
    on<${cls}Refreshed>(_onStarted);

    // TODO: one handler per action, e.g.
    // on<${cls}Deleted>(_onDeleted, transformer: droppable());
    //
    // `transformer:` is how events queue before the handler sees them —
    // droppable, restartable, sequential, concurrent, from bloc_concurrency.
  }

$fields

  Future<void> _onStarted(${cls}Event event, Emitter<${cls}State> emit) async {
    // A refresh over loaded data keeps the data on screen.
    if (state is! ${cls}Success) emit(const ${cls}Loading());
    try {
      final items = await _repo.fetchAll();
      emit(${cls}Success(items: items));
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

/// Creates the bloc and owns it: leaving the route closes it, and with it any
/// subscription it holds.
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
  /// wrapper of moarch's own. The bloc is provided above it by [page], so
  /// this reads it off the context and never builds one.
  ///
  /// [useFirestore] renders the `items` the bloc's subscription keeps current,
  /// so the screen redraws on every change to the collection without a refresh
  /// gesture.
  static String view(String name, String cls, String varName,
      {required bool hasBloc, bool useFirestore = false}) {
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

    // Only the live variant draws the list, so only it has an empty case. The
    // guard goes above the unguarded `${cls}Success()` arm, which would
    // otherwise swallow it.
    final emptyCase = useFirestore
        ? '          ${cls}Success(:final items) when items.isEmpty =>\n'
            '            const EmptyView(),\n'
        : '';

    final emptyImport = useFirestore
        ? "import '../../../../shared/widgets/empty_view.dart';\n"
        : '';

    final body = useFirestore
        ? '''


  // TODO: build the row. Every field drawn here needs a fake value in
  // `${cls}Success.placeholder`, or the skeleton traces a blank line.
  Widget _body(BuildContext context, ${cls}Success state) {
    return ListView.builder(
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final $varName = state.items[index];
        return ListTile(
          title: Text($varName.id),
        );
      },
    );
  }'''
        : '''


  // TODO: build the screen from `state.items`. Every field drawn here needs a
  // fake value in `${cls}Success.placeholder`, or the skeleton traces a blank
  // line.
  Widget _body(BuildContext context, ${cls}Success state) {
    return const SizedBox.shrink();
  }''';

    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

${emptyImport}import '../../../../shared/widgets/error_view.dart';
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
            case ${cls}Success():
              // TODO: what should happen once — a toast, a pop, a redirect.
              break;
            case ${cls}Initial():
            case ${cls}Loading():
              break;
          }
        },
        builder: (context, state) => switch (state) {
          // Traced from `${cls}Success.placeholder` — Skeletonizer shimmers
          // the tree it is handed, so that has to hold fake data.
          ${cls}Initial() || ${cls}Loading() => Skeletonizer(
              child: _body(context, ${cls}Success.placeholder),
            ),
          ${cls}Failure(:final message) => ErrorView(
              message: message,
              onRetry: () =>
                  context.read<${cls}Bloc>().add(const ${cls}Refreshed()),
            ),
$emptyCase          ${cls}Success() => _body(context, state),
        },
      ),
    );
  }$body
}
''';
  }
}
