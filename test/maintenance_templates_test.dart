import 'package:moarch/src/templates/riverpod/maintenance_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('maintenanceGate', () {
    test('fails open — an unread status resolves to "up"', () {
      // The whole point: a fault in the check must not lock every user out.
      for (final source in [
        MaintenanceTemplates.maintenanceGate(),
        MaintenanceTemplates.maintenanceGate(withFirestore: true),
        MaintenanceTemplates.maintenanceGate(withDio: true),
      ]) {
        expect(source, contains('.value ??'));
        expect(source, contains('const MaintenanceStatus.up();'));
        expect(source, contains('map[\'active\'] as bool? ?? false'));
      }
    });

    test('blank copy falls back to the default wording', () {
      // A document seeded from the console starts as `title: ""`, and an empty
      // string is not null — without this the gate would close on a screen with
      // no heading and no body, which reads as a crash rather than an outage.
      final source = MaintenanceTemplates.maintenanceGate();

      expect(source, contains("title: _text(map['title'])"));
      expect(source, contains("message: _text(map['message'])"));
      expect(source, contains('trimmed.isEmpty ? null : trimmed'));
      expect(source, contains("status.title ?? 'Under maintenance'"));
    });

    test('blocks by replacing the app, not by covering it', () {
      final source = MaintenanceTemplates.maintenanceGate();

      // Returning the child unchanged is the only path through when the flag
      // is off, and MaintenanceView is the only path when it is on — there is
      // no overlay a route could be pushed on top of.
      expect(source, contains('if (!status.isActive) return child;'));
      expect(source, contains('return MaintenanceView(status: status);'));
    });

    test('the Firestore variant watches, the Dio variant polls', () {
      final firestore =
          MaintenanceTemplates.maintenanceGate(withFirestore: true);
      final dio = MaintenanceTemplates.maintenanceGate(withDio: true);

      // The status is state, so it stays a Riverpod provider; what it reads
      // is a dependency, so that comes out of the locator.
      expect(firestore, contains('getIt<FirebaseFirestore>()'));
      expect(firestore, contains('final maintenanceStatusProvider'));
      expect(firestore, contains('.snapshots()'));
      expect(firestore, isNot(contains('Timer.periodic')));

      expect(dio, contains('getIt<Dio>()'));
      expect(dio, contains('final maintenanceStatusProvider'));
      expect(dio, contains('Timer.periodic'));
      expect(dio, contains('AppLifecycleListener'));
      expect(dio, isNot(contains('FirebaseFirestore')));
    });

    test('a polled source is torn down with the provider', () {
      // An orphaned Timer would keep hitting the endpoint for the life of the
      // process, and a StreamController left open leaks the subscription.
      final dio = MaintenanceTemplates.maintenanceGate(withDio: true);

      expect(dio, contains('ref.onDispose('));
      expect(dio, contains('timer.cancel()'));
      expect(dio, contains('lifecycle.dispose()'));
      expect(dio, contains('controller.close()'));
    });

    test('each variant imports only what it uses', () {
      final stub = MaintenanceTemplates.maintenanceGate();
      final firestore =
          MaintenanceTemplates.maintenanceGate(withFirestore: true);
      final dio = MaintenanceTemplates.maintenanceGate(withDio: true);

      // The stub reads nothing, so it needs neither the locator nor a client.
      expect(stub, isNot(contains('injector.dart')));
      expect(stub, isNot(contains('package:dio/dio.dart')));
      expect(stub, isNot(contains('cloud_firestore')));
      expect(stub, isNot(contains("import 'dart:async'")));

      expect(firestore,
          contains("import 'package:cloud_firestore/cloud_firestore.dart';"));
      expect(firestore, contains("import '../../config/di/injector.dart';"));
      expect(firestore, isNot(contains('package:dio/dio.dart')));

      expect(dio, contains("import 'package:dio/dio.dart';"));
      expect(dio, contains("import '../../config/di/injector.dart';"));
      expect(dio, contains("import 'dart:async'"));
      expect(dio, isNot(contains('cloud_firestore')));

      // ErrorView does the drawing in all three.
      for (final source in [stub, firestore, dio]) {
        expect(source, contains("import 'error_view.dart';"));
      }
    });
  });

  group('WidgetCatalog.sourceFor', () {
    test('a project with both backends watches rather than polls', () {
      // Firestore wins: a live listener beats a five-minute poll, and
      // generating both would leave two sources of the same truth.
      const spec = 'maintenance-gate';
      final source = WidgetCatalog.sourceFor(
        WidgetCatalog.byName(spec)!,
        const WidgetVariants(hasFirestore: true, hasDio: true),
      );

      expect(source, contains('.snapshots()'));
      expect(source, isNot(contains('Timer.periodic')));
    });

    test('falls back to the plain template for widgets that do not vary', () {
      final spec = WidgetCatalog.byName('error-view')!;

      expect(
        WidgetCatalog.sourceFor(spec, const WidgetVariants(hasDio: true)),
        spec.template(),
      );
    });

    test('AppButton follows the biometric option', () {
      final spec = WidgetCatalog.byName('button')!;

      expect(
        WidgetCatalog.sourceFor(spec, const WidgetVariants(hasBiometric: true)),
        isNot(WidgetCatalog.sourceFor(spec, const WidgetVariants())),
      );
    });
  });
}
