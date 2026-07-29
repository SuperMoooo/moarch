import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('appInputFormat', () {
    final output = SharedTemplates.appInputFormat();

    test('covers every format the input family relies on', () {
      for (final format in [
        'text',
        'multiline',
        'personName',
        'email',
        'password',
        'username',
        'url',
        'phone',
        'integer',
        'decimal',
        'money',
        'creditCard',
        'cardExpiry',
        'cvv',
      ]) {
        expect(output, contains('  $format'), reason: '$format is missing');
      }
    });

    test('ships the formatters the formats resolve to', () {
      expect(output, contains('class DecimalInputFormatter'));
      expect(output, contains('class MoneyInputFormatter'));
      expect(output, contains('class MaskedInputFormatter'));
      expect(output, contains('class LowerCaseInputFormatter'));
      expect(output, contains("MaskedInputFormatter('#### #### #### ####')"));
      expect(output, contains("MaskedInputFormatter('##/##')"));
    });

    test('resolves a keyboard, hints, a rule and an unformatter', () {
      expect(output, contains('TextInputType get keyboardType'));
      expect(output, contains('List<TextInputFormatter> get formatters'));
      expect(output, contains('InputType get validationType'));
      expect(output, contains('List<String>? get autofillHints'));
      expect(output, contains('String unformat(String value)'));
      expect(output, contains('static AppInputFormat? forKeyboardType('));
    });

    test('imports only what it needs', () {
      expect(output, contains("import 'package:flutter/services.dart';"));
      expect(
        output,
        contains("import '../../../core/security/validation_service.dart';"),
      );
    });
  });

  group('appInput', () {
    final output = SharedTemplates.appInput();

    test('drives itself from the format', () {
      expect(output, contains("import './app_input_format.dart';"));
      expect(output, contains('this.format = AppInputFormat.text'));
      expect(output, contains('widget.inputFormatters ?? format.formatters'));
      expect(output, contains('widget.keyboardType ?? format.keyboardType'));
      expect(output, contains('widget.autofillHints ?? format.autofillHints'));
      expect(output, contains('widget.maxLength ?? format.maxLength'));
    });

    test('falls back to the format a bare keyboardType implies', () {
      expect(output, contains('AppInputFormat.forKeyboardType('));
    });

    test('exposes the built-in rule so a custom validator can build on it', () {
      expect(output, contains('static String? validate('));
      expect(output, contains('widget.validator ??'));
      expect(output, contains('inputType: format.validationType'));
      expect(output, contains('format.unformat(text)'));
    });

    test('leaves the counter to the config unless the field says', () {
      expect(output, contains('showCounter: widget.showCounter'));
      expect(
        SharedTemplates.appInputStyle(),
        contains(
            "counterText: (showCounter ?? config.showCounter) ? null : ''"),
      );
    });

    test('takes its look from the config, not from hardcoded defaults', () {
      for (final field in [
        'final AppInputLabelMode? labelMode;',
        'final AppInputVariant? variant;',
        'final AppInputType? type;',
        'final AppInputShape? shape;',
        'final AppInputSize? size;',
      ]) {
        expect(output, contains(field), reason: '$field is missing');
      }
      expect(output, isNot(contains('this.variant = AppInputVariant')));
      expect(output, contains('AppInputStyle.config.labelMode'));
      expect(
        output,
        contains(
          'widget.autovalidateMode ?? AppInputStyle.config.autovalidateMode',
        ),
      );
    });

    test('leaves a read-only field tappable only when it has an onTap', () {
      expect(output, contains('widget.readOnly && widget.onTap == null'));
    });
  });

  group('appInputConfig', () {
    final output = SharedTemplates.appInputConfig();

    test('owns the vocabulary the whole family speaks', () {
      for (final declaration in [
        'enum AppInputVariant',
        'enum AppInputType',
        'enum AppInputShape',
        'enum AppInputSize',
        'enum AppInputLabelMode { above, floating, placeholder, none }',
        'typedef InputSizeConfig',
      ]) {
        expect(output, contains(declaration),
            reason: '$declaration is missing');
      }
    });

    test('is reachable as one assignment', () {
      expect(output, contains('static AppInputConfig defaults'));
      expect(output, contains('AppInputConfig copyWith('));
      expect(output, contains('InputSizeConfig metricsOf(AppInputSize size)'));
    });

    test('carries the knobs the widgets stopped hardcoding', () {
      for (final field in [
        'final AppInputLabelMode labelMode;',
        'final bool showRequiredMarker;',
        'final String requiredMarker;',
        'final double labelGap;',
        'final FloatingLabelBehavior floatingLabelBehavior;',
        'final bool showCounter;',
        'final AutovalidateMode? autovalidateMode;',
        'final double idleBorderWidth;',
        'final double focusedBorderWidth;',
        'final double idleBorderOpacity;',
        'final double fillOpacity;',
        'final double disabledOpacity;',
        'final double hintOpacity;',
        'final InputSizeConfig smallMetrics;',
        'final InputSizeConfig mediumMetrics;',
        'final InputSizeConfig largeMetrics;',
      ]) {
        expect(output, contains(field), reason: '$field is missing');
      }
    });

    test('holds no colors — those stay with the theme', () {
      // Colors have to differ between light and dark, which a const config
      // cannot do; the config only says how strongly they are applied.
      expect(output, isNot(contains(RegExp(r'final Color'))));
      expect(output, isNot(contains(RegExp(r'\bColorScheme\b(?!`)'))));
      expect(output, contains('they come from `ColorScheme`'));
    });
  });

  group('input family wiring', () {
    test('every labeled field lays out through InputFieldLayout', () {
      expect(SharedTemplates.inputTitle(), contains('class InputFieldLayout'));

      for (final template in [
        SharedTemplates.appInput,
        SharedTemplates.dateInput,
        SharedTemplates.timeInput,
        SharedTemplates.appDropdown,
        SharedTemplates.appOtpInput,
      ]) {
        expect(template(), contains('InputFieldLayout('));
      }
    });

    test('no input hardcodes a variant, type, shape or size default', () {
      for (final template in [
        SharedTemplates.appInput,
        SharedTemplates.dateInput,
        SharedTemplates.timeInput,
        SharedTemplates.appDropdown,
        SharedTemplates.appOtpInput,
        SharedTemplates.appCheckbox,
        SharedTemplates.appCheckboxLabel,
        SharedTemplates.appSwitch,
        SharedTemplates.appSegmented,
        SharedTemplates.appChoiceChip,
        SharedTemplates.appRadioGroup,
        SharedTemplates.appSlider,
        SharedTemplates.appStepper,
        SharedTemplates.appSearchField,
        SharedTemplates.appProgressBar,
      ]) {
        final output = template();
        for (final hardcoded in [
          'this.variant = AppInputVariant',
          'this.type = AppInputType',
          'this.shape = AppInputShape',
          'this.size = AppInputSize',
        ]) {
          expect(output, isNot(contains(hardcoded)), reason: hardcoded);
        }
      }
    });
  });

  group('adaptive date & time pickers', () {
    final pickers = {
      'dateInput': SharedTemplates.dateInput(),
      'timeInput': SharedTemplates.timeInput(),
    };

    pickers.forEach((name, output) {
      test('$name picks its picker off the platform', () {
        expect(output, contains("import 'dart:io';"));
        expect(output, contains("import 'package:flutter/cupertino.dart';"));
        expect(output, contains('Platform.isAndroid'));
        expect(output, contains('? _showMaterialPicker(context)'));
        expect(output, contains(': _showCupertinoPicker(context)'));
        // The context is spent before the await, not carried over it.
        expect(output, isNot(contains('? await _show')));
      });

      test('$name opens the shared sheet on the Cupertino side', () {
        expect(output, contains("import './cupertino_picker_sheet.dart';"));
        expect(output, contains('showModalBottomSheet<'));
        expect(output, contains('CupertinoPickerSheet('));
        expect(output, contains('CupertinoDatePicker('));
      });

      test('$name only commits what the wheel was showing on Done', () {
        expect(output, contains('onDone: () => Navigator.pop(sheetContext, '));
        expect(output, contains('onCancel: () => Navigator.pop(sheetContext)'));
      });

      test('$name does not touch state after an unmounted await', () {
        expect(output, contains('if (picked == null || !mounted) return;'));
      });
    });

    test('the date picker holds both platforms to one range', () {
      final output = SharedTemplates.dateInput();
      expect(output, contains('static final DateTime _firstDate'));
      expect(output, contains('static final DateTime _lastDate'));
      expect(output, contains('firstDate: _firstDate'));
      expect(output, contains('minimumDate: _firstDate'));
      expect(output, contains('lastDate: _lastDate'));
      expect(output, contains('maximumDate: _lastDate'));
    });

    test('both wheels stay on 24-hour time, like the Material dialogs', () {
      expect(SharedTemplates.timeInput(), contains('use24hFormat: true'));
      expect(
        SharedTemplates.cupertinoPickerSheet(),
        contains('alwaysUse24HourFormat: true'),
      );
    });

    test('the sheet wears the app theme, not the Cupertino one', () {
      final output = SharedTemplates.cupertinoPickerSheet();
      expect(output, contains('color: theme.colorScheme.surface'));
      expect(output, contains('brightness: theme.brightness'));
      expect(output, contains('primaryColor: accent'));
      // A fixed-height wheel cannot grow with the text scale.
      expect(output, contains('textScaler: TextScaler.noScaling'));
      expect(output, contains('localizations.cancelButtonLabel'));
      expect(output, contains('localizations.okButtonLabel'));
    });
  });

  group('catalog wiring', () {
    test('resolving either picker field pulls the sheet in', () {
      for (final field in ['date-input', 'time-input']) {
        expect(
          WidgetCatalog.resolve([field]).map((spec) => spec.name),
          contains('picker-sheet'),
          reason: '$field needs the sheet it opens',
        );
      }
      expect(
        WidgetCatalog.all
            .firstWhere((spec) => spec.name == 'picker-sheet')
            .file,
        'inputs/cupertino_picker_sheet.dart',
      );
    });

    test('input-config ships with init and everything hangs off it', () {
      final config = WidgetCatalog.all.firstWhere(
        (spec) => spec.name == 'input-config',
      );
      expect(config.file, 'inputs/app_input_config.dart');
      expect(config.common, isTrue);

      // Every input reaches the config through AppInputStyle, which re-exports
      // it — so depending on input-style has to be enough.
      expect(
        WidgetCatalog.all.firstWhere((spec) => spec.name == 'input-style').deps,
        contains('input-config'),
      );
      expect(
        SharedTemplates.appInputStyle(),
        contains("export './app_input_config.dart';"),
      );
    });

    test('input-format ships with init, like the input that imports it', () {
      final format = WidgetCatalog.all.firstWhere(
        (spec) => spec.name == 'input-format',
      );
      expect(format.file, 'inputs/app_input_format.dart');
      expect(format.common, isTrue);
      expect(format.category, 'Inputs');
    });

    test('resolving the input pulls the format in', () {
      final resolved = WidgetCatalog.resolve([
        'input',
      ]).map((spec) => spec.name);
      expect(
        resolved,
        containsAll(['input', 'input-style', 'input-title', 'input-format']),
      );
    });
  });
}
