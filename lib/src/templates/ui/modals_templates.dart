/// Helper template
class ModalsTemplates {
  ModalsTemplates._();

  /// Template for app Modal
  static String appBottomModals() => '''
import 'package:flutter/material.dart';
import '../../../config/router/app_router.dart';
import '../../../core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final modalProvider = Provider<IAppBottomModals>((ref) {
  return AppBottomModals();
});

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
