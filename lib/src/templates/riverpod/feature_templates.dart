/// Generates feature scaffold templates.
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
/// notifier depends on: Riverpod only rebuilds listeners when the new state
/// differs from the old one, so a hand-written `==` that misses a field
/// silently loses the change. Its `copyWith` also tells "not passed" from
/// "passed null", which `?? this.x` cannot.
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

  /// A live view of the collection: emits now with what Firestore has, and
  /// again on every change — including the ones made on this device, which
  /// land straight from the local cache before the server confirms them.
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
  /// layer, the same provider name, a different backend behind it.
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

  /// Live updates — the reason to be on Firestore at all. Errors arrive as
  /// AppException, so AppAsyncView renders them like any other failure.
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
  /// [useFirestore] adds the `items` the live query fills in. Both variants
  /// carry the `placeholder` the loading skeleton is traced from.
  static String state(String name, String cls, {bool useFirestore = false}) =>
      '''
${useFirestore ? "import 'package:skeletonizer/skeletonizer.dart';\n\n" : ''}import '../../../../core/utils/action_notifier.dart';${useFirestore ? "\nimport '../../domain/entities/${name}_entity.dart';" : ''}

class ${cls}State implements ActionState<${cls}State> {
  const ${cls}State({${useFirestore ? '\n    this.items = const [],' : ''}
    this.isLoadingAction = false,
    this.error,
    this.success,
  });
${useFirestore ? '''

  /// The state the loading skeleton is traced from — rows that exist only to
  /// be the right size.
  ///
  /// Skeletonizer shimmers the tree it is handed, so this has to hold
  /// something: a body built from an empty state traces to a blank screen.
  /// The *length* of the text sets the width of the bone, which is what
  /// `BoneMock` is for. `List.generate`, not `List.filled`, so each row is its
  /// own instance with its own id and a keyed list stays valid.
  static final placeholder = ${cls}State(
    items: List.generate(
      3,
      (index) => ${cls}Entity(id: '\${BoneMock.name}\$index'),
    ),
  );

  /// The collection as Firestore last reported it, replaced whole on every
  /// snapshot so it never drifts from the server.
  final List<${cls}Entity> items;
''' : '''

  /// The state the loading skeleton is traced from.
  ///
  /// TODO: as you add fields, give them fake values here — Skeletonizer
  /// shimmers the tree it is handed, and an empty state traces to a blank
  /// screen. `BoneMock.name` / `BoneMock.words(3)` hand out strings whose
  /// length becomes the width of the bone.
  static const placeholder = ${cls}State();
'''}

  final bool isLoadingAction;
  final String? error;
  final String? success;

  ${cls}State copyWith({${useFirestore ? '\n    List<${cls}Entity>? items,' : ''}
    bool? isLoadingAction,
    String? error,
    String? success,
  }) {
    return ${cls}State(${useFirestore ? '\n      items: items ?? this.items,' : ''}
      isLoadingAction: isLoadingAction ?? this.isLoadingAction,
      error: error,
      success: success,
    );
  }

  @override
  ${cls}State copyWithLoading() => copyWith(isLoadingAction: true);

  @override
  ${cls}State copyWithError(String message) => copyWith(error: message);
}
''';

  // ── Presentation — Notifier ─────────────────────────────────────────────────

  /// Returns the generated notifier template.
  ///
  /// [useFirestore] builds the state off `watchAll()` instead of returning an
  /// empty one, so the screen tracks the collection for as long as it is
  /// mounted. The subscription is the notifier's: Riverpod disposes it with
  /// the provider.
  ///
  /// The repository comes out of the locator rather than off another provider:
  /// `injector.dart` is where the data layer is wired, and the notifier is the
  /// seam between it and Riverpod.
  ///
  /// [hasRepository] is false when the feature was scaffolded without a data
  /// layer: `build()` is then a TODO returning an empty state, rather than
  /// resolving a repository that was never generated.
  static String notifier(String name, String cls, String varName,
      {bool useFirestore = false, bool hasRepository = true}) {
    final dependency =
        '  ${cls}Repository get _repo => getIt<${cls}Repository>();';

    final imports =
        "import '../../domain/repositories/${name}_repository.dart';";

    // No data layer to reach, so no locator and no repository to import.
    if (!hasRepository) {
      return '''
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_notifier.dart';
import '../states/${name}_state.dart';

final ${varName}NotifierProvider =
    AsyncNotifierProvider<${cls}Notifier, ${cls}State>(${cls}Notifier.new);

class ${cls}Notifier extends AsyncNotifier<${cls}State>
    with ActionNotifierMixin<${cls}State> {
  @override
  FutureOr<${cls}State> build() async {
    // TODO: load what the screen needs and put it into ${cls}State.
    return const ${cls}State();
  }

  // TODO: add your methods — runAction (from ActionNotifierMixin) handles
  // loading, AppException and unknown errors for you. It passes you the
  // pre-action state (loading off): build the next state from it.
  // Example:
  // Future<void> doSomething() {
  //   return runAction((current) async {
  //     return current.copyWith(success: 'Done!');
  //   });
  // }
}
''';
    }

    return '''
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injector.dart';
import '../../../../core/utils/action_notifier.dart';
$imports
import '../states/${name}_state.dart';

final ${varName}NotifierProvider =
    AsyncNotifierProvider<${cls}Notifier, ${cls}State>(${cls}Notifier.new);

class ${cls}Notifier extends AsyncNotifier<${cls}State>
    with ActionNotifierMixin<${cls}State> {

$dependency

${useFirestore ? '''  @override
  FutureOr<${cls}State> build() {
    // One subscription answers both the first frame and every change after
    // it. Awaiting `.first` for the initial load and then listening would
    // register the query twice — twice the billed reads, and a gap between
    // the two where a change goes unseen.
    final firstSnapshot = Completer<${cls}State>();

    final subscription = _repo.watchAll().listen(
      (items) {
        if (!firstSnapshot.isCompleted) {
          firstSnapshot.complete(${cls}State(items: items));
          return;
        }
        // Read back off `state`, not off a captured value: an action may have
        // run since the last snapshot.
        state = AsyncData(
          (state.value ?? const ${cls}State()).copyWith(items: items),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!firstSnapshot.isCompleted) {
          firstSnapshot.completeError(error, stackTrace);
          return;
        }
        state = AsyncError(error, stackTrace);
      },
    );

    // Firestore keeps the listener open until this is called; without it the
    // query outlives the screen and goes on billing reads.
    ref.onDispose(subscription.cancel);

    return firstSnapshot.future;
  }

  // TODO: add your methods — runAction (from ActionNotifierMixin) handles
  // loading, AppException and unknown errors for you. A write does not need
  // to touch `items`: the subscription above re-emits with the change, and
  // Firestore applies it to the local cache before the server confirms it.
  // Example:
  // Future<void> doSomething() {
  //   return runAction((current) async {
  //     await _repo.doSomething();
  //     return current.copyWith(success: 'Done!');
  //   });
  // }''' : '''  @override
  FutureOr<${cls}State> build() async {
    // The repository's fetchAll is a TODO until you implement it, which is
    // why this fails on the first run rather than showing an empty screen.
    // TODO: put what it returns into ${cls}State — add a field for it, give
    // that field a fake value in `placeholder`, and draw it in the view.
    await _repo.fetchAll();
    return const ${cls}State();
  }

  // TODO: add your methods — runAction (from ActionNotifierMixin) handles
  // loading, AppException and unknown errors for you. It passes you the
  // pre-action state (loading off): build the next state from it.
  // Example:
  // Future<void> doSomething() {
  //   return runAction((current) async {
  //     await _repo.doSomething();
  //     return current.copyWith(success: 'Done!');
  //   });
  // }'''}


}
''';
  }

  // ── Presentation — View ─────────────────────────────────────────────────────

  /// Returns the generated view template.
  ///
  /// [useFirestore] renders the `items` the notifier's subscription keeps
  /// current, so the screen redraws on every change to the collection without
  /// a refresh gesture or an `invalidate` anywhere.
  static String view(String name, String cls, String varName,
      {required bool hasNotifier, bool useFirestore = false}) {
    if (!hasNotifier) {
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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_async_view.dart';
import '../../../../shared/widgets/feedback/action_listener.dart';
import '../notifiers/${name}_notifier.dart';
import '../states/${name}_state.dart';

class ${cls}View extends ConsumerStatefulWidget {
  const ${cls}View({super.key});

  @override
  ConsumerState<${cls}View> createState() => _${cls}ViewState();
}

class _${cls}ViewState extends ConsumerState<${cls}View> {
  @override
  Widget build(BuildContext context) {
    // The notifier's one-shot messages, surfaced once each. Pass onError /
    // onSuccess to navigate or log instead of toasting.
    ref.listenAction<${cls}State>(
      context,
      ${varName}NotifierProvider,
      errorOf: (state) => state.error,
      successOf: (state) => state.success,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('$cls')),
      body: AppAsyncView<${cls}State>(
        value: ref.watch(${varName}NotifierProvider),
        onRetry: () => ref.invalidate(${varName}NotifierProvider),
${useFirestore ? '        isEmpty: (state) => state.items.isEmpty,\n' : ''}        // Shimmered while the first load runs: the same body, traced from
        // `${cls}State.placeholder`. That has to be *fake data* — Skeletonizer
        // shimmers the tree it is handed, and a body drawn from an empty state
        // has nothing in it to shimmer.
        skeleton: (context) => _body(context, ${cls}State.placeholder),
        builder: _body,
      ),
    );
  }
${useFirestore ? '''

  // Rebuilt on every Firestore snapshot — `state.items` is whatever the
  // collection says right now, so nothing here has to refresh it.
  //
  // TODO: build the row. It is also what the skeleton above is traced from, so
  // every field you draw here needs a fake value in `${cls}State.placeholder`.
  Widget _body(BuildContext context, ${cls}State state) {
    return ListView.builder(
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final $varName = state.items[index];
        return ListTile(
          title: Text($varName.id),
        );
      },
    );
  }''' : '''

  // TODO: build the screen. It is handed the loaded state, and it is also what
  // the skeleton above is traced from — so every field you draw here needs a
  // fake value in `${cls}State.placeholder`.
  Widget _body(BuildContext context, ${cls}State state) {
    return const SizedBox.shrink();
  }'''}
}
''';
  }
}
