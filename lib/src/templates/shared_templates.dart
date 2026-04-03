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
  _getSizeConfig() => switch (size) {
    AppButtonSize.small => (
      AppConstants.touchTarget,
      14,
      18,
      AppConstants.padding12,
    ),
    AppButtonSize.medium => (
      AppConstants.touchTarget + 4,
      16,
      22,
      AppConstants.padding16,
    ),
    AppButtonSize.large => (
      AppConstants.touchTarget + 8,
      18,
      26,
      EdgeInsets.all(AppConstants.space16 + 2),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final (height, fontSize, iconSize, padding) = _getSizeConfig();

    final (backgroundColor, foregroundColor) = switch (type) {
      AppButtonType.primary     => (theme.colorScheme.primary, theme.colorScheme.onPrimary),
      AppButtonType.secondary   => (theme.colorScheme.secondary, theme.colorScheme.onSecondary),
      AppButtonType.tertiary    => (theme.colorScheme.tertiary, theme.colorScheme.onTertiary),
      AppButtonType.transparent => (Colors.transparent, theme.colorScheme.onSurface),
      AppButtonType.danger      => (theme.colorScheme.error, theme.colorScheme.onError),
    };

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: padding,
          backgroundColor: type == AppButtonType.tertiary
              ? Colors.transparent
              : backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppConstants.borderRadius12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefixIcon != null) ...[
              Icon(prefixIcon, size: iconSize, color: foregroundColor),
              const SizedBox(width: AppConstants.space4),
            ],
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                color: foregroundColor,
                fontSize: fontSize,
              ),
            ),
            if (suffixIcon != null) ...[
              const SizedBox(width: AppConstants.space4),
              Icon(suffixIcon, size: iconSize, color: foregroundColor),
            ],
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
    this.maxLines = 1,
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
    super.initState();
    if (widget.initialValue != null) {
      widget.controller?.text = widget.initialValue!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

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
            initialValue: widget.controller == null ? widget.initialValue : null,
            maxLines: widget.maxLines,
            obscureText: widget.isPassword,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              hintText: widget.hint,
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

  static String dateInput() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

class DateAppInput extends StatefulWidget {
  const DateAppInput({
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

  @override
  State<DateAppInput> createState() => _DateAppInputState();
}

class _DateAppInputState extends State<DateAppInput> {
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
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    );
    if (picked != null) {
      setState(() {
        widget.controller?.text = picked.formattedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

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
            onTap: () => _selectDate(context),
            focusNode: widget.focusNode,
            autofocus: widget.autoFocus,
            readOnly: true,
            controller: widget.controller,
            style: theme.textTheme.bodyLarge,
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              hintText: widget.hint,
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

  static String timeInput() => r'''
import 'package:flutter/material.dart';

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

  @override
  State<AppTimeInput> createState() => _AppTimeInputState();
}

class _AppTimeInputState extends State<AppTimeInput> {
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
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        widget.controller?.text = picked.formattedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

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
            onTap: () => _selectTime(context),
            focusNode: widget.focusNode,
            autofocus: widget.autoFocus,
            readOnly: true,
            controller: widget.controller,
            style: theme.textTheme.bodyLarge,
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              hintText: widget.hint,
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

  static String appDropdown() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

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
  });

  final String label;
  final List<T> items;
  final String Function(T item) idOf;
  final String Function(T item) labelOf;
  final ValueChanged<String> onChanged;
  final String? selectedId;
  final String hint;
  final bool enabled;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      spacing: AppConstants.space8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: theme.textTheme.bodyLarge?.copyWith(letterSpacing: 1.25),
            children: required
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
          ignoring: !enabled,
          child: DropdownButtonFormField<String>(
            value: selectedId,
            hint: Text(hint),
            isExpanded: true,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            icon: enabled ? const Icon(Icons.keyboard_arrow_down) : null,
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: idOf(item),
                    child: Text(labelOf(item)),
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
    if (onlyLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (!isLoading) return const SizedBox.shrink();

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withAlpha(100),
        child: const Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}
''';

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
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
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

  static String designSystemView() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../widgets/buttons/app_button.dart';
import '../widgets/error_view.dart';
import '../widgets/loadings/app_loading_action.dart';
import '../widgets/loadings/app_loading_data.dart';

/// Design system preview screen.
/// Shows all shared widgets rendered with your current theme.
/// Toggle light/dark using the icon in the app bar.
///
/// Add to your router temporarily:
///   GoRoute(
///     path: '/design-system',
///     builder: (_, __) => const DesignSystemView(),
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
                    AppButton(type: AppButtonType.primary,   label: 'Primary',   onPressed: () {}),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(type: AppButtonType.secondary, label: 'Secondary', onPressed: () {}),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(type: AppButtonType.tertiary,  label: 'Tertiary',  onPressed: () {}),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(type: AppButtonType.transparent, label: 'Transparent', onPressed: () {}),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(type: AppButtonType.danger,    label: 'Danger',    onPressed: () {}),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(type: AppButtonType.primary,   label: 'With prefix icon', onPressed: () {}, prefixIcon: Icons.add),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(type: AppButtonType.primary,   label: 'With suffix icon', onPressed: () {}, suffixIcon: Icons.arrow_forward),
                    const SizedBox(height: AppConstants.space16),
                    const Text('Sizes:'),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(type: AppButtonType.primary, label: 'Small',  onPressed: () {}, size: AppButtonSize.small),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(type: AppButtonType.primary, label: 'Medium', onPressed: () {}, size: AppButtonSize.medium),
                    const SizedBox(height: AppConstants.space8),
                    AppButton(type: AppButtonType.primary, label: 'Large',  onPressed: () {}, size: AppButtonSize.large),
                  ],
                ),
              ),

              // ── Inputs ────────────────────────────────────────────────────
              _Section(
                title: 'Inputs',
                child: Column(
                  children: [
                    const TextField(
                      decoration: InputDecoration(hintText: 'Default input'),
                    ),
                    const SizedBox(height: AppConstants.space12),
                    const TextField(
                      decoration: InputDecoration(
                        hintText: 'With prefix icon',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: AppConstants.space12),
                    const TextField(
                      decoration: InputDecoration(
                        hintText: 'Error state',
                        errorText: 'This field is required',
                      ),
                    ),
                    const SizedBox(height: AppConstants.space12),
                    const TextField(
                      enabled: false,
                      decoration: InputDecoration(hintText: 'Disabled'),
                    ),
                    const SizedBox(height: AppConstants.space12),
                    DropdownButtonFormField<String>(
                      value: _selectedDropdown,
                      hint: const Text('Dropdown'),
                      items: const [
                        DropdownMenuItem(value: 'a', child: Text('Option A')),
                        DropdownMenuItem(value: 'b', child: Text('Option B')),
                        DropdownMenuItem(value: 'c', child: Text('Option C')),
                      ],
                      onChanged: (v) => setState(() => _selectedDropdown = v),
                    ),
                  ],
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

              _Section(
                title: 'AppLoadingAction (overlay)',
                child: SizedBox(
                  height: 80,
                  child: Stack(
                    children: [
                      Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: Text('Content behind overlay')),
                      ),
                      const AppLoadingAction(isLoading: true),
                    ],
                  ),
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
                            type: AppButtonType.secondary,
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
