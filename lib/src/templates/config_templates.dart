class ConfigTemplates {
  ConfigTemplates._();

  static String appTheme() => r'''
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF6750A4);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      );
}
''';

  // Plain Navigator-based router — no go_router dependency
  static String appRouter() => r'''
import 'package:flutter/material.dart';

// Route names
abstract final class AppRoutes {
  static const home = '/';
  // static const login = '/login';
  // add more as needed
}

// Pass this to MaterialApp.router or use onGenerateRoute with MaterialApp
final appRouter = RouterConfig<Object>(
  routerDelegate: _AppRouterDelegate(),
  routeInformationParser: _AppRouteInformationParser(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Simple Navigator 2.0 wiring — swap for go_router if you prefer
// ─────────────────────────────────────────────────────────────────────────────

class _AppRouteInformationParser
    extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(
    RouteInformation routeInformation,
  ) async =>
      routeInformation.uri.path;

  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri.parse(configuration));
}

class _AppRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  String _location = AppRoutes.home;

  void go(String location) {
    _location = location;
    notifyListeners();
  }

  @override
  String? get currentConfiguration => _location;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage(
          key: ValueKey(_location),
          child: _routeWidget(_location),
        ),
      ],
      onDidRemovePage: (page) {},
    );
  }

  Widget _routeWidget(String location) {
    return switch (location) {
      AppRoutes.home => const Scaffold(
          body: Center(child: Text('Home — replace me!')),
        ),
      _ => const Scaffold(
          body: Center(child: Text('404 — not found')),
        ),
    };
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    _location = configuration;
  }
}
''';

  static String env() => r'''
abstract final class Env {
  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://api.example.com',
  );

  static const appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get isProduction => appEnv == 'production';
  static bool get isDevelopment => appEnv == 'development';
}
''';
}
