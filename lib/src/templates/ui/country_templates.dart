/// Templates for the country picker — the one place the country sheet is
/// configured, which `AppPhoneInput` opens for its prefix too.
abstract final class CountryTemplates {
  /// Returns the generated appCountryPicker template.
  static String appCountryPicker() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_country.dart';
import './app_input_style.dart';
import './input_title.dart';
import './search_picker_sheet.dart';
import '../../../core/constants/app_constants.dart';

/// What a country reads as in a closed field.
enum AppCountryDisplay {
  /// `🇵🇹 Portugal` — the default, and what a shipping or address field wants.
  flagAndName,

  /// `Portugal`.
  name,

  /// `🇵🇹 +351` — for a narrow field where the name will not fit.
  flagAndDialCode,

  /// `🇵🇹` alone.
  flag,
}

/// Picks one of the 238 countries in [AppCountries].
///
/// Two ways in. As a field, validating like the rest of the family:
///
/// ```dart
/// AppCountryPicker(
///   label: 'Country',
///   selectedIso: _iso,
///   required: true,
///   onChanged: (country) => setState(() => _iso = country.iso),
/// )
/// ```
///
/// Or as a sheet on its own, for a country picked from somewhere that is not
/// a form — a filter, a settings row, the prefix of a phone field:
///
/// ```dart
/// final country = await AppCountryPicker.show(context, selectedIso: _iso);
/// ```
///
/// [show] is the single place the country sheet is configured — the flag
/// leading each row, the calling code trailing it, and the ranked search that
/// makes `PT` find Portugal rather than the first country whose name happens
/// to contain those letters. `AppPhoneInput` opens this same sheet for its
/// prefix, so the two can never drift apart.
class AppCountryPicker extends StatelessWidget {
  const AppCountryPicker({
    super.key,
    required this.onChanged,
    this.label = 'Country',
    this.selectedIso,
    this.hint = 'Select a country',
    this.display = AppCountryDisplay.flagAndName,
    this.countries,
    this.enabled = true,
    this.required = false,
    this.validator,
    this.autovalidateMode,
    this.showDialCodeInSheet = true,
    this.pickerTitle,
    this.searchHint = 'Search country',
    this.onCleared,
    this.prefixIcon,
    this.suffixIcon,
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
  });

  /// Called with the whole country, not just its code — the caller usually
  /// wants the dial code or the flag as well, and looking it back up by ISO
  /// to get them is work this already did.
  final ValueChanged<AppCountry> onChanged;

  final String label;

  /// The current selection, by ISO 3166-1 alpha-2. Unknown or null shows
  /// [hint].
  final String? selectedIso;

  final String hint;
  final AppCountryDisplay display;

  /// Narrows the list — the countries you ship to, the ones you have numbers
  /// for. Null offers all of [AppCountries.all].
  final List<AppCountry>? countries;

  final bool enabled;

  /// Marks the label and, unless [validator] replaces the rule, rejects an
  /// empty selection when the form validates.
  final bool required;

  /// Replaces the built-in rule. Receives the selected ISO code, or null.
  final String? Function(String? iso)? validator;

  final AutovalidateMode? autovalidateMode;

  /// Shows `+351` at the end of each row in the sheet. Off for a plain
  /// country list where the calling code is noise.
  final bool showDialCodeInSheet;

  /// Heading over the sheet. Defaults to [label].
  final String? pickerTitle;

  final String searchHint;

  /// Offers a clear button once something is selected. Without it the field
  /// cannot be emptied again.
  final VoidCallback? onCleared;

  final Widget? prefixIcon;

  /// Replaces the chevron — and with it the clear button.
  final Widget? suffixIcon;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  static const double _flagSize = 20;

  /// Opens the country sheet and resolves to the pick, or null if it was
  /// dismissed.
  ///
  /// The one configuration of the sheet, shared with `AppPhoneInput`.
  static Future<AppCountry?> show(
    BuildContext context, {
    String? selectedIso,
    List<AppCountry>? countries,
    String title = 'Select a country',
    String searchHint = 'Search country',
    bool showDialCode = true,
    AppInputVariant? variant,
  }) {
    return SearchPickerSheet.show<AppCountry>(
      context,
      title: title,
      searchHint: searchHint,
      items: countries ?? AppCountries.all,
      idOf: (country) => country.iso,
      labelOf: (country) => country.name,
      trailingLabelOf: showDialCode ? (country) => country.dialCode : null,
      leadingOf: (country) => Text(
        country.flag,
        style: const TextStyle(fontSize: _flagSize),
      ),
      // Ranked, so two letters find the country whose code they are rather
      // than the first country whose name happens to contain them.
      filter: (countries, query) => AppCountries.search(query, within: countries),
      selectedId: selectedIso,
      variant: variant,
    );
  }

  /// The rule applied when no [validator] is given.
  ///
  /// Exposed so a custom [validator] can layer onto it rather than replace
  /// it:
  ///
  ///   validator: (iso) =>
  ///       AppCountryPicker.validate(iso, required: true) ??
  ///       (_blocked.contains(iso) ? 'We do not ship there yet' : null),
  static String? validate(String? iso, {bool required = false}) {
    if (required && (iso == null || iso.isEmpty)) {
      return 'This field is required';
    }
    return null;
  }

  AppCountry? get _selected {
    final iso = selectedIso;
    return iso == null ? null : AppCountries.byIso(iso);
  }

  String _labelFor(AppCountry country) => switch (display) {
        AppCountryDisplay.flagAndName => '${country.flag}  ${country.name}',
        AppCountryDisplay.name => country.name,
        AppCountryDisplay.flagAndDialCode =>
          '${country.flag}  ${country.dialCode}',
        AppCountryDisplay.flag => country.flag,
      };

  Future<void> _open(
    BuildContext context,
    FormFieldState<String> state,
  ) async {
    HapticFeedback.selectionClick();
    final picked = await show(
      context,
      selectedIso: selectedIso,
      countries: countries,
      title: pickerTitle ?? label,
      searchHint: searchHint,
      showDialCode: showDialCodeInSheet,
      variant: variant,
    );
    if (picked == null) return;
    state.didChange(picked.iso);
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final country = _selected;

    return InputFieldLayout(
      label: label,
      required: required,
      labelMode: labelMode,
      variant: variant,
      size: size,
      field: FormField<String>(
        initialValue: selectedIso,
        enabled: enabled,
        autovalidateMode:
            autovalidateMode ?? AppInputStyle.config.autovalidateMode,
        // Judged on [selectedIso] rather than on the value this FormField
        // happens to hold: the caller owns the selection, so its answer is
        // the true one even before a rebuild has reached here.
        validator: (_) {
          final rule = validator;
          return rule != null
              ? rule(selectedIso)
              : validate(selectedIso, required: required);
        },
        builder: (state) => MergeSemantics(
          // An InkWell announces nothing on its own; without this a screen
          // reader reads out the country and never says it can be opened.
          child: Semantics(
            button: true,
            enabled: enabled,
            child: InkWell(
              onTap: enabled ? () => _open(context, state) : null,
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
                  suffixIcon: suffixIcon ?? _trailing(state, country),
                  enabled: enabled,
                ).copyWith(errorText: state.errorText),
                // Drives the hint and the floating label the way an empty
                // text field would.
                isEmpty: country == null,
                child: country == null
                    ? null
                    : Text(
                        _labelFor(country),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppInputStyle.textStyle(context, size: size),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The chevron, or a clear button when there is something to clear and
  /// somewhere to report it. A disabled field shows neither action.
  Widget _trailing(FormFieldState<String> state, AppCountry? country) {
    final clear = onCleared;
    if (clear == null || country == null || !enabled) {
      return const Icon(Icons.keyboard_arrow_down);
    }
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () {
        HapticFeedback.selectionClick();
        state.didChange(null);
        clear();
      },
    );
  }
}
''';
}
