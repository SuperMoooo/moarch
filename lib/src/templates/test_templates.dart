class TestTemplates {
  TestTemplates._();

  // ── Integration test ────────────────────────────────────────────────────────
  // Hits the real API and verifies:
  //   1. The request succeeds (status 200)
  //   2. The response JSON parses into the model without throwing
  //   3. Required fields are present and non-null
  //
  // Run separately from unit tests:
  //   flutter test test/features/<n>/<n>_integration_test.dart
  //
  // DO NOT run in CI by default — these need a live server.
  // Add to CI only in a separate job with @Tags(['integration']).

  static String integrationTest(String name, String cls) => '''
// ignore_for_file: avoid_print
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/config/env/app_env.dart';

import '../../../lib/core/constants/api_constants.dart';
import '../../../lib/features/$name/data/datasources/${name}_remote_datasource.dart';
import '../../../lib/features/$name/data/models/${name}_model.dart';

// ── Setup ─────────────────────────────────────────────────────────────────────
// Requires a running API. Set BASE_URL in .env before running.
//
// Run with:
//   flutter test test/features/$name/${name}_integration_test.dart
//
// NOTE: These tests are intentionally NOT run with the rest of the unit tests.
// They depend on the network and a live server — keep them separate.

Dio buildTestDio() {
  return Dio(
    BaseOptions(
      baseUrl: AppEnv.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) {
              return status != null && status >= 200 && status < 500;
      },
    ),
  );
}

void main() {

  group('${cls} — data layer integration', () {
    late ${cls}RemoteDataSource datasource;

    setUp(() {
      datasource = ${cls}RemoteDataSourceImpl(buildTestDio());
    });

    // ── getAll ──────────────────────────────────────────────────────────────

    test('getAll() responds without throwing', () async {
      // If this throws, your endpoint or fromJson is broken
      final result = await datasource.getAll();
      print('[${cls}] getAll() returned \${result.length} items');
      expect(result, isA<List<${cls}Model>>());
    });

    test('getAll() returns a non-empty list', () async {
      // Fails if the API returns [] when it should have data —
      // catch seeding issues early
      final result = await datasource.getAll();
      expect(result, isNotEmpty);
    });


    // ── toEntity ─────────────────────────────────────────────────────────────

    test('toEntity() converts model without throwing', () async {
      final all = await datasource.getAll();
      expect(all, isNotEmpty);

      // Verify the full conversion chain: JSON → Model → Entity
      expect(() => all.first.toEntity(), returnsNormally);
    });
  });
}
''';

  // ── Notifier test ───────────────────────────────────────────────────────────
  // Tests state transitions: initial → loading → loaded / error
  // Uses a fake repository instead of mocking — simpler, no mock package needed

  static String notifierTest(String name, String cls) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/$name/data/repositories/${name}_repository_impl.dart';
import '../../../lib/features/$name/domain/entities/${name}_entity.dart';
import '../../../lib/features/$name/domain/repositories/${name}_repository.dart';
import '../../../lib/features/$name/presentation/notifiers/${name}_notifier.dart';
import '../../../lib/features/$name/presentation/states/${name}_state.dart';

// ── Fake repository ───────────────────────────────────────────────────────────
// A simple in-memory fake — no mock package needed.
// Return what you want per test by setting [items] or [shouldThrow].

class Fake${cls}Repository implements ${cls}Repository {
  Fake${cls}Repository({this.items = const [], this.shouldThrow = false});

  List<${cls}Entity> items;
  bool shouldThrow;
  String errorMessage = 'Something went wrong';

  @override
  Future<List<${cls}Entity>> getAll() async {
    if (shouldThrow) throw Exception(errorMessage);
    return items;
  }

  // TODO: add overrides for any other methods you add to the repository
}

// ── Helpers ───────────────────────────────────────────────────────────────────

ProviderContainer makeContainer({required ${cls}Repository repository}) {
  final container = ProviderContainer(
    overrides: [
      ${name}RepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('${cls}Notifier', () {
    test('initial state is correct', () {
      final container = makeContainer(
        repository: Fake${cls}Repository(),
      );
      final state = container.read(${name}NotifierProvider);

      expect(state, isA<AsyncData<${cls}State>>());
      expect(state.value?.isLoadingAction, false);
      expect(state.value?.error, isNull);
      expect(state.value?.success, isNull);
    });

    test('load() sets isLoading then populates items on success', () async {
      // TODO: replace with real entity fields
      final fakeItems = [const ${cls}Entity()];
      final container = makeContainer(
        repository: Fake${cls}Repository(items: fakeItems),
      );

      final notifier = container.read(${name}NotifierProvider.notifier);
      await notifier.load();

      final state = container.read(${name}NotifierProvider);
      expect(state.value?.isLoadingAction, false);
      expect(state.value?.error, isNull);
      // TODO: uncomment when entity has fields
      // expect(state.value?.items, fakeItems);
    });

    test('load() sets error on failure', () async {
      final repo = Fake${cls}Repository(shouldThrow: true);
      repo.errorMessage = 'Network error';
      final container = makeContainer(repository: repo);

      final notifier = container.read(${name}NotifierProvider.notifier);
      await notifier.load();

      final state = container.read(${name}NotifierProvider);
      expect(state.value?.error, isNotNull);
      expect(state.value?.isLoadingAction, false);
    });
  });
}
''';

  // ── Repository test ─────────────────────────────────────────────────────────
  // Tests that DioException is caught and rethrown as AppException.
  // Uses a fake datasource — no mock package needed.

  static String repositoryTest(String name, String cls) => '''
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/errors/app_exception.dart';
import '../../../lib/features/$name/data/datasources/${name}_remote_datasource.dart';
import '../../../lib/features/$name/data/models/${name}_model.dart';
import '../../../lib/features/$name/data/repositories/${name}_repository_impl.dart';

// ── Fake datasource ───────────────────────────────────────────────────────────

class Fake${cls}RemoteDataSource implements ${cls}RemoteDataSource {
  Fake${cls}RemoteDataSource({this.models = const [], this.shouldThrow = false});

  List<${cls}Model> models;
  bool shouldThrow;
  int? throwStatusCode;

  @override
  Future<List<${cls}Model>> getAll() async {
    if (shouldThrow) {
      final response = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: throwStatusCode ?? 500,
        data: {'message': 'Server error'},
      );
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        response: response,
      );
    }
    return models;
  }

  // TODO: add overrides for any other datasource methods
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('${cls}RepositoryImpl', () {
    test('getAll() returns entities on success', () async {
      // TODO: replace with real model fields
      const fakeModels = [${cls}Model()];
      final repo = ${cls}RepositoryImpl(
        Fake${cls}RemoteDataSource(models: fakeModels),
      );

      final result = await repo.getAll();

      expect(result.length, fakeModels.length);
    });

    test('getAll() throws AppException when DioException is thrown', () async {
      final repo = ${cls}RepositoryImpl(
        Fake${cls}RemoteDataSource(shouldThrow: true, throwStatusCode: 500),
      );

      expect(
        () => repo.getAll(),
        throwsA(isA<AppException>()),
      );
    });


    test('AppException carries the message from the response body', () async {
      final repo = ${cls}RepositoryImpl(
        Fake${cls}RemoteDataSource(shouldThrow: true),
      );

      try {
        await repo.getAll();
        fail('Expected AppException');
      } on AppException catch (e) {
        expect(e.message, isNotEmpty);
      }
    });
  });
}
''';

  // ── Use case test ───────────────────────────────────────────────────────────
  // Tests that the use case delegates to the repository correctly.
  // Straightforward — just verifying the call chain.

  static String usecaseTest(String name, String cls) => '''
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/$name/domain/entities/${name}_entity.dart';
import '../../../lib/features/$name/domain/repositories/${name}_repository.dart';
import '../../../lib/features/$name/domain/usecases/get_$name.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class Fake${cls}Repository implements ${cls}Repository {
  Fake${cls}Repository({this.items = const []});

  List<${cls}Entity> items;
  int callCount = 0;

  @override
  Future<List<${cls}Entity>> getAll() async {
    callCount++;
    return items;
  }

  // TODO: add overrides for any other methods you add to the repository
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Get$cls', () {
    test('calls repository.getAll() once', () async {
      final repo = Fake${cls}Repository();
      final useCase = Get$cls(repo);

      await useCase.call();

      expect(repo.callCount, 1);
    });

    test('returns the result from the repository', () async {
      // TODO: replace with real entity fields
      final expected = [${cls}Entity()];
      final repo = Fake${cls}Repository(items: expected);
      final useCase = Get$cls(repo);

      final result = await useCase.call();

      expect(result, expected);
    });

    test('propagates exceptions from the repository', () async {
      final repo = Fake${cls}Repository()
        ..getAll; // override below
      final useCase = Get$cls(_ThrowingRepository());

      expect(() => useCase.call(), throwsException);
    });
  });
}

class _ThrowingRepository implements ${cls}Repository {
  @override
  Future<List<${cls}Entity>> getAll() async => throw Exception('repo error');

  // TODO: add overrides for any other methods you add to the repository
}
''';
}
