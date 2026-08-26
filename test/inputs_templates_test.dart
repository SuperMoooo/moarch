import 'package:moarch/src/templates/ui/inputs_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('appMultiSelect', () {
    final output = InputsTemplates.appMultiSelect();

    test('reports the whole selection, in items order', () {
      expect(output, contains('final ValueChanged<List<String>>? onChanged;'));
      expect(output, contains('List<T> get _selected => ['));
      expect(output, contains('if (selectedIds.contains(idOf(item))) item,'));
    });

    test('validates required, min and max — and exposes the rule', () {
      expect(output, contains('static String? validate('));
      expect(
        output,
        contains(
          'if (required && ids.isEmpty) '
          'return AppInputStyle.config.requiredMessage;',
        ),
      );
      expect(output, contains("return 'Pick at least \$min';"));
      expect(output, contains("return 'Pick no more than \$max';"));
    });

    test('an untouched optional field is not "fewer than min"', () {
      expect(output,
          contains('if (min != null && ids.isNotEmpty && ids.length < min)'));
    });

    test('judges the caller\'s selection, not the FormField\'s own copy', () {
      expect(output, contains('validator: (_) => _validate(selectedIds),'));
      expect(output, contains('state.didChange(ids);'));
    });

    test('a dismissed sheet changes nothing, an empty result does', () {
      expect(output, contains('if (picked == null) return;'));
    });

    test('shows its picks three ways', () {
      expect(output,
          contains('enum AppMultiSelectDisplay { chips, labels, count }'));
      expect(output, contains("'\${selected.length} selected'"));
      expect(output, contains('AppMultiSelectDisplay.chips => _chips('));
      expect(output,
          contains('final overflow = selected.length - maxVisibleChips;'));
    });

    test('a chip can drop its own pick', () {
      expect(output, contains('onDeleted: enabled && !readOnly'));
      expect(output, contains('? () => _remove(item, state)'));
    });

    test('a read-only field keeps its chips but not their X', () {
      // The whole field is gated, so the delete would be inert anyway — an X
      // that does nothing is worse than no X.
      expect(output, contains('builder: (state) => ReadOnlyGate('));
      expect(output, contains('onDeleted: enabled && !readOnly'));
    });

    test('trips on duplicate ids rather than selecting the wrong row', () {
      expect(
          output, contains('items.map(idOf).toSet().length == items.length,'));
    });
  });

  group('searchPickerSheet, multi-select mode', () {
    final output = SharedTemplates.searchPickerSheet();

    test('opens with checkboxes and a Done button', () {
      expect(output, contains('static Future<List<T>?> showMulti<T>('));
      expect(output, contains('multiSelect: true,'));
      expect(output,
          contains('if (widget.multiSelect) _confirmBar(theme, accent),'));
      expect(output, contains('final checkbox = Checkbox('));
    });

    test('works on its own copy, so backing out changes nothing', () {
      expect(
          output,
          contains(
              'late final Set<String> _picked = {...widget.selectedIds};'));
      expect(output, contains('Navigator.pop(context, _pickedItems);'));
    });

    test('hands back the picks in items order', () {
      expect(output, contains('List<T> get _pickedItems => ['));
      expect(
          output, contains('if (_picked.contains(widget.idOf(item))) item,'));
    });

    test('stops at the ceiling instead of letting the form refuse it later',
        () {
      expect(output, contains('bool get _atLimit =>'));
      expect(
        output,
        contains('!widget.multiSelect || selected || !_atLimit;'),
      );
      expect(output, contains('onTap: enabled'));
    });

    test('opens at the first tick in multi-select', () {
      expect(
        output,
        contains(
            '(widget.selectedIds.isEmpty ? null : widget.selectedIds.first)'),
      );
    });

    test('the single-select path still pops the item it was given', () {
      expect(output, contains('Navigator.pop(context, item);'));
      expect(output, contains('static Future<T?> show<T>('));
    });

    test('the row is the target, so the box does not double the haptics', () {
      expect(
          output, contains('onChanged: enabled ? (_) => _toggle(id) : null,'));
      // One place buzzes for a toggle, whichever half of the row was tapped.
      expect('HapticFeedback.'.allMatches(output).length, 3);
    });
  });

  group('appDateRangeInput', () {
    final output = InputsTemplates.appDateRangeInput();

    test('holds a range, not the text of one', () {
      expect(output, contains('field: FormField<DateTimeRange>('));
      expect(output, isNot(contains('TextEditingController')));
    });

    test('enforces maxDays inclusively, which a picker cannot express', () {
      expect(
          output,
          contains(
              'if (maxDays != null && range.duration.inDays + 1 > maxDays)'));
      expect(output,
          contains("return 'Pick a range of \$maxDays days or fewer';"));
    });

    test('follows a value the caller changes from outside', () {
      expect(output,
          contains('void didUpdateWidget(AppDateRangeInput oldWidget)'));
      expect(output,
          contains('if (widget.initialValue != oldWidget.initialValue)'));
    });

    test('is the Material picker on every platform, deliberately', () {
      expect(output, contains('await showDateRangePicker('));
      expect(output, isNot(contains('CupertinoDatePicker')));
      expect(output, isNot(contains("import 'dart:io';")));
    });

    test('writes the two dates with the app\'s own date format', () {
      expect(output, contains('range.start.formattedDate'));
      expect(output, contains('range.end.formattedDate'));
      expect(output, contains("this.separator = ' – '"));
    });

    test('clears the error as soon as a range lands', () {
      expect(output, contains('if (mounted) state.didChange(_range);'));
    });
  });

  group('appFilePickerField', () {
    final output = InputsTemplates.appFilePickerField();

    test('costs the project no picker dependency', () {
      // The doc comment names both packages to say it is not one of them.
      expect(output, isNot(contains("import 'package:file_picker")));
      expect(output, isNot(contains("import 'package:image_picker")));
      expect(output,
          contains('final Future<List<AppPickedFile>?> Function()? onPick;'));
    });

    test('a cancelled pick costs nothing', () {
      expect(output, contains('if (picked == null || picked.isEmpty) return;'));
    });

    test('trims at the ceiling rather than refusing the whole pick', () {
      expect(
          output,
          contains(
              'final limited = maxFiles == null ? next : next.take(maxFiles!).toList();'));
      expect(output, contains('if (enabled && !readOnly && !_atLimit)'));
    });

    test('reads a file well enough to draw it', () {
      expect(output, contains('String get extension {'));
      expect(output, contains('bool get isImage =>'));
      expect(output, contains('String? get readableSize {'));
      expect(output, contains('IconData get icon => switch (extension) {'));
      expect(output, contains("'pdf' => Icons.picture_as_pdf_outlined,"));
    });

    test('a file that moved since it was picked does not break the row', () {
      expect(output, contains('errorBuilder: (context, error, stackTrace) =>'));
    });

    test('a web pick has no path and simply shows no preview', () {
      expect(output, contains('if (file.isImage && path != null) {'));
    });
  });

  group('appRating', () {
    final output = InputsTemplates.appRating();

    test('is the same widget read-only and interactive', () {
      expect(
        output,
        contains('bool get _enabled => onChanged != null || readOnly;'),
      );
      expect(output, contains('if (!_enabled) return row;'));
      expect(output, contains('if (!_interactive) return star;'));
    });

    test('readOnly freezes the stars without leaving the form', () {
      // Narrower than dropping onChanged: the rating is still the form's, so a
      // required one still fails validation rather than passing quietly.
      expect(
        output,
        contains('bool get _interactive => _enabled && !readOnly;'),
      );
      expect(output, contains('builder: (_) => ReadOnlyGate('));
    });

    test('a display-only rating stays out of the form', () {
      // Wrapping it in a FormField would put it in Form.validate()'s way with
      // nothing to say.
      expect(output, contains('return SelectionFormField<double>('));
    });

    test('the left half of a star is the half score', () {
      expect(output, contains('double _scoreFor(int index, double dx) {'));
      expect(output,
          contains('return dx < _starSize / 2 ? index + 0.5 : index + 1;'));
      expect(
          output,
          contains(
              'onTapDown: (details) => _report(_scoreFor(index, details.localPosition.dx)),'));
    });

    test('tapping the score again takes it back, when allowed', () {
      expect(output,
          contains('onChanged?.call(allowClear && next == value ? 0 : next);'));
    });

    test('pairs the outline star with the filled one it was given', () {
      expect(
          output,
          contains(
              'static IconData _outlineOf(IconData icon) => switch (icon) {'));
      expect(output,
          contains('Icons.star_rounded => Icons.star_outline_rounded,'));
    });

    test('meets the tap target without growing the star', () {
      expect(output,
          contains('(AppConstants.touchTarget - _starSize).clamp(0, 24) / 2,'));
    });

    test('says its score to a screen reader', () {
      expect(
          output,
          contains(
              "value: '\${value.toStringAsFixed(allowHalf ? 1 : 0)} of \$count',"));
    });
  });

  group('the catalog', () {
    test('files the four new fields under Inputs, on the shared base', () {
      for (final name in [
        'multi-select',
        'date-range-input',
        'file-input',
        'rating',
      ]) {
        final spec = WidgetCatalog.byName(name);
        expect(spec, isNotNull, reason: '$name is missing from the catalog');
        expect(spec!.category, 'Inputs');
        expect(spec.deps, containsAll(['input-style', 'input-title']));
        expect(spec.file, startsWith('inputs/'));
        expect(spec.packages, isEmpty, reason: '$name should cost no package');
      }
    });

    test('multi-select opens the sheet it depends on', () {
      expect(
          WidgetCatalog.byName('multi-select')!.deps, contains('search-sheet'));
    });

    test('none of them are generated on init', () {
      // The common set stays lean; these are one command away.
      final common = WidgetCatalog.common.map((spec) => spec.name);
      for (final name in [
        'multi-select',
        'date-range-input',
        'file-input',
        'rating',
      ]) {
        expect(common, isNot(contains(name)));
      }
    });
  });
}
