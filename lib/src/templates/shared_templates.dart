class SharedTemplates {
  SharedTemplates._();

  static String appButton() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

enum AppButtonType { primary, secondary, tertiary, transparent, danger }

enum AppButtonSize { large, medium, small }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.type,
    required this.label,
    required this.onPressed,
    this.prefixIcon,
    this.suffixIcon,
    this.width,
    this.size = AppButtonSize.medium,
  });

  final AppButtonType type;
  final String label;
  final VoidCallback onPressed;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final double? width;
  final AppButtonSize size;

  (double height, double fontSize, double iconSize, EdgeInsets padding)
  _getSizeConfig() {
    switch (size) {
      case AppButtonSize.small:
        return (AppConstants.touchTarget, 14, 18, AppConstants.padding12);
      case AppButtonSize.medium:
        return (AppConstants.touchTarget + 4, 16, 22, AppConstants.padding16);
      case AppButtonSize.large:
        return (AppConstants.touchTarget + 8, 18, 26, EdgeInsets.all(AppConstants.space16 + 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final (height, fontSize, iconSize, padding) = _getSizeConfig();

    Color? backgroundColor;
    Color? foregroundColor;

   (backgroundColor, foregroundColor) = switch (type) {
    AppButtonType.primary   => (theme.colorScheme.primary, theme.colorScheme.onPrimary),
    AppButtonType.secondary => (theme.colorScheme.secondary, theme.colorScheme.onSecondary),
    AppButtonType.tertiary  => (theme.colorScheme.tertiary, theme.colorScheme.onTertiary),
    AppButtonType.transparent => (Colors.transparent, theme.colorScheme.primary),
    AppButtonType.danger    => (theme.colorScheme.error, theme.colorScheme.onError),
    };

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: padding,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppConstants.borderRadius12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppConstants.space4,
          children: [
            if (prefixIcon != null) Icon(prefixIcon, size: iconSize, color: foregroundColor),
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                color: foregroundColor,
                fontSize: fontSize,
              ),
            ),
            if (suffixIcon != null) Icon(suffixIcon, size: iconSize, color: foregroundColor),
          ],
        ),
      ),
    );
  }
}

''';

  static String appInput() => r'''
  import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.maxLines,
    this.isPassword = false,
    this.initialValue,
    this.keyboardType,
    this.textInputAction,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.autoFocus = false,
    this.required = false,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final int? maxLines;
  final bool isPassword;
  final String? initialValue;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final bool autoFocus;
  final bool required;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  @override
  void initState() {
    if (widget.initialValue != null) {
      widget.controller?.text = widget.initialValue!;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final verticalPadding =
        (AppConstants.touchTarget - AppConstants.fontSize16) / 2;

    return Column(
      spacing: AppConstants.space8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: widget.label,
            style: theme.textTheme.bodyLarge?.copyWith(letterSpacing: 1.25),
            children: widget.required
                ? [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                : [],
          ),
        ),
        IgnorePointer(
          ignoring: widget.readOnly,
          child: TextFormField(
            focusNode: widget.focusNode,
            autofocus: widget.autoFocus,
            readOnly: widget.readOnly,
            controller: widget.controller,
            style: theme.textTheme.bodyLarge,
            initialValue: widget.controller == null
                ? widget.initialValue
                : null,
            maxLines: widget.maxLines ?? 1,
            obscureText: widget.isPassword,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              hint: Text(
                widget.hint ?? "",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: verticalPadding,
                horizontal: AppConstants.space12,
              ),
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

  static String appLoadingData() => r'''
import 'package:flutter/material.dart';

class AppLoadingData extends StatelessWidget {
  const AppLoadingData({super.key, this.appBar});
  final bool? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar == true ? AppBar() : null,
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

''';

  static String appLoadingAction() => r'''
import 'package:flutter/material.dart';

class AppLoadingAction extends StatelessWidget {
  const AppLoadingAction({
    super.key,
    required this.isLoading,
    this.onlyLoading = false,
  });
  final bool isLoading;
  final bool onlyLoading;

  @override
  Widget build(BuildContext context) {
    if (onlyLoading) return Center(child: CircularProgressIndicator.adaptive());

    return isLoading
        ? Positioned(
          child: Container(
            color: Colors.black.withAlpha(100),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        )
        : SizedBox.shrink();
  }
}

''';

  static String errorView() => r'''
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

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
}
