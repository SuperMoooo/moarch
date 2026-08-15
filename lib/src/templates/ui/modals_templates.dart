/// Helper template
class ModalsTemplates {
  ModalsTemplates._();

  /// Template for app Modal
  ///
  /// The helper reaches the navigator through `rootNavigatorKey`, so it needs
  /// no context — and it holds no state, so a project either registers
  /// `AppBottomModals` in the locator or calls the class directly.
  static String appBottomModals() {
    return '''
import 'package:flutter/material.dart';
import '../../../config/router/app_router.dart';
import '../../../core/constants/app_constants.dart';

abstract class IAppBottomModals {
  Future<T?> showAppBottomModal<T>({
  required Widget child,
  bool enableDrag = true,
  bool isDismissible = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  double barrierOpacity = 0.5,
});
}

class AppBottomModals implements IAppBottomModals{

@override
Future<T?> showAppBottomModal<T>({
  required Widget child,
  bool enableDrag = true,
  bool isDismissible = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  double barrierOpacity = 0.5,
}) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return null;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    useSafeArea: useSafeArea,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    builder: (_) {
      // Wrap [child] in an AppBottomSheetScaffold to get a drag handle,
      // surface background and optional title for free.
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppConstants.radius24),
          topRight: Radius.circular(AppConstants.radius24),
        ),
        child: child,
      );
    },
  );
}


}

''';
  }

  /// Template for the platform-shaped action sheet.
  static String appActionSheet() => r'''
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import 'app_bottom_sheet_scaffold.dart';

/// Which shape [AppActionSheet] takes.
///
/// [adaptive] follows the platform the way the date and time fields do:
/// Material on Android, the iOS grouped cards everywhere else.
enum AppActionSheetStyle { adaptive, material, cupertino }

/// One row in an [AppActionSheet].
///
/// [value] is what `AppActionSheet.show` resolves to. [onTap] is the other way
/// round — a callback run once the sheet has closed. Use one or the other:
/// a row needs no value if its callback already does the work.
class AppSheetAction<T> {
  const AppSheetAction({
    required this.label,
    this.value,
    this.icon,
    this.color,
    this.enabled = true,
    this.onTap,
  }) : isDestructive = false;

  /// An action that cannot be taken back — delete, sign out, discard.
  ///
  /// Drawn in the theme's error color on both platforms, which is the one
  /// piece of emphasis an action sheet carries. It does not confirm on your
  /// behalf: pair it with `AppConfirmDialog` when the answer should be
  /// deliberate.
  const AppSheetAction.destructive({
    required this.label,
    this.value,
    this.icon,
    this.enabled = true,
    this.onTap,
  })  : isDestructive = true,
        color = null;

  final String label;

  /// What `AppActionSheet.show` resolves to when this row is picked.
  final T? value;

  final IconData? icon;

  /// Overrides the row color. Ignored on a destructive row, which owns its
  /// own.
  final Color? color;

  final bool enabled;

  /// Run after the sheet has closed — never while it is closing, where a
  /// handler that pushes a route or opens a dialog fights the navigator for
  /// it.
  final VoidCallback? onTap;

  final bool isDestructive;
}

/// A sheet of actions on the thing you just long-pressed or tapped a
/// three-dot button on.
///
/// ```dart
/// final picked = await AppActionSheet.show<String>(
///   context,
///   title: 'Order #1042',
///   actions: [
///     const AppSheetAction(label: 'Edit', icon: Icons.edit, value: 'edit'),
///     const AppSheetAction(label: 'Share', icon: Icons.ios_share, value: 'share'),
///     const AppSheetAction.destructive(
///       label: 'Delete',
///       icon: Icons.delete_outline,
///       value: 'delete',
///     ),
///   ],
/// );
/// ```
///
/// Dismissing resolves to null, so a `switch` on the result has one honest
/// "the user backed out" branch.
class AppActionSheet<T> extends StatelessWidget {
  const AppActionSheet({
    super.key,
    required this.actions,
    this.title,
    this.message,
    this.cancelLabel = 'Cancel',
    this.showCancel = true,
    this.style = AppActionSheetStyle.adaptive,
  });

  final List<AppSheetAction<T>> actions;
  final String? title;
  final String? message;
  final String cancelLabel;

  /// Shows the cancel card. Read by the Cupertino shape only — the Material
  /// sheet is dismissed by its drag handle or the scrim, and a cancel row
  /// under a bottom sheet is not a thing Android does.
  final bool showCancel;

  final AppActionSheetStyle style;

  static const double _disabledOpacity = 0.38;
  static const double _cupertinoRowHeight = 56;

  /// Opens the sheet and resolves to the picked row's
  /// [AppSheetAction.value] — or null if it was dismissed.
  static Future<R?> show<R>(
    BuildContext context, {
    required List<AppSheetAction<R>> actions,
    String? title,
    String? message,
    String cancelLabel = 'Cancel',
    bool showCancel = true,
    AppActionSheetStyle style = AppActionSheetStyle.adaptive,
    bool isDismissible = true,
  }) async {
    HapticFeedback.selectionClick();

    final picked = await showModalBottomSheet<AppSheetAction<R>>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: isDismissible,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AppActionSheet<R>(
        actions: actions,
        title: title,
        message: message,
        cancelLabel: cancelLabel,
        showCancel: showCancel,
        style: style,
      ),
    );

    if (picked == null) return null;
    // The sheet is gone by here, so a handler is free to push or open
    // whatever it likes.
    picked.onTap?.call();
    return picked.value;
  }

  Color _colorFor(BuildContext context, AppSheetAction<T> action) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!action.enabled) {
      return colorScheme.onSurface.withValues(alpha: _disabledOpacity);
    }
    if (action.isDestructive) return colorScheme.error;
    return action.color ?? colorScheme.onSurface;
  }

  void _pick(BuildContext context, AppSheetAction<T> action) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    final cupertino = switch (style) {
      AppActionSheetStyle.material => false,
      AppActionSheetStyle.cupertino => true,
      // Matches how AppDateInput picks its picker, so one app does not mix
      // the two conventions.
      AppActionSheetStyle.adaptive => !Platform.isAndroid,
    };
    return cupertino ? _buildCupertino(context) : _buildMaterial(context);
  }

  // ── Material ───────────────────────────────────────────────────────────────

  Widget _buildMaterial(BuildContext context) {
    final theme = Theme.of(context);
    final note = message;

    return AppBottomSheetScaffold(
      title: title,
      // The rows carry their own inset so their ripple reaches the sheet's
      // edges instead of stopping short of it.
      padding: const EdgeInsets.only(bottom: AppConstants.space8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.space24,
                0,
                AppConstants.space24,
                AppConstants.space8,
              ),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final action in actions) _materialRow(context, action),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialRow(BuildContext context, AppSheetAction<T> action) {
    final theme = Theme.of(context);
    final color = _colorFor(context, action);
    final icon = action.icon;

    return Material(
      // Its own Material, so the ink paints over the sheet's surface rather
      // than under it on the transparent one showModalBottomSheet provides.
      color: Colors.transparent,
      child: InkWell(
        onTap: action.enabled ? () => _pick(context, action) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.space24,
            vertical: AppConstants.space16,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppConstants.iconMedium, color: color),
                const SizedBox(width: AppConstants.space16),
              ],
              Expanded(
                child: Text(
                  action.label,
                  style: theme.textTheme.bodyLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cupertino ──────────────────────────────────────────────────────────────

  Widget _buildCupertino(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasHeader = title != null || message != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: _card(
                context,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasHeader) _cupertinoHeader(context),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < actions.length; i++) ...[
                              if (i > 0 || hasHeader)
                                Divider(
                                  height: 1,
                                  color: colorScheme.outlineVariant,
                                ),
                              _cupertinoRow(
                                context,
                                label: actions[i].label,
                                color: _colorFor(context, actions[i]),
                                icon: actions[i].icon,
                                onTap: actions[i].enabled
                                    ? () => _pick(context, actions[i])
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showCancel) ...[
              const SizedBox(height: AppConstants.space8),
              _card(
                context,
                child: _cupertinoRow(
                  context,
                  label: cancelLabel,
                  color: colorScheme.onSurface,
                  bold: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius: AppConstants.borderRadius16,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: child,
      ),
    );
  }

  Widget _cupertinoHeader(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title;
    final note = message;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.space16),
      child: Column(
        children: [
          if (heading != null)
            Text(
              heading,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (heading != null && note != null)
            const SizedBox(height: AppConstants.space4),
          if (note != null)
            Text(
              note,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _cupertinoRow(
    BuildContext context, {
    required String label,
    required Color color,
    IconData? icon,
    bool bold = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _cupertinoRowHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.space16,
            vertical: AppConstants.space12,
          ),
          child: Row(
            children: [
              // Balances the trailing icon so the label stays centered, which
              // is the whole look of an iOS action sheet.
              if (icon != null) const SizedBox(width: AppConstants.iconMedium),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (icon != null)
                Icon(icon, size: AppConstants.iconMedium, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
''';
}
