/// Generates feature scaffold templates.
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
  /// layer, the same provider name, a different backend behind it.
  static String remoteDatasource(
    String name,
    String cls,
    String varName, {
    bool useFirestore = false,
    bool withApiConstant = false,
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
import '../../domain/models/${name}_model.dart';

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
  /// [useFirestore] adds the `items` the live query fills in.
  static String state(String name, String cls, {bool useFirestore = false}) =>
      '''
import '../../../../core/utils/action_notifier.dart';${useFirestore ? "\nimport '../../domain/models/${name}_model.dart';" : ''}

class ${cls}State implements ActionState<${cls}State> {
  const ${cls}State({${useFirestore ? '\n    this.items = const [],' : ''}
    this.isLoadingAction = false,
    this.error,
    this.success,
  });${useFirestore ? '''

  /// The collection as of the last snapshot.
  final List<${cls}Model> items;''' : ''}

  final bool isLoadingAction;
  final String? error;
  final String? success;

  ${cls}State copyWith({${useFirestore ? '\n    List<${cls}Model>? items,' : ''}
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
  static String notifier(
    String name,
    String cls,
    String varName, {
    bool useFirestore = false,
    bool hasRepository = true,
  }) {
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

  // TODO: one method per action, each wrapped in runAction:
  //
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
    // One subscription serves the first frame and every change after it.
    final firstSnapshot = Completer<${cls}State>();

    final subscription = _repo.watchAll().listen(
      (items) {
        if (!firstSnapshot.isCompleted) {
          firstSnapshot.complete(${cls}State(items: items));
          return;
        }
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

    ref.onDispose(subscription.cancel);

    return firstSnapshot.future;
  }

  // TODO: one method per action, each wrapped in runAction. A write need not
  // touch `items`: the subscription re-emits with the change.
  //
  // Future<void> doSomething() {
  //   return runAction((current) async {
  //     await _repo.doSomething();
  //     return current.copyWith(success: 'Done!');
  //   });
  // }''' : '''  @override
  FutureOr<${cls}State> build() async {
    // TODO: put the result on the state.
    await _repo.fetchAll();
    return const ${cls}State();
  }

  // TODO: one method per action, each wrapped in runAction:
  //
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
  static String view(
    String name,
    String cls,
    String varName, {
    required bool hasNotifier,
    bool useFirestore = false,
  }) {
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
import '../widgets/${name}_skeleton.dart';

class ${cls}View extends ConsumerStatefulWidget {
  const ${cls}View({super.key});

  @override
  ConsumerState<${cls}View> createState() => _${cls}ViewState();
}

class _${cls}ViewState extends ConsumerState<${cls}View> {
  @override
  Widget build(BuildContext context) {
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
${useFirestore ? '        isEmpty: (state) => state.items.isEmpty,\n' : ''}        skeleton: (context) => const ${cls}Skeleton(),
        builder: _body,
      ),
    );
  }
${useFirestore ? '''

  // TODO: build the row.
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

  // TODO: build the screen from `state`.
  Widget _body(BuildContext context, ${cls}State state) {
    return const SizedBox.shrink();
  }'''}
}
''';
  }
}
