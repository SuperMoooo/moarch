import 'dart:io';

import 'package:path/path.dart' as p;

import 'dart_source.dart';

/// What [RouterUtils.register] did with a feature's route.
enum RoutePatchResult {
  /// The project has no GoRouter, so there was nothing to add a route to.
  noRouter,

  /// The path went into `app_routes.dart` and the `GoRoute` into
  /// `app_router.dart`.
  added,

  /// Both files already had it — `create feature` re-run on a feature whose
  /// route is there.
  alreadyThere,

  /// One of the two files has no [RouterUtils.anchor] (a project from before
  /// the anchors, or one that removed them), so neither was touched.
  missingAnchor,
}

/// Adds a feature's route to the project's GoRouter — the router's
/// counterpart to `InjectorUtils`.
///
/// `lib/config/router/app_routes.dart` gets the path constant and
/// `app_router.dart` the `GoRoute`, each above the [anchor] comment their
/// templates carry. Either both are patched or neither is: a path with no
/// route, or a route naming a constant that does not exist, would not
/// compile.
abstract final class RouterUtils {
  /// The comment each route is inserted above. Load-bearing: the generated
  /// source says so.
  static const String anchor = '// moarch:routes';

  /// `lib/config/router/app_routes.dart` inside [libPath].
  static String routesFileFor(String libPath) =>
      p.join(libPath, 'config', 'router', 'app_routes.dart');

  /// `lib/config/router/app_router.dart` inside [libPath].
  static String routerFileFor(String libPath) =>
      p.join(libPath, 'config', 'router', 'app_router.dart');

  /// The URL path for [featureName]: `order_history` → `/order-history`.
  static String pathFor(String featureName) =>
      '/${featureName.replaceAll('_', '-')}';

  /// The `AppRoutes` constant declaring [featureName]'s path.
  static String routeConstant(String featureName, String varName) =>
      "  static const $varName = '${pathFor(featureName)}';";

  /// The `GoRoute` entry for [screen], at [indent] — the anchor's own.
  static String goRoute(String varName, String screen, String indent) => [
    'GoRoute(',
    '  path: AppRoutes.$varName,',
    '  builder: (context, state) => const $screen(),',
    '),',
  ].map((line) => '$indent$line').join('\n');

  /// Registers [screen] (the page on bloc, the view on Riverpod) at
  /// [featureName]'s path, importing it from [screenImport] (relative to
  /// `lib/config/router/`).
  static Future<RoutePatchResult> register(
    String libPath, {
    required String featureName,
    required String varName,
    required String screen,
    required String screenImport,
  }) async {
    final routesFile = File(routesFileFor(libPath));
    final routerFile = File(routerFileFor(libPath));
    if (!routesFile.existsSync() || !routerFile.existsSync()) {
      return RoutePatchResult.noRouter;
    }

    final routes = routesFile.readAsStringSync();
    final router = routerFile.readAsStringSync();
    if (!routes.contains(anchor) || !router.contains(anchor)) {
      return RoutePatchResult.missingAnchor;
    }

    final hasConstant = routes.contains('static const $varName ');
    final hasRoute = router.contains('path: AppRoutes.$varName,');
    if (hasConstant && hasRoute) return RoutePatchResult.alreadyThere;

    if (!hasConstant) {
      await routesFile.writeAsString(
        DartSource.insertAbove(
          routes,
          anchor,
          routeConstant(featureName, varName),
        )!,
      );
    }
    if (!hasRoute) {
      final withImport = DartSource.addImports(router, [
        "import '$screenImport';",
      ]);
      await routerFile.writeAsString(
        DartSource.insertAbove(
          withImport,
          anchor,
          goRoute(varName, screen, _indentOf(withImport, anchor)),
        )!,
      );
    }
    return RoutePatchResult.added;
  }

  /// The whitespace in front of [marker] on its line.
  static String _indentOf(String source, String marker) {
    final index = source.indexOf(marker);
    final lineStart = source.lastIndexOf('\n', index) + 1;
    return source.substring(lineStart, index);
  }
}
