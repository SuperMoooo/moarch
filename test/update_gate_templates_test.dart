import 'package:moarch/src/templates/bloc/app_templates.dart' as bloc;
import 'package:moarch/src/templates/bloc/update_gate_templates.dart' as bloc;
import 'package:moarch/src/templates/riverpod/app_templates.dart' as riverpod;
import 'package:moarch/src/templates/riverpod/update_gate_templates.dart'
    as riverpod;
import 'package:moarch/src/utils/state_management.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  final variants =
      <String, String Function({bool withFirestore, bool withDio})>{
        'riverpod': riverpod.UpdateGateTemplates.updateGate,
        'bloc': bloc.UpdateGateTemplates.updateGate,
      };

  for (final entry in variants.entries) {
    final updateGate = entry.value;

    group('${entry.key} update gate', () {
      test('every backend variant shares the policy and the screen', () {
        for (final source in [
          updateGate(),
          updateGate(withFirestore: true),
          updateGate(withDio: true),
        ]) {
          expect(source, contains('class UpdatePolicy'));
          expect(source, contains('int? compareVersions(String a, String b)'));
          expect(source, contains('class UpdateRequiredView'));
          expect(source, contains('class UpdateGate'));
          expect(source, contains('PackageInfo.fromPlatform()'));
          expect(source, contains('LaunchMode.externalApplication'));
          // material.dart does not export defaultTargetPlatform.
          expect(source, contains("import 'package:flutter/foundation.dart';"));
        }
      });

      test('Firestore watches config/app_version', () {
        final source = updateGate(withFirestore: true);
        expect(source, contains(".doc('app_version')"));
        expect(source, contains('getIt<FirebaseFirestore>()'));
        expect(source, isNot(contains('package:dio/dio.dart')));
      });

      test('Dio re-reads on resume, not on a timer', () {
        final source = updateGate(withDio: true);
        expect(source, contains("'/config/app-version'"));
        expect(source, contains('AppLifecycleListener(onResume: check)'));
        expect(source, isNot(contains('Timer.periodic')));
        expect(source, isNot(contains('cloud_firestore')));
      });

      test('the stub reads no backend', () {
        final source = updateGate();
        expect(source, isNot(contains('injector.dart')));
        expect(source, isNot(contains('package:dio/dio.dart')));
        expect(source, isNot(contains('cloud_firestore')));
      });

      test('an unreadable policy reads as no minimum', () {
        // The failed request falls back to `none`, the fail-open value —
        // returned by the provider's helper, assigned in the cubit.
        final source = updateGate(withDio: true);
        expect(
          source,
          anyOf(
            contains('return const UpdatePolicy.none();\n  }\n}'),
            contains('policy = const UpdatePolicy.none();'),
          ),
        );
      });
    });
  }

  test('bloc owns its cubit and waives the file-name rule for it', () {
    final source = bloc.UpdateGateTemplates.updateGate(withDio: true);
    expect(
      source,
      contains('class UpdateGateCubit extends Cubit<UpdatePolicy?>'),
    );
    expect(source, contains('// ignore: prefer_file_naming_conventions'));
    expect(source, contains('create: (_) => _createUpdateGateCubit()'));
  });

  test(
    'riverpod reads both values with .value, so loading lets the app in',
    () {
      final source = riverpod.UpdateGateTemplates.updateGate();
      expect(source, contains('ref.watch(installedVersionProvider).value'));
      expect(source, contains('ref.watch(updatePolicyProvider).value'));
    },
  );

  group('main.dart', () {
    test('mounts the update gate inside the maintenance gate', () {
      for (final source in [
        riverpod.AppTemplates.mainDart(
          withMaintenanceGate: true,
          withUpdateGate: true,
        ),
        bloc.AppTemplates.mainDart(
          withMaintenanceGate: true,
          withUpdateGate: true,
        ),
      ]) {
        expect(source, contains("import 'shared/widgets/update_gate.dart';"));
        expect(
          source,
          contains('MaintenanceGate(child: UpdateGate(child: child!))'),
        );
      }
    });

    test('mounts it alone when there is no maintenance gate', () {
      final source = riverpod.AppTemplates.mainDart(withUpdateGate: true);
      expect(source, contains('UpdateGate(child: child!)'));
      expect(source, isNot(contains('MaintenanceGate')));
    });

    test('is absent unless asked for', () {
      expect(riverpod.AppTemplates.mainDart(), isNot(contains('UpdateGate')));
    });
  });

  group('catalog', () {
    test('follows the project backend and stack', () {
      final spec = WidgetCatalog.byName('update-gate')!;
      final blocFirestore = WidgetCatalog.sourceFor(
        spec,
        const WidgetVariants(
          hasFirestore: true,
          hasDio: true,
          stateManagement: StateManagement.bloc,
        ),
      );
      expect(
        blocFirestore,
        contains('UpdateGateCubit(getIt<FirebaseFirestore>())'),
      );

      final riverpodDio = WidgetCatalog.sourceFor(
        spec,
        const WidgetVariants(hasDio: true),
      );
      expect(riverpodDio, contains('final dio = getIt<Dio>();'));
    });

    test('brings the packages it imports', () {
      expect(
        WidgetCatalog.byName('update-gate')!.packages,
        containsAll(['package_info_plus: ', 'url_launcher: ']),
      );
    });
  });
}
