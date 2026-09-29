import 'dart:io';

import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/api_constants_utils.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String libPath;

  Future<void> writeConstants(String source) async {
    final file = File(ApiConstantsUtils.fileFor(libPath));
    await file.create(recursive: true);
    await file.writeAsString(source);
  }

  Future<EndpointPatchResult> registerOrders() => ApiConstantsUtils.register(
    libPath,
    featureName: 'order_history',
    varName: 'orderHistory',
  );

  String constants() =>
      File(ApiConstantsUtils.fileFor(libPath)).readAsStringSync();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_api_test');
    libPath = p.join(tempDir.path, 'lib');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  test('the endpoint goes in above the anchor, inside ApiConstants', () async {
    await writeConstants(CoreTemplates.apiConstants(withAuthFeature: true));

    expect(await registerOrders(), EndpointPatchResult.added);
    final source = constants();
    expect(
      source,
      contains(
        "  static const orderHistory = '/order_history';\n"
        '  ${ApiConstantsUtils.anchor}\n}',
      ),
    );
    expect(CoreTemplates.declaredEndpoints(source), contains('orderHistory'));
  });

  test('a re-run declares nothing twice', () async {
    await writeConstants(CoreTemplates.apiConstants());
    await registerOrders();
    final once = constants();

    expect(await registerOrders(), EndpointPatchResult.alreadyThere);
    expect(constants(), once);
  });

  test('a file without the anchor is left alone', () async {
    const old = 'abstract final class ApiConstants {\n}\n';
    await writeConstants(old);

    expect(await registerOrders(), EndpointPatchResult.missingAnchor);
    expect(constants(), old);
    expect(EndpointPatchResult.missingAnchor.declared, isFalse);
  });

  test('a project without the file is reported, not created', () async {
    expect(await registerOrders(), EndpointPatchResult.noConstants);
    expect(File(ApiConstantsUtils.fileFor(libPath)).existsSync(), isFalse);
  });

  group('the feature datasource', () {
    for (final stack in StateManagement.values) {
      test('names its endpoint when it is declared (${stack.name})', () {
        final templates = StackTemplates(stack);
        final named = templates.featureRemoteDatasource(
          'order_history',
          'OrderHistory',
          'orderHistory',
          withApiConstant: true,
        );
        final inline = templates.featureRemoteDatasource(
          'order_history',
          'OrderHistory',
          'orderHistory',
        );

        expect(
          named,
          contains('_dio.get<List<dynamic>>(ApiConstants.orderHistory)'),
        );
        expect(
          named,
          contains("import '../../../../core/constants/api_constants.dart';"),
        );
        expect(inline, contains("_dio.get<List<dynamic>>('/order_history')"));
        expect(inline, isNot(contains('api_constants.dart')));
      });
    }
  });

  group('the gates', () {
    const dio = WidgetVariants(hasDio: true);

    for (final name in ['maintenance-gate', 'update-gate']) {
      test('$name reads its path from ApiConstants when declared', () {
        final spec = WidgetCatalog.byName(name)!;
        final declared = WidgetVariants(
          hasDio: true,
          apiEndpoints: CoreTemplates.declaredEndpoints(
            CoreTemplates.apiConstants(
              withMaintenanceGate: true,
              withUpdateGate: true,
            ),
          ),
        );

        final source = WidgetCatalog.sourceFor(spec, declared);
        expect(source, contains('ApiConstants.config'));
        expect(source, contains('core/constants/api_constants.dart'));
      });

      test('$name writes the path in a project that lacks it', () {
        final source = WidgetCatalog.sourceFor(
          WidgetCatalog.byName(name)!,
          dio,
        );

        expect(source, isNot(contains('ApiConstants')));
        expect(source, isNot(contains('api_constants.dart')));
        expect(source, contains("'/config/"));
      });
    }
  });
}
