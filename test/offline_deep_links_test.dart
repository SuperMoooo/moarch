import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/misc/agents_templates.dart';
import 'package:moarch/src/templates/misc/deep_links_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/manifest_utils.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

void main() {
  const riverpod = StackTemplates(StateManagement.riverpod);
  const bloc = StackTemplates(StateManagement.bloc);

  group('connectivity', () {
    test('the stream starts with the current state and drops repeats', () {
      final source = ServicesTemplates.connectivityService();
      expect(
        source,
        contains('Stream<bool> get hasInternetStream => _states().distinct();'),
      );
      expect(source, contains('yield await hasInternet();'));
    });

    test('onReconnect fires only on the way back from offline', () {
      final source = ServicesTemplates.connectivityService();
      expect(source, contains('final cameBack = previous == false && online;'));
      // A failed sync is logged, not lost.
      expect(source, contains("_log.e('Reconnect task failed'"));
    });

    test('each stack gets something to watch', () {
      expect(
        ServicesTemplates.connectivityService(),
        contains('final hasInternetProvider = StreamProvider<bool>'),
      );
      final blocSource = ServicesTemplates.connectivityService(
        stateManagement: StateManagement.bloc,
      );
      expect(
        blocSource,
        contains('class ConnectivityCubit extends Cubit<bool>'),
      );
      expect(blocSource, isNot(contains('flutter_riverpod')));
    });
  });

  group('the offline gate', () {
    test('covers the app instead of replacing it, on both stacks', () {
      for (final stack in [riverpod, bloc]) {
        final source = stack.offlineGate();
        // The app stays first in the Stack, so it keeps its state underneath.
        expect(
          source,
          contains(
            'child,\n'
            '${stack.isBloc ? '            ' : '        '}if (!online) const Positioned.fill(child: OfflineView()),',
          ),
        );
      }
    });

    test('fails open', () {
      expect(riverpod.offlineGate(), contains('.value ?? true'));
      expect(
        ServicesTemplates.connectivityService(
          stateManagement: StateManagement.bloc,
        ),
        contains(': super(true)'),
      );
    });

    test('main.dart mounts it innermost and adds the reconnect hook', () {
      for (final stack in [riverpod, bloc]) {
        final source = stack.mainDart(
          withMaintenanceGate: true,
          withOfflineGate: true,
        );
        expect(
          source,
          contains('MaintenanceGate(child: OfflineGate(child: child!))'),
        );
        expect(
          source,
          contains('getIt<ConnectivityService>().onReconnect(() async {'),
        );
      }
      expect(riverpod.mainDart(), isNot(contains('OfflineGate')));
    });

    test('is in the catalog, with its service', () {
      expect(
        ScaffoldCatalog.byName('offline-gate')!.path,
        'lib/shared/widgets/offline_gate.dart',
      );
      expect(
        ScaffoldCatalog.byName('connectivity')!.path,
        'lib/core/services/connectivity_service.dart',
      );
    });
  });

  group('deep links', () {
    const manifest =
        '<manifest>\r\n'
        '    <application>\r\n'
        '        <activity\r\n'
        '            android:name=".MainActivity"\r\n'
        '            android:exported="true">\r\n'
        '            <intent-filter>\r\n'
        '                <action android:name="android.intent.action.MAIN"/>\r\n'
        '            </intent-filter>\r\n'
        '        </activity>\r\n'
        '    </application>\r\n'
        '</manifest>\r\n';

    String patch(String content) => ManifestUtils.ensureActivityIntentFilter(
      content,
      intentFilter: DeepLinksTemplates.androidIntentFilter('example.com'),
      marker: 'android:autoVerify="true"',
    );

    test('the intent filter goes inside MainActivity, once', () {
      final patched = patch(manifest);
      final filter = patched.indexOf('android:autoVerify="true"');
      expect(filter, greaterThan(patched.indexOf('.MainActivity')));
      expect(filter, lessThan(patched.indexOf('</activity>')));
      expect(patch(patched), patched);
    });

    test('keeps the manifest on its own line endings', () {
      final patched = patch(manifest);
      expect(patched.replaceAll('\r\n', ''), isNot(contains('\n')));
      expect(
        ManifestUtils.ensurePermissions(manifest, [
          'android.permission.X',
        ]).replaceAll('\r\n', ''),
        isNot(contains('\n')),
      );
    });

    test('a manifest without MainActivity is left alone', () {
      const other = '<manifest><application/></manifest>';
      expect(patch(other), other);
    });

    test('the guide is filled in with the project ids', () {
      final doc = DeepLinksTemplates.doc(
        androidApplicationId: 'dev.demo.app',
        iosBundleId: 'dev.demo.App',
      );
      expect(doc, contains('"package_name": "dev.demo.app"'));
      expect(doc, contains('"appIDs": ["<TEAM_ID>.dev.demo.App"]'));
      expect(doc, isNot(contains('## Signed-out users')));
      expect(
        DeepLinksTemplates.doc(withAuthFeature: true),
        contains('## Signed-out users'),
      );
    });

    test('the router carries a link through splash and login', () {
      for (final stack in [riverpod, bloc]) {
        final router = stack.appRouter(withAuth: true);
        expect(
          router,
          contains('_withFrom(AppRoutes.splash, state.uri.toString())'),
        );
        expect(
          router,
          contains('_withFrom(AppRoutes.login, state.uri.toString())'),
        );
        expect(router, contains('return from ?? AppRoutes.home;'));
        // Only an in-app path is followed.
        expect(
          router,
          contains(
            "if (from == null || !from.startsWith('/') || from.startsWith('//'))",
          ),
        );
      }
    });

    test('AGENTS.md says a route must open from its URL alone', () {
      final agents = AgentsTemplates.agentsMd(
        projectName: 'demo',
        stateManagement: StateManagement.bloc,
        withDeepLinks: true,
        withOfflineGate: true,
      );
      expect(agents, contains('## Links and connectivity'));
      expect(agents, contains('never from `extra`'));
      expect(agents, contains('`ConnectivityService.onReconnect`'));
      expect(
        AgentsTemplates.agentsMd(
          projectName: 'demo',
          stateManagement: StateManagement.bloc,
        ),
        isNot(contains('## Links and connectivity')),
      );
    });
  });
}
