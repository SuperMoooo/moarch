import 'package:moarch/src/templates/config/config_templates.dart';
import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('AppStatusColors', () {
    test('is a ThemeExtension with a safe fallback', () {
      final source = ConfigTemplates.appStatusColors();
      expect(
        source,
        contains(
          'class AppStatusColors extends ThemeExtension<AppStatusColors>',
        ),
      );
      expect(source, contains('theme.extension<AppStatusColors>() ?? light'));
      expect(source, contains('AppStatusColors get statusColors'));
      expect(source, contains('AppStatusColors lerp('));
    });

    test('has a dark set only with the dark palette', () {
      expect(ConfigTemplates.appStatusColors(), isNot(contains('successDark')));
      expect(
        ConfigTemplates.appStatusColors(withDark: true),
        contains('success: AppConstants.successDark'),
      );
    });
  });

  group('AppTheme', () {
    test('registers the extension on each theme only when it exists', () {
      final withIt = ConfigTemplates.appTheme(
        withDark: true,
        withStatusColors: true,
      );
      expect(withIt, contains("import 'app_status_colors.dart';"));
      expect(withIt, contains('extensions: const [AppStatusColors.light]'));
      expect(withIt, contains('extensions: const [AppStatusColors.dark]'));

      // A project scaffolded before the file existed refreshes into a theme
      // that does not import it.
      final without = ConfigTemplates.appTheme(withDark: true);
      expect(without, isNot(contains('AppStatusColors')));
    });
  });

  group('status widgets', () {
    test('read the theme when the project has AppStatusColors', () {
      for (final source in [
        SharedTemplates.appTag(withStatusColors: true),
        SharedTemplates.appBanner(withStatusColors: true),
      ]) {
        expect(
          source,
          contains("import '../../../config/theme/app_status_colors.dart';"),
        );
        expect(source, contains('AppStatusColors.of(theme).success'));
        expect(source, isNot(contains('AppConstants.success')));
      }

      final toast = SharedTemplates.appToast(
        withDark: true,
        withStatusColors: true,
      );
      expect(toast, contains('context.statusColors'));
      expect(toast, isNot(contains('AppConstants.successDark')));
    });

    test('keep AppConstants in a project without it', () {
      expect(SharedTemplates.appTag(), contains('AppConstants.success'));
      expect(SharedTemplates.appBanner(), contains('AppConstants.success'));
      expect(
        SharedTemplates.appToast(withDark: true),
        contains('AppConstants.successDark'),
      );
    });
  });

  group('motion tokens', () {
    test('AppConstants declares every token a widget may inline', () {
      final constants = CoreTemplates.appConstants();
      for (final token in CoreTemplates.tokenLiterals.keys) {
        expect(constants, contains(token.split('.').last));
      }
    });

    test('a project whose AppConstants predates them gets literals', () {
      final spec = WidgetCatalog.byName('toast')!;
      final current = WidgetCatalog.sourceFor(
        spec,
        const WidgetVariants(hasMotionTokens: true),
      );
      final legacy = WidgetCatalog.sourceFor(spec, const WidgetVariants());

      expect(current, contains('AppConstants.curveEnter'));
      expect(legacy, isNot(contains('AppConstants.curve')));
      expect(legacy, contains('Curves.easeOutCubic'));
    });
  });
}
