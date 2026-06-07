import 'package:moarch/src/templates/core/core_templates.dart';
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
}
