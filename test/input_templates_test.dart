import 'package:moarch/src/templates/config/config_templates.dart';
import 'package:moarch/src/templates/ui/calendar_templates.dart';
import 'package:moarch/src/templates/ui/country_templates.dart';
import 'package:moarch/src/templates/ui/inputs_templates.dart';
import 'package:moarch/src/templates/ui/phone_templates.dart';
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
        'final String requiredMessage;',
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

  group('read-only across the family', () {
    // Every widget in the kit whose value the user can change. Read-only is not
    // disabled: the control keeps its colors — the value it is showing is real
    // and worth reading — and only stops answering.
    final valueBearing = <String, String Function()>{
      'appInput': SharedTemplates.appInput,
      'dateInput': SharedTemplates.dateInput,
      'timeInput': SharedTemplates.timeInput,
      'appDropdown': SharedTemplates.appDropdown,
      'appOtpInput': SharedTemplates.appOtpInput,
      'appCheckbox': SharedTemplates.appCheckbox,
      'appCheckboxLabel': SharedTemplates.appCheckboxLabel,
      'appSwitch': SharedTemplates.appSwitch,
      'appSegmented': SharedTemplates.appSegmented,
      'appChoiceChip': SharedTemplates.appChoiceChip,
      'appRadioGroup': SharedTemplates.appRadioGroup,
      'appSlider': SharedTemplates.appSlider,
      'appStepper': SharedTemplates.appStepper,
      'appMultiSelect': InputsTemplates.appMultiSelect,
      'appDateRangeInput': InputsTemplates.appDateRangeInput,
      'appFilePickerField': InputsTemplates.appFilePickerField,
      'appRating': InputsTemplates.appRating,
      'appPhoneInput': PhoneTemplates.appPhoneInput,
      'appCountryPicker': CountryTemplates.appCountryPicker,
      'appCalendar': CalendarTemplates.appCalendar,
    };

    // How each one goes inert. Most wrap themselves in the shared gate; the
    // rest have a reason not to, recorded here so that no widget can quietly
    // opt out of read-only altogether by having no reason at all.
    const notGated = {
      'appInput': 'hands it to TextFormField.readOnly',
      'dateInput': 'hands it to the TextFormField under the picker',
      'timeInput': 'hands it to the TextFormField under the picker',
      'appDateRangeInput': 'hands it to the TextFormField under the picker',
      'appPhoneInput': 'passes it down to the AppInput it is built on',
      'appFilePickerField': 'drops the add area rather than gating a live one',
      'appCalendar': 'only the day tap goes; paging months changes no value',
    };

    valueBearing.forEach((name, template) {
      test('$name takes readOnly', () {
        final output = template();
        expect(output, contains('this.readOnly = false,'), reason: name);
        expect(output, contains('final bool readOnly;'), reason: name);
      });

      test('$name acts on the flag rather than just declaring it', () {
        final output = template();
        final reason = notGated[name];
        if (reason == null) {
          expect(output, contains('ReadOnlyGate('), reason: name);
        } else {
          expect(output, isNot(contains('ReadOnlyGate(')), reason: reason);
        }
        // Declared, documented, and never read is the failure worth catching.
        expect(
          'readOnly'.allMatches(output).length,
          greaterThan(2),
          reason: name,
        );
      });
    });

    test('readOnly is the whole of what a caller writes', () {
      // Not `readOnly: true, onChanged: (_) {}`. A required callback would put
      // that no-op back on the caller, so none of these may have one.
      valueBearing.forEach((name, template) {
        final output = template();
        expect(
          output,
          isNot(contains('required this.onChanged')),
          reason: name,
        );
        expect(
          output,
          isNot(contains('required this.onSelected')),
          reason: name,
        );
        expect(output, isNot(contains('required this.onPick')), reason: name);
      });
    });

    test('a read-only control still paints live with no callback at all', () {
      // Material greys out anything handed a null callback, so each of these
      // works out for itself that it should hand over one that is never
      // reached — which is what `|| readOnly` is doing in every one of them.
      final painting = <String, String Function()>{
        'appCheckbox': SharedTemplates.appCheckbox,
        'appCheckboxLabel': SharedTemplates.appCheckboxLabel,
        'appSwitch': SharedTemplates.appSwitch,
        'appSegmented': SharedTemplates.appSegmented,
        'appChoiceChip': SharedTemplates.appChoiceChip,
        'appRadioGroup': SharedTemplates.appRadioGroup,
        'appSlider': SharedTemplates.appSlider,
        'appStepper': SharedTemplates.appStepper,
        'appRating': InputsTemplates.appRating,
      };
      painting.forEach((name, template) {
        expect(template(), contains('|| readOnly;'), reason: name);
      });
    });

    test('a pickable field with no callback trips an assert, not silence', () {
      // The looser signature is for read-only fields; forgetting the callback
      // on one the user can actually pick in has to be loud.
      final picking = <String, String Function()>{
        'appDropdown': SharedTemplates.appDropdown,
        'appMultiSelect': InputsTemplates.appMultiSelect,
        'appCountryPicker': CountryTemplates.appCountryPicker,
      };
      picking.forEach((name, template) {
        expect(
          template(),
          contains('onChanged != null || readOnly,'),
          reason: name,
        );
      });
      expect(
        InputsTemplates.appFilePickerField(),
        contains('(onPick != null && onChanged != null) || readOnly,'),
      );
    });

    test('the gate is declared once, with the inputs that reach for it', () {
      final style = SharedTemplates.appInputStyle();
      expect(style, contains('class ReadOnlyGate'));
      // Focus goes with the pointer, or a tab lands on something inert.
      expect(
        style,
        contains('ExcludeFocus(child: IgnorePointer(child: child))'),
      );
    });

    test('nothing is excused from the gate that no longer takes readOnly', () {
      // Otherwise a renamed widget leaves an excuse behind that silently
      // covers for whatever takes its name next.
      for (final name in notGated.keys) {
        expect(valueBearing.keys, contains(name));
      }
    });
  });

  group('theme-first painting', () {
    test('the config names no variant, so the theme is what paints', () {
      final config = SharedTemplates.appInputConfig();
      expect(config, contains('final AppInputVariant? variant;'));
      expect(config, isNot(contains('this.variant = AppInputVariant')));
    });

    test('accentOrNull is what hands a color slot back to the theme', () {
      final style = SharedTemplates.appInputStyle();
      expect(style, contains('static Color? accentOrNull('));
      expect(style, contains('static Color? onAccentOrNull('));
      expect(style, contains('if (resolved == null) return null;'));
      // The non-null pair stay, for the slots with no themed default to reach.
      expect(style, contains('static Color accentOf('));
      expect(style, contains('static Color onAccentOf('));
    });

    test('a filled field with no variant takes the theme fill untinted', () {
      // Which is the color AppCard paints too, so a field and a card standing
      // next to each other read as one surface.
      final style = SharedTemplates.appInputStyle();
      expect(style, contains('final baseFill = decorationTheme.fillColor ??'));
      expect(style, contains('? baseFill'));
      expect(style, contains('Color.alphaBlend('));
    });

    test('AppCard is painted by cardTheme', () {
      final card = SharedTemplates.appCard();
      expect(card, contains('final cardTheme = theme.cardTheme;'));
      expect(card, contains('cardTheme.color ??'));
      expect(card, contains('cardTheme.shadowColor ??'));
      expect(card, contains('final shape = cardTheme.shape;'));
      // The hardcoded surface it used to paint whatever the theme said.
      expect(
        card,
        isNot(contains('color: theme.colorScheme.surfaceContainerLowest,')),
      );
    });

    test('AppListTile reads listTileTheme, being no ListTile itself', () {
      final tile = SharedTemplates.appListTile();
      expect(tile, contains('final tileTheme = theme.listTileTheme;'));
      expect(tile, contains('tileTheme.contentPadding ??'));
      expect(tile, contains('tileTheme.iconColor ??'));
    });

    test('the Material-backed controls leave their colors null', () {
      // Each of these wraps a widget the theme already has an opinion about,
      // so passing a color unasked is what stopped the theme applying.
      final wrapping = <String, String Function()>{
        'appCheckbox': SharedTemplates.appCheckbox,
        'appSwitch': SharedTemplates.appSwitch,
        'appSlider': SharedTemplates.appSlider,
        'appChoiceChip': SharedTemplates.appChoiceChip,
        'appSegmented': SharedTemplates.appSegmented,
        'appRadioGroup': SharedTemplates.appRadioGroup,
      };
      wrapping.forEach((name, template) {
        expect(
          template(),
          contains('AppInputStyle.accentOrNull('),
          reason: name,
        );
      });
    });

    test('the theme sets the geometry the widgets used to hardcode', () {
      // Twice over: the light getter and the dark one. These have to match what
      // the widgets were drawing, or every card and chip changes shape the day
      // it starts reading the theme.
      final theme = ConfigTemplates.appTheme(withDark: true);
      expect(
        'borderRadius: AppConstants.borderRadius16'.allMatches(theme).length,
        2,
      );
      expect(
        'borderRadius: AppConstants.borderRadiusFull,'.allMatches(theme).length,
        2,
      );
      expect('shadowColor: Colors.black,'.allMatches(theme).length, 2);
    });
  });

  group('validation copy', () {
    // Every field that can reject an empty value, wherever its template lives.
    final validating = {
      'appInput': SharedTemplates.appInput(),
      'dateInput': SharedTemplates.dateInput(),
      'timeInput': SharedTemplates.timeInput(),
      'appDropdown': SharedTemplates.appDropdown(),
      'appMultiSelect': InputsTemplates.appMultiSelect(),
      'appDateRangeInput': InputsTemplates.appDateRangeInput(),
      'appFilePickerField': InputsTemplates.appFilePickerField(),
      'appCountryPicker': CountryTemplates.appCountryPicker(),
      'appPhoneInput': PhoneTemplates.appPhoneInput(),
    };

    test('the required message is declared once, in the config', () {
      expect(
        SharedTemplates.appInputConfig(),
        contains("this.requiredMessage = 'This field is required',"),
      );
    });

    validating.forEach((name, output) {
      test('$name reads the message rather than spelling it out', () {
        expect(output, isNot(contains('This field is required')));
        expect(output, contains('AppInputStyle.config.requiredMessage'));
      });
    });
  });

  group('error alignment', () {
    test('the shift off the content padding is worked out in one place', () {
      final style = SharedTemplates.appInputStyle();
      expect(style, contains('static Widget decorationError('));
      expect(style, contains('static Widget? decorationErrorOrNull('));
      expect(style, contains('static TextStyle? errorStyle(BuildContext'));
      // Underline fields pad nothing, so they are already flush.
      expect(style, contains('type == AppInputType.underline'));
      // RTL indents from the other edge — shifting left there would be worse
      // than leaving it alone.
      expect(style, contains('Directionality.of(context)'));
    });

    final decorated = {
      'appInput': SharedTemplates.appInput(),
      'dateInput': SharedTemplates.dateInput(),
      'timeInput': SharedTemplates.timeInput(),
      'appDropdown': SharedTemplates.appDropdown(),
      'appMultiSelect': InputsTemplates.appMultiSelect(),
      'appDateRangeInput': InputsTemplates.appDateRangeInput(),
      'appCountryPicker': CountryTemplates.appCountryPicker(),
    };

    decorated.forEach((name, output) {
      test('$name hands its message to the decoration, not errorText', () {
        expect(output, contains('AppInputStyle.decorationError'));
        // `errorText` is what puts the message back at the indent.
        expect(output, isNot(contains('copyWith(errorText:')));
      });
    });

    test('the controls that draw their own line start at the same x', () {
      for (final output in [
        SharedTemplates.inputTitle(),
        InputsTemplates.appFilePickerField(),
      ]) {
        expect(output, contains('AppInputStyle.errorStyle(context)'));
        expect(
          output,
          isNot(contains('left: AppConstants.space12')),
          reason: 'an error line indented to match the old decoration',
        );
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
