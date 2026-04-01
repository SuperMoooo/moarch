class TestTemplates {
  TestTemplates._();

  // ── Notifier test ───────────────────────────────────────────────────────────
  // Tests state transitions: initial → loading → loaded / error
  // Uses a fake repository instead of mocking — simpler, no mock package needed

  static String notifierTest(String name, String cls) => '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:your_app/features/$name/data/repositories/${name}_repository_impl.dart';
import 'package:your_app/features/$name/domain/entities/${name}_entity.dart';
import 'package:your_app/features/$name/domain/repositories/${name}_repository.dart';
import 'package:your_app/features/$name/presentation/notifiers/${name}_notifier.dart';
import 'package:your_app/features/$name/presentation/states/${name}_state.dart';

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

import 'package:your_app/core/errors/app_exception.dart';
import 'package:your_app/features/$name/data/datasources/${name}_remote_datasource.dart';
import 'package:your_app/features/$name/data/models/${name}_model.dart';
import 'package:your_app/features/$name/data/repositories/${name}_repository_impl.dart';

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
  });
}
''';

  // ── Use case test ───────────────────────────────────────────────────────────
  // Tests that the use case delegates to the repository correctly.
  // Straightforward — just verifying the call chain.

  static String usecaseTest(String name, String cls) => '''
import 'package:flutter_test/flutter_test.dart';

import 'package:your_app/features/$name/domain/entities/${name}_entity.dart';
import 'package:your_app/features/$name/domain/repositories/${name}_repository.dart';
import 'package:your_app/features/$name/domain/usecases/get_$name.dart';

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
      final expected = [const ${cls}Entity()];
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
