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

    test('keeps the counter opt-in', () {
      expect(
        output,
        contains("copyWith(counterText: widget.showCounter ? null : '')"),
      );
    });

    test('leaves a read-only field tappable only when it has an onTap', () {
      expect(output, contains('widget.readOnly && widget.onTap == null'));
    });
  });

  group('catalog wiring', () {
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
