import 'package:moarch/src/templates/ui/audio_templates.dart';
import 'package:moarch/src/templates/ui/calendar_templates.dart';
import 'package:moarch/src/templates/ui/country_templates.dart';
import 'package:moarch/src/templates/ui/drag_templates.dart';
import 'package:moarch/src/templates/ui/content_templates.dart';
import 'package:moarch/src/templates/ui/inputs_templates.dart';
import 'package:moarch/src/templates/ui/modals_templates.dart';
import 'package:moarch/src/templates/ui/navigation_templates.dart';
import 'package:moarch/src/templates/ui/table_templates.dart';
import 'package:moarch/src/templates/ui/phone_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/templates/ui/text_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('haptic feedback', () {
    /// Every widget in the kit a finger can act on. A control that changes
    /// something and says nothing back is the gap these cover.
    final tactile = <String, String Function()>{
      'appButton': SharedTemplates.appButton,
      'appIconButton': SharedTemplates.appIconButton,
      'appTextButton': TextTemplates.appTextButton,
      'appRichText': TextTemplates.appRichText,
      'appInput': SharedTemplates.appInput,
      'dateInput': SharedTemplates.dateInput,
      'timeInput': SharedTemplates.timeInput,
      'cupertinoPickerSheet': SharedTemplates.cupertinoPickerSheet,
      'appDropdown': SharedTemplates.appDropdown,
      'searchPickerSheet': SharedTemplates.searchPickerSheet,
      'appPhoneInput': PhoneTemplates.appPhoneInput,
      'appCheckbox': SharedTemplates.appCheckbox,
      'appCheckboxLabel': SharedTemplates.appCheckboxLabel,
      'appSwitch': SharedTemplates.appSwitch,
      'appSegmented': SharedTemplates.appSegmented,
      'appChoiceChip': SharedTemplates.appChoiceChip,
      'appRadioGroup': SharedTemplates.appRadioGroup,
      'appSlider': SharedTemplates.appSlider,
      'appStepper': SharedTemplates.appStepper,
      'appListTile': SharedTemplates.appListTile,
      'appCard': SharedTemplates.appCard,
      'appExpansionTile': SharedTemplates.appExpansionTile,
      'appSectionHeader': SharedTemplates.appSectionHeader,
      'appBanner': SharedTemplates.appBanner,
      'appToast': SharedTemplates.appToast,
      'appBottomNav': SharedTemplates.appBottomNav,
      'appBottomSheetScaffold': SharedTemplates.appBottomSheetScaffold,
      'appFab': SharedTemplates.appFab,
      'appMultiSelect': InputsTemplates.appMultiSelect,
      'appDateRangeInput': InputsTemplates.appDateRangeInput,
      'appFilePickerField': InputsTemplates.appFilePickerField,
      'appRating': InputsTemplates.appRating,
      'appCalendar': CalendarTemplates.appCalendar,
      'appCountryPicker': CountryTemplates.appCountryPicker,
      'appAudioPlayer': AudioTemplates.appAudioPlayer,
      'appTable': TableTemplates.appTable,
      'appDragSection': DragTemplates.appDragSection,
      'appActionSheet': ModalsTemplates.appActionSheet,
      'appTabs': NavigationTemplates.appTabs,
      'appDrawer': NavigationTemplates.appDrawer,
      'appNavRail': NavigationTemplates.appNavRail,
      'appTimeline': ContentTemplates.appTimeline,
    };

    tactile.forEach((name, template) {
      test('$name answers a touch', () {
        final output = template();
        expect(output, contains('HapticFeedback.'), reason: '$name is silent');
        expect(
          output,
          contains("import 'package:flutter/services.dart';"),
          reason: '$name calls HapticFeedback without importing it',
        );
      });
    });

    test('the OTP field leaves the haptics to mo_2fa_code', () {
      expect(SharedTemplates.appOtpInput(), contains('hapticFeedback: true'));
    });

    test('a toast tells you how bad the news is by feel', () {
      final output = SharedTemplates.appToast();
      expect(output, contains('AppToastType.success => HapticFeedback.light'));
      expect(output, contains('AppToastType.warning => HapticFeedback.medium'));
      expect(output, contains('AppToastType.error => HapticFeedback.heavy'));
    });

    test('a continuous slider buzzes on grab, a stepped one on each step', () {
      final output = SharedTemplates.appSlider();
      expect(output, contains('onChangeStart:'));
      expect(output, contains('if (divisions != null && v != value)'));
    });

    test('a checkbox row buzzes once, whichever half is tapped', () {
      expect(
        SharedTemplates.appCheckbox(),
        contains('onChanged: onChanged == null'),
      );
      // Both halves of the row report through one `toggle`, which is the only
      // place the row buzzes — so neither half can double up or stay silent.
      final row = SharedTemplates.appCheckboxLabel();
      expect(row, contains('void toggle(bool next) {'));
      expect('HapticFeedback.'.allMatches(row).length, 1);
      expect(row, contains('onTap: enabled ? () => toggle(!value) : null'));
      expect(row, contains('onChanged: enabled ? (v) => toggle(v ?? false)'));
    });

    test('a picker reports the open and the pick, not every wheel notch', () {
      for (final output in [
        SharedTemplates.dateInput(),
        SharedTemplates.timeInput(),
      ]) {
        // Once when the sheet or dialog opens, once when a value comes back.
        expect('HapticFeedback.'.allMatches(output).length, 2);
      }
    });
  });

  group('appToast', () {
    final output = SharedTemplates.appToast();

    test('draws its own card, because a SnackBar cannot be outlined', () {
      expect(output, contains('backgroundColor: Colors.transparent,'));
      expect(output, contains('elevation: 0,'));
      expect(output, contains('padding: EdgeInsets.zero,'));
      expect(output, contains('class _ToastCard extends StatelessWidget'));
      expect(output, contains('border: Border.all('));
      expect(output, contains('boxShadow: ['));
    });

    test('resolves its colors where it is built, not where it was shown', () {
      // The SnackBar builds a frame later; colors computed in show() would be
      // a light-palette green on a dark card if the theme changed in between.
      expect(output,
          contains('final isDark = theme.brightness == Brightness.dark;'));
      expect(output,
          contains('final (accent, icon) = AppToast._resolve(type, isDark);'));
      expect(output, contains('required this.type,'));
    });

    test('sits on an elevated surface in dark, a plain one in light', () {
      // A toast is an overlay: in a dark theme it has to be lighter than the
      // page it covers, which surfaceContainerLowest is not.
      expect(
        output,
        contains('isDark\n              ? colorScheme.surfaceContainerHighest\n'
            '              : colorScheme.surfaceContainerLowest,'),
      );
    });

    test('tints the surface without coloring the text', () {
      expect(output, contains('color: Color.alphaBlend('));
      expect(
          output, contains('accent.withValues(alpha: AppToast._surfaceTint)'));
      expect(output, contains('static const double _surfaceTint = 0.07;'));
    });

    test('stays a card rather than becoming a banner on a tablet', () {
      expect(output, contains('static const double _maxWidth = 480;'));
      expect(output,
          contains('constraints: const BoxConstraints(maxWidth: _maxWidth),'));
    });

    test('takes a title over the detail', () {
      expect(output, contains('String? title,'));
      expect(output, contains('final heading = title;'));
      expect(output, contains('if (heading != null)'));
      // The message dims only when a title is carrying the emphasis.
      expect(
        output,
        contains('color: heading == null\n                          '
            '? colorScheme.onSurface\n                          '
            ': colorScheme.onSurfaceVariant,'),
      );
    });

    test('an action dismisses the toast before it runs', () {
      expect(
        output,
        contains(
            'ScaffoldMessenger.of(context).hideCurrentSnackBar();\n                onAction!();'),
      );
    });

    test('offers one helper per status, and a way to take it back', () {
      for (final helper in ['success', 'error', 'warning', 'info']) {
        expect(
          output,
          contains('static void $helper(BuildContext context, String message'),
          reason: '$helper helper is missing',
        );
      }
      expect(output, contains('static void dismiss(BuildContext context)'));
    });

    test('is flicked away sideways', () {
      expect(
          output, contains('dismissDirection: DismissDirection.horizontal,'));
    });
  });

  group('appButton hint', () {
    final output = SharedTemplates.appButton();

    test('sits above the button, centered over it', () {
      expect(output, contains('if (hint == null) return button;'));
      expect(output, contains('textAlign: TextAlign.center,'));
      expect(
          output, contains('crossAxisAlignment: CrossAxisAlignment.center,'));
      // The hint first, the whole button under it.
      expect(
        output.indexOf('hint!,'),
        lessThan(output.indexOf('        button,')),
      );
    });

    test('is centered without stretching, which would eat an explicit width',
        () {
      // Stretch hands children a tight cross-axis constraint, so a
      // `width: 220` button would go full-bleed the moment it took a hint.
      expect(output, isNot(contains('CrossAxisAlignment.stretch')));
      expect(output, contains('height: sizeConfig.height,'));
    });

    test('reads as a caption rather than as part of the fill', () {
      expect(output, contains('color: theme.colorScheme.onSurfaceVariant,'));
      expect(
        output,
        isNot(contains('foregroundColor.withValues(alpha: 0.85)')),
      );
    });

    test('the spinner still replaces the button\'s own content', () {
      expect(output, contains('child: isLoading\n            ? SizedBox('));
    });
  });

  group('appSingleScrollView', () {
    final output = SharedTemplates.appSingleScrollView();

    test('decides the page defaults so screens stop re-deciding them', () {
      expect(output, contains('this.padding = AppConstants.padding12'));
      expect(
        output,
        contains(
          'this.keyboardDismissBehavior = '
          'ScrollViewKeyboardDismissBehavior.onDrag',
        ),
      );
      expect(output, contains('this.safeArea = true'));
      expect(output, contains('this.safeAreaTop = true'));
      expect(output, contains('this.safeAreaBottom = true'));
      expect(output, contains('this.safeAreaHorizontal = true'));
    });

    test('every safe-area edge reaches the SafeArea it configures', () {
      expect(output, contains('top: safeAreaTop'));
      expect(output, contains('bottom: safeAreaBottom'));
      expect(output, contains('left: safeAreaHorizontal'));
      expect(output, contains('right: safeAreaHorizontal'));
      // Otherwise the content jumps by the home indicator when a field opens
      // the keyboard.
      expect(output, contains('maintainBottomViewPadding: true'));
      expect(output, contains('if (!safeArea) return scrollView;'));
    });

    test('opts out of the keyboard inset by default — the Scaffold has it', () {
      expect(output, contains('this.avoidKeyboard = false'));
      expect(output, contains('MediaQuery.viewInsetsOf(context).bottom'));
      expect(output, contains('resizeToAvoidBottomInset'));
    });

    test('fills the viewport with something an Expanded can divide', () {
      expect(output, contains('this.fillViewport = false'));
      expect(output, contains('constraints.hasBoundedHeight'));
      expect(output, contains('- resolvedPadding.vertical'));
      expect(output, contains('IntrinsicHeight(child: child)'));
    });

    test('can scroll a short page so a RefreshIndicator still works', () {
      expect(output, contains('this.alwaysScrollable = false'));
      expect(
        output,
        contains('(alwaysScrollable ? const AlwaysScrollableScrollPhysics()'),
      );
    });

    test('builds one scroll view, filled or not', () {
      expect('SingleChildScrollView('.allMatches(output).length, 1);
    });

    test('is in the catalog under Layout & content, standing alone', () {
      final spec = WidgetCatalog.all.firstWhere(
        (spec) => spec.name == 'single-scroll-view',
      );
      expect(spec.file, 'layouts/app_single_scroll_view.dart');
      expect(spec.category, 'Layout & content');
      expect(spec.deps, isEmpty);
      expect(spec.packages, isEmpty);
    });
  });
}
