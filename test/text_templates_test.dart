import 'package:moarch/src/templates/ui/text_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('appTextButton', () {
    final output = TextTemplates.appTextButton();

    test('speaks the kit\'s vocabulary, plus the neutral role', () {
      // The four app roles are shared with AppButton and AppIconButton; neutral
      // is the addition, for the action offered without being urged.
      expect(
        output,
        contains(
            'enum AppTextButtonVariant { primary, secondary, tertiary, danger, neutral }'),
      );
      expect(output,
          contains('enum AppTextButtonType { plain, underlined, tonal }'));
      expect(output, contains('enum AppTextButtonShape { rounded, pill }'));
      expect(
          output, contains('enum AppTextButtonSize { small, medium, large }'));
    });

    test('the neutral variant follows the theme rather than a fixed grey', () {
      expect(
        output,
        contains('AppTextButtonVariant.neutral => (\n'
            '          theme.colorScheme.onSurface,'),
      );
    });

    test('only the tonal type paints anything behind the label', () {
      expect(
        output,
        contains('AppTextButtonType.plain || AppTextButtonType.underlined =>\n'
            '        Colors.transparent,'),
      );
    });

    test('the underlined type is the only one that rules its label', () {
      expect(
        output,
        contains('decoration: type == AppTextButtonType.underlined\n'
            '              ? TextDecoration.underline\n'
            '              : TextDecoration.none,'),
      );
    });

    test('a disabled button stays its variant, just faded', () {
      expect(output, contains('static const double _disabledOpacity = 0.38;'));
      expect(
        output,
        contains(
            'enabled ? accent : accent.withValues(alpha: _disabledOpacity)'),
      );
    });

    test('loading keeps the label\'s exact width', () {
      // A spinner sized to the icon would shrink the button and reflow the row
      // it sits in; stacking it over an invisible label cannot.
      expect(output, contains('Opacity(opacity: 0, child: content)'));
      expect(output, contains('Stack('));
    });

    test('dense trades the touch target away, and nothing else does', () {
      expect(output, contains('padding: dense ? EdgeInsets.zero'));
      expect(
          output,
          contains(
              'minimumSize: dense ? Size.zero : Size(0, sizeConfig.minHeight)'));
      expect(
        output,
        contains(
            'dense ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded'),
      );
    });

    test('a label wider than its room truncates instead of overflowing', () {
      expect(output, contains('overflow: TextOverflow.ellipsis,'));
      expect(output, contains('Flexible('));
    });
  });

  group('appRichText', () {
    final output = TextTemplates.appRichText();

    test('offers a color role per span, body text included', () {
      expect(
        output,
        contains(
            'enum AppSpanVariant { primary, secondary, tertiary, danger, neutral, muted }'),
      );
    });

    test('a span states only what it changes', () {
      // copyWith keeps the base value wherever the span passes null, and the
      // explicit `style` is merged last so it beats every shorthand.
      expect(output, contains('return base\n        .copyWith('));
      expect(output, contains('.merge(style);'));
      expect(output, contains('color: color ?? _variantColor(theme),'));
      expect(output, contains('fontSize: fontSize ?? scaled,'));
    });

    test('every style shorthand reaches the resolved TextStyle', () {
      for (final shorthand in [
        'fontWeight: weight,',
        'fontStyle: italic ? FontStyle.italic : null,',
        'decoration: decoration,',
        'backgroundColor: background,',
      ]) {
        expect(output, contains(shorthand), reason: '$shorthand is dropped');
      }
      // `scale` is the one that has to be resolved against the base size.
      expect(output,
          contains('final scaled = scale == null ? null : baseSize * scale!;'));
    });

    test('null variant leaves the surrounding color alone', () {
      expect(
          output,
          contains(
              'Color? _variantColor(ThemeData theme) => switch (variant) {\n        null => null,'));
    });

    test('recognizers outlive the frame that built them', () {
      // Rebuilding the recognizer on every build would dispose it under a
      // finger mid-press, and the press would be swallowed.
      expect(output, contains('class _SpanGesture {'));
      expect(output, contains('late final GestureRecognizer recognizer;'));
      expect(
          output,
          contains(
              '_SpanGesture _gestureAt(int index, _SpanGestureKind kind)'));
      expect(output, contains('void bind(VoidCallback? handler,'));
      // A span that swapped which gesture it wants needs the other type.
      expect(output, contains('if (existing.kind == kind) return existing;'));
    });

    test('every recognizer it makes, it disposes', () {
      expect(
          output,
          contains(
              '  void dispose() {\n    for (final gesture in _gestures) {\n      gesture.dispose();\n    }'));
      // Including the ones a now-shorter span list left behind.
      expect(output, contains('void _trimGestures(int used) {'));
      expect(output, contains('_gestures.removeLast().dispose();'));
    });

    test('uses only the recognizers a paragraph can turn into semantics', () {
      // RenderParagraph asserts on anything but a tap, a long press or a
      // double tap — a cleverer recognizer that reported both gestures at once
      // would render fine and then blow up the moment a screen reader is on.
      expect(output, contains('enum _SpanGestureKind { tap, longPress }'));
      expect(
          output,
          contains(
              '_SpanGestureKind.tap => TapGestureRecognizer()..onTap = _handleTap'));
      expect(
        output,
        contains('_SpanGestureKind.longPress => LongPressGestureRecognizer()\n'
            '        ..onLongPress = _handleLongPress,'),
      );
      expect(output, isNot(contains('MultiTapGestureRecognizer')));
    });

    test('a run wanting both gestures is promoted, not silently halved', () {
      // One TextSpan holds one recognizer, so the run becomes an inline widget
      // that can carry a GestureDetector instead.
      expect(output, contains('if (onTap != null && onLongPress != null) {'));
      expect(output, contains('alignment: PlaceholderAlignment.baseline,'));
      expect(output, contains('baseline: TextBaseline.alphabetic,'));
      expect(output, contains('_SpanGestureKind? get _gestureKind {'));
    });

    test('text spans are pressed through a recognizer, so they still wrap', () {
      // A GestureDetector needs a WidgetSpan, which cannot break across lines —
      // only the icon, widget and both-gesture spans pay that price.
      expect(output, contains('final kind = span._gestureKind;'));
      expect(output, contains('recognizer: recognizer,'));
      expect(output, contains('Widget _wrapGestures(Widget content,'));
    });

    test('a tappable span says so to the pointer and to a screen reader', () {
      expect(
        output,
        contains(
            'mouseCursor:\n          _isTappable ? SystemMouseCursors.click : MouseCursor.defer,'),
      );
      expect(output, contains('semanticsLabel: semanticsLabel,'));
      expect(output, contains('cursor: SystemMouseCursors.click,'));
    });

    test('selectable keeps the taps working', () {
      // SelectableText.rich would drop the recognizers; SelectionArea wraps.
      expect(output, contains('return SelectionArea(child: text);'));
      expect(output, isNot(contains('SelectableText.rich')));
    });

    test('has a constructor for each everyday span', () {
      for (final ctor in [
        'const AppSpan(\n    this.text,',
        'const AppSpan.bold(',
        'const AppSpan.link(',
        'const AppSpan.icon(',
        'const AppSpan.widget(',
        'static const AppSpan lineBreak',
      ]) {
        expect(output, contains(ctor), reason: '$ctor is missing');
      }
    });

    test('a link is underlined unless the design says otherwise', () {
      expect(
        output,
        contains(
            'decoration =\n            underline ? TextDecoration.underline : TextDecoration.none,'),
      );
    });

    test('template keeps a typo visible instead of eating the word', () {
      expect(output, contains('if (replacement == null) continue;'));
      expect(output, contains(r"RegExp(r'\{(\w+)\}')"));
      expect(
          output,
          contains(
              'static List<AppSpan> template(String pattern, Map<String, AppSpan> values) {'));
    });

    test('template keeps the text between and after the placeholders', () {
      expect(
          output,
          contains(
              'spans.add(AppSpan(pattern.substring(index, match.start)));'));
      expect(
        output,
        contains(
            'if (index < pattern.length) spans.add(AppSpan(pattern.substring(index)));'),
      );
    });

    test(
        'highlight matches case-insensitively by default, and survives an empty query',
        () {
      expect(output, contains('if (query.isEmpty) return [AppSpan(text)];'));
      expect(output, contains('bool caseSensitive = false,'));
      expect(
          output,
          contains(
              'final haystack = caseSensitive ? text : text.toLowerCase();'));
    });
  });

  group('appHeading', () {
    final output = TextTemplates.appHeading();

    test('offers a size, a color role and an alignment', () {
      expect(
        output,
        contains(
            'enum AppHeadingSize { display, large, medium, small, label }'),
      );
      // The kit's four roles, plus the two a heading actually needs: neutral
      // for structure, muted for the group label that stays in the background.
      expect(
        output,
        contains(
            'enum AppHeadingVariant { primary, secondary, tertiary, danger, neutral, muted }'),
      );
      expect(output, contains('enum AppHeadingAlign { start, center, end }'));
    });

    test('a heading is neutral until told otherwise', () {
      // Unlike a button, whose whole job is to be an accent.
      expect(output, contains('this.variant = AppHeadingVariant.neutral,'));
      expect(output, contains('this.size = AppHeadingSize.medium,'));
      expect(output, contains('this.align = AppHeadingAlign.start,'));
    });

    test('every size comes off a theme role, not a bare TextStyle', () {
      // So the app's font family and any theme-level tweak survive; the size
      // metrics land on top with copyWith.
      expect(
          output,
          contains(
              'TextStyle? _baseStyle(TextTheme textTheme) => switch (size)'));
      for (final role in [
        'AppHeadingSize.display => textTheme.headlineLarge,',
        'AppHeadingSize.large => textTheme.headlineMedium,',
        'AppHeadingSize.medium => textTheme.titleLarge,',
        'AppHeadingSize.small => textTheme.titleMedium,',
        'AppHeadingSize.label => textTheme.labelSmall,',
      ]) {
        expect(output, contains(role), reason: '$role is missing');
      }
    });

    test('only the label size capitalizes, and caps can be forced either way',
        () {
      expect(output, contains('final caps = uppercase ?? config.uppercase;'));
      expect(output, contains('caps ? title.toUpperCase() : title,'));
    });

    test('caps always get tracking, whatever size asked for them', () {
      // Uppercase set at the display size' spacing reads cramped.
      expect(output, contains('static const double _capsLetterSpacing = 0.8;'));
      expect(
        output,
        contains(
            'letterSpacing: caps && config.letterSpacing < _capsLetterSpacing\n'
            '          ? _capsLetterSpacing\n'
            '          : config.letterSpacing,'),
      );
    });

    test('align moves the title and the subtitle together', () {
      expect(output, contains('TextAlign get _textAlign => switch (align)'));
      expect(output,
          contains('CrossAxisAlignment get _crossAlign => switch (align)'));
      // And it can only act because the heading claims the full width.
      expect(
          output, contains('SizedBox(width: double.infinity, child: content)'));
    });

    test('the subtitle stays quiet whatever the variant says', () {
      expect(
        output,
        contains('color: subtitleColor ?? theme.colorScheme.onSurfaceVariant,'),
      );
    });

    test('a capped title ellipsizes, an uncapped one is left alone', () {
      // overflow: ellipsis with a null maxLines clips mid-word on one line.
      expect(
        output,
        contains('overflow: maxLines == null ? null : TextOverflow.ellipsis,'),
      );
    });

    test('a long title next to an icon truncates instead of overflowing', () {
      expect(output, contains('Flexible(child: titleLine),'));
    });

    test('it is announced as a heading, not as more text', () {
      expect(output, contains('return Semantics(\n      header: true,'));
    });
  });

  group('the catalog carries all three', () {
    test('each is registered under the category it belongs to', () {
      final textButton = WidgetCatalog.byName('text-button');
      expect(textButton, isNotNull);
      expect(textButton!.title, 'AppTextButton');
      expect(textButton.file, 'buttons/app_text_button.dart');
      expect(textButton.category, 'Buttons & icons');

      final richText = WidgetCatalog.byName('rich-text');
      expect(richText, isNotNull);
      expect(richText!.title, 'AppRichText');
      expect(richText.file, 'text/app_rich_text.dart');
      expect(richText.category, 'Layout & content');

      final heading = WidgetCatalog.byName('heading');
      expect(heading, isNotNull);
      expect(heading!.title, 'AppHeading');
      expect(heading.file, 'text/app_heading.dart');
      expect(heading.category, 'Layout & content');
    });

    test('none needs a package or the router', () {
      for (final name in ['text-button', 'rich-text', 'heading']) {
        final spec = WidgetCatalog.byName(name)!;
        expect(spec.packages, isEmpty);
        expect(spec.needsRouter, isFalse);
        expect(spec.deps, isEmpty, reason: '$name should stand on its own');
      }
    });
  });
}
