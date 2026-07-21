/// Helper template
class DialogsTemplates {
  DialogsTemplates._();

  /// Template for app Dialog
  static String appDialog() => '''
import 'package:flutter/material.dart';
import '../../../config/router/app_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final dialogProvider = Provider<IAppDialogs>((ref) {
  return AppDialogs();
});


abstract class IAppDialogs {
  Future<T?> showAppDialog<T>({
  required Widget child,
  bool dismissible = true,
  bool useRootNavigator = true,
  Duration duration = const Duration(milliseconds: 300),
  Color barrierColor = const Color(0x80000000),
});
}

class AppDialogs implements IAppDialogs{

@override
Future<T?> showAppDialog<T>({
  required Widget child,
  bool dismissible = true,
  bool useRootNavigator = true,
  Duration duration = const Duration(milliseconds: 300),
  Color barrierColor = const Color(0x80000000),
}) async{
  final context = rootNavigatorKey.currentContext;
  if (context == null) return null;

  return await showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: barrierColor,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: duration,
    useRootNavigator: useRootNavigator,
    pageBuilder: (_, __, ___) => child,
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

}
''';

  /// Template for the confirm/cancel dialog, built from [AppButton] and
  /// [AppLeadingIcon].
  static String confirmDialog() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../buttons/app_button.dart';
import '../icons/app_leading_icon.dart';
import 'app_dialogs.dart';

/// A confirm/cancel dialog built from [AppButton] and [AppLeadingIcon]. Pass
/// it to [IAppDialogs.showAppDialog], or use [AppConfirmDialog.show] to do
/// both in one call.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final String? message;
  final IconData? icon;

  /// Colors both the leading icon and the confirm button — pass
  /// [AppButtonVariant.danger] for a destructive action.
  final AppButtonVariant variant;
  final String confirmLabel;
  final String cancelLabel;

  /// Shows the dialog through [dialogs] and resolves to whether the user
  /// confirmed. Dismissing without a choice resolves to `false`.
  static Future<bool> show(
    IAppDialogs dialogs, {
    required String title,
    String? message,
    IconData? icon,
    AppButtonVariant variant = AppButtonVariant.primary,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
  }) async {
    final confirmed = await dialogs.showAppDialog<bool>(
      child: AppConfirmDialog(
        title: title,
        message: message,
        icon: icon,
        variant: variant,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return confirmed ?? false;
  }

  static AppLeadingIconVariant _leadingVariantOf(AppButtonVariant variant) =>
      switch (variant) {
        AppButtonVariant.primary => AppLeadingIconVariant.primary,
        AppButtonVariant.secondary => AppLeadingIconVariant.secondary,
        AppButtonVariant.tertiary => AppLeadingIconVariant.tertiary,
        AppButtonVariant.danger => AppLeadingIconVariant.danger,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadius16),
      child: Padding(
        padding: AppConstants.padding24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppLeadingIcon(icon: icon!, variant: _leadingVariantOf(variant)),
              const SizedBox(height: AppConstants.space16),
            ],
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppConstants.space8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppConstants.space24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    variant: variant,
                    type: AppButtonType.ghost,
                    label: cancelLabel,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppConstants.space12),
                Expanded(
                  child: AppButton(
                    variant: variant,
                    label: confirmLabel,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
''';
}
