import 'package:moarch/src/templates/ui/country_templates.dart';
import 'package:moarch/src/templates/ui/phone_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  final output = CountryTemplates.appCountryPicker();

  group('appCountryPicker', () {
    test('reads the country table rather than carrying its own', () {
      expect(output, contains("import './app_country.dart';"));
      expect(output, contains('items: countries ?? AppCountries.all,'));
      expect(output, isNot(contains('const AppCountry(')));
    });

    test('is the one place the country sheet is configured', () {
      expect(output, contains('static Future<AppCountry?> show('));
      expect(output, contains('SearchPickerSheet.show<AppCountry>('));
      expect(output, contains('trailingLabelOf: showDialCode ?'));
      expect(
        output,
        contains(
            'filter: (countries, query) => AppCountries.search(query, within: countries),'),
      );
    });

    test('and the phone field opens that one, not a copy of it', () {
      final phone = PhoneTemplates.appPhoneInput();
      expect(phone, contains('AppCountryPicker.show('));
      expect(phone, isNot(contains('SearchPickerSheet')));
    });

    test('hands back the whole country, not just its code', () {
      expect(output, contains('final ValueChanged<AppCountry>? onChanged;'));
      expect(output, contains('onChanged?.call(picked);'));
    });

    test('validates on the caller\'s selection, not on its own lagging copy',
        () {
      expect(output, contains('validator: (_) {'));
      expect(output, contains('? rule(selectedIso)'));
      expect(output, contains(': validate(selectedIso, required: required);'));
    });

    test('its rule is exposed so a custom one can add to it', () {
      expect(
        output,
        contains(
            'static String? validate(String? iso, {bool required = false})'),
      );
    });

    test('an unknown ISO reads as nothing selected rather than crashing', () {
      expect(output,
          contains('return iso == null ? null : AppCountries.byIso(iso);'));
      expect(output, contains('isEmpty: country == null,'));
    });

    test('the closed field can read four ways', () {
      for (final display in [
        'AppCountryDisplay.flagAndName =>',
        'AppCountryDisplay.name =>',
        'AppCountryDisplay.flagAndDialCode =>',
        'AppCountryDisplay.flag =>',
      ]) {
        expect(output, contains(display));
      }
    });

    test('the clear button appears only when a clear can be reported', () {
      expect(output,
          contains('if (clear == null || country == null || !enabled)'));
      expect(output, contains('return const Icon(Icons.keyboard_arrow_down);'));
    });

    test('announces itself as a button to a screen reader', () {
      expect(output, contains('MergeSemantics('));
      expect(output, contains('button: true,'));
    });

    test('wears the family decoration rather than one of its own', () {
      expect(output, contains('AppInputStyle.decoration('));
      expect(output, contains('AppInputStyle.decorationErrorOrNull('));
      expect(output, contains('return InputFieldLayout('));
    });

    test('is in the catalog, and the phone field now leans on it', () {
      final picker =
          WidgetCatalog.all.firstWhere((s) => s.name == 'country-picker');
      expect(picker.file, 'inputs/app_country_picker.dart');
      expect(picker.category, 'Inputs');
      expect(picker.packages, isEmpty);
      expect(picker.deps, contains('country'));
      expect(picker.deps, contains('search-sheet'));

      final phone =
          WidgetCatalog.all.firstWhere((s) => s.name == 'phone-input');
      expect(phone.deps, contains('country-picker'));
    });

    test('generating the phone field still brings the sheet along', () {
      // It reaches the search sheet through the picker now rather than
      // directly, so the closure has to still contain it.
      final resolved =
          WidgetCatalog.resolve(['phone-input']).map((s) => s.name).toSet();
      expect(resolved, contains('search-sheet'));
      expect(resolved, contains('country-picker'));
      expect(resolved, contains('country'));
    });
  });
}
