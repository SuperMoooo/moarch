/// Generates reusable shared widget templates.
class SharedTemplates {
  SharedTemplates._();

  /// Returns the generated appAvatar template.
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
              placeholder: (context, url) => _placeholder(context),
              errorWidget: (context, url, error) => _fallback(),
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
              placeholder: (context, url) => _placeholder(context),
              errorWidget: (context, url, error) => _fallback(),
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
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    return _fallback();
  }

  /// Last resort. The placeholder asset has to be declared in pubspec.yaml to
  /// exist at all, so it gets an errorBuilder of its own — a missing
  /// placeholder should degrade to a neutral box, never throw.
  Widget _fallback() => Image.asset(
        placeholderAsset,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Builder(
          builder: (context) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
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
                  // Flexible + ellipsis so a label longer than an explicit
                  // [width] truncates instead of overflowing the button.
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foregroundColor,
                        fontSize: sizeConfig.fontSize,
                      ),
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
/// - [plain]: no container at all — just the variant-colored icon.
enum AppLeadingIconType { filled, tonal, outlined, plain }

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

    // No container: render the bare icon at the variant's color.
    if (type == AppLeadingIconType.plain) {
      return Icon(icon, size: sizeConfig.icon, color: accent);
    }

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
      AppLeadingIconType.plain => (Colors.transparent, accent),
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

  /// Returns the generated appInputConfig template.
  static String appInputConfig() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Color role of an input. Every color the input paints — border, focus ring,
/// cursor, icons, fill tint and the required marker — is derived from the
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

/// Where a field's label goes.
///
/// - [above]: its own line over the field, with the required marker.
/// - [floating]: inside the field, rising into the border on focus (Material).
/// - [placeholder]: no label; it is used as the hint until the user types.
/// - [none]: no label at all — the field is described by something else.
enum AppInputLabelMode { above, floating, placeholder, none }

/// Font, icon and padding metrics for one [AppInputSize].
typedef InputSizeConfig = ({
  double fontSize,
  double iconSize,
  double verticalPadding,
});

/// The one place the input family's look and behaviour is decided.
///
/// Every input in the kit reads [defaults] at build time for anything the call
/// site left unset. **Edit the [defaults] literal below** — that is the whole
/// point of this file, and nothing else in the app needs touching:
///
///   static AppInputConfig defaults = const AppInputConfig(
///     labelMode: AppInputLabelMode.floating,
///     type: AppInputType.outlined,
///     shape: AppInputShape.pill,
///   );
///
/// A single field still wins over the config when it says so:
///
///   AppInput(label: 'Email', labelMode: AppInputLabelMode.above)
///
/// **What belongs here and what does not.** Colors are not here on purpose:
/// they come from `ColorScheme` so they can differ between light and dark, and
/// the fill tint blends into `inputDecorationTheme.fillColor` from the theme.
/// The raw sizes are not here either — they are tokens in [AppConstants]. What
/// this file owns is how the inputs *use* those two: which token each size
/// picks, how strong the borders and tints are, and how a field is labelled.
class AppInputConfig {
  const AppInputConfig({
    this.labelMode = AppInputLabelMode.above,
    this.variant = AppInputVariant.primary,
    this.type = AppInputType.filled,
    this.shape = AppInputShape.rounded,
    this.size = AppInputSize.medium,
    this.showRequiredMarker = true,
    this.requiredMarker = ' *',
    this.labelGap = AppConstants.space8,
    this.floatingLabelBehavior = FloatingLabelBehavior.auto,
    this.showCounter = false,
    this.autovalidateMode,
    this.idleBorderWidth = 1,
    this.focusedBorderWidth = 1.5,
    this.idleBorderOpacity = 0.4,
    this.fillOpacity = 0.06,
    this.disabledOpacity = 0.38,
    this.hintOpacity = 0.35,
    this.smallMetrics = const (
      fontSize: AppConstants.fontSize14,
      iconSize: AppConstants.iconSmall,
      verticalPadding: AppConstants.space8,
    ),
    this.mediumMetrics = const (
      fontSize: AppConstants.fontSize16,
      iconSize: AppConstants.iconMedium,
      verticalPadding: (AppConstants.touchTarget - AppConstants.fontSize16) / 2,
    ),
    this.largeMetrics = const (
      fontSize: AppConstants.fontSize34,
      iconSize: AppConstants.iconLarge,
      verticalPadding: AppConstants.space16,
    ),
  });

  /// The config every input falls back to — edit this literal to restyle the
  /// app's inputs. Every argument is optional; what you leave out keeps the
  /// default shown in the constructor below.
  ///
  ///   static AppInputConfig defaults = const AppInputConfig(
  ///     labelMode: AppInputLabelMode.floating,
  ///   );
  ///
  /// It stays assignable for the cases a literal cannot cover — a flavor or a
  /// white-label build choosing at startup, or a test swapping it out. Do that
  /// before `runApp`: it is read during build, not watched, so a later change
  /// will not rebuild inputs already on screen.
  static AppInputConfig defaults = const AppInputConfig();

  // ── Labels ─────────────────────────────────────────────────────────────────

  /// Where labels go by default.
  final AppInputLabelMode labelMode;

  /// Whether a `required: true` field is marked at all.
  final bool showRequiredMarker;

  /// What marks a required field — `' *'`, `' (required)'`, anything.
  final String requiredMarker;

  /// Space between an [AppInputLabelMode.above] label and its field.
  final double labelGap;

  /// Whether an [AppInputLabelMode.floating] label starts inside the field and
  /// rises on focus ([FloatingLabelBehavior.auto]), sits above it always
  /// ([FloatingLabelBehavior.always]), or never floats.
  final FloatingLabelBehavior floatingLabelBehavior;

  // ── Defaults every input starts from ───────────────────────────────────────

  final AppInputVariant variant;
  final AppInputType type;
  final AppInputShape shape;
  final AppInputSize size;

  /// Whether a field with a `maxLength` shows its counter.
  final bool showCounter;

  /// When fields validate themselves. Null keeps Flutter's default — validate
  /// on submit only. [AutovalidateMode.onUserInteraction] is the usual choice
  /// for a form that should correct itself as it is filled in.
  final AutovalidateMode? autovalidateMode;

  // ── Border and fill ────────────────────────────────────────────────────────

  final double idleBorderWidth;
  final double focusedBorderWidth;

  /// How visible a resting border is, as a fraction of the variant color.
  final double idleBorderOpacity;

  /// How much of the variant color tints a filled input's background. If light
  /// and dark need different strengths, set `inputDecorationTheme.fillColor`
  /// per theme instead — this tint is blended into it.
  final double fillOpacity;

  final double disabledOpacity;
  final double hintOpacity;

  // ── Size metrics ───────────────────────────────────────────────────────────

  final InputSizeConfig smallMetrics;
  final InputSizeConfig mediumMetrics;
  final InputSizeConfig largeMetrics;

  /// The metrics behind one [AppInputSize].
  InputSizeConfig metricsOf(AppInputSize size) => switch (size) {
    AppInputSize.small => smallMetrics,
    AppInputSize.medium => mediumMetrics,
    AppInputSize.large => largeMetrics,
  };

  AppInputConfig copyWith({
    AppInputLabelMode? labelMode,
    AppInputVariant? variant,
    AppInputType? type,
    AppInputShape? shape,
    AppInputSize? size,
    bool? showRequiredMarker,
    String? requiredMarker,
    double? labelGap,
    FloatingLabelBehavior? floatingLabelBehavior,
    bool? showCounter,
    AutovalidateMode? autovalidateMode,
    double? idleBorderWidth,
    double? focusedBorderWidth,
    double? idleBorderOpacity,
    double? fillOpacity,
    double? disabledOpacity,
    double? hintOpacity,
    InputSizeConfig? smallMetrics,
    InputSizeConfig? mediumMetrics,
    InputSizeConfig? largeMetrics,
  }) {
    return AppInputConfig(
      labelMode: labelMode ?? this.labelMode,
      variant: variant ?? this.variant,
      type: type ?? this.type,
      shape: shape ?? this.shape,
      size: size ?? this.size,
      showRequiredMarker: showRequiredMarker ?? this.showRequiredMarker,
      requiredMarker: requiredMarker ?? this.requiredMarker,
      labelGap: labelGap ?? this.labelGap,
      floatingLabelBehavior:
          floatingLabelBehavior ?? this.floatingLabelBehavior,
      showCounter: showCounter ?? this.showCounter,
      autovalidateMode: autovalidateMode ?? this.autovalidateMode,
      idleBorderWidth: idleBorderWidth ?? this.idleBorderWidth,
      focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
      idleBorderOpacity: idleBorderOpacity ?? this.idleBorderOpacity,
      fillOpacity: fillOpacity ?? this.fillOpacity,
      disabledOpacity: disabledOpacity ?? this.disabledOpacity,
      hintOpacity: hintOpacity ?? this.hintOpacity,
      smallMetrics: smallMetrics ?? this.smallMetrics,
      mediumMetrics: mediumMetrics ?? this.mediumMetrics,
      largeMetrics: largeMetrics ?? this.largeMetrics,
    );
  }
}
''';

  /// Returns the generated appInputStyle template.
  static String appInputStyle() => r'''
import 'package:flutter/material.dart';

import './app_input_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

// The vocabulary (variant, type, shape, size, label mode) lives with the config
// it configures, but every input reaches for it through this file — so one
// import still brings the whole set.
export './app_input_config.dart';

/// Resolves [AppInputVariant] + [AppInputType] into a concrete
/// [InputDecoration].
///
/// This overrides the global `inputDecorationTheme` on purpose: the theme can
/// only describe one variant, and inputs need all four. Colors come from the
/// [ColorScheme] so they follow light and dark; everything else — border
/// weights, tint strength, size metrics, where the label goes — comes from
/// [AppInputConfig.defaults].
class AppInputStyle {
  const AppInputStyle._();

  /// The app-wide input config. Every number below is read from it.
  static AppInputConfig get config => AppInputConfig.defaults;

  /// The variant's color — the single source every other color derives from.
  static Color accentOf(BuildContext context, AppInputVariant? variant) {
    final colorScheme = context.theme.colorScheme;
    return switch (variant ?? config.variant) {
      AppInputVariant.primary => colorScheme.primary,
      AppInputVariant.secondary => colorScheme.secondary,
      AppInputVariant.tertiary => colorScheme.tertiary,
      AppInputVariant.danger => colorScheme.error,
    };
  }

  /// Font, icon and padding metrics for a size. Retune the scale in
  /// [AppInputConfig], not here.
  static InputSizeConfig configOf(AppInputSize? size) =>
      config.metricsOf(size ?? config.size);

  /// Style for the text the user types. Pair with [decoration] of the same size.
  static TextStyle? textStyle(BuildContext context, {AppInputSize? size}) =>
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

  /// The label with its required marker appended, when the config shows one.
  /// Used by the label modes that render inside the field; an above-label is
  /// drawn by `InputTitle`, which styles the marker instead of inlining it.
  static String? markedLabel(String? label, {bool required = false}) {
    if (label == null) return null;
    return required && config.showRequiredMarker
        ? '$label${config.requiredMarker}'
        : label;
  }

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

  /// Builds the decoration for an input.
  ///
  /// Anything left null falls back to [AppInputConfig.defaults], so a field
  /// that says nothing looks like the rest of the app. [label] is only painted
  /// here for the label modes that live inside the field —
  /// [AppInputLabelMode.floating] and [AppInputLabelMode.placeholder].
  static InputDecoration decoration(
    BuildContext context, {
    AppInputVariant? variant,
    AppInputType? type,
    AppInputShape? shape,
    AppInputSize? size,
    String? label,
    AppInputLabelMode? labelMode,
    bool required = false,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool enabled = true,
    bool? showCounter,
    bool alignLabelWithHint = false,
  }) {
    final theme = context.theme;
    final resolvedType = type ?? config.type;
    final resolvedShape = shape ?? config.shape;
    final resolvedSize = size ?? config.size;
    final mode = labelMode ?? config.labelMode;

    final accent = accentOf(context, variant);
    final errorColor = theme.colorScheme.error;
    final filled = _isFilled(resolvedType);
    final sizeConfig = configOf(resolvedSize);

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
        : accent.withValues(alpha: config.idleBorderOpacity);
    final disabledColor = theme.colorScheme.onSurface.withValues(
      alpha: config.disabledOpacity / 2,
    );

    // Tint the theme's fill with the variant instead of replacing it, so the
    // input still sits correctly on the surface in both light and dark themes.
    final baseFill =
        theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surface;

    final marked = markedLabel(label, required: required);

    return InputDecoration(
      // Only the in-field modes draw the label here: `above` is a separate
      // widget over the field, and `none` drops it entirely.
      labelText: mode == AppInputLabelMode.floating ? marked : null,
      floatingLabelBehavior: config.floatingLabelBehavior,
      alignLabelWithHint: alignLabelWithHint,
      hintText: mode == AppInputLabelMode.placeholder ? (hint ?? marked) : hint,
      prefixIcon: sized(prefixIcon),
      suffixIcon: sized(suffixIcon),
      enabled: enabled,
      filled: filled,
      fillColor: filled
          ? Color.alphaBlend(
              accent.withValues(alpha: config.fillOpacity),
              baseFill,
            )
          : Colors.transparent,
      border: _border(
        resolvedType,
        resolvedShape,
        idleColor,
        config.idleBorderWidth,
      ),
      enabledBorder: _border(
        resolvedType,
        resolvedShape,
        idleColor,
        config.idleBorderWidth,
      ),
      focusedBorder: _border(
        resolvedType,
        resolvedShape,
        accent,
        config.focusedBorderWidth,
      ),
      disabledBorder: _border(
        resolvedType,
        resolvedShape,
        disabledColor,
        config.idleBorderWidth,
      ),
      errorBorder: _border(
        resolvedType,
        resolvedShape,
        errorColor,
        config.idleBorderWidth,
      ),
      focusedErrorBorder: _border(
        resolvedType,
        resolvedShape,
        errorColor,
        config.focusedBorderWidth,
      ),
      prefixIconColor: enabled ? accent : disabledColor,
      suffixIconColor: enabled ? accent : disabledColor,
      // At rest a floating label sits where the hint would, so it reads like
      // one; once it floats it becomes the field's accent.
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: enabled
            ? accent.withValues(alpha: config.hintOpacity)
            : disabledColor,
        fontSize: sizeConfig.fontSize,
      ),
      floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: enabled ? accent : disabledColor,
      ),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: accent.withValues(alpha: config.hintOpacity),
        fontSize: sizeConfig.fontSize,
      ),
      // The counter is opt-in: a maxLength is usually a guard rail, not
      // something the user needs to watch tick down.
      counterText: (showCounter ?? config.showCounter) ? null : '',
      contentPadding: EdgeInsets.symmetric(
        vertical: sizeConfig.verticalPadding,
        horizontal: resolvedType == AppInputType.underline
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

/// The label an [AppInputLabelMode.above] field wears, with its required
/// marker styled in the field's own accent.
///
/// The other label modes never build this — they hand the label to the
/// decoration instead, so it can sit inside the field.
class InputTitle extends StatelessWidget {
  const InputTitle({
    super.key,
    required this.label,
    required this.required,
    this.variant,
    this.size,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final bool required;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;
  final AppInputSize? size;

  /// Kept in step with the field's own alignment so the label sits over the
  /// text it describes.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final config = AppInputStyle.config;
    final fontSize = AppInputStyle.configOf(size).fontSize;

    return Text.rich(
      textAlign: textAlign,
      TextSpan(
        text: label,
        style: textTheme.bodyLarge?.copyWith(fontSize: fontSize),
        children: required && config.showRequiredMarker
            ? [
                TextSpan(
                  text: config.requiredMarker,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppInputStyle.accentOf(context, variant),
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
              ]
            : [],
      ),
    );
  }
}

/// Puts a field under its [InputTitle] when labels go [AppInputLabelMode.above],
/// and returns the field untouched for every other mode — where the label is
/// already part of the decoration, or gone.
///
/// Every labeled input in the kit lays itself out through this, so the label
/// mode is decided in exactly one place.
class InputFieldLayout extends StatelessWidget {
  const InputFieldLayout({
    super.key,
    required this.label,
    required this.required,
    required this.field,
    this.labelMode,
    this.variant,
    this.size,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final bool required;
  final Widget field;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputSize? size;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final config = AppInputStyle.config;
    if ((labelMode ?? config.labelMode) != AppInputLabelMode.above) {
      return field;
    }

    return Column(
      spacing: config.labelGap,
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
        field,
      ],
    );
  }
}
''';

  /// Returns the generated appInputFormat template.
  static String appInputFormat() => r'''
import 'package:flutter/services.dart';

import '../../../core/security/validation_service.dart';

/// Separators the money formatter inserts. Both [MoneyInputFormatter] and
/// [AppInputFormat.unformat] read them, so switching an app to another locale
/// is a two-line edit here.
const String moneyGroupSeparator = ',';
const String moneyDecimalSeparator = '.';

/// What a field holds — the one knob that decides how it behaves.
///
/// A format resolves to a keyboard, the [TextInputFormatter]s that keep junk
/// out while the user types, autofill hints and the [InputType] the value is
/// validated against. Set it once and the rest follows:
///
///   AppInput(label: 'Amount', format: AppInputFormat.money)
///
/// Everything it decides is a plain getter, so a hand-rolled [TextField] can
/// borrow the same behaviour without going through `AppInput`.
enum AppInputFormat {
  /// Free text, unfiltered.
  text,

  /// Free text over several lines — a notes or description box.
  multiline,

  /// A person's name: word capitalisation and name autofill.
  personName,

  /// An email address: lower-cased, no spaces.
  email,

  /// A secret: obscured by default, password autofill.
  password,

  /// A handle: letters, digits, `-` and `_` only.
  username,

  /// A link, no spaces.
  url,

  /// A phone number: digits and the punctuation phone numbers use.
  phone,

  /// A whole number.
  integer,

  /// A number with up to two decimal places.
  decimal,

  /// An amount: decimals plus thousands grouping as you type.
  money,

  /// A card number, grouped `#### #### #### ####`.
  creditCard,

  /// A card expiry, masked `MM/YY`.
  cardExpiry,

  /// A card security code: 3–4 digits.
  cvv;

  /// The keyboard to raise.
  TextInputType get keyboardType => switch (this) {
    AppInputFormat.multiline => TextInputType.multiline,
    AppInputFormat.personName => TextInputType.name,
    AppInputFormat.email => TextInputType.emailAddress,
    AppInputFormat.url => TextInputType.url,
    AppInputFormat.phone => TextInputType.phone,
    AppInputFormat.integer ||
    AppInputFormat.creditCard ||
    AppInputFormat.cardExpiry ||
    AppInputFormat.cvv => TextInputType.number,
    AppInputFormat.decimal || AppInputFormat.money =>
      const TextInputType.numberWithOptions(decimal: true),
    AppInputFormat.text ||
    AppInputFormat.password ||
    AppInputFormat.username => TextInputType.text,
  };

  /// Formatters applied on every keystroke, so the field can only ever hold
  /// something shaped like its format. Passing `inputFormatters` to an input
  /// replaces this list.
  List<TextInputFormatter> get formatters => switch (this) {
    AppInputFormat.email => [_noSpaces, const LowerCaseInputFormatter()],
    AppInputFormat.url => [_noSpaces],
    AppInputFormat.username => [_usernameChars],
    AppInputFormat.phone => [_phoneChars],
    AppInputFormat.integer ||
    AppInputFormat.cvv => [FilteringTextInputFormatter.digitsOnly],
    AppInputFormat.decimal => [const DecimalInputFormatter()],
    AppInputFormat.money => [const MoneyInputFormatter()],
    AppInputFormat.creditCard => [
      const MaskedInputFormatter('#### #### #### ####'),
    ],
    AppInputFormat.cardExpiry => [const MaskedInputFormatter('##/##')],
    _ => const [],
  };

  /// The rule [ValidationService] checks the value against.
  InputType get validationType => switch (this) {
    AppInputFormat.email => InputType.email,
    AppInputFormat.password => InputType.password,
    AppInputFormat.username => InputType.username,
    AppInputFormat.url => InputType.url,
    AppInputFormat.phone => InputType.phone,
    AppInputFormat.creditCard => InputType.creditCard,
    AppInputFormat.cardExpiry => InputType.cardExpiry,
    AppInputFormat.cvv => InputType.cvv,
    AppInputFormat.integer ||
    AppInputFormat.decimal ||
    AppInputFormat.money => InputType.number,
    AppInputFormat.text ||
    AppInputFormat.multiline ||
    AppInputFormat.personName => InputType.text,
  };

  /// Whether the value is hidden until the user asks to see it.
  bool get isObscured => this == AppInputFormat.password;

  /// Whether the field should grow past one line.
  bool get isMultiline => this == AppInputFormat.multiline;

  /// The cap the format carries on its own — the mask's own width for cards
  /// and expiries. `null` means uncapped.
  int? get maxLength => switch (this) {
    AppInputFormat.creditCard => 19,
    AppInputFormat.cardExpiry => 5,
    AppInputFormat.cvv => 4,
    _ => null,
  };

  /// How the keyboard capitalises what is typed.
  TextCapitalization get textCapitalization => switch (this) {
    AppInputFormat.personName => TextCapitalization.words,
    AppInputFormat.multiline => TextCapitalization.sentences,
    _ => TextCapitalization.none,
  };

  /// Hints that let the OS offer a saved value — keychain, address book, or
  /// the card scanner.
  List<String>? get autofillHints => switch (this) {
    AppInputFormat.personName => const [AutofillHints.name],
    AppInputFormat.email => const [AutofillHints.email],
    AppInputFormat.password => const [AutofillHints.password],
    AppInputFormat.username => const [AutofillHints.username],
    AppInputFormat.url => const [AutofillHints.url],
    AppInputFormat.phone => const [AutofillHints.telephoneNumber],
    AppInputFormat.creditCard => const [AutofillHints.creditCardNumber],
    AppInputFormat.cardExpiry => const [AutofillHints.creditCardExpirationDate],
    AppInputFormat.cvv => const [AutofillHints.creditCardSecurityCode],
    _ => null,
  };

  /// The value with the punctuation this format added stripped back out — what
  /// you send to an API or hand to `num.parse`.
  ///
  ///   AppInputFormat.money.unformat('1,234.50')            // 1234.50
  ///   AppInputFormat.creditCard.unformat('4111 1111 ...')  // 41111111...
  ///
  /// Formats that add nothing return the value untouched.
  String unformat(String value) => switch (this) {
    AppInputFormat.money =>
      value
          .replaceAll(moneyGroupSeparator, '')
          .replaceAll(moneyDecimalSeparator, '.'),
    AppInputFormat.creditCard ||
    AppInputFormat.cardExpiry ||
    AppInputFormat.cvv => _digitsOnly(value),
    AppInputFormat.phone => value.replaceAll(RegExp(r'[^\d+]'), ''),
    _ => value,
  };

  /// The format a bare [TextInputType] implies — the bridge for fields written
  /// as `keyboardType:` before formats existed. `null` when nothing matches.
  static AppInputFormat? forKeyboardType(TextInputType? keyboardType) {
    if (keyboardType == null) return null;
    if (keyboardType == TextInputType.emailAddress) return AppInputFormat.email;
    if (keyboardType == TextInputType.phone) return AppInputFormat.phone;
    if (keyboardType == TextInputType.url) return AppInputFormat.url;
    if (keyboardType == TextInputType.name) return AppInputFormat.personName;
    if (keyboardType == TextInputType.multiline) {
      return AppInputFormat.multiline;
    }
    if (keyboardType == TextInputType.number) return AppInputFormat.integer;
    if (keyboardType == TextInputType.numberWithOptions(decimal: true)) {
      return AppInputFormat.decimal;
    }
    return null;
  }
}

/// Keeps a decimal number well-formed as it is typed: digits, one separator,
/// and at most [decimalDigits] after it. An edit that would break the shape is
/// rejected rather than corrected, so the caret never jumps.
///
/// Whichever separator key the keyboard offers produces [separator], so the
/// field behaves the same on a comma keyboard as on a dot one.
class DecimalInputFormatter extends TextInputFormatter {
  const DecimalInputFormatter({
    this.decimalDigits = 2,
    this.allowNegative = false,
    this.separator = moneyDecimalSeparator,
  });

  final int decimalDigits;
  final bool allowNegative;
  final String separator;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // A 1:1 replacement, so the selection offsets stay valid.
    final text = newValue.text.replaceAll(RegExp(r'[.,]'), separator);
    final sign = allowNegative ? '-?' : '';
    final tail = decimalDigits > 0
        ? '(${RegExp.escape(separator)}\\d{0,$decimalDigits})?'
        : '';

    if (!RegExp('^$sign\\d*$tail\$').hasMatch(text)) return oldValue;
    return newValue.copyWith(text: text);
  }
}

/// Groups the whole part of an amount as it is typed — `1234.5` shows as
/// `1,234.5` — and puts the caret back where the user left it.
///
/// [decimalSeparator] is the only key that opens the decimal part; the
/// grouping punctuation is this formatter's own and is ignored on the way in.
/// Flip the two for a locale that writes `1.234,50`.
///
/// Read the plain number back with `AppInputFormat.money.unformat(text)`.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({
    this.decimalDigits = 2,
    this.allowNegative = false,
    this.maxIntegerDigits = 12,
    this.groupSeparator = moneyGroupSeparator,
    this.decimalSeparator = moneyDecimalSeparator,
  });

  final int decimalDigits;
  final bool allowNegative;
  final int maxIntegerDigits;
  final String groupSeparator;
  final String decimalSeparator;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Anchor the caret to the digits that follow it: the separators move
    // around as the value grows, the digits after the caret don't.
    final trailingDigits = _digitsAfterCaret(newValue);

    final negative = allowNegative && newValue.text.startsWith('-');
    // Only [decimalSeparator] opens the decimal part — the other punctuation
    // is this formatter's own grouping, so it cannot mean both things.
    final stripped = newValue.text.replaceAll(groupSeparator, '');
    final split = decimalDigits > 0 ? stripped.indexOf(decimalSeparator) : -1;

    var whole = _digitsOnly(
      split == -1 ? stripped : stripped.substring(0, split),
    );
    var fraction = split == -1
        ? ''
        : _digitsOnly(stripped.substring(split + 1));

    if (whole.length > 1) {
      whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    }
    if (whole.length > maxIntegerDigits) {
      whole = whole.substring(0, maxIntegerDigits);
    }
    if (fraction.length > decimalDigits) {
      fraction = fraction.substring(0, decimalDigits);
    }

    final buffer = StringBuffer(negative ? '-' : '')
      ..write(_group(whole, groupSeparator));
    if (split != -1) {
      buffer
        ..write(decimalSeparator)
        ..write(fraction);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: _offsetLeaving(text, trailingDigits),
      ),
    );
  }
}

/// Types the punctuation for the user: `#` is a digit slot, every other
/// character is a literal the field fills in as the slots around it fill.
///
///   MaskedInputFormatter('#### #### #### ####')  // 4111 1111 1111 1111
///   MaskedInputFormatter('##/##')                // 12/25
///   MaskedInputFormatter('(###) ###-####')       // (555) 010-9999
///
/// Digits past the last slot are dropped, so the mask is also the length cap.
class MaskedInputFormatter extends TextInputFormatter {
  const MaskedInputFormatter(this.mask, {this.slot = '#'});

  final String mask;
  final String slot;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final trailingDigits = _digitsAfterCaret(newValue);
    final slots = slot.allMatches(mask).length;

    var digits = _digitsOnly(newValue.text);
    if (digits.length > slots) digits = digits.substring(0, slots);

    // Literals are only written while a digit still needs a slot, so a
    // half-typed value never ends on a dangling separator.
    final buffer = StringBuffer();
    var next = 0;
    for (var i = 0; i < mask.length && next < digits.length; i++) {
      buffer.write(mask[i] == slot ? digits[next++] : mask[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: _offsetLeaving(text, trailingDigits),
      ),
    );
  }
}

/// Lower-cases as the user types — emails and handles are case-insensitive, so
/// a capital from the keyboard's auto-shift shouldn't reach your API.
class LowerCaseInputFormatter extends TextInputFormatter {
  const LowerCaseInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toLowerCase();
    // A few scripts change length when cased, which would invalidate the
    // selection; leave those alone.
    return text.length == newValue.text.length
        ? newValue.copyWith(text: text)
        : newValue;
  }
}

/// Upper-cases as the user types — coupon codes, plates, reference numbers.
class UpperCaseInputFormatter extends TextInputFormatter {
  const UpperCaseInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase();
    return text.length == newValue.text.length
        ? newValue.copyWith(text: text)
        : newValue;
  }
}

final _noSpaces = FilteringTextInputFormatter.deny(RegExp(r'\s'));
final _usernameChars = FilteringTextInputFormatter.allow(
  RegExp(r'[a-zA-Z0-9_-]'),
);
final _phoneChars = FilteringTextInputFormatter.allow(RegExp(r'[\d()+\- ]'));
final _nonDigits = RegExp(r'\D');
final _digit = RegExp(r'\d');

String _digitsOnly(String value) => value.replaceAll(_nonDigits, '');

/// Groups [digits] in threes from the right: `1234567` -> `1,234,567`.
String _group(String digits, String separator) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// How many digits sit after the caret — the part of the value an edit leaves
/// untouched, and so the anchor a re-formatted string can be measured against.
int _digitsAfterCaret(TextEditingValue value) {
  final caret = value.selection.end;
  if (caret < 0 || caret > value.text.length) return 0;
  return _digitsOnly(value.text.substring(caret)).length;
}

/// The offset in [text] that leaves exactly [digits] digits after it.
int _offsetLeaving(String text, int digits) {
  if (digits <= 0) return text.length;
  var seen = 0;
  for (var i = text.length - 1; i >= 0; i--) {
    if (_digit.hasMatch(text[i])) {
      seen++;
      if (seen == digits) return i;
    }
  }
  return 0;
}
''';

  /// Returns the generated appInput template.
  static String appInput() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_input_format.dart';
import './app_input_style.dart';
import './input_title.dart';
import '../../../core/security/validation_service.dart';

/// A labeled text field — the kit's default way to collect a value.
///
/// [format] is the knob that matters: it picks the keyboard, the formatters
/// that keep junk out while typing, the autofill hints and the validation rule
/// in one go, so a money field only ever holds money.
///
///   AppInput(label: 'Email', format: AppInputFormat.email, required: true)
///   AppInput(label: 'Amount', format: AppInputFormat.money)
///   AppInput(label: 'Card', format: AppInputFormat.creditCard)
///
/// A formatted field still reads back as a plain value:
/// `AppInputFormat.money.unformat(controller.text)`.
///
/// Every decision the format makes can be overridden on the field —
/// [keyboardType], [inputFormatters], [autofillHints], [textCapitalization],
/// [obscureText], [maxLength], [validator].
///
/// How it *looks* — where the label goes, which variant, type, shape and size —
/// comes from [AppInputConfig.defaults] unless this field says otherwise, so
/// the app has one place to change its mind.
class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    required this.label,
    this.format = AppInputFormat.text,
    this.controller,
    this.initialValue,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.autoFocus = false,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showCounter,
    this.obscureText,
    this.showPasswordToggle = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization,
    this.inputFormatters,
    this.autofillHints,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.textAlign = TextAlign.start,
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
  });

  final String label;

  /// What the field holds. Drives keyboard, formatters, autofill and
  /// validation together — see [AppInputFormat].
  final AppInputFormat format;

  final TextEditingController? controller;

  /// Seeds the field. With a [controller] it is only used while the controller
  /// is still empty, so an already-populated controller is never clobbered.
  final String? initialValue;

  final String? hint;

  /// Marks the label with an asterisk and rejects an empty value.
  final bool required;

  /// A disabled field is greyed out and cannot be focused.
  final bool enabled;

  /// A read-only field is styled normally but cannot be edited. Without an
  /// [onTap] it ignores pointers entirely; with one it stays tappable, which is
  /// how the picker-backed inputs are built.
  final bool readOnly;

  final bool autoFocus;
  final FocusNode? focusNode;

  /// Lines the field shows. An [AppInputFormat.multiline] field opens at five
  /// unless you say otherwise; `null` grows without limit.
  final int? maxLines;
  final int? minLines;

  /// Character cap. Defaults to the format's own where it has one (a card
  /// number, an expiry).
  final int? maxLength;

  /// Whether [maxLength] shows its counter. Null follows the config.
  final bool? showCounter;

  /// Hides the value. Defaults to the format's own answer — only
  /// [AppInputFormat.password] hides by default.
  final bool? obscureText;

  /// Shows the eye that reveals an obscured value, unless [suffixIcon] takes
  /// the slot. Turn it off for a value that should never be revealed.
  final bool showPasswordToggle;

  /// Overrides [AppInputFormat.keyboardType].
  final TextInputType? keyboardType;

  final TextInputAction? textInputAction;

  /// Overrides [AppInputFormat.textCapitalization].
  final TextCapitalization? textCapitalization;

  /// Replaces [AppInputFormat.formatters]. To keep them and add your own,
  /// spread them: `[...AppInputFormat.money.formatters, myFormatter]`.
  final List<TextInputFormatter>? inputFormatters;

  /// Overrides [AppInputFormat.autofillHints].
  final List<String>? autofillHints;

  final Widget? prefixIcon;
  final Widget? suffixIcon;

  /// Replaces the built-in rule entirely. Call [AppInput.validate] from inside
  /// it to add a rule on top instead of dropping validation.
  final String? Function(String? value)? validator;

  /// When the field validates itself. Null follows the config, which starts at
  /// Flutter's own default — on submit only.
  final AutovalidateMode? autovalidateMode;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  /// Alignment of the typed value and the hint. The label follows it too.
  final TextAlign textAlign;

  /// Where this field's label goes. Null follows the config — see
  /// [AppInputLabelMode].
  final AppInputLabelMode? labelMode;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// The rule an [AppInput] applies when no [validator] is given: required
  /// first, then the format's own [ValidationService] check on the unformatted
  /// value. Empty optional fields pass.
  ///
  /// Exposed so a custom [validator] can layer on top of it:
  ///
  ///   validator: (v) =>
  ///       AppInput.validate(v, format: AppInputFormat.email, required: true) ??
  ///       (v!.endsWith('@work.com') ? null : 'Use your work address'),
  static String? validate(
    String? value, {
    AppInputFormat format = AppInputFormat.text,
    bool required = false,
  }) {
    final text = value ?? '';
    if (required && text.trim().isEmpty) return 'This field is required';
    if (text.isEmpty) return null;

    final result = ValidationService.validate(
      format.unformat(text),
      inputType: format.validationType,
    );
    return result.isValid ? null : result.error;
  }

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late bool _obscured;

  /// The format actually in force: an explicit [AppInput.format] wins, then the
  /// one a bare `keyboardType:` implies — so fields written before formats
  /// existed keep validating the way they did.
  AppInputFormat get _format => widget.format != AppInputFormat.text
      ? widget.format
      : AppInputFormat.forKeyboardType(widget.keyboardType) ??
            AppInputFormat.text;

  /// Whether this field hides its value at all — the eye shows for the whole
  /// life of such a field, not only while the value is hidden.
  bool get _obscurable => widget.obscureText ?? _format.isObscured;

  /// Where this field's label goes: its own answer, else the app's.
  AppInputLabelMode get _labelMode =>
      widget.labelMode ?? AppInputStyle.config.labelMode;

  @override
  void initState() {
    super.initState();
    _obscured = _obscurable;

    final controller = widget.controller;
    if (controller != null &&
        controller.text.isEmpty &&
        widget.initialValue != null) {
      controller.text = widget.initialValue!;
    }
  }

  @override
  void didUpdateWidget(AppInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscureText != oldWidget.obscureText ||
        widget.format != oldWidget.format) {
      _obscured = _obscurable;
    }
  }

  /// An obscured field is single-line by force; a multiline one opens at five
  /// lines unless the caller pinned a value.
  int? get _maxLines {
    if (_obscured) return 1;
    if (_format.isMultiline && widget.maxLines == 1) return 5;
    return widget.maxLines;
  }

  /// The caller's suffix, else the show/hide eye when there is one to show.
  Widget? get _suffixIcon {
    if (widget.suffixIcon != null) return widget.suffixIcon;
    if (!_obscurable || !widget.showPasswordToggle) return null;
    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() => _obscured = !_obscured);
      },
      tooltip: _obscured ? 'Show' : 'Hide',
      icon: Icon(
        _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = _format;
    final accent = AppInputStyle.accentOf(context, widget.variant);

    final field = TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      focusNode: widget.focusNode,
      autofocus: widget.autoFocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: _obscured,
      maxLines: _maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength ?? format.maxLength,
      keyboardType: widget.keyboardType ?? format.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization:
          widget.textCapitalization ?? format.textCapitalization,
      textAlign: widget.textAlign,
      inputFormatters: widget.inputFormatters ?? format.formatters,
      autofillHints: widget.autofillHints ?? format.autofillHints,
      autovalidateMode:
          widget.autovalidateMode ?? AppInputStyle.config.autovalidateMode,
      validator:
          widget.validator ??
          (value) => AppInput.validate(
            value,
            format: format,
            required: widget.required,
          ),
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      cursorColor: accent,
      style: AppInputStyle.textStyle(
        context,
        size: widget.size,
      )?.copyWith(color: accent, fontWeight: FontWeight.bold),
      decoration: AppInputStyle.decoration(
        context,
        variant: widget.variant,
        type: widget.type,
        shape: widget.shape,
        size: widget.size,
        label: widget.label,
        labelMode: _labelMode,
        required: widget.required,
        hint: widget.hint,
        enabled: widget.enabled,
        showCounter: widget.showCounter,
        // A label floating over several lines of text belongs at the first
        // line, not centred against the whole box.
        alignLabelWithHint: _maxLines != 1,
        prefixIcon: widget.prefixIcon,
        suffixIcon: _suffixIcon,
      ),
    );

    return InputFieldLayout(
      label: widget.label,
      required: widget.required,
      labelMode: _labelMode,
      variant: widget.variant,
      size: widget.size,
      textAlign: widget.textAlign,
      // A read-only field with nothing to tap shouldn't take focus or raise a
      // keyboard either.
      field: widget.readOnly && widget.onTap == null
          ? IgnorePointer(child: field)
          : field,
    );
  }
}
''';

  /// Returns the generated cupertinoPickerSheet template.
  static String cupertinoPickerSheet() => r'''
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// The iOS convention for a wheel picker: a Cancel / Done bar above the wheel,
/// on a sheet the caller pops with whatever the wheel was showing.
///
/// Used by [AppDateInput] and [AppTimeInput] on every platform but Android, and
/// reusable for any other wheel — drop a [CupertinoPicker] in as the [child]:
///
/// ```dart
/// showModalBottomSheet<String>(
///   context: context,
///   backgroundColor: Colors.transparent,
///   builder: (sheetContext) => CupertinoPickerSheet(
///     accent: Theme.of(context).colorScheme.primary,
///     onCancel: () => Navigator.pop(sheetContext),
///     onDone: () => Navigator.pop(sheetContext, pending),
///     child: CupertinoPicker(...),
///   ),
/// );
/// ```
///
/// It stays on Material surface colors rather than Cupertino's own, so the
/// sheet matches the rest of the app instead of the rest of iOS.
class CupertinoPickerSheet extends StatelessWidget {
  const CupertinoPickerSheet({
    super.key,
    required this.child,
    required this.accent,
    required this.onCancel,
    required this.onDone,
    this.wheelHeight = _defaultWheelHeight,
  });

  /// The wheel itself — a [CupertinoDatePicker] or a [CupertinoPicker].
  final Widget child;

  /// Colors the confirm action. Pass the variant color of the field that
  /// opened the sheet so the two read as one control.
  final Color accent;

  /// Dismiss without a value. Pop the sheet with nothing.
  final VoidCallback onCancel;

  /// Confirm. Pop the sheet with the value the wheel last reported.
  final VoidCallback onDone;

  /// A wheel is not laid out from its content, so it needs a height. 216 is
  /// what iOS gives one; raise it for a wheel with more columns.
  final double wheelHeight;

  static const double _defaultWheelHeight = 216;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final localizations = MaterialLocalizations.of(context);

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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onCancel();
                  },
                  child: Text(
                    localizations.cancelButtonLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                CupertinoButton(
                  // The haptic for a confirmed pick belongs to whoever acts on
                  // the value, so this one only reports it.
                  onPressed: onDone,
                  child: Text(
                    localizations.okButtonLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            SizedBox(
              height: wheelHeight,
              child: MediaQuery(
                // The wheel has a fixed height, so a large text scale would
                // clip its rows instead of growing the sheet.
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.noScaling,
                  alwaysUse24HourFormat: true,
                ),
                child: CupertinoTheme(
                  // The wheel paints its labels from the Cupertino theme, not
                  // the Material one — without this they stay dark in dark mode.
                  data: CupertinoThemeData(
                    brightness: theme.brightness,
                    primaryColor: accent,
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
''';

  /// Returns the generated dateInput template.
  static String dateInput() => r'''
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_input_style.dart';
import './cupertino_picker_sheet.dart';
import './input_title.dart';
import '../../../core/utils/extensions.dart';

/// A read-only field that opens whichever date picker its platform is used to:
/// the Material calendar dialog on Android, the iOS wheel in a bottom sheet
/// anywhere else. Both paths share one range and hand back one [DateTime], so
/// the call site never has to know which one ran.
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
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
    this.textAlign = TextAlign.start,
    this.onChanged,
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

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// Alignment of the displayed date and the hint. The label follows it too.
  final TextAlign textAlign;

  /// Fires with the picked date. Without it the only way to read the value is
  /// to pass your own [controller] and parse its text back.
  final ValueChanged<DateTime>? onChanged;

  @override
  State<AppDateInput> createState() => _AppDateInputState();
}

class _AppDateInputState extends State<AppDateInput> {
  DateTime _lastSelectedDate = DateTime.now();

  /// One range for both pickers, so the two platforms never disagree about
  /// which dates are selectable.
  static final DateTime _firstDate =
      DateTime.now().subtract(const Duration(days: 365 * 100));
  static final DateTime _lastDate =
      DateTime.now().add(const Duration(days: 365 * 100));

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _lastSelectedDate = widget.initialValue!;
      widget.controller?.text = widget.initialValue!.formattedDate;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.selectionClick();
    // The picker is chosen and opened before anything is awaited, so the
    // context is never carried across the gap.
    final picker = Platform.isAndroid
        ? _showMaterialPicker(context)
        : _showCupertinoPicker(context);

    final picked = await picker;
    if (picked == null || !mounted) return;

    HapticFeedback.selectionClick();
    setState(() {
      _lastSelectedDate = picked;
      widget.controller?.text = picked.formattedDate;
    });
    widget.onChanged?.call(picked);
  }

  Future<DateTime?> _showMaterialPicker(BuildContext context) {
    return showDatePicker(
      context: context,
      initialDate: _lastSelectedDate,
      firstDate: _firstDate,
      lastDate: _lastDate,
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
  }

  Future<DateTime?> _showCupertinoPicker(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, widget.variant);

    // The wheel reports every date it rolls past; only the one showing when
    // Done is tapped counts, so it is parked here until then.
    var pending = _lastSelectedDate;

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => CupertinoPickerSheet(
        accent: accent,
        onCancel: () => Navigator.pop(sheetContext),
        onDone: () => Navigator.pop(sheetContext, pending),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: _lastSelectedDate,
          minimumDate: _firstDate,
          maximumDate: _lastDate,
          onDateTimeChanged: (value) => pending = value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, widget.variant);

    return InputFieldLayout(
      label: widget.label,
      required: widget.required,
      labelMode: widget.labelMode,
      variant: widget.variant,
      size: widget.size,
      textAlign: widget.textAlign,
      field: IgnorePointer(
        ignoring: widget.readOnly,
        child: TextFormField(
          onTap: () => _selectDate(context),
          focusNode: widget.focusNode,
          autofocus: widget.autoFocus,
          readOnly: true,
          controller: widget.controller,
          style: AppInputStyle.textStyle(
            context,
            size: widget.size,
          )?.copyWith(color: accent, fontWeight: FontWeight.bold),
          textAlign: widget.textAlign,
          cursorColor: accent,
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
            suffixIcon: widget.suffixIcon,
          ),
        ),
      ),
    );
  }
}
''';

  /// Returns the generated timeInput template.
  static String timeInput() => r'''
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_input_style.dart';
import './cupertino_picker_sheet.dart';
import './input_title.dart';
import '../../../core/utils/extensions.dart';

/// A read-only field that opens whichever time picker its platform is used to:
/// the Material clock dialog on Android, the iOS wheel in a bottom sheet
/// anywhere else. Both paths hand back one [TimeOfDay], so the call site never
/// has to know which one ran.
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
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
    this.textAlign = TextAlign.start,
    this.onChanged,
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

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// Alignment of the displayed time and the hint. The label follows it too.
  final TextAlign textAlign;

  /// Fires with the picked time. Without it the only way to read the value is
  /// to pass your own [controller] and parse its text back.
  final ValueChanged<TimeOfDay>? onChanged;

  @override
  State<AppTimeInput> createState() => _AppTimeInputState();
}

class _AppTimeInputState extends State<AppTimeInput> {
  TimeOfDay _lastSelectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _lastSelectedTime = widget.initialValue!;
      widget.controller?.text = widget.initialValue!.formattedTime;
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    HapticFeedback.selectionClick();
    // The picker is chosen and opened before anything is awaited, so the
    // context is never carried across the gap.
    final picker = Platform.isAndroid
        ? _showMaterialPicker(context)
        : _showCupertinoPicker(context);

    final picked = await picker;
    if (picked == null || !mounted) return;

    HapticFeedback.selectionClick();
    setState(() {
      _lastSelectedTime = picked;
      widget.controller?.text = picked.formattedTime;
    });
    widget.onChanged?.call(picked);
  }

  Future<TimeOfDay?> _showMaterialPicker(BuildContext context) {
    return showTimePicker(
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
  }

  Future<TimeOfDay?> _showCupertinoPicker(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, widget.variant);

    // The wheel reports every time it rolls past; only the one showing when
    // Done is tapped counts, so it is parked here until then.
    var pending = _lastSelectedTime;

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => CupertinoPickerSheet(
        accent: accent,
        onCancel: () => Navigator.pop(sheetContext),
        onDone: () => Navigator.pop(sheetContext, pending),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          // The wheel only works in DateTime; which day it sits on is
          // irrelevant, since only the time is read back out.
          initialDateTime: _lastSelectedTime.onDate(DateTime.now()),
          use24hFormat: true,
          onDateTimeChanged: (value) => pending = TimeOfDay.fromDateTime(value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, widget.variant);

    return InputFieldLayout(
      label: widget.label,
      required: widget.required,
      labelMode: widget.labelMode,
      variant: widget.variant,
      size: widget.size,
      textAlign: widget.textAlign,
      field: IgnorePointer(
        ignoring: widget.readOnly,
        child: TextFormField(
          onTap: () => _selectTime(context),
          focusNode: widget.focusNode,
          autofocus: widget.autoFocus,
          readOnly: true,
          controller: widget.controller,
          style: AppInputStyle.textStyle(
            context,
            size: widget.size,
          )?.copyWith(color: accent, fontWeight: FontWeight.bold),
          textAlign: widget.textAlign,
          cursorColor: accent,
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
            suffixIcon: widget.suffixIcon,
          ),
        ),
      ),
    );
  }
}
''';

  /// Returns the generated searchPickerSheet template.
  static String searchPickerSheet() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_input_style.dart';
import './app_search_field.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A bottom sheet that picks one row out of a long list, with a search field
/// pinned above it.
///
/// A dropdown menu stops being usable somewhere around thirty options, which is
/// why [AppDropdownInput] opens this once it is told `searchable: true`, and why
/// the country selector on `AppPhoneInput` — 238 rows — uses nothing else.
///
/// Generic over the row type, so callers keep their own entities:
///
/// ```dart
/// final picked = await SearchPickerSheet.show<CategoryEntity>(
///   context,
///   title: 'Category',
///   items: categories,
///   idOf: (item) => item.id,
///   labelOf: (item) => item.name,
///   selectedId: _categoryId,
/// );
/// ```
///
/// Resolves to the picked item, or null when the sheet is dismissed.
class SearchPickerSheet<T> extends StatefulWidget {
  /// Creates the sheet. Prefer [show], which opens it with the modal settings
  /// a full-height searchable sheet needs.
  const SearchPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.idOf,
    required this.labelOf,
    this.selectedId,
    this.searchHint = 'Search',
    this.leadingOf,
    this.trailingLabelOf,
    this.filter,
    this.emptyLabel = 'Nothing matches that search',
    this.variant,
  });

  /// Heading over the search field.
  final String title;

  /// Rows to choose from.
  final List<T> items;

  /// Extracts the id used to mark the current selection.
  final String Function(T item) idOf;

  /// Extracts the row's display text — and, unless [matches] says otherwise,
  /// the text the query is compared against.
  final String Function(T item) labelOf;

  /// The row to mark as current and to open the list scrolled to.
  final String? selectedId;

  /// Placeholder in the search field.
  final String searchHint;

  /// Optional leading widget per row — a flag, an avatar, an icon.
  final Widget Function(T item)? leadingOf;

  /// Optional dimmed text at the end of a row, for a secondary value like a
  /// calling code.
  final String Function(T item)? trailingLabelOf;

  /// Replaces the default filter, which is a case-insensitive `contains` over
  /// [labelOf].
  ///
  /// Returns the rows to show *in the order to show them*, so a caller can
  /// rank matches as well as select them — which is how the country picker
  /// keeps Portugal above Egypt for the query `PT`.
  final List<T> Function(List<T> items, String query)? filter;

  /// Shown in place of the list when nothing matches.
  final String emptyLabel;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  /// Opens the sheet and resolves to the picked item, or null if dismissed.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required String Function(T item) idOf,
    required String Function(T item) labelOf,
    String? selectedId,
    String searchHint = 'Search',
    Widget Function(T item)? leadingOf,
    String Function(T item)? trailingLabelOf,
    List<T> Function(List<T> items, String query)? filter,
    String emptyLabel = 'Nothing matches that search',
    AppInputVariant? variant,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      // The sheet has to be free to grow past half the screen and to sit above
      // the keyboard the search field raises.
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SearchPickerSheet<T>(
        title: title,
        items: items,
        idOf: idOf,
        labelOf: labelOf,
        selectedId: selectedId,
        searchHint: searchHint,
        leadingOf: leadingOf,
        trailingLabelOf: trailingLabelOf,
        filter: filter,
        emptyLabel: emptyLabel,
        variant: variant,
      ),
    );
  }

  @override
  State<SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<SearchPickerSheet<T>> {
  late final ScrollController _scrollController = ScrollController(
    initialScrollOffset: _initialOffset,
  );
  String _query = '';

  /// Opens the list already showing the current selection, so a picker over a
  /// long table doesn't start hundreds of rows away from the answer.
  ///
  /// Exact rather than estimated because the rows are a fixed [_rowHeight].
  double get _initialOffset {
    final selectedId = widget.selectedId;
    if (selectedId == null) return 0;
    final index = widget.items.indexWhere(
      (item) => widget.idOf(item) == selectedId,
    );
    return index <= 0 ? 0 : index * _rowHeight;
  }

  List<T> get _filtered {
    final filter = widget.filter;
    if (filter != null) return filter(widget.items, _query);

    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return widget.items;
    return [
      for (final item in widget.items)
        if (widget.labelOf(item).toLowerCase().contains(needle)) item,
    ];
  }

  void _onQueryChanged(String query) {
    setState(() => _query = query);
    // The previous offset means nothing against a freshly filtered list, and
    // may well be past its end.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final mediaQuery = MediaQuery.of(context);
    final accent = AppInputStyle.accentOf(context, widget.variant);
    final rows = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * _maxHeightFactor,
        ),
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
            children: [
              Padding(
                padding: AppConstants.padding16,
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.space12),
                    AppSearchField(
                      hint: widget.searchHint,
                      autofocus: true,
                      variant: widget.variant,
                      onChanged: _onQueryChanged,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Flexible(
                child: rows.isEmpty
                    ? Padding(
                        padding: AppConstants.padding24,
                        child: Text(
                          widget.emptyLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        // A fixed extent is what makes _initialOffset exact,
                        // and it keeps a 238-row list cheap to scroll.
                        itemExtent: _rowHeight,
                        padding: EdgeInsets.zero,
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final item = rows[index];
                          final id = widget.idOf(item);
                          final selected = id == widget.selectedId;
                          final trailing = widget.trailingLabelOf?.call(item);

                          return ListTile(
                            selected: selected,
                            selectedColor: accent,
                            leading: widget.leadingOf?.call(item),
                            title: Text(
                              widget.labelOf(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: selected
                                  ? const TextStyle(fontWeight: FontWeight.bold)
                                  : null,
                            ),
                            trailing: trailing == null
                                ? null
                                : Text(
                                    trailing,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: selected
                                          ? accent
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context, item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows are a fixed height so the list can be opened at an exact offset.
const double _rowHeight = 56;

/// How much of the screen the sheet may take before its list scrolls.
const double _maxHeightFactor = 0.85;
''';

  /// Returns the generated appDropdown template.
  static String appDropdown() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './app_input_style.dart';
import './input_title.dart';
import './search_picker_sheet.dart';
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
//
// Past about thirty options a menu becomes a scroll hunt. Pass
// `searchable: true` and the field opens a [SearchPickerSheet] instead — the
// same field, the same callback, a list you can type into.
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
    this.searchable = false,
    this.searchHint = 'Search',
    this.searchTitle,
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

  /// Swaps the menu for a [SearchPickerSheet] — a bottom sheet with a search
  /// field over the same options. Turn it on once a list is long enough that
  /// scrolling a menu is the slow way to find a row.
  final bool searchable;

  /// Placeholder in the sheet's search field. Only used when [searchable].
  final String searchHint;

  /// Heading over the sheet. Defaults to [label]. Only used when [searchable].
  final String? searchTitle;

  final Widget? prefixIcon;
  final Widget? suffixIcon;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// Alignment of the selected value and the hint. The label follows it too.
  final TextAlign textAlign;

  /// The item [selectedId] points at, or null when nothing is selected.
  T? get _selected {
    for (final item in items) {
      if (idOf(item) == selectedId) return item;
    }
    return null;
  }

  InputDecoration _decoration(BuildContext context, {Widget? suffix}) =>
      AppInputStyle.decoration(
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
        suffixIcon: suffix,
        enabled: enabled,
      );

  Future<void> _openSheet(BuildContext context) async {
    final picked = await SearchPickerSheet.show<T>(
      context,
      title: searchTitle ?? label,
      searchHint: searchHint,
      items: items,
      idOf: idOf,
      labelOf: labelOf,
      selectedId: selectedId,
      variant: variant,
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    onChanged(idOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    final alignment = AppInputStyle.alignmentOf(textAlign);

    return InputFieldLayout(
      label: label,
      required: required,
      labelMode: labelMode,
      variant: variant,
      size: size,
      textAlign: textAlign,
      field: IgnorePointer(
        ignoring: !enabled,
        child: searchable
            ? _searchableField(context, accent, alignment)
            : _menuField(context, accent, alignment),
      ),
    );
  }

  /// The searchable form: the field only *shows* the selection and opens the
  /// sheet, so there is no menu to lay out and the value still lives with the
  /// caller.
  Widget _searchableField(
    BuildContext context,
    Color accent,
    AlignmentGeometry alignment,
  ) {
    final selected = _selected;

    return InkWell(
      onTap: enabled ? () => _openSheet(context) : null,
      borderRadius: AppConstants.borderRadius12,
      child: InputDecorator(
        // The chevron sits inside the border here, where a suffix goes; the
        // menu form draws its own outside it.
        decoration: _decoration(
          context,
          suffix:
              suffixIcon ??
              (enabled ? const Icon(Icons.keyboard_arrow_down) : null),
        ),
        // Drives the hint and the floating label the same way an empty text
        // field would.
        isEmpty: selected == null,
        child: selected == null
            ? null
            : Align(
                alignment: alignment,
                child: Text(
                  labelOf(selected),
                  textAlign: textAlign,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppInputStyle.textStyle(
                    context,
                    size: size,
                  )?.copyWith(color: accent, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }

  Widget _menuField(
    BuildContext context,
    Color accent,
    AlignmentGeometry alignment,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      style: AppInputStyle.textStyle(
        context,
        size: size,
      )?.copyWith(color: accent, fontWeight: FontWeight.bold),
      decoration: _decoration(context, suffix: suffixIcon),
      isExpanded: true,
      // A dropdown has no textAlign, so align the item boxes instead.
      alignment: alignment,
      onChanged: (value) {
        if (value == null) return;
        HapticFeedback.selectionClick();
        onChanged(value);
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
    );
  }
}
''';

  /// Returns the generated appCheckbox template.
  static String appCheckbox() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.variant,
    this.size,
    this.shape,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final AppInputVariant? variant;
  final AppInputSize? size;

  /// [AppInputShape.pill] renders as a circular checkbox; any other shape
  /// renders as a rounded square.
  final AppInputShape? shape;
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
  Color _onAccentOf(ColorScheme colorScheme, AppInputVariant variant) =>
      switch (variant) {
        AppInputVariant.primary => colorScheme.onPrimary,
        AppInputVariant.secondary => colorScheme.onSecondary,
        AppInputVariant.tertiary => colorScheme.onTertiary,
        AppInputVariant.danger => colorScheme.onError,
      };

  @override
  Widget build(BuildContext context) {
    final config = AppInputStyle.config;
    final colorScheme = context.colorScheme;
    final accent = AppInputStyle.accentOf(context, variant);

    return Transform.scale(
      scale: _scaleOf(size ?? config.size),
      child: Checkbox(
        value: value,
        tristate: tristate,
        onChanged: onChanged == null
            ? null
            : (v) {
                HapticFeedback.selectionClick();
                onChanged!(v);
              },
        activeColor: accent,
        checkColor: _onAccentOf(colorScheme, variant ?? config.variant),
        side: BorderSide(
          color: accent.withValues(alpha: _idleBorderOpacity),
          width: _borderWidth,
        ),
        shape: (shape ?? config.shape) == AppInputShape.pill
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
import 'package:flutter/services.dart';
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
    this.variant,
    this.size,
    this.shape,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppInputVariant? variant;
  final AppInputSize? size;
  final AppInputShape? shape;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final fontSize = AppInputStyle.configOf(size).fontSize;

    return InkWell(
      borderRadius: AppConstants.borderRadius8,
      // The square has its own haptic in AppCheckbox, so this one only covers
      // the rest of the row — one buzz either way.
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
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

/// A [Switch] colored from [AppInputVariant], for on/off settings. Pair it with
/// a label by dropping it into an [AppListTile] as the trailing widget.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.variant,
  });

  final bool value;

  /// Pass null to render the switch disabled.
  final ValueChanged<bool>? onChanged;
  final AppInputVariant? variant;

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
/// ```dart
/// AppSegmented<Range>(
///   segments: Range.values,
///   selected: _range,
///   labelOf: (r) => r.name,
///   onChanged: (r) => setState(() => _range = r),
/// )
/// ```
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    this.variant,
  });

  final List<T> segments;
  final T selected;
  final String Function(T value) labelOf;
  final IconData? Function(T value)? iconOf;
  final ValueChanged<T> onChanged;
  final AppInputVariant? variant;

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
    this.variant,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;
  final AppInputVariant? variant;

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
    this.variant,
  });

  final List<T> values;
  final T? groupValue;
  final String Function(T value) labelOf;
  final String? Function(T value)? subtitleOf;
  final ValueChanged<T> onChanged;
  final AppInputVariant? variant;

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
import 'package:flutter/services.dart';
import './app_input_style.dart';

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
    this.variant,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final AppInputVariant? variant;

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
        onChangeStart: onChanged == null
            ? null
            : (_) => HapticFeedback.selectionClick(),
        onChanged: onChanged == null
            ? null
            : (v) {
                // A stepped slider ticks as it snaps. A continuous one would
                // buzz on every pixel, so for that one the grab is the only
                // feedback.
                if (divisions != null && v != value) {
                  HapticFeedback.selectionClick();
                }
                onChanged!(v);
              },
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
                    softWrap: true,
                    maxLines: 2,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: titleColor,
                      overflow: TextOverflow.ellipsis,
                    ),
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
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final AppCardType type;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// How the child is clipped to the card's rounded corners. Defaults to
  /// [Clip.antiAlias] so an interactive child (e.g. an AppListTile with
  /// [padding] set to [EdgeInsets.zero]) keeps its ripple inside the corners.
  final Clip clipBehavior;

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

    final content = Container(
      clipBehavior: clipBehavior,
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

  /// Returns the generated appCardTile template.
  static String appCardTile() => r'''
import 'package:flutter/material.dart';
import '../cards/app_card.dart';
import 'app_list_tile.dart';

/// An [AppListTile] on its own [AppCard] surface — a standalone, card-backed
/// row. Saves nesting the two by hand every time you want a single tappable
/// row that isn't part of a larger list. The whole card is the tap target.
class AppCardTile extends StatelessWidget {
  const AppCardTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.danger = false,
    this.cardType = AppCardType.filled,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Appends a trailing chevron when [trailing] is null — the usual "drills
  /// into another screen" affordance.
  final bool showChevron;

  /// Tints the title in the error color, for destructive rows.
  final bool danger;

  /// Surface treatment of the enclosing card.
  final AppCardType cardType;

  @override
  Widget build(BuildContext context) {
    // onTap lives on the card so the whole surface is the tap target; the
    // tile stays passive (its padding still shapes the content).
    return AppCard(
      type: cardType,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: AppListTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        showChevron: showChevron,
        danger: danger,
      ),
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
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppConstants.space12),
        itemBuilder: (context, index) => ListTile(
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
import 'package:flutter/services.dart';
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

    _feedback(type);

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
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onAction();
                },
              )
            : null,
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: AppToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: AppToastType.error);

  /// A toast usually lands while the user is looking somewhere else, so it
  /// says what happened by feel as well as by color — the worse the news, the
  /// heavier the tap.
  static void _feedback(AppToastType type) => switch (type) {
        AppToastType.success => HapticFeedback.lightImpact(),
        AppToastType.warning => HapticFeedback.mediumImpact(),
        AppToastType.error => HapticFeedback.heavyImpact(),
        AppToastType.info => HapticFeedback.selectionClick(),
      };

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
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Fill treatment of the sheet's close button.
///
/// Mirrors `AppIconButtonType`'s naming so it reads like the rest of the kit.
/// It is redeclared here rather than imported because this widget ships with
/// `moarch init` and AppIconButton does not — an init widget can only lean on
/// other init widgets.
enum AppSheetCloseType { filled, tonal, outlined, ghost }

/// The standard inside of a bottom sheet: a rounded surface panel with a drag
/// handle (grabber) at the top, an optional [title], an optional close button,
/// and your [child].
/// Pass this as the `child` to `AppBottomModals.showAppBottomModal`.
class AppBottomSheetScaffold extends StatelessWidget {
  const AppBottomSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
    this.padding = AppConstants.paddingPage,
    this.titleAlign = TextAlign.center,
    this.handleWidth = 40,
    this.handleHeight = 4,
    this.handleColor,
    this.showClose = false,
    this.onClose,
    this.closeIcon = Icons.close,
    this.closeType = AppSheetCloseType.tonal,
    this.closeColor,
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final EdgeInsetsGeometry padding;

  /// Centered reads as a modal, [TextAlign.start] as a panel. Pick one per app
  /// and keep to it.
  final TextAlign titleAlign;

  final double handleWidth;
  final double handleHeight;

  /// Defaults to a muted `onSurfaceVariant`. Worth overriding only when the
  /// sheet sits on a colored surface.
  final Color? handleColor;

  /// Shows a close button in the sheet's top corner. The drag handle already
  /// says "dismissable" — add this when the sheet is tall enough that the
  /// handle scrolls out of reach, or when dismissal needs to be obvious.
  final bool showClose;

  /// Overrides the default `Navigator.maybePop` — e.g. to confirm unsaved work.
  final VoidCallback? onClose;

  final IconData closeIcon;

  /// How the close button wears [closeColor]. Tonal gives the soft grey circle
  /// most sheets want; [AppSheetCloseType.ghost] is a bare glyph.
  final AppSheetCloseType closeType;

  /// Defaults to `onSurfaceVariant` — a close button is chrome, not an action,
  /// so it stays neutral unless you say otherwise.
  final Color? closeColor;

  /// Matches AppIconButton's `small` tap target, so a sheet close and an icon
  /// button elsewhere in the app are the same size.
  static const double _closeDimension = 32;
  static const double _closeTonalOpacity = 0.12;
  static const double _closeBorderWidth = 1.5;
  static const double _handleOpacity = 0.4;

  Widget _buildClose(BuildContext context, ThemeData theme) {
    final accent = closeColor ?? theme.colorScheme.onSurfaceVariant;
    final (background, foreground) = switch (closeType) {
      AppSheetCloseType.filled => (accent, theme.colorScheme.surface),
      AppSheetCloseType.tonal => (
          Color.alphaBlend(
            accent.withValues(alpha: _closeTonalOpacity),
            theme.colorScheme.surface,
          ),
          accent,
        ),
      AppSheetCloseType.outlined || AppSheetCloseType.ghost => (
          Colors.transparent,
          accent,
        ),
    };

    return Tooltip(
      message: MaterialLocalizations.of(context).closeButtonTooltip,
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: CircleBorder(
          side: closeType == AppSheetCloseType.outlined
              ? BorderSide(color: accent, width: _closeBorderWidth)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            if (onClose != null) {
              onClose!();
            } else {
              Navigator.maybePop(context);
            }
          },
          child: SizedBox.square(
            dimension: _closeDimension,
            child: Icon(
              closeIcon,
              size: AppConstants.iconSmall,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }

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
                  width: handleWidth,
                  height: handleHeight,
                  decoration: BoxDecoration(
                    color: handleColor ??
                        theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: _handleOpacity),
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
                  if (title != null || showClose) ...[
                    // A Stack rather than a Row: it keeps a centered title
                    // centered on the sheet instead of on the space left over
                    // beside the close button.
                    Stack(
                      alignment: AlignmentDirectional.centerEnd,
                      children: [
                        if (title != null)
                          Padding(
                            // Reserve the close button's width on both sides so
                            // a centered title doesn't drift left to avoid it.
                            padding: EdgeInsets.symmetric(
                              horizontal: showClose ? _closeDimension : 0,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                title!,
                                style: theme.textTheme.titleLarge,
                                textAlign: titleAlign,
                              ),
                            ),
                          ),
                        if (showClose) _buildClose(context, theme),
                      ],
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
    this.labelMode,
    this.variant,
    this.type,
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

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;

  /// The code cells have no decoration to host a label inside them, so every
  /// mode but [AppInputLabelMode.none] puts the title above them.
  AppInputLabelMode get _labelMode =>
      (labelMode ?? AppInputStyle.config.labelMode) == AppInputLabelMode.none
      ? AppInputLabelMode.none
      : AppInputLabelMode.above;

  Mo2FACellShape get _shape => switch (type ?? AppInputStyle.config.type) {
    AppInputType.filled => Mo2FACellShape.filled,
    AppInputType.outlined => Mo2FACellShape.outlined,
    AppInputType.underline => Mo2FACellShape.underline,
  };

  Mo2FACellVariant get _cellVariant =>
      switch (variant ?? AppInputStyle.config.variant) {
        AppInputVariant.primary => Mo2FACellVariant.primary,
        AppInputVariant.secondary => Mo2FACellVariant.secondary,
        AppInputVariant.tertiary => Mo2FACellVariant.tertiary,
        AppInputVariant.danger => Mo2FACellVariant.error,
      };

  @override
  Widget build(BuildContext context) {
    return InputFieldLayout(
      label: label,
      required: required,
      labelMode: _labelMode,
      variant: variant,
      field: Mo2FACodeField(
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

  /// Returns the generated appIconButton template.
  static String appIconButton() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Color role of [AppIconButton]. Mirrors [AppButtonVariant] and
/// [AppLeadingIconVariant] so every control speaks the same color vocabulary.
enum AppIconButtonVariant { primary, secondary, tertiary, danger }

/// Fill treatment of [AppIconButton] — how the variant color is applied.
///
/// - [filled]: solid variant background, contrasting icon.
/// - [tonal]: soft variant-tinted background, variant-colored icon.
/// - [outlined]: transparent background, variant-colored border + icon.
/// - [ghost]: no container at all — just the variant-colored icon.
enum AppIconButtonType { filled, tonal, outlined, ghost }

/// Corner shape of the tap target.
enum AppIconButtonShape { rounded, circle }

enum AppIconButtonSize { small, medium, large }

typedef _IconButtonSizeConfig = ({double container, double icon});

/// A tappable icon — [AppLeadingIcon]'s interactive sibling. Same color
/// vocabulary, but with a ripple, haptics, a loading state and a real touch
/// target. Use [AppLeadingIcon] when the icon is decoration, this when it does
/// something.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = AppIconButtonVariant.primary,
    this.type = AppIconButtonType.ghost,
    this.shape = AppIconButtonShape.circle,
    this.size = AppIconButtonSize.medium,
    this.tooltip,
    this.isLoading = false,
    this.color,
  });

  final IconData icon;

  /// Tap handler. Pass null to render the button in its disabled state.
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;
  final AppIconButtonType type;
  final AppIconButtonShape shape;
  final AppIconButtonSize size;

  /// Long-press label. Worth setting on every icon button — an icon on its own
  /// rarely names itself, and screen readers have nothing else to read.
  final String? tooltip;

  /// Replaces the icon with a spinner and ignores taps, keeping the same size
  /// so the surrounding layout doesn't jump.
  final bool isLoading;

  /// Overrides [variant]'s accent color. For the control that has to match a
  /// color the variant vocabulary doesn't name — a status tint, say. Reach for
  /// a [variant] first; this is the escape hatch.
  final Color? color;

  static const double _tonalFillOpacity = 0.12;
  static const double _outlinedBorderWidth = 1.5;
  static const double _disabledOpacity = 0.38;

  /// The tap target's outer dimension for [size]. Public so a layout that has
  /// to reserve room for the button — an AppBar's leading slot, say — can size
  /// that slot instead of guessing at it.
  static double dimensionOf(AppIconButtonSize size) => switch (size) {
        AppIconButtonSize.small => 32.0,
        AppIconButtonSize.medium => AppConstants.touchTarget,
        AppIconButtonSize.large => AppConstants.touchTarget + 16,
      };

  _IconButtonSizeConfig _sizeConfig() => (
        container: dimensionOf(size),
        icon: switch (size) {
          AppIconButtonSize.small => AppConstants.iconSmall,
          AppIconButtonSize.medium => AppConstants.iconMedium,
          AppIconButtonSize.large => AppConstants.iconLarge,
        },
      );

  /// The accent color, plus the color that reads on top of it.
  (Color, Color) _colorsOf(ThemeData theme) {
    final override = color;
    if (override != null) {
      // No colorScheme pair exists for an arbitrary color, so pick whichever
      // of black/white keeps the filled treatment legible.
      return (
        override,
        ThemeData.estimateBrightnessForColor(override) == Brightness.dark
            ? Colors.white
            : Colors.black,
      );
    }
    return switch (variant) {
      AppIconButtonVariant.primary => (
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary,
        ),
      AppIconButtonVariant.secondary => (
          theme.colorScheme.secondary,
          theme.colorScheme.onSecondary,
        ),
      AppIconButtonVariant.tertiary => (
          theme.colorScheme.tertiary,
          theme.colorScheme.onTertiary,
        ),
      AppIconButtonVariant.danger => (
          theme.colorScheme.error,
          theme.colorScheme.onError,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final sizeConfig = _sizeConfig();
    final (accent, onAccent) = _colorsOf(theme);
    final enabled = onPressed != null && !isLoading;

    // Variant chooses the color; type only decides how that color is applied.
    final (backgroundColor, foregroundColor) = switch (type) {
      AppIconButtonType.filled => (accent, onAccent),
      AppIconButtonType.tonal => (
          Color.alphaBlend(
            accent.withValues(alpha: _tonalFillOpacity),
            theme.colorScheme.surface,
          ),
          accent,
        ),
      AppIconButtonType.outlined || AppIconButtonType.ghost => (
          Colors.transparent,
          accent,
        ),
    };

    // A disabled button stays its variant, just faded — never a generic grey.
    final resolvedForeground = enabled
        ? foregroundColor
        : foregroundColor.withValues(alpha: _disabledOpacity);
    final resolvedBackground = enabled
        ? backgroundColor
        : backgroundColor.withValues(alpha: _disabledOpacity);

    final border = type == AppIconButtonType.outlined
        ? BorderSide(color: resolvedForeground, width: _outlinedBorderWidth)
        : BorderSide.none;

    final button = Material(
      color: resolvedBackground,
      clipBehavior: Clip.antiAlias,
      shape: shape == AppIconButtonShape.circle
          ? CircleBorder(side: border)
          : RoundedRectangleBorder(
              borderRadius: AppConstants.borderRadius12,
              side: border,
            ),
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onPressed!();
              }
            : null,
        child: SizedBox.square(
          dimension: sizeConfig.container,
          child: isLoading
              ? Center(
                  child: SizedBox.square(
                    dimension: sizeConfig.icon,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: resolvedForeground,
                    ),
                  ),
                )
              : Icon(icon, size: sizeConfig.icon, color: resolvedForeground),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
''';

  /// Returns the generated appAppBar template.
  static String appAppBar() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import '../buttons/app_icon_button.dart';

/// The app's [AppBar]: one title treatment, an optional supporting line, and
/// a back button that only appears when there is something to go back to.
///
/// The back button is an [AppIconButton], so it takes the same
/// variant/type/shape/size vocabulary as every other control in the kit —
/// `backType: AppIconButtonType.ghost` for a bare arrow, `.filled` for a solid
/// one. It defaults to a tonal circle.
///
/// Implements [PreferredSizeWidget], so it drops straight into
/// `Scaffold(appBar: AppAppBar(title: 'Settings'))`.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.centerTitle = false,
    this.showBack = true,
    this.onBack,
    this.bottom,
    this.backgroundColor,
    this.backIcon = Icons.arrow_back,
    this.backVariant = AppIconButtonVariant.primary,
    this.backType = AppIconButtonType.tonal,
    this.backShape = AppIconButtonShape.circle,
    this.backSize = AppIconButtonSize.medium,
  });

  final String? title;

  /// Small supporting line under [title] — a count, a status, a date.
  final String? subtitle;

  /// Replaces the automatic back button entirely. When set, every `back*`
  /// option below is ignored — you own the slot.
  final Widget? leading;
  final List<Widget> actions;
  final bool centerTitle;

  /// Shows a back button when the route can actually pop. Leave it on: it is
  /// already a no-op on a root route. Set false for tab roots that can pop but
  /// shouldn't offer to.
  final bool showBack;

  /// Overrides the default `Navigator.maybePop` — e.g. to confirm unsaved work.
  final VoidCallback? onBack;

  /// A [TabBar] or any other bar below the toolbar.
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  /// Swap for `Icons.arrow_back_ios_new` on an iOS-leaning design, or
  /// `Icons.close` when the screen reads as a dismissable sheet.
  final IconData backIcon;

  /// Color role of the back button.
  final AppIconButtonVariant backVariant;

  /// How the back button wears its color. [AppIconButtonType.tonal] gives the
  /// soft tinted container; [AppIconButtonType.ghost] the bare arrow.
  final AppIconButtonType backType;
  final AppIconButtonShape backShape;
  final AppIconButtonSize backSize;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight +
            (subtitle == null ? 0 : AppConstants.space12) +
            (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final canPop = Navigator.of(context).canPop();
    final showsOwnBack = leading == null && showBack && canPop;

    return AppBar(
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.5,
      centerTitle: centerTitle,
      toolbarHeight: preferredSize.height - (bottom?.preferredSize.height ?? 0),
      // The leading slot is resolved here, so `automaticallyImplyLeading`
      // would only ever fight it.
      automaticallyImplyLeading: false,
      // The default 56pt slot clips a container-bearing button at the larger
      // sizes, so the slot is measured from the button rather than assumed.
      leadingWidth: showsOwnBack
          ? AppIconButton.dimensionOf(backSize) + AppConstants.space16
          : null,
      leading: leading ??
          (showsOwnBack
              ? Center(
                  child: AppIconButton(
                    icon: backIcon,
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                    variant: backVariant,
                    type: backType,
                    shape: backShape,
                    size: backSize,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                  ),
                )
              : null),
      title: title == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: AppConstants.fontSize20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
      actions: actions,
      bottom: bottom,
    );
  }
}
''';

  /// Returns the generated appBanner template.
  static String appBanner() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import '../buttons/app_icon_button.dart';
import '../indicators/app_tag.dart';

/// An inline status message — the calm, persistent counterpart to AppToast.
/// Use a banner for something that stays true while the screen is open
/// ("You're offline", "Verify your email"), and a toast for something that
/// just happened.
///
/// Colors come from [AppTagStatus], shared with [AppTag], so a banner and a
/// pill about the same thing read as the same thing.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.title,
    this.status = AppTagStatus.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.dismissIcon = Icons.close,
    this.dismissType = AppIconButtonType.ghost,
    this.dismissShape = AppIconButtonShape.circle,
  });

  final String message;

  /// Optional bold first line. Skip it for one-sentence banners.
  final String? title;
  final AppTagStatus status;

  /// Overrides the status's default icon.
  final IconData? icon;

  /// Inline text action — "Retry", "Verify now". Shown only when [onAction]
  /// is also set.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shows a close button when set. Leave it null for a banner the user
  /// shouldn't be able to wave away.
  final VoidCallback? onDismiss;

  final IconData dismissIcon;

  /// How the dismiss button wears the [status] color. Ghost keeps the banner
  /// quiet; [AppIconButtonType.tonal] gives the close a soft container of its
  /// own, which helps when the banner is long enough to hunt for it.
  final AppIconButtonType dismissType;
  final AppIconButtonShape dismissShape;

  static const double _fillOpacity = 0.10;
  static const double _borderOpacity = 0.35;

  Color _colorOf(ThemeData theme) => switch (status) {
        AppTagStatus.neutral => theme.colorScheme.onSurfaceVariant,
        AppTagStatus.success => AppConstants.success,
        AppTagStatus.warning => AppConstants.warning,
        AppTagStatus.error => theme.colorScheme.error,
        AppTagStatus.info => AppConstants.info,
      };

  IconData _iconOf() => switch (status) {
        AppTagStatus.neutral => Icons.info_outline,
        AppTagStatus.success => Icons.check_circle_outline,
        AppTagStatus.warning => Icons.warning_amber_outlined,
        AppTagStatus.error => Icons.error_outline,
        AppTagStatus.info => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = _colorOf(theme);

    return Container(
      padding: AppConstants.padding12,
      decoration: BoxDecoration(
        color: color.withValues(alpha: _fillOpacity),
        borderRadius: AppConstants.borderRadius12,
        border: Border.all(color: color.withValues(alpha: _borderOpacity)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _iconOf(), color: color, size: AppConstants.iconMedium),
          const SizedBox(width: AppConstants.space12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppConstants.space4),
                  // A bare text action keeps the banner quiet: it is
                  // information first, a call to action second.
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onAction!();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: AppConstants.space4),
            AppIconButton(
              icon: dismissIcon,
              onPressed: onDismiss,
              // The banner's color comes from AppTagStatus, which the variant
              // vocabulary doesn't name — hence the explicit override.
              color: color,
              type: dismissType,
              shape: dismissShape,
              size: AppIconButtonSize.small,
              tooltip: 'Dismiss',
            ),
          ],
        ],
      ),
    );
  }
}
''';

  /// Returns the generated appProgressBar template.
  static String appProgressBar() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import '../inputs/app_input_style.dart';

/// Thickness of [AppProgressBar].
enum AppProgressBarSize { small, medium, large }

/// A linear progress bar colored from [AppInputVariant].
///
/// Pass a [value] between 0 and 1 for determinate progress (an upload, a
/// wizard); leave it null for the indeterminate sweep. Prefer a determinate
/// bar whenever you can actually measure the work — it is the difference
/// between "this is going somewhere" and "this is stuck".
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    this.value,
    this.label,
    this.variant,
    this.size = AppProgressBarSize.medium,
    this.showPercent = false,
  });

  /// 0..1 (clamped), or null for an indeterminate bar.
  final double? value;

  /// Caption above the bar, e.g. "Uploading photo".
  final String? label;
  final AppInputVariant? variant;
  final AppProgressBarSize size;

  /// Shows the rounded percentage at the end of the caption row. Ignored while
  /// [value] is null — an indeterminate bar has no percentage to show.
  final bool showPercent;

  static const double _trackOpacity = 0.15;

  double get _thickness => switch (size) {
        AppProgressBarSize.small => 4,
        AppProgressBarSize.medium => 8,
        AppProgressBarSize.large => 12,
      };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accent = AppInputStyle.accentOf(context, variant);
    final progress = value?.clamp(0.0, 1.0).toDouble();
    final percent = progress == null ? null : (progress * 100).round();

    final bar = ClipRRect(
      borderRadius: AppConstants.borderRadiusFull,
      child: LinearProgressIndicator(
        value: progress,
        minHeight: _thickness,
        color: accent,
        backgroundColor: accent.withValues(alpha: _trackOpacity),
      ),
    );

    final showsCaption = label != null || (showPercent && percent != null);
    if (!showsCaption) return bar;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (label != null)
              Expanded(
                child: Text(
                  label!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (showPercent && percent != null)
              Text(
                '$percent%',
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
          ],
        ),
        const SizedBox(height: AppConstants.space4),
        bar,
      ],
    );
  }
}
''';

  /// Returns the generated appSearchField template.
  static String appSearchField() => r'''
import 'package:flutter/material.dart';

import '../buttons/app_icon_button.dart';
import './app_input_style.dart';

/// A search field: leading search icon, plus a clear button that appears only
/// once there is something to clear.
///
/// Wire [onChanged] straight to your filter for a local list. For a remote
/// search, put a debouncer between them (see
/// core/services/debouncer_service.dart) so you aren't firing a request per
/// keystroke.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.variant,
    this.type,
    this.shape,
    this.size,
    this.autofocus = false,
    this.enabled = true,
    this.searchIcon = Icons.search,
    this.clearIcon = Icons.close,
    this.clearVariant = AppIconButtonVariant.primary,
    this.clearType = AppIconButtonType.ghost,
    this.clearShape = AppIconButtonShape.circle,
  });

  /// Optional external controller — pass one to read or clear the query from
  /// outside. When omitted, the field owns (and disposes) its own.
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;
  final bool autofocus;
  final bool enabled;

  /// The leading icon. `Icons.search` reads as "find"; swap it for
  /// `Icons.filter_list` when the field narrows a list you're already looking
  /// at.
  final IconData searchIcon;

  final IconData clearIcon;
  final AppIconButtonVariant clearVariant;

  /// How the clear button wears its color. [AppIconButtonType.tonal] turns it
  /// into a small filled chip, which is easier to hit on a busy toolbar.
  final AppIconButtonType clearType;
  final AppIconButtonShape clearShape;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  /// Only dispose what this widget created — an injected controller belongs to
  /// the caller and may well outlive the field.
  late final bool _ownsController = widget.controller == null;

  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// Rebuilds only when the clear button has to appear or disappear, not on
  /// every keystroke.
  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      style: AppInputStyle.textStyle(context, size: widget.size),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: AppInputStyle.decoration(
        context,
        variant: widget.variant,
        type: widget.type,
        shape: widget.shape,
        size: widget.size,
        hint: widget.hint,
        enabled: widget.enabled,
        prefixIcon: Icon(widget.searchIcon),
        suffixIcon: _hasText
            ? AppIconButton(
                icon: widget.clearIcon,
                onPressed: _clear,
                variant: widget.clearVariant,
                type: widget.clearType,
                shape: widget.clearShape,
                size: AppIconButtonSize.small,
                tooltip: 'Clear',
              )
            : null,
      ),
    );
  }
}
''';

  /// Returns the generated appStepper template.
  static String appStepper() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import './app_input_style.dart';

/// A quantity stepper — "− 2 +". For picking a small count, where a slider
/// would be imprecise and a text field is overkill.
///
/// The buttons disable themselves at [min] and [max], so the value can never
/// leave the range you allow.
class AppStepper extends StatelessWidget {
  const AppStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    this.variant,
    this.size,
  });

  final int value;

  /// Pass null to render the whole stepper disabled.
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;

  /// How much one tap moves the value.
  final int step;
  final AppInputVariant? variant;
  final AppInputSize? size;

  static const double _fillOpacity = 0.06;
  static const double _borderOpacity = 0.25;
  static const double _disabledOpacity = 0.35;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accent = AppInputStyle.accentOf(context, variant);
    final sizeConfig = AppInputStyle.configOf(size);
    final enabled = onChanged != null;

    void emit(int next) {
      HapticFeedback.selectionClick();
      onChanged!(next.clamp(min, max));
    }

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _fillOpacity),
        borderRadius: AppConstants.borderRadiusFull,
        border: Border.all(color: accent.withValues(alpha: _borderOpacity)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            color: accent,
            iconSize: sizeConfig.iconSize,
            disabledOpacity: _disabledOpacity,
            onTap: enabled && value > min ? () => emit(value - step) : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: AppConstants.space32),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: sizeConfig.fontSize,
                color: enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface
                        .withValues(alpha: _disabledOpacity),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            color: accent,
            iconSize: sizeConfig.iconSize,
            disabledOpacity: _disabledOpacity,
            onTap: enabled && value < max ? () => emit(value + step) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.color,
    required this.iconSize,
    required this.disabledOpacity,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final double iconSize;
  final double disabledOpacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: AppConstants.padding8,
        child: Icon(
          icon,
          size: iconSize,
          color:
              onTap == null ? color.withValues(alpha: disabledOpacity) : color,
        ),
      ),
    );
  }
}
''';

  /// Returns the generated appSectionHeader template.
  static String appSectionHeader() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A heading above a group of rows or cards: a title, an optional supporting
/// line, and an optional text action on the right ("See all", "Edit").
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(vertical: AppConstants.space8),
  });

  final String title;
  final String? subtitle;

  /// Trailing text action. Shown only when [onAction] is also set.
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onAction!();
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
''';

  /// Returns the generated appExpansionTile template.
  static String appExpansionTile() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A collapsible section, themed to match [AppListTile] and [AppCard].
///
/// The stock [ExpansionTile] draws its own top and bottom rules from the
/// ambient divider color; this one is borderless, so it can sit inside an
/// [AppCard] without doubling up on edges.
class AppExpansionTile extends StatelessWidget {
  const AppExpansionTile({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.childrenPadding = AppConstants.padding12,
  });

  final String title;
  final List<Widget> children;
  final String? subtitle;

  /// Usually an AppLeadingIcon.
  final Widget? leading;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry childrenPadding;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final shape = RoundedRectangleBorder(
      borderRadius: AppConstants.borderRadius12,
    );

    return Theme(
      // ExpansionTile reads dividerColor off the ambient theme; blanking it
      // here is the only way to drop its rules.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(title, style: theme.textTheme.bodyLarge),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        leading: leading,
        initiallyExpanded: initiallyExpanded,
        // The header is the tap target, so the haptic goes here whether or not
        // the caller cares about the new state.
        onExpansionChanged: (expanded) {
          HapticFeedback.selectionClick();
          onExpansionChanged?.call(expanded);
        },
        shape: shape,
        collapsedShape: shape,
        iconColor: theme.colorScheme.primary,
        collapsedIconColor: theme.colorScheme.onSurfaceVariant,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.space12,
        ),
        childrenPadding: childrenPadding,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
''';

  /// Returns the generated appSingleScrollView template.
  static String appSingleScrollView() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// The standard scrollable page body: one [SingleChildScrollView] with the
/// safe area, the page padding and the keyboard behaviour already decided, so
/// screens stop re-deciding them one at a time.
///
/// ```dart
/// Scaffold(
///   appBar: const AppAppBar(title: 'Profile'),
///   // The app bar already ate the top inset, so the body doesn't inset again.
///   body: AppSingleScrollView(
///     safeAreaTop: false,
///     child: Column(children: [...]),
///   ),
/// )
/// ```
///
/// Vertical by design — it is a page scroller, not a general-purpose one. And
/// it builds its whole [child] whether or not any of it is on screen, so for a
/// long or repeating list reach for `ListView.builder` instead.
class AppSingleScrollView extends StatelessWidget {
  const AppSingleScrollView({
    super.key,
    required this.child,
    this.padding = AppConstants.padding12,
    this.safeArea = true,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.safeAreaHorizontal = true,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.avoidKeyboard = false,
    this.fillViewport = false,
    this.alwaysScrollable = false,
    this.physics,
    this.controller,
    this.reverse = false,
  });

  final Widget child;

  /// Inset around [child], inside the safe area.
  final EdgeInsets padding;

  /// Master switch for the safe area. Off means the content runs under the
  /// notch, the status bar and the home indicator — for a screen that paints
  /// itself edge to edge and insets whatever needs it by hand.
  final bool safeArea;

  /// Whether the top inset is honoured. Set false under an [AppBar]: it has
  /// already consumed the status bar, and insetting twice leaves a gap.
  final bool safeAreaTop;

  /// Whether the bottom inset is honoured — the home indicator, mainly. Set
  /// false when a bottom bar or a pinned footer below this one already takes
  /// it.
  final bool safeAreaBottom;

  /// Whether the side insets are honoured. They only amount to anything in
  /// landscape on a notched phone, which is exactly when they matter.
  final bool safeAreaHorizontal;

  /// What dragging does to an open keyboard.
  /// [ScrollViewKeyboardDismissBehavior.onDrag] — the default — closes it as
  /// soon as the user scrolls, which is what a form wants.
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// Adds the keyboard's height to the bottom padding, so the content can
  /// scroll clear of it.
  ///
  /// Leave this off inside a normal [Scaffold]: `resizeToAvoidBottomInset`
  /// already shrinks the body, and doing both leaves a gap the height of the
  /// keyboard. Turn it on in a bottom sheet, a dialog, or a Scaffold with
  /// `resizeToAvoidBottomInset: false`.
  final bool avoidKeyboard;

  /// Stretches [child] to at least the height of the viewport, so a short page
  /// can still push a footer down with a [Spacer] or an [Expanded] while a
  /// tall one scrolls as usual.
  ///
  /// Costs an [IntrinsicHeight] pass over the child, so leave it off for a
  /// page that is taller than the screen anyway.
  final bool fillViewport;

  /// Lets the view scroll — and so bounce, and so drive a [RefreshIndicator] —
  /// even when the content is shorter than the viewport. Ignored when
  /// [physics] is set.
  final bool alwaysScrollable;

  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool reverse;

  Widget _scrollView(Widget content, EdgeInsets resolvedPadding) {
    return SingleChildScrollView(
      padding: resolvedPadding,
      controller: controller,
      reverse: reverse,
      keyboardDismissBehavior: keyboardDismissBehavior,
      physics: physics ??
          (alwaysScrollable ? const AlwaysScrollableScrollPhysics() : null),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = avoidKeyboard
        ? padding.copyWith(
            bottom: padding.bottom + MediaQuery.viewInsetsOf(context).bottom,
          )
        : padding;

    Widget scrollView = _scrollView(child, resolvedPadding);

    if (fillViewport) {
      scrollView = LayoutBuilder(
        builder: (context, constraints) {
          // Nested inside another scrollable there is no viewport height to
          // fill, so the child just takes the height it asks for.
          final available = constraints.hasBoundedHeight
              ? (constraints.maxHeight - resolvedPadding.vertical)
                  .clamp(0.0, double.infinity)
              : 0.0;

          return _scrollView(
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: available),
              // A minimum alone leaves the child's height unbounded, and an
              // Expanded inside it would throw; this gives it a height to
              // divide up.
              child: IntrinsicHeight(child: child),
            ),
            resolvedPadding,
          );
        },
      );
    }

    if (!safeArea) return scrollView;

    return SafeArea(
      top: safeAreaTop,
      bottom: safeAreaBottom,
      left: safeAreaHorizontal,
      right: safeAreaHorizontal,
      // Without this the bottom inset collapses the moment the keyboard opens,
      // and the content jumps by the height of the home indicator.
      maintainBottomViewPadding: true,
      child: scrollView,
    );
  }
}
''';

  /// Returns the generated appStepIndicator template.
  static String appStepIndicator() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import '../inputs/app_input_style.dart';

/// Shape of [AppStepIndicator].
///
/// - [dots]: a row of dots — compact, for carousels and onboarding.
/// - [bars]: filled segments — reads as progress, best for wizards.
/// - [numbered]: numbered circles with optional captions, for named steps.
enum AppStepIndicatorType { dots, bars, numbered }

/// Shows where the user is in a multi-step flow. Steps before [currentStep]
/// render as done, the current one is highlighted, and later steps stay muted.
class AppStepIndicator extends StatelessWidget {
  const AppStepIndicator({
    super.key,
    required this.currentStep,
    required this.stepCount,
    this.labels = const [],
    this.type = AppStepIndicatorType.bars,
    this.variant,
  });

  /// Zero-based index of the active step.
  final int currentStep;
  final int stepCount;

  /// Per-step captions. Only used by [AppStepIndicatorType.numbered]; a short
  /// or empty list just means fewer captions, never an error.
  final List<String> labels;
  final AppStepIndicatorType type;
  final AppInputVariant? variant;

  static const double _mutedOpacity = 0.2;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);

    Color colorFor(int index) => index <= currentStep
        ? accent
        : accent.withValues(alpha: _mutedOpacity);

    return switch (type) {
      AppStepIndicatorType.dots => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < stepCount; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.space4,
                ),
                child: AnimatedContainer(
                  duration: AppConstants.duration200,
                  height: AppConstants.space8,
                  // The active dot stretches rather than growing, so the row
                  // keeps its rhythm.
                  width: i == currentStep
                      ? AppConstants.space24
                      : AppConstants.space8,
                  decoration: BoxDecoration(
                    color: colorFor(i),
                    borderRadius: AppConstants.borderRadiusFull,
                  ),
                ),
              ),
          ],
        ),
      AppStepIndicatorType.bars => Row(
          children: [
            for (var i = 0; i < stepCount; i++) ...[
              if (i > 0) const SizedBox(width: AppConstants.space4),
              Expanded(
                child: AnimatedContainer(
                  duration: AppConstants.duration200,
                  height: AppConstants.space4,
                  decoration: BoxDecoration(
                    color: colorFor(i),
                    borderRadius: AppConstants.borderRadiusFull,
                  ),
                ),
              ),
            ],
          ],
        ),
      AppStepIndicatorType.numbered => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < stepCount; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(
                      top: AppConstants.space12,
                      left: AppConstants.space4,
                      right: AppConstants.space4,
                    ),
                    color: colorFor(i),
                  ),
                ),
              _NumberedStep(
                index: i,
                currentStep: currentStep,
                accent: accent,
                label: i < labels.length ? labels[i] : null,
              ),
            ],
          ],
        ),
    };
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.index,
    required this.currentStep,
    required this.accent,
    required this.label,
  });

  final int index;
  final int currentStep;
  final Color accent;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDone = index < currentStep;
    final isCurrent = index == currentStep;
    final reached = isDone || isCurrent;

    // The accent can be any variant color, so the label inside the filled
    // circle is picked from the accent's own brightness rather than assuming
    // onPrimary.
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppConstants.space24,
            height: AppConstants.space24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reached ? accent : Colors.transparent,
              border: Border.all(
                color: reached ? accent : accent.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: isDone
                ? Icon(Icons.check, size: 14, color: onAccent)
                : Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isCurrent
                          ? onAccent
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          if (label != null) ...[
            const SizedBox(height: AppConstants.space4),
            Text(
              label!,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: reached
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
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
import '../widgets/buttons/app_icon_button.dart';
import '../widgets/cards/app_card.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/feedback/app_banner.dart';
import '../widgets/feedback/app_progress_bar.dart';
import '../widgets/icons/app_leading_icon.dart';
import '../widgets/indicators/app_badge.dart';
import '../widgets/indicators/app_tag.dart';
import '../widgets/inputs/app_checkbox.dart';
import '../widgets/inputs/app_checkbox_label.dart';
import '../widgets/inputs/app_choice_chip.dart';
import '../widgets/inputs/app_date_input.dart';
import '../widgets/inputs/app_dropdown_input.dart';
import '../widgets/inputs/app_input.dart';
import '../widgets/inputs/app_input_format.dart';
import '../widgets/inputs/app_input_style.dart';
import '../widgets/inputs/app_otp_input.dart';
import '../widgets/inputs/app_radio_group.dart';
import '../widgets/inputs/app_search_field.dart';
import '../widgets/inputs/app_segmented.dart';
import '../widgets/inputs/app_slider.dart';
import '../widgets/inputs/app_stepper.dart';
import '../widgets/inputs/app_switch.dart';
import '../widgets/inputs/app_time_input.dart';
import '../widgets/layouts/app_single_scroll_view.dart';
import '../widgets/lists/app_card_tile.dart';
import '../widgets/lists/app_expansion_tile.dart';
import '../widgets/lists/app_list_tile.dart';
import '../widgets/lists/app_section_header.dart';
import '../widgets/loadings/app_loading_action_overlay.dart';
import '../widgets/loadings/app_loading_data.dart';
import '../widgets/loadings/app_screen_lock.dart';
import '../widgets/loadings/app_skeleton_list.dart';
import '../widgets/media/app_avatar.dart';
import '../widgets/media/app_image.dart';
import '../widgets/navigation/app_app_bar.dart';
import '../widgets/navigation/app_bottom_nav.dart';
import '../widgets/navigation/app_step_indicator.dart';
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
  bool _plainCheckbox = true;
  int _quantity = 1;
  int _wizardStep = 1;
  double _progress = 0.45;
  bool _bannerVisible = true;
  bool _overlayLoading = false;
  String _query = '';

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
          // The screen's own chrome is AppAppBar, so this doubles as its
          // preview — subtitle, actions and all.
          appBar: AppAppBar(
            title: 'Design System',
            subtitle: 'Every shared widget, in your theme',
            showBack: false,
            actions: [
              AppIconButton(
                icon: _mode == ThemeMode.light
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                onPressed: _toggleTheme,
                tooltip: 'Toggle theme',
              ),
              const SizedBox(width: AppConstants.space8),
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
              const _Section(
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
              const _Section(
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
                title: 'AppInput — label modes',
                child: Column(
                  children: [
                    // Whichever of these you like, set it once as
                    // AppInputConfig.defaults.labelMode and every input in the
                    // app follows — these four override it per field.
                    for (final mode in AppInputLabelMode.values) ...[
                      AppInput(
                        label: 'Label mode: ${mode.name}',
                        hint: 'Hint text',
                        required: true,
                        labelMode: mode,
                      ),
                      const SizedBox(height: AppConstants.space12),
                    ],
                  ],
                ),
              ),

              _Section(
                title: 'AppInput — formats',
                child: Column(
                  children: [
                    // Each format brings its own keyboard, live formatting and
                    // validation rule — type into them to see it.
                    for (final format in AppInputFormat.values) ...[
                      AppInput(
                        label: format.name,
                        hint: 'Format: ${format.name}',
                        format: format,
                      ),
                      const SizedBox(height: AppConstants.space12),
                    ],
                  ],
                ),
              ),

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
                    const AppInput(
                      label: 'secondary + underline',
                      hint: 'Composed',
                      variant: AppInputVariant.secondary,
                      type: AppInputType.underline,
                    ),
                    const SizedBox(height: AppConstants.space12),
                    const AppInput(
                      label: 'tertiary + outlined + pill',
                      hint: 'Composed',
                      variant: AppInputVariant.tertiary,
                      type: AppInputType.outlined,
                      shape: AppInputShape.pill,
                    ),
                    const SizedBox(height: AppConstants.space12),
                    const AppInput(
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
              const _Section(
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
                  height: 320,
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

              // ── AppSingleScrollView ───────────────────────────────────────
              _Section(
                title: 'AppSingleScrollView',
                child: SizedBox(
                  // Boxed and safe-area-free only so it can be previewed
                  // inside this list; on a real screen it is the whole body.
                  height: 160,
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: AppSingleScrollView(
                      safeArea: false,
                      child: Column(
                        children: [
                          for (var i = 1; i <= 8; i++)
                            AppListTile(title: 'Scrollable row $i'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── AppTag & AppBadge ─────────────────────────────────────────
              const _Section(
                title: 'AppTag & AppBadge',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
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
                    SizedBox(height: AppConstants.space16),
                    Row(
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
              const _Section(
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

              // ── AppIconButton ─────────────────────────────────────────────
              _Section(
                title: 'AppIconButton',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Types (primary):'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space12,
                      runSpacing: AppConstants.space12,
                      children: [
                        for (final type in AppIconButtonType.values)
                          AppIconButton(
                            icon: Icons.favorite_outline,
                            type: type,
                            tooltip: type.name,
                            onPressed: () {},
                          ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Variants (tonal):'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space12,
                      runSpacing: AppConstants.space12,
                      children: [
                        for (final variant in AppIconButtonVariant.values)
                          AppIconButton(
                            icon: Icons.share_outlined,
                            variant: variant,
                            type: AppIconButtonType.tonal,
                            tooltip: variant.name,
                            onPressed: () {},
                          ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Sizes, shape & states:'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space12,
                      runSpacing: AppConstants.space12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final size in AppIconButtonSize.values)
                          AppIconButton(
                            icon: Icons.edit_outlined,
                            type: AppIconButtonType.filled,
                            size: size,
                            tooltip: size.name,
                            onPressed: () {},
                          ),
                        AppIconButton(
                          icon: Icons.delete_outline,
                          variant: AppIconButtonVariant.danger,
                          type: AppIconButtonType.outlined,
                          shape: AppIconButtonShape.rounded,
                          tooltip: 'rounded',
                          onPressed: () {},
                        ),
                        const AppIconButton(
                          icon: Icons.cloud_upload_outlined,
                          type: AppIconButtonType.tonal,
                          isLoading: true,
                        ),
                        const AppIconButton(
                          icon: Icons.block,
                          type: AppIconButtonType.filled,
                          tooltip: 'disabled',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── AppSearchField ────────────────────────────────────────────
              _Section(
                title: 'AppSearchField',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSearchField(
                      hint: 'Search transactions',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: AppConstants.space8),
                    Text(
                      _query.isEmpty ? 'Query: (empty)' : 'Query: $_query',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppConstants.space12),
                    const AppSearchField(
                      hint: 'Outlined + rounded',
                      variant: AppInputVariant.secondary,
                      type: AppInputType.outlined,
                      shape: AppInputShape.rounded,
                    ),
                  ],
                ),
              ),

              // ── AppStepper ────────────────────────────────────────────────
              _Section(
                title: 'AppStepper',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quantity'),
                    AppStepper(
                      value: _quantity,
                      min: 1,
                      max: 10,
                      onChanged: (v) => setState(() => _quantity = v),
                    ),
                  ],
                ),
              ),

              // ── AppCheckbox ───────────────────────────────────────────────
              _Section(
                title: 'AppCheckbox — shapes',
                child: Row(
                  children: [
                    AppCheckbox(
                      value: _plainCheckbox,
                      onChanged: (v) =>
                          setState(() => _plainCheckbox = v ?? false),
                    ),
                    const SizedBox(width: AppConstants.space16),
                    AppCheckbox(
                      value: _plainCheckbox,
                      shape: AppInputShape.pill,
                      variant: AppInputVariant.tertiary,
                      onChanged: (v) =>
                          setState(() => _plainCheckbox = v ?? false),
                    ),
                  ],
                ),
              ),

              // ── Date & time inputs ────────────────────────────────────────
              _Section(
                title: 'AppDateInput / AppTimeInput',
                child: Column(
                  children: [
                    AppDateInput(
                      label: 'Date of birth',
                      hint: 'Pick a date',
                      required: true,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: AppConstants.space12),
                    AppTimeInput(
                      label: 'Reminder',
                      hint: 'Pick a time',
                      variant: AppInputVariant.secondary,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),

              // ── AppSectionHeader ──────────────────────────────────────────
              _Section(
                title: 'AppSectionHeader',
                child: AppSectionHeader(
                  title: 'Recent activity',
                  subtitle: 'Last 30 days',
                  actionLabel: 'See all',
                  onAction: () {},
                ),
              ),

              // ── AppCardTile ───────────────────────────────────────────────
              _Section(
                title: 'AppCardTile',
                child: Column(
                  children: [
                    AppCardTile(
                      leading: const AppLeadingIcon(
                        icon: Icons.credit_card_outlined,
                      ),
                      title: 'Payment method',
                      subtitle: 'Visa ending 4242',
                      showChevron: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: AppConstants.space8),
                    AppCardTile(
                      cardType: AppCardType.outlined,
                      leading: const AppLeadingIcon(
                        icon: Icons.receipt_long_outlined,
                        variant: AppLeadingIconVariant.tertiary,
                      ),
                      title: 'Billing history',
                      showChevron: true,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              // ── AppExpansionTile ──────────────────────────────────────────
              const _Section(
                title: 'AppExpansionTile',
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      AppExpansionTile(
                        title: 'Shipping options',
                        subtitle: 'Standard, express, pickup',
                        leading: AppLeadingIcon(
                          icon: Icons.local_shipping_outlined,
                        ),
                        initiallyExpanded: true,
                        children: [
                          Text('Standard — 3-5 business days, free.'),
                          SizedBox(height: AppConstants.space8),
                          Text('Express — next business day.'),
                        ],
                      ),
                      AppExpansionTile(
                        title: 'Returns',
                        children: [Text('30 days, no questions asked.')],
                      ),
                    ],
                  ),
                ),
              ),

              // ── AppBanner ─────────────────────────────────────────────────
              _Section(
                title: 'AppBanner',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_bannerVisible) ...[
                      AppBanner(
                        title: 'Verify your email',
                        message:
                            'We sent a link to jane@example.com. Verify to enable payouts.',
                        status: AppTagStatus.warning,
                        actionLabel: 'Resend link',
                        onAction: () {},
                        onDismiss: () =>
                            setState(() => _bannerVisible = false),
                      ),
                      const SizedBox(height: AppConstants.space8),
                    ] else ...[
                      AppButton(
                        variant: AppButtonVariant.secondary,
                        type: AppButtonType.ghost,
                        label: 'Bring the dismissed banner back',
                        onPressed: () =>
                            setState(() => _bannerVisible = true),
                      ),
                      const SizedBox(height: AppConstants.space8),
                    ],
                    const AppBanner(
                      message: 'Your changes were saved.',
                      status: AppTagStatus.success,
                    ),
                    const SizedBox(height: AppConstants.space8),
                    const AppBanner(
                      message: 'We could not reach the server.',
                      status: AppTagStatus.error,
                    ),
                    const SizedBox(height: AppConstants.space8),
                    const AppBanner(
                      message: 'Read-only mode — you are offline.',
                      status: AppTagStatus.neutral,
                    ),
                  ],
                ),
              ),

              // ── AppProgressBar ────────────────────────────────────────────
              _Section(
                title: 'AppProgressBar',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppProgressBar(
                      value: _progress,
                      label: 'Uploading photo',
                      showPercent: true,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    AppSlider(
                      value: _progress,
                      label: 'Drag to change progress',
                      onChanged: (v) => setState(() => _progress = v),
                    ),
                    const SizedBox(height: AppConstants.space8),
                    for (final size in AppProgressBarSize.values) ...[
                      AppProgressBar(value: 0.6, size: size),
                      const SizedBox(height: AppConstants.space8),
                    ],
                    const AppProgressBar(
                      variant: AppInputVariant.tertiary,
                      label: 'Indeterminate (no value)',
                    ),
                  ],
                ),
              ),

              // ── AppStepIndicator ──────────────────────────────────────────
              _Section(
                title: 'AppStepIndicator',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppStepIndicator(currentStep: _wizardStep, stepCount: 4),
                    const SizedBox(height: AppConstants.space16),
                    AppStepIndicator(
                      currentStep: _wizardStep,
                      stepCount: 4,
                      type: AppStepIndicatorType.dots,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    AppStepIndicator(
                      currentStep: _wizardStep,
                      stepCount: 4,
                      type: AppStepIndicatorType.numbered,
                      labels: const ['Account', 'Profile', 'Payment', 'Done'],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIconButton(
                          icon: Icons.chevron_left,
                          type: AppIconButtonType.tonal,
                          tooltip: 'Previous step',
                          onPressed: _wizardStep == 0
                              ? null
                              : () => setState(() => _wizardStep--),
                        ),
                        const SizedBox(width: AppConstants.space16),
                        AppIconButton(
                          icon: Icons.chevron_right,
                          type: AppIconButtonType.tonal,
                          tooltip: 'Next step',
                          onPressed: _wizardStep == 3
                              ? null
                              : () => setState(() => _wizardStep++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── AppAvatar & AppImage ──────────────────────────────────────
              const _Section(
                title: 'AppAvatar & AppImage',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Initials fallback (no URL):'),
                    SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space12,
                      runSpacing: AppConstants.space12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppAvatar(name: 'Jane Doe', size: AppAvatarSize.chat),
                        AppAvatar(name: 'Ada Lovelace'),
                        AppAvatar(
                          name: 'Grace Hopper',
                          size: AppAvatarSize.detail,
                        ),
                        AppAvatar(
                          name: 'Alan Turing',
                          size: AppAvatarSize.detail,
                          roundedSquare: true,
                        ),
                        AppAvatar(),
                      ],
                    ),
                    SizedBox(height: AppConstants.space16),
                    Text(
                      'AppImage falls back to assets/images/placeholder_image.jpg — '
                      'add one, or point placeholderAsset at your own.',
                    ),
                    SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space12,
                      runSpacing: AppConstants.space12,
                      children: [
                        AppImage(size: AppImageSize.small),
                        AppImage(
                          size: AppImageSize.small,
                          shape: AppImageShape.circle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── EmptyView ─────────────────────────────────────────────────
              _Section(
                title: 'EmptyView',
                child: SizedBox(
                  height: 320,
                  child: EmptyView(
                    title: 'No transactions yet',
                    message: 'Your payments will show up here.',
                    actionLabel: 'Add one',
                    onAction: () {},
                  ),
                ),
              ),

              // ── AppLoadingActionOverlay ───────────────────────────────────
              _Section(
                title: 'AppLoadingActionOverlay',
                child: AppLoadingActionOverlay(
                  isLoading: _overlayLoading,
                  child: Container(
                    height: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: AppConstants.borderRadius12,
                    ),
                    child: AppButton(
                      variant: AppButtonVariant.primary,
                      width: 220,
                      label: 'Cover this box for 3s',
                      onPressed: () async {
                        setState(() => _overlayLoading = true);
                        await Future<void>.delayed(const Duration(seconds: 3));
                        if (mounted) setState(() => _overlayLoading = false);
                      },
                    ),
                  ),
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
