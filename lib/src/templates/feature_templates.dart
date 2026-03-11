class FeatureTemplates {
  FeatureTemplates._();

  // ── Domain — Entity ─────────────────────────────────────────────────────────
  // Plain immutable class with manual copyWith and ==

  static String entity(String name, String cls) => '''
class ${cls}Entity {
  const ${cls}Entity({
    required this.id,
    // TODO: add your fields
  });

  final String id;

  ${cls}Entity copyWith({
    String? id,
  }) {
    return ${cls}Entity(
      id: id ?? this.id,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ${cls}Entity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '${cls}Entity(id: \$id)';
}
''';

  // ── Domain — Repository interface ───────────────────────────────────────────

  static String repositoryInterface(String name, String cls) => '''
import '../entities/${name}_entity.dart';

abstract interface class ${cls}Repository {
  Future<List<${cls}Entity>> getAll();
  Future<${cls}Entity> getById(String id);
  Future<void> create(${cls}Entity entity);
  Future<void> update(${cls}Entity entity);
  Future<void> delete(String id);
}
''';

  // ── Domain — Use case ───────────────────────────────────────────────────────

  static String usecase(String name, String cls) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/${name}_repository_impl.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/${name}_entity.dart';
import '../repositories/${name}_repository.dart';

final get${cls}Provider = Provider<Get$cls>(
  (ref) => Get$cls(ref.watch(${name}RepositoryProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────

class Get$cls implements NoParamsUseCase<List<${cls}Entity>> {
  const Get$cls(this._repository);

  final ${cls}Repository _repository;

  @override
  Future<List<${cls}Entity>> call() => _repository.getAll();
}
''';

  // ── Data — Model ────────────────────────────────────────────────────────────
  // Manual fromJson/toJson — no json_serializable

  static String model(String name, String cls) => '''
import '../../domain/entities/${name}_entity.dart';

class ${cls}Model {
  const ${cls}Model({
    required this.id,
    // TODO: add your fields
  });

  final String id;

  factory ${cls}Model.fromJson(Map<String, dynamic> json) {
    return ${cls}Model(
      id: json['id'] as String,
      // TODO: parse your fields
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // TODO: add your fields
    };
  }

  ${cls}Entity toEntity() => ${cls}Entity(id: id);
}
''';

  // ── Data — Remote datasource ────────────────────────────────────────────────

  static String remoteDatasource(String name, String cls) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../models/${name}_model.dart';

final ${name}RemoteDataSourceProvider = Provider<${cls}RemoteDataSource>(
  (ref) => ${cls}RemoteDataSourceImpl(ref.watch(dioClientProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────

abstract interface class ${cls}RemoteDataSource {
  Future<List<${cls}Model>> getAll();
  Future<${cls}Model> getById(String id);
}

class ${cls}RemoteDataSourceImpl implements ${cls}RemoteDataSource {
  const ${cls}RemoteDataSourceImpl(this._client);

  final DioClient _client;

  static const _endpoint = '/${name}s'; // TODO: update endpoint

  @override
  Future<List<${cls}Model>> getAll() async {
    final response = await _client.get<List<dynamic>>(_endpoint);
    return (response.data as List)
        .map((e) => ${cls}Model.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<${cls}Model> getById(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('\$_endpoint/\$id');
    return ${cls}Model.fromJson(response.data!);
  }
}
''';

  // ── Data — Local/cache datasource ───────────────────────────────────────────

  static String localDatasource(String name, String cls) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/${name}_model.dart';

final ${name}LocalDataSourceProvider = Provider<${cls}LocalDataSource>(
  (ref) => ${cls}LocalDataSourceImpl(),
);

// ─────────────────────────────────────────────────────────────────────────────

abstract interface class ${cls}LocalDataSource {
  Future<List<${cls}Model>> getCached();
  Future<void> cache(List<${cls}Model> items);
  Future<void> clear();
}

class ${cls}LocalDataSourceImpl implements ${cls}LocalDataSource {
  // TODO: inject SharedPreferences / Hive / Isar / etc.

  @override
  Future<List<${cls}Model>> getCached() async {
    // TODO: read from local storage
    return [];
  }

  @override
  Future<void> cache(List<${cls}Model> items) async {
    // TODO: persist to local storage
  }

  @override
  Future<void> clear() async {
    // TODO: clear local storage
  }
}
''';

  // ── Data — Repository impl ───────────────────────────────────────────────────

  static String repositoryImpl(
    String name,
    String cls, {
    required bool hasRemote,
    required bool hasLocal,
  }) {
    final dsImports = StringBuffer();
    final ctorParams = StringBuffer();
    final fields = StringBuffer();

    if (hasRemote) {
      dsImports.writeln("import '../datasources/${name}_remote_datasource.dart';");
      ctorParams.write('this._remote');
      fields.writeln('  final ${cls}RemoteDataSource _remote;');
    }
    if (hasLocal) {
      if (hasRemote) ctorParams.write(', ');
      ctorParams.write('this._local');
      fields.writeln('  final ${cls}LocalDataSource _local;');
    }

    final providerArgs = [
      if (hasRemote) 'ref.watch(${name}RemoteDataSourceProvider)',
      if (hasLocal) 'ref.watch(${name}LocalDataSourceProvider)',
    ].join(',\n    ');

    return '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/logger.dart';
${hasRemote ? "import '../datasources/${name}_remote_datasource.dart';" : ''}
${hasLocal ? "import '../datasources/${name}_local_datasource.dart';" : ''}
import '../../domain/entities/${name}_entity.dart';
import '../../domain/repositories/${name}_repository.dart';

final ${name}RepositoryProvider = Provider<${cls}Repository>(
  (ref) => ${cls}RepositoryImpl(
    $providerArgs
  ),
);

// ─────────────────────────────────────────────────────────────────────────────

class ${cls}RepositoryImpl implements ${cls}Repository {
  const ${cls}RepositoryImpl($ctorParams);

$fields
  @override
  Future<List<${cls}Entity>> getAll() async {
    try {
${hasRemote ? '      final models = await _remote.getAll();' : '      final models = <dynamic>[];'}
${hasLocal ? '      await _local.cache(models);' : ''}
      return models.map((m) => m.toEntity()).toList();
    } on AppException catch (e, st) {
      AppLogger.error('${cls}Repository.getAll', e, st);
      throw ServerFailure(message: e.message, statusCode: e.statusCode);
    } catch (e, st) {
      AppLogger.error('${cls}Repository.getAll (unknown)', e, st);
      throw UnknownFailure(message: e.toString());
    }
  }

  @override
  Future<${cls}Entity> getById(String id) async {
    try {
${hasRemote ? '      return (await _remote.getById(id)).toEntity();' : '      throw UnimplementedError();'}
    } on AppException catch (e, st) {
      AppLogger.error('${cls}Repository.getById', e, st);
      throw ServerFailure(message: e.message, statusCode: e.statusCode);
    } catch (e, st) {
      AppLogger.error('${cls}Repository.getById (unknown)', e, st);
      throw UnknownFailure(message: e.toString());
    }
  }

  @override
  Future<void> create(${cls}Entity entity) async {
    // TODO: implement
  }

  @override
  Future<void> update(${cls}Entity entity) async {
    // TODO: implement
  }

  @override
  Future<void> delete(String id) async {
    // TODO: implement
  }
}
''';
  }

  // ── Presentation — State ────────────────────────────────────────────────────
  // Plain class with safe copyWith — nullable fields use explicit clear flags

  static String state(String name, String cls) => '''
import '../../domain/entities/${name}_entity.dart';

class ${cls}State {
  const ${cls}State({
    this.isLoading = false,
    this.isLoadingAction = false,
    this.items = const [],
    this.error,
    this.success,
  });

  final bool isLoading;
  final bool isLoadingAction;
  final List<${cls}Entity> items;
  final String? error;
  final String? success;

  ${cls}State copyWith({
    bool? isLoading,
    bool? isLoadingAction,
    List<${cls}Entity>? items,
    String? error,
    String? success,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ${cls}State(
      isLoading: isLoading ?? this.isLoading,
      isLoadingAction: isLoadingAction ?? this.isLoadingAction,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
      success: clearSuccess ? null : (success ?? this.success),
    );
  }
}
''';

  // ── Presentation — Notifier ─────────────────────────────────────────────────

  static String notifier(String name, String cls, {required bool hasUseCase}) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

${hasUseCase ? "import '../../domain/usecases/get_$name.dart';" : "import '../../../data/repositories/${name}_repository_impl.dart';"}
import '${name}_state.dart';

final ${name}NotifierProvider =
    AsyncNotifierProvider<${cls}Notifier, ${cls}State>(${cls}Notifier.new);

// ─────────────────────────────────────────────────────────────────────────────

class ${cls}Notifier extends AsyncNotifier<${cls}State> {
  @override
  Future<${cls}State> build() async {
    return const ${cls}State();
  }

  Future<void> load() async {
    final current = state.value ?? const ${cls}State();
    state = AsyncData(current.copyWith(isLoading: true, clearError: true));
    try {
${hasUseCase ? '      final items = await ref.read(get${cls}Provider).call();' : '      final items = await ref.read(${name}RepositoryProvider).getAll();'}
      state = AsyncData(current.copyWith(isLoading: false, items: items));
    } catch (e) {
      state = AsyncData(current.copyWith(isLoading: false, error: e.toString()));
    }
  }

  // Example action with isLoadingAction (e.g. create / delete)
  Future<bool> create(/* TODO: your params */) async {
    final current = state.value;
    if (current == null) return false;
    try {
      state = AsyncData(current.copyWith(isLoadingAction: true, clearError: true));
      // TODO: await repo.create(...)
      state = AsyncData(current.copyWith(
        isLoadingAction: false,
        success: '${cls} created successfully',
      ));
      return true;
    } catch (e) {
      state = AsyncData(current.copyWith(isLoadingAction: false, error: e.toString()));
      return false;
    }
  }

  void clearMessages() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true, clearSuccess: true));
  }
}
''';

  // ── Presentation — View ─────────────────────────────────────────────────────

  static String view(String name, String cls, {required bool hasNotifier}) => '''
import 'package:flutter/material.dart';
${hasNotifier ? "import 'package:flutter_riverpod/flutter_riverpod.dart';" : ''}

import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/error_view.dart';
${hasNotifier ? "import '../notifiers/${name}_notifier.dart';" : ''}

class ${cls}View extends ${hasNotifier ? 'ConsumerStatefulWidget' : 'StatelessWidget'} {
  const ${cls}View({super.key});

  static const routeName = '/$name';

${hasNotifier ? '''  @override
  ConsumerState<${cls}View> createState() => _${cls}ViewState();
}

class _${cls}ViewState extends ConsumerState<${cls}View> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(${name}NotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(${name}NotifierProvider);

    // Show snackbars for error/success messages
    ref.listen(${name}NotifierProvider, (_, next) {
      final state = next.value;
      if (state == null) return;
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
        );
        ref.read(${name}NotifierProvider.notifier).clearMessages();
      }
      if (state.success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.success!)),
        );
        ref.read(${name}NotifierProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('$cls')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(${name}NotifierProvider.notifier).load(),
        ),
        data: (state) {
          if (state.isLoading) return const AppLoading();

          return Stack(
            children: [
              ListView.builder(
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return ListTile(
                    title: Text(item.id),
                    // TODO: render your fields
                  );
                },
              ),
              if (state.isLoadingAction)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: AppLoading(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}''' : '''  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$cls')),
      body: const Center(child: Text('$cls')),
    );
  }
}'''}
''';
}
