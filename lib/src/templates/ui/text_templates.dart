/// Templates for the text widgets: the heading that titles what follows it,
/// the low-emphasis text action, and the paragraph whose parts are styled —
/// and tapped — one span at a time.
abstract final class TextTemplates {
  /// Returns the generated appTextButton template.
  static String appTextButton() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Color role of [AppTextButton] — what the action is about, not how it is
/// drawn. Mirrors [AppButtonVariant].
///
/// [neutral] follows the theme's `onSurface`, for actions that are offered
/// without being urged: "Skip", "Not now", "Cancel".
enum AppTextButtonVariant { primary, secondary, tertiary, danger, neutral }

/// How the [AppTextButtonVariant] color is applied. Orthogonal to variant and
/// size — any combination works.
///
/// - [plain]: bare colored label, the quietest.
/// - [underlined]: the inline-link look, for an action inside a sentence —
///   pair it with `bare: true` to drop the button box around it.
/// - [tonal]: label on a soft tinted pill, findable at a glance.
enum AppTextButtonType { plain, underlined, tonal }

/// Corner shape of the [AppTextButtonType.tonal] pill. Ignored by the other
/// two types, which paint no container to shape.
enum AppTextButtonShape { rounded, pill }

enum AppTextButtonSize { small, medium, large }

typedef _TextButtonSizeConfig = ({
  double fontSize,
  double iconSize,
  double minHeight,
  EdgeInsets padding,
});

/// A text-first action: the label *is* the button. [AppButton]'s quiet
/// sibling, for the choice that shouldn't compete with the screen's main one.
///
/// ```dart
/// AppTextButton(
///   label: 'Forgot password?',
///   variant: AppTextButtonVariant.primary,
///   type: AppTextButtonType.underlined,
///   bare: true,
///   alignment: Alignment.centerRight,
///   onPressed: () => context.push('/reset'),
/// )
/// ```
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppTextButtonVariant.primary,
    this.type = AppTextButtonType.plain,
    this.shape = AppTextButtonShape.rounded,
    this.size = AppTextButtonSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.color,
    this.fontWeight,
    this.maxLines = 1,
    this.expand = false,
    this.alignment,
    this.dense = false,
    this.bare = false,
    this.tooltip,
  });

  final String label;

  /// Tap handler. Pass null to render the button in its disabled state.
  final VoidCallback? onPressed;
  final AppTextButtonVariant variant;
  final AppTextButtonType type;

  /// Only read by [AppTextButtonType.tonal] — the other types have no
  /// container to shape.
  final AppTextButtonShape shape;
  final AppTextButtonSize size;
  final IconData? prefixIcon;
  final IconData? suffixIcon;

  /// Replaces the label with a spinner and ignores taps. The button keeps the
  /// exact width the label gave it, so a row of actions doesn't reflow.
  final bool isLoading;

  /// Overrides [variant]'s color — the escape hatch for a tint the variant
  /// vocabulary doesn't name.
  final Color? color;

  /// Defaults to semi-bold, which is what keeps a bare label reading as
  /// something tappable rather than as more text.
  final FontWeight? fontWeight;

  /// Lines the label may wrap onto before it ellipsizes. One by default.
  final int maxLines;

  /// Stretches the button across its parent. Off by default: a text action
  /// normally takes only the room its label needs.
  final bool expand;

  /// Where the label sits. Setting it also gives the button the parent's width
  /// to align inside of, so `Alignment.centerRight` puts the label on the right
  /// of the row or column it sits in rather than only inside its own box.
  /// Defaults to centered.
  final Alignment? alignment;

  /// Drops the 48dp touch target and the padding, for an action that has to
  /// sit tight against something else. Keep it for already-tappable rows.
  final bool dense;

  /// Drops the button itself — no padding, no minimum size, no ripple, no
  /// container — leaving the label and its tap handler. What an underlined
  /// link needs to sit inline with the text around it, where a button's box
  /// would show. Makes [dense], [shape] and the [AppTextButtonType.tonal] fill
  /// moot: there is nothing left to pad, shape or paint.
  final bool bare;

  /// Long-press label. Worth setting when the label is abbreviated by
  /// [maxLines] on a narrow screen.
  final String? tooltip;

  static const double _tonalFillOpacity = 0.12;
  static const double _disabledOpacity = 0.38;
  static const FontWeight _defaultWeight = FontWeight.w600;

  _TextButtonSizeConfig _sizeConfig() => switch (size) {
        AppTextButtonSize.small => (
            fontSize: AppConstants.fontSize13,
            iconSize: 16.0,
            minHeight: 32.0,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space8,
              vertical: AppConstants.space4,
            ),
          ),
        AppTextButtonSize.medium => (
            fontSize: AppConstants.fontSize15,
            iconSize: 18.0,
            minHeight: 40.0,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space12,
              vertical: AppConstants.space8,
            ),
          ),
        AppTextButtonSize.large => (
            fontSize: AppConstants.fontSize17,
            iconSize: 20.0,
            minHeight: AppConstants.touchTarget,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space16,
              vertical: AppConstants.space12,
            ),
          ),
      };

  /// The variant's color, plus the color that reads on top of it. Single
  /// source for every color the button paints.
  (Color, Color) _colorsOf(ThemeData theme) {
    final override = color;
    if (override != null) {
      // No colorScheme pair exists for an arbitrary color, so pick whichever
      // of black/white keeps a tonal fill legible.
      return (
        override,
        ThemeData.estimateBrightnessForColor(override) == Brightness.dark
            ? Colors.white
            : Colors.black,
      );
    }
    return switch (variant) {
      AppTextButtonVariant.primary => (
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary,
        ),
      AppTextButtonVariant.secondary => (
          theme.colorScheme.secondary,
          theme.colorScheme.onSecondary,
        ),
      AppTextButtonVariant.tertiary => (
          theme.colorScheme.tertiary,
          theme.colorScheme.onTertiary,
        ),
      AppTextButtonVariant.danger => (
          theme.colorScheme.error,
          theme.colorScheme.onError,
        ),
      AppTextButtonVariant.neutral => (
          theme.colorScheme.onSurface,
          theme.colorScheme.surface,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final sizeConfig = _sizeConfig();
    final (accent, _) = _colorsOf(theme);
    final enabled = onPressed != null && !isLoading;

    // Variant chooses the color; type only decides how that color is applied.
    // Only the tonal type paints anything behind the label.
    final background = switch (type) {
      AppTextButtonType.tonal => Color.alphaBlend(
          accent.withValues(alpha: _tonalFillOpacity),
          theme.colorScheme.surface,
        ),
      AppTextButtonType.plain || AppTextButtonType.underlined =>
        Colors.transparent,
    };

    // A disabled button stays its variant, just faded — never a generic grey.
    final foreground =
        enabled ? accent : accent.withValues(alpha: _disabledOpacity);
    final resolvedBackground = enabled
        ? background
        : background.withValues(alpha: _disabledOpacity);

    final textStyle = theme.textTheme.labelLarge?.copyWith(
          color: foreground,
          fontSize: sizeConfig.fontSize,
          fontWeight: fontWeight ?? _defaultWeight,
          decoration: type == AppTextButtonType.underlined
              ? TextDecoration.underline
              : TextDecoration.none,
        ) ??
        TextStyle(
          color: foreground,
          fontSize: sizeConfig.fontSize,
          fontWeight: fontWeight ?? _defaultWeight,
        );

    // The alignment has to reach the row and the label too: a row that always
    // centers, holding a label that always centers, pins the text to the middle
    // of a stretched button whatever the button's own alignment says.
    final resolvedAlignment = alignment ?? Alignment.center;
    final (rowAlignment, textAlign) = switch (resolvedAlignment.x) {
      < 0 => (MainAxisAlignment.start, TextAlign.left),
      > 0 => (MainAxisAlignment.end, TextAlign.right),
      _ => (MainAxisAlignment.center, TextAlign.center),
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: rowAlignment,
      children: [
        if (prefixIcon != null) ...[
          Icon(prefixIcon, size: sizeConfig.iconSize, color: foreground),
          const SizedBox(width: AppConstants.space4),
        ],
        // Flexible + ellipsis so a label wider than the room it is given
        // truncates instead of overflowing the row it sits in.
        Flexible(
          child: Text(
            label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: textStyle,
          ),
        ),
        if (suffixIcon != null) ...[
          const SizedBox(width: AppConstants.space4),
          Icon(suffixIcon, size: sizeConfig.iconSize, color: foreground),
        ],
      ],
    );

    final handleTap = enabled
        ? () {
            HapticFeedback.selectionClick();
            onPressed!();
          }
        : null;

    final child = isLoading
        // Stacked under a transparent copy of the label so the button keeps
        // the exact width it had, and the row around it doesn't jump.
        ? Stack(
            alignment: resolvedAlignment,
            children: [
              Opacity(opacity: 0, child: content),
              SizedBox.square(
                dimension: sizeConfig.iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              ),
            ],
          )
        : content;

    // Nothing around the label: no padding to fake away, no minimum size, no
    // ripple, no shape — the label is the whole widget, and the tap is on it.
    if (bare) {
      final bareButton = MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          // Only the label takes the tap. An opaque box would take the whole
          // width a stretched parent hands down, so a tap far to the side of a
          // short link would still fire it.
          behavior: HitTestBehavior.deferToChild,
          onTap: handleTap,
          child: child,
        ),
      );
      return _wrap(bareButton);
    }

    final button = TextButton(
      onPressed: handleTap,
      style: TextButton.styleFrom(
        backgroundColor: resolvedBackground,
        disabledBackgroundColor: resolvedBackground,
        foregroundColor: foreground,
        disabledForegroundColor: foreground,
        padding: dense ? EdgeInsets.zero : sizeConfig.padding,
        alignment: resolvedAlignment,
        // A dense button gives up its 48dp target for the layout's sake; every
        // other one keeps a target a finger can actually land on.
        minimumSize: dense ? Size.zero : Size(0, sizeConfig.minHeight),
        tapTargetSize:
            dense ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(
          borderRadius: switch (shape) {
            AppTextButtonShape.rounded => AppConstants.borderRadius8,
            AppTextButtonShape.pill => AppConstants.borderRadiusFull,
          },
        ),
      ),
      child: child,
    );

    return _wrap(button);
  }

  /// Gives [button] the width [expand] and [alignment] ask for, then the
  /// tooltip. Shared by the bare label and the real button.
  Widget _wrap(Widget button) {
    final sized =
        expand ? SizedBox(width: double.infinity, child: button) : button;
    // A button only as wide as its label has nothing to align inside of, so an
    // alignment claims the width the parent offers to align against. In an
    // unbounded parent — a Row, a scrolling Column — Align shrink-wraps, so
    // this costs nothing where there is no room to move into.
    final aligned = alignment != null && !expand
        ? Align(alignment: alignment!, child: sized)
        : sized;
    if (tooltip == null) return aligned;
    return Tooltip(message: tooltip!, child: aligned);
  }
}
''';

  /// Returns the generated appRichText template.
  static String appRichText() => r'''
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Color role of one [AppSpan] — the four app roles plus [neutral] for body
/// text and [muted] for what is said more quietly. Null inherits.
enum AppSpanVariant { primary, secondary, tertiary, danger, neutral, muted }

/// One run inside an [AppRichText]: its text, its style, and its tap handler.
///
/// Style is layered, each beating the last: the paragraph's base style, then
/// [variant], then the shorthands, then [color], then [style]. Null inherits,
/// so a span only states what it changes.
///
/// ```dart
/// AppRichText(
///   spans: [
///     const AppSpan('By continuing you agree to our '),
///     AppSpan.link('Terms', onTap: () => context.push('/terms')),
///     const AppSpan(' and '),
///     AppSpan.link('Privacy Policy', onTap: () => context.push('/privacy')),
///     const AppSpan('.'),
///   ],
/// )
/// ```
@immutable
class AppSpan {
  /// A run of plain text, styled by whichever of the arguments you pass.
  const AppSpan(
    this.text, {
    this.style,
    this.variant,
    this.color,
    this.weight,
    this.italic = false,
    this.fontSize,
    this.scale,
    this.decoration,
    this.background,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
  })  : icon = null,
        child = null;

  /// A run set in bold — the emphasized name, figure or date inside a sentence.
  const AppSpan.bold(
    this.text, {
    this.style,
    this.variant,
    this.color,
    this.italic = false,
    this.fontSize,
    this.scale,
    this.decoration,
    this.background,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
  })  : weight = FontWeight.w700,
        icon = null,
        child = null;

  /// A tappable run: variant-colored and underlined, recognizer and cursor
  /// handled for you. Pass `underline: false` to color links instead.
  const AppSpan.link(
    this.text, {
    required this.onTap,
    bool underline = true,
    this.variant = AppSpanVariant.primary,
    this.style,
    this.color,
    this.weight = FontWeight.w600,
    this.italic = false,
    this.fontSize,
    this.scale,
    this.background,
    this.onLongPress,
    this.semanticsLabel,
  })  : decoration =
            underline ? TextDecoration.underline : TextDecoration.none,
        icon = null,
        child = null;

  /// An icon sitting on the text baseline's line box, sized off the text around
  /// it — the arrow after "Learn more", the lock before a private note.
  const AppSpan.icon(
    this.icon, {
    this.style,
    this.variant,
    this.color,
    this.fontSize,
    this.scale,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
  })  : text = null,
        child = null,
        weight = null,
        italic = false,
        decoration = null,
        background = null;

  /// Any widget, inline in the paragraph — a chip, an avatar, a countdown.
  /// The escape hatch for the part that isn't text at all.
  const AppSpan.widget(
    this.child, {
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
  })  : text = null,
        icon = null,
        style = null,
        variant = null,
        color = null,
        weight = null,
        italic = false,
        fontSize = null,
        scale = null,
        decoration = null,
        background = null;

  /// A hard line break, for the sentence that has to start on its own line.
  static const AppSpan lineBreak = AppSpan('\n');

  /// The run's text. Null on the icon and widget spans.
  final String? text;

  /// Drawn inline instead of [text], by [AppSpan.icon].
  final IconData? icon;

  /// Drawn inline instead of [text], by [AppSpan.widget].
  final Widget? child;

  /// Merged last, over everything else — for what the shorthands don't name
  /// (a font family, letter spacing, a shadow).
  final TextStyle? style;

  /// Color role. Null keeps the surrounding text's color.
  final AppSpanVariant? variant;

  /// An exact color, beating [variant].
  final Color? color;

  final FontWeight? weight;
  final bool italic;

  /// An exact size in logical pixels, beating [scale].
  final double? fontSize;

  /// A multiple of the paragraph's size — `1.4` for a figure that has to be
  /// larger than the words around it, without hard-coding a size.
  final double? scale;

  final TextDecoration? decoration;

  /// Painted behind the run — the highlight over a search match.
  final Color? background;

  /// Tap handler. [AppRichText] owns the recognizer's whole lifecycle, and a
  /// tappable span is announced as a link to a screen reader.
  final VoidCallback? onTap;

  /// Long-press handler — "hold to copy".
  ///
  /// A [TextSpan] carries one recognizer, so a run wanting *both* gestures is
  /// drawn as an inline widget and no longer breaks across lines. Keep those
  /// spans short.
  final VoidCallback? onLongPress;

  /// What a screen reader says instead of [text] — for a run that reads as
  /// something else out loud ("€1,240.00" said as "one thousand…").
  final String? semanticsLabel;

  bool get _isTappable => onTap != null || onLongPress != null;

  /// The recognizer this run needs, or null when it needs none — because it is
  /// not tappable, because it is drawn as an inline widget ([AppSpan.icon],
  /// [AppSpan.widget]), or because it wants both gestures and so is promoted to
  /// one.
  _SpanGestureKind? get _gestureKind {
    if (text == null) return null;
    if (onTap != null && onLongPress != null) return null;
    if (onTap != null) return _SpanGestureKind.tap;
    if (onLongPress != null) return _SpanGestureKind.longPress;
    return null;
  }

  static final RegExp _placeholder = RegExp(r'\{(\w+)\}');

  /// Fills `{name}` placeholders in [pattern] with the spans in [values], and
  /// wraps everything between them in plain spans.
  ///
  /// The one way to build a styled sentence that survives translation — the
  /// translator moves `{terms}` and the link goes with it, where concatenating
  /// spans by hand pins English word order into the layout. An unknown key is
  /// left as literal text, so a typo shows up rather than dropping a word.
  ///
  /// ```dart
  /// AppRichText(
  ///   spans: AppSpan.template(
  ///     context.l10n.agreeToTerms, // 'By continuing you accept the {terms}.'
  ///     {'terms': AppSpan.link('Terms', onTap: _openTerms)},
  ///   ),
  /// )
  /// ```
  static List<AppSpan> template(String pattern, Map<String, AppSpan> values) {
    final spans = <AppSpan>[];
    var index = 0;
    for (final match in _placeholder.allMatches(pattern)) {
      final replacement = values[match.group(1)];
      if (replacement == null) continue;
      if (match.start > index) {
        spans.add(AppSpan(pattern.substring(index, match.start)));
      }
      spans.add(replacement);
      index = match.end;
    }
    if (index < pattern.length) spans.add(AppSpan(pattern.substring(index)));
    return spans;
  }

  /// Splits [text] so that every occurrence of [query] is its own emphasized
  /// span — the search result with the typed words picked out of it.
  ///
  /// ```dart
  /// AppRichText(spans: AppSpan.highlight(result.title, query: _query))
  /// ```
  static List<AppSpan> highlight(
    String text, {
    required String query,
    AppSpanVariant variant = AppSpanVariant.primary,
    FontWeight weight = FontWeight.w700,
    Color? background,
    bool caseSensitive = false,
  }) {
    if (query.isEmpty) return [AppSpan(text)];
    final haystack = caseSensitive ? text : text.toLowerCase();
    final needle = caseSensitive ? query : query.toLowerCase();
    final spans = <AppSpan>[];
    var index = 0;
    while (true) {
      final found = haystack.indexOf(needle, index);
      if (found < 0) break;
      if (found > index) spans.add(AppSpan(text.substring(index, found)));
      spans.add(
        AppSpan(
          text.substring(found, found + needle.length),
          variant: variant,
          weight: weight,
          background: background,
        ),
      );
      index = found + needle.length;
    }
    if (index < text.length) spans.add(AppSpan(text.substring(index)));
    return spans;
  }

  Color? _variantColor(ThemeData theme) => switch (variant) {
        null => null,
        AppSpanVariant.primary => theme.colorScheme.primary,
        AppSpanVariant.secondary => theme.colorScheme.secondary,
        AppSpanVariant.tertiary => theme.colorScheme.tertiary,
        AppSpanVariant.danger => theme.colorScheme.error,
        AppSpanVariant.neutral => theme.colorScheme.onSurface,
        AppSpanVariant.muted => theme.colorScheme.onSurfaceVariant,
      };

  /// The run's own style, resolved against the paragraph's [base]. `copyWith`
  /// keeps [base]'s value wherever this span passes null, which is what lets a
  /// span state only what it changes.
  TextStyle _resolveStyle(TextStyle base, ThemeData theme) {
    final baseSize = base.fontSize ?? AppConstants.fontSize14;
    final scaled = scale == null ? null : baseSize * scale!;
    return base
        .copyWith(
          color: color ?? _variantColor(theme),
          fontWeight: weight,
          fontStyle: italic ? FontStyle.italic : null,
          fontSize: fontSize ?? scaled,
          decoration: decoration,
          backgroundColor: background,
        )
        .merge(style);
  }

  /// Wraps an inline widget in the gestures it asked for. Only the icon and
  /// widget spans come through here — a text run is tapped through its
  /// recognizer instead, so that it can still wrap across lines.
  Widget _wrapGestures(Widget content, {required bool haptics}) {
    if (!_isTappable) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                if (haptics) HapticFeedback.selectionClick();
                onTap!();
              },
        onLongPress: onLongPress == null
            ? null
            : () {
                if (haptics) HapticFeedback.mediumImpact();
                onLongPress!();
              },
        child: content,
      ),
    );
  }

  InlineSpan _toInlineSpan({
    required TextStyle base,
    required ThemeData theme,
    required bool haptics,
    GestureRecognizer? recognizer,
  }) {
    final resolved = _resolveStyle(base, theme);

    final inlineChild = child;
    if (inlineChild != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _wrapGestures(inlineChild, haptics: haptics),
      );
    }

    final inlineIcon = icon;
    if (inlineIcon != null) {
      final size = (resolved.fontSize ?? AppConstants.fontSize14) * _iconScale;
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _wrapGestures(
          Icon(inlineIcon, size: size, color: resolved.color),
          haptics: haptics,
        ),
      );
    }

    // A TextSpan holds one recognizer, so a run wanting both a tap and a long
    // press is drawn as an inline widget — which cannot break across lines.
    // Baseline-aligned so it still sits on the line of the words around it.
    if (onTap != null && onLongPress != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _wrapGestures(Text(text!, style: resolved), haptics: haptics),
      );
    }

    return TextSpan(
      text: text,
      style: resolved,
      semanticsLabel: semanticsLabel,
      recognizer: recognizer,
      mouseCursor:
          _isTappable ? SystemMouseCursors.click : MouseCursor.defer,
    );
  }

  /// An inline icon reads as part of the sentence at a shade above the text
  /// size, not at it — glyphs sit inside their em box, icons fill theirs.
  static const double _iconScale = 1.15;
}

/// A paragraph whose parts are styled, and tapped, one at a time.
///
/// It owns the [TextSpan] tree and the gesture recognizers a tappable span
/// needs — the reason tappable text normally drags a StatefulWidget with it.
///
/// ```dart
/// AppRichText(
///   style: context.theme.textTheme.bodyLarge,
///   spans: [
///     const AppSpan('Signed in as '),
///     AppSpan.bold(user.email, variant: AppSpanVariant.neutral),
///     const AppSpan(' · '),
///     AppSpan.link('Switch account', onTap: _switchAccount),
///   ],
/// )
/// ```
class AppRichText extends StatefulWidget {
  const AppRichText({
    super.key,
    required this.spans,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
    this.selectable = false,
    this.haptics = true,
  });

  /// The runs, in reading order. Each one carries its own style and its own
  /// tap handler; see [AppSpan].
  final List<AppSpan> spans;

  /// The style every span starts from. Defaults to the theme's `bodyMedium`.
  final TextStyle? style;

  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;

  /// Lets the text be selected and copied. Tappable spans keep working — the
  /// paragraph is wrapped in a [SelectionArea] rather than swapped for a
  /// SelectableText, which would drop the recognizers.
  final bool selectable;

  /// Buzzes when a span is tapped, the way the rest of the kit's controls do.
  /// Turn it off for text that is tapped often enough for that to nag.
  final bool haptics;

  @override
  State<AppRichText> createState() => _AppRichTextState();
}

class _AppRichTextState extends State<AppRichText> {
  /// One entry per tappable text span, in order. Kept across rebuilds rather
  /// than rebuilt with the span list — see [_SpanGesture].
  final List<_SpanGesture> _gestures = [];

  @override
  void dispose() {
    for (final gesture in _gestures) {
      gesture.dispose();
    }
    _gestures.clear();
    super.dispose();
  }

  /// The gesture at [index], created on first use. A span that changed which
  /// gesture it wants gets a new recognizer, since the two are different types.
  _SpanGesture _gestureAt(int index, _SpanGestureKind kind) {
    while (_gestures.length <= index) {
      _gestures.add(_SpanGesture(kind));
    }
    final existing = _gestures[index];
    if (existing.kind == kind) return existing;
    existing.dispose();
    return _gestures[index] = _SpanGesture(kind);
  }

  /// Drops the recognizers left over from a longer span list.
  void _trimGestures(int used) {
    while (_gestures.length > used) {
      _gestures.removeLast().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final base = widget.style ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: AppConstants.fontSize14);

    final children = <InlineSpan>[];
    var gestureIndex = 0;
    for (final span in widget.spans) {
      // Only text runs are driven by a recognizer. An icon span, a widget span
      // and a run that wants both gestures are drawn as inline widgets, and
      // carry their own GestureDetector instead.
      GestureRecognizer? recognizer;
      final kind = span._gestureKind;
      if (kind != null) {
        final gesture = _gestureAt(gestureIndex++, kind)
          ..bind(
            span.onTap ?? span.onLongPress,
            haptics: widget.haptics,
          );
        recognizer = gesture.recognizer;
      }
      children.add(
        span._toInlineSpan(
          base: base,
          theme: theme,
          haptics: widget.haptics,
          recognizer: recognizer,
        ),
      );
    }
    _trimGestures(gestureIndex);

    final text = Text.rich(
      TextSpan(style: base, children: children),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );

    if (!widget.selectable) return text;
    return SelectionArea(child: text);
  }
}

/// Which recognizer a text run is driven by.
///
/// Only these two, plus a double tap, are recognizers a [TextSpan] can carry:
/// they are the ones `RenderParagraph` knows how to turn into semantics, so a
/// screen reader announces the run as a link, or as long-pressable. Anything
/// else is rejected outright in debug.
enum _SpanGestureKind { tap, longPress }

/// One tappable span's gesture wiring.
///
/// The recognizer is built once and only its callback is repointed on rebuild.
/// Rebuilding the recognizer itself would work until the paragraph rebuilt
/// mid-press — a form rebuilding on every keystroke, a stream ticking — at
/// which point the recognizer under the finger would be disposed and the press
/// swallowed.
class _SpanGesture {
  _SpanGesture(this.kind) {
    recognizer = switch (kind) {
      _SpanGestureKind.tap => TapGestureRecognizer()..onTap = _handleTap,
      _SpanGestureKind.longPress => LongPressGestureRecognizer()
        ..onLongPress = _handleLongPress,
    };
  }

  final _SpanGestureKind kind;
  late final GestureRecognizer recognizer;

  VoidCallback? _handler;
  bool _haptics = true;

  void bind(VoidCallback? handler, {required bool haptics}) {
    _handler = handler;
    _haptics = haptics;
  }

  void _handleTap() {
    final handler = _handler;
    if (handler == null) return;
    if (_haptics) HapticFeedback.selectionClick();
    handler();
  }

  void _handleLongPress() {
    final handler = _handler;
    if (handler == null) return;
    if (_haptics) HapticFeedback.mediumImpact();
    handler();
  }

  void dispose() => recognizer.dispose();
}
''';

  /// Returns the generated appHeading template.
  static String appHeading() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Visual weight of an [AppHeading] — how much of the screen the title claims.
///
/// - [display]: the screen's own title, hero-sized.
/// - [large]: a major section that opens a new context.
/// - [medium]: the everyday heading above a list or a form block.
/// - [small]: a sub-heading inside a section.
/// - [label]: the small uppercased eyebrow over a settings group.
enum AppHeadingSize { display, large, medium, small, label }

/// Color role of an [AppHeading] — the kit's four roles, plus [neutral] for
/// the default `onSurface` (a heading is structure, not accent) and [muted]
/// for the group label that should stay in the background.
enum AppHeadingVariant { primary, secondary, tertiary, danger, neutral, muted }

/// Where the heading sits in the width it is given. Moves the title, the
/// subtitle and the icon together.
enum AppHeadingAlign { start, center, end }

typedef _HeadingSizeConfig = ({
  double fontSize,
  double subtitleSize,
  FontWeight weight,
  double letterSpacing,
  bool uppercase,
});

/// The title before a thing — a page, a list, a settings group, a form block.
///
/// Typography only, announced as a header to screen readers. For the header
/// *row* with a "See all" action there is [AppSectionHeader]; for the
/// screen's chrome, [AppAppBar].
///
/// ```dart
/// AppHeading(title: 'Settings', size: AppHeadingSize.large),
/// // ...
/// AppHeading(
///   title: 'Notifications',
///   size: AppHeadingSize.label,
///   variant: AppHeadingVariant.muted,
/// ),
/// AppListTile(...),
/// ```
class AppHeading extends StatelessWidget {
  const AppHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.size = AppHeadingSize.medium,
    this.variant = AppHeadingVariant.neutral,
    this.align = AppHeadingAlign.start,
    this.icon,
    this.trailing,
    this.color,
    this.subtitleColor,
    this.weight,
    this.uppercase,
    this.maxLines,
    this.divider = false,
    this.padding = const EdgeInsets.symmetric(vertical: AppConstants.space8),
  });

  final String title;

  /// Supporting line under the title. Quiet whatever the [variant] says —
  /// only [subtitleColor] changes it.
  final String? subtitle;

  final AppHeadingSize size;
  final AppHeadingVariant variant;

  /// The heading takes the full width it is offered, so [AppHeadingAlign.center]
  /// and [AppHeadingAlign.end] always have room to act.
  final AppHeadingAlign align;

  /// Leading icon, sized to the title and painted its color.
  final IconData? icon;

  /// Anything that belongs on the heading's right edge — an [AppIconButton],
  /// a tag, a count. The title column keeps the rest of the width.
  final Widget? trailing;

  /// Overrides [variant]'s color — the escape hatch for a tint the variant
  /// vocabulary doesn't name.
  final Color? color;

  /// Overrides the subtitle's `onSurfaceVariant`.
  final Color? subtitleColor;

  /// Overrides [size]'s weight.
  final FontWeight? weight;

  /// Null follows [size]: only [AppHeadingSize.label] capitalizes. Set it to
  /// force either look at any size — caps bring letter spacing with them.
  final bool? uppercase;

  /// Lines the title may take before it ellipsizes. Unlimited by default.
  final int? maxLines;

  /// Draws a hairline rule under the heading — the settings-page way of
  /// marking where a group starts.
  final bool divider;

  final EdgeInsetsGeometry padding;

  /// Uppercase without tracking reads cramped, so caps at any size get at
  /// least the label size's spacing.
  static const double _capsLetterSpacing = 0.8;

  /// An icon next to text is drawn a shade larger than the glyphs — they sit
  /// inside their em box while the icon fills its own.
  static const double _iconScale = 1.15;

  _HeadingSizeConfig _sizeConfig() => switch (size) {
        AppHeadingSize.display => (
            fontSize: AppConstants.fontSize34,
            subtitleSize: AppConstants.fontSize16,
            weight: FontWeight.w700,
            letterSpacing: -0.5,
            uppercase: false,
          ),
        AppHeadingSize.large => (
            fontSize: AppConstants.fontSize28,
            subtitleSize: AppConstants.fontSize15,
            weight: FontWeight.w700,
            letterSpacing: -0.25,
            uppercase: false,
          ),
        AppHeadingSize.medium => (
            fontSize: AppConstants.fontSize22,
            subtitleSize: AppConstants.fontSize14,
            weight: FontWeight.w600,
            letterSpacing: 0,
            uppercase: false,
          ),
        AppHeadingSize.small => (
            fontSize: AppConstants.fontSize17,
            subtitleSize: AppConstants.fontSize13,
            weight: FontWeight.w600,
            letterSpacing: 0,
            uppercase: false,
          ),
        AppHeadingSize.label => (
            fontSize: AppConstants.fontSize13,
            subtitleSize: AppConstants.fontSize12,
            weight: FontWeight.w600,
            letterSpacing: _capsLetterSpacing,
            uppercase: true,
          ),
      };

  /// The theme role each size starts from, so the app's font family and any
  /// theme-level tweaks flow through before the size metrics land on top.
  TextStyle? _baseStyle(TextTheme textTheme) => switch (size) {
        AppHeadingSize.display => textTheme.headlineLarge,
        AppHeadingSize.large => textTheme.headlineMedium,
        AppHeadingSize.medium => textTheme.titleLarge,
        AppHeadingSize.small => textTheme.titleMedium,
        AppHeadingSize.label => textTheme.labelSmall,
      };

  Color _variantColor(ThemeData theme) => switch (variant) {
        AppHeadingVariant.primary => theme.colorScheme.primary,
        AppHeadingVariant.secondary => theme.colorScheme.secondary,
        AppHeadingVariant.tertiary => theme.colorScheme.tertiary,
        AppHeadingVariant.danger => theme.colorScheme.error,
        AppHeadingVariant.neutral => theme.colorScheme.onSurface,
        AppHeadingVariant.muted => theme.colorScheme.onSurfaceVariant,
      };

  TextAlign get _textAlign => switch (align) {
        AppHeadingAlign.start => TextAlign.start,
        AppHeadingAlign.center => TextAlign.center,
        AppHeadingAlign.end => TextAlign.end,
      };

  CrossAxisAlignment get _crossAlign => switch (align) {
        AppHeadingAlign.start => CrossAxisAlignment.start,
        AppHeadingAlign.center => CrossAxisAlignment.center,
        AppHeadingAlign.end => CrossAxisAlignment.end,
      };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final config = _sizeConfig();
    final accent = color ?? _variantColor(theme);
    final caps = uppercase ?? config.uppercase;

    final titleStyle =
        (_baseStyle(theme.textTheme) ?? const TextStyle()).copyWith(
      color: accent,
      fontSize: config.fontSize,
      fontWeight: weight ?? config.weight,
      letterSpacing: caps && config.letterSpacing < _capsLetterSpacing
          ? _capsLetterSpacing
          : config.letterSpacing,
    );

    Widget titleLine = Text(
      caps ? title.toUpperCase() : title,
      textAlign: _textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: titleStyle,
    );
    if (icon != null) {
      titleLine = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: config.fontSize * _iconScale, color: accent),
          const SizedBox(width: AppConstants.space8),
          Flexible(child: titleLine),
        ],
      );
    }

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _crossAlign,
      children: [
        titleLine,
        if (subtitle != null) ...[
          const SizedBox(height: AppConstants.space4),
          Text(
            subtitle!,
            textAlign: _textAlign,
            style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
              color: subtitleColor ?? theme.colorScheme.onSurfaceVariant,
              fontSize: config.subtitleSize,
            ),
          ),
        ],
      ],
    );

    if (trailing != null) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: content),
          const SizedBox(width: AppConstants.space8),
          trailing!,
        ],
      );
    }

    if (divider) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          const SizedBox(height: AppConstants.space8),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant,
          ),
        ],
      );
    }

    // Full width so [align] has the room it aligns within — a heading paints
    // no background, so the claim costs nothing.
    return Semantics(
      header: true,
      child: Padding(
        padding: padding,
        child: SizedBox(width: double.infinity, child: content),
      ),
    );
  }
}
''';
}
