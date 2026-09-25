import 'dart:io';

import 'package:moarch/src/templates/config/config_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/router_utils.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String libPath;

  Future<void> writeRouter(StateManagement stateManagement) async {
    final dir = Directory(p.join(libPath, 'config', 'router'));
    await dir.create(recursive: true);
    await File(
      RouterUtils.routesFileFor(libPath),
    ).writeAsString(ConfigTemplates.appRoutes());
    await File(
      RouterUtils.routerFileFor(libPath),
    ).writeAsString(StackTemplates(stateManagement).appRouter(withAuth: true));
  }

  Future<RoutePatchResult> registerOrders({
    String screen = 'OrdersPage',
    String import = '../../features/orders/presentation/pages/orders_page.dart',
  }) => RouterUtils.register(
    libPath,
    featureName: 'order_history',
    varName: 'orderHistory',
    screen: screen,
    screenImport: import,
  );

  String routes() =>
      File(RouterUtils.routesFileFor(libPath)).readAsStringSync();
  String router() =>
      File(RouterUtils.routerFileFor(libPath)).readAsStringSync();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_router_test');
    libPath = p.join(tempDir.path, 'lib');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  test('the generated router files carry the anchor, on both stacks', () {
    expect(ConfigTemplates.appRoutes(), contains(RouterUtils.anchor));
    for (final stack in StateManagement.values) {
      for (final withAuth in [true, false]) {
        expect(
          StackTemplates(stack).appRouter(withAuth: withAuth),
          contains(RouterUtils.anchor),
        );
      }
    }
  });

  test('the path is the feature name in kebab-case', () {
    expect(RouterUtils.pathFor('order_history'), '/order-history');
  });

  for (final stack in StateManagement.values) {
    test(
      'adds the path and the GoRoute above the anchors (${stack.name})',
      () async {
        await writeRouter(stack);

        expect(await registerOrders(), RoutePatchResult.added);

        expect(
          routes(),
          contains(
            "  static const orderHistory = '/order-history';\n"
            '  // moarch:routes',
          ),
        );
        final source = router();
        expect(
          source,
          contains(
            "import '../../features/orders/presentation/pages/orders_page.dart';",
          ),
        );
        // Indented like the anchor, so the list stays formatted.
        final indent = stack.isBloc ? '    ' : '      ';
        expect(
          source,
          contains(
            '${indent}GoRoute(\n'
            '$indent  path: AppRoutes.orderHistory,\n'
            '$indent  builder: (context, state) => const OrdersPage(),\n'
            '$indent),\n'
            '$indent// moarch:routes',
          ),
        );
      },
    );
  }

  test('a second run adds nothing twice', () async {
    await writeRouter(StateManagement.bloc);
    await registerOrders();
    final routesOnce = routes();
    final routerOnce = router();

    expect(await registerOrders(), RoutePatchResult.alreadyThere);
    expect(routes(), routesOnce);
    expect(router(), routerOnce);
  });

  test('without an anchor, neither file is touched', () async {
    await writeRouter(StateManagement.riverpod);
    final routesFile = File(RouterUtils.routesFileFor(libPath));
    await routesFile.writeAsString(
      routes().replaceAll(RouterUtils.anchor, '//'),
    );
    final routesBefore = routes();
    final routerBefore = router();

    expect(await registerOrders(), RoutePatchResult.missingAnchor);
    // A route naming a constant that is not there would not compile.
    expect(routes(), routesBefore);
    expect(router(), routerBefore);
  });

  test('a project without a router is left alone', () async {
    expect(await registerOrders(), RoutePatchResult.noRouter);
    expect(Directory(p.join(libPath, 'config')).existsSync(), isFalse);
  });
}
