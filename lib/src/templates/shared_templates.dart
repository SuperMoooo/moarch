class SharedTemplates {
  SharedTemplates._();

  static String appButton() => r'''
import 'package:flutter/material.dart';
import 'package:projeto_flutter/core/theme/app_theme.dart';

enum AppButtonType { primary, secondary, tertiary, danger }

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
    this.size = ButtonSize.large,
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
      case ButtonSize.small:
        return (40, 14, 18, const EdgeInsets.symmetric(horizontal: 12));
      case ButtonSize.medium:
        return (50, 16, 22, const EdgeInsets.symmetric(horizontal: 16));
      case ButtonSize.large:
        return (65, 18, 26, const EdgeInsets.symmetric(horizontal: 20));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final (height, fontSize, iconSize, padding) = _getSizeConfig();

    Color? backgroundColor;
    Color? foregroundColor;

    switch (type) {
      case ButtonType.primary:
        {
          backgroundColor = theme.colorScheme.primary;
          foregroundColor = theme.colorScheme.onPrimary;
          break;
        }
      case ButtonType.secondary:
        {
          backgroundColor = theme.colorScheme.secondary;
          foregroundColor = theme.colorScheme.onSecondary;
          break;
        }
      case ButtonType.tertiary:
        {
          backgroundColor = theme.colorScheme.tertiary;
          foregroundColor = theme.colorScheme.onTertiary;
          break;
        }
      case ButtonType.danger:
        {
          backgroundColor = theme.colorScheme.error;
          foregroundColor = theme.colorScheme.onError;
          break;
        }
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: padding,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.borderRadiusFull),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Sizes.spacing,
          children: [
            if (prefixIcon != null) Icon(prefixIcon, size: iconSize),
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                color: foregroundColor,
                fontSize: fontSize,
              ),
            ),
            if (suffixIcon != null) Icon(suffixIcon, size: iconSize),
          ],
        ),
      ),
    );
  }
}

''';

  static String appInput() => r''' 
  import 'package:flutter/material.dart';
import 'package:projeto_flutter/core/theme/app_theme.dart';

class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    this.controller,
    required this.label,
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
  State<BaseInput> createState() => _BaseInputState();
}

class _BaseInputState extends State<BaseInput> {
  @override
  void initState() {
    if (widget.initialValue != null) {
      widget.controller?.text = widget.initialValue!;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: widget.readOnly,
      child: TextFormField(
        focusNode: widget.focusNode,
        autofocus: widget.autoFocus,
        readOnly: widget.readOnly,
        controller: widget.controller,
        style: theme.textTheme.bodyLarge,
        initialValue: widget.controller == null ? widget.initialValue : null,
        maxLines: widget.maxLines ?? 1,
        obscureText: widget.isPassword,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          label: Text.rich(
            TextSpan(
              text: widget.label,
              style: theme.textTheme.bodyLarge,
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
          labelStyle: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(220),
          ),
          contentPadding: EdgeInsets.all(Sizes.padding),
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainer,

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Sizes.borderRadius),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Sizes.borderRadius),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

''';

  static String appLoading() => r'''
import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
''';

  static String errorView() => r'''
import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
}
