import 'dart:io';

import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/core/feature_flags_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('the flags', () {
    test('are typed getters over the backend map, with fallbacks', () {
      final source = FeatureFlagsTemplates.featureFlags();

      expect(source, contains('class FeatureFlags {'));
      expect(
        source,
        contains('const FeatureFlags([this._values = const {}]);'),
      );
      expect(
        source,
        contains('bool flag(String key, {required bool fallback}) {'),
      );
      expect(source, contains('return value is bool ? value : fallback;'));
      // Starts empty: the getters are the project's to write.
      expect(
        source,
        contains(
          "// bool get newCheckout => flag('new_checkout', fallback: false);",
        ),
      );
    });

    test('over Dio: polled, on resume too, failures keep the last flags', () {
      final source = FeatureFlagsTemplates.featureFlags();

      expect(source, contains("import 'package:dio/dio.dart';"));
      expect(source, contains('ApiConstants.configFlags,'));
      expect(source, contains('Timer.periodic(pollInterval'));
      expect(source, contains('AppLifecycleListener(onResume:'));
      expect(source, contains("_log.w('Not read, keeping the last flags'"));
      expect(source, isNot(contains('cloud_firestore')));
    });

    test('with Firestore: the config/flags document, live', () {
      final source = FeatureFlagsTemplates.featureFlags(withFirestore: true);

      expect(source, contains(".collection('config')"));
      expect(source, contains(".doc('flags')"));
      expect(source, contains('.snapshots()'));
      expect(source, contains('allow read: if true;'));
      expect(source, isNot(contains('package:dio')));
      expect(source, isNot(contains('ApiConstants')));
    });

    test('the holder follows the stack', () {
      final riverpod = FeatureFlagsTemplates.featureFlags();
      final bloc = FeatureFlagsTemplates.featureFlags(
        stateManagement: StateManagement.bloc,
      );

      expect(riverpod, contains('final featureFlagsProvider = StreamProvider'));
      expect(riverpod, isNot(contains('Cubit')));
      expect(
        bloc,
        contains('class FeatureFlagsCubit extends Cubit<FeatureFlags> {'),
      );
      expect(bloc, isNot(contains('flutter_riverpod')));
      expect(bloc, isNot(contains('injector.dart')));
    });
  });

  group('the app around it', () {
    test('ApiConstants declares the endpoint only with flags', () {
      expect(
        CoreTemplates.apiConstants(withFeatureFlags: true),
        contains("static const configFlags = '/config/flags';"),
      );
      expect(CoreTemplates.apiConstants(), isNot(contains('configFlags')));
      expect(CoreTemplates.endpointLiterals['configFlags'], '/config/flags');
    });

    test('the core module starts the service from its source', () {
      const stack = StackTemplates(StateManagement.riverpod);
      final overDio = stack.coreModule(withFeatureFlags: true);
      final firestore = stack.coreModule(
        withFeatureFlags: true,
        flagsFromFirestore: true,
      );

      expect(overDio, contains('FeatureFlagsService(getIt<Dio>())..start()'));
      expect(overDio, contains("import 'package:dio/dio.dart';"));
      expect(
        firestore,
        contains('FeatureFlagsService(getIt<FirebaseFirestore>())..start()'),
      );
      expect(
        firestore,
        contains("import 'package:cloud_firestore/cloud_firestore.dart';"),
      );
      expect(firestore, isNot(contains('package:dio')));
      expect(stack.coreModule(), isNot(contains('FeatureFlags')));
    });

    test('is a catalog entry', () {
      expect(
        ScaffoldCatalog.byName('feature-flags')?.path,
        'lib/core/services/feature_flags.dart',
      );
    });
  });

  group('detection', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_flags_test');
    });

    tearDown(() async => tempDir.delete(recursive: true));

    test('hasFeatureFlags reads feature_flags.dart off disk', () async {
      expect(ScaffoldContext.detect(tempDir.path).hasFeatureFlags, isFalse);
      await File(
        p.join(tempDir.path, 'lib', 'core', 'services', 'feature_flags.dart'),
      ).create(recursive: true);
      expect(ScaffoldContext.detect(tempDir.path).hasFeatureFlags, isTrue);
    });

    test('an older ApiConstants gets the path inlined', () async {
      final spec = ScaffoldCatalog.byName('feature-flags')!;
      await File(
        p.join(tempDir.path, 'lib', 'core', 'constants', 'api_constants.dart'),
      ).create(recursive: true);

      final source = spec.template(ScaffoldContext.detect(tempDir.path));
      expect(source, contains("'/config/flags',"));
      expect(source, isNot(contains('api_constants.dart')));
    });
  });
}
