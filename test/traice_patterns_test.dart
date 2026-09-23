// Patterns brought in from a production moarch project (9.0.0): the FCM
// background isolate, droppable submits, the feature module and the lifecycle
// service.
import 'package:moarch/src/templates/bloc/auth_templates.dart' as bloc;
import 'package:moarch/src/templates/bloc/firebase_auth_templates.dart'
    as bloc_firebase;
import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/misc/agents_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

void main() {
  group('FCM background isolate', () {
    test(
      'without local notifications it only initializes Firebase and logs',
      () {
        final source = ServicesTemplates.firebaseNotificationsService();
        expect(source, contains('if (Firebase.apps.isEmpty) await Firebase'));
        expect(source, isNot(contains('getIt<NotificationService>')));
        expect(source, isNot(contains("import 'notifications_service.dart';")));
        expect(source, isNot(contains('injector.dart')));
      },
    );

    test(
      'with local notifications it sets the isolate up and shows data-only',
      () {
        final source = ServicesTemplates.firebaseNotificationsService(
          withLocalNotifications: true,
        );
        expect(source, contains("import 'notifications_service.dart';"));
        expect(source, contains("import '../../config/di/injector.dart';"));
        expect(source, contains('await _setUpBackgroundIsolate();'));
        // Registered and initialized inside the isolate, idempotently.
        expect(
          source,
          contains('if (!getIt.isRegistered<NotificationService>())'),
        );
        expect(source, contains('await getIt<NotificationService>().init();'));
        // The OS already shows a message with a notification block.
        expect(
          source,
          contains('if (message.notification == null) await _showLocally'),
        );
        expect(source, contains('payload: jsonEncode(message.data)'));
      },
    );

    test('shows foreground messages the OS will not', () {
      final source = ServicesTemplates.firebaseNotificationsService(
        withLocalNotifications: true,
      );
      expect(
        source,
        contains('if (!_isApplePlatform || message.notification == null)'),
      );
      expect(source, isNot(contains('show one\n    // yourself')));
    });

    test('the catalog follows whether the local service exists', () {
      final spec = ScaffoldCatalog.byName('firebase-notifications')!;
      expect(
        spec.path,
        'lib/core/services/firebase_notifications_service.dart',
      );
    });
  });

  group('droppable submits (bloc)', () {
    test('the REST auth bloc drops repeated submits', () {
      final source = bloc.AuthTemplates.bloc(withConcurrency: true);
      expect(
        source,
        contains("import 'package:bloc_concurrency/bloc_concurrency.dart';"),
      );
      expect(
        source,
        contains('on<AuthLoginRequested>(_onLogin, transformer: droppable());'),
      );
      expect(
        source,
        contains(
          'on<AuthRegisterRequested>(_onRegister, transformer: droppable());',
        ),
      );
      // Session restore has to see every event.
      expect(source, contains('on<AuthStarted>(_onStarted);'));
    });

    test('the Firebase auth bloc drops repeated submits too', () {
      final source = bloc_firebase.FirebaseAuthTemplates.bloc(
        withConcurrency: true,
      );
      expect(
        source,
        contains(
          'on<AuthGoogleSignInRequested>(_onGoogleSignIn, '
          'transformer: droppable());',
        ),
      );
      expect(source, contains('on<AuthUserChanged>(_onUserChanged);'));
    });

    test('a project without bloc_concurrency keeps plain handlers', () {
      final source = bloc.AuthTemplates.bloc();
      expect(source, isNot(contains('bloc_concurrency')));
      expect(source, isNot(contains('droppable')));
    });
  });

  group('feature module', () {
    test('holds the feature registrar and the scope helpers', () {
      final source = InjectorTemplates.featureModule();
      expect(source, contains('void registerFeatureServices()'));
      expect(
        source,
        contains('void openScope(String name, void Function(GetIt scope)'),
      );
      expect(source, contains('await getIt.dropScope(name);'));
    });

    test('the root calls it only when the file exists', () {
      final withIt = InjectorTemplates.injector(
        stateManagement: StateManagement.bloc,
        withFeatureModule: true,
      );
      expect(withIt, contains("import 'feature_module.dart';"));
      expect(withIt, contains('registerFeatureServices();'));

      final without = InjectorTemplates.injector(
        stateManagement: StateManagement.bloc,
      );
      expect(without, isNot(contains('feature_module')));
      expect(without, isNot(contains('registerFeatureServices')));
    });

    test('AGENTS.md names it only when the project has it', () {
      String agents({required bool withFeatureModule}) =>
          AgentsTemplates.agentsMd(
            projectName: 'demo',
            stateManagement: StateManagement.riverpod,
            withFeatureModule: withFeatureModule,
          );
      expect(agents(withFeatureModule: true), contains('feature_module.dart'));
      expect(
        agents(withFeatureModule: false),
        isNot(contains('feature_module.dart')),
      );
    });
  });

  group('app lifecycle service', () {
    test('streams changes and how long the app was away', () {
      final source = ServicesTemplates.appLifecycleService();
      expect(source, contains('Stream<AppLifecycleState> get changes'));
      expect(source, contains('Stream<Duration> get resumed'));
      // Timed from hidden/paused, not inactive (a notification shade).
      expect(
        source,
        contains('case AppLifecycleState.hidden || AppLifecycleState.paused:'),
      );
      expect(source, contains('_listener.dispose();'));
    });

    test('the core module registers it with a dispose', () {
      final source = InjectorTemplates.coreModule(withAppLifecycle: true);
      expect(
        source,
        contains("import '../../core/services/app_lifecycle_service.dart';"),
      );
      expect(source, contains('dispose: (service) => service.dispose()'));
      expect(
        InjectorTemplates.coreModule(),
        isNot(contains('AppLifecycleService')),
      );
    });
  });
}
