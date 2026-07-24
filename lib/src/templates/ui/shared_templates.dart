/// Generates reusable shared widget templates.
class SharedTemplates {
  SharedTemplates._();

  /// Returns the generated appImage template.
  static String appAvatar() => r'''
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

enum AppAvatarSize {
  profile(160),
  call(180),
  detail(80),
  card(38),
  chat(36);

  const AppAvatarSize(this.diameter);
  final double diameter;
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.avatar,
    this.name,
    this.size = AppAvatarSize.card,
    this.roundedSquare = false,
  });

  final String? avatar;
  final String? name;
  final AppAvatarSize size;
  final bool roundedSquare;

  String _initial() {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  Color _backgroundColor() {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return AppConstants.avatarPalette.last;
    final index = trimmed.codeUnitAt(0) % AppConstants.avatarPalette.length;
    return AppConstants.avatarPalette[index];
  }

  @override
  Widget build(BuildContext context) {
    final double dimension = size.diameter;
    final Widget image = SizedBox.square(
      dimension: dimension,
      child: (avatar?.isValidUrl() ?? false)
          ? CachedNetworkImage(
              imageUrl: avatar!,
              fit: BoxFit.cover,
              placeholder: (context, _) => _placeholder(context),
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );

    if (roundedSquare) {
      return ClipRRect(borderRadius: AppConstants.borderRadius12, child: image);
    }
    return ClipOval(child: image);
  }

  Widget _placeholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );

  Widget _fallback() => Container(
        color: _backgroundColor(),
        alignment: Alignment.center,
        child: Text(
          _initial(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size.diameter * 0.4,
          ),
        ),
      );
}
''';

  /// Returns the generated appImage template.
  static String appImage() => r'''
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

enum AppImageSize {
  banner(320),
  large(240),
  medium(160),
  small(80),
  thumbnail(48);

  const AppImageSize(this.size);
  final double size;
}

enum AppImageShape {
  rectangle,
  roundedRectangle,
  circle,
}

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    this.imageUrl,
    this.assetPath,
    this.width,
    this.height,
    this.size = AppImageSize.medium,
    this.shape = AppImageShape.roundedRectangle,
    this.fit = BoxFit.cover,
    this.placeholderAsset = 'assets/images/placeholder_image.jpg',
  });

  final String? imageUrl;
  final String? assetPath;
  final double? width;
  final double? height;
  final AppImageSize size;
  final AppImageShape shape;
  final BoxFit fit;
  final String placeholderAsset;

  @override
  Widget build(BuildContext context) {
    final double resolvedWidth = width ?? size.size;
    final double resolvedHeight = height ?? size.size;

    final Widget image = SizedBox(
      width: resolvedWidth,
      height: resolvedHeight,
      child: (imageUrl?.isValidUrl() ?? false)
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: fit,
              placeholder: (context, _) => _placeholder(context),
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _localOrFallback(),
    );

    return switch (shape) {
      AppImageShape.circle => ClipOval(child: image),
      AppImageShape.roundedRectangle => ClipRRect(
          borderRadius: AppConstants.borderRadius12,
          child: image,
        ),
      AppImageShape.rectangle => image,
    };
  }

  Widget _placeholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );

 Widget _localOrFallback() {
    final path = assetPath;
    if (path != null && path.isNotEmpty) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Image.asset(placeholderAsset, fit: fit);
}
''';

  /// Returns the generated appButton template.
  ///
  /// When [hasBiometricAuth] is true, adds a `requireAuth` flag that runs
  /// BiometricService.verifyUserLocalAuth before [onPressed]; the import and
  /// flag are left out otherwise, since core/security/biometric_service.dart
  /// is only generated when that feature is selected.
  static String appButton({bool hasBiometricAuth = false}) {
    final biometricImports = hasBiometricAuth
        ? "\nimport 'package:flutter_riverpod/flutter_riverpod.dart';"
            "\nimport '../../../core/security/biometric_service.dart';"
        : '';

    final classDeclaration = hasBiometricAuth
        ? 'class AppButton extends ConsumerWidget {'
        : 'class AppButton extends StatelessWidget {';

    final requireAuthParam =
        hasBiometricAuth ? '\n    this.requireAuth = false,' : '';

    final requireAuthField = !hasBiometricAuth
        ? ''
        : '\n\n  /// Runs biometric verification before [onPressed]; the press\n'
            '  /// is cancelled when it fails.\n'
            '  final bool requireAuth;';

    final buildSignature = hasBiometricAuth
        ? 'Widget build(BuildContext context, WidgetRef ref) {'
        : 'Widget build(BuildContext context) {';

    final onPressedWiring = !hasBiometricAuth
        ? 'isLoading || onPressed == null\n'
            '            ? null\n'
            '            : () {\n'
            '                HapticFeedback.selectionClick();\n'
            '                onPressed!();\n'
            '              }'
        : 'isLoading || onPressed == null\n'
            '            ? null\n'
            '            : () async {\n'
            '                HapticFeedback.selectionClick();\n'
            '                if (!requireAuth) {\n'
            '                  onPressed!();\n'
            '                  return;\n'
            '                }\n'
            '                final verified = await ref\n'
            '                    .read(biometricServiceProvider)\n'
            '                    .verifyUserLocalAuth(context);\n'
            '                if (verified) onPressed!();\n'
            '              }';

    return '''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';$biometricImports

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Color role of [AppButton] — what the button is *about*, never how it is
/// filled. Every color the button paints derives from this, so a
/// [AppButtonVariant.danger] button is danger-colored whatever its type.
enum AppButtonVariant { primary, secondary, tertiary, danger }

/// Fill treatment of [AppButton] — how the [AppButtonVariant] color is applied.
///
/// - [filled]: solid variant background, contrasting label.
/// - [outlined]: transparent background, variant-colored border + label.
/// - [ghost]: transparent background, no border, variant-colored label.
///
/// Orthogonal to [AppButtonVariant] and [AppButtonShape]: any color combines
/// with any fill and any shape.
enum AppButtonType { filled, outlined, ghost }

/// Corner shape of [AppButton].
enum AppButtonShape { rounded, pill }

enum AppButtonSize { large, medium, small }

typedef _ButtonSizeConfig = ({
  double height,
  double fontSize,
  double iconSize,
  EdgeInsets padding,
});

$classDeclaration
  const AppButton({
    super.key,
    required this.variant,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.type = AppButtonType.filled,
    this.shape = AppButtonShape.rounded,
    this.prefixIcon,
    this.suffixIcon,
    this.width,
    this.size = AppButtonSize.medium,
    this.hint,$requireAuthParam
  });

  final AppButtonVariant variant;
  final String label;

  /// Tap handler. Pass null to render the button in its disabled state.
  final VoidCallback? onPressed;

  /// When true, the label is replaced by a spinner and taps are ignored, while
  /// the button keeps its size so the surrounding layout doesn't jump.
  final bool isLoading;
  final AppButtonType type;
  final AppButtonShape shape;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final double? width;
  final AppButtonSize size;

  /// Tip shown above the button, e.g. to explain what it does before the
  /// user taps it. Omit for a plain button.
  final String? hint;$requireAuthField

  _ButtonSizeConfig _getSizeConfig() => switch (size) {
        AppButtonSize.small => (
            height: AppConstants.touchTarget,
            fontSize: 14,
            iconSize: 18,
            padding: AppConstants.padding12,
          ),
        AppButtonSize.medium => (
            height: AppConstants.touchTarget + 4,
            fontSize: 16,
            iconSize: 22,
            padding: AppConstants.padding16,
          ),
        AppButtonSize.large => (
            height: AppConstants.touchTarget + 8,
            fontSize: 18,
            iconSize: 26,
            padding: AppConstants.padding16,
          ),
      };

  /// The variant's color, plus the color that reads on top of it. Single
  /// source for every color the button paints.
  (Color, Color) _colorsOf(ThemeData theme) => switch (variant) {
        AppButtonVariant.primary => (
            theme.colorScheme.primary,
            theme.colorScheme.onPrimary,
          ),
        AppButtonVariant.secondary => (
            theme.colorScheme.secondary,
            theme.colorScheme.onSecondary,
          ),
        AppButtonVariant.tertiary => (
            theme.colorScheme.tertiary,
            theme.colorScheme.onTertiary,
          ),
        AppButtonVariant.danger => (
            theme.colorScheme.error,
            theme.colorScheme.onError,
          ),
      };

  @override
  $buildSignature
    final theme = context.theme;
    final sizeConfig = _getSizeConfig();
    final (accent, onAccent) = _colorsOf(theme);

    // Variant chooses the color; type only decides how that color is applied.
    final (backgroundColor, foregroundColor) = switch (type) {
      AppButtonType.filled => (accent, onAccent),
      AppButtonType.outlined || AppButtonType.ghost => (
          Colors.transparent,
          accent,
        ),
    };

    // Faded versions of the same colors for the disabled state, so a disabled
    // button still reads as its variant rather than a generic grey.
    final (disabledBackground, disabledForeground) = switch (type) {
      AppButtonType.filled => (
          accent.withValues(alpha: 0.35),
          onAccent.withValues(alpha: 0.9),
        ),
      AppButtonType.outlined || AppButtonType.ghost => (
          Colors.transparent,
          accent.withValues(alpha: 0.4),
        ),
    };

    final button = SizedBox(
      width: width ?? double.infinity,
      height: sizeConfig.height,
      child: ElevatedButton(
        onPressed: $onPressedWiring,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: sizeConfig.padding,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          // While loading, the button keeps its full color (just non-tappable);
          // only a truly disabled button (onPressed == null) fades.
          disabledBackgroundColor:
              isLoading ? backgroundColor : disabledBackground,
          disabledForegroundColor:
              isLoading ? foregroundColor : disabledForeground,
          shape: RoundedRectangleBorder(
            borderRadius: switch (shape) {
              AppButtonShape.rounded => AppConstants.borderRadius12,
              AppButtonShape.pill => AppConstants.borderRadiusFull,
            },
            side: type == AppButtonType.outlined
                ? BorderSide(color: accent, width: 2)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: sizeConfig.iconSize,
                width: sizeConfig.iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: foregroundColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (prefixIcon != null) ...[
                    Icon(prefixIcon,
                        size: sizeConfig.iconSize, color: foregroundColor),
                    const SizedBox(width: AppConstants.space4),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: foregroundColor,
                      fontSize: sizeConfig.fontSize,
                    ),
                  ),
                  if (suffixIcon != null) ...[
                    const SizedBox(width: AppConstants.space4),
                    Icon(suffixIcon,
                        size: sizeConfig.iconSize, color: foregroundColor),
                  ],
                ],
              ),
      ),
    );

    if (hint == null) return button;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.space4),
          child: Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        button,
      ],
    );
  }
}
''';
  }

  /// Returns the generated appLeadingIcon template.
  static String appLeadingIcon() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Color role of [AppLeadingIcon]. Mirrors [AppButtonVariant] so a leading
/// icon, a button and an input all speak the same color vocabulary.
enum AppLeadingIconVariant { primary, secondary, tertiary, danger }

/// Fill treatment of [AppLeadingIcon] — how the [AppLeadingIconVariant] color
/// is applied to the container.
///
/// - [filled]: solid variant background, contrasting icon.
/// - [tonal]: soft variant-tinted background, variant-colored icon.
/// - [outlined]: transparent background, variant-colored border + icon.
enum AppLeadingIconType { filled, tonal, outlined }

/// Corner shape of the container.
enum AppLeadingIconShape { rounded, circle }

enum AppLeadingIconSize { small, medium, large }

typedef _LeadingIconSizeConfig = ({double container, double icon});

/// A Material-style icon container: a colored, rounded (or circular) box
/// with a single icon centered in it. Meant as a leading visual for list
/// tiles, cards and dialogs — not a tappable control on its own.
class AppLeadingIcon extends StatelessWidget {
  const AppLeadingIcon({
    super.key,
    required this.icon,
    this.variant = AppLeadingIconVariant.primary,
    this.type = AppLeadingIconType.tonal,
    this.shape = AppLeadingIconShape.rounded,
    this.size = AppLeadingIconSize.medium,
  });

  final IconData icon;
  final AppLeadingIconVariant variant;
  final AppLeadingIconType type;
  final AppLeadingIconShape shape;
  final AppLeadingIconSize size;

  static const double _tonalFillOpacity = 0.12;
  static const double _outlinedBorderWidth = 1.5;

  _LeadingIconSizeConfig _sizeConfig() => switch (size) {
        AppLeadingIconSize.small => (
            container: 32.0,
            icon: AppConstants.iconSmall,
          ),
        AppLeadingIconSize.medium => (
            container: AppConstants.touchTarget,
            icon: AppConstants.iconMedium,
          ),
        AppLeadingIconSize.large => (
            container: AppConstants.touchTarget + 16,
            icon: AppConstants.iconLarge,
          ),
      };

  /// The variant's color, plus the color that reads on top of it. Single
  /// source for every color the container paints.
  (Color, Color) _colorsOf(ThemeData theme) => switch (variant) {
        AppLeadingIconVariant.primary => (
            theme.colorScheme.primary,
            theme.colorScheme.onPrimary,
          ),
        AppLeadingIconVariant.secondary => (
            theme.colorScheme.secondary,
            theme.colorScheme.onSecondary,
          ),
        AppLeadingIconVariant.tertiary => (
            theme.colorScheme.tertiary,
            theme.colorScheme.onTertiary,
          ),
        AppLeadingIconVariant.danger => (
            theme.colorScheme.error,
            theme.colorScheme.onError,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final sizeConfig = _sizeConfig();
    final (accent, onAccent) = _colorsOf(theme);

    // Variant chooses the color; type only decides how that color is applied.
    final (backgroundColor, iconColor) = switch (type) {
      AppLeadingIconType.filled => (accent, onAccent),
      AppLeadingIconType.tonal => (
          Color.alphaBlend(
            accent.withValues(alpha: _tonalFillOpacity),
            theme.colorScheme.surface,
          ),
          accent,
        ),
      AppLeadingIconType.outlined => (Colors.transparent, accent),
    };

    final isCircle = shape == AppLeadingIconShape.circle;

    return Container(
      width: sizeConfig.container,
      height: sizeConfig.container,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : AppConstants.borderRadius12,
        border: type == AppLeadingIconType.outlined
            ? Border.all(color: accent, width: _outlinedBorderWidth)
            : null,
      ),
      child: Icon(icon, size: sizeConfig.icon, color: iconColor),
    );
  }
}
''';

  /// Returns the generated appInputStyle template.
  static String appInputStyle() => r'''
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Color role of an input. Every color the input paints — border, focus ring,
/// cursor, icons, fill tint and the required asterisk — is derived from the
/// variant, so an [AppInputVariant.secondary] input is secondary all over.
///
/// Mirrors [AppButtonVariant] so the two widgets share one vocabulary.
enum AppInputVariant { primary, secondary, tertiary, danger }

/// Fill treatment of an input — how the [AppInputVariant] color is applied.
///
/// - [filled]: filled, borderless until focused.
/// - [outlined]: transparent with a visible border at rest.
/// - [underline]: bottom border only, no fill.
///
/// Orthogonal to [AppInputVariant] and [AppInputShape].
enum AppInputType { filled, outlined, underline }

/// Corner shape of an input. Ignored by [AppInputType.underline], which has no
/// corners to round.
enum AppInputShape { rounded, pill }

/// Text scale of an input — drives the value text, the hint, the icons and the
/// vertical padding together so the field grows as one.
enum AppInputSize { small, medium, large }

typedef InputSizeConfig = ({
  double fontSize,
  double iconSize,
  double verticalPadding,
});

/// Resolves [AppInputVariant] + [AppInputType] into a concrete [InputDecoration].
///
/// This overrides the global `inputDecorationTheme` on purpose: the theme can
/// only describe one variant, and inputs need all four.
class AppInputStyle {
  const AppInputStyle._();

  static const double _idleBorderWidth = 1;
  static const double _focusedBorderWidth = 1.5;
  static const double _idleBorderOpacity = 0.4;
  static const double _fillOpacity = 0.06;
  static const double _disabledOpacity = 0.38;
  static const double _hintOpacity = 0.35;

  /// The variant's color — the single source every other color derives from.
  static Color accentOf(BuildContext context, AppInputVariant variant) {
    final colorScheme = context.theme.colorScheme;
    return switch (variant) {
      AppInputVariant.primary => colorScheme.primary,
      AppInputVariant.secondary => colorScheme.secondary,
      AppInputVariant.tertiary => colorScheme.tertiary,
      AppInputVariant.danger => colorScheme.error,
    };
  }

  /// Font, icon and padding metrics for a size. Font sizes match [AppButton]'s
  /// scale so a button and an input of the same size read as a matched pair.
   static InputSizeConfig configOf(AppInputSize size) => switch (size) {
        AppInputSize.small => (
            fontSize: AppConstants.fontSize14,
            iconSize: AppConstants.iconSmall,
            verticalPadding: AppConstants.space8,
          ),
        AppInputSize.medium => (
            fontSize: AppConstants.fontSize16,
            iconSize: AppConstants.iconMedium,
            verticalPadding:
                (AppConstants.touchTarget - AppConstants.fontSize16) / 2,
          ),
        AppInputSize.large => (
            fontSize: AppConstants.fontSize34,
            iconSize: AppConstants.iconLarge,
            verticalPadding: AppConstants.space16,
          ),
      };

  /// Style for the text the user types. Pair with [decoration] of the same size.
  static TextStyle? textStyle(
    BuildContext context, {
    required AppInputSize size,
  }) =>
      context.theme.textTheme.bodyMedium?.copyWith(
        fontSize: configOf(size).fontSize,
      );

  /// [TextAlign] as an [AlignmentGeometry], for widgets that align a child box
  /// rather than a run of text — the dropdown's items and hint.
  static AlignmentGeometry alignmentOf(TextAlign textAlign) =>
      switch (textAlign) {
        TextAlign.center => Alignment.center,
        TextAlign.right || TextAlign.end => AlignmentDirectional.centerEnd,
        _ => AlignmentDirectional.centerStart,
      };

  static bool _isFilled(AppInputType type) => type == AppInputType.filled;

  static BorderRadius _radiusOf(AppInputType type, AppInputShape shape) =>
      switch (type) {
        AppInputType.underline => BorderRadius.zero,
        _ => switch (shape) {
            AppInputShape.rounded => AppConstants.borderRadius12,
            AppInputShape.pill => AppConstants.borderRadiusFull,
          },
      };

  static InputBorder _border(
    AppInputType type,
    AppInputShape shape,
    Color color,
    double width,
  ) {
    final side = BorderSide(color: color, width: width);
    if (type == AppInputType.underline) {
      return UnderlineInputBorder(borderSide: side);
    }
    return OutlineInputBorder(
      borderRadius: _radiusOf(type, shape),
      borderSide: side,
    );
  }

  /// Builds the decoration for an input of [variant], [type] and [size].
  static InputDecoration decoration(
    BuildContext context, {
    required AppInputVariant variant,
    required AppInputType type,
    AppInputShape shape = AppInputShape.rounded,
    AppInputSize size = AppInputSize.medium,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    final theme = context.theme;
    final accent = accentOf(context, variant);
    final errorColor = theme.colorScheme.error;
    final filled = _isFilled(type);
    final sizeConfig = configOf(size);

    // Size the icons through an IconTheme so callers can still override with an
    // explicit `Icon(..., size: x)`.
    Widget? sized(Widget? icon) => icon == null
        ? null
        : IconTheme.merge(
            data: IconThemeData(size: sizeConfig.iconSize),
            child: icon,
          );

    // Filled inputs carry their color in the fill, so they stay borderless
    // until focused. Outlined and underline inputs need a visible resting edge.
    final idleColor = filled
        ? Colors.transparent
        : accent.withValues(alpha: _idleBorderOpacity);
    final disabledColor = theme.colorScheme.onSurface.withValues(
      alpha: _disabledOpacity / 2,
    );

    // Tint the theme's fill with the variant instead of replacing it, so the
    // input still sits correctly on the surface in both light and dark themes.
    final baseFill =
        theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surface;

    return InputDecoration(
      hintText: hint,
      prefixIcon: sized(prefixIcon),
      suffixIcon: sized(suffixIcon),
      enabled: enabled,
      filled: filled,
      fillColor: filled
          ? Color.alphaBlend(accent.withValues(alpha: _fillOpacity), baseFill)
          : Colors.transparent,
      border: _border(type, shape, idleColor, _idleBorderWidth),
      enabledBorder: _border(type, shape, idleColor, _idleBorderWidth),
      focusedBorder: _border(type, shape, accent, _focusedBorderWidth),
      disabledBorder: _border(type, shape, disabledColor, _idleBorderWidth),
      errorBorder: _border(type, shape, errorColor, _idleBorderWidth),
      focusedErrorBorder: _border(type, shape, errorColor, _focusedBorderWidth),
      prefixIconColor: enabled ? accent : disabledColor,
      suffixIconColor: enabled ? accent : disabledColor,
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: accent.withValues(alpha: _hintOpacity),
        fontSize: sizeConfig.fontSize,
      ),
      contentPadding: EdgeInsets.symmetric(
        vertical: sizeConfig.verticalPadding,
        horizontal: type == AppInputType.underline
            ? 0
            : AppConstants.space12,
      ),
    );
  }
}
''';

  /// Returns the generated inputTitle template.
  static String inputTitle() => r'''
import 'package:flutter/material.dart';
import './app_input_style.dart';
import '../../../core/utils/extensions.dart';

class InputTitle extends StatelessWidget {
  const InputTitle({
    super.key,
    required this.label,
    required this.required,
    this.variant = AppInputVariant.primary,
    this.size = AppInputSize.medium,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final bool required;
  final AppInputVariant variant;
  final AppInputSize size;

  /// Kept in step with the field's own alignment so the label sits over the
  /// text it describes.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Text.rich(
      textAlign: textAlign,
      TextSpan(
        text: label,
        style: textTheme.bodyLarge?.copyWith(
          fontSize: AppInputStyle.configOf(size).fontSize,
        ),
        children: required
            ? [
                TextSpan(
                  text: ' *',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppInputStyle.accentOf(context, variant),
                    fontWeight: FontWeight.bold,
                    fontSize: AppInputStyle.configOf(size).fontSize,
                  ),
                ),
              ]
            : [],
      ),
    );
  }
}


''';

  /// Returns the generated appInput template.
  static String appInput() => r'''
import 'package:flutter/material.dart';
import './app_input_style.dart';
import './input_title.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/validation_service.dart';

class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.hidePassword = false,
    this.typePassword = false,
    this.initialValue,
    this.keyboardType,
    this.textInputAction,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.autoFocus = false,
    this.required = false,
    this.onChanged,
    this.variant = AppInputVariant.primary,
    this.type = AppInputType.filled,
    this.shape = AppInputShape.rounded,
    this.size = AppInputSize.medium,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final int? maxLines;
  final bool hidePassword;
  final bool typePassword;
  final String? initialValue;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final bool autoFocus;
  final bool required;
  final Function(String c)? onChanged;
  final AppInputVariant variant;
  final AppInputType type;
  final AppInputShape shape;
  final AppInputSize size;

  /// Alignment of the typed value and the hint. The label follows it too.
  final TextAlign textAlign;

  @override
  State<AppInput> createState() => _AppInputState();

  InputType _getInputType() {
    if (keyboardType != null) {
      switch (keyboardType) {
        case TextInputType.emailAddress:
          return InputType.email;
        case TextInputType.number:
          return InputType.number;
        case TextInputType.phone:
          return InputType.phone;
        case TextInputType.url:
          return InputType.url;
        default:
          return InputType.text;
      }
    }
    if (typePassword) {
      return InputType.password;
    }
    return InputType.text;
  }
}

class _AppInputState extends State<AppInput> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.hidePassword || widget.typePassword;
    if (widget.initialValue != null) {
      widget.controller?.text = widget.initialValue!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppConstants.space8,
      // Stretch so the label can align itself against the field's full width.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputTitle(
          label: widget.label,
          required: widget.required,
          variant: widget.variant,
          size: widget.size,
          textAlign: widget.textAlign,
        ),
        IgnorePointer(
          ignoring: widget.readOnly,
          child: TextFormField(
            validator: (value) {
              if (widget.required && (value == null || value.isEmpty)) {
                return 'This field is required';
              }
              if ((widget.keyboardType == TextInputType.emailAddress ||
                      widget.typePassword) &&
                  (value == null || value.isEmpty)) {
                return 'This field is required';
              }
              final result = ValidationService.validate(
                value ?? '',
                inputType: widget._getInputType(),
              );
              if (!result.isValid) {
                return result.error;
              }
              return null;
            },
            onChanged: widget.onChanged,
            focusNode: widget.focusNode,
            autofocus: widget.autoFocus,
            readOnly: widget.readOnly,
            controller: widget.controller,
            style: AppInputStyle.textStyle(context, size: widget.size)?.copyWith(
              color: AppInputStyle.accentOf(context, widget.variant),
              fontWeight: FontWeight.bold,
            ),
            textAlign: widget.textAlign,
            initialValue: widget.controller == null
                ? widget.initialValue
                : null,
            maxLines: widget.maxLines,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            cursorColor: AppInputStyle.accentOf(context, widget.variant),
            decoration: AppInputStyle.decoration(
              context,
              variant: widget.variant,
              type: widget.type,
              shape: widget.shape,
              size: widget.size,
              hint: widget.hint,
              prefixIcon: widget.prefixIcon,
              // A password field gets a built-in show/hide eye when the caller
              // hasn't supplied its own suffix icon.
              suffixIcon: (widget.typePassword && widget.suffixIcon == null)
                  ? IconButton(
                      onPressed: () =>
                          setState(() => _obscured = !_obscured),
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    )
                  : widget.suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}

''';

  /// Returns the generated dateInput template.
  static String dateInput() => r'''
import 'package:flutter/material.dart';
import './app_input_style.dart';
import './input_title.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

class AppDateInput extends StatefulWidget {
  const AppDateInput({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.initialValue,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.autoFocus = false,
    this.required = false,
    this.variant = AppInputVariant.primary,
    this.type = AppInputType.filled,
    this.shape = AppInputShape.rounded,
    this.size = AppInputSize.medium,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final DateTime? initialValue;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final bool autoFocus;
  final bool required;
  final AppInputVariant variant;
  final AppInputType type;
  final AppInputShape shape;
  final AppInputSize size;

  /// Alignment of the displayed date and the hint. The label follows it too.
  final TextAlign textAlign;

  @override
  State<AppDateInput> createState() => _AppDateInputState();
}

class _AppDateInputState extends State<AppDateInput> {
  DateTime _lastSelectedDate = DateTime.now();
  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      widget.controller?.text = widget.initialValue!.formattedDate;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastSelectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
      _lastSelectedDate = picked;
        widget.controller?.text = picked.formattedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppConstants.space8,
      // Stretch so the label can align itself against the field's full width.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputTitle(
          label: widget.label,
          required: widget.required,
          variant: widget.variant,
          size: widget.size,
          textAlign: widget.textAlign,
        ),
        IgnorePointer(
          ignoring: widget.readOnly,
          child: TextFormField(
            onTap: () => _selectDate(context),
            focusNode: widget.focusNode,
            autofocus: widget.autoFocus,
            readOnly: true,
            controller: widget.controller,
            style: AppInputStyle.textStyle(context, size: widget.size)?.copyWith(
              color: AppInputStyle.accentOf(context, widget.variant),
              fontWeight: FontWeight.bold,
            ),
            textAlign: widget.textAlign,
            cursorColor: AppInputStyle.accentOf(context, widget.variant),
            decoration: AppInputStyle.decoration(
              context,
              variant: widget.variant,
              type: widget.type,
              shape: widget.shape,
              size: widget.size,
              hint: widget.hint,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}
''';

  /// Returns the generated timeInput template.
  static String timeInput() => r'''
import 'package:flutter/material.dart';
import './app_input_style.dart';
import './input_title.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

class AppTimeInput extends StatefulWidget {
  const AppTimeInput({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.initialValue,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.autoFocus = false,
    this.required = false,
    this.variant = AppInputVariant.primary,
    this.type = AppInputType.filled,
    this.shape = AppInputShape.rounded,
    this.size = AppInputSize.medium,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final TimeOfDay? initialValue;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final bool autoFocus;
  final bool required;
  final AppInputVariant variant;
  final AppInputType type;
  final AppInputShape shape;
  final AppInputSize size;

  /// Alignment of the displayed time and the hint. The label follows it too.
  final TextAlign textAlign;

  @override
  State<AppTimeInput> createState() => _AppTimeInputState();
}

class _AppTimeInputState extends State<AppTimeInput> {
  TimeOfDay _lastSelectedTime = TimeOfDay.now();
  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      widget.controller?.text = widget.initialValue!.formattedTime;
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _lastSelectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _lastSelectedTime = picked;
        widget.controller?.text = picked.formattedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppConstants.space8,
      // Stretch so the label can align itself against the field's full width.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputTitle(
          label: widget.label,
          required: widget.required,
          variant: widget.variant,
          size: widget.size,
          textAlign: widget.textAlign,
        ),
        IgnorePointer(
          ignoring: widget.readOnly,
          child: TextFormField(
            onTap: () => _selectTime(context),
            focusNode: widget.focusNode,
            autofocus: widget.autoFocus,
            readOnly: true,
            controller: widget.controller,
            style: AppInputStyle.textStyle(context, size: widget.size)?.copyWith(
              color: AppInputStyle.accentOf(context, widget.variant),
              fontWeight: FontWeight.bold,
            ),
            textAlign: widget.textAlign,
            cursorColor: AppInputStyle.accentOf(context, widget.variant),
            decoration: AppInputStyle.decoration(
              context,
              variant: widget.variant,
              type: widget.type,
              shape: widget.shape,
              size: widget.size,
              hint: widget.hint,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}
''';

  /// Returns the generated appDropdown template.
  static String appDropdown() => r'''
import 'package:flutter/material.dart';
import './app_input_style.dart';
import './input_title.dart';
import '../../../core/constants/app_constants.dart';

// Usage with an entity:
//  AppDropdownInput<CategoryEntity>(
//     label: 'Category',
//     items: categories,
//     selectedId: _selectedCategoryId,
//     idOf: (item) => item.id,
//     labelOf: (item) => item.name,
//     onChanged: (id) => setState(() => _selectedCategoryId = id),
//  )
class AppDropdownInput<T> extends StatelessWidget {
  const AppDropdownInput({
    super.key,
    required this.label,
    required this.items,
    required this.idOf,
    required this.labelOf,
    required this.onChanged,
    this.selectedId,
    this.hint = 'Select an option',
    this.enabled = true,
    this.required = false,
    this.prefixIcon,
    this.suffixIcon,
    this.variant = AppInputVariant.primary,
    this.type = AppInputType.filled,
    this.shape = AppInputShape.rounded,
    this.size = AppInputSize.medium,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final List<T> items;

  /// Extract the id from an item — always a String, used as the dropdown value.
  final String Function(T item) idOf;

  /// Extract the display label from an item.
  final String Function(T item) labelOf;

  /// Called with the selected id when the user picks an option.
  final ValueChanged<String> onChanged;

  final String? selectedId;
  final String hint;
  final bool enabled;
  final bool required;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final AppInputVariant variant;
  final AppInputType type;
  final AppInputShape shape;
  final AppInputSize size;

  /// Alignment of the selected value and the hint. The label follows it too.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    final alignment = AppInputStyle.alignmentOf(textAlign);

    return Column(
      spacing: AppConstants.space8,
      // Stretch so the label can align itself against the field's full width.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputTitle(
          label: label,
          required: required,
          variant: variant,
          size: size,
          textAlign: textAlign,
        ),
        IgnorePointer(
          ignoring: !enabled,
          child: DropdownButtonFormField<String>(
            initialValue: selectedId,
            style: AppInputStyle.textStyle(context, size: size)?.copyWith(
              color: accent,
              fontWeight: FontWeight.bold,
            ),
            decoration: AppInputStyle.decoration(
              context,
              variant: variant,
              type: type,
              shape: shape,
              size: size,
              hint: hint,
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              enabled: enabled,
            ),
            isExpanded: true,
            // A dropdown has no textAlign, so align the item boxes instead.
            alignment: alignment,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            iconEnabledColor: accent,
            icon: enabled ? const Icon(Icons.keyboard_arrow_down) : null,
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: idOf(item),
                    alignment: alignment,
                    child: Text(labelOf(item), textAlign: textAlign),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
''';

  /// Returns the generated appCheckbox template.
  static String appCheckbox() => r'''
import 'package:flutter/material.dart';
import './app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A [Checkbox] colored and sized from [AppInputVariant] and [AppInputSize],
/// so it reads as part of the same input family.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.variant = AppInputVariant.primary,
    this.size = AppInputSize.medium,
    this.shape = AppInputShape.rounded,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final AppInputVariant variant;
  final AppInputSize size;

  /// [AppInputShape.pill] renders as a circular checkbox; any other shape
  /// renders as a rounded square.
  final AppInputShape shape;
  final bool tristate;

  static const double _borderWidth = 1.5;
  static const double _idleBorderOpacity = 0.6;

  double _scaleOf(AppInputSize size) => switch (size) {
        AppInputSize.small => 0.85,
        AppInputSize.medium => 1,
        AppInputSize.large => 1.15,
      };

  /// The color that reads on top of the checked fill — mirrors the
  /// foreground half of [AppButton]'s variant colors.
  Color _onAccentOf(ColorScheme colorScheme) => switch (variant) {
        AppInputVariant.primary => colorScheme.onPrimary,
        AppInputVariant.secondary => colorScheme.onSecondary,
        AppInputVariant.tertiary => colorScheme.onTertiary,
        AppInputVariant.danger => colorScheme.onError,
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final accent = AppInputStyle.accentOf(context, variant);

    return Transform.scale(
      scale: _scaleOf(size),
      child: Checkbox(
        value: value,
        tristate: tristate,
        onChanged: onChanged,
        activeColor: accent,
        checkColor: _onAccentOf(colorScheme),
        side: BorderSide(
          color: accent.withValues(alpha: _idleBorderOpacity),
          width: _borderWidth,
        ),
        shape: shape == AppInputShape.pill
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: AppConstants.borderRadius4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
''';

  /// Returns the generated appCheckboxLabel template.
  static String appCheckboxLabel() => r'''
import 'package:flutter/material.dart';
import './app_checkbox.dart';
import './app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// [AppCheckbox] paired with a tappable label (and optional subtitle), the
/// whole row toggling the value — not just the checkbox square.
class AppCheckboxLabel extends StatelessWidget {
  const AppCheckboxLabel({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.variant = AppInputVariant.primary,
    this.size = AppInputSize.medium,
    this.shape = AppInputShape.rounded,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppInputVariant variant;
  final AppInputSize size;
  final AppInputShape shape;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final fontSize = AppInputStyle.configOf(size).fontSize;

    return InkWell(
      borderRadius: AppConstants.borderRadius8,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppCheckbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              variant: variant,
              size: size,
              shape: shape,
            ),
            const SizedBox(width: AppConstants.space8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyLarge?.copyWith(fontSize: fontSize),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
''';

  /// Returns the generated appSwitch template.
  static String appSwitch() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './app_input_style.dart';
import '../../../core/utils/extensions.dart';

/// A [Switch] colored from [AppInputVariant], for on/off settings. Pair it with
/// a label by dropping it into an [AppListTile] as the trailing widget.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.variant = AppInputVariant.primary,
  });

  final bool value;

  /// Pass null to render the switch disabled.
  final ValueChanged<bool>? onChanged;
  final AppInputVariant variant;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    return Switch(
      value: value,
      activeTrackColor: accent,
      onChanged: onChanged == null
          ? null
          : (v) {
              HapticFeedback.selectionClick();
              onChanged!(v);
            },
    );
  }
}
''';

  /// Returns the generated appSegmented template.
  static String appSegmented() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// An exclusive single-choice segmented control (2-4 options), styled from
/// [AppInputVariant]. Ideal for Day/Week/Month-style switches.
///
/// Usage:
///   AppSegmented<Range>(
///     segments: Range.values,
///     selected: _range,
///     labelOf: (r) => r.name,
///     onChanged: (r) => setState(() => _range = r),
///   )
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    this.variant = AppInputVariant.primary,
  });

  final List<T> segments;
  final T selected;
  final String Function(T value) labelOf;
  final IconData? Function(T value)? iconOf;
  final ValueChanged<T> onChanged;
  final AppInputVariant variant;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    final onAccent = context.theme.colorScheme.surface;

    return SegmentedButton<T>(
      showSelectedIcon: false,
      selected: {selected},
      onSelectionChanged: (set) {
        HapticFeedback.selectionClick();
        onChanged(set.first);
      },
      segments: [
        for (final segment in segments)
          ButtonSegment<T>(
            value: segment,
            label: Text(labelOf(segment)),
            icon: iconOf?.call(segment) == null
                ? null
                : Icon(iconOf!.call(segment)),
          ),
      ],
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onAccent : accent,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppConstants.borderRadius8),
        ),
      ),
    );
  }
}
''';

  /// Returns the generated appChoiceChip template.
  static String appChoiceChip() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A single selectable chip styled from [AppInputVariant]. Lay several out in a
/// [Wrap] for a multi-select tag/filter row.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.variant = AppInputVariant.primary,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;
  final AppInputVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accent = AppInputStyle.accentOf(context, variant);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: AppConstants.iconSmall,
              color: selected ? theme.colorScheme.surface : accent,
            ),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color:
            selected ? theme.colorScheme.surface : theme.colorScheme.onSurface,
      ),
      selectedColor: accent,
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadiusFull),
      onSelected: (v) {
        HapticFeedback.selectionClick();
        onSelected(v);
      },
    );
  }
}
''';

  /// Returns the generated appRadioGroup template.
  static String appRadioGroup() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A vertical single-select list of labeled radio options, colored from
/// [AppInputVariant]. The whole row is tappable, not just the dot. Built on the
/// current [RadioGroup] ancestor API (requires Flutter 3.32+).
class AppRadioGroup<T> extends StatelessWidget {
  const AppRadioGroup({
    super.key,
    required this.values,
    required this.groupValue,
    required this.labelOf,
    required this.onChanged,
    this.subtitleOf,
    this.variant = AppInputVariant.primary,
  });

  final List<T> values;
  final T? groupValue;
  final String Function(T value) labelOf;
  final String? Function(T value)? subtitleOf;
  final ValueChanged<T> onChanged;
  final AppInputVariant variant;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final accent = AppInputStyle.accentOf(context, variant);

    void select(T value) {
      HapticFeedback.selectionClick();
      onChanged(value);
    }

    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: (value) {
        if (value != null) select(value);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in values)
            InkWell(
              borderRadius: AppConstants.borderRadius8,
              onTap: () => select(value),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppConstants.space4),
                child: Row(
                  children: [
                    // The row's InkWell drives selection, so the Radio is
                    // display-only; the RadioGroup above supplies its state.
                    IgnorePointer(
                      child: Radio<T>(
                        value: value,
                        activeColor: accent,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: AppConstants.space8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(labelOf(value), style: textTheme.bodyLarge),
                          if (subtitleOf?.call(value) != null)
                            Text(
                              subtitleOf!.call(value)!,
                              style: textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
''';

  /// Returns the generated appSlider template.
  static String appSlider() => r'''
import 'package:flutter/material.dart';
import './app_input_style.dart';
import '../../../core/utils/extensions.dart';

/// A [Slider] colored from [AppInputVariant], with an optional value label
/// shown while dragging (set [divisions] to snap to steps).
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.variant = AppInputVariant.primary,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final AppInputVariant variant;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: accent,
        inactiveTrackColor: accent.withValues(alpha: 0.15),
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
        valueIndicatorColor: accent,
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
    );
  }
}
''';

  /// Returns the generated appListTile template.
  static String appListTile() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A settings/menu row: an optional leading widget (e.g. AppLeadingIcon), a
/// title with optional subtitle, and an optional trailing widget (a value
/// Text, an AppSwitch, a chevron...). Tapping anywhere fires [onTap].
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Appends a trailing chevron when [trailing] is null - the usual "drills
  /// into another screen" affordance.
  final bool showChevron;

  /// Tints the title in the error color, for destructive rows like
  /// "Delete account" / "Log out".
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final titleColor =
        danger ? theme.colorScheme.error : theme.colorScheme.onSurface;

    Widget? resolvedTrailing = trailing;
    if (resolvedTrailing == null && showChevron) {
      resolvedTrailing = Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
        size: AppConstants.iconMedium,
      );
    }

    return InkWell(
      borderRadius: AppConstants.borderRadius12,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.space12,
          vertical: AppConstants.space12,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppConstants.space12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        theme.textTheme.bodyLarge?.copyWith(color: titleColor),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (resolvedTrailing != null) ...[
              const SizedBox(width: AppConstants.space12),
              resolvedTrailing,
            ],
          ],
        ),
      ),
    );
  }
}
''';

  /// Returns the generated appCard template.
  static String appCard() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Fill treatment of [AppCard].
/// - [elevated]: soft shadow, raised off the surface.
/// - [filled]: sits on a tonal surface, no border (the default).
/// - [outlined]: flat with a hairline border.
enum AppCardType { elevated, filled, outlined }

/// A themed surface container. Provide [onTap] to make the whole card tappable.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.type = AppCardType.filled,
    this.padding = AppConstants.padding16,
    this.onTap,
  });

  final Widget child;
  final AppCardType type;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final radius = AppConstants.borderRadius16;

    final decoration = switch (type) {
      AppCardType.elevated => BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      AppCardType.filled => BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: radius,
        ),
      AppCardType.outlined => BoxDecoration(
          color: Colors.transparent,
          borderRadius: radius,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
    };

    final content = DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: radius,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: content,
    );
  }
}
''';

  /// Returns the generated appBadge template.
  static String appBadge() => r'''
import 'package:flutter/material.dart';
import '../../../core/utils/extensions.dart';

/// Wraps [child] with a notification [Badge] — a small count or dot in the
/// top-end corner. Pass [count] for a number (hidden when 0), or leave it null
/// with [showDot] for a plain presence dot.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.child,
    this.count,
    this.showDot = false,
    this.color,
  });

  final Widget child;
  final int? count;
  final bool showDot;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? context.theme.colorScheme.error;

    if (count == null && !showDot) return child;
    if (count != null && count! <= 0) return child;

    if (count == null) {
      return Badge(backgroundColor: badgeColor, smallSize: 8, child: child);
    }

    return Badge(
      backgroundColor: badgeColor,
      label: Text(count! > 99 ? '99+' : '$count'),
      child: child,
    );
  }
}
''';

  /// Returns the generated appTag template.
  static String appTag() => r'''
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Status role of an [AppTag].
enum AppTagStatus { neutral, success, warning, error, info }

/// A small status pill — "Active", "Pending", "Failed". The color comes from
/// [status] and the fill is a soft tint of it, so several tags sit calmly
/// together in a list.
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    this.status = AppTagStatus.neutral,
    this.icon,
  });

  final String label;
  final AppTagStatus status;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = switch (status) {
      AppTagStatus.neutral => theme.colorScheme.onSurfaceVariant,
      AppTagStatus.success => AppConstants.success,
      AppTagStatus.warning => AppConstants.warning,
      AppTagStatus.error => theme.colorScheme.error,
      AppTagStatus.info => AppConstants.info,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.space8,
        vertical: AppConstants.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppConstants.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppConstants.space4),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
''';

  /// Returns the generated appSkeletonList template.
  static String appSkeletonList() => r'''
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../core/constants/app_constants.dart';

/// A shimmering placeholder list for content that is loading, built on
/// skeletonizer. Prefer it over a bare spinner for content areas — it previews
/// the shape of what is coming, which reads as faster.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    super.key,
    this.itemCount = 6,
    this.hasLeading = true,
    this.padding = AppConstants.paddingPage,
  });

  final int itemCount;
  final bool hasLeading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppConstants.space12),
        itemBuilder: (_, __) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: hasLeading ? const CircleAvatar(radius: 24) : null,
          title: const Text('Loading item title here'),
          subtitle: const Text('Secondary supporting line'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
''';

  /// Returns the generated appBottomNav template.
  static String appBottomNav() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/extensions.dart';

/// A single destination for [AppBottomNav].
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A themed [NavigationBar] wrapper. Feed it the current [index], the
/// [destinations], and an [onDestinationSelected] callback. For go_router,
/// drive [index] from a StatefulShellRoute and switch branch in the callback.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int index;
  final List<AppNavDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return NavigationBar(
      selectedIndex: index,
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      onDestinationSelected: (i) {
        HapticFeedback.selectionClick();
        onDestinationSelected(i);
      },
      destinations: [
        for (final d in destinations)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon:
                Icon(d.selectedIcon, color: theme.colorScheme.primary),
            label: d.label,
          ),
      ],
    );
  }
}
''';

  /// Returns the generated appToast template.
  static String appToast() => r'''
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Feedback status for [AppToast].
enum AppToastType { success, error, warning, info }

/// One consistent feedback surface for the whole app, built on
/// [ScaffoldMessenger] floating snackbars.
///
/// Usage: `AppToast.show(context, 'Saved', type: AppToastType.success);`
/// From a Riverpod notifier you already have a context inside `ref.listen`.
class AppToast {
  const AppToast._();

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (accent, icon) = _resolve(type, isDark);

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        elevation: 4,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: AppConstants.borderRadius12,
        ),
        content: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: AppConstants.borderRadius4,
              ),
            ),
            const SizedBox(width: AppConstants.space12),
            Icon(icon, color: accent, size: AppConstants.iconMedium),
            const SizedBox(width: AppConstants.space12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: accent,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: AppToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: AppToastType.error);

  static (Color, IconData) _resolve(AppToastType type, bool isDark) =>
      switch (type) {
        AppToastType.success => (
            isDark ? AppConstants.successDark : AppConstants.success,
            Icons.check_circle_outline,
          ),
        AppToastType.error => (
            isDark ? AppConstants.errorDark : AppConstants.error,
            Icons.error_outline,
          ),
        AppToastType.warning => (
            isDark ? AppConstants.warningDark : AppConstants.warning,
            Icons.warning_amber_rounded,
          ),
        AppToastType.info => (
            isDark ? AppConstants.infoDark : AppConstants.info,
            Icons.info_outline,
          ),
      };
}
''';

  /// Returns the generated appBottomSheetScaffold template.
  static String appBottomSheetScaffold() => r'''
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// The standard inside of a bottom sheet: a rounded surface panel with a drag
/// handle (grabber) at the top, an optional centered [title], and your [child].
/// Pass this as the `child` to `AppBottomModals.showAppBottomModal`.
class AppBottomSheetScaffold extends StatelessWidget {
  const AppBottomSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
    this.padding = AppConstants.paddingPage,
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radius24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppConstants.space12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: AppConstants.borderRadiusFull,
                  ),
                ),
              ),
            Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.space16),
                  ],
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
''';

  /// Returns the generated appOtpInput template.
  static String appOtpInput() => r'''
import 'package:flutter/material.dart';
import 'package:mo_2fa_code/mo_2fa_code.dart';
import './app_input_style.dart';
import './input_title.dart';
import '../../../core/constants/app_constants.dart';

/// A one-time-code / OTP field wrapping mo_2fa_code's [Mo2FACodeField], styled
/// from [AppInputVariant] + [AppInputType] so it matches the rest of the input
/// family and sits under an [InputTitle] like the other inputs.
///
/// Usage:
///   final _codeController = Mo2FACodeController();
///   AppOtpInput(
///     label: 'Verification code',
///     controller: _codeController,
///     onCompleted: (code) => _verify(code),
///   )
class AppOtpInput extends StatelessWidget {
  const AppOtpInput({
    super.key,
    required this.label,
    this.controller,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.validator,
    this.autoFocus = true,
    this.obscureText = false,
    this.required = false,
    this.variant = AppInputVariant.primary,
    this.type = AppInputType.outlined,
  });

  final String label;
  final Mo2FACodeController? controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool autoFocus;
  final bool obscureText;
  final bool required;
  final AppInputVariant variant;
  final AppInputType type;

  Mo2FACellShape get _shape => switch (type) {
        AppInputType.filled => Mo2FACellShape.filled,
        AppInputType.outlined => Mo2FACellShape.outlined,
        AppInputType.underline => Mo2FACellShape.underline,
      };

  Mo2FACellVariant get _cellVariant => switch (variant) {
        AppInputVariant.primary => Mo2FACellVariant.primary,
        AppInputVariant.secondary => Mo2FACellVariant.secondary,
        AppInputVariant.tertiary => Mo2FACellVariant.tertiary,
        AppInputVariant.danger => Mo2FACellVariant.error,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppConstants.space8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputTitle(label: label, required: required, variant: variant),
        Mo2FACodeField(
          length: length,
          controller: controller,
          autoFocus: autoFocus,
          obscureText: obscureText,
          hapticFeedback: true,
          onChanged: onChanged,
          onCompleted: onCompleted,
          validator: validator,
          style: Mo2FACodeStyle(variant: _cellVariant, shape: _shape),
        ),
      ],
    );
  }
}
''';

  /// Returns the generated appScreenLock template.
  static String appScreenLock() => r'''
import 'package:flutter/material.dart';

/// Wraps a screen (or any subtree) and, while [locked] is true, blocks both
/// back navigation (via [PopScope]) and all touch input (via [AbsorbPointer]) —
/// the reusable "freeze the screen while an action is in flight" widget.
///
/// Drive [locked] from your loading state and keep the tapped button's own
/// spinner (AppButton.isLoading) inside it, so the affordance shows progress
/// while the rest of the screen stays put:
///
///   AppScreenLock(
///     locked: state.isLoading,
///     child: Scaffold(
///       body: Column(
///         children: [
///           AppInput(label: 'Email'),
///           AppButton(
///             variant: AppButtonVariant.primary,
///             label: 'Save',
///             isLoading: state.isLoading,
///             onPressed: _save,
///           ),
///         ],
///       ),
///     ),
///   )
///
/// Set [dim]/[showProgress] for a payment-style full block with a scrim and a
/// centered spinner. For rotating reassurance messages over a long operation,
/// use AppLoadingActionOverlay instead (or nest it inside this).
class AppScreenLock extends StatelessWidget {
  const AppScreenLock({
    super.key,
    required this.locked,
    required this.child,
    this.dim = false,
    this.showProgress = false,
    this.onBlockedPop,
  });

  /// While true, back navigation and all pointer input are blocked.
  final bool locked;
  final Widget child;

  /// Paints a translucent scrim over [child] while locked.
  final bool dim;

  /// Centers a [CircularProgressIndicator] over [child] while locked.
  final bool showProgress;

  /// Called when the user tries to leave (back gesture / button) but [locked]
  /// blocked it — e.g. to flash a "Please wait..." toast.
  final VoidCallback? onBlockedPop;

  @override
  Widget build(BuildContext context) {
    Widget content = AbsorbPointer(absorbing: locked, child: child);

    if (locked && (dim || showProgress)) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: ColoredBox(
              color: dim ? const Color(0x66000000) : const Color(0x00000000),
              child: showProgress
                  ? const Center(child: CircularProgressIndicator())
                  : null,
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: !locked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBlockedPop?.call();
      },
      child: content,
    );
  }
}
''';

  /// Returns the generated appLoadingData template.
  static String appLoadingData() => r'''
import 'package:flutter/material.dart';

class AppLoadingData extends StatelessWidget {
  const AppLoadingData({super.key, this.appBar});
  final bool? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar == true ? AppBar() : null,
      body: const Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
''';

  /// Returns the generated appLoadingAction template.
  static String appLoadingAction() => r'''
import 'dart:async';

import 'package:flutter/material.dart';

const _kWaitingMessages = [
  'We are processing your request...',
  'Still processing...',
  'Almost done...',
  'Thank you for your patience...',
];

class AppLoadingActionOverlay extends StatefulWidget {
  const AppLoadingActionOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  State<AppLoadingActionOverlay> createState() =>
      _AppLoadingActionOverlayState();
}

class _AppLoadingActionOverlayState extends State<AppLoadingActionOverlay> {
  Timer? _initialTimer;
  Timer? _cycleTimer;
  String? _currentMessage;
  int _messageIndex = 0;

  @override
  void didUpdateWidget(AppLoadingActionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isLoading && !oldWidget.isLoading) {
      _startTimers();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _clearTimers();
    }
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  void _startTimers() {
    _messageIndex = 0;
    _currentMessage = null;

    _initialTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _currentMessage = _kWaitingMessages[_messageIndex]);

      _cycleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        _messageIndex = (_messageIndex + 1) % _kWaitingMessages.length;
        setState(() => _currentMessage = _kWaitingMessages[_messageIndex]);
      });
    });
  }

  void _clearTimers() {
    _initialTimer?.cancel();
    _cycleTimer?.cancel();
    _initialTimer = null;
    _cycleTimer = null;
    _currentMessage = null;
    _messageIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isLoading) ...[
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                const CircularProgressIndicator(),
                if (_currentMessage != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _currentMessage!,
                      key: ValueKey(_currentMessage),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

''';

  /// Returns the generated emptyView template.
  static String emptyView() => r'''
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.title = 'Nothing here yet',
    this.message = 'No items are available right now.',
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: AppConstants.padding24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

''';

  /// Returns the generated errorView template.
  static String errorView() => r'''
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Inline error state — a centered icon, title, message and optional retry.
/// Mirrors [EmptyView] so the two can be swapped freely; wrap it in a
/// [Scaffold] when you need it to fill a whole route.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
  });

  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppConstants.padding24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'An unknown error occurred',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

''';

  /// Returns the generated designSystemView template.
  static String designSystemView() => r'''
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../widgets/buttons/app_button.dart';
import '../widgets/cards/app_card.dart';
import '../widgets/error_view.dart';
import '../widgets/icons/app_leading_icon.dart';
import '../widgets/indicators/app_badge.dart';
import '../widgets/indicators/app_tag.dart';
import '../widgets/inputs/app_checkbox_label.dart';
import '../widgets/inputs/app_choice_chip.dart';
import '../widgets/inputs/app_dropdown_input.dart';
import '../widgets/inputs/app_input.dart';
import '../widgets/inputs/app_input_style.dart';
import '../widgets/inputs/app_otp_input.dart';
import '../widgets/inputs/app_radio_group.dart';
import '../widgets/inputs/app_segmented.dart';
import '../widgets/inputs/app_slider.dart';
import '../widgets/inputs/app_switch.dart';
import '../widgets/lists/app_list_tile.dart';
import '../widgets/loadings/app_loading_data.dart';
import '../widgets/loadings/app_screen_lock.dart';
import '../widgets/loadings/app_skeleton_list.dart';
import '../widgets/navigation/app_bottom_nav.dart';
import '../widgets/overlays/app_bottom_sheet_scaffold.dart';
import '../widgets/overlays/app_confirm_dialog.dart';
import '../widgets/overlays/app_toast.dart';

/// Design system preview screen.
/// Shows all shared widgets rendered with your current theme.
/// Toggle light/dark using the icon in the app bar.
///
/// Add to your router temporarily:
///   GoRoute(
///     path: '/design-system',
///     builder: (_, _) => const DesignSystemView(),
///   )
class DesignSystemView extends StatefulWidget {
  const DesignSystemView({super.key});

  @override
  State<DesignSystemView> createState() => _DesignSystemViewState();
}

class _DesignSystemViewState extends State<DesignSystemView> {
  ThemeMode _mode = ThemeMode.light;
  String? _selectedDropdown;
  final Map<AppInputVariant, bool> _checkboxValues = {};
  bool _switchValue = true;
  int _segment = 0;
  final Set<int> _choices = {0};
  int? _radioValue = 0;
  double _sliderValue = 0.4;
  bool _buttonLoading = false;
  bool _locked = false;
  int _navIndex = 0;

  void _toggleTheme() => setState(() {
        _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      // TODO: replace with your actual AppTheme
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Design System'),
            actions: [
              IconButton(
                onPressed: _toggleTheme,
                icon: Icon(
                  _mode == ThemeMode.light
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
                tooltip: 'Toggle theme',
              ),
            ],
          ),
          body: ListView(
            padding: AppConstants.paddingPage,
            children: [
              // ── Colors ────────────────────────────────────────────────────
              _Section(
                title: 'Color Scheme',
                child: Builder(builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                  return Wrap(
                    spacing: AppConstants.space8,
                    runSpacing: AppConstants.space8,
                    children: [
                      _ColorChip(label: 'primary', color: cs.primary, onColor: cs.onPrimary),
                      _ColorChip(label: 'secondary', color: cs.secondary, onColor: cs.onSecondary),
                      _ColorChip(label: 'tertiary', color: cs.tertiary, onColor: cs.onTertiary),
                      _ColorChip(label: 'error', color: cs.error, onColor: cs.onError),
                      _ColorChip(label: 'surface', color: cs.surface, onColor: cs.onSurface),
                      _ColorChip(label: 'surfaceVariant', color: cs.surfaceContainerHighest, onColor: cs.onSurfaceVariant),
                      _ColorChip(label: 'primaryContainer', color: cs.primaryContainer, onColor: cs.onPrimaryContainer),
                      _ColorChip(label: 'secondaryContainer', color: cs.secondaryContainer, onColor: cs.onSecondaryContainer),
                    ],
                  );
                }),
              ),

              // ── Typography ────────────────────────────────────────────────
              _Section(
                title: 'Typography',
                child: Builder(builder: (context) {
                  final tt = Theme.of(context).textTheme;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('displayLarge', style: tt.displayLarge),
                      Text('displayMedium', style: tt.displayMedium),
                      Text('displaySmall', style: tt.displaySmall),
                      const SizedBox(height: AppConstants.space8),
                      Text('headlineLarge', style: tt.headlineLarge),
                      Text('headlineMedium', style: tt.headlineMedium),
                      Text('headlineSmall', style: tt.headlineSmall),
                      const SizedBox(height: AppConstants.space8),
                      Text('titleLarge', style: tt.titleLarge),
                      Text('titleMedium', style: tt.titleMedium),
                      Text('titleSmall', style: tt.titleSmall),
                      const SizedBox(height: AppConstants.space8),
                      Text('bodyLarge', style: tt.bodyLarge),
                      Text('bodyMedium', style: tt.bodyMedium),
                      Text('bodySmall', style: tt.bodySmall),
                      const SizedBox(height: AppConstants.space8),
                      Text('labelLarge', style: tt.labelLarge),
                      Text('labelMedium', style: tt.labelMedium),
                      Text('labelSmall', style: tt.labelSmall),
                    ],
                  );
                }),
              ),

              // ── Spacing ───────────────────────────────────────────────────
              _Section(
                title: 'Spacing Scale',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SpacingRow(label: 'space4',  value: AppConstants.space4),
                    _SpacingRow(label: 'space8',  value: AppConstants.space8),
                    _SpacingRow(label: 'space12', value: AppConstants.space12),
                    _SpacingRow(label: 'space16', value: AppConstants.space16),
                    _SpacingRow(label: 'space24', value: AppConstants.space24),
                    _SpacingRow(label: 'space32', value: AppConstants.space32),
                    _SpacingRow(label: 'space48', value: AppConstants.space48),
                  ],
                ),
              ),

              // ── Border Radius ─────────────────────────────────────────────
              _Section(
                title: 'Border Radius',
                child: Wrap(
                  spacing: AppConstants.space12,
                  runSpacing: AppConstants.space12,
                  children: [
                    _RadiusChip(label: 'radius8',    radius: AppConstants.radius8),
                    _RadiusChip(label: 'radius12',   radius: AppConstants.radius12),
                    _RadiusChip(label: 'radius16',   radius: AppConstants.radius16),
                    _RadiusChip(label: 'radius24',   radius: AppConstants.radius24),
                    _RadiusChip(label: 'radiusFull', radius: AppConstants.radiusFull),
                  ],
                ),
              ),

              // ── AppButton ─────────────────────────────────────────────────
              _Section(
                title: 'AppButton',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Variant sets the color, type sets the fill — every
                    // combination is valid.
                    for (final variant in AppButtonVariant.values) ...[
                      for (final type in AppButtonType.values) ...[
                        AppButton(
                          variant: variant,
                          type: type,
                          label: '${variant.name} / ${type.name}',
                          onPressed: () {},
                        ),
                        const SizedBox(height: AppConstants.space8),
                      ],
                    ],
                    const Text('Shapes:'),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(
                      variant: AppButtonVariant.danger,
                      type: AppButtonType.outlined,
                      shape: AppButtonShape.pill,
                      label: 'Danger / outlined / pill',
                      onPressed: () {},
                    ),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(
                      variant: AppButtonVariant.tertiary,
                      shape: AppButtonShape.pill,
                      label: 'Tertiary / filled / pill',
                      onPressed: () {},
                    ),
                    const SizedBox(height: AppConstants.space16),
                    AppButton(variant: AppButtonVariant.primary,   label: 'With prefix icon', onPressed: () {}, prefixIcon: Icons.add),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(variant: AppButtonVariant.primary,   label: 'With suffix icon', onPressed: () {}, suffixIcon: Icons.arrow_forward),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Sizes:'),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(variant: AppButtonVariant.primary, label: 'Small',  onPressed: () {}, size: AppButtonSize.small),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(variant: AppButtonVariant.primary, label: 'Medium', onPressed: () {}, size: AppButtonSize.medium),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(variant: AppButtonVariant.primary, label: 'Large',  onPressed: () {}, size: AppButtonSize.large),
                    const SizedBox(height: AppConstants.space16),
                    AppButton(
                      variant: AppButtonVariant.primary,
                      label: 'Delete account',
                      onPressed: () {},
                      hint: 'This cannot be undone',
                    ),
                  ],
                ),
              ),

              // ── Inputs ────────────────────────────────────────────────────
              _Section(
                title: 'AppInput — types',
                child: Column(
                  children: [
                    for (final type in AppInputType.values) ...[
                      AppInput(
                        label: type.name,
                        hint: 'Type: ${type.name}',
                        type: type,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      const SizedBox(height: AppConstants.space12),
                    ],
                  ],
                ),
              ),

              _Section(
                title: 'AppInput — variants',
                child: Column(
                  children: [
                    for (final variant in AppInputVariant.values) ...[
                      AppInput(
                        label: variant.name,
                        hint: 'Variant: ${variant.name}',
                        required: true,
                        variant: variant,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      const SizedBox(height: AppConstants.space12),
                    ],
                    // Variant, type and shape compose freely.
                    AppInput(
                      label: 'secondary + underline',
                      hint: 'Composed',
                      variant: AppInputVariant.secondary,
                      type: AppInputType.underline,
                    ),
                    const SizedBox(height: AppConstants.space12),
                    AppInput(
                      label: 'tertiary + outlined + pill',
                      hint: 'Composed',
                      variant: AppInputVariant.tertiary,
                      type: AppInputType.outlined,
                      shape: AppInputShape.pill,
                    ),
                    const SizedBox(height: AppConstants.space12),
                    AppInput(
                      label: 'danger + filled + pill',
                      hint: 'Composed',
                      variant: AppInputVariant.danger,
                      shape: AppInputShape.pill,
                    ),
                  ],
                ),
              ),

              _Section(
                title: 'AppInput — sizes',
                child: Column(
                  children: [
                    for (final size in AppInputSize.values) ...[
                      AppInput(
                        label: size.name,
                        hint: 'Size: ${size.name}',
                        size: size,
                        prefixIcon: const Icon(Icons.tag),
                      ),
                      const SizedBox(height: AppConstants.space12),
                    ],
                  ],
                ),
              ),

              _Section(
                title: 'AppInput — text alignment',
                child: Column(
                  children: [
                    for (final align in [
                      TextAlign.start,
                      TextAlign.center,
                      TextAlign.end,
                    ]) ...[
                      AppInput(
                        label: align.name,
                        hint: 'Aligned ${align.name}',
                        required: true,
                        textAlign: align,
                      ),
                      const SizedBox(height: AppConstants.space12),
                    ],
                  ],
                ),
              ),

              _Section(
                title: 'AppDropdownInput',
                child: AppDropdownInput<String>(
                  label: 'Dropdown',
                  items: const ['a', 'b', 'c'],
                  idOf: (item) => item,
                  labelOf: (item) => 'Option ${item.toUpperCase()}',
                  selectedId: _selectedDropdown,
                  variant: AppInputVariant.secondary,
                  onChanged: (v) => setState(() => _selectedDropdown = v),
                ),
              ),

              // ── AppCheckbox ───────────────────────────────────────────────
              _Section(
                title: 'AppCheckbox / AppCheckboxLabel',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final variant in AppInputVariant.values)
                      AppCheckboxLabel(
                        label: 'Notify me (${variant.name})',
                        subtitle: variant == AppInputVariant.primary
                            ? 'With a subtitle'
                            : null,
                        value: _checkboxValues[variant] ?? false,
                        variant: variant,
                        onChanged: (v) =>
                            setState(() => _checkboxValues[variant] = v),
                      ),
                  ],
                ),
              ),

              // ── AppLeadingIcon ────────────────────────────────────────────
              _Section(
                title: 'AppLeadingIcon',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Variants:'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space12,
                      runSpacing: AppConstants.space12,
                      children: [
                        for (final variant in AppLeadingIconVariant.values)
                          AppLeadingIcon(
                            icon: Icons.star_outline,
                            variant: variant,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Types:'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space12,
                      runSpacing: AppConstants.space12,
                      children: [
                        for (final type in AppLeadingIconType.values)
                          AppLeadingIcon(
                            icon: Icons.notifications_outlined,
                            type: type,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Shapes & sizes:'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space12,
                      runSpacing: AppConstants.space12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final size in AppLeadingIconSize.values)
                          AppLeadingIcon(
                            icon: Icons.person_outline,
                            shape: AppLeadingIconShape.circle,
                            size: size,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── AppConfirmDialog ──────────────────────────────────────────
              _Section(
                title: 'AppConfirmDialog',
                child: AppButton(
                  variant: AppButtonVariant.danger,
                  label: 'Show confirm dialog',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => const AppConfirmDialog(
                        title: 'Delete item?',
                        message: 'This action cannot be undone.',
                        icon: Icons.delete_outline,
                        variant: AppButtonVariant.danger,
                        confirmLabel: 'Delete',
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Confirmed: ${confirmed ?? false}')),
                      );
                    }
                  },
                ),
              ),

              // ── Loading ───────────────────────────────────────────────────
              _Section(
                title: 'AppLoadingData',
                child: SizedBox(
                  height: 80,
                  child: AppLoadingData(),
                ),
              ),

              // ── ErrorView ─────────────────────────────────────────────────
              _Section(
                title: 'ErrorView',
                child: SizedBox(
                  height: 220,
                  child: ErrorView(
                    message: 'Something went wrong. Please try again.',
                    onRetry: () {},
                  ),
                ),
              ),

              // ── Cards ─────────────────────────────────────────────────────
              _Section(
                title: 'Cards',
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: AppConstants.padding16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Card title', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: AppConstants.space4),
                            Text('Card body text.', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.space8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppConstants.borderRadius12,
                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Padding(
                        padding: AppConstants.padding16,
                        child: Text('Outlined card', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Chips ─────────────────────────────────────────────────────
              _Section(
                title: 'Chips',
                child: Wrap(
                  spacing: AppConstants.space8,
                  runSpacing: AppConstants.space8,
                  children: [
                    const Chip(label: Text('Default')),
                    ActionChip(label: const Text('Action'), onPressed: () {}),
                    FilterChip(label: const Text('Filter'), selected: true, onSelected: (_) {}),
                    InputChip(label: const Text('Input'), onDeleted: () {}),
                  ],
                ),
              ),

              // ── Dialogs & Snackbars ───────────────────────────────────────
              _Section(
                title: 'Dialogs & Snackbars',
                child: Wrap(
                  spacing: AppConstants.space8,
                  runSpacing: AppConstants.space8,
                  children: [
                    OutlinedButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Dialog title'),
                          content: const Text('Dialog content text.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Confirm')),
                          ],
                        ),
                      ),
                      child: const Text('Dialog'),
                    ),
                    OutlinedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Snackbar')),
                      ),
                      child: const Text('Snackbar'),
                    ),
                    OutlinedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Error'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      child: const Text('Error Snackbar'),
                    ),
                  ],
                ),
              ),

              // ── Bottom Sheet ──────────────────────────────────────────────
              _Section(
                title: 'Bottom Sheet',
                child: OutlinedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppConstants.radius24),
                      ),
                    ),
                    builder: (_) => Padding(
                      padding: AppConstants.paddingPage,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bottom Sheet', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: AppConstants.space8),
                          Text('Content goes here.', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: AppConstants.space24),
                          AppButton(
                            variant: AppButtonVariant.secondary,
                            label: 'Close',
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: AppConstants.space16),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('Show Bottom Sheet'),
                ),
              ),

              // ── AppButton — states ────────────────────────────────────────
              _Section(
                title: 'AppButton — loading & disabled',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      variant: AppButtonVariant.primary,
                      label: 'Tap to load for 2s',
                      isLoading: _buttonLoading,
                      onPressed: () async {
                        setState(() => _buttonLoading = true);
                        await Future<void>.delayed(const Duration(seconds: 2));
                        if (mounted) setState(() => _buttonLoading = false);
                      },
                    ),
                    const SizedBox(height: AppConstants.space8),
                    const AppButton(
                      variant: AppButtonVariant.primary,
                      label: 'Disabled (onPressed: null)',
                      onPressed: null,
                    ),
                    const SizedBox(height: AppConstants.space8),
                    const AppButton(
                      variant: AppButtonVariant.danger,
                      type: AppButtonType.outlined,
                      label: 'Disabled outlined',
                      onPressed: null,
                    ),
                  ],
                ),
              ),

              // ── AppSwitch ─────────────────────────────────────────────────
              _Section(
                title: 'AppSwitch',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Enable notifications'),
                    AppSwitch(
                      value: _switchValue,
                      onChanged: (v) => setState(() => _switchValue = v),
                    ),
                  ],
                ),
              ),

              // ── AppSegmented ──────────────────────────────────────────────
              _Section(
                title: 'AppSegmented',
                child: AppSegmented<int>(
                  segments: const [0, 1, 2],
                  selected: _segment,
                  labelOf: (i) => const ['Day', 'Week', 'Month'][i],
                  onChanged: (i) => setState(() => _segment = i),
                ),
              ),

              // ── AppChoiceChip ─────────────────────────────────────────────
              _Section(
                title: 'AppChoiceChip',
                child: Wrap(
                  spacing: AppConstants.space8,
                  runSpacing: AppConstants.space8,
                  children: [
                    for (var i = 0; i < 4; i++)
                      AppChoiceChip(
                        label: const ['All', 'Food', 'Travel', 'Bills'][i],
                        selected: _choices.contains(i),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _choices.add(i);
                          } else {
                            _choices.remove(i);
                          }
                        }),
                      ),
                  ],
                ),
              ),

              // ── AppRadioGroup ─────────────────────────────────────────────
              _Section(
                title: 'AppRadioGroup',
                child: AppRadioGroup<int>(
                  values: const [0, 1, 2],
                  groupValue: _radioValue,
                  labelOf: (i) => const ['Card', 'Bank transfer', 'Cash'][i],
                  subtitleOf: (i) => i == 0 ? 'Visa ending 4242' : null,
                  onChanged: (i) => setState(() => _radioValue = i),
                ),
              ),

              // ── AppSlider ─────────────────────────────────────────────────
              _Section(
                title: 'AppSlider',
                child: AppSlider(
                  value: _sliderValue,
                  divisions: 10,
                  label: '${(_sliderValue * 100).round()}%',
                  onChanged: (v) => setState(() => _sliderValue = v),
                ),
              ),

              // ── AppListTile ───────────────────────────────────────────────
              _Section(
                title: 'AppListTile',
                child: Column(
                  children: [
                    AppListTile(
                      leading: const AppLeadingIcon(icon: Icons.person_outline),
                      title: 'Account',
                      subtitle: 'Profile, security, devices',
                      showChevron: true,
                      onTap: () {},
                    ),
                    AppListTile(
                      leading: const AppLeadingIcon(
                        icon: Icons.notifications_outlined,
                        variant: AppLeadingIconVariant.secondary,
                      ),
                      title: 'Notifications',
                      trailing: AppSwitch(
                        value: _switchValue,
                        onChanged: (v) => setState(() => _switchValue = v),
                      ),
                    ),
                    AppListTile(
                      leading: const AppLeadingIcon(
                        icon: Icons.logout,
                        variant: AppLeadingIconVariant.danger,
                      ),
                      title: 'Log out',
                      danger: true,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              // ── AppCard ───────────────────────────────────────────────────
              _Section(
                title: 'AppCard',
                child: Column(
                  children: [
                    for (final type in AppCardType.values) ...[
                      AppCard(
                        type: type,
                        child: Row(
                          children: [
                            Expanded(child: Text('${type.name} card')),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.space8),
                    ],
                  ],
                ),
              ),

              // ── AppTag & AppBadge ─────────────────────────────────────────
              _Section(
                title: 'AppTag & AppBadge',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wrap(
                      spacing: AppConstants.space8,
                      runSpacing: AppConstants.space8,
                      children: [
                        AppTag(label: 'Neutral'),
                        AppTag(
                          label: 'Active',
                          status: AppTagStatus.success,
                          icon: Icons.check,
                        ),
                        AppTag(label: 'Pending', status: AppTagStatus.warning),
                        AppTag(label: 'Failed', status: AppTagStatus.error),
                        AppTag(label: 'Info', status: AppTagStatus.info),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Row(
                      children: [
                        AppBadge(
                          count: 3,
                          child: Icon(Icons.notifications_outlined),
                        ),
                        SizedBox(width: AppConstants.space24),
                        AppBadge(showDot: true, child: Icon(Icons.mail_outline)),
                        SizedBox(width: AppConstants.space24),
                        AppBadge(
                          count: 128,
                          child: Icon(Icons.chat_bubble_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── AppOtpInput ───────────────────────────────────────────────
              _Section(
                title: 'AppOtpInput',
                child: AppOtpInput(
                  label: 'Verification code',
                  length: 5,
                  autoFocus: false,
                  onCompleted: (code) {},
                ),
              ),

              // ── AppToast ──────────────────────────────────────────────────
              _Section(
                title: 'AppToast',
                child: Wrap(
                  spacing: AppConstants.space8,
                  runSpacing: AppConstants.space8,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          AppToast.success(context, 'Saved successfully'),
                      child: const Text('Success'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          AppToast.error(context, 'Something failed'),
                      child: const Text('Error'),
                    ),
                    OutlinedButton(
                      onPressed: () => AppToast.show(
                        context,
                        'Heads up',
                        type: AppToastType.warning,
                      ),
                      child: const Text('Warning'),
                    ),
                    OutlinedButton(
                      onPressed: () => AppToast.show(
                        context,
                        'For your info',
                        type: AppToastType.info,
                      ),
                      child: const Text('Info'),
                    ),
                  ],
                ),
              ),

              // ── AppSkeletonList ───────────────────────────────────────────
              _Section(
                title: 'AppSkeletonList',
                child: SizedBox(
                  height: 240,
                  child: AppSkeletonList(
                    itemCount: 3,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

              // ── AppScreenLock ─────────────────────────────────────────────
              _Section(
                title: 'AppScreenLock (PopScope + AbsorbPointer)',
                child: AppScreenLock(
                  locked: _locked,
                  dim: true,
                  showProgress: true,
                  child: Container(
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: AppConstants.borderRadius12,
                    ),
                    child: AppButton(
                      variant: AppButtonVariant.primary,
                      width: 200,
                      label: 'Lock screen for 2s',
                      onPressed: () async {
                        setState(() => _locked = true);
                        await Future<void>.delayed(const Duration(seconds: 2));
                        if (mounted) setState(() => _locked = false);
                      },
                    ),
                  ),
                ),
              ),

              // ── AppBottomNav ──────────────────────────────────────────────
              _Section(
                title: 'AppBottomNav',
                child: AppBottomNav(
                  index: _navIndex,
                  onDestinationSelected: (i) => setState(() => _navIndex = i),
                  destinations: const [
                    AppNavDestination(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'Home',
                    ),
                    AppNavDestination(
                      icon: Icons.search_outlined,
                      selectedIcon: Icons.search,
                      label: 'Search',
                    ),
                    AppNavDestination(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: 'Profile',
                    ),
                  ],
                ),
              ),

              // ── Bottom Sheet (with drag handle) ───────────────────────────
              _Section(
                title: 'AppBottomSheetScaffold',
                child: OutlinedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => AppBottomSheetScaffold(
                      title: 'Confirm payment',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Send \$120.00 to Jane Doe?',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppConstants.space24),
                          AppButton(
                            variant: AppButtonVariant.primary,
                            label: 'Confirm',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('Show sheet with handle'),
                ),
              ),

              const SizedBox(height: AppConstants.space48),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.space24),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: AppConstants.space4),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: AppConstants.space16),
        child,
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.label, required this.color, required this.onColor});
  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppConstants.borderRadius8,
      ),
      alignment: Alignment.center,
      padding: AppConstants.padding4,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onColor),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SpacingRow extends StatelessWidget {
  const _SpacingRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.space8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
          Container(
            width: value,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: AppConstants.borderRadius4,
            ),
          ),
          const SizedBox(width: AppConstants.space8),
          Text('${value.toInt()}pt', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _RadiusChip extends StatelessWidget {
  const _RadiusChip({required this.label, required this.radius});
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(radius.clamp(0, 28)),
          ),
        ),
        const SizedBox(height: AppConstants.space4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
''';
}
