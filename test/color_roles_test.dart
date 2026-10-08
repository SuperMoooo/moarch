import 'dart:io';
import 'dart:math' as math;

import 'package:moarch/src/templates/bloc/app_templates.dart' as bloc;
import 'package:moarch/src/templates/config/config_templates.dart';
import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/ui/content_templates.dart';
import 'package:moarch/src/templates/riverpod/app_templates.dart' as riverpod;
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/templates/ui/text_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

/// Every `AppConstants.<token>` a source refers to.
Set<String> _referenced(String source) =>
    RegExp(r'AppConstants\.(\w+)').allMatches(source).map((m) => m[1]!).toSet();

/// Every token `AppConstants` declares.
Set<String> _declared(String source) => RegExp(
  r'static (?:const|final)[^=]*?(\w+)\s*=',
).allMatches(source).map((m) => m[1]!).toSet();

/// The `0xAARRGGBB` value [AppConstants] gives [token].
int _color(String constants, String token) {
  final match = RegExp(
    'Color $token\\s*=\\s*Color\\(0x([0-9A-Fa-f]{8})\\)',
  ).firstMatch(constants);
  expect(match, isNotNull, reason: '$token is not a Color literal');
  return int.parse(match![1]!, radix: 16);
}

double _channel(int c) {
  final s = c / 255;
  return s <= 0.03928
      ? s / 12.92
      : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(int argb) =>
    0.2126 * _channel((argb >> 16) & 0xFF) +
    0.7152 * _channel((argb >> 8) & 0xFF) +
    0.0722 * _channel(argb & 0xFF);

/// [fg] at [alpha] over [bg], opaque.
int _blend(int fg, int bg, double alpha) {
  int mix(int shift) =>
      (((fg >> shift) & 0xFF) * alpha + ((bg >> shift) & 0xFF) * (1 - alpha))
          .round();
  return 0xFF000000 | (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

/// WCAG contrast ratio of two opaque colors.
double _contrast(int a, int b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const _white = 0xFFFFFFFF;

/// The light constants as they were before the color roles: what a project
/// scaffolded before 9.9.0 still has on disk.
String _constantsWithoutRoles({bool withDark = false}) =>
    CoreTemplates.appConstants(withDark: withDark)
        .split('\n')
        .where(
          (line) => !RegExp(
            r'Color (onPrimary|onSecondary|onTertiary|onSurfaceMuted)(Dark)?\s',
          ).hasMatch(line),
        )
        .join('\n');

void main() {
  group('AppConstants color roles', () {
    test('declares what reads on each accent, and a quieter text tone', () {
      final light = CoreTemplates.appConstants();
      for (final role in [
        'onPrimary',
        'onSecondary',
        'onTertiary',
        'onSurfaceMuted',
      ]) {
        expect(light, contains('static const Color $role '));
      }
      // On-accent colors default to the old behavior until a team sets them.
      expect(light, contains('static const Color onPrimary   = surface;'));
    });

    test('the dark half declares the same roles', () {
      final dark = CoreTemplates.appConstants(withDark: true);
      for (final role in [
        'onPrimaryDark',
        'onSecondaryDark',
        'onTertiaryDark',
        'onSurfaceMutedDark',
      ]) {
        expect(dark, contains('static const Color $role '));
      }
    });

    test('documents the 60-30-10 split and the pairs to check', () {
      final light = CoreTemplates.appConstants();
      expect(light, contains('60-30-10'));
      expect(light, contains('onPrimary on primary'));
    });

    test('status colors pass AA as text on white and on their own tint', () {
      // AppTag and AppBanner paint the color as text over a 12% tint of it.
      final light = CoreTemplates.appConstants();
      for (final token in ['success', 'warning', 'info', 'error']) {
        final color = _color(light, token);
        expect(
          _contrast(color, _white),
          greaterThanOrEqualTo(4.5),
          reason: '$token on white',
        );
        expect(
          _contrast(color, _blend(color, _white, 0.12)),
          greaterThanOrEqualTo(4.5),
          reason: '$token on its tint',
        );
      }
    });

    test('dark text tones pass AA on every dark surface', () {
      final dark = CoreTemplates.appConstants(withDark: true);
      for (final text in ['onSurfaceDark', 'onSurfaceMutedDark']) {
        for (final surface in [
          'surfaceDark',
          'surfaceContainerLowestDark',
          'surfaceContainerLowDark',
          'surfaceContainerHighestDark',
        ]) {
          expect(
            _contrast(_color(dark, text), _color(dark, surface)),
            greaterThanOrEqualTo(4.5),
            reason: '$text on $surface',
          );
        }
      }
    });
  });

  group('AppTheme', () {
    for (final dark in [false, true]) {
      final s = dark ? 'Dark' : '';
      final theme = ConfigTemplates.appTheme(withDark: dark);
      // The getter under test, so a light assertion is not met by the dark one.
      final half = dark ? theme.substring(theme.indexOf('get dark')) : theme;

      group(dark ? 'dark' : 'light', () {
        test('maps the on-accent and muted roles into the ColorScheme', () {
          expect(half, contains('onPrimary: AppConstants.onPrimary$s,'));
          expect(half, contains('onSecondary: AppConstants.onSecondary$s,'));
          expect(half, contains('onTertiary: AppConstants.onTertiary$s,'));
          expect(
            half,
            contains('onSurfaceVariant: AppConstants.onSurfaceMuted$s,'),
          );
        });

        test('puts text on the accent in onPrimary, never in a literal', () {
          expect(half, isNot(contains('Colors.white')));
          expect(half, contains('foregroundColor: AppConstants.onPrimary$s,'));
          expect(
            half,
            contains(
              'checkColor: const WidgetStatePropertyAll('
              'AppConstants.onPrimary$s)',
            ),
          );
        });

        test('keeps the accent off resting inputs and on focus', () {
          expect(
            half,
            contains('prefixIconColor: AppConstants.onSurfaceMuted$s,'),
          );
          expect(half, contains('color: AppConstants.primary$s,\n'));
          expect(half, contains('width: 1.5'));
          expect(half, contains(': AppConstants.outline$s,\n'));
          expect(half, contains('side: WidgetStateBorderSide.resolveWith('));
        });

        test('greys out a disabled checkbox and switch', () {
          final checkbox = half.substring(
            half.indexOf('checkboxTheme:'),
            half.indexOf('textSelectionTheme:'),
          );
          final switches = half.substring(
            half.indexOf('switchTheme:'),
            half.indexOf('radioTheme:'),
          );
          for (final theme in [checkbox, switches]) {
            expect(theme, contains('WidgetState.disabled'));
            expect(
              theme,
              contains('AppConstants.onSurface$s.withValues(alpha: 0.38)'),
            );
          }
        });

        test('fills fields and segments from the highest layer', () {
          // Lowest is often the surface color itself, which leaves a filled
          // field at rest with no edge at all.
          expect(
            half,
            contains('fillColor: AppConstants.surfaceContainerHighest$s,'),
          );
          final segmented = half.substring(
            half.indexOf('segmentedButtonTheme:'),
          );
          expect(
            segmented,
            contains(': AppConstants.surfaceContainerHighest$s,'),
          );
          expect(
            half,
            isNot(contains('fillColor: AppConstants.surfaceContainerLowest')),
          );
        });

        test('writes a picked chip in onSurface, not onSecondary', () {
          final chip = half.substring(
            half.indexOf('chipTheme:'),
            half.indexOf('switchTheme:'),
          );
          // The theme's labelStyle replaces the chip's default outright, so
          // it has to start from a full text style.
          expect(
            chip,
            contains('labelStyle: _textTheme.labelLarge?.copyWith('),
          );
          expect(chip, contains(': AppConstants.onSurface$s,'));
        });

        test('hints and unselected tabs use the muted tone, not an alpha', () {
          expect(half, isNot(contains('alpha: 0.35')));
          expect(
            half,
            contains('unselectedLabelColor: AppConstants.onSurfaceMuted$s,'),
          );
        });

        test('draws control edges at 3:1 and keeps dividers visible', () {
          expect(
            half,
            contains('outline: AppConstants.outline$s.withValues(alpha: 0.5)'),
          );
          expect(
            half,
            isNot(contains('DividerThemeData(color: Colors.transparent)')),
          );
          expect(half, contains('dividerTheme: DividerThemeData('));
        });

        test('styles stock buttons like AppButton', () {
          for (final slot in [
            'filledButtonTheme',
            'elevatedButtonTheme',
            'outlinedButtonTheme',
            'textButtonTheme',
          ]) {
            expect(half, contains('$slot:'));
          }
        });

        test('a bare Icon gets Material\'s 24, not 16', () {
          expect(
            half,
            contains(
              'color: AppConstants.outline$s,\n'
              '      size: AppConstants.iconMedium,',
            ),
          );
        });

        test('the app bar sits on the scaffold surface', () {
          expect(
            half,
            contains(
              'appBarTheme: const AppBarTheme(\n'
              '      backgroundColor: AppConstants.surface$s,',
            ),
          );
        });
      });
    }
  });

  group('a project whose AppConstants predates the roles', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('moarch_roles'));
    tearDown(() => temp.deleteSync(recursive: true));

    void writeConstants(String content) =>
        File('${temp.path}/lib/core/constants/app_constants.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync(content);

    void writeTheme({required bool dark}) =>
        File('${temp.path}/lib/config/theme/app_theme.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync(ConfigTemplates.appTheme(withDark: dark));

    test('is detected off app_constants.dart', () {
      expect(ScaffoldContext.detect(temp.path).hasColorRoles, isTrue);

      writeConstants(_constantsWithoutRoles());
      expect(ScaffoldContext.detect(temp.path).hasColorRoles, isFalse);

      writeConstants(CoreTemplates.appConstants());
      expect(ScaffoldContext.detect(temp.path).hasColorRoles, isTrue);
    });

    for (final dark in [false, true]) {
      test('gets a refreshed theme that compiles against it (dark: $dark)', () {
        final constants = _constantsWithoutRoles(withDark: dark);
        writeConstants(constants);
        writeTheme(dark: dark);

        final theme = ScaffoldCatalog.byName(
          'theme',
        )!.template(ScaffoldContext.detect(temp.path));

        expect(
          _referenced(theme).difference(_declared(constants)),
          isEmpty,
          reason: 'the refreshed theme reads a role the project lacks',
        );
        expect(theme, contains('onPrimary: AppConstants.surface'));
      });
    }

    test('the fallbacks never clip a longer role name', () {
      final out = CoreTemplates.inlineMissingColorRoles(
        'AppConstants.onPrimaryDark AppConstants.onPrimary',
      );
      expect(out, 'AppConstants.surfaceDark AppConstants.surface');
    });
  });

  group('the kit keeps one accent', () {
    test('secondary and tertiary actions are neutral', () {
      for (final source in [
        SharedTemplates.appButton(),
        SharedTemplates.appIconButton(),
        SharedTemplates.appInputStyle(),
        TextTemplates.appTextButton(),
      ]) {
        expect(source, isNot(contains('colorScheme.secondary')));
        expect(source, isNot(contains('colorScheme.tertiary')));
      }
    });

    test('AppButton turns a filled secondary tonal and a tertiary outlined', () {
      final button = SharedTemplates.appButton();
      expect(button, contains('AppButtonType.filled when !_isAccented => ('));
      expect(button, contains('theme.colorScheme.surfaceContainerHighest,'));
      expect(
        button,
        contains(
          'variant == AppButtonVariant.tertiary && type == AppButtonType.filled',
        ),
      );
    });

    test('AppButton labels come off the type scale', () {
      final button = SharedTemplates.appButton();
      expect(button, contains('textStyle: textTheme.titleMedium,'));
      expect(button, isNot(contains('fontSize:')));
    });

    test('the empty state illustration is neutral', () {
      final empty = SharedTemplates.emptyView();
      expect(empty, isNot(contains('colorScheme.primary')));
      expect(empty, contains('color: theme.colorScheme.onSurfaceVariant,'));
    });

    test('every kit file that reads a token imports AppConstants', () {
      // The template tests read text, so a token added without its import
      // only fails once a project is compiled.
      const variants = WidgetVariants(hasMotionTokens: true);
      for (final spec in WidgetCatalog.all) {
        final source = WidgetCatalog.sourceFor(spec, variants);
        if (!source.contains('AppConstants.')) continue;
        expect(
          source,
          contains('core/constants/app_constants.dart'),
          reason: '${spec.file} reads AppConstants without importing it',
        );
      }
    });

    test('black or white is picked by contrast, not a brightness guess', () {
      // estimateBrightnessForColor puts white on oranges and teals that black
      // reads far better on; 0.179 is where the two contrasts cross.
      final avatar = SharedTemplates.appAvatar();
      expect(avatar, contains('background.computeLuminance() > 0.179'));
      for (final source in [
        SharedTemplates.appAvatar(),
        SharedTemplates.appIconButton(),
        SharedTemplates.appStepIndicator(),
        TextTemplates.appTextButton(),
        ContentTemplates.appTimeline(),
      ]) {
        expect(source, isNot(contains('estimateBrightnessForColor')));
      }
    });
  });

  group('touch targets', () {
    test('AppCheckbox keeps 48dp unless a row is the target', () {
      expect(
        SharedTemplates.appCheckbox(),
        contains(': MaterialTapTargetSize.padded,'),
      );
      expect(SharedTemplates.appCheckboxLabel(), contains('dense: true,'));
    });
  });

  group('text scaling', () {
    test('follows the system up to 2x on both stacks', () {
      for (final main in [
        riverpod.AppTemplates.mainDart(),
        bloc.AppTemplates.mainDart(),
      ]) {
        expect(main, isNot(contains('maxScaleFactor: 1.3')));
        expect(main, contains('clamp(maxScaleFactor: 2)'));
      }
    });
  });
}
