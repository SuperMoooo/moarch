import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/ui/feature_templates.dart';
import 'package:moarch/src/templates/ui/modals_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:test/test.dart';

void main() {
  test('mainDart adds notification initialization when requested', () {
    final output = CoreTemplates.mainDart(
      withRouter: false,
      withNotificationsService: true,
    );

    expect(
        output, contains("import 'core/services/notifications_service.dart';"));
    expect(output, contains('await NotificationService.instance.init();'));
  });

  test('mainDart omits notification initialization by default', () {
    final output = CoreTemplates.mainDart(withRouter: false);

    expect(output,
        isNot(contains("import 'core/services/notifications_service.dart';")));
    expect(
        output, isNot(contains('await NotificationService.instance.init();')));
  });

  test('generated modals use the interface expected for testability', () {
    final output = ModalsTemplates.appBottomModals();

    expect(output, contains('implements IAppBottomModals'));
  });

  test('generated feature templates favor the safe API flow in datasource', () {
    final output =
        FeatureTemplates.remoteDatasource('sample', 'Sample', 'sample');

    expect(output, contains('safeApiCall<'));
    expect(output, contains('apiCall: () async'));
  });

  test('shared templates expose empty and success states', () {
    expect(SharedTemplates.emptyView(), contains('class EmptyView'));
  });
}
