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
      expect(SharedTemplates.appCheckbox(), contains('onChanged: _live'));
      // Both halves of the row report through one `toggle`, which is the only
      // place the row buzzes — so neither half can double up or stay silent.
      final row = SharedTemplates.appCheckboxLabel();
      expect(row, contains('void toggle(bool next) {'));
      expect('HapticFeedback.'.allMatches(row).length, 1);
      expect(row, contains('onTap: live ? () => toggle(!value) : null'));
      expect(row, contains('onChanged: live ? (v) => toggle(v ?? false)'));
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

    test('draws its own outlined card on the overlay', () {
      expect(output, contains('class _ToastCard extends StatelessWidget'));
      expect(output, contains('border: Border.all('));
      expect(output, contains('boxShadow: ['));
      expect(output, contains('Overlay.maybeOf(context, rootOverlay: true)'));
      expect(output, contains('overlay.insert(entry);'));
    });

    test('owns both ends of the animation, which a SnackBar does not expose',
        () {
      expect(
          output,
          contains(
              'static const Duration _enterDuration = Duration(milliseconds: 320);'));
      expect(
          output,
          contains(
              'static const Duration _exitDuration = Duration(milliseconds: 200);'));
      // Decelerating in, accelerating out — reversing easeOutCubic would have
      // the card crawl off the screen.
      expect(output, contains('curve: Curves.easeOutCubic,'));
      expect(output, contains('reverseCurve: Curves.easeInCubic,'));
      // Fade, rise and scale run off the same curve.
      expect(output, contains('FadeTransition('));
      expect(output, contains('begin: const Offset(0, AppToast._rise),'));
      expect(output,
          contains('Tween<double>(begin: AppToast._enterScale, end: 1)'));
    });

    test('honours reduce motion', () {
      expect(output,
          contains('final reduced = MediaQuery.disableAnimationsOf(context);'));
      expect(output,
          contains('reduced ? Duration.zero : AppToast._enterDuration'));
      expect(
          output, contains('reduced ? Duration.zero : AppToast._exitDuration'));
    });

    test('a second toast swaps the content of the card already up', () {
      // Playing a full exit first makes the user watch 200ms of a message they
      // have been replaced out of before the new one starts arriving.
      expect(output, contains('if (_entry != null && live != null) {'));
      expect(output, contains('live.value = spec;'));
      // And the exit is called off if one was already running.
      expect(output, contains('_controller.forward();\n    setState(() {});'));
    });

    test('pulls the entry only once the exit has finished', () {
      expect(
        output,
        contains('if (status == AnimationStatus.dismissed) widget.onGone();'),
      );
      expect(output, contains('entry?.remove();'));
    });

    test('lets go of an overlay that died without playing its exit', () {
      // The route under it popped, the navigator was replaced, a hot restart:
      // _release never ran, and statics left pointing at a disposed notifier
      // make show() treat every later toast as a replacement for a card that is
      // not there — silently doing nothing for the rest of the session.
      expect(output, contains('AppToast._forget(widget.spec);'));
      expect(output,
          contains('static void _forget(ValueNotifier<_ToastSpec> spec) {'));
      // Identity-checked: the exit path clears these a frame before dispose
      // runs, so a toast shown in that gap already owns them.
      expect(output, contains('if (!identical(_live, spec)) return;'));
    });

    test('cannot remove the same entry twice', () {
      // A swipe and the timer can land on the same frame.
      expect(
        output,
        contains('final entry = _entry;\n    _entry = null;'),
      );
    });

    test('sits above the keyboard when there is one', () {
      expect(
        output,
        contains(
            'media.viewInsets.bottom > 0\n        ? media.viewInsets.bottom\n'
            '        : media.viewPadding.bottom;'),
      );
    });

    test('resolves its colors where it is built, not where it was shown', () {
      // The card builds a frame later; colors computed in show() would be
      // a light-palette green on a dark card if the theme changed in between.
      expect(output,
          contains('final isDark = theme.brightness == Brightness.dark;'));
      expect(
          output, contains('final (accent, icon) = AppToast._resolve(type);'));
      expect(output, contains('required this.type,'));
    });

    test('picks the status color per brightness only with a dark theme', () {
      final dark = SharedTemplates.appToast(withDark: true);
      expect(dark,
          contains('final (accent, icon) = AppToast._resolve(type, isDark);'));
      expect(dark,
          contains('isDark ? AppConstants.successDark : AppConstants.success'));

      // With one brand theme those *Dark constants are not generated at all,
      // so reading them would not compile.
      expect(output, isNot(contains('Dark :')));
      expect(output, isNot(contains('AppConstants.successDark')));
      expect(output, contains('AppConstants.success,'));
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
      expect(
          output,
          contains(
              'constraints: const BoxConstraints(maxWidth: AppToast._maxWidth),'));
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
        contains('AppToast.dismiss();\n                onAction!();'),
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
      // No context: the overlay is reachable without one, and the caller that
      // wants a toast gone is often the one whose context is going away.
      expect(
          output, contains('static void dismiss() => _hideCurrent?.call();'));
    });

    test('is flicked away sideways, and skips the exit when it is', () {
      expect(output, contains('direction: DismissDirection.horizontal,'));
      expect(output, contains('onDismissed: (_) => _handleSwipe(),'));
      expect(output, contains('resizeDuration: null,'));
    });
  });

  group('appButton disabled state', () {
    test('one guard covers all three ways a press is refused', () {
      for (final hasBiometricAuth in [false, true]) {
        final output =
            SharedTemplates.appButton(hasBiometricAuth: hasBiometricAuth);

        expect(output, contains('this.isDisabled = false,'),
            reason: 'biometric: $hasBiometricAuth');
        expect(output, contains('final bool isDisabled;'),
            reason: 'biometric: $hasBiometricAuth');
        expect(
          output,
          contains('onPressed: isDisabled || isLoading || onPressed == null'),
          reason: 'biometric: $hasBiometricAuth',
        );
      }
    });

    test('busy is not the same as unavailable', () {
      final output = SharedTemplates.appButton();

      // A loading button keeps its full color; one that is actually disabled
      // fades, and stays faded even while it loads.
      expect(
        output,
        contains(
            'final showsBusy = isLoading && !isDisabled && onPressed != null;'),
      );
      expect(
        output,
        contains('disabledBackgroundColor:\n'
            '              showsBusy ? backgroundColor : disabledBackground,'),
      );
    });

    test('the preview screen shows both ways of disabling', () {
      final preview = SharedTemplates.designSystemView();

      expect(preview, contains("label: 'Disabled (onPressed: null)'"));
      expect(preview, contains("label: 'Disabled (isDisabled: true)'"));
      expect(preview, contains('isDisabled: true,'));
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

  /// A control that draws its name is not the same as one that says it. These
  /// cover the widgets whose spoken name would otherwise go missing — a
  /// spinner replacing a label, an icon standing alone, a picture with no
  /// description.
  group('a control keeps its name', () {
    test('a loading button is still called by its label', () {
      final output = SharedTemplates.appButton();

      // The spinner takes the label's place on screen only.
      expect(output, contains('semanticsLabel: label,'));
    });

    test('a button reads its hint as part of itself', () {
      expect(SharedTemplates.appButton(), contains('return MergeSemantics('));
    });

    test('an icon button falls back to its tooltip for a name', () {
      final output = SharedTemplates.appIconButton();

      expect(output, contains('final String? semanticLabel;'));
      expect(output, contains('final label = semanticLabel ?? tooltip;'));
      expect(output, contains('button: true,'));
      // Tooltip would otherwise announce the same string a second time.
      expect(output, contains('excludeFromSemantics: true,'));
    });

    test('a slider says what the value is of', () {
      final output = SharedTemplates.appSlider();

      expect(output, contains('return Semantics(\n      label: label,'));
    });

    test('a progress bar speaks its caption instead of drawing it twice', () {
      final output = SharedTemplates.appProgressBar();

      expect(output, contains('semanticsLabel: label,'));
      expect(
        output,
        contains("semanticsValue: percent == null ? null : '\$percent%',"),
      );
      expect(output, contains('ExcludeSemantics('));
    });

    test('an avatar is the person, not the initial standing in for them', () {
      final output = SharedTemplates.appAvatar();

      expect(output, contains('image: true,'));
      // Without this a screen reader reads the fallback letter on its own.
      expect(output, contains('ExcludeSemantics(child: clipped)'));
    });

    test('an image is either described or skipped, never unnamed', () {
      final output = SharedTemplates.appImage();

      expect(output, contains('final String? semanticLabel;'));
      expect(
        output,
        contains(
          'if (semanticLabel == null) return ExcludeSemantics(child: clipped);',
        ),
      );
    });

    test('the play button names the action its glyph is showing', () {
      final output = AudioTemplates.appAudioPlayer();

      expect(
        output,
        contains("label: state.playing ? 'Pause' : 'Play',"),
      );
    });
  });

  /// An InkWell ripples but announces nothing, so every tappable container
  /// has to say it is one.
  group('a tappable container announces the tap', () {
    test('a list tile is a button when it has somewhere to go', () {
      final output = SharedTemplates.appListTile();

      expect(
        output,
        contains(
          'child: onTap == null ? row : Semantics(button: true, child: row),',
        ),
      );
      // Claiming the role unconditionally would plant a contrary node inside
      // the AppCardTile card that is the one actually taking the tap.
      expect(output, isNot(contains('button: onTap != null,')));
    });

    test('a card is a button only when it takes a tap', () {
      final output = SharedTemplates.appCard();

      expect(output, contains('final card = onTap == null\n        ? content'));
      expect(output, contains('button: true,'));
    });

    test('a timeline entry that opens something says so', () {
      expect(ContentTemplates.appTimeline(), contains('button: true,'));
    });
  });

  /// Material's minimum touch target. What the eye sees is allowed to be
  /// smaller than what a finger has to hit; what it cannot be is the target
  /// itself.
  group('a small icon button is still 48dp to a finger', () {
    final output = SharedTemplates.appIconButton();

    test('the painted shape and the target are measured apart', () {
      expect(output, contains('static double dimensionOf('));
      expect(output, contains('static double tapTargetOf('));
      expect(output, contains('painted < AppConstants.touchTarget'));
    });

    test('the slop appears only when the shape is under the minimum', () {
      expect(
        output,
        contains('final sized = target == sizeConfig.container'),
      );
      expect(output, contains('behavior: HitTestBehavior.opaque,'));
      // The slop is a hit area, not a second thing to announce.
      expect(output, contains('excludeFromSemantics: true,'));
    });

    test('one tap fires one callback, wherever it lands', () {
      // Both recognizers share the handler rather than each closing over a
      // call to onPressed of its own.
      expect(output, contains('final VoidCallback? handleTap = enabled'));
      expect('onTap: handleTap,'.allMatches(output).length, 2);
      expect('onPressed!();'.allMatches(output).length, 1);
    });

    test('the semantics node covers the target, not just the paint', () {
      expect(
        output.indexOf('return Semantics('),
        greaterThan(output.indexOf('final sized =')),
      );
    });

    test('the app bar reserves what the button occupies', () {
      expect(
        SharedTemplates.appAppBar(),
        contains('AppIconButton.tapTargetOf(backSize)'),
      );
    });
  });

  /// A control and the text naming it are one thing to a screen reader, not
  /// two stops that have to be pieced together.
  group('a label and its control are read as one', () {
    test('the checkbox row merges', () {
      expect(
        SharedTemplates.appCheckboxLabel(),
        contains('child: MergeSemantics('),
      );
    });

    test('each radio row merges', () {
      expect(SharedTemplates.appRadioGroup(), contains('MergeSemantics('));
    });
  });
}
