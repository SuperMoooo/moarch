/// Helper template
class HelperTemplates {
  HelperTemplates._();

  /// Template for app Dialog
  static String appDialog() => '''
import 'package:flutter/material.dart';
import '../../config/router/app_router.dart';

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
''';

  /// Template for app Modal
  static String appBottomModal() => '''
import 'package:flutter/material.dart';
import '../../config/router/app_router.dart';
import '../constants/app_constants.dart';

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
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppConstants.radius16),
          topRight: Radius.circular(AppConstants.radius16),
        ),
        child: child,
      );
    },
  );
}

''';
}
