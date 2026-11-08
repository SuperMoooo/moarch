import 'dart:io';

import 'package:moarch/src/templates/core/analytics_templates.dart';
import 'package:moarch/src/templates/misc/agents_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/package_versions.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('the agent guide', _agentsGuide);

  group('the analytics service', () {
    test('is an interface the app logs through, on Firebase', () {
      final source = AnalyticsTemplates.analyticsService();

      expect(source, contains('abstract interface class AnalyticsService {'));
      expect(
        source,
        contains(
          'class FirebaseAnalyticsService implements AnalyticsService {',
        ),
      );
      expect(
        source,
        contains('_analytics.logEvent(name: name, parameters: parameters)'),
      );
      expect(source, contains('_analytics.setUserId(id: id)'));
      expect(source, contains('_analytics.logScreenView(screenName: name)'));
    });

    test('the observer logs pages, never dialogs, by route name', () {
      final source = AnalyticsTemplates.analyticsService();

      expect(
        source,
        contains('class AnalyticsRouteObserver extends NavigatorObserver {'),
      );
      expect(source, contains('if (route is PageRoute && name != null) {'));
      // A pop uncovers the page below: that is the screen now.
      expect(
        source,
        contains('if (previousRoute != null) _log(previousRoute);'),
      );
    });

    test('is a catalog entry, and firebase_analytics is pinned', () {
      expect(
        ScaffoldCatalog.byName('analytics-service')?.path,
        'lib/core/services/analytics_service.dart',
      );
      expect(PackageVersions.packages, contains('firebase_analytics'));
    });
  });

  group('the app around it', () {
    for (final stateManagement in StateManagement.values) {
      test('the router observes screens only with it ($stateManagement)', () {
        final stack = StackTemplates(stateManagement);
        for (final withAuth in [true, false]) {
          final source = stack.appRouter(
            withAuth: withAuth,
            withAccountScreens: withAuth,
            withAnalytics: true,
          );

          expect(
            source,
            contains(
              'observers: [AnalyticsRouteObserver(getIt<AnalyticsService>())],',
            ),
          );
          expect(
            source,
            contains("import '../../core/services/analytics_service.dart';"),
          );
          expect("import '../di/injector.dart';".allMatchesIn(source), 1);
          // Relative imports stay in order.
          expect(
            source.indexOf('core/services/analytics_service.dart'),
            lessThan(source.indexOf("import '../di/injector.dart';")),
          );
          expect(
            source.indexOf("import '../di/injector.dart';"),
            lessThan(source.indexOf("import './app_routes.dart';")),
          );
          expect(
            stack.appRouter(withAuth: withAuth, withAccountScreens: withAuth),
            isNot(contains('Analytics')),
          );
        }
      });
    }

    test('the core module registers it only with it', () {
      const stack = StackTemplates(StateManagement.riverpod);

      expect(
        stack.coreModule(withAnalytics: true),
        contains(
          'registerLazySingleton<AnalyticsService>(FirebaseAnalyticsService.new)',
        ),
      );
      expect(
        stack.coreModule(withAnalytics: true),
        contains("import '../../core/services/analytics_service.dart';"),
      );
      expect(stack.coreModule(), isNot(contains('Analytics')));
    });
  });

  group('detection', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_analytics_test');
    });

    tearDown(() async => tempDir.delete(recursive: true));

    test('hasAnalytics reads analytics_service.dart off disk', () async {
      expect(ScaffoldContext.detect(tempDir.path).hasAnalytics, isFalse);
      await File(
        p.join(
          tempDir.path,
          'lib',
          'core',
          'services',
          'analytics_service.dart',
        ),
      ).create(recursive: true);
      expect(ScaffoldContext.detect(tempDir.path).hasAnalytics, isTrue);
    });
  });
}

extension on String {
  int allMatchesIn(String source) => allMatches(source).length;
}

void _agentsGuide() {
  test('AGENTS.md states the analytics, flags and encryption rules', () {
    for (final stateManagement in StateManagement.values) {
      final source = AgentsTemplates.agentsMd(
        projectName: 'demo',
        stateManagement: stateManagement,
        withDio: true,
        withLocalCache: true,
        withEncryptedDatabase: true,
        withAnalytics: true,
        withFeatureFlags: true,
      );

      expect(source, contains('## Analytics and feature flags'));
      expect(source, contains('Log through `AnalyticsService`'));
      expect(source, contains('A remote switch is a getter on `FeatureFlags`'));
      expect(source, contains('source: sqlite3mc'));
      expect(
        source,
        contains(
          stateManagement.isBloc
              ? '`FeatureFlagsCubit`'
              : '`featureFlagsProvider`',
        ),
      );
    }
    final plain = AgentsTemplates.agentsMd(
      projectName: 'demo',
      stateManagement: StateManagement.riverpod,
      withDio: true,
      withLocalCache: true,
    );
    expect(plain, isNot(contains('Analytics and feature flags')));
    expect(plain, isNot(contains('sqlite3mc')));
  });
}
