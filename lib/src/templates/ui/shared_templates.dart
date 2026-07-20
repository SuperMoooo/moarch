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
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );

    if (roundedSquare) {
      return ClipRRect(borderRadius: AppConstants.borderRadius12, child: image);
    }
    return ClipOval(child: image);
  }

  Widget _placeholder() => Container(
        color: Colors.grey[300],
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
              placeholder: (_, __) => _placeholder(),
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

  Widget _placeholder() => Container(
        color: Colors.grey[300],
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
  static String appButton() => r'''
import 'package:flutter/material.dart';

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

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.variant,
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.filled,
    this.shape = AppButtonShape.rounded,
    this.prefixIcon,
    this.suffixIcon,
    this.width,
    this.size = AppButtonSize.medium,
  });

  final AppButtonVariant variant;
  final String label;
  final VoidCallback onPressed;
  final AppButtonType type;
  final AppButtonShape shape;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final double? width;
  final AppButtonSize size;

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
  Widget build(BuildContext context) {
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

    return SizedBox(
      width: width ?? double.infinity,
      height: sizeConfig.height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: sizeConfig.padding,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefixIcon != null) ...[
              Icon(prefixIcon, size: sizeConfig.iconSize, color: foregroundColor),
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
              Icon(suffixIcon, size: sizeConfig.iconSize, color: foregroundColor),
            ],
          ],
        ),
      ),
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
  @override
  void initState() {
    super.initState();
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
            obscureText: widget.hidePassword,
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
              suffixIcon: widget.suffixIcon,
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

import '../../../core/constants/app_constants.dart';

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

import '../../../core/constants/app_constants.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: AppConstants.padding24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
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
      ),
    );
  }
}

''';

  /// Returns the generated designSystemView template.
  static String designSystemView() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../widgets/buttons/app_button.dart';
import '../widgets/error_view.dart';
import '../widgets/inputs/app_dropdown_input.dart';
import '../widgets/inputs/app_input.dart';
import '../widgets/inputs/app_input_style.dart';
import '../widgets/loadings/app_loading_data.dart';

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
