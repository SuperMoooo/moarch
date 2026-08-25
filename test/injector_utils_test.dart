import 'dart:io';

import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/utils/injector_utils.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String libPath;

  /// The current layout: `injector.dart` plus one module per layer.
  Future<void> scaffoldSplit({required StateManagement stateManagement}) async {
    final di = Directory(p.join(libPath, 'config', 'di'));
    await di.create(recursive: true);

    Future<void> write(String name, String source) =>
        File(p.join(di.path, name)).writeAsString(source);

    await write('injector.dart',
        InjectorTemplates.injector(stateManagement: stateManagement));
    await write('external_module.dart',
        InjectorTemplates.externalModule(withDio: true));
    await write('core_module.dart', InjectorTemplates.coreModule());
    await write(
        'data_module.dart', InjectorTemplates.dataModule(withDio: true));
    if (stateManagement.isBloc) {
      await write(
          'presentation_module.dart', InjectorTemplates.presentationModule());
    }
  }

  /// The pre-split layout, as projects scaffolded before the split have it.
  Future<void> scaffoldSingleFile({
    required StateManagement stateManagement,
  }) async {
    final di = Directory(p.join(libPath, 'config', 'di'));
    await di.create(recursive: true);
    await File(p.join(di.path, 'injector.dart')).writeAsString(
      InjectorTemplates.singleFileInjector(
        stateManagement: stateManagement,
        withDio: true,
      ),
    );
  }

  String read(String name) =>
      File(p.join(libPath, 'config', 'di', name)).readAsStringSync();

  /// A full feature: two datasources, a repository and a bloc.
  InjectorRegistrations ordersFeature({bool hasBloc = true}) =>
      InjectorUtils.registrationsFor(
        featureName: 'orders',
        className: 'Orders',
        hasRemote: true,
        hasLocal: false,
        hasRepository: true,
        hasBloc: hasBloc,
        useFirestore: false,
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_injector_test');
    libPath = p.join(tempDir.path, 'lib');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  group('the split layout', () {
    test('is detected off disk rather than remembered', () async {
      await scaffoldSingleFile(stateManagement: StateManagement.riverpod);
      expect(InjectorUtils.isSplit(libPath), isFalse);

      await scaffoldSplit(stateManagement: StateManagement.riverpod);
      expect(InjectorUtils.isSplit(libPath), isTrue);
    });

    test('sends each half of a feature to the layer it belongs to', () async {
      await scaffoldSplit(stateManagement: StateManagement.bloc);

      final result = await InjectorUtils.register(
        libPath,
        className: 'Orders',
        registrations: ordersFeature(),
      );

      expect(result.complete, isTrue);
      expect(
        result.written,
        [InjectorUtils.dataPath, InjectorUtils.presentationPath],
      );

      final data = read('data_module.dart');
      expect(data, contains('registerLazySingleton<OrdersRemoteDataSource>'));
      expect(data, contains('registerLazySingleton<OrdersRepository>'));
      // The state holder is not the data layer's business.
      expect(data, isNot(contains('OrdersBloc')));

      final presentation = read('presentation_module.dart');
      expect(presentation, contains('registerFactory<OrdersBloc>'));
      expect(presentation, isNot(contains('OrdersRemoteDataSource')));

      // The root file is the one thing that does not grow.
      expect(read('injector.dart'), isNot(contains('Orders')));
    });

    test('each module gets only the imports its own half needs', () async {
      await scaffoldSplit(stateManagement: StateManagement.bloc);
      await InjectorUtils.register(
        libPath,
        className: 'Orders',
        registrations: ordersFeature(),
      );

      final data = read('data_module.dart');
      expect(data, contains("import 'package:dio/dio.dart';"));
      expect(
        data,
        contains(
            "import '../../features/orders/data/repositories/orders_repository_impl.dart';"),
      );
      expect(data, isNot(contains('orders_bloc.dart')));

      final presentation = read('presentation_module.dart');
      expect(
        presentation,
        contains(
            "import '../../features/orders/presentation/blocs/orders_bloc.dart';"),
      );
      // The bloc's constructor names it, so the interface has to be in scope
      // here too — but the implementation does not.
      expect(
        presentation,
        contains(
            "import '../../features/orders/domain/repositories/orders_repository.dart';"),
      );
      expect(presentation, isNot(contains('orders_repository_impl.dart')));
    });

    test('a Riverpod feature touches the data module alone', () async {
      await scaffoldSplit(stateManagement: StateManagement.riverpod);

      final result = await InjectorUtils.register(
        libPath,
        className: 'Orders',
        // A notifier is not registered anywhere: it needs the Ref Riverpod
        // owns, so it stays behind its provider.
        registrations: ordersFeature(hasBloc: false),
      );

      expect(result.written, [InjectorUtils.dataPath]);
      expect(read('data_module.dart'), contains('OrdersRepository'));
      expect(
        File(p.join(libPath, 'config', 'di', 'presentation_module.dart'))
            .existsSync(),
        isFalse,
      );
    });

    test('registering the same feature twice writes nothing', () async {
      await scaffoldSplit(stateManagement: StateManagement.bloc);
      await InjectorUtils.register(
        libPath,
        className: 'Orders',
        registrations: ordersFeature(),
      );
      final after = read('data_module.dart');

      final second = await InjectorUtils.register(
        libPath,
        className: 'Orders',
        registrations: ordersFeature(),
      );

      expect(second.written, isEmpty);
      expect(read('data_module.dart'), after);
    });

    test('a module that lost its anchor is left alone and reported', () async {
      await scaffoldSplit(stateManagement: StateManagement.bloc);
      final dataFile = File(InjectorUtils.dataFileFor(libPath));
      await dataFile.writeAsString(
        dataFile.readAsStringSync().replaceAll(InjectorUtils.anchor, '//'),
      );

      final result = await InjectorUtils.register(
        libPath,
        className: 'Orders',
        registrations: ordersFeature(),
      );

      // The bloc still landed; the data layer did not, and the caller is told
      // which file to go and look at — that one, not both.
      expect(result.complete, isFalse);
      expect(result.written, [InjectorUtils.presentationPath]);
      expect(result.missing, [InjectorUtils.dataPath]);
      expect(result.describeMissing, InjectorUtils.dataPath);
      expect(result.describeWritten, InjectorUtils.presentationPath);
    });
  });

  group('the pre-split layout', () {
    test('takes both halves in the one file', () async {
      await scaffoldSingleFile(stateManagement: StateManagement.bloc);

      final result = await InjectorUtils.register(
        libPath,
        className: 'Orders',
        registrations: ordersFeature(),
      );

      expect(result.complete, isTrue);
      expect(result.written, [InjectorUtils.path]);

      final source = read('injector.dart');
      expect(source, contains('registerLazySingleton<OrdersRepository>'));
      expect(source, contains('registerFactory<OrdersBloc>'));
      // One heading, not one per half — it is one block here.
      expect('// ── Orders '.allMatches(source).length, 1);
    });

    test('gets every import either half needs, once each', () async {
      await scaffoldSingleFile(stateManagement: StateManagement.bloc);
      await InjectorUtils.register(
        libPath,
        className: 'Orders',
        registrations: ordersFeature(),
      );

      final source = read('injector.dart');
      for (final import in [
        "import 'package:dio/dio.dart';",
        "import '../../features/orders/data/datasources/orders_remote_datasource.dart';",
        "import '../../features/orders/domain/repositories/orders_repository.dart';",
        "import '../../features/orders/presentation/blocs/orders_bloc.dart';",
      ]) {
        expect(import.allMatches(source).length, 1, reason: import);
      }
    });

    test('a project with no locator at all reports the root file', () async {
      await Directory(libPath).create(recursive: true);

      final result = await InjectorUtils.register(
        libPath,
        className: 'Orders',
        registrations: ordersFeature(),
      );

      expect(result.written, isEmpty);
      expect(result.describeTargets, InjectorUtils.path);
    });
  });

  test('a feature with nothing the locator holds asks nothing of it', () async {
    await scaffoldSplit(stateManagement: StateManagement.riverpod);

    final result = await InjectorUtils.register(
      libPath,
      className: 'Orders',
      registrations: InjectorUtils.registrationsFor(
        featureName: 'orders',
        className: 'Orders',
        hasRemote: false,
        hasLocal: false,
        hasRepository: false,
        hasBloc: false,
        useFirestore: false,
      ),
    );

    expect(result.targets, isEmpty);
    expect(result.written, isEmpty);
    expect(read('data_module.dart'), isNot(contains('Orders')));
  });
}
