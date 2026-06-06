/// Generates feature scaffold templates.
class FeatureTemplates {
  FeatureTemplates._();

  // ── Domain — Entity ─────────────────────────────────────────────────────────

  /// Returns the generated entity template.
  static String entity(String name, String cls) => '''
class ${cls}Entity {


  // TODO: add copyWith, ==, hashCode if needed
}
''';

  // ── Domain — Repository interface ───────────────────────────────────────────

  /// Returns the generated repositoryInterface template.
  static String repositoryInterface(String name, String cls) => '''
import '../entities/${name}_entity.dart';

abstract interface class ${cls}Repository {
  // TODO: add your methods
}
''';

  // ── Domain — Use case ───────────────────────────────────────────────────────

  /// Returns the generated usecase template.
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

  /// Returns the generated model template.
  static String model(String name, String cls) => '''
import '../../domain/entities/${name}_entity.dart';

class ${cls}Model extends ${cls}Entity{
   ${cls}Model();

  factory ${cls}Model.fromJson(Map<String, dynamic> json) {
    return ${cls}Model(
      // TODO: parse your fields
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // TODO: add your fields
    };
  }

  factory ${cls}Model.fromEntity(${cls}Entity entity) => ${cls}Model(
  );

  ${cls}Entity toEntity() =>
      ${cls}Entity();
}
''';

  // ── Data — Remote datasource ────────────────────────────────────────────────

  /// Returns the generated remoteDatasource template.
  static String remoteDatasource(String name, String cls) => '''
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../models/${name}_model.dart';

final ${name}RemoteDataSourceProvider = Provider<${cls}RemoteDataSource>(
  (ref) => ${cls}RemoteDataSource(ref.watch(dioClientProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────


class ${cls}RemoteDataSource {
  const ${cls}RemoteDataSource(this._dio);

  final Dio _dio;

  // TODO: implement methods
}
''';

  // ── Data — Local/cache datasource ───────────────────────────────────────────

  /// Returns the generated localDatasource template.
  static String localDatasource(String name, String cls) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/${name}_model.dart';

final ${name}LocalDataSourceProvider = Provider<${cls}LocalDataSource>(
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
    String cls, {
    required bool hasRemote,
    required bool hasLocal,
  }) {
    final providerArgs = [
      if (hasRemote) '      ref.watch(${name}RemoteDataSourceProvider),',
      if (hasLocal) '      ref.watch(${name}LocalDataSourceProvider),',
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

  // TODO: implement methods
  // Catch DioException and throw AppException:
  //
  // } on DioException catch (e) {
  //    AppException.fromDioError(e);
  // }
}
''';
  }

  // ── Presentation — State ────────────────────────────────────────────────────

  /// Returns the generated state template.
  static String state(String name, String cls) => '''
class ${cls}State {
  const ${cls}State({
    this.isLoadingAction = false,
    this.error,
    this.success,
  });

  final bool isLoadingAction;
  final String? error;
  final String? success;

  ${cls}State copyWith({
    bool? isLoadingAction,
    String? error,
    String? success,
  }) {
    return ${cls}State(
      isLoadingAction: isLoadingAction ?? false,
      error: error,
      success: success,
    );
  }
}
''';

  // ── Presentation — Notifier ─────────────────────────────────────────────────

  /// Returns the generated notifier template.
  static String notifier(String name, String cls, {required bool hasUseCase}) =>
      '''
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';

${hasUseCase ? "import '../../domain/usecases/get_$name.dart';" : "import '../../data/repositories/${name}_repository_impl.dart';"}
import '../../domain/repositories/${name}_repository.dart';
import '../states/${name}_state.dart';

final ${name}NotifierProvider =
    AsyncNotifierProvider<${cls}Notifier, ${cls}State>(${cls}Notifier.new);

// ─────────────────────────────────────────────────────────────────────────────

class ${cls}Notifier extends AsyncNotifier<${cls}State> {

  ${cls}Repository get _repo => ref.watch(${name}RepositoryProvider);

  @override
  FutureOr<${cls}State> build() async {
  try {
     return const ${cls}State();
    } on AppException catch (_) {
      return const ${cls}State();
    } catch (e) {
      appLogger.e(e);
      return const ${cls}State();
    }
    
  }

  // TODO: add your methods
  // Example:
  // Future<void> doSomething() async {
  //   final current = state.value;
  //   if (current == null) return;
  //   state = AsyncData(current.copyWith(isLoadingAction: true));
  //   try {
  //     // await ref.read(${name}RepositoryProvider).doSomething();
  //     state = AsyncData(current.copyWith(success: 'Done!'));
  //   } on AppException catch (e) {
  //     state = AsyncData(current.copyWith(error: e.message));
  //   }
  // }
}
''';

  // ── Presentation — View ─────────────────────────────────────────────────────

  /// Returns the generated view template.
  static String view(String name, String cls, {required bool hasNotifier}) =>
      '''
import 'package:flutter/material.dart';
import '../../../../shared/widgets/error_view.dart';
import 'package:skeletonizer/skeletonizer.dart';

${hasNotifier ? "import 'package:flutter_riverpod/flutter_riverpod.dart';" : ''}

${hasNotifier ? "import '../notifiers/${name}_notifier.dart';" : ''}

class ${cls}View extends ${hasNotifier ? 'ConsumerStatefulWidget' : 'StatelessWidget'} {
  const ${cls}View({super.key});


${hasNotifier ? '''  @override
  ConsumerState<${cls}View> createState() => _${cls}ViewState();
}

class _${cls}ViewState extends ConsumerState<${cls}View> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final ${name}Async = ref.watch(${name}NotifierProvider);
    ref.listen(${name}NotifierProvider, (_, next) {
      final value = next.value;
      if (value == null) return;
        if (value.error != null) {
        // SHOW UI ERROR
      }
      if (value.success != null) {
        // SHOW UI SUCCESS
      }
    });

    Widget _mainWidget(${cls}State? state){
      return const SizedBox.shrink();
    }
    return ${name}Async.when(
        data: (state) => _mainWidget(state),

        loading: () => Skeletonizer(
          enabled: true,
          child: _mainWidget(),
        ),
        error: (_, _) => ErrorView(message: "Failed to load ${cls}"),
        
    );
  }
}''' : '''  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$cls')),
      body: const SizedBox.shrink(),
    );
  }
}'''}
''';
}
