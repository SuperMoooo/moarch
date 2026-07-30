import 'package:moarch/src/templates/ui/phone_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('haptic feedback', () {
    /// Every widget in the kit a finger can act on. A control that changes
    /// something and says nothing back is the gap these cover.
    final tactile = <String, String Function()>{
      'appButton': SharedTemplates.appButton,
      'appIconButton': SharedTemplates.appIconButton,
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
