/// Generates feature scaffold templates.
class FeatureTemplates {
  FeatureTemplates._();

  // ── Domain — Entity ─────────────────────────────────────────────────────────

  /// Returns the generated entity template.
  static String entity(String name, String cls) => '''
class ${cls}Entity {
  const ${cls}Entity({
    required this.id,
  });

  final int id;

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
  static String repositoryInterface(String name, String cls) => '''
import '../entities/${name}_entity.dart';

abstract interface class ${cls}Repository {
  Future<List<${cls}Entity>> getAll();

  // TODO: add your other methods
}
''';

  // ── Domain — Use case ───────────────────────────────────────────────────────

  /// Returns the generated usecase template.
  static String usecase(String name, String cls, String varName) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/${name}_repository_impl.dart';
import '../entities/${name}_entity.dart';
import '../repositories/${name}_repository.dart';

final get${cls}Provider = Provider<Get$cls>(
  (ref) => Get$cls(ref.watch(${varName}RepositoryProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────

class Get$cls {
  const Get$cls(this._repository);

  final ${cls}Repository _repository;

  Future<List<${cls}Entity>> call() => _repository.getAll();
}
''';

  // ── Data — Model ────────────────────────────────────────────────────────────

  /// Returns the generated model template.
  static String model(String name, String cls) => '''
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

  // ── Data — Remote datasource ────────────────────────────────────────────────

  /// Returns the generated remoteDatasource template.
  static String remoteDatasource(String name, String cls, String varName) => '''
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/safe_api_call.dart';
import '../models/${name}_model.dart';

final ${varName}RemoteDataSourceProvider = Provider<${cls}RemoteDataSource>(
  (ref) => ${cls}RemoteDataSource(ref.watch(dioClientProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────


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

  // ── Data — Local/cache datasource ───────────────────────────────────────────

  /// Returns the generated localDatasource template.
  static String localDatasource(String name, String cls, String varName) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/${name}_model.dart';

final ${varName}LocalDataSourceProvider = Provider<${cls}LocalDataSource>(
  (ref) => ${cls}LocalDataSource(),
);

// ─────────────────────────────────────────────────────────────────────────────



class ${cls}LocalDataSource {
  // TODO: inject SharedPreferences / Hive / Isar / etc.
  // TODO: implement methods
}
''';

  // ── Data — Repository impl ───────────────────────────────────────────────────

  /// Returns the generated repositoryImpl template.
  static String repositoryImpl(
    String name,
    String cls,
    String varName, {
    required bool hasRemote,
    required bool hasLocal,
  }) {
    final providerArgs = [
      if (hasRemote) '      ref.watch(${varName}RemoteDataSourceProvider),',
      if (hasLocal) '      ref.watch(${varName}LocalDataSourceProvider),',
    ].join('\n');

    final ctorParams = [
      if (hasRemote) 'this._remote',
      if (hasLocal) 'this._local',
    ].join(', ');

    final fields = [
      if (hasRemote) '  final ${cls}RemoteDataSource _remote;',
      if (hasLocal) '  final ${cls}LocalDataSource _local;',
    ].join('\n');

    return '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
${hasRemote ? "import '../datasources/${name}_remote_datasource.dart';" : ''}
${hasLocal ? "import '../datasources/${name}_local_datasource.dart';" : ''}
import '../../domain/entities/${name}_entity.dart';
import '../../domain/repositories/${name}_repository.dart';

final ${varName}RepositoryProvider = Provider<${cls}Repository>(
  (ref) => ${cls}RepositoryImpl(
$providerArgs
  ),
);

// ─────────────────────────────────────────────────────────────────────────────

class ${cls}RepositoryImpl implements ${cls}Repository {
  const ${cls}RepositoryImpl($ctorParams);

$fields

  @override
  Future<List<${cls}Entity>> getAll() {
    // TODO: implement using the datasource(s) above
    throw UnimplementedError();
  }
}
''';
  }

  // ── Presentation — State ────────────────────────────────────────────────────

  /// Returns the generated state template.
  static String state(String name, String cls) => '''
import '../../../../core/utils/action_notifier.dart';

class ${cls}State implements ActionState<${cls}State> {
  const ${cls}State({
    this.isLoadingAction = false,
    this.error,
    this.success,
  });

  final bool isLoadingAction;

  /// One-shot UI event fields: any copyWith call that omits them clears
  /// them, so a message is only surfaced once.
  final String? error;
  final String? success;

  ${cls}State copyWith({
    bool? isLoadingAction,
    String? error,
    String? success,
  }) {
    return ${cls}State(
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
  static String notifier(String name, String cls, String varName,
          {required bool hasUseCase}) =>
      '''
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/action_notifier.dart';

import '../../data/repositories/${name}_repository_impl.dart';
${hasUseCase ? "import '../../domain/usecases/get_$name.dart';" : ''}
import '../../domain/repositories/${name}_repository.dart';
import '../states/${name}_state.dart';

final ${varName}NotifierProvider =
    AsyncNotifierProvider<${cls}Notifier, ${cls}State>(${cls}Notifier.new);

// ─────────────────────────────────────────────────────────────────────────────

class ${cls}Notifier extends AsyncNotifier<${cls}State>
    with ActionNotifierMixin<${cls}State> {

  ${cls}Repository get _repo => ref.watch(${varName}RepositoryProvider);

  @override
  FutureOr<${cls}State> build() async {
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
  // }


}
''';

  // ── Presentation — View ─────────────────────────────────────────────────────

  /// Returns the generated view template.
  static String view(String name, String cls, String varName,
      {required bool hasNotifier}) {
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
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../shared/widgets/error_view.dart';
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
    final ${varName}Async = ref.watch(${varName}NotifierProvider);
    ref.listen(${varName}NotifierProvider, (_, next) {
      final value = next.value;
      if (value == null) return;
      if (value.error != null) {
        // SHOW UI ERROR
      }
      if (value.success != null) {
        // SHOW UI SUCCESS
      }
    });

    Widget mainWidget(${cls}State? state) {
      return const SizedBox.shrink();
    }

    return ${varName}Async.when(
      data: (state) => mainWidget(state),
      loading: () => Skeletonizer(
        enabled: true,
        child: mainWidget(null),
      ),
      error: (_, __) => const ErrorView(message: 'Failed to load $cls'),
    );
  }
}
''';
  }
}
