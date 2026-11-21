import 'package:moarch/src/commands/init_command.dart';
import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/product_templates.dart';
import 'package:moarch/src/templates/misc/ios_templates.dart';
import 'package:moarch/src/templates/misc/project_docs_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/package_versions.dart';
import 'package:moarch/src/utils/platform_requirements.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/service_options.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

const _rest = ServiceVariant(withDio: true);
const _firebase = ServiceVariant(withFirestore: true, withFirebaseAuth: true);

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="demo">
        <activity
            android:name=".MainActivity">
        </activity>
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
        </intent>
    </queries>
</manifest>
''';

void main() {
  group('ServiceOptions', () {
    test('names, labels and paths are unique', () {
      for (final read in <String Function(ServiceOption)>[
        (o) => o.name,
        (o) => o.label,
        (o) => o.path,
      ]) {
        final values = ServiceOptions.all.map(read).toList();
        expect(values.toSet(), hasLength(values.length));
      }
    });

    for (final option in ServiceOptions.all) {
      group(option.name, () {
        test('declares its class, under lib/core/', () {
          expect(option.path, startsWith('lib/core/'));
          for (final variant in [_rest, _firebase]) {
            expect(option.template(variant), contains('class ${option.title}'));
          }
        });

        test('pins every package it adds', () {
          for (final package in option.packages) {
            expect(
              PackageVersions.packages,
              contains(package),
              reason: '$package has no constraint in PackageVersions',
            );
          }
        });

        test('is refreshed by update', () {
          final spec = ScaffoldCatalog.all.singleWhere(
            (spec) => spec.name == option.name,
          );
          expect(spec.path, option.path);
        });

        test('declares every endpoint its template reads', () {
          for (final variant in [_rest, _firebase]) {
            final source = option.template(variant);
            final read = RegExp(
              r'ApiConstants\.(\w+)',
            ).allMatches(source).map((m) => m.group(1)!).toSet();
            expect(option.endpoints(variant).keys.toSet(), containsAll(read));
            // And an older ApiConstants gets them inlined.
            for (final name in read) {
              expect(CoreTemplates.endpointLiterals, contains(name));
            }
          }
        });
      });
    }
  });

  group('the core module', () {
    final module = InjectorTemplates.coreModule(
      withSync: true,
      services: ServiceOptions.all,
      serviceVariant: _rest,
    );

    test('imports and registers each service', () {
      for (final option in ServiceOptions.all) {
        expect(module, contains(option.import));
        expect(module, contains('registerLazySingleton<${option.title}>'));
      }
    });

    test('imports Dio once, though sync and three services need it', () {
      expect("import 'package:dio/dio.dart';".allMatches(module), hasLength(1));
    });

    test('hands moderation the Firebase handles when it has them', () {
      final firebase = InjectorTemplates.coreModule(
        services: [ServiceOptions.moderation],
        serviceVariant: _firebase,
      );
      expect(firebase, contains('getIt<FirebaseFirestore>()'));
      expect(firebase, contains("import 'package:firebase_auth/"));
      expect(firebase, isNot(contains('getIt<Dio>()')));
    });
  });

  test('moderation over REST declares its endpoints; Firestore none', () {
    final rest = CoreTemplates.apiConstants(
      serviceEndpoints: ServiceOptions.moderation.endpoints(_rest),
    );
    expect(rest, contains("static const moderationReports = '/moderation/"));
    expect(ServiceOptions.moderation.endpoints(_firebase), isEmpty);
    expect(
      ServiceOptions.moderation.template(_firebase),
      contains("collection('reports')"),
    );
  });

  test('purchases are never delivered without a server check', () {
    final local = ProductTemplates.purchaseService();
    expect(local, contains('return false;'));
    expect(local, contains('TODO'));
    final rest = ProductTemplates.purchaseService(withDio: true);
    expect(rest, contains('ApiConstants.purchasesVerify'));
  });

  test('the Dio client checks pins only when asked', () {
    final pinned = CoreTemplates.dioClient(withPinning: true);
    expect(pinned, contains("import 'certificate_pins.dart';"));
    expect(pinned, contains('CertificatePins.allows(certificate)'));
    expect(CoreTemplates.dioClient(), isNot(contains('CertificatePins')));
    expect(ProductTemplates.certificatePins(), contains('sha256.convert'));
  });

  test('the edge runtime registers only the engines the app uses', () {
    final llmOnly = ProductTemplates.edgeAiRuntime();
    expect(llmOnly, contains('const [LiteRtLmEngine()]'));
    expect(llmOnly, isNot(contains('sttBackends')));
    final all = ProductTemplates.edgeAiRuntime(
      withSpeech: true,
      withSearch: true,
    );
    expect(all, contains('sttBackends: const [LiteRtSttBackend()]'));
    expect(
      all,
      contains('embeddingBackends: const [LiteRtEmbeddingBackend()]'),
    );
  });

  test('health declares Health Connect inside MainActivity, once', () {
    final out = PlatformRequirement.health.patchManifest(_manifest);
    final activity = out.indexOf('android:name=".MainActivity"');
    final rationale = out.indexOf('Health Connect: the permissions rationale');
    expect(rationale, greaterThan(activity));
    expect(rationale, lessThan(out.indexOf('</activity>')));
    expect(out, contains('com.google.android.apps.healthdata'));
    expect(out, contains('ViewPermissionUsageActivity'));
    expect(out, contains('android.permission.health.READ_STEPS'));
    expect(PlatformRequirement.health.patchManifest(out), out);
  });

  test('the entitlements carry HealthKit and the memory limit', () {
    final out = IosTemplates.runnerEntitlements(
      withPush: false,
      withHealthKit: true,
      withIncreasedMemory: true,
    );
    expect(out, contains('com.apple.developer.healthkit'));
    expect(out, contains('com.apple.developer.kernel.increased-memory-limit'));
    expect(
      IosTemplates.runnerProfileEntitlements(withPush: false),
      isNot(contains('healthkit')),
    );
  });

  test('both stacks mount the onboarding gate', () {
    for (final stack in StateManagement.values) {
      final main = StackTemplates(stack).mainDart(withOnboarding: true);
      expect(main, contains("import 'shared/widgets/onboarding_gate.dart';"));
      expect(main, contains('OnboardingGate(child: '));
    }
  });

  test('the services guide lists each service the project has', () {
    final services = ProjectDocsTemplates.all.singleWhere(
      (doc) => doc.slug == 'services-doc',
    );
    final doc = services.render!(
      DocsOptions(
        projectName: 'demo',
        stateManagement: StateManagement.riverpod,
        services: {ServiceOptions.share.name},
      ),
    );
    expect(doc, contains('`ShareService`'));
    expect(doc, isNot(contains('`ScannerService`')));
  });

  group('the rules between options', () {
    test('the session lock brings the lifecycle service', () {
      final stack = {ServiceOptions.sessionLock.label};
      InitCommand.reconcileSelection(stack);
      expect(stack, contains('App lifecycle service (revalidate on resume)'));
    });

    test('integrity and pinning need Dio', () {
      final stack = {
        ServiceOptions.integrity.label,
        'Certificate pinning (Dio)',
      };
      expect(InitCommand.reconcileSelection(stack), hasLength(2));
      expect(stack, isEmpty);
    });

    test('moderation needs Dio, or Firestore with Firebase Auth', () {
      final alone = {ServiceOptions.moderation.label};
      InitCommand.reconcileSelection(alone);
      expect(alone, isEmpty);
      final firebase = {
        ServiceOptions.moderation.label,
        'Firebase Firestore',
        'Firebase Auth',
      };
      expect(InitCommand.reconcileSelection(firebase), isEmpty);
    });

    test('voice and search need on-device AI', () {
      final stack = {
        ServiceOptions.voice.label,
        ServiceOptions.knowledge.label,
      };
      InitCommand.reconcileSelection(stack);
      expect(stack, isEmpty);
    });
  });
}
