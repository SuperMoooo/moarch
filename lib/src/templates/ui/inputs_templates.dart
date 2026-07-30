/// Templates for the second half of the input family: the fields that hold more
/// than one value, a range rather than a point, a file rather than text, or a
/// score rather than a choice.
class InputsTemplates {
  /// Returns the generated appMultiSelect template.
  static String appMultiSelect() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_input_style.dart';
import './input_title.dart';
import './search_picker_sheet.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// How a multi-select field shows what is in it.
///
/// - [chips]: a removable chip per selection, spilling into "+N" past
///   [AppMultiSelectInput.maxVisibleChips].
/// - [labels]: the labels on one line, comma-separated and ellipsized.
/// - [count]: "3 selected" — for a field whose picks are long or many.
enum AppMultiSelectDisplay { chips, labels, count }

/// [AppDropdownInput]'s plural: the same id/label entity list, any number of
/// them selected, picked in a [SearchPickerSheet] with a checkbox per row.
///
/// ```dart
/// AppMultiSelectInput<TagEntity>(
///   label: 'Tags',
///   items: tags,
///   idOf: (t) => t.id,
///   labelOf: (t) => t.name,
///   selectedIds: _tagIds,
///   required: true,
///   maxSelected: 3,
///   onChanged: (ids) => setState(() => _tagIds = ids),
/// )
/// ```
///
/// The caller owns the selection, as it does on every other field in the
/// family: [onChanged] hands back the whole new list rather than a diff, so the
/// field never holds a second copy of the truth.
class AppMultiSelectInput<T> extends StatelessWidget {
  const AppMultiSelectInput({
    super.key,
    required this.label,
    required this.items,
    required this.idOf,
    required this.labelOf,
    required this.onChanged,
    this.selectedIds = const [],
    this.onSelected,
    this.hint = 'Select options',
    this.enabled = true,
    this.required = false,
    this.minSelected,
    this.maxSelected,
    this.validator,
    this.autovalidateMode,
    this.display = AppMultiSelectDisplay.chips,
    this.maxVisibleChips = 3,
    this.searchHint = 'Search',
    this.searchTitle,
    this.leadingOf,
    this.trailingLabelOf,
    this.filter,
    this.emptyLabel,
    this.prefixIcon,
    this.suffixIcon,
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
  });

  final String label;
  final List<T> items;

  /// Extract the id from an item. Ids are what the selection is made of, so
  /// they must be unique across [items] — a duplicate trips an assert.
  final String Function(T item) idOf;

  /// Extract the display label from an item.
  final String Function(T item) labelOf;

  /// Called with the complete new selection, in the order the items appear in
  /// [items] — not in the order they were ticked, which no caller wants to
  /// store.
  final ValueChanged<List<String>> onChanged;

  /// The current selection.
  final List<String> selectedIds;

  /// Called with the items themselves, alongside [onChanged].
  final ValueChanged<List<T>>? onSelected;

  final String hint;
  final bool enabled;

  /// Marks the label, and — unless [validator] replaces the rule — rejects an
  /// empty selection when the form validates.
  final bool required;

  /// Floor and ceiling on how many may be picked. [maxSelected] is enforced in
  /// the sheet as well: past it the unticked rows stop responding rather than
  /// letting the user pick something the form will reject.
  final int? minSelected;
  final int? maxSelected;

  /// Replaces the built-in rule entirely. Receives the selected ids.
  /// Call [AppMultiSelectInput.validate] from inside it to add a rule on top
  /// instead of dropping the required, min and max checks.
  final String? Function(List<String> ids)? validator;

  /// When the field validates itself. Null follows the config.
  final AutovalidateMode? autovalidateMode;

  final AppMultiSelectDisplay display;

  /// How many chips are drawn before the rest become a "+N" chip. Only read by
  /// [AppMultiSelectDisplay.chips].
  final int maxVisibleChips;

  final String searchHint;

  /// Heading over the sheet. Defaults to [label].
  final String? searchTitle;

  /// Optional leading widget per row in the sheet.
  final Widget Function(T item)? leadingOf;

  /// Optional dimmed text at the end of a sheet row.
  final String Function(T item)? trailingLabelOf;

  /// Replaces the sheet's default filter, a case-insensitive `contains` over
  /// [labelOf]. Returns the rows to show in the order to show them.
  final List<T> Function(List<T> items, String query)? filter;

  /// Shown in the sheet in place of the list when there is nothing to show.
  final String? emptyLabel;

  final Widget? prefixIcon;

  /// Replaces the chevron — and with it the clear button.
  final Widget? suffixIcon;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// The rule applied when no [validator] is given: a required field holds at
  /// least one id, and the selection sits inside [min] and [max].
  ///
  /// Exposed so a custom [validator] can layer on top of it:
  ///
  ///   validator: (ids) =>
  ///       AppMultiSelectInput.validate(ids, required: true) ??
  ///       (ids.contains('archived') ? 'That tag is closed' : null),
  static String? validate(
    List<String> ids, {
    bool required = false,
    int? min,
    int? max,
  }) {
    if (required && ids.isEmpty) return 'This field is required';
    // An empty optional field is not "fewer than min" — it is untouched, and
    // saying "pick at least 2" to someone who picked none is noise.
    if (min != null && ids.isNotEmpty && ids.length < min) {
      return 'Pick at least $min';
    }
    if (max != null && ids.length > max) return 'Pick no more than $max';
    return null;
  }

  /// The items the selection points at, in [items] order.
  List<T> get _selected => [
    for (final item in items)
      if (selectedIds.contains(idOf(item))) item,
  ];

  String? _validate(List<String> ids) {
    final rule = validator;
    return rule != null
        ? rule(ids)
        : validate(
            ids,
            required: required,
            min: minSelected,
            max: maxSelected,
          );
  }

  Future<void> _openSheet(
    BuildContext context,
    FormFieldState<List<String>> state,
  ) async {
    final picked = await SearchPickerSheet.showMulti<T>(
      context,
      title: searchTitle ?? label,
      searchHint: searchHint,
      items: items,
      idOf: idOf,
      labelOf: labelOf,
      selectedIds: selectedIds,
      maxSelected: maxSelected,
      leadingOf: leadingOf,
      trailingLabelOf: trailingLabelOf,
      filter: filter,
      emptyLabel:
          emptyLabel ??
          (items.isEmpty
              ? 'Nothing to choose from'
              : 'Nothing matches that search'),
      variant: variant,
    );
    // Null is a dismissed sheet, which leaves the selection alone. An empty
    // list is a confirmed "none of them", which does not.
    if (picked == null) return;
    _report(picked, state);
  }

  void _report(List<T> picked, FormFieldState<List<String>> state) {
    final ids = [for (final item in picked) idOf(item)];
    // Marks the field as interacted with, so a form set to validate on
    // interaction clears its error the moment a selection lands.
    state.didChange(ids);
    onChanged(ids);
    onSelected?.call(picked);
  }

  void _remove(T item, FormFieldState<List<String>> state) {
    HapticFeedback.selectionClick();
    final id = idOf(item);
    _report([
      for (final other in _selected)
        if (idOf(other) != id) other,
    ], state);
  }

  /// What sits at the end of the field: the caller's suffix, else the clear
  /// button once there is something to clear, ahead of the chevron.
  Widget? _trailing(FormFieldState<List<String>> state) {
    if (suffixIcon != null) return suffixIcon;
    if (!enabled) return null;

    const chevron = Icon(Icons.keyboard_arrow_down);
    if (selectedIds.isEmpty) return chevron;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _report(const [], state);
          },
          tooltip: 'Clear',
          icon: const Icon(Icons.close),
        ),
        chevron,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(
      items.map(idOf).toSet().length == items.length,
      'AppMultiSelectInput<$T>: idOf returned the same id for more than one '
      'item. Ids are what the selection is made of, so they have to be unique.',
    );

    return InputFieldLayout(
      label: label,
      required: required,
      labelMode: labelMode,
      variant: variant,
      size: size,
      field: FormField<List<String>>(
        initialValue: selectedIds,
        enabled: enabled,
        autovalidateMode:
            autovalidateMode ?? AppInputStyle.config.autovalidateMode,
        // Judged on [selectedIds] rather than on the value this FormField holds:
        // the caller owns the selection, so its answer is the true one even
        // before a rebuild has reached here.
        validator: (_) => _validate(selectedIds),
        builder: (state) => MergeSemantics(
          child: Semantics(
            button: true,
            enabled: enabled,
            child: InkWell(
              onTap: enabled ? () => _openSheet(context, state) : null,
              borderRadius: AppConstants.borderRadius12,
              child: InputDecorator(
                decoration: AppInputStyle.decoration(
                  context,
                  variant: variant,
                  type: type,
                  shape: shape,
                  size: size,
                  label: label,
                  labelMode: labelMode,
                  required: required,
                  hint: hint,
                  prefixIcon: prefixIcon,
                  suffixIcon: _trailing(state),
                  enabled: enabled,
                ).copyWith(errorText: state.errorText),
                isEmpty: selectedIds.isEmpty,
                child: selectedIds.isEmpty ? null : _value(context, state),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _value(BuildContext context, FormFieldState<List<String>> state) {
    final accent = AppInputStyle.accentOf(context, variant);
    final selected = _selected;
    final valueStyle = AppInputStyle.textStyle(context, size: size)?.copyWith(
      color: accent,
      fontWeight: FontWeight.bold,
    );

    return switch (display) {
      AppMultiSelectDisplay.count => Text(
        '${selected.length} selected',
        style: valueStyle,
      ),
      AppMultiSelectDisplay.labels => Text(
        [for (final item in selected) labelOf(item)].join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: valueStyle,
      ),
      AppMultiSelectDisplay.chips => _chips(context, selected, state, accent),
    };
  }

  Widget _chips(
    BuildContext context,
    List<T> selected,
    FormFieldState<List<String>> state,
    Color accent,
  ) {
    final overflow = selected.length - maxVisibleChips;
    final shown = overflow > 0 ? selected.take(maxVisibleChips) : selected;

    return Wrap(
      spacing: AppConstants.space4,
      runSpacing: AppConstants.space4,
      children: [
        for (final item in shown)
          // The chip's own delete button is the shortest path to dropping one
          // pick, and it keeps the sheet for the case where several change.
          InputChip(
            label: Text(labelOf(item)),
            labelStyle: context.textTheme.bodySmall?.copyWith(color: accent),
            backgroundColor: accent.withValues(
              alpha: AppInputStyle.config.fillOpacity * 2,
            ),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
            deleteIcon: const Icon(Icons.close, size: AppConstants.iconSmall),
            deleteIconColor: accent,
            onDeleted: enabled ? () => _remove(item, state) : null,
          ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.space4),
            child: Text(
              '+$overflow',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
''';

  /// Returns the generated appDateRangeInput template.
  static String appDateRangeInput() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_input_style.dart';
import './input_title.dart';
import '../../../core/utils/extensions.dart';

/// A read-only field holding a start and an end date, opening the calendar
/// range picker.
///
/// ```dart
/// AppDateRangeInput(
///   label: 'Period',
///   initialValue: _period,
///   onChanged: (range) => setState(() => _period = range),
/// )
/// ```
///
/// Unlike [AppDateInput] this does not switch pickers per platform: Cupertino
/// has no range wheel, and two wheels stitched together reads worse than the
/// calendar users of both platforms already know. The [firstDate] / [lastDate]
/// window and [maxDays] are enforced here rather than left to the picker.
class AppDateRangeInput extends StatefulWidget {
  const AppDateRangeInput({
    super.key,
    required this.label,
    this.initialValue,
    this.hint,
    this.separator = ' – ',
    this.firstDate,
    this.lastDate,
    this.maxDays,
    this.enabled = true,
    this.readOnly = false,
    this.required = false,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onCleared,
    this.prefixIcon,
    this.suffixIcon,
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
    this.textAlign = TextAlign.start,
  });

  final String label;

  /// The range the field starts on. The caller keeps ownership of the value
  /// after that — [onChanged] reports every pick.
  final DateTimeRange? initialValue;

  final String? hint;

  /// What goes between the two dates. An en dash by default, which is what a
  /// range is written with.
  final String separator;

  /// The selectable window. Null is a century either side of today, matching
  /// [AppDateInput].
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Longest range the field accepts, in days, inclusive of both ends. A pick
  /// wider than this is rejected with a message rather than silently trimmed —
  /// the user chose two dates and deserves to know which rule refused them.
  final int? maxDays;

  final bool enabled;

  /// Styled normally but opens nothing — for a range that is displayed rather
  /// than chosen.
  final bool readOnly;

  /// Marks the label, and — unless [validator] replaces the rule — rejects an
  /// empty field when the form validates.
  final bool required;

  /// Replaces the built-in rule entirely. Receives the current range.
  /// Call [AppDateRangeInput.validate] from inside it to add a rule on top
  /// instead of dropping the required and [maxDays] checks.
  final String? Function(DateTimeRange? range)? validator;

  final AutovalidateMode? autovalidateMode;

  /// Fires with the picked range.
  final ValueChanged<DateTimeRange>? onChanged;

  /// Providing it is what puts the clear button in the field.
  final VoidCallback? onCleared;

  final Widget? prefixIcon;
  final Widget? suffixIcon;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  final TextAlign textAlign;

  /// The rule applied when no [validator] is given: a required field holds a
  /// range, and a range is no wider than [maxDays].
  static String? validate(
    DateTimeRange? range, {
    bool required = false,
    int? maxDays,
  }) {
    if (range == null) {
      return required ? 'This field is required' : null;
    }
    if (maxDays != null && range.duration.inDays + 1 > maxDays) {
      return 'Pick a range of $maxDays days or fewer';
    }
    return null;
  }

  @override
  State<AppDateRangeInput> createState() => _AppDateRangeInputState();
}

class _AppDateRangeInputState extends State<AppDateRangeInput> {
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _range = widget.initialValue;
  }

  @override
  void didUpdateWidget(AppDateRangeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The caller cleared or moved the range from outside — a reset button on
    // the form, a value arriving from a fetch.
    if (widget.initialValue != oldWidget.initialValue) {
      _range = widget.initialValue;
    }
  }

  DateTime get _firstDate =>
      widget.firstDate ??
      DateTime.now().subtract(const Duration(days: 365 * 100));

  DateTime get _lastDate =>
      widget.lastDate ?? DateTime.now().add(const Duration(days: 365 * 100));

  String get _text {
    final range = _range;
    if (range == null) return '';
    return '${range.start.formattedDate}${widget.separator}'
        '${range.end.formattedDate}';
  }

  Future<void> _pick() async {
    HapticFeedback.selectionClick();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: _firstDate,
      lastDate: _lastDate,
      builder: (context, child) => MediaQuery(
        // A range picker is two dates wide already; letting the system text
        // scale grow it as well is what pushes the calendar off the screen.
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    HapticFeedback.selectionClick();
    setState(() => _range = picked);
    widget.onChanged?.call(picked);
  }

  void _clear() {
    HapticFeedback.selectionClick();
    setState(() => _range = null);
    widget.onCleared?.call();
  }

  String? _validate() {
    final rule = widget.validator;
    return rule != null
        ? rule(_range)
        : AppDateRangeInput.validate(
            _range,
            required: widget.required,
            maxDays: widget.maxDays,
          );
  }

  Widget? _trailing() {
    if (widget.suffixIcon != null) return widget.suffixIcon;
    if (!widget.enabled || widget.readOnly) return null;

    const calendar = Icon(Icons.date_range_outlined);
    if (widget.onCleared == null || _range == null) return calendar;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _clear,
          tooltip: 'Clear',
          icon: const Icon(Icons.close),
        ),
        calendar,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, widget.variant);
    final alignment = AppInputStyle.alignmentOf(widget.textAlign);

    return InputFieldLayout(
      label: widget.label,
      required: widget.required,
      labelMode: widget.labelMode,
      variant: widget.variant,
      size: widget.size,
      textAlign: widget.textAlign,
      // A FormField rather than a TextFormField: the value is a range, and a
      // controller holding its printed form would make the text the truth.
      field: FormField<DateTimeRange>(
        initialValue: _range,
        enabled: widget.enabled,
        autovalidateMode:
            widget.autovalidateMode ?? AppInputStyle.config.autovalidateMode,
        validator: (_) => _validate(),
        builder: (state) => MergeSemantics(
          child: Semantics(
            button: true,
            enabled: widget.enabled && !widget.readOnly,
            child: InkWell(
              onTap: widget.enabled && !widget.readOnly
                  ? () async {
                      await _pick();
                      // Clears the error the moment a range lands, on a form
                      // that validates as it is filled in.
                      if (mounted) state.didChange(_range);
                    }
                  : null,
              child: InputDecorator(
                decoration: AppInputStyle.decoration(
                  context,
                  variant: widget.variant,
                  type: widget.type,
                  shape: widget.shape,
                  size: widget.size,
                  label: widget.label,
                  labelMode: widget.labelMode,
                  required: widget.required,
                  hint: widget.hint,
                  prefixIcon: widget.prefixIcon,
                  suffixIcon: _trailing(),
                  enabled: widget.enabled,
                ).copyWith(errorText: state.errorText),
                isEmpty: _range == null,
                child: _range == null
                    ? null
                    : Align(
                        alignment: alignment,
                        child: Text(
                          _text,
                          textAlign: widget.textAlign,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppInputStyle.textStyle(
                            context,
                            size: widget.size,
                          )?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
''';

  /// Returns the generated appFilePickerField template.
  static String appFilePickerField() => r'''
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_input_style.dart';
import './input_title.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// One attachment held by an [AppFilePickerField].
///
/// Deliberately not a `file_picker` or `image_picker` type: the field takes
/// whatever the app already uses — `MediaService`, a camera, a download — and
/// maps it into this. Nothing here imports a picker package, so the widget
/// costs the project no dependency it had not already chosen.
class AppPickedFile {
  const AppPickedFile({required this.name, this.path, this.sizeBytes});

  final String name;

  /// Where the bytes are, when they are on disk. A file chosen on the web has
  /// no path, and the field simply shows no preview for it.
  final String? path;

  final int? sizeBytes;

  /// Lower-case extension without the dot, or empty when the name has none.
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// Whether this can be drawn as a thumbnail.
  bool get isImage =>
      const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}
          .contains(extension);

  /// Size as a person reads it — "480 KB", "1.2 MB".
  String? get readableSize {
    final bytes = sizeBytes;
    if (bytes == null) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// The icon that stands in for a file with no thumbnail.
  IconData get icon => switch (extension) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'doc' || 'docx' || 'txt' || 'rtf' => Icons.description_outlined,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
    'zip' || 'rar' || '7z' => Icons.folder_zip_outlined,
    'mp3' || 'wav' || 'm4a' => Icons.audiotrack_outlined,
    'mp4' || 'mov' || 'avi' => Icons.movie_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}

/// A field whose value is a list of attachments: an area that opens the app's
/// own picker, and a row per file with a thumbnail and a remove button.
///
/// The picking itself belongs to the caller — this is the field, not the
/// plugin:
///
/// ```dart
/// AppFilePickerField(
///   label: 'Documents',
///   files: _files,
///   maxFiles: 3,
///   required: true,
///   onPick: () async {
///     final picked = await ref.read(mediaServiceProvider).pickFiles();
///     return [for (final f in picked) AppPickedFile(name: f.name, path: f.path)];
///   },
///   onChanged: (files) => setState(() => _files = files),
/// )
/// ```
class AppFilePickerField extends StatelessWidget {
  const AppFilePickerField({
    super.key,
    required this.label,
    required this.files,
    required this.onPick,
    required this.onChanged,
    this.hint = 'Add a file',
    this.maxFiles,
    this.enabled = true,
    this.required = false,
    this.validator,
    this.autovalidateMode,
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
  });

  final String label;

  /// The attachments held right now. The caller owns them, as with every other
  /// field in the family.
  final List<AppPickedFile> files;

  /// Opens whatever picker the app uses and resolves to what was chosen.
  /// Returning null or an empty list leaves the field alone, so a cancelled
  /// picker costs nothing.
  final Future<List<AppPickedFile>?> Function() onPick;

  /// Called with the complete new list, added or removed.
  final ValueChanged<List<AppPickedFile>> onChanged;

  /// Copy on the add area.
  final String hint;

  /// Ceiling on how many may be held. At the limit the add area disappears
  /// rather than offering a pick the field would have to throw away.
  final int? maxFiles;

  final bool enabled;

  /// Marks the label, and — unless [validator] replaces the rule — rejects an
  /// empty field when the form validates.
  final bool required;

  /// Replaces the built-in rule entirely. Receives the current files.
  final String? Function(List<AppPickedFile> files)? validator;

  final AutovalidateMode? autovalidateMode;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// The rule applied when no [validator] is given: a required field holds at
  /// least one file, and no more than [max] are held.
  static String? validate(
    List<AppPickedFile> files, {
    bool required = false,
    int? max,
  }) {
    if (required && files.isEmpty) return 'This field is required';
    if (max != null && files.length > max) {
      return 'Attach no more than $max file${max == 1 ? '' : 's'}';
    }
    return null;
  }

  bool get _atLimit => maxFiles != null && files.length >= maxFiles!;

  String? _validate() {
    final rule = validator;
    return rule != null
        ? rule(files)
        : validate(files, required: required, max: maxFiles);
  }

  Future<void> _add(FormFieldState<List<AppPickedFile>> state) async {
    HapticFeedback.selectionClick();
    final picked = await onPick();
    if (picked == null || picked.isEmpty) return;

    // Trims at the ceiling rather than refusing the whole pick: someone who
    // selected five images for three slots meant to attach three.
    final next = [...files, ...picked];
    final limited = maxFiles == null ? next : next.take(maxFiles!).toList();
    state.didChange(limited);
    onChanged(limited);
  }

  void _remove(int index, FormFieldState<List<AppPickedFile>> state) {
    HapticFeedback.selectionClick();
    final next = [...files]..removeAt(index);
    state.didChange(next);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return InputFieldLayout(
      label: label,
      required: required,
      labelMode: labelMode,
      variant: variant,
      size: size,
      field: FormField<List<AppPickedFile>>(
        initialValue: files,
        enabled: enabled,
        autovalidateMode:
            autovalidateMode ?? AppInputStyle.config.autovalidateMode,
        validator: (_) => _validate(),
        builder: (state) {
          final error = state.errorText;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < files.length; i++)
                _FileRow(
                  file: files[i],
                  variant: variant,
                  onRemove: enabled ? () => _remove(i, state) : null,
                ),
              if (enabled && !_atLimit) _addArea(context, state, error != null),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppConstants.space4,
                    left: AppConstants.space12,
                  ),
                  child: Text(
                    error,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The tappable area that opens the picker. Dashed-looking rather than a
  /// filled field: it is an action, and it should not read as a value.
  Widget _addArea(
    BuildContext context,
    FormFieldState<List<AppPickedFile>> state,
    bool hasError,
  ) {
    final accent = AppInputStyle.accentOf(context, variant);
    final borderColor = hasError
        ? context.colorScheme.error
        : accent.withValues(alpha: AppInputStyle.config.idleBorderOpacity);

    return Semantics(
      button: true,
      label: hint,
      child: InkWell(
        onTap: () => _add(state),
        borderRadius: AppConstants.borderRadius12,
        child: Container(
          width: double.infinity,
          padding: AppConstants.padding16,
          decoration: BoxDecoration(
            borderRadius: AppConstants.borderRadius12,
            border: Border.all(
              color: borderColor,
              width: AppInputStyle.config.idleBorderWidth,
            ),
            color: accent.withValues(alpha: AppInputStyle.config.fillOpacity),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppConstants.space8,
            children: [
              Icon(
                Icons.attach_file,
                size: AppInputStyle.configOf(size).iconSize,
                color: accent,
              ),
              Text(
                hint,
                style: AppInputStyle.textStyle(
                  context,
                  size: size,
                )?.copyWith(color: accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One attachment: thumbnail or type icon, name, size, and a remove button.
class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onRemove, this.variant});

  final AppPickedFile file;
  final VoidCallback? onRemove;
  final AppInputVariant? variant;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    final size = file.readableSize;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.space8),
      child: Row(
        spacing: AppConstants.space12,
        children: [
          ClipRRect(
            borderRadius: AppConstants.borderRadius8,
            child: SizedBox.square(
              dimension: AppConstants.touchTarget,
              child: _thumbnail(context, accent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium,
                ),
                if (size != null)
                  Text(
                    size,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }

  Widget _thumbnail(BuildContext context, Color accent) {
    final path = file.path;
    if (file.isImage && path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        // A file that has been moved or deleted since it was picked is not a
        // reason to break the row.
        errorBuilder: (context, error, stackTrace) => _icon(context, accent),
      );
    }
    return _icon(context, accent);
  }

  Widget _icon(BuildContext context, Color accent) => ColoredBox(
    color: accent.withValues(alpha: AppInputStyle.config.fillOpacity * 2),
    child: Icon(file.icon, color: accent, size: AppConstants.iconMedium),
  );
}
''';

  /// Returns the generated appRating template.
  static String appRating() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_input_style.dart';
import './input_title.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A star rating, both ways round: tappable when [onChanged] is given, a
/// read-only score when it is not.
///
/// ```dart
/// AppRating(value: _score, onChanged: (v) => setState(() => _score = v))
/// AppRating(value: product.rating, allowHalf: true)   // display only
/// ```
///
/// The same widget shows a product's 4.5 and collects the user's 5, which is
/// what keeps a list's stars and a review form's stars the same size and color.
class AppRating extends StatelessWidget {
  const AppRating({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.count = 5,
    this.allowHalf = false,
    this.allowClear = false,
    this.required = false,
    this.validator,
    this.autovalidateMode,
    this.starSize,
    this.showValueLabel = false,
    this.icon = Icons.star_rounded,
    this.emptyIcon,
    this.variant,
    this.labelMode,
  });

  /// The score, from 0 to [count]. Halves are only drawn when [allowHalf].
  final double value;

  /// Pass null for a display-only rating: no taps, no haptics, and no place in
  /// a form.
  final ValueChanged<double>? onChanged;

  /// Shown above the stars, like any other field's label. Null draws none.
  final String? label;

  final int count;

  /// Whether a tap on the left half of a star scores a half.
  final bool allowHalf;

  /// Whether tapping the current score again clears it back to 0 — the way out
  /// of a rating given by accident.
  final bool allowClear;

  /// Marks the label, and — unless [validator] replaces the rule — refuses to
  /// validate at 0.
  final bool required;

  /// Replaces the built-in rule entirely. Receives the current score.
  final String? Function(double value)? validator;

  final AutovalidateMode? autovalidateMode;

  /// Null takes the icon size from [AppInputSize.large]'s metrics, which is the
  /// scale a rating is read at.
  final double? starSize;

  /// Whether the numeric score sits beside the stars — "4.5".
  final bool showValueLabel;

  final IconData icon;

  /// The unfilled star. Null derives an outline from [icon] where one is known,
  /// and otherwise reuses [icon] at a lower opacity.
  final IconData? emptyIcon;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;
  final AppInputLabelMode? labelMode;

  /// The rule applied when no [validator] is given: a required rating is not 0.
  static String? validate(double value, {bool required = false}) =>
      required && value <= 0 ? 'Please choose a rating' : null;

  bool get _enabled => onChanged != null;

  double get _starSize =>
      starSize ?? AppInputStyle.configOf(AppInputSize.large).iconSize;

  /// The score a tap at [dx] within a star of [_starSize] means. The left half
  /// of a star is the half score, which is how every rating widget worth using
  /// behaves — and is why a half needs no separate control.
  double _scoreFor(int index, double dx) {
    if (!allowHalf) return index + 1;
    return dx < _starSize / 2 ? index + 0.5 : index + 1;
  }

  void _report(double next) {
    HapticFeedback.selectionClick();
    // Tapping the score you already gave takes it back, when the field allows
    // an empty answer at all.
    onChanged!(allowClear && next == value ? 0 : next);
  }

  @override
  Widget build(BuildContext context) {
    final stars = _stars(context);
    final title = label;

    if (title == null) return stars;

    return InputFieldLayout(
      label: title,
      required: required,
      labelMode: labelMode,
      variant: variant,
      field: stars,
    );
  }

  Widget _stars(BuildContext context) {
    final row = Semantics(
      slider: _enabled,
      value: '${value.toStringAsFixed(allowHalf ? 1 : 0)} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) _star(context, i),
          if (showValueLabel) ...[
            const SizedBox(width: AppConstants.space8),
            Text(
              value.toStringAsFixed(allowHalf ? 1 : 0),
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );

    // A display-only rating is not a form field, and wrapping it in one would
    // put it in the way of `Form.validate()` with nothing to say.
    if (!_enabled) return row;

    return SelectionFormField<double>(
      value: value,
      autovalidateMode: autovalidateMode,
      validator: validator ?? (v) => validate(v, required: required),
      builder: (_) => Align(alignment: AlignmentDirectional.centerStart, child: row),
    );
  }

  Widget _star(BuildContext context, int index) {
    final accent = AppInputStyle.accentOf(context, variant);
    final filled = value >= index + 1;
    final half = allowHalf && !filled && value >= index + 0.5;

    final star = Icon(
      filled
          ? icon
          : half
          ? Icons.star_half_rounded
          : (emptyIcon ?? _outlineOf(icon)),
      size: _starSize,
      color: filled || half
          ? accent
          : accent.withValues(alpha: AppInputStyle.config.idleBorderOpacity),
    );

    if (!_enabled) return star;

    // A tap has to be located inside the star to tell a half from a whole, so
    // this reads the position rather than taking an onTap.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _report(_scoreFor(index, details.localPosition.dx)),
      child: Padding(
        // Widens the target to the 48px minimum without widening the star.
        padding: EdgeInsets.symmetric(
          vertical: (AppConstants.touchTarget - _starSize).clamp(0, 24) / 2,
        ),
        child: star,
      ),
    );
  }

  /// The outline twin of the filled star icons, so the default pairing needs no
  /// second argument from the caller.
  static IconData _outlineOf(IconData icon) => switch (icon) {
    Icons.star_rounded => Icons.star_outline_rounded,
    Icons.star => Icons.star_border,
    Icons.favorite => Icons.favorite_border,
    Icons.circle => Icons.circle_outlined,
    _ => icon,
  };
}
''';
}
