import 'dart:io';

import 'package:moarch/src/templates/config/config_templates.dart';
import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:moarch/src/templates/riverpod/app_templates.dart'
    as riverpod;
import 'package:test/test.dart';

/// Every `AppConstants.<token>` a source refers to.
Set<String> _referenced(String source) =>
    RegExp(r'AppConstants\.(\w+)').allMatches(source).map((m) => m[1]!).toSet();

/// Every token `AppConstants` declares.
Set<String> _declared(String source) =>
    RegExp(r'static (?:const|final)[^=]*?(\w+)\s*=')
        .allMatches(source)
        .map((m) => m[1]!)
        .toSet();

void main() {
  group('AppConstants', () {
    test('holds one palette by default', () {
      final output = CoreTemplates.appConstants();

      expect(output, contains('static const Color primary'));
      expect(output, contains('static const Color success'));
      expect(output, isNot(contains('Dark')));
    });

    test('adds the dark half when asked, without moving the light one', () {
      final light = CoreTemplates.appConstants();
      final dark = CoreTemplates.appConstants(withDark: true);

      expect(dark, contains('static const Color primaryDark'));
      expect(dark, contains('static const Color surfaceContainerLowestDark'));
      expect(dark, contains('static const Color successDark'));
      // The light half is the same text either way, so switching scope never
      // rewrites a color the project already set.
      for (final token in _declared(light)) {
        expect(dark, contains(token), reason: '$token went missing');
      }
    });

    test('declares no token the generated code never reads', () {
      // The kit is the only consumer; a token nothing reads is dead weight in
      // every project moarch generates.
      const everything = WidgetVariants(
        hasBiometric: true,
        hasFirestore: true,
        hasDio: true,
      );

      final used = <String>{
        ..._referenced(ConfigTemplates.appTheme()),
        ..._referenced(riverpod.AppTemplates.mainDart()),
        for (final spec in WidgetCatalog.all)
          ..._referenced(WidgetCatalog.sourceFor(spec, everything)),
      };

      // radius4 is read by borderRadius4 inside the class, unprefixed.
      final unused = _declared(CoreTemplates.appConstants()).difference(used)
        ..remove('radius4');
      expect(unused, isEmpty, reason: 'unused constants: $unused');
    });
  });

  group('theme scope', () {
    // The dark palette and everything reading it are generated against each
    // other: a reference to a token the project does not declare is a project
    // that does not compile.
    for (final dark in [false, true]) {
      test('every AppConstants reference resolves with withDark: $dark', () {
        final declared = _declared(CoreTemplates.appConstants(withDark: dark));
        final variants = WidgetVariants(
          hasBiometric: true,
          hasFirestore: true,
          hasDio: true,
          hasDarkTheme: dark,
        );

        final sources = <String, String>{
          'app_theme.dart': ConfigTemplates.appTheme(withDark: dark),
          'main.dart': riverpod.AppTemplates.mainDart(withDarkTheme: dark),
          for (final spec in WidgetCatalog.all)
            spec.file: WidgetCatalog.sourceFor(spec, variants),
        };

        sources.forEach((name, source) {
          expect(_referenced(source).difference(declared), isEmpty,
              reason: '$name reads a token AppConstants does not declare');
        });
      });
    }
  });

  group('AppTheme', () {
    test('is light-only by default', () {
      final output = ConfigTemplates.appTheme();

      expect(output, contains('static ThemeData get light => ThemeData('));
      expect(output, isNot(contains('get dark')));
      expect(output, isNot(contains('Brightness.dark')));
    });

    test('gains the dark getter when asked', () {
      final output = ConfigTemplates.appTheme(withDark: true);

      expect(output, contains('static ThemeData get light => ThemeData('));
      expect(output, contains('static ThemeData get dark => ThemeData('));
      expect(output, contains('brightness: Brightness.dark'));
    });
  });

  group('main.dart', () {
    for (final withRouter in [true, false]) {
      test('hands MaterialApp one theme by default (router: $withRouter)', () {
        final output = riverpod.AppTemplates.mainDart(withRouter: withRouter);

        expect(output, contains('theme: AppTheme.light,'));
        expect(output, isNot(contains('AppTheme.dark')));
        // A themeMode with nothing to switch to would resolve to the same
        // theme in every mode.
        expect(output, isNot(contains('themeMode:')));
      });

      test('follows the system brightness with dark (router: $withRouter)', () {
        final output = riverpod.AppTemplates.mainDart(
          withRouter: withRouter,
          withDarkTheme: true,
        );

        expect(output, contains('theme: AppTheme.light,'));
        expect(output, contains('darkTheme: AppTheme.dark,'));
        expect(output, contains('themeMode: ThemeMode.system,'));
        // The dark theme was commented out for years; a commented line here
        // means the option silently did nothing again.
        expect(output, isNot(contains('//darkTheme')));
      });
    }
  });

  group('DesignSystemView', () {
    test('drops the brightness toggle with a single theme', () {
      final output = SharedTemplates.designSystemView();

      expect(output, contains('theme: AppTheme.light,'));
      expect(output, isNot(contains('AppTheme.dark')));
      expect(output, isNot(contains('ThemeMode')));
      expect(output, isNot(contains('_toggleTheme')));
      expect(output, isNot(contains('Toggle theme')));
    });

    test('previews both themes when the project has both', () {
      final output = SharedTemplates.designSystemView(withDark: true);

      expect(output, contains('themeMode: _mode,'));
      expect(output, contains('darkTheme: AppTheme.dark,'));
      expect(output, contains('void _toggleTheme() => setState(() {'));
      expect(output, contains("tooltip: 'Toggle theme',"));
      // The toggle only works if MaterialApp actually gets the second theme.
      expect(output, isNot(contains('//darkTheme')));
    });
  });

  group('detection', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('moarch_theme'));
    tearDown(() => temp.deleteSync(recursive: true));

    void writeTheme(String content) {
      final file = File(
        '${temp.path}/lib/config/theme/app_theme.dart',
      )..createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    test('reads the scope off app_theme.dart, not off the checklist', () {
      writeTheme(ConfigTemplates.appTheme(withDark: true));
      expect(WidgetVariants.hasDarkThemeIn('${temp.path}/lib'), isTrue);
      expect(ScaffoldContext.detect(temp.path).hasDarkTheme, isTrue);

      writeTheme(ConfigTemplates.appTheme());
      expect(WidgetVariants.hasDarkThemeIn('${temp.path}/lib'), isFalse);
      expect(ScaffoldContext.detect(temp.path).hasDarkTheme, isFalse);
    });

    test('a project without a theme file has no dark theme', () {
      expect(WidgetVariants.hasDarkThemeIn('${temp.path}/lib'), isFalse);
      expect(ScaffoldContext.detect(temp.path).hasDarkTheme, isFalse);
    });

    test('detect() carries the scope into the widget variants', () {
      writeTheme(ConfigTemplates.appTheme(withDark: true));
      final variants = WidgetVariants.detect('${temp.path}/lib');
      expect(variants.hasDarkTheme, isTrue);

      final toast = WidgetCatalog.sourceFor(
        WidgetCatalog.byName('toast')!,
        variants,
      );
      expect(toast, contains('AppConstants.successDark'));
    });
  });
}
