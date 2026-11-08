/// Analytics: one interface the app logs through, implemented with Firebase
/// Analytics, and the navigator observer that logs every screen.
///
/// It holds no state, so it is the same in both stacks. Only offered with
/// Firebase, like Crashlytics: another provider is a second implementation
/// of the interface, registered in `core_module.dart` instead.
abstract final class AnalyticsTemplates {
  /// `lib/core/services/analytics_service.dart`.
  static String analyticsService() => r'''
import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

/// What the app tells analytics: events, who is signed in, which screen.
///
/// Screens, notifiers and blocs call this, never the SDK: to change provider,
/// implement it again and register the new class in `core_module.dart`.
abstract interface class AnalyticsService {
  /// [name] in snake_case, at most 40 characters; [parameters] values are
  /// strings or numbers.
  Future<void> logEvent(String name, {Map<String, Object>? parameters});

  /// Ties what follows to the account [id], or to nobody when null (sign
  /// out). An opaque id, never an email or a name.
  Future<void> setUser(String? id);

  /// A screen view. [AnalyticsRouteObserver] logs one for every route.
  Future<void> logScreen(String name);
}

/// [AnalyticsService] on Firebase Analytics.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService([FirebaseAnalytics? analytics])
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> setUser(String? id) => _analytics.setUserId(id: id);

  @override
  Future<void> logScreen(String name) {
    return _analytics.logScreenView(screenName: name);
  }
}

/// Logs a screen view each time a page is shown: pushed, replaced, or
/// uncovered by a pop. Dialogs and sheets are not pages and are not logged.
///
/// GoRouter names a page after its route's `name`, else its path pattern
/// (`/orders/:id`), so no id ends up in a screen name.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  final AnalyticsService _analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _log(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _log(previousRoute);
  }

  void _log(Route<dynamic> route) {
    final name = route.settings.name;
    if (route is PageRoute && name != null) {
      unawaited(_analytics.logScreen(name));
    }
  }
}
''';

  /// The registration `core_module.dart` gets.
  static const String registration =
      '    ..registerLazySingleton<AnalyticsService>(FirebaseAnalyticsService.new)';

  /// The `observers:` line GoRouter gets in `app_router.dart`, at [indent].
  static String routerObserver(String indent) =>
      '$indent// Logs a screen view for every page (core/services/analytics_service.dart).\n'
      '${indent}observers: [AnalyticsRouteObserver(getIt<AnalyticsService>())],';

  /// [imports] — an import block, package imports first — with the router's
  /// analytics imports merged into its relative ones, in order.
  static String withRouterImports(String imports) {
    const extra = [
      "import '../../core/services/analytics_service.dart';",
      "import '../di/injector.dart';",
    ];
    final lines = imports.split('\n');
    final packages = [
      for (final line in lines)
        if (line.startsWith("import 'package:")) line,
    ];
    final relative = {
      for (final line in lines)
        if (line.startsWith("import '.")) line,
      ...extra,
    }.toList()..sort();
    return [
      if (packages.isNotEmpty) ...[...packages, ''],
      ...relative,
    ].join('\n');
  }
}
