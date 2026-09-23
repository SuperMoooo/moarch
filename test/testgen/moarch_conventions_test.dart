// What `moarch create tests` does differently from the mogen packages it
// replaced: the shapes a moarch project is actually written in.
import 'dart:io';

import 'package:moarch/src/testgen/integration/generators/test_orchestrator.dart';
import 'package:moarch/src/testgen/testgen_conventions.dart';
import 'package:moarch/src/testgen/unit/generators/test_orchestrator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String root;

  void write(String relative, String content) {
    File(p.joinAll([root, ...relative.split('/')]))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  String read(String relative) =>
      File(p.joinAll([root, ...relative.split('/')])).readAsStringSync();

  bool exists(String relative) =>
      File(p.joinAll([root, ...relative.split('/')])).existsSync();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('moarch_testgen');
    root = tempDir.path;
    write('pubspec.yaml', 'name: shop\n');
    write('lib/core/constants/api_constants.dart', '''
abstract final class ApiConstants {
  static const Duration connectTimeout = Duration(seconds: 30);
  static const ordersHistory = '/orders/history';
}
''');
    write('lib/features/orders/domain/models/orders_model.dart', '''
class OrdersModel {
  const OrdersModel({required this.id});
  factory OrdersModel.empty() => const OrdersModel(id: 0);
  final int id;
}
''');
    write('lib/features/orders/domain/repositories/orders_repository.dart', '''
import '../models/orders_model.dart';

abstract interface class OrdersRepository {
  Future<List<OrdersModel>> fetchAll();
  Future<OrdersModel> cancel(int id);
}
''');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  group('Riverpod notifier reading getIt', () {
    setUp(() {
      write('lib/features/orders/presentation/states/orders_state.dart', '''
class OrdersState {
  const OrdersState({this.isLoadingAction = false, this.error, this.success});
  final bool isLoadingAction;
  final String? error;
  final String? success;
}
''');
      write(
        'lib/features/orders/presentation/notifiers/orders_notifier.dart',
        '''
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/di/injector.dart';
import '../../domain/repositories/orders_repository.dart';
import '../states/orders_state.dart';

final ordersNotifierProvider =
    AsyncNotifierProvider<OrdersNotifier, OrdersState>(OrdersNotifier.new);

class OrdersNotifier extends AsyncNotifier<OrdersState> {
  OrdersRepository get _repo => getIt<OrdersRepository>();

  @override
  FutureOr<OrdersState> build() async {
    await _repo.fetchAll();
    return const OrdersState();
  }

  Future<void> cancel(int id) {
    return runAction((current) async {
      await _repo.cancel(id);
      return current.copyWith(success: 'Cancelled');
    });
  }
}
''',
      );
    });

    String generate() {
      UnitTestOrchestrator(projectRoot: root, packageName: 'shop').run();
      return read('test/unit/features/orders/orders_notifier_test.dart');
    }

    test('registers the mock in getIt rather than overriding a provider', () {
      final source = generate();
      expect(
        source,
        contains("import 'package:shop/config/di/injector.dart';"),
      );
      expect(
        source,
        contains(
          'getIt.registerSingleton<OrdersRepository>(mockOrdersRepository);',
        ),
      );
      expect(source, contains('await getIt.reset();'));
      expect(source, isNot(contains('overrideWithValue')));
      expect(source, contains('container = ProviderContainer();'));
    });

    test('follows calls through the getter, into runAction closures', () {
      final source = generate();
      // build()'s call is hoisted into setUp.
      expect(source, contains('mockOrdersRepository.fetchAll()'));
      // cancel() reaches the repository inside runAction's closure.
      expect(source, contains('mockOrdersRepository.cancel(any())'));
    });

    test('throws a ServerException on the error path', () {
      final source = generate();
      expect(
        source,
        contains("thenThrow(const ServerException(message: 'test'))"),
      );
      expect(
        source,
        contains("import 'package:shop/core/errors/app_exception.dart';"),
      );
      expect(source, isNot(contains('AppException.test()')));
      expect(
        source,
        contains('expect(finalState.requireValue.error, isNotNull);'),
      );
    });

    test('an inline getIt<X>().call() is a dependency too', () {
      write(
        'lib/features/orders/presentation/notifiers/orders_notifier.dart',
        '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrdersNotifier extends AsyncNotifier<OrdersState> {
  @override
  Future<OrdersState> build() async => const OrdersState();

  Future<void> cancel(int id) async {
    await getIt<OrdersRepository>().cancel(id);
  }
}
''',
      );
      final source = generate();
      expect(
        source,
        contains(
          'getIt.registerSingleton<OrdersRepository>(mockOrdersRepository);',
        ),
      );
      expect(source, contains('mockOrdersRepository.cancel(any())'));
    });
  });

  group('bloc handler through runAction', () {
    setUp(() {
      write('lib/features/orders/presentation/blocs/orders_event.dart', '''
sealed class OrdersEvent {
  const OrdersEvent();
}

final class OrdersCancelled extends OrdersEvent {
  const OrdersCancelled(this.id);
  final int id;
}
''');
      write('lib/features/orders/presentation/blocs/orders_state.dart', '''
class OrdersState {
  const OrdersState({this.errorMessage, this.successMessage});
  final String? errorMessage;
  final String? successMessage;
}
''');
      write('lib/features/orders/presentation/blocs/orders_bloc.dart', '''
import 'package:bloc/bloc.dart';

import '../../domain/repositories/orders_repository.dart';
import 'orders_event.dart';
import 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState>
    with ActionBlocMixin<OrdersEvent, OrdersState> {
  OrdersBloc(this._repo) : super(const OrdersState()) {
    on<OrdersCancelled>(_onCancelled);
  }

  final OrdersRepository _repo;

  Future<void> _onCancelled(
    OrdersCancelled event,
    Emitter<OrdersState> emit,
  ) =>
      runAction(emit, (current) async {
        await _repo.cancel(event.id);
        return current.copyWith(successMessage: 'Cancelled');
      });
}
''');
    });

    test('asserts the error on the state, not an escaped exception', () {
      UnitTestOrchestrator(projectRoot: root, packageName: 'shop').run();
      final source = read('test/unit/features/orders/orders_bloc_test.dart');

      expect(
        source,
        contains(
          'OrdersBloc buildOrdersBloc() => '
          'OrdersBloc(mockOrdersRepository);',
        ),
      );
      expect(source, contains('bloc.add(const OrdersCancelled(0))'));
      expect(
        source,
        contains("thenThrow(const ServerException(message: 'test'))"),
      );
      // runAction turns the failure into state — the error test reads it.
      expect(source, contains('expect(bloc.state.errorMessage, isNotNull);'));
      expect(source, isNot(contains('errors: () => [isA<AppException>()]')));
      expect(source, contains('expect(bloc.state.successMessage, isNotNull);'));
    });
  });

  group('guarded bloc handler', () {
    setUp(() {
      write('lib/features/orders/presentation/blocs/orders_event.dart', '''
sealed class OrdersEvent {
  const OrdersEvent();
}

final class OrdersArchived extends OrdersEvent {
  const OrdersArchived();
}
''');
      write('lib/features/orders/presentation/blocs/orders_state.dart', '''
sealed class OrdersState {
  const OrdersState();
}

final class OrdersIdle extends OrdersState {
  const OrdersIdle();
}

final class OrdersLoaded extends OrdersState {
  const OrdersLoaded({required this.count});
  final int count;
}

final class OrdersGone extends OrdersState {
  const OrdersGone();
}
''');
      write('lib/features/orders/presentation/blocs/orders_bloc.dart', '''
import 'package:bloc/bloc.dart';

import '../../domain/repositories/orders_repository.dart';
import 'orders_event.dart';
import 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc(this._repo) : super(const OrdersIdle()) {
    on<OrdersArchived>(_onArchived);
  }

  final OrdersRepository _repo;

  Future<void> _onArchived(
    OrdersArchived event,
    Emitter<OrdersState> emit,
  ) async {
    final current = state;
    if (current is! OrdersLoaded) return;
    await _repo.cancel(current.count);
    emit(const OrdersGone());
  }
}
''');
    });

    test('seeds the state the handler guards on', () {
      UnitTestOrchestrator(projectRoot: root, packageName: 'shop').run();
      final source = read('test/unit/features/orders/orders_bloc_test.dart');
      // Without the seed the bloc starts in OrdersIdle, the guard returns,
      // and the test verifies a call that never happened.
      expect(source, contains('seed: () => const OrdersLoaded(count: 0),'));
    });
  });

  group('integration tests', () {
    setUp(() {
      write(
        'lib/features/orders/data/datasources/orders_remote_datasource.dart',
        '''
import 'package:dio/dio.dart';

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._dio);

  final Dio _dio;

  Future<void> fetchHistory() async {
    await _dio.get<dynamic>(ApiConstants.ordersHistory);
  }

  Future<void> fetchOne() async {
    await _dio.get<dynamic>('/orders');
  }
}
''',
      );
    });

    test('resolves an ApiConstants path as well as a literal', () {
      final result = IntegrationTestOrchestrator(
        projectRoot: root,
        packageName: 'shop',
      ).run();

      expect(result.warnings, isEmpty);
      expect(
        exists(
          'test/integration/features/orders/'
          'orders_history_integration_test.dart',
        ),
        isTrue,
      );
      expect(
        exists('test/integration/features/orders/orders_integration_test.dart'),
        isTrue,
      );
    });

    test('treats a safeApiCall failure as reachable unless it is offline', () {
      IntegrationTestOrchestrator(projectRoot: root, packageName: 'shop').run();
      final source = read(
        'test/integration/features/orders/orders_history_integration_test.dart',
      );

      expect(
        source,
        contains("import 'package:flutter_test/flutter_test.dart';"),
      );
      expect(source, contains('} on NetworkException catch (e) {'));
      expect(source, contains('} on AppException {'));
      expect(source, contains('} on DioException catch (e) {'));
      expect(source, contains('OrdersRemoteDataSource(dio)'));
    });

    test('writes the Dio helper from AppEnv once, and never overwrites it', () {
      IntegrationTestOrchestrator(projectRoot: root, packageName: 'shop').run();
      final helper = read('test/integration/dio_helper.dart');
      expect(helper, contains('baseUrl: AppEnv.baseUrl'));
      expect(helper, contains('ApiConstants.connectTimeout'));

      write('test/integration/dio_helper.dart', '// the team logs in here\n');
      IntegrationTestOrchestrator(projectRoot: root, packageName: 'shop').run();
      expect(
        read('test/integration/dio_helper.dart'),
        '// the team logs in here\n',
      );
    });
  });

  group('overwrite protection', () {
    const path =
        'test/integration/features/orders/orders_integration_test.dart';

    setUp(() {
      write(
        'lib/features/orders/data/datasources/orders_remote_datasource.dart',
        '''
import 'package:dio/dio.dart';

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._dio);
  final Dio _dio;
  Future<void> fetchOne() async => _dio.get<dynamic>('/orders');
}
''',
      );
    });

    test('every file starts with the marker', () {
      IntegrationTestOrchestrator(projectRoot: root, packageName: 'shop').run();
      expect(read(path), startsWith(TestGenConventions.header));
    });

    test('a file without the marker is left alone unless --force', () {
      write(path, '// hand-written\n');
      final result = IntegrationTestOrchestrator(
        projectRoot: root,
        packageName: 'shop',
      ).run();
      expect(read(path), '// hand-written\n');
      expect(result.handMaintained, hasLength(1));

      IntegrationTestOrchestrator(
        projectRoot: root,
        packageName: 'shop',
        force: true,
      ).run();
      expect(read(path), startsWith(TestGenConventions.header));
    });

    test('a file the mogen packages wrote is still refreshed', () {
      write(path, '// GENERATED BY mogen_integration_tests — DO NOT EDIT\n');
      IntegrationTestOrchestrator(projectRoot: root, packageName: 'shop').run();
      expect(read(path), startsWith(TestGenConventions.header));
    });

    test('a dry run writes nothing and lists what it would', () {
      final result = IntegrationTestOrchestrator(
        projectRoot: root,
        packageName: 'shop',
        dryRun: true,
      ).run();
      expect(exists(path), isFalse);
      expect(result.planned, isNotEmpty);
      expect(result.written, isEmpty);
    });
  });
}
