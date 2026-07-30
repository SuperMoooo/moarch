import 'package:moarch/src/templates/ui/phone_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

/// One row of the generated country table.
final _row = RegExp(
  r"AppCountry\('([A-Z]{2})', '(\d+)', '((?:\\'|[^'])*)', \[([^\]]*)\]\),",
);

/// The mask strings inside one row's list.
final _mask = RegExp(r"'([^']*)'");

typedef _Country = ({String iso, String dial, String name, List<String> masks});

List<_Country> _parseTable(String output) => [
      for (final match in _row.allMatches(output))
        (
          iso: match.group(1)!,
          dial: match.group(2)!,
          name: match.group(3)!.replaceAll(r"\'", "'"),
          masks: [
            for (final mask in _mask.allMatches(match.group(4)!))
              mask.group(1)!,
          ],
        ),
    ];

void main() {
  group('appCountry', () {
    final output = PhoneTemplates.appCountry();
    final table = _parseTable(output);

    test('ships the whole world, once each', () {
      expect(table, hasLength(238));
      expect(
        table.map((country) => country.iso).toSet(),
        hasLength(table.length),
        reason: 'an ISO code appears twice',
      );
    });

    test('every row is a usable numbering plan', () {
      for (final country in table) {
        expect(country.masks, isNotEmpty, reason: '${country.iso} has no mask');
        expect(country.name, isNotEmpty, reason: '${country.iso} has no name');
        for (final mask in country.masks) {
          expect(
            mask,
            matches(RegExp(r'^[#() \-]+$')),
            reason: '${country.iso} mask "$mask" holds something odd',
          );
          expect(
            mask,
            contains('#'),
            reason: '${country.iso} mask "$mask" has no digit slot',
          );
        }
      }
    });

    test('the calling code is lifted out of the mask, not left in it', () {
      // The dial code lives in the selector. A mask that still carried it
      // would make the user type it, or show it twice.
      for (final country in table) {
        for (final mask in country.masks) {
          expect(mask, isNot(contains('+')), reason: country.iso);
          expect(mask, isNot(matches(RegExp(r'\d'))), reason: country.iso);
        }
      }
    });

    test('masks are listed narrowest first, so a plan can widen', () {
      for (final country in table) {
        final widths = [
          for (final mask in country.masks) '#'.allMatches(mask).length,
        ];
        expect(
          widths,
          orderedEquals(List<int>.from(widths)..sort()),
          reason: '${country.iso} lists its masks out of order',
        );
      }
    });

    test('keeps the variable-length plans a single mask would get wrong', () {
      final byIso = {for (final country in table) country.iso: country};

      // Each of these is a country whose numbers genuinely come in more than
      // one length — the case a one-mask-per-country table cannot express.
      expect(byIso['HU']!.masks, ['# ### ####', '## ### ####']);
      expect(byIso['AU']!.masks, ['#### ####', '# #### ####']);
      expect(byIso['DE']!.masks, hasLength(4));
      expect(byIso['PT']!.masks, hasLength(3));

      final variable = table.where((c) => c.masks.length > 1);
      expect(variable, hasLength(24));
    });

    test('territories sharing a code keep the prefix that tells them apart', () {
      final byIso = {for (final country in table) country.iso: country};
      expect(byIso['US']!.dial, '1');
      expect(byIso['VG']!.dial, '1284', reason: 'British Virgin Islands');
      expect(byIso['AS']!.dial, '1684', reason: 'American Samoa');
      // +7 is Russia and Kazakhstan both; the table carries the real code and
      // the tie is broken by preferredForSharedDialCode.
      expect(byIso['KZ']!.dial, '7');
      expect(byIso['RU']!.dial, '7');
    });

    test('names a preference for every calling code more than one country uses',
        () {
      final shared = <String, List<String>>{};
      for (final country in table) {
        shared.putIfAbsent(country.dial, () => []).add(country.iso);
      }
      final ambiguous = shared.entries.where((e) => e.value.length > 1);

      for (final entry in ambiguous) {
        expect(
          output,
          contains("'${entry.key}': '"),
          reason: '+${entry.key} is shared by ${entry.value} with no preference',
        );
      }
    });

    test('derives flags from the ISO code instead of storing them', () {
      expect(output, contains('_regionalIndicator'));
      expect(output, contains('String get flag'));
      // An emoji in the table would be a second thing to keep in sync.
      expect(output, isNot(matches(RegExp(r'[\u{1F1E6}-\u{1F1FF}]', unicode: true))));
    });

    test('validates a length against the plan, not against a range', () {
      // Armenia takes 8 or 10 digits and nothing in between, which a
      // min..max check would wave through.
      expect(output, contains('bool accepts(String digits) =>'));
      expect(output, contains('lengths.contains('));
    });

    test('ranks a search so a code beats a name that contains it', () {
      expect(output, contains('int matchRank(String query)'));
      expect(output, contains('if (lowerIso == needle) return 0;'));
      expect(output, contains('if (lowerName.contains(needle)) return 5;'));
      expect(
        output,
        contains('static List<AppCountry> search(String query, '
            '{List<AppCountry>? within})'),
      );
    });

    test('reads a number back apart as well as together', () {
      expect(output, contains('String e164(String digits)'));
      expect(output, contains('static AppPhoneNumber split('));
      expect(output, contains('static AppCountry? byDialCode('));
      // Longest-prefix, so +1284 is the BVI rather than the US.
      expect(output, contains('for (var length = longest; length > 0; length--)'));
    });

    test('lets an app move the default off the United States', () {
      expect(output, contains('static AppCountry initial = byIso('));
    });

    test('needs nothing from Flutter but its immutability annotation', () {
      expect(output, contains("import 'package:flutter/foundation.dart';"));
      expect(output, isNot(contains("import 'package:flutter/material.dart';")));
    });
  });

  group('appPhoneInput', () {
    final output = PhoneTemplates.appPhoneInput();

    test('masks through the country rather than a fixed format', () {
      expect(output, contains('class PhoneNumberInputFormatter'));
      expect(output, contains('inputFormatters: [PhoneNumberInputFormatter(_country)]'));
      expect(output, contains('country.format(newValue.text)'));
    });

    test('re-masks what is already typed when the country changes', () {
      // Flutter only runs inputFormatters on an edit, so without this a US
      // number keeps US punctuation after a switch to Germany.
      expect(output, contains('void _selectCountry(AppCountry country)'));
      expect(output, contains('final reshaped = country.format(digits);'));
      expect(output, contains('if (reshaped != _controller.text)'));
      expect(output, contains('TextSelection.collapsed(offset: reshaped.length)'));
    });

    test('puts the country picker in the prefix, not in the value', () {
      expect(output, contains('prefixIcon: _countrySelector'));
      expect(output, contains('SearchPickerSheet.show<AppCountry>'));
      expect(output, contains('_country.dialCode'));
    });

    test('ranks the picker search instead of taking the first name hit', () {
      expect(output, contains('AppCountries.search(query, within: countries)'));
    });

    test('opens on the country an E.164 seed implies', () {
      expect(output, contains('AppCountries.split('));
      expect(output, contains('widget.initialCountry'));
    });

    test('validates against the country before calling a number complete', () {
      expect(output, contains('static String? validate('));
      expect(output, contains('required AppCountry country'));
      expect(output, contains('country.accepts(digits)'));
      // Still screened the way every other field is.
      expect(output, contains('ValidationService.validate('));
      expect(output, contains('inputType: InputType.phone'));
    });

    test('only disposes a controller it created', () {
      expect(output, contains('_ownsController = widget.controller == null'));
      expect(output, contains('if (_ownsController) _controller.dispose();'));
    });

    test('does not touch state after an unmounted await', () {
      expect(output, contains('if (picked == null || !mounted) return;'));
    });

    test('reports a whole number, so a form never re-parses the text', () {
      expect(output, contains('ValueChanged<AppPhoneNumber>? onChanged'));
      expect(output, contains('AppPhoneNumber get _value'));
    });

    test('builds on AppInput instead of a bare TextFormField', () {
      expect(output, contains("import './app_input.dart';"));
      expect(output, contains('return AppInput('));
      expect(output, contains('format: AppInputFormat.phone'));
      expect(output, isNot(contains('TextFormField(')));
    });

    test('a read-only field cannot change country either', () {
      expect(output, contains('final enabled = widget.enabled && !widget.readOnly;'));
    });
  });

  group('searchPickerSheet', () {
    final output = SharedTemplates.searchPickerSheet();

    test('is generic over the row, and hands the row back', () {
      expect(output, contains('class SearchPickerSheet<T> extends StatefulWidget'));
      expect(output, contains('static Future<T?> show<T>('));
      expect(output, contains('Navigator.pop(context, item)'));
    });

    test('reuses the kit search field rather than rolling one', () {
      expect(output, contains("import './app_search_field.dart';"));
      expect(output, contains('AppSearchField('));
      expect(output, contains('autofocus: true'));
    });

    test('opens the list already showing the current selection', () {
      // A 238-row picker that starts at the top is a scroll hunt.
      expect(output, contains('initialScrollOffset: _initialOffset'));
      expect(output, contains('itemExtent: _rowHeight'));
      expect(output, contains('index * _rowHeight'));
    });

    test('drops a stale offset when the list is filtered underneath it', () {
      expect(output, contains('if (_scrollController.hasClients) _scrollController.jumpTo(0);'));
    });

    test('lets a caller rank matches, not just select them', () {
      // A boolean match keeps the list in table order, which puts Egypt above
      // Portugal for the query 'PT'.
      expect(
        output,
        contains('final List<T> Function(List<T> items, String query)? filter;'),
      );
      expect(output, contains('if (filter != null) return filter('));
    });

    test('sits above the keyboard it raises', () {
      expect(output, contains('isScrollControlled: true'));
      expect(output, contains('mediaQuery.viewInsets.bottom'));
      expect(output, contains('_maxHeightFactor'));
    });

    test('says so when nothing matches', () {
      expect(output, contains('widget.emptyLabel'));
    });

    test('disposes its scroll controller', () {
      expect(output, contains('_scrollController.dispose();'));
    });
  });

  group('appDropdown searchable', () {
    final output = SharedTemplates.appDropdown();

    test('keeps one widget and one callback for both forms', () {
      expect(output, contains('final bool? searchable;'));
      expect(
        output,
        contains('? _searchableField(context, selected, accent, alignment)'),
      );
      expect(
        output,
        contains(': _menuField(context, selected, accent, alignment)'),
      );
      // Same callback either way: both forms report through one _pick, which
      // is the only place the caller's onChanged is called at all.
      expect('_pick('.allMatches(output).length, greaterThanOrEqualTo(3));
      expect('onChanged(idOf(item));'.allMatches(output).length, 1);
    });

    test('a list long enough to need a search gets one unasked', () {
      expect(
        output,
        contains(
          'searchable ?? items.length >= AppInputStyle.config.searchableThreshold',
        ),
      );
      expect(
        SharedTemplates.appInputConfig(),
        contains('this.searchableThreshold = 30'),
      );
    });

    test('the searchable form only displays the selection', () {
      expect(output, contains('InputDecorator('));
      expect(output, contains('isEmpty: selected == null'));
      expect(output, contains('T? get _selected'));
      expect(output, contains('SearchPickerSheet.show<T>('));
    });

    test('the sheet gets every row option the caller set', () {
      for (final forwarded in [
        'leadingOf: leadingOf,',
        'trailingLabelOf: trailingLabelOf,',
        'filter: filter,',
        'emptyLabel:',
      ]) {
        expect(output, contains(forwarded), reason: '$forwarded is dropped');
      }
    });

    test('both forms build the same decoration', () {
      expect(output, contains('InputDecoration _decoration('));
      expect(output, contains('decoration: _decoration(context),'));
    });

    test('both forms validate — a sheet-backed field is still a form field', () {
      expect(output, contains('static String? validate('));
      // The searchable form: an InputDecorator alone is invisible to a Form.
      expect(output, contains('FormField<String>('));
      expect(output, contains('errorText: state.errorText'));
      // The menu form validates through the FormField it already is.
      expect(output, contains('validator: _validate,'));
    });

    test('an id with no row never reaches the menu', () {
      // A dropdown asserts one item carries its value, so an id waiting on its
      // list would throw.
      expect(
        output,
        contains('initialValue: selected == null ? null : selectedId,'),
      );
    });

    test('a disabled field opens nothing', () {
      expect(
        output,
        contains('onTap: enabled ? () => _openSheet(context, state) : null'),
      );
      expect(output, contains('onChanged: enabled ? _onMenuChanged : null'));
    });
  });

  group('catalog wiring', () {
    test('the phone field pulls in everything it imports', () {
      final resolved = WidgetCatalog.resolve(['phone-input'])
          .map((spec) => spec.name)
          .toSet();
      expect(
        resolved,
        containsAll([
          'phone-input',
          'country',
          'search-sheet',
          'input',
          'input-format',
          'input-style',
          // through search-sheet
          'search-field',
          'icon-button',
        ]),
      );
    });

    test('the dropdown pulls in the sheet it can open', () {
      expect(
        WidgetCatalog.resolve(['dropdown']).map((spec) => spec.name),
        contains('search-sheet'),
      );
    });

    test('the new widgets land where their imports expect them', () {
      final files = {
        'country': 'inputs/app_country.dart',
        'phone-input': 'inputs/app_phone_input.dart',
        'search-sheet': 'inputs/search_picker_sheet.dart',
      };
      files.forEach((name, file) {
        final spec = WidgetCatalog.all.firstWhere((spec) => spec.name == name);
        expect(spec.file, file);
        expect(spec.category, 'Inputs');
      });
    });

    test('the country table stands alone — it is data, not a widget', () {
      final spec = WidgetCatalog.all.firstWhere((spec) => spec.name == 'country');
      expect(spec.deps, isEmpty);
      expect(spec.packages, isEmpty);
    });

    test('none of them are forced on every project by init', () {
      for (final name in ['country', 'phone-input', 'search-sheet']) {
        final spec = WidgetCatalog.all.firstWhere((spec) => spec.name == name);
        expect(spec.common, isFalse, reason: '$name should be opt-in');
      }
    });
  });
}
