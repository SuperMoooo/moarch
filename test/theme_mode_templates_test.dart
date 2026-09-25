import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

void main() {
  const riverpod = StackTemplates(StateManagement.riverpod);
  const bloc = StackTemplates(StateManagement.bloc);

  group('the saved theme mode', () {
    test('main.dart watches it on both stacks', () {
      expect(
        riverpod.mainDart(withDarkTheme: true, withThemeMode: true),
        allOf(
          contains("import 'core/services/theme_mode_service.dart';"),
          contains('themeMode: ref.watch(themeModeProvider),'),
        ),
      );
      expect(
        bloc.mainDart(withDarkTheme: true, withThemeMode: true),
        allOf(
          contains(
            'create: (_) => ThemeModeCubit(getIt<PreferencesService>()),',
          ),
          contains('themeMode: context.watch<ThemeModeCubit>().state,'),
        ),
      );
    });

    test('means nothing without a dark theme to switch to', () {
      for (final stack in [riverpod, bloc]) {
        final source = stack.mainDart(withThemeMode: true);
        expect(source, isNot(contains('ThemeMode')));
        expect(source, isNot(contains('theme_mode_service')));
      }
    });

    test('a dark theme from before it follows the system', () {
      for (final stack in [riverpod, bloc]) {
        expect(
          stack.mainDart(withDarkTheme: true),
          contains('themeMode: ThemeMode.system,'),
        );
      }
    });

    test('the holder starts from the saved choice', () {
      expect(
        riverpod.themeModeService(),
        contains(
          'ThemeMode.values.asNameMap()[_prefs.getString(_key)] ?? ThemeMode.system',
        ),
      );
      expect(bloc.themeModeService(), contains('class ThemeModeCubit'));
      for (final stack in [riverpod, bloc]) {
        expect(
          stack.themeModeService(),
          contains('await _prefs.setString(_key, mode.name);'),
        );
      }
    });

    test('preferences load before runApp, so reads are synchronous', () {
      expect(
        ServicesTemplates.preferencesService(),
        contains('await SharedPreferencesWithCache.create('),
      );
      expect(
        InjectorTemplates.coreModule(withPreferences: true),
        contains(
          '..registerSingletonAsync<PreferencesService>(PreferencesService.create)',
        ),
      );
      expect(
        InjectorTemplates.coreModule(),
        isNot(contains('PreferencesService')),
      );
    });

    test('both files are in the catalog, so update can refresh them', () {
      expect(
        ScaffoldCatalog.byName('preferences')!.path,
        'lib/core/services/preferences_service.dart',
      );
      expect(
        ScaffoldCatalog.byName('theme-mode')!.path,
        'lib/core/services/theme_mode_service.dart',
      );
    });
  });
}
