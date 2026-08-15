import '../../utils/state_management.dart';

/// Generates reusable shared widget templates.
///
/// The kit is stack-agnostic apart from two widgets: `AppButton`, when it
/// gates a press on biometrics, and the design-system preview, which shows
/// `AppAsyncView`. Both take a [StateManagement] rather than being copied
/// into the per-stack folders.
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
  ///
  /// The service comes out of the locator in both stacks, so there is one
  /// button rather than two.
  static String appButton({
    bool hasBiometricAuth = false,
  }) {
    final biometricImports = !hasBiometricAuth
        ? ''
        : "\nimport '../../../config/di/injector.dart';"
            "\nimport '../../../core/security/biometric_service.dart';";

    // The locator needs no element of its own, so the button stays a
    // StatelessWidget.
    const classDeclaration = 'class AppButton extends StatelessWidget {';

    final requireAuthParam =
        hasBiometricAuth ? '\n    this.requireAuth = false,' : '';

    final requireAuthField = !hasBiometricAuth
        ? ''
        : '\n\n  /// Runs biometric verification before [onPressed]; the press\n'
            '  /// is cancelled when it fails.\n'
            '  final bool requireAuth;';

    const buildSignature = 'Widget build(BuildContext context) {';

    const verifyCall =
        '                final verified = await getIt<BiometricService>()\n'
        '                    .verifyUserLocalAuth(context);\n';

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
            '$verifyCall'
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

  /// A line centered above the button — what the action will do, or what it
  /// costs, said before the user commits to it. Omit for a plain button.
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
      // Centered rather than stretched: stretch would hand the button a tight
      // width and override an explicit [width], so a 220px button would come
      // out full-bleed the moment it was given a hint.
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.space4),
          child: Text(
            hint!,
            textAlign: TextAlign.center,
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
    this.searchableThreshold = 30,
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

  /// How many options an [AppDropdownInput] shows in a menu before it switches
  /// to a searchable sheet. A menu stops being usable somewhere around thirty
  /// rows; raise this for a list that stays scannable longer, or set it to 0 to
  /// make every dropdown searchable. A field can still answer for itself with
  /// `searchable: true` or `false`.
  final int searchableThreshold;

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
    int? searchableThreshold,
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
      searchableThreshold: searchableThreshold ?? this.searchableThreshold,
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

  /// The color that reads on top of [accentOf] — what a checked box, a selected
  /// segment or a filled chip puts its glyph and label in.
  ///
  /// Every control that fills itself with the accent needs this, and each one
  /// guessing separately is how a selected segment ends up unreadable: the
  /// surface color is only the right answer in a light theme.
  static Color onAccentOf(BuildContext context, AppInputVariant? variant) {
    final colorScheme = context.theme.colorScheme;
    return switch (variant ?? config.variant) {
      AppInputVariant.primary => colorScheme.onPrimary,
      AppInputVariant.secondary => colorScheme.onSecondary,
      AppInputVariant.tertiary => colorScheme.onTertiary,
      AppInputVariant.danger => colorScheme.onError,
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
import '../../../core/constants/app_constants.dart';
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

/// Makes a control that carries its own selection — a checkbox, a radio group,
/// a chip row — validate like the rest of the family.
///
/// The fields built on [InputDecoration] get `errorText` for free: a border to
/// turn red and a line underneath to explain it. A checkbox paints neither, so
/// a `Form` that rejects one has nowhere to say why. This wraps the control in
/// a [FormField] and puts that line under it.
///
/// ```dart
/// SelectionFormField<bool>(
///   value: _accepted,
///   validator: (v) => v ? null : 'Please accept the terms',
///   builder: (_) => AppCheckboxLabel(...),
/// )
/// ```
class SelectionFormField<T> extends StatelessWidget {
  const SelectionFormField({
    super.key,
    required this.value,
    required this.validator,
    required this.builder,
    this.enabled = true,
    this.autovalidateMode,
  });

  /// The control's current selection, read from the caller on every validate
  /// rather than stored — the caller owns it, so its answer is the true one
  /// even before a rebuild has reached this field.
  final T value;

  /// Null leaves the control out of validation altogether, and no error line is
  /// ever built.
  final String? Function(T value)? validator;

  final Widget Function(FormFieldState<T> state) builder;
  final bool enabled;

  /// Null follows [AppInputConfig.defaults].
  final AutovalidateMode? autovalidateMode;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: value,
      enabled: enabled,
      autovalidateMode:
          autovalidateMode ?? AppInputStyle.config.autovalidateMode,
      // A null [validator] resolves to no rule, so an unvalidated control still
      // builds exactly as it did — it simply never has anything to report.
      validator: (_) => validator?.call(value),
      builder: (state) {
        final error = state.errorText;
        return Column(
          mainAxisSize: MainAxisSize.min,
          // Stretch so the control keeps the width it had before it was
          // wrapped: a row-wide tap target must not shrink to its content.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            builder(state),
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
    if (keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
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
    this.enabled = true,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.autoFocus = false,
    this.required = false,
    this.validator,
    this.autovalidateMode,
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
    this.textAlign = TextAlign.start,
    this.onChanged,
  });

  /// Optional external controller — pass one to read or clear the date from
  /// outside. When omitted the field owns (and disposes) its own, so a value
  /// still shows without one.
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final DateTime? initialValue;

  /// A disabled field is greyed out and opens nothing.
  final bool enabled;

  /// Styled normally but opens no picker — for a date that is displayed rather
  /// than chosen.
  final bool readOnly;

  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final bool autoFocus;

  /// Marks the label, and — unless [validator] replaces the rule — rejects an
  /// empty field when the form validates.
  final bool required;

  /// Replaces the built-in rule entirely. Receives the field's text.
  /// Call [AppDateInput.validate] from inside it to add a rule on top instead
  /// of dropping the required check.
  final String? Function(String? value)? validator;

  /// When the field validates itself. Null follows the config.
  final AutovalidateMode? autovalidateMode;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// Alignment of the displayed date and the hint. The label follows it too.
  final TextAlign textAlign;

  /// Fires with the picked date.
  final ValueChanged<DateTime>? onChanged;

  /// The rule applied when no [validator] is given: a required field has to
  /// hold a date.
  static String? validate(String? value, {bool required = false}) =>
      required && (value == null || value.trim().isEmpty)
      ? 'This field is required'
      : null;

  @override
  State<AppDateInput> createState() => _AppDateInputState();
}

class _AppDateInputState extends State<AppDateInput> {
  /// The field shows whatever this holds, so it has to exist even when the
  /// caller passes nothing — otherwise a picked date would update the state
  /// and never appear on screen.
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  /// Only dispose what this widget created; an injected controller belongs to
  /// the caller and may well outlive the field.
  late final bool _ownsController = widget.controller == null;

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
      // A controller that already holds something was seeded by the caller,
      // and that beats a default.
      if (_controller.text.isEmpty) {
        _controller.text = widget.initialValue!.formattedDate;
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
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
      _controller.text = picked.formattedDate;
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
      field: TextFormField(
        // A read-only field keeps its normal look but opens nothing; a disabled
        // one is greyed out by `enabled` and never reaches this callback.
        onTap: widget.readOnly ? null : () => _selectDate(context),
        focusNode: widget.focusNode,
        autofocus: widget.autoFocus,
        enabled: widget.enabled,
        // Always true: the value is chosen in a picker, never typed.
        readOnly: true,
        controller: _controller,
        autovalidateMode:
            widget.autovalidateMode ?? AppInputStyle.config.autovalidateMode,
        validator:
            widget.validator ??
            (value) => AppDateInput.validate(value, required: widget.required),
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
          enabled: widget.enabled,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
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
    this.enabled = true,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.autoFocus = false,
    this.required = false,
    this.validator,
    this.autovalidateMode,
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
    this.textAlign = TextAlign.start,
    this.onChanged,
  });

  /// Optional external controller — pass one to read or clear the time from
  /// outside. When omitted the field owns (and disposes) its own, so a value
  /// still shows without one.
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final TimeOfDay? initialValue;

  /// A disabled field is greyed out and opens nothing.
  final bool enabled;

  /// Styled normally but opens no picker — for a time that is displayed rather
  /// than chosen.
  final bool readOnly;

  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final bool autoFocus;

  /// Marks the label, and — unless [validator] replaces the rule — rejects an
  /// empty field when the form validates.
  final bool required;

  /// Replaces the built-in rule entirely. Receives the field's text.
  /// Call [AppTimeInput.validate] from inside it to add a rule on top instead
  /// of dropping the required check.
  final String? Function(String? value)? validator;

  /// When the field validates itself. Null follows the config.
  final AutovalidateMode? autovalidateMode;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// Alignment of the displayed time and the hint. The label follows it too.
  final TextAlign textAlign;

  /// Fires with the picked time.
  final ValueChanged<TimeOfDay>? onChanged;

  /// The rule applied when no [validator] is given: a required field has to
  /// hold a time.
  static String? validate(String? value, {bool required = false}) =>
      required && (value == null || value.trim().isEmpty)
      ? 'This field is required'
      : null;

  @override
  State<AppTimeInput> createState() => _AppTimeInputState();
}

class _AppTimeInputState extends State<AppTimeInput> {
  /// The field shows whatever this holds, so it has to exist even when the
  /// caller passes nothing — otherwise a picked time would update the state
  /// and never appear on screen.
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  /// Only dispose what this widget created; an injected controller belongs to
  /// the caller and may well outlive the field.
  late final bool _ownsController = widget.controller == null;

  TimeOfDay _lastSelectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _lastSelectedTime = widget.initialValue!;
      // A controller that already holds something was seeded by the caller,
      // and that beats a default.
      if (_controller.text.isEmpty) {
        _controller.text = widget.initialValue!.formattedTime;
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
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
      _controller.text = picked.formattedTime;
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
      field: TextFormField(
        // A read-only field keeps its normal look but opens nothing; a disabled
        // one is greyed out by `enabled` and never reaches this callback.
        onTap: widget.readOnly ? null : () => _selectTime(context),
        focusNode: widget.focusNode,
        autofocus: widget.autoFocus,
        enabled: widget.enabled,
        // Always true: the value is chosen in a picker, never typed.
        readOnly: true,
        controller: _controller,
        autovalidateMode:
            widget.autovalidateMode ?? AppInputStyle.config.autovalidateMode,
        validator:
            widget.validator ??
            (value) => AppTimeInput.validate(value, required: widget.required),
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
          enabled: widget.enabled,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
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
///
/// [showMulti] opens the same sheet with a checkbox per row and a Done button —
/// what [AppMultiSelectInput] uses. One sheet covers both because everything
/// that makes this sheet worth having (the search, the filter, opening at the
/// current selection) is the same either way.
class SearchPickerSheet<T> extends StatefulWidget {
  /// Creates the sheet. Prefer [show] or [showMulti], which open it with the
  /// modal settings a full-height searchable sheet needs.
  const SearchPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.idOf,
    required this.labelOf,
    this.selectedId,
    this.selectedIds = const [],
    this.multiSelect = false,
    this.maxSelected,
    this.doneLabel = 'Done',
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

  /// The rows already ticked, when [multiSelect]. The sheet works on its own
  /// copy and reports the result once, so a dismissed sheet changes nothing.
  final List<String> selectedIds;

  /// Puts a checkbox on every row and a Done button under the list. Tapping a
  /// row toggles it instead of closing the sheet.
  final bool multiSelect;

  /// Ceiling on how many may be ticked. At the limit the unticked rows stop
  /// responding — better than letting the user pick a sixth of five and having
  /// the form refuse it afterwards. Only read when [multiSelect].
  final int? maxSelected;

  /// Copy on the confirm button. Only read when [multiSelect].
  final String doneLabel;

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

  /// Opens the sheet in multi-select mode and resolves to everything ticked
  /// when Done was tapped, or null if it was dismissed.
  ///
  /// An empty list and null mean different things: the first is a deliberate
  /// "none of them", the second is "leave it as it was".
  static Future<List<T>?> showMulti<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required String Function(T item) idOf,
    required String Function(T item) labelOf,
    List<String> selectedIds = const [],
    int? maxSelected,
    String doneLabel = 'Done',
    String searchHint = 'Search',
    Widget Function(T item)? leadingOf,
    String Function(T item)? trailingLabelOf,
    List<T> Function(List<T> items, String query)? filter,
    String emptyLabel = 'Nothing matches that search',
    AppInputVariant? variant,
  }) {
    return showModalBottomSheet<List<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SearchPickerSheet<T>(
        title: title,
        items: items,
        idOf: idOf,
        labelOf: labelOf,
        selectedIds: selectedIds,
        multiSelect: true,
        maxSelected: maxSelected,
        doneLabel: doneLabel,
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

  /// The sheet's own copy of a multi-select selection: it is reported once, on
  /// Done, so backing out of the sheet leaves the caller's list untouched.
  late final Set<String> _picked = {...widget.selectedIds};

  /// Opens the list already showing the current selection, so a picker over a
  /// long table doesn't start hundreds of rows away from the answer.
  ///
  /// Exact rather than estimated because the rows are a fixed [_rowHeight].
  double get _initialOffset {
    // In multi-select the first tick is the one to open at — it is where the
    // user was working, and later ones are usually near it.
    final selectedId =
        widget.selectedId ??
        (widget.selectedIds.isEmpty ? null : widget.selectedIds.first);
    if (selectedId == null) return 0;
    final index = widget.items.indexWhere(
      (item) => widget.idOf(item) == selectedId,
    );
    return index <= 0 ? 0 : index * _rowHeight;
  }

  /// True once as many rows are ticked as [SearchPickerSheet.maxSelected]
  /// allows.
  bool get _atLimit =>
      widget.maxSelected != null && _picked.length >= widget.maxSelected!;

  /// Everything ticked, in [SearchPickerSheet.items] order rather than in the
  /// order it was tapped — which is the order a caller wants to store.
  List<T> get _pickedItems => [
    for (final item in widget.items)
      if (_picked.contains(widget.idOf(item))) item,
  ];

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_picked.remove(id)) _picked.add(id);
    });
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
                          final selected = widget.multiSelect
                              ? _picked.contains(id)
                              : id == widget.selectedId;
                          final trailing = widget.trailingLabelOf?.call(item);
                          // Past the ceiling only the ticked rows still answer:
                          // offering a pick the caller has to throw away is
                          // worse than showing it can't be made.
                          final enabled =
                              !widget.multiSelect || selected || !_atLimit;

                          return ListTile(
                            enabled: enabled,
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
                            trailing: _rowTrailing(
                              theme: theme,
                              accent: accent,
                              trailingLabel: trailing,
                              selected: selected,
                              enabled: enabled,
                              id: id,
                            ),
                            onTap: enabled
                                ? () {
                                    if (widget.multiSelect) {
                                      _toggle(id);
                                      return;
                                    }
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(context, item);
                                  }
                                : null,
                          );
                        },
                      ),
              ),
              if (widget.multiSelect) _confirmBar(theme, accent),
            ],
          ),
        ),
      ),
    );
  }

  /// The end of a row: its secondary label, and in multi-select the checkbox
  /// that says whether it is in.
  Widget? _rowTrailing({
    required ThemeData theme,
    required Color accent,
    required String? trailingLabel,
    required bool selected,
    required bool enabled,
    required String id,
  }) {
    final label = trailingLabel == null
        ? null
        : Text(
            trailingLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selected ? accent : theme.colorScheme.onSurfaceVariant,
            ),
          );

    if (!widget.multiSelect) return label;

    final checkbox = Checkbox(
      value: selected,
      activeColor: accent,
      // The whole row is the target — the box only has to report the state, and
      // a second tap handler here would double the haptics.
      onChanged: enabled ? (_) => _toggle(id) : null,
    );

    if (label == null) return checkbox;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [label, checkbox],
    );
  }

  /// The bar under a multi-select list: how many are in, and the button that
  /// commits them.
  Widget _confirmBar(ThemeData theme, Color accent) {
    final max = widget.maxSelected;
    return Container(
      padding: AppConstants.padding16,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        spacing: AppConstants.space12,
        children: [
          Expanded(
            child: Text(
              max == null
                  ? '${_picked.length} selected'
                  : '${_picked.length} of $max selected',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, _pickedItems);
            },
            child: Text(widget.doneLabel),
          ),
        ],
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
// Past about thirty options a menu becomes a scroll hunt, so a list that long
// opens a [SearchPickerSheet] instead — the same field, the same callback, a
// list you can type into. Where "long" begins is
// [AppInputConfig.searchableThreshold]; passing [searchable] overrules it for
// a single field.
class AppDropdownInput<T> extends StatelessWidget {
  const AppDropdownInput({
    super.key,
    required this.label,
    required this.items,
    required this.idOf,
    required this.labelOf,
    required this.onChanged,
    this.onSelected,
    this.onCleared,
    this.selectedId,
    this.hint = 'Select an option',
    this.enabled = true,
    this.required = false,
    this.validator,
    this.autovalidateMode,
    this.searchable,
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
    this.textAlign = TextAlign.start,
  });

  final String label;
  final List<T> items;

  /// Extract the id from an item — always a String, used as the dropdown value.
  /// Ids pick the selection, so they must be unique across [items]; a duplicate
  /// trips an assert rather than quietly selecting the wrong row.
  final String Function(T item) idOf;

  /// Extract the display label from an item.
  final String Function(T item) labelOf;

  /// Called with the selected id when the user picks an option.
  final ValueChanged<String> onChanged;

  /// Called with the item itself, alongside [onChanged]. Saves the caller
  /// looking up an entity this field had in its hand a moment earlier.
  final ValueChanged<T>? onSelected;

  /// Called when the user clears the field. Providing it is what puts the clear
  /// button in the field — with nowhere to report a clear there is no point
  /// offering one.
  final VoidCallback? onCleared;

  final String? selectedId;
  final String hint;
  final bool enabled;

  /// Marks the label, and — unless [validator] replaces the rule — rejects an
  /// empty selection when the form validates.
  final bool required;

  /// Replaces the built-in rule entirely. Receives the selected id, or null.
  /// Call [AppDropdownInput.validate] from inside it to add a rule on top
  /// instead of dropping the required check.
  final String? Function(String? id)? validator;

  /// When the field validates itself. Null follows the config, which starts at
  /// Flutter's own default — on submit only.
  final AutovalidateMode? autovalidateMode;

  /// Swaps the menu for a [SearchPickerSheet] — a bottom sheet with a search
  /// field over the same options.
  ///
  /// Null decides from the list's own length against
  /// [AppInputConfig.searchableThreshold], which is the answer nearly every
  /// field wants. Say `false` to keep a menu over a long list, `true` to give a
  /// short one a search box anyway.
  final bool? searchable;

  /// Placeholder in the sheet's search field. Only used when searchable.
  final String searchHint;

  /// Heading over the sheet. Defaults to [label]. Only used when searchable.
  final String? searchTitle;

  /// Optional leading widget per row in the sheet — a flag, an avatar, an icon.
  /// Only used when searchable.
  final Widget Function(T item)? leadingOf;

  /// Optional dimmed text at the end of a sheet row, for a secondary value.
  /// Only used when searchable.
  final String Function(T item)? trailingLabelOf;

  /// Replaces the sheet's default filter, which is a case-insensitive
  /// `contains` over [labelOf]. Returns the rows to show *in the order to show
  /// them*, so a caller can rank matches as well as select them. Only used when
  /// searchable.
  final List<T> Function(List<T> items, String query)? filter;

  /// Shown in the sheet in place of the list when there is nothing to show.
  /// Null picks copy that fits the reason — an empty [items] is not a failed
  /// search, and saying so stops the user retyping a query that was never the
  /// problem. Only used when searchable.
  final String? emptyLabel;

  final Widget? prefixIcon;

  /// Replaces the chevron — and, with it, the clear button. The field's own
  /// trailing affordances are a default, not a guarantee.
  final Widget? suffixIcon;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// Alignment of the selected value and the hint. The label follows it too.
  final TextAlign textAlign;

  /// The rule applied when no [validator] is given: a required field has to
  /// hold a selection.
  ///
  /// Exposed so a custom [validator] can layer on top of it:
  ///
  ///   validator: (id) =>
  ///       AppDropdownInput.validate(id, required: true) ??
  ///       (id == 'archived' ? 'That category is closed' : null),
  static String? validate(String? id, {bool required = false}) =>
      required && (id == null || id.isEmpty) ? 'This field is required' : null;

  /// The item an id points at, or null when no row carries it.
  T? _itemFor(String? id) {
    if (id == null) return null;
    for (final item in items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  /// The item [selectedId] points at, or null when nothing is selected — or
  /// when the id has no row yet.
  T? get _selected => _itemFor(selectedId);

  /// Whether this field opens a sheet rather than a menu.
  bool get _searchable =>
      searchable ?? items.length >= AppInputStyle.config.searchableThreshold;

  /// The rule in force — the caller's, else the built-in one.
  String? _validate(String? id) {
    final rule = validator;
    return rule != null ? rule(id) : validate(id, required: required);
  }

  InputDecoration _decoration(
    BuildContext context, {
    Widget? suffix,
    String? errorText,
  }) => AppInputStyle.decoration(
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
  ).copyWith(errorText: errorText);

  /// What sits at the end of the field: the caller's own suffix if there is
  /// one, else the clear button when there is something to clear, ahead of the
  /// chevron. A disabled field shows neither — there is no action left to
  /// advertise.
  Widget? _trailing(T? selected) {
    if (suffixIcon != null) return suffixIcon;
    if (!enabled) return null;

    const chevron = Icon(Icons.keyboard_arrow_down);
    if (onCleared == null || selected == null) return chevron;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onCleared!();
          },
          tooltip: 'Clear',
          icon: const Icon(Icons.close),
        ),
        chevron,
      ],
    );
  }

  /// Reports a pick to the caller. [haptic] is off on the sheet's path, where
  /// the tapped row has already given feedback of its own.
  void _pick(T item, {bool haptic = true}) {
    if (haptic) HapticFeedback.selectionClick();
    onChanged(idOf(item));
    onSelected?.call(item);
  }

  Future<void> _openSheet(
    BuildContext context,
    FormFieldState<String> state,
  ) async {
    final picked = await SearchPickerSheet.show<T>(
      context,
      title: searchTitle ?? label,
      searchHint: searchHint,
      items: items,
      idOf: idOf,
      labelOf: labelOf,
      selectedId: selectedId,
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
    if (picked == null) return;
    // Marks the field as interacted with, so a form set to validate on
    // interaction clears its error the moment a selection lands.
    state.didChange(idOf(picked));
    _pick(picked, haptic: false);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      items.map(idOf).toSet().length == items.length,
      'AppDropdownInput<$T>: idOf returned the same id for more than one item. '
      'Ids are what pick the selection, so they have to be unique.',
    );

    final selected = _selected;
    final accent = AppInputStyle.accentOf(context, variant);
    final alignment = AppInputStyle.alignmentOf(textAlign);

    return InputFieldLayout(
      label: label,
      required: required,
      labelMode: labelMode,
      variant: variant,
      size: size,
      textAlign: textAlign,
      // Both forms turn themselves off from the inside — an IgnorePointer here
      // would block the tap but leave the field painting itself as live.
      field: _searchable
          ? _searchableField(context, selected, accent, alignment)
          : _menuField(context, selected, accent, alignment),
    );
  }

  /// The searchable form: the field only *shows* the selection and opens the
  /// sheet, so there is no menu to lay out and the value still lives with the
  /// caller.
  ///
  /// The [FormField] around it is what lets this form be validated at all. An
  /// [InputDecorator] is only a picture of an input — without this a `Form`
  /// walks straight past a searchable field and a required one submits empty.
  Widget _searchableField(
    BuildContext context,
    T? selected,
    Color accent,
    AlignmentGeometry alignment,
  ) {
    return FormField<String>(
      initialValue: selectedId,
      enabled: enabled,
      autovalidateMode:
          autovalidateMode ?? AppInputStyle.config.autovalidateMode,
      // Judged on [selectedId] rather than on the value this FormField happens
      // to hold: the caller owns the selection, so its answer is the true one
      // even before a rebuild has reached here.
      validator: (_) => _validate(selectedId),
      builder: (state) => MergeSemantics(
        // An InkWell announces nothing on its own; without this a screen reader
        // reads out the value and never says it can be opened.
        child: Semantics(
          button: true,
          enabled: enabled,
          child: InkWell(
            onTap: enabled ? () => _openSheet(context, state) : null,
            borderRadius: AppConstants.borderRadius12,
            child: InputDecorator(
              // The chevron sits inside the border here, where a suffix goes;
              // the menu form hands its own to the dropdown instead.
              decoration: _decoration(
                context,
                suffix: _trailing(selected),
                errorText: state.errorText,
              ),
              // Drives the hint and the floating label the same way an empty
              // text field would.
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
          ),
        ),
      ),
    );
  }

  Widget _menuField(
    BuildContext context,
    T? selected,
    Color accent,
    AlignmentGeometry alignment,
  ) {
    return DropdownButtonFormField<String>(
      // Only an id that actually resolves. A dropdown asserts that exactly one
      // of its items carries its value, so an id whose row has not arrived yet
      // — restored state waiting on a fetch, a list refreshed out from under
      // the selection — would otherwise throw.
      initialValue: selected == null ? null : selectedId,
      style: AppInputStyle.textStyle(
        context,
        size: size,
      )?.copyWith(color: accent, fontWeight: FontWeight.bold),
      decoration: _decoration(context),
      isExpanded: true,
      // A dropdown has no textAlign, so align the item boxes instead.
      alignment: alignment,
      autovalidateMode:
          autovalidateMode ?? AppInputStyle.config.autovalidateMode,
      validator: _validate,
      // A null onChanged is what disables a dropdown: it greys the value out
      // and takes the field out of the focus order, which no wrapper can do.
      onChanged: enabled ? _onMenuChanged : null,
      iconEnabledColor: accent,
      iconSize: AppInputStyle.configOf(size).iconSize,
      // The trailing widget belongs here, not in the decoration: a dropdown
      // draws exactly one, and `icon` is the slot it reads first — anything
      // left in `suffixIcon` is dropped on the floor.
      icon: _trailing(selected) ?? const SizedBox.shrink(),
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

  void _onMenuChanged(String? id) {
    final item = _itemFor(id);
    if (item != null) _pick(item);
  }
}
''';

  /// Returns the generated appCheckbox template.
  static String appCheckbox() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './app_input_style.dart';
import '../../../core/constants/app_constants.dart';

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

  @override
  Widget build(BuildContext context) {
    final config = AppInputStyle.config;
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
        checkColor: AppInputStyle.onAccentOf(context, variant),
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
import './input_title.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// [AppCheckbox] paired with a tappable label (and optional subtitle), the
/// whole row toggling the value — not just the checkbox square.
///
/// `required: true` makes it the "accept the terms" checkbox: a `Form` refuses
/// to validate until it is ticked, and says so under the row.
class AppCheckboxLabel extends StatelessWidget {
  const AppCheckboxLabel({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.required = false,
    this.requiredError = 'This box must be ticked',
    this.validator,
    this.autovalidateMode,
    this.variant,
    this.size,
    this.shape,
  });

  final String label;
  final String? subtitle;
  final bool value;

  /// Pass null to render the whole row disabled.
  final ValueChanged<bool>? onChanged;

  /// Marks the row and refuses to validate until it is ticked.
  final bool required;

  /// What a [required] row says when it is still unticked.
  final String requiredError;

  /// Replaces the built-in rule entirely. Returning null means valid.
  final String? Function(bool value)? validator;

  /// When the row validates itself. Null follows the config.
  final AutovalidateMode? autovalidateMode;

  final AppInputVariant? variant;
  final AppInputSize? size;
  final AppInputShape? shape;

  /// The rule in force: the caller's, else the required check, else nothing to
  /// enforce at all.
  String? Function(bool value)? get _rule {
    if (validator != null) return validator;
    if (!required) return null;
    return (value) => value ? null : requiredError;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final fontSize = AppInputStyle.configOf(size).fontSize;
    final enabled = onChanged != null;

    return SelectionFormField<bool>(
      value: value,
      validator: _rule,
      enabled: enabled,
      autovalidateMode: autovalidateMode,
      builder: (state) {
        void toggle(bool next) {
          HapticFeedback.selectionClick();
          // Tells the FormField it has been interacted with, so a form set to
          // validate on interaction drops the error as soon as it is ticked.
          state.didChange(next);
          onChanged!(next);
        }

        return InkWell(
          borderRadius: AppConstants.borderRadius8,
          // The square has its own haptic in AppCheckbox, so this one only
          // covers the rest of the row — one buzz either way.
          onTap: enabled ? () => toggle(!value) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppCheckbox(
                  value: value,
                  onChanged: enabled ? (v) => toggle(v ?? false) : null,
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
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: fontSize,
                          color: enabled
                              ? null
                              : context.colorScheme.onSurface.withValues(
                                  alpha: AppInputStyle.config.disabledOpacity,
                                ),
                        ),
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
      },
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
      // The thumb rides on the accent track once on, so it takes the same
      // foreground a checked box does rather than the theme's default.
      activeThumbColor: AppInputStyle.onAccentOf(context, variant),
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

  /// The chosen segment. Must be one of [segments] — a value from outside it
  /// draws a control with nothing highlighted, so it is caught by an assert
  /// instead.
  final T selected;

  final String Function(T value) labelOf;
  final IconData? Function(T value)? iconOf;

  /// Pass null to render the whole control disabled.
  final ValueChanged<T>? onChanged;

  final AppInputVariant? variant;

  @override
  Widget build(BuildContext context) {
    assert(
      segments.contains(selected),
      'AppSegmented<$T>: selected is not one of segments, so the control would '
      'render with nothing highlighted.',
    );

    final accent = AppInputStyle.accentOf(context, variant);
    final onAccent = AppInputStyle.onAccentOf(context, variant);
    final enabled = onChanged != null;

    return SegmentedButton<T>(
      showSelectedIcon: false,
      selected: {selected},
      // Null is what disables a SegmentedButton; there is no `enabled` flag.
      onSelectionChanged: enabled
          ? (set) {
              HapticFeedback.selectionClick();
              onChanged!(set.first);
            }
          : null,
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

  /// Pass null to render the chip disabled.
  final ValueChanged<bool>? onSelected;

  final IconData? icon;
  final AppInputVariant? variant;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accent = AppInputStyle.accentOf(context, variant);
    final onAccent = AppInputStyle.onAccentOf(context, variant);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: AppConstants.iconSmall,
              color: selected ? onAccent : accent,
            ),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? onAccent : theme.colorScheme.onSurface,
      ),
      selectedColor: accent,
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadiusFull),
      // Null is what disables a ChoiceChip; there is no `enabled` flag.
      onSelected: onSelected == null
          ? null
          : (v) {
              HapticFeedback.selectionClick();
              onSelected!(v);
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
import './input_title.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A vertical single-select list of labeled radio options, colored from
/// [AppInputVariant]. The whole row is tappable, not just the dot. Built on the
/// current [RadioGroup] ancestor API (requires Flutter 3.32+).
///
/// `required: true` refuses to validate while [groupValue] is still null, and
/// says so under the list.
class AppRadioGroup<T> extends StatelessWidget {
  const AppRadioGroup({
    super.key,
    required this.values,
    required this.groupValue,
    required this.labelOf,
    required this.onChanged,
    this.subtitleOf,
    this.required = false,
    this.requiredError = 'Please choose an option',
    this.validator,
    this.autovalidateMode,
    this.variant,
  });

  final List<T> values;

  /// The chosen option, or null while nothing is chosen. Must be one of
  /// [values]; anything else would draw a list with nothing selected, so it is
  /// caught by an assert instead.
  final T? groupValue;

  final String Function(T value) labelOf;
  final String? Function(T value)? subtitleOf;

  /// Pass null to render the whole group disabled.
  final ValueChanged<T>? onChanged;

  /// Refuses to validate until an option is chosen.
  final bool required;

  /// What a [required] group says while nothing is chosen.
  final String requiredError;

  /// Replaces the built-in rule entirely. Returning null means valid.
  final String? Function(T? value)? validator;

  /// When the group validates itself. Null follows the config.
  final AutovalidateMode? autovalidateMode;

  final AppInputVariant? variant;

  /// The rule in force: the caller's, else the required check, else nothing to
  /// enforce at all.
  String? Function(T? value)? get _rule {
    if (validator != null) return validator;
    if (!required) return null;
    return (value) => value == null ? requiredError : null;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      groupValue == null || values.contains(groupValue),
      'AppRadioGroup<$T>: groupValue is not one of values, so the list would '
      'render with nothing selected.',
    );

    final accent = AppInputStyle.accentOf(context, variant);
    final enabled = onChanged != null;

    return SelectionFormField<T?>(
      value: groupValue,
      validator: _rule,
      enabled: enabled,
      autovalidateMode: autovalidateMode,
      builder: (state) {
        void select(T value) {
          HapticFeedback.selectionClick();
          // Tells the FormField it has been interacted with, so a form set to
          // validate on interaction drops the error as soon as one is chosen.
          state.didChange(value);
          onChanged!(value);
        }

        return RadioGroup<T>(
          groupValue: groupValue,
          onChanged: (value) {
            if (value != null && enabled) select(value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in values)
                InkWell(
                  borderRadius: AppConstants.borderRadius8,
                  onTap: enabled ? () => select(value) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.space4,
                    ),
                    child: Row(
                      children: [
                        // The row's InkWell drives selection, so the Radio is
                        // display-only; the RadioGroup above supplies its
                        // state.
                        IgnorePointer(
                          child: Radio<T>(
                            value: value,
                            activeColor: accent,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: AppConstants.space8),
                        Expanded(
                          child: _RadioLabel(
                            label: labelOf(value),
                            subtitle: subtitleOf?.call(value),
                            enabled: enabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One row's text. Pulled out so [AppRadioGroup.subtitleOf] is asked once per
/// row instead of once to test for null and again to read the value.
class _RadioLabel extends StatelessWidget {
  const _RadioLabel({
    required this.label,
    required this.subtitle,
    required this.enabled,
  });

  final String label;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final colorScheme = context.colorScheme;
    final disabled = colorScheme.onSurface.withValues(
      alpha: AppInputStyle.config.disabledOpacity,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodyLarge?.copyWith(
            color: enabled ? null : disabled,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: enabled ? colorScheme.onSurfaceVariant : disabled,
            ),
          ),
      ],
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
    this.margin,
    this.borderColor,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final AppCardType type;

  /// Inset between the card's edge and its content.
  final EdgeInsetsGeometry padding;

  /// Inset around the outside of the card — space between it and whatever it
  /// sits next to. Null is none. It stays outside the surface, so the border,
  /// the shadow and the tap ripple all stop at the card's edge.
  final EdgeInsetsGeometry? margin;

  /// Color of the card's hairline border. On [AppCardType.outlined] it stands
  /// in for the default [ColorScheme.outlineVariant]; on the other two it adds
  /// a border they do not otherwise draw — a filled card ringed in the error
  /// color to mark an invalid section, say. Null leaves each type as it is.
  final Color? borderColor;

  final VoidCallback? onTap;

  /// How the child is clipped to the card's rounded corners. Defaults to
  /// [Clip.antiAlias] so an interactive child (e.g. an AppListTile with
  /// [padding] set to [EdgeInsets.zero]) keeps its ripple inside the corners.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final radius = AppConstants.borderRadius16;

    // Outlined always draws a border; the other two only once asked for one.
    final border = borderColor == null && type != AppCardType.outlined
        ? null
        : Border.all(color: borderColor ?? theme.colorScheme.outlineVariant);

    final decoration = switch (type) {
      AppCardType.elevated => BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: radius,
          border: border,
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
          border: border,
        ),
      AppCardType.outlined => BoxDecoration(
          color: Colors.transparent,
          borderRadius: radius,
          border: border,
        ),
    };

    final content = Container(
      clipBehavior: clipBehavior,
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );

    final card = onTap == null
        ? content
        : InkWell(
            borderRadius: radius,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap!();
            },
            child: content,
          );

    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
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
    this.margin,
    this.borderColor,
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

  /// Inset around the outside of the card — space between this row and the one
  /// next to it, when a stack of these is standing in for a list. Null is none.
  final EdgeInsetsGeometry? margin;

  /// Color of the card's border. See [AppCard.borderColor]: it overrides the
  /// hairline on an outlined card, and gives a filled or elevated one a border
  /// it would not otherwise draw.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    // onTap lives on the card so the whole surface is the tap target; the
    // tile stays passive (its padding still shapes the content).
    return AppCard(
      type: cardType,
      padding: EdgeInsets.zero,
      margin: margin,
      borderColor: borderColor,
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

import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A single destination for [AppBottomNav] — and for the rail and the drawer,
/// which read the same list so an app describes its navigation once.
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

/// How [AppBottomNav] marks the selected destination.
///
/// - [material]: Material 3's own bar — a label under every icon and a pill
///   indicator that slides behind the selected one.
/// - [classic]: the pre-M3 bar — icon over label, the selected pair tinted
///   with the accent and nothing drawn behind it.
/// - [pill]: icons only until selected; the selected one opens into an accent
///   pill with its label beside the icon.
/// - [dot]: icons only, with a dot under the selected one. The quietest of the
///   four, for a bar whose icons speak for themselves.
enum AppBottomNavStyle { material, classic, pill, dot }

/// Where [AppBottomNav] writes its labels, on top of what the
/// [AppBottomNavStyle] says by itself.
///
/// - [auto]: whatever the style does on its own — [AppBottomNavStyle.material]
///   and [AppBottomNavStyle.classic] write the label under every icon,
///   [AppBottomNavStyle.pill] beside the selected one, [AppBottomNavStyle.dot]
///   nowhere.
/// - [below]: every destination carries its label under its icon, whichever
///   style is drawing. The pill then fills behind the icon *and* the label
///   instead of opening sideways; the dot keeps its mark under both.
/// - [none]: icons only. The label still reaches a screen reader, and a long
///   press still names the icon.
enum AppBottomNavLabels { auto, below, none }

/// A corner [AppBottomNav] cuts something with — the floating card it rides in
/// ([AppBottomNav.floatingShape]) and the fill behind the selected destination
/// ([AppBottomNav.pillShape]) are each asked this separately.
///
/// - [full]: a stadium, as round at the ends as the thing is tall.
/// - [rounded]: the corner an elevated card wears.
/// - [square]: sharp corners.
///
/// [AppBottomNav.floatingBorderRadius] and [AppBottomNav.pillBorderRadius]
/// override the three where a project wants a number of its own.
enum AppBottomNavShape { full, rounded, square }

/// The app's bottom navigation. Feed it the current [index], the
/// [destinations], and an [onDestinationSelected] callback. For go_router,
/// drive [index] from a `StatefulShellRoute` and switch branch in the callback:
///
/// ```dart
/// AppBottomNav(
///   index: shell.currentIndex,
///   destinations: destinations,
///   onDestinationSelected: shell.goBranch,
///   style: AppBottomNavStyle.pill,
///   labels: AppBottomNavLabels.below,
///   floating: true,
///   floatingShape: AppBottomNavShape.rounded,
/// )
/// ```
///
/// Each knob answers one question and combines freely with the rest: [style] is
/// how the selected destination is marked, [labels] is where the names are
/// written, [floating] is whether the bar is a band across the bottom edge or a
/// card riding above it, [floatingShape] is the corner that card is cut with,
/// and [pillShape] the corner of the fill behind the selection. A floating
/// [pill] is the look most modern apps wear, but every style floats and every
/// style can carry labels.
///
/// A floating bar wants `Scaffold(extendBody: true)` under it, so the content
/// runs through the gap instead of stopping at it. [AppAdaptiveNav] sets that
/// for you.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.destinations,
    required this.onDestinationSelected,
    this.style = AppBottomNavStyle.material,
    this.labels = AppBottomNavLabels.auto,
    this.floating = false,
    this.floatingShape = AppBottomNavShape.full,
    this.floatingBorderRadius,
    this.pillShape,
    this.pillBorderRadius,
    this.variant,
  });

  final int index;
  final List<AppNavDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  final AppBottomNavStyle style;

  /// Where the destination names are written. Defaults to whatever [style]
  /// does on its own.
  final AppBottomNavLabels labels;

  /// Detaches the bar from the bottom edge: a card with a margin around it and
  /// a shadow under it. Works with every [style].
  final bool floating;

  /// The corner that card is cut with. Only read when [floating].
  final AppBottomNavShape floatingShape;

  /// A corner of the project's own, overriding [floatingShape]. Only read when
  /// [floating].
  final BorderRadius? floatingBorderRadius;

  /// The corner of the fill behind the selected destination: the pill an
  /// [AppBottomNavStyle.pill] draws, and the indicator Material's own bar
  /// slides behind its selection.
  ///
  /// Null leaves each of them the corner it wears by itself — a stadium for a
  /// pill that opens sideways, a card's corner for one stacked over its label,
  /// and the theme's for Material's indicator.
  final AppBottomNavShape? pillShape;

  /// A corner of the project's own for that fill, overriding [pillShape].
  final BorderRadius? pillBorderRadius;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  /// The height of the three styles this widget draws itself, before any
  /// safe-area inset: a row of touch targets with a little air around it.
  /// Material's own bar measures itself and is left alone.
  static const double _height = 64;

  static BorderRadius _radiusOf(AppBottomNavShape shape) => switch (shape) {
        AppBottomNavShape.full => AppConstants.borderRadiusFull,
        AppBottomNavShape.rounded => AppConstants.borderRadius16,
        AppBottomNavShape.square => BorderRadius.zero,
      };

  /// The corner the floating card is cut with: the project's own where it named
  /// one, the shape's otherwise.
  BorderRadius get _radius => floatingBorderRadius ?? _radiusOf(floatingShape);

  /// The corner asked for behind the selected destination, or null where none
  /// was and every style keeps the one it draws by itself.
  BorderRadius? get _pillRadius {
    final shape = pillShape;
    return pillBorderRadius ?? (shape == null ? null : _radiusOf(shape));
  }

  /// Whether the selected destination opens sideways into a labelled pill. That
  /// is the pill style's own layout, and it is the one thing asking for labels
  /// [AppBottomNavLabels.below] — or for none — takes away.
  bool get _opens =>
      style == AppBottomNavStyle.pill && labels == AppBottomNavLabels.auto;

  void _select(int i) {
    HapticFeedback.selectionClick();
    onDestinationSelected(i);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      destinations.length >= 2,
      'AppBottomNav: needs at least two destinations — a bar with one of them '
      'is not navigation.',
    );
    assert(
      index >= 0 && index < destinations.length,
      'AppBottomNav: index $index is outside the ${destinations.length} '
      'destinations it was given.',
    );

    final bar = style == AppBottomNavStyle.material
        ? _material(context)
        : _drawn(context);

    return floating ? _floated(context, bar) : bar;
  }

  /// Material's own [NavigationBar] — still the right answer when you want the
  /// platform look, and the only style whose indicator animates between
  /// destinations for free.
  Widget _material(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    final pillRadius = _pillRadius;

    return NavigationBar(
      selectedIndex: index,
      // Floating, the card behind it owns the surface and the shadow — a bar
      // painting its own would draw a second edge inside the rounded one.
      backgroundColor:
          floating ? Colors.transparent : context.colorScheme.surface,
      elevation: floating ? 0 : null,
      indicatorColor: accent.withValues(
        alpha: AppInputStyle.config.fillOpacity * 2,
      ),
      // Material's indicator is the same fill the pill style draws by hand, so
      // a project that named a corner for one means it for both. Null leaves
      // NavigationBarTheme's own.
      indicatorShape: pillRadius == null
          ? null
          : RoundedRectangleBorder(borderRadius: pillRadius),
      // Material's bar writes a label under every icon on its own, so `auto`
      // and `below` are the same answer here — and null is the one that lets a
      // NavigationBarTheme still have its say.
      labelBehavior: switch (labels) {
        AppBottomNavLabels.auto => null,
        AppBottomNavLabels.below =>
          NavigationDestinationLabelBehavior.alwaysShow,
        AppBottomNavLabels.none =>
          NavigationDestinationLabelBehavior.alwaysHide,
      },
      onDestinationSelected: _select,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon, color: accent),
            label: destination.label,
          ),
      ],
    );
  }

  /// The three styles Material does not ship: one row of items over the bar's
  /// own surface.
  Widget _drawn(BuildContext context) {
    final row = SizedBox(
      height: _height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < destinations.length; i++)
            // Only a pill that opens sideways grows with its label, so only
            // that one is sized by its content — every other layout divides the
            // width evenly. A stacked pill still hugs its own content inside
            // its even share, which is what keeps it a pill.
            if (!_opens)
              Expanded(child: _item(i))
            // The open pill is the one item that can want more room than it is
            // given: Flexible lets its label ellipsize on a narrow screen
            // instead of overflowing the row.
            else if (i == index)
              Flexible(child: _item(i))
            else
              _item(i),
        ],
      ),
    );

    // Floating, the shell around it is the Material, and it has already spent
    // the safe area on the margin under the card.
    if (floating) return row;

    return Material(
      color: context.colorScheme.surface,
      child: DecoratedBox(
        // What separates the bar from the content above it, since this one
        // carries no elevation. Drawn outside the SafeArea so it spans the
        // full width on a notched phone held sideways.
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: context.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(top: false, child: row),
      ),
    );
  }

  Widget _item(int i) => _AppNavItem(
        destination: destinations[i],
        selected: i == index,
        style: style,
        labels: labels,
        // A pill that opens sideways is a stadium, which is what it has always
        // been. Stacked over a label it is taller than it is wide, and a
        // stadium there is a lozenge — so that one defaults to a card's corner,
        // the same one Material's stacked indicator wears.
        pillRadius: _pillRadius ??
            (_opens
                ? AppConstants.borderRadiusFull
                : AppConstants.borderRadius16),
        variant: variant,
        onTap: () => _select(i),
      );

  /// The card a floating bar rides in: the margin off the edges, the corner it
  /// is cut with, and the shadow that lifts it off the content passing
  /// underneath.
  Widget _floated(BuildContext context, Widget bar) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final radius = _radius;

    // A rounded end curves in over the outermost destination, and this is the
    // room that keeps it clear of the curve — so it tracks the corner rather
    // than being spent on a square card that has no curve to clear.
    final clearance = switch (radius.topLeft.x) {
      >= AppConstants.radius24 => AppConstants.space8,
      > 0 => AppConstants.space4,
      _ => 0.0,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.space16,
        right: AppConstants.space16,
        top: AppConstants.space8,
        // Just clear of the gesture indicator where there is one, a margin's
        // worth off the edge where there is not.
        bottom: inset > 0 ? inset : AppConstants.space16,
      ),
      child: DecoratedBox(
        // The same shadow an elevated AppCard casts, so the two read as
        // siblings rather than as two ideas of what "raised" looks like.
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          // A step off `surface`, which is what keeps the card visible in a
          // dark theme, where the shadow under it is not.
          color: context.colorScheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          borderRadius: radius,
          // The bar inside must not inset itself as well — NavigationBar wraps
          // itself in a SafeArea, which here would pad the inside of the card.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: clearance),
              child: bar,
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination in the styles [AppBottomNav] draws itself.
class _AppNavItem extends StatelessWidget {
  const _AppNavItem({
    required this.destination,
    required this.selected,
    required this.style,
    required this.labels,
    required this.pillRadius,
    required this.variant,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final AppBottomNavStyle style;
  final AppBottomNavLabels labels;

  /// The corner of the fill behind a selected [AppBottomNavStyle.pill].
  final BorderRadius pillRadius;

  final AppInputVariant? variant;
  final VoidCallback onTap;

  /// The mark under a selected [AppBottomNavStyle.dot] icon. Small enough to
  /// read as a mark rather than as a second icon.
  static const double _dotSize = 6;

  /// Whether this destination's name is written on screen — which decides both
  /// whether the layouts below make room for it and whether a tooltip naming
  /// the icon would be repeating what is already there.
  bool get _labelled => switch (labels) {
        AppBottomNavLabels.none => false,
        AppBottomNavLabels.below => true,
        AppBottomNavLabels.auto => switch (style) {
            AppBottomNavStyle.material || AppBottomNavStyle.classic => true,
            // The pill writes its label only once it has opened to hold it.
            AppBottomNavStyle.pill => selected,
            AppBottomNavStyle.dot => false,
          },
      };

  /// Whether this item is a pill that opens sideways on selection, as opposed
  /// to one stacked over its label or holding an icon alone.
  bool get _opens =>
      style == AppBottomNavStyle.pill && labels == AppBottomNavLabels.auto;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    final idle = context.colorScheme.onSurfaceVariant;
    final pill = style == AppBottomNavStyle.pill;

    // The pill is the one style that fills a surface behind its icon, so it is
    // the one style whose selected icon is drawn *on* the accent.
    final selectedColor =
        pill ? AppInputStyle.onAccentOf(context, variant) : accent;

    // Reduce-motion reaches the same layouts, just instantly.
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppConstants.duration200;

    final icon = Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: AppConstants.iconMedium,
      color: selected ? selectedColor : idle,
    );

    final label = Text(
      destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.labelMedium?.copyWith(
        color: selected ? selectedColor : idle,
        fontWeight: selected ? FontWeight.bold : null,
      ),
    );

    // Icon over name, or the icon alone where the name is not written. What
    // every layout here but the opening pill is built from.
    // The label is not Flexible here the way it is inside an open pill: down
    // the column, flex would hand it the leftover height instead of letting it
    // ellipsize, and the width it has to fit is the item's own either way.
    final stacked = <Widget>[
      icon,
      if (_labelled) ...[
        const SizedBox(height: AppConstants.space4),
        label,
      ],
    ];

    final Widget content = switch (style) {
      // The material style is a NavigationBar, not a row of these, so it never
      // arrives here — answering with the nearest layout beats an empty box if
      // that ever stops being true.
      AppBottomNavStyle.classic || AppBottomNavStyle.material => Column(
          mainAxisSize: MainAxisSize.min,
          children: stacked,
        ),
      AppBottomNavStyle.dot => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...stacked,
            // Closer under a label than under a bare icon, so the dot reads as
            // this destination's mark either way.
            SizedBox(
              height: _labelled ? AppConstants.space4 : AppConstants.space8,
            ),
            // The dot's room is held whether or not it is drawn, so the icons
            // do not hop as the selection moves.
            SizedBox(
              width: _dotSize,
              height: _dotSize,
              child: AnimatedOpacity(
                duration: duration,
                opacity: selected ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      AppBottomNavStyle.pill => AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal:
                _opens && selected ? AppConstants.space16 : AppConstants.space12,
            // Stacked, the label is inside the fill, and the air an open pill
            // wears above and below it would push the whole thing past the
            // height of the bar.
            vertical:
                _labelled && !_opens ? AppConstants.space4 : AppConstants.space8,
          ),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: pillRadius,
          ),
          child: _opens
              // The label is only in the tree while selected; AnimatedSize is
              // what turns its arrival into the pill opening rather than a
              // jump.
              ? AnimatedSize(
                  duration: duration,
                  curve: Curves.easeOut,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      if (selected) ...[
                        const SizedBox(width: AppConstants.space8),
                        Flexible(child: label),
                      ],
                    ],
                  ),
                )
              // Stacked, every item holds the same layout whether or not it is
              // selected, so there is nothing to animate but the fill.
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: stacked,
                ),
        ),
    };

    final target = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppConstants.touchTarget,
        minHeight: AppConstants.touchTarget,
      ),
      // Shrink-wraps where the item is sized by its content — a pill that
      // stretched to the free space beside it would not be a pill. Ignored
      // where the row hands down a tight width.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        // The label below carries the same string as the Semantics above, and
        // reading a destination out twice is what excluding it here avoids.
        child: ExcludeSemantics(child: content),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        selected: selected,
        // Some of these layouts never draw the label, and a row of unnamed
        // icons is unusable with a screen reader.
        label: destination.label,
        child: _tooltipped(
          // The ripple follows the fill it lands on where there is one, so a
          // squared-off pill is not tapped with a round splash.
          child: InkWell(
            onTap: onTap,
            borderRadius: style == AppBottomNavStyle.pill
                ? pillRadius
                : AppConstants.borderRadiusFull,
            child: target,
          ),
        ),
      ),
    );
  }

  /// Names the icon on a long press — but only where the label is not already
  /// written beside it, so a tooltip never repeats what is on screen.
  Widget _tooltipped({required Widget child}) {
    if (_labelled) return child;
    return Tooltip(message: destination.label, child: child);
  }
}
''';

  /// Returns the generated appToast template.
  ///
  /// [withDark] picks the status color per brightness; with a single brand
  /// theme there is only ever one, so the lookup drops the flag rather than
  /// reading `*Dark` constants the project does not have.
  static String appToast({bool withDark = false}) {
    final resolveSignature = withDark
        ? 'static (Color, IconData) _resolve(AppToastType type, bool isDark) =>'
        : 'static (Color, IconData) _resolve(AppToastType type) =>';

    final resolveCall = withDark
        ? 'AppToast._resolve(type, isDark)'
        : 'AppToast._resolve(type)';

    String status(String name) => withDark
        ? 'isDark ? AppConstants.${name}Dark : AppConstants.$name'
        : 'AppConstants.$name';

    return '''
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';

/// Feedback status for [AppToast].
enum AppToastType { success, error, warning, info }

/// One consistent feedback surface for the whole app.
///
/// ```dart
/// AppToast.success(context, 'Saved');
/// AppToast.show(
///   context,
///   'Check your connection and try again.',
///   title: 'Could not save',
///   type: AppToastType.error,
///   actionLabel: 'Retry',
///   onAction: _save,
/// );
/// ```
///
/// From a Riverpod notifier you already have a context inside `ref.listen` —
/// or use `ref.listenAction`, which calls this for you.
///
/// **It draws its own card on the root [Overlay], not on a [SnackBar].** A
/// SnackBar buys positioning and timing but fixes the motion: 250ms, no scale,
/// and an exit that holds full opacity for 72% of the slide before cutting out.
/// On an outlined card with a shadow that reads as a snap rather than as a
/// dismissal, and none of it is tunable. Owning the [AnimationController] buys
/// a curve on both ends — and it lets a second toast crossfade into the card
/// already on screen instead of making the user watch a full exit first.
class AppToast {
  const AppToast._();

  /// How much of the status color tints the card's surface. Enough to be felt,
  /// not enough to fight the text on it.
  static const double _surfaceTint = 0.07;

  /// The outline, which is what gives the card an edge in both themes — a
  /// shadow alone disappears against a dark background.
  static const double _borderOpacity = 0.30;

  /// The icon chip's fill. Matches [AppLeadingIcon]'s tonal fill, so the two
  /// read as siblings.
  static const double _chipFill = 0.12;

  /// Widest the card gets. Past this a toast on a tablet becomes a banner
  /// stretched across the screen, and the eye has to travel to read six words.
  static const double _maxWidth = 480;

  /// Arriving is slower than leaving. Coming in, the card has to be noticed and
  /// read, and easing it over a third of a second is what makes it look placed
  /// rather than popped; going out it has already done its job.
  static const Duration _enterDuration = Duration(milliseconds: 320);
  static const Duration _exitDuration = Duration(milliseconds: 200);

  /// How far the card rises, as a fraction of its own height. Short on purpose:
  /// a full-height slide reads as a drawer opening, this reads as it settling.
  static const double _rise = 0.35;

  /// Paired with the rise. Growing the last few percent into place is what
  /// makes it look like it came toward the user rather than up past them.
  static const double _enterScale = 0.94;

  /// The live toast, if any. One at a time by design: a stack of toasts is a
  /// log, and a log belongs on a screen rather than over one.
  static OverlayEntry? _entry;
  static ValueNotifier<_ToastSpec>? _live;

  /// Registered by the live overlay so [dismiss] can reach it without a key.
  static VoidCallback? _hideCurrent;

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    String? title,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    bool showClose = false,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _feedback(type);

    final spec = _ToastSpec(
      message: message,
      title: title,
      type: type,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      showClose: showClose,
    );

    // A toast already on screen takes the new content where it stands. Playing
    // its exit first would make the user watch 200ms of a message they have
    // been replaced out of before the one they asked for starts arriving.
    final live = _live;
    if (_entry != null && live != null) {
      live.value = spec;
      return;
    }

    final notifier = ValueNotifier<_ToastSpec>(spec);
    final entry = OverlayEntry(
      builder: (_) => _ToastOverlay(spec: notifier, onGone: _release),
    );
    _live = notifier;
    _entry = entry;
    overlay.insert(entry);
  }

  static void success(BuildContext context, String message, {String? title}) =>
      show(context, message, title: title, type: AppToastType.success);

  static void error(BuildContext context, String message, {String? title}) =>
      show(context, message, title: title, type: AppToastType.error);

  static void warning(BuildContext context, String message, {String? title}) =>
      show(context, message, title: title, type: AppToastType.warning);

  static void info(BuildContext context, String message, {String? title}) =>
      show(context, message, title: title, type: AppToastType.info);

  /// Takes the current toast off screen early — for a screen that is about to
  /// be popped, or an action whose result has already been shown another way.
  /// It animates out; nothing happens if there is no toast up.
  static void dismiss() => _hideCurrent?.call();

  /// Called by the overlay once the card is off screen. Pulling the entry any
  /// earlier would cut the exit animation off at the knees.
  static void _release() {
    // Cleared before the removal so that a second call — a swipe and a timer
    // landing on the same frame — cannot remove the same entry twice.
    final entry = _entry;
    _entry = null;
    // The notifier belongs to the overlay from insertion on, and is disposed
    // there — the widget still has to unsubscribe from it after this runs.
    _live = null;
    entry?.remove();
  }

  /// Called when the overlay goes away without the exit ever running: the route
  /// under it popped, the navigator replaced, a hot restart. The entry died
  /// with its Overlay, so there is nothing to remove — but left pointing at a
  /// disposed notifier, [show] would treat every later toast as a replacement
  /// for a card that no longer exists and quietly do nothing.
  ///
  /// Identity-checked because the exit path nulls these fields a frame before
  /// the widget is disposed, and a toast shown in that gap owns them by then.
  static void _forget(ValueNotifier<_ToastSpec> spec) {
    if (!identical(_live, spec)) return;
    _entry = null;
    _live = null;
  }

  /// A toast usually lands while the user is looking somewhere else, so it
  /// says what happened by feel as well as by color — the worse the news, the
  /// heavier the tap.
  static void _feedback(AppToastType type) => switch (type) {
        AppToastType.success => HapticFeedback.lightImpact(),
        AppToastType.warning => HapticFeedback.mediumImpact(),
        AppToastType.error => HapticFeedback.heavyImpact(),
        AppToastType.info => HapticFeedback.selectionClick(),
      };

  $resolveSignature
      switch (type) {
        AppToastType.success => (
            ${status('success')},
            Icons.check_circle_outline,
          ),
        AppToastType.error => (
            ${status('error')},
            Icons.error_outline,
          ),
        AppToastType.warning => (
            ${status('warning')},
            Icons.warning_amber_rounded,
          ),
        AppToastType.info => (
            ${status('info')},
            Icons.info_outline,
          ),
      };
}

/// Everything one call to [AppToast.show] asked for, in one object so that a
/// replacement is a single assignment the live overlay can animate across.
class _ToastSpec {
  const _ToastSpec({
    required this.message,
    required this.title,
    required this.type,
    required this.duration,
    required this.actionLabel,
    required this.onAction,
    required this.showClose,
  });

  final String message;
  final String? title;
  final AppToastType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showClose;
}

/// What actually sits in the overlay: the card, its entrance and exit, its
/// timer, and the swipe that cuts both short.
class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({required this.spec, required this.onGone});

  /// Listened to rather than passed by value, so [AppToast.show] can swap the
  /// content of a card that is already up without rebuilding the entry.
  final ValueNotifier<_ToastSpec> spec;

  /// Called once the card is off screen and the entry can be pulled.
  final VoidCallback onGone;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  Timer? _timer;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_handleStatus);
    // Out on the mirror of the way in: decelerating into place, accelerating
    // away. Reversing easeOutCubic instead would have it crawl off the screen.
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    widget.spec.addListener(_handleSpecChanged);
    AppToast._hideCurrent = _hide;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Durations are settled here and not in initState because "reduce motion"
    // is a MediaQuery — and a controller ignores a duration changed mid-flight,
    // so they have to be right before the first forward() rather than after it.
    final reduced = MediaQuery.disableAnimationsOf(context);
    _controller
      ..duration = reduced ? Duration.zero : AppToast._enterDuration
      ..reverseDuration = reduced ? Duration.zero : AppToast._exitDuration;
    if (!_entered) {
      _entered = true;
      _controller.forward();
      _restartTimer();
    }
  }

  @override
  void dispose() {
    if (AppToast._hideCurrent == _hide) AppToast._hideCurrent = null;
    AppToast._forget(widget.spec);
    _timer?.cancel();
    widget.spec.removeListener(_handleSpecChanged);
    widget.spec.dispose();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSpecChanged() {
    _restartTimer();
    // If it was on its way out, bring it back: the entry is about to be pulled
    // out from under content that has only just been handed to it.
    _controller.forward();
    setState(() {});
  }

  /// The controller only reaches `dismissed` again by completing a reverse, so
  /// this is the exit finishing and nothing else.
  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) widget.onGone();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(widget.spec.value.duration, _hide);
  }

  void _hide() {
    _timer?.cancel();
    if (mounted) _controller.reverse();
  }

  /// A flick already carried the card off screen, so there is no exit left to
  /// play — the entry goes straight away.
  void _handleSwipe() {
    _timer?.cancel();
    widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Above the keyboard while there is one, above the gesture bar when there
    // is not. A toast the keyboard covers is a toast nobody reads.
    final bottomInset = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.viewPadding.bottom;
    final spec = widget.spec.value;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppConstants.space12,
          0,
          AppConstants.space12,
          bottomInset + AppConstants.space12,
        ),
        // Bottom-center on a wide window rather than pinned to one corner. The
        // strip around the card paints nothing and so absorbs nothing: taps
        // beside the toast reach the screen underneath it.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppToast._maxWidth),
            child: FadeTransition(
              opacity: _curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, AppToast._rise),
                  end: Offset.zero,
                ).animate(_curve),
                child: ScaleTransition(
                  scale: Tween<double>(begin: AppToast._enterScale, end: 1)
                      .animate(_curve),
                  // Grows out of the edge it rose from, not out of its middle.
                  alignment: Alignment.bottomCenter,
                  child: Dismissible(
                    // New content is a new card as far as the drag is
                    // concerned; rekeying clears an offset left by a swipe the
                    // user started and abandoned.
                    key: ObjectKey(spec),
                    // Flick it away sideways, which is what a card at the edge
                    // of the screen invites; down would be into the bezel.
                    direction: DismissDirection.horizontal,
                    // Nothing sits below it to resize into.
                    resizeDuration: null,
                    onDismissed: (_) => _handleSwipe(),
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      child: Material(
                        // The overlay is outside the app's Material, and the
                        // action button wants one to ink into.
                        type: MaterialType.transparency,
                        // The card resolves its own colors from the context it
                        // is built in. Passing them down from show() looks
                        // equivalent and is not: it builds a frame later, and a
                        // theme that changed in between would leave a
                        // light-palette green on a dark card.
                        child: _ToastCard(
                          message: spec.message,
                          title: spec.title,
                          type: spec.type,
                          actionLabel: spec.actionLabel,
                          onAction: spec.onAction,
                          showClose: spec.showClose,
                        ),
                      ),
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

/// The card [AppToast] puts in the overlay. Private on purpose: a toast is
/// shown through [AppToast.show], never built by hand.
class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.title,
    required this.type,
    required this.actionLabel,
    required this.onAction,
    required this.showClose,
  });

  final String message;
  final String? title;
  final AppToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final (accent, icon) = $resolveCall;
    final heading = title;
    final hasAction = actionLabel != null && onAction != null;

    return Container(
      padding: const EdgeInsets.all(AppConstants.space12),
      decoration: BoxDecoration(
        // Tinted rather than colored: the status is carried by the icon and the
        // outline, so the text keeps the contrast the theme guarantees it.
        color: Color.alphaBlend(
          accent.withValues(alpha: AppToast._surfaceTint),
          isDark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerLowest,
        ),
        borderRadius: AppConstants.borderRadius16,
        border: Border.all(
          color: accent.withValues(alpha: AppToast._borderOpacity),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: AppConstants.space24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        // Top, not center: with a title and two lines of body the icon belongs
        // beside the first line, not floating halfway down the card.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.space8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: AppToast._chipFill),
              borderRadius: AppConstants.borderRadius8,
            ),
            child: Icon(icon, color: accent, size: AppConstants.iconSmall),
          ),
          const SizedBox(width: AppConstants.space12),
          Expanded(
            child: Padding(
              // Centers a single line against the icon chip without moving a
              // two-line one off the top.
              padding: const EdgeInsets.symmetric(vertical: AppConstants.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (heading != null)
                    Text(
                      heading,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    message,
                    // A toast is glanceable by definition; anything longer than
                    // this belongs in an AppBanner, which persists.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: heading == null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasAction) ...[
            const SizedBox(width: AppConstants.space8),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                AppToast.dismiss();
                onAction!();
              },
              style: TextButton.styleFrom(
                foregroundColor: accent,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppConstants.borderRadius8,
                ),
              ),
              child: Text(
                actionLabel!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          if (showClose)
            IconButton(
              onPressed: AppToast.dismiss,
              icon: const Icon(Icons.close, size: AppConstants.iconSmall),
              color: colorScheme.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }
}
''';
  }

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
  void initState() {
    super.initState();
    // A screen that opens with a request already in flight mounts this widget
    // loading. Without this the timers only ever start on a false-to-true
    // change, and that screen shows a bare spinner forever.
    if (widget.isLoading) _startTimers();
  }

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

  /// Returns the generated appFab template.
  static String appFab() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_button.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// The screen's one primary action, wearing [AppButtonVariant] so it matches
/// the buttons inside the screen it floats over.
///
/// ```dart
/// Scaffold(
///   floatingActionButton: AppFab(
///     icon: Icons.add,
///     label: 'New order',        // omit for a circular icon-only FAB
///     onPressed: _create,
///   ),
///   ...
/// )
/// ```
///
/// [isLoading] swaps the icon for a spinner and stops the taps without changing
/// the button's size, so a FAB that starts a request does not resize the screen
/// under it. A null [onPressed] renders it disabled — the same rule the rest of
/// the kit follows.
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
    this.variant = AppButtonVariant.primary,
    this.type = AppButtonType.filled,
    this.isLoading = false,
    this.mini = false,
    this.tooltip,
    this.heroTag,
  });

  final IconData icon;

  /// Pass null to render the FAB disabled.
  final VoidCallback? onPressed;

  /// Turns the circle into an extended pill. Skip it for the icon-only form.
  final String? label;

  final AppButtonVariant variant;

  /// [AppButtonType.filled] is the FAB Material describes;
  /// [AppButtonType.outlined] and [AppButtonType.ghost] give the quieter
  /// version a screen with its own strong content sometimes wants.
  final AppButtonType type;

  final bool isLoading;

  /// The smaller circle, for a dense screen. Ignored by the extended form,
  /// which has a label to fit.
  final bool mini;

  /// Falls back to [label] on the extended form. Worth setting on the
  /// icon-only form, which otherwise says nothing at all to a screen reader.
  final String? tooltip;

  /// Only needed when two FABs can be on screen at once, or across a route
  /// transition: Flutter animates same-tag heroes into each other and throws if
  /// it finds two.
  final Object? heroTag;

  (Color, Color) _colorsOf(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (accent, onAccent) = switch (variant) {
      AppButtonVariant.primary => (colorScheme.primary, colorScheme.onPrimary),
      AppButtonVariant.secondary => (
        colorScheme.secondary,
        colorScheme.onSecondary,
      ),
      AppButtonVariant.tertiary => (
        colorScheme.tertiary,
        colorScheme.onTertiary,
      ),
      AppButtonVariant.danger => (colorScheme.error, colorScheme.onError),
    };

    // Variant picks the color; type only decides how it is applied — the same
    // split AppButton makes.
    return switch (type) {
      AppButtonType.filled => (accent, onAccent),
      AppButtonType.outlined || AppButtonType.ghost => (
        colorScheme.surfaceContainerLowest,
        accent,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;
    final (background, foreground) = _colorsOf(context);
    final resolvedBackground = enabled
        ? background
        : background.withValues(alpha: 0.35);

    final child = isLoading
        ? SizedBox.square(
            dimension: AppConstants.iconMedium,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foreground,
            ),
          )
        : Icon(icon, color: foreground);

    void handlePress() {
      HapticFeedback.selectionClick();
      onPressed!();
    }

    final shape = RoundedRectangleBorder(
      borderRadius: AppConstants.borderRadius16,
      side: type == AppButtonType.outlined
          ? BorderSide(color: foreground, width: 1.5)
          : BorderSide.none,
    );

    final resolvedLabel = label;
    if (resolvedLabel == null) {
      return FloatingActionButton(
        onPressed: enabled ? handlePress : null,
        backgroundColor: resolvedBackground,
        foregroundColor: foreground,
        elevation: type == AppButtonType.ghost ? 0 : null,
        mini: mini,
        shape: shape,
        tooltip: tooltip,
        heroTag: heroTag,
        child: child,
      );
    }

    return FloatingActionButton.extended(
      onPressed: enabled ? handlePress : null,
      backgroundColor: resolvedBackground,
      foregroundColor: foreground,
      elevation: type == AppButtonType.ghost ? 0 : null,
      shape: shape,
      tooltip: tooltip ?? resolvedLabel,
      heroTag: heroTag,
      icon: child,
      label: Text(
        resolvedLabel,
        style: context.textTheme.titleSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
            tooltip: 'Decrease',
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
            tooltip: 'Increase',
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
    required this.tooltip,
    required this.color,
    required this.iconSize,
    required this.disabledOpacity,
    required this.onTap,
  });

  final IconData icon;

  /// Names the button. A bare glyph tells a screen reader nothing, and "−" and
  /// "+" are exactly the two a stepper cannot afford to have confused.
  final String tooltip;

  final Color color;
  final double iconSize;
  final double disabledOpacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            // Material's minimum tap target. The glyph alone left it at 40.
            constraints: const BoxConstraints(
              minWidth: AppConstants.touchTarget,
              minHeight: AppConstants.touchTarget,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: onTap == null
                  ? color.withValues(alpha: disabledOpacity)
                  : color,
            ),
          ),
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
  ///
  /// [stateManagement] only decides which async type the `AppAsyncView`
  /// section is previewed with — the rest of the kit is stack-agnostic.
  static String designSystemView({
    bool withDark = false,
    StateManagement stateManagement = StateManagement.riverpod,
  }) {
    // The brightness toggle only means something when there is a second theme
    // to switch to; with one brand theme the button would be a no-op, so the
    // state it drives goes with it.
    final themeState = withDark ? '\n  ThemeMode _mode = ThemeMode.light;' : '';

    final toggleMethod = withDark
        ? '''

  void _toggleTheme() => setState(() {
        _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      });
'''
        : '';

    final toggleDoc = withDark
        ? '\n/// Toggle light/dark using the icon in the app bar.'
        : '';

    final themeConfig = withDark
        ? '''      themeMode: _mode,
      // The app's real themes, so what this screen previews is what ships —
      // edit config/theme/app_theme.dart and every widget below follows.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,'''
        : '''      // The app's real theme, so what this screen previews is what ships —
      // edit config/theme/app_theme.dart and every widget below follows.
      theme: AppTheme.light,''';

    final toggleAction = withDark
        ? '''
              AppIconButton(
                icon: _mode == ThemeMode.light
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                onPressed: _toggleTheme,
                tooltip: 'Toggle theme',
              ),
'''
        : '';

    // The preview's fake async value comes from whichever type the project's
    // AppAsyncView takes: Riverpod's AsyncValue, or the AsyncState the bloc
    // stack declares in core/utils/action_bloc.dart.
    final asyncImport = stateManagement.isBloc
        ? "import '../../core/utils/action_bloc.dart';"
        : "import 'package:flutter_riverpod/flutter_riverpod.dart';";

    final previewAsync = stateManagement.isBloc
        ? '''  AsyncState<List<String>> get _previewAsync => switch (_asyncState) {
    1 => const AsyncLoading<List<String>>(),
    2 => AsyncFailure<List<String>>(
      AppException.noInternet(),
      StackTrace.empty,
    ),
    3 => const AsyncData<List<String>>([]),
    _ => const AsyncData<List<String>>(['One', 'Two', 'Three']),
  };'''
        : '''  AsyncValue<List<String>> get _previewAsync => switch (_asyncState) {
    1 => const AsyncValue<List<String>>.loading(),
    2 => AsyncValue<List<String>>.error(
      AppException.noInternet(),
      StackTrace.empty,
    ),
    3 => const AsyncValue<List<String>>.data([]),
    _ => const AsyncValue<List<String>>.data(['One', 'Two', 'Three']),
  };''';

    final previewAsyncDoc = stateManagement.isBloc
        ? 'Stands in for a bloc\'s state, so the four states'
        : 'Stands in for `ref.watch(someNotifierProvider)`, so the four states';

    return '''
import 'package:flutter/material.dart';
$asyncImport
import 'package:skeletonizer/skeletonizer.dart';

import '../../config/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../widgets/app_async_view.dart';
import '../widgets/buttons/app_button.dart';
import '../widgets/buttons/app_fab.dart';
import '../widgets/audio/app_audio_player.dart';
import '../widgets/buttons/app_icon_button.dart';
import '../widgets/buttons/app_text_button.dart';
import '../widgets/calendar/app_calendar.dart';
import '../widgets/cards/app_card.dart';
import '../widgets/drag/app_drag_section.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/feedback/app_banner.dart';
import '../widgets/feedback/app_progress_bar.dart';
import '../widgets/icons/app_leading_icon.dart';
import '../widgets/indicators/app_badge.dart';
import '../widgets/indicators/app_tag.dart';
import '../widgets/inputs/app_checkbox.dart';
import '../widgets/inputs/app_country_picker.dart';
import '../widgets/inputs/app_checkbox_label.dart';
import '../widgets/inputs/app_choice_chip.dart';
import '../widgets/inputs/app_date_input.dart';
import '../widgets/inputs/app_date_range_input.dart';
import '../widgets/inputs/app_dropdown_input.dart';
import '../widgets/inputs/app_file_picker_field.dart';
import '../widgets/inputs/app_input.dart';
import '../widgets/inputs/app_input_format.dart';
import '../widgets/inputs/app_input_style.dart';
import '../widgets/inputs/app_multi_select_input.dart';
import '../widgets/inputs/app_otp_input.dart';
import '../widgets/inputs/app_phone_input.dart';
import '../widgets/inputs/app_radio_group.dart';
import '../widgets/inputs/app_rating.dart';
import '../widgets/inputs/app_search_field.dart';
import '../widgets/inputs/app_segmented.dart';
import '../widgets/inputs/app_slider.dart';
import '../widgets/inputs/app_stepper.dart';
import '../widgets/inputs/app_switch.dart';
import '../widgets/inputs/app_time_input.dart';
import '../widgets/layouts/app_single_scroll_view.dart';
import '../widgets/tables/app_table.dart';
import '../widgets/text/app_heading.dart';
import '../widgets/text/app_rich_text.dart';
import '../widgets/lists/app_card_tile.dart';
import '../widgets/lists/app_expansion_tile.dart';
import '../widgets/lists/app_list_tile.dart';
import '../widgets/lists/app_section_header.dart';
import '../widgets/lists/app_timeline.dart';
import '../widgets/loadings/app_loading_action_overlay.dart';
import '../widgets/loadings/app_loading_data.dart';
import '../widgets/loadings/app_screen_lock.dart';
import '../widgets/loadings/app_skeleton_list.dart';
import '../widgets/media/app_avatar.dart';
import '../widgets/media/app_carousel.dart';
import '../widgets/media/app_image.dart';
import '../widgets/navigation/app_app_bar.dart';
import '../widgets/navigation/app_bottom_nav.dart';
import '../widgets/navigation/app_drawer.dart';
import '../widgets/navigation/app_nav_rail.dart';
import '../widgets/navigation/app_step_indicator.dart';
import '../widgets/navigation/app_tabs.dart';
import '../widgets/overlays/app_action_sheet.dart';
import '../widgets/overlays/app_bottom_sheet_scaffold.dart';
import '../widgets/overlays/app_confirm_dialog.dart';
import '../widgets/overlays/app_toast.dart';

/// Design system preview screen.
/// Shows all shared widgets rendered with your current theme.$toggleDoc
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

class _DesignSystemViewState extends State<DesignSystemView> {$themeState
  String? _selectedDropdown;
  String? _selectedRow;
  bool _accepted = false;
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
  List<String> _selectedTags = const ['b'];
  DateTimeRange? _period;
  DateTime _calendarDay = DateTime.now();
  String? _countryIso = 'PT';
  List<String> _dragCards = const ['Revenue', 'Orders', 'Refunds'];
  double _rating = 3.5;
  List<AppPickedFile> _attachments = const [];
  int _railIndex = 0;
  int _asyncState = 0;

  /// $previewAsyncDoc
  /// [AppAsyncView] draws can be stepped through here.
$previewAsync

  /// One destination list behind the bottom bar, the rail and the drawer —
  /// which is the whole point of them sharing [AppNavDestination].
  static const List<AppNavDestination> _navDestinations = [
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
  ];
$toggleMethod
  /// [style] is forced by two of the buttons so one device can preview the
  /// platform shape it is not running on.
  Future<void> _showActionSheet(
    BuildContext context, {
    AppActionSheetStyle style = AppActionSheetStyle.adaptive,
  }) async {
    final picked = await AppActionSheet.show<String>(
      context,
      style: style,
      title: 'Order #1042',
      message: 'Choose what to do with this order.',
      actions: const [
        AppSheetAction(label: 'Edit', icon: Icons.edit_outlined, value: 'edit'),
        AppSheetAction(label: 'Share', icon: Icons.ios_share, value: 'share'),
        AppSheetAction(
          label: 'Archive',
          icon: Icons.archive_outlined,
          value: 'archive',
          enabled: false,
        ),
        AppSheetAction.destructive(
          label: 'Delete',
          icon: Icons.delete_outline,
          value: 'delete',
        ),
      ],
    );
    if (!context.mounted) return;
    AppToast.info(context, picked == null ? 'Dismissed' : 'Picked: \$picked');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
$themeConfig
      home: Builder(
        builder: (context) => Scaffold(
          // The screen's own chrome is AppAppBar, so this doubles as its
          // preview — subtitle, actions and all.
          appBar: AppAppBar(
            title: 'Design System',
            subtitle: 'Every shared widget, in your theme',
            showBack: false,
            actions: [
$toggleAction              const SizedBox(width: AppConstants.space8),
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
                          label: '\${variant.name} / \${type.name}',
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
                        label: 'Label mode: \${mode.name}',
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
                        hint: 'Format: \${format.name}',
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
                        hint: 'Type: \${type.name}',
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
                        hint: 'Variant: \${variant.name}',
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
                        hint: 'Size: \${size.name}',
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
                        hint: 'Aligned \${align.name}',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Short list, so it stays a menu. `onCleared` is what puts
                    // the × in the field.
                    AppDropdownInput<String>(
                      label: 'Dropdown',
                      items: const ['a', 'b', 'c'],
                      idOf: (item) => item,
                      labelOf: (item) => 'Option \${item.toUpperCase()}',
                      selectedId: _selectedDropdown,
                      variant: AppInputVariant.secondary,
                      onChanged: (v) => setState(() => _selectedDropdown = v),
                      onCleared: () => setState(() => _selectedDropdown = null),
                    ),
                    const SizedBox(height: AppConstants.space12),
                    // Long enough to cross AppInputConfig.searchableThreshold,
                    // so it opens the search sheet without being told to.
                    AppDropdownInput<int>(
                      label: 'Auto-searchable',
                      required: true,
                      items: List.generate(60, (index) => index),
                      idOf: (item) => '\$item',
                      labelOf: (item) => 'Row \${item + 1}',
                      trailingLabelOf: (item) => '#\$item',
                      selectedId: _selectedRow,
                      variant: AppInputVariant.secondary,
                      onChanged: (v) => setState(() => _selectedRow = v),
                      onCleared: () => setState(() => _selectedRow = null),
                    ),
                  ],
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
                        label: 'Notify me (\${variant.name})',
                        subtitle: variant == AppInputVariant.primary
                            ? 'With a subtitle'
                            : null,
                        value: _checkboxValues[variant] ?? false,
                        variant: variant,
                        onChanged: (v) =>
                            setState(() => _checkboxValues[variant] = v),
                      ),
                    // `required` makes it the accept-the-terms box: the form
                    // below refuses to submit until it is ticked.
                    AppCheckboxLabel(
                      label: 'Accept the terms (required)',
                      value: _accepted,
                      required: true,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (v) => setState(() => _accepted = v),
                    ),
                    const AppCheckboxLabel(
                      label: 'Disabled row',
                      value: false,
                      onChanged: null,
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
                        SnackBar(content: Text('Confirmed: \${confirmed ?? false}')),
                      );
                    }
                  },
                ),
              ),

              // ── AppActionSheet ────────────────────────────────────────────
              _Section(
                title: 'AppActionSheet',
                child: Wrap(
                  spacing: AppConstants.space8,
                  runSpacing: AppConstants.space8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _showActionSheet(context),
                      child: const Text('Adaptive'),
                    ),
                    // Both shapes are forced here so one device can preview
                    // the platform it is not.
                    OutlinedButton(
                      onPressed: () => _showActionSheet(
                        context,
                        style: AppActionSheetStyle.material,
                      ),
                      child: const Text('Material'),
                    ),
                    OutlinedButton(
                      onPressed: () => _showActionSheet(
                        context,
                        style: AppActionSheetStyle.cupertino,
                      ),
                      child: const Text('Cupertino'),
                    ),
                  ],
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
                  label: '\${(_sliderValue * 100).round()}%',
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
                            Expanded(child: Text('\${type.name} card')),
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
                            AppListTile(title: 'Scrollable row \$i'),
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
                      onPressed: () => AppToast.info(context, 'For your info'),
                      child: const Text('Info'),
                    ),
                    // The long form: a title over the detail, and an action
                    // that dismisses the toast before it runs.
                    OutlinedButton(
                      onPressed: () => AppToast.show(
                        context,
                        'Check your connection and try again.',
                        title: 'Could not save',
                        type: AppToastType.error,
                        actionLabel: 'Retry',
                        onAction: () {},
                      ),
                      child: const Text('Title + action'),
                    ),
                    OutlinedButton(
                      onPressed: () => AppToast.show(
                        context,
                        'Stays until you send it away.',
                        title: 'Dismissible',
                        showClose: true,
                        duration: const Duration(seconds: 10),
                      ),
                      child: const Text('With close'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Style says how the selection is marked, floating says
                    // whether the bar is a band or a card — every combination
                    // is valid, and they all drive the one index.
                    for (final style in AppBottomNavStyle.values) ...[
                      Text('\${style.name}:'),
                      const SizedBox(height: AppConstants.space8),
                      AppBottomNav(
                        index: _navIndex,
                        style: style,
                        onDestinationSelected: (i) =>
                            setState(() => _navIndex = i),
                        destinations: _navDestinations,
                      ),
                      const SizedBox(height: AppConstants.space16),
                    ],
                    // Where the names are written is its own question: the pill
                    // stacks over its label instead of opening sideways, and
                    // the dot picks up a label it does not have by itself.
                    const Text('pill / labels below:'),
                    const SizedBox(height: AppConstants.space8),
                    AppBottomNav(
                      index: _navIndex,
                      style: AppBottomNavStyle.pill,
                      labels: AppBottomNavLabels.below,
                      onDestinationSelected: (i) =>
                          setState(() => _navIndex = i),
                      destinations: _navDestinations,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('dot / labels below:'),
                    const SizedBox(height: AppConstants.space8),
                    AppBottomNav(
                      index: _navIndex,
                      style: AppBottomNavStyle.dot,
                      labels: AppBottomNavLabels.below,
                      onDestinationSelected: (i) =>
                          setState(() => _navIndex = i),
                      destinations: _navDestinations,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    // The fill behind the selection takes a corner of its own,
                    // whichever one the style would have picked.
                    const Text('pill / labels below / square pill:'),
                    const SizedBox(height: AppConstants.space8),
                    AppBottomNav(
                      index: _navIndex,
                      style: AppBottomNavStyle.pill,
                      labels: AppBottomNavLabels.below,
                      pillShape: AppBottomNavShape.square,
                      onDestinationSelected: (i) =>
                          setState(() => _navIndex = i),
                      destinations: _navDestinations,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('classic / labels none:'),
                    const SizedBox(height: AppConstants.space8),
                    AppBottomNav(
                      index: _navIndex,
                      style: AppBottomNavStyle.classic,
                      labels: AppBottomNavLabels.none,
                      onDestinationSelected: (i) =>
                          setState(() => _navIndex = i),
                      destinations: _navDestinations,
                    ),
                    const SizedBox(height: AppConstants.space16),
                    // Floating, in each corner it can be cut with. The surface
                    // behind them is the point: a floating bar is meant to have
                    // content passing under its margin.
                    for (final shape in AppBottomNavShape.values) ...[
                      Text('pill / floating / \${shape.name}:'),
                      const SizedBox(height: AppConstants.space8),
                      ColoredBox(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLowest,
                        child: AppBottomNav(
                          index: _navIndex,
                          style: AppBottomNavStyle.pill,
                          floating: true,
                          floatingShape: shape,
                          onDestinationSelected: (i) =>
                              setState(() => _navIndex = i),
                          destinations: _navDestinations,
                        ),
                      ),
                      const SizedBox(height: AppConstants.space16),
                    ],
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
                            'Send \\\$120.00 to Jane Doe?',
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

              // ── AppTextButton ─────────────────────────────────────────────
              _Section(
                title: 'AppTextButton',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Types (primary):'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final type in AppTextButtonType.values)
                          AppTextButton(
                            label: type.name,
                            type: type,
                            onPressed: () {},
                          ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    // The neutral variant is the one the louder controls do not
                    // have: the action offered without being urged.
                    const Text('Variants (plain):'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final variant in AppTextButtonVariant.values)
                          AppTextButton(
                            label: variant.name,
                            variant: variant,
                            onPressed: () {},
                          ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Sizes (tonal, pill):'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final size in AppTextButtonSize.values)
                          AppTextButton(
                            label: size.name,
                            size: size,
                            type: AppTextButtonType.tonal,
                            shape: AppTextButtonShape.pill,
                            onPressed: () {},
                          ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Icons & states:'),
                    const SizedBox(height: AppConstants.space8),
                    Wrap(
                      spacing: AppConstants.space8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppTextButton(
                          label: 'See all',
                          suffixIcon: Icons.chevron_right,
                          onPressed: () {},
                        ),
                        AppTextButton(
                          label: 'Add note',
                          prefixIcon: Icons.add,
                          variant: AppTextButtonVariant.secondary,
                          onPressed: () {},
                        ),
                        // Loading keeps the label's exact width, so nothing in
                        // the row moves while it spins.
                        const AppTextButton(label: 'Resending…', isLoading: true),
                        const AppTextButton(
                          label: 'Disabled',
                          variant: AppTextButtonVariant.danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Dense — no touch target, for a tight row:'),
                    const SizedBox(height: AppConstants.space8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent orders'),
                        AppTextButton(
                          label: 'See all',
                          size: AppTextButtonSize.small,
                          dense: true,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    // Bare drops the button box; the alignment claims the width
                    // it needs to push the label to the edge.
                    const Text('Bare + aligned right — just the link:'),
                    const SizedBox(height: AppConstants.space8),
                    AppTextButton(
                      label: 'Forgot password?',
                      type: AppTextButtonType.underlined,
                      size: AppTextButtonSize.small,
                      bare: true,
                      alignment: Alignment.centerRight,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // ── AppHeading ────────────────────────────────────────────────
              _Section(
                title: 'AppHeading — sizes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final size in AppHeadingSize.values)
                      AppHeading(
                        title: size.name,
                        subtitle: 'With a supporting line',
                        size: size,
                      ),
                  ],
                ),
              ),

              _Section(
                title: 'AppHeading — variants, align & extras',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final variant in AppHeadingVariant.values)
                      AppHeading(
                        title: variant.name,
                        size: AppHeadingSize.small,
                        variant: variant,
                      ),
                    const SizedBox(height: AppConstants.space8),
                    for (final align in AppHeadingAlign.values)
                      AppHeading(
                        title: 'Aligned \${align.name}',
                        subtitle: 'The subtitle follows the title',
                        size: AppHeadingSize.small,
                        align: align,
                      ),
                    const SizedBox(height: AppConstants.space8),
                    const AppHeading(
                      title: 'With an icon',
                      icon: Icons.tune,
                      variant: AppHeadingVariant.primary,
                    ),
                    AppHeading(
                      title: 'With a trailing slot',
                      subtitle: 'And a rule under it',
                      divider: true,
                      trailing: AppIconButton(
                        icon: Icons.more_horiz,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(height: AppConstants.space8),
                    const AppHeading(
                      title: 'A title long enough that it has to stop somewhere '
                          'rather than run on down the screen',
                      size: AppHeadingSize.small,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              // ── AppRichText ───────────────────────────────────────────────
              _Section(
                title: 'AppRichText',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('A style per span:'),
                    const SizedBox(height: AppConstants.space8),
                    AppRichText(
                      style: Theme.of(context).textTheme.bodyLarge,
                      spans: const [
                        AppSpan('Plain, '),
                        AppSpan.bold('bold'),
                        AppSpan(', '),
                        AppSpan('italic', italic: true),
                        AppSpan(', '),
                        AppSpan('muted', variant: AppSpanVariant.muted),
                        AppSpan(', '),
                        AppSpan('danger', variant: AppSpanVariant.danger),
                        AppSpan(', '),
                        AppSpan(
                          'struck',
                          decoration: TextDecoration.lineThrough,
                        ),
                        AppSpan(' and '),
                        AppSpan(
                          '1.6×',
                          scale: 1.6,
                          weight: FontWeight.w700,
                          variant: AppSpanVariant.primary,
                        ),
                        AppSpan('.'),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Tappable spans — tap either, hold the second:'),
                    const SizedBox(height: AppConstants.space8),
                    AppRichText(
                      spans: [
                        const AppSpan('By continuing you agree to our '),
                        AppSpan.link(
                          'Terms',
                          onTap: () => AppToast.info(context, 'Terms tapped'),
                        ),
                        const AppSpan(' and '),
                        AppSpan.link(
                          'Privacy Policy',
                          onTap: () => AppToast.info(context, 'Privacy tapped'),
                          onLongPress: () =>
                              AppToast.success(context, 'Link copied'),
                        ),
                        const AppSpan('.'),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    const Text('An icon, and a whole widget, inline:'),
                    const SizedBox(height: AppConstants.space8),
                    const AppRichText(
                      spans: [
                        AppSpan('Delivery by '),
                        AppSpan.bold('Friday'),
                        AppSpan(' '),
                        AppSpan.icon(
                          Icons.local_shipping_outlined,
                          variant: AppSpanVariant.primary,
                        ),
                        AppSpan('  '),
                        AppSpan.widget(
                          AppTag(
                            label: 'On time',
                            status: AppTagStatus.success,
                            icon: Icons.check,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    // The sentence comes from one translatable string; the
                    // translator moves {placeholders} and the styling follows.
                    const Text('A sentence from {placeholders}:'),
                    const SizedBox(height: AppConstants.space8),
                    AppRichText(
                      spans: AppSpan.template(
                        'Signed in as {email}. {action} at any time.',
                        {
                          'email': const AppSpan.bold(
                            'ana@example.com',
                            variant: AppSpanVariant.neutral,
                          ),
                          'action': AppSpan.link(
                            'Switch account',
                            onTap: () =>
                                AppToast.info(context, 'Switch account'),
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: AppConstants.space16),
                    // Reads the query typed into AppSearchField above.
                    const Text('Search highlighting:'),
                    const SizedBox(height: AppConstants.space8),
                    AppRichText(
                      selectable: true,
                      spans: AppSpan.highlight(
                        'The quick brown fox jumps over the lazy dog.',
                        query: _query.isEmpty ? 'the' : _query,
                      ),
                    ),
                    const SizedBox(height: AppConstants.space4),
                    Text(
                      _query.isEmpty
                          ? 'Type in AppSearchField above to change the query.'
                          : 'Matching "\$_query"',
                      style: Theme.of(context).textTheme.bodySmall,
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
                      _query.isEmpty ? 'Query: (empty)' : 'Query: \$_query',
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

              // ── AppAsyncView ──────────────────────────────────────────────
              _Section(
                title: 'AppAsyncView',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSegmented<int>(
                      segments: const [0, 1, 2, 3],
                      selected: _asyncState,
                      labelOf: (i) =>
                          const ['data', 'loading', 'error', 'empty'][i],
                      onChanged: (i) => setState(() => _asyncState = i),
                    ),
                    const SizedBox(height: AppConstants.space12),
                    SizedBox(
                      height: 220,
                      child: AppAsyncView<List<String>>(
                        value: _previewAsync,
                        isEmpty: (rows) => rows.isEmpty,
                        emptyTitle: 'Nothing to show',
                        emptyMessage: 'Rows will appear here once there are any.',
                        onRetry: () => setState(() => _asyncState = 0),
                        // The shape the skeleton is traced from: the same list,
                        // with placeholder rows in it. Fake rows, not an empty
                        // list — there has to be something there to shimmer.
                        skeleton: (context) => Column(
                          children: [
                            for (var i = 0; i < 3; i++)
                              AppListTile(
                                title: BoneMock.name,
                                subtitle: BoneMock.subtitle,
                              ),
                          ],
                        ),
                        builder: (context, rows) => Column(
                          children: [
                            for (final row in rows)
                              AppListTile(title: row, subtitle: 'Loaded'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── AppPhoneInput ─────────────────────────────────────────────
              _Section(
                title: 'AppPhoneInput',
                child: AppPhoneInput(
                  label: 'Phone',
                  required: true,
                  initialCountry: 'PT',
                  onChanged: (_) {},
                ),
              ),

              // ── AppMultiSelectInput ───────────────────────────────────────
              _Section(
                title: 'AppMultiSelectInput',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppMultiSelectInput<String>(
                      label: 'Tags',
                      items: const ['a', 'b', 'c', 'd', 'e'],
                      idOf: (item) => item,
                      labelOf: (item) => 'Tag \${item.toUpperCase()}',
                      selectedIds: _selectedTags,
                      required: true,
                      maxSelected: 3,
                      onChanged: (ids) => setState(() => _selectedTags = ids),
                    ),
                    const SizedBox(height: AppConstants.space12),
                    // The same selection, summarised instead of chipped.
                    AppMultiSelectInput<String>(
                      label: 'Same field, counted',
                      items: const ['a', 'b', 'c', 'd', 'e'],
                      idOf: (item) => item,
                      labelOf: (item) => 'Tag \${item.toUpperCase()}',
                      selectedIds: _selectedTags,
                      display: AppMultiSelectDisplay.count,
                      variant: AppInputVariant.secondary,
                      onChanged: (ids) => setState(() => _selectedTags = ids),
                    ),
                  ],
                ),
              ),

              // ── AppDateRangeInput ─────────────────────────────────────────
              _Section(
                title: 'AppDateRangeInput',
                child: AppDateRangeInput(
                  label: 'Period',
                  hint: 'Pick a range',
                  maxDays: 31,
                  initialValue: _period,
                  onChanged: (range) => setState(() => _period = range),
                  onCleared: () => setState(() => _period = null),
                ),
              ),

              // ── AppCalendar ───────────────────────────────────────────────
              _Section(
                title: 'AppCalendar',
                child: AppCalendar(
                  selected: _calendarDay,
                  canChangeFormat: true,
                  // Whatever time the data carries, the dot lands on the day.
                  events: {
                    DateTime.now(): 1,
                    DateTime.now().add(const Duration(days: 2)): 3,
                    DateTime.now().subtract(const Duration(days: 3)): 2,
                  },
                  onSelected: (day) => setState(() => _calendarDay = day),
                ),
              ),

              // ── AppCountryPicker ──────────────────────────────────────────
              _Section(
                title: 'AppCountryPicker',
                child: AppCountryPicker(
                  selectedIso: _countryIso,
                  required: true,
                  onChanged: (country) =>
                      setState(() => _countryIso = country.iso),
                  onCleared: () => setState(() => _countryIso = null),
                ),
              ),

              // ── AppTable ──────────────────────────────────────────────────
              _Section(
                title: 'AppTable',
                child: AppTable(
                  striped: true,
                  showRowDividers: false,
                  columns: const [
                    AppTableColumn(label: 'Item', flex: 2),
                    AppTableColumn.numeric(label: 'Qty', width: 48),
                    AppTableColumn.numeric(label: 'Total'),
                  ],
                  rows: [
                    AppTableRow(cells: const ['Coffee', '2', '7.00'],
                        onTap: () {}),
                    AppTableRow(cells: const ['Pastry', '1', '2.40'],
                        onTap: () {}),
                    AppTableRow(
                      cells: const ['Juice', '3', '9.60'],
                      selected: true,
                      onTap: () {},
                    ),
                  ],
                  footer: const AppTableRow(cells: ['Total', '6', '19.00']),
                ),
              ),

              // ── AppDragSection ────────────────────────────────────────────
              _Section(
                title: 'AppDragSection (hold an item to move it)',
                child: AppDragSection(
                  items: [
                    for (final card in _dragCards)
                      AppDragItem(
                        id: card,
                        child: AppCard(
                          child: ListTile(
                            leading: const Icon(Icons.drag_indicator),
                            title: Text(card),
                          ),
                        ),
                      ),
                    // Pinned: it keeps the last slot however the rest are
                    // shuffled, and nothing can be dropped past it.
                    const AppDragItem(
                      id: '_add',
                      draggable: false,
                      child: AppCard(
                        child: ListTile(
                          leading: Icon(Icons.add),
                          title: Text('Add a card (pinned)'),
                        ),
                      ),
                    ),
                  ],
                  onReorder: (from, to) => setState(
                    () => _dragCards =
                        AppDragSection.reorder(_dragCards, from, to),
                  ),
                ),
              ),

              // ── AppAudioPlayer ────────────────────────────────────────────
              const _Section(
                title: 'AppAudioPlayer',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A short public-domain clip, so the preview has something
                    // real to scrub. Point it at your own audio.
                    AppAudioPlayer(
                      source: AppAudioSource.url(
                        'https://file-examples.com/storage/fe0b4b1a2f/file_example_MP3_700KB.mp3',
                      ),
                      title: 'Episode 12',
                      subtitle: 'The one about Flutter',
                      showSpeed: true,
                      showRemaining: true,
                    ),
                    SizedBox(height: AppConstants.space12),
                    // The same widget as a voice note: one row, nothing to
                    // skip, no speed.
                    AppAudioPlayer(
                      source: AppAudioSource.url(
                        'https://file-examples.com/storage/fe0b4b1a2f/file_example_MP3_700KB.mp3',
                      ),
                      style: AppAudioPlayerStyle.compact,
                      showSkip: false,
                      showRemaining: true,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              // ── AppRating ─────────────────────────────────────────────────
              _Section(
                title: 'AppRating',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppRating(
                      label: 'How did we do?',
                      value: _rating,
                      required: true,
                      allowHalf: true,
                      allowClear: true,
                      showValueLabel: true,
                      onChanged: (v) => setState(() => _rating = v),
                    ),
                    const SizedBox(height: AppConstants.space12),
                    // No onChanged — the same widget as a read-only score.
                    AppRating(
                      value: _rating,
                      allowHalf: true,
                      starSize: AppConstants.iconSmall,
                      variant: AppInputVariant.tertiary,
                    ),
                  ],
                ),
              ),

              // ── AppFilePickerField ────────────────────────────────────────
              _Section(
                title: 'AppFilePickerField',
                child: AppFilePickerField(
                  label: 'Attachments',
                  files: _attachments,
                  maxFiles: 3,
                  // A real screen calls its own picker here; this stands one in
                  // so the field can be tried without a plugin.
                  onPick: () async => const [
                    AppPickedFile(name: 'invoice.pdf', sizeBytes: 184320),
                  ],
                  onChanged: (files) => setState(() => _attachments = files),
                ),
              ),

              // ── AppFab ────────────────────────────────────────────────────
              _Section(
                title: 'AppFab',
                child: Wrap(
                  spacing: AppConstants.space16,
                  runSpacing: AppConstants.space16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Two FABs on one screen need distinct hero tags — Flutter
                    // animates same-tag heroes into each other.
                    AppFab(
                      icon: Icons.add,
                      heroTag: 'preview-fab',
                      tooltip: 'Add',
                      onPressed: () {},
                    ),
                    AppFab(
                      icon: Icons.edit_outlined,
                      label: 'New order',
                      heroTag: 'preview-fab-extended',
                      onPressed: () {},
                    ),
                    AppFab(
                      icon: Icons.delete_outline,
                      variant: AppButtonVariant.danger,
                      type: AppButtonType.outlined,
                      mini: true,
                      heroTag: 'preview-fab-danger',
                      tooltip: 'Delete',
                      onPressed: () {},
                    ),
                    AppFab(
                      icon: Icons.cloud_upload_outlined,
                      label: 'Uploading',
                      isLoading: true,
                      heroTag: 'preview-fab-loading',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // ── AppTabs ───────────────────────────────────────────────────
              _Section(
                title: 'AppTabs',
                child: SizedBox(
                  height: 180,
                  child: AppTabs(
                    tabs: const [
                      AppTab(label: 'Open', icon: Icons.inbox_outlined),
                      AppTab(label: 'Closed', icon: Icons.check_circle_outline),
                    ],
                    style: AppTabsStyle.pill,
                    children: [
                      for (final label in ['Open orders', 'Closed orders'])
                        Center(child: Text(label)),
                    ],
                  ),
                ),
              ),

              // ── AppTimeline ───────────────────────────────────────────────
              const _Section(
                title: 'AppTimeline',
                child: AppTimeline(
                  entries: [
                    AppTimelineEntry(
                      title: 'Ordered',
                      subtitle: '2 items',
                      timestamp: 'Mon 09:12',
                      icon: Icons.check,
                    ),
                    AppTimelineEntry(title: 'Shipped', timestamp: 'Tue 11:40'),
                    AppTimelineEntry(
                      title: 'Out for delivery',
                      status: AppTimelineStatus.current,
                    ),
                    AppTimelineEntry(
                      title: 'Delivered',
                      status: AppTimelineStatus.pending,
                    ),
                  ],
                ),
              ),

              // ── AppCarousel ───────────────────────────────────────────────
              _Section(
                title: 'AppCarousel',
                child: AppCarousel(
                  aspectRatio: 16 / 9,
                  autoPlay: const Duration(seconds: 4),
                  indicatorInside: true,
                  children: [
                    for (final (index, color) in [
                      Colors.indigo,
                      Colors.teal,
                      Colors.deepOrange,
                    ].indexed)
                      Container(
                        color: color.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: Text('Page \${index + 1}'),
                      ),
                  ],
                ),
              ),

              // ── AppNavRail & AppDrawer ────────────────────────────────────
              _Section(
                title: 'AppNavRail / AppDrawer',
                child: SizedBox(
                  height: 300,
                  child: Row(
                    children: [
                      AppNavRail(
                        destinations: _navDestinations,
                        index: _railIndex,
                        onDestinationSelected: (i) =>
                            setState(() => _railIndex = i),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: AppDrawer(
                          destinations: _navDestinations,
                          selectedIndex: _railIndex,
                          onDestinationSelected: (i) =>
                              setState(() => _railIndex = i),
                          header: const AppDrawerHeader(
                            title: 'Acme',
                            subtitle: 'Signed in',
                          ),
                        ),
                      ),
                    ],
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
          Text('\${value.toInt()}pt', style: Theme.of(context).textTheme.labelSmall),
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
}
