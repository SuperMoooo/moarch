/// Generates the offline gate for the Riverpod stack.
///
/// The mirror of `templates/bloc/offline_templates.dart`: the same screen,
/// the same "cover, never replace" rule, read from `hasInternetProvider`
/// instead of a `ConnectivityCubit`.
class OfflineTemplates {
  OfflineTemplates._();

  /// Returns the `shared/widgets/offline_gate.dart` source.
  static String offlineGate() => r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';
import 'error_view.dart';

/// Covers the app with [OfflineView] while the device has no connection, and
/// lifts it the moment the connection is back.
///
/// Mounted in `MaterialApp.builder`, around the Navigator, so it covers every
/// route. It covers rather than replaces: the app underneath stays mounted,
/// so the screen the user was on — a half-filled form — is still there when
/// the connection returns. What runs on that return is
/// `ConnectivityService.onReconnect`, in `main.dart`.
///
/// It fails open: until the first reading arrives, and if reading fails, the
/// app shows. For an app whose screens work offline, take the gate out of
/// `main.dart` and watch `hasInternetProvider` where it matters instead — an
/// `AppBanner` saying so, a disabled send button.
class OfflineGate extends ConsumerWidget {
  /// Wraps [child], which is the app.
  const OfflineGate({required this.child, super.key});

  /// The app being covered.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(hasInternetProvider).value ?? true;
    return Stack(
      children: [
        // First and always there, so it keeps its state underneath.
        child,
        if (!online) const Positioned.fill(child: OfflineView()),
      ],
    );
  }
}

/// The screen shown over the app while offline.
///
/// Public so a route can reuse it. It is [ErrorView] in a [Scaffold] —
/// restyle it here rather than teaching the gate about layout.
class OfflineView extends ConsumerWidget {
  const OfflineView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ErrorView(
          icon: Icons.wifi_off_rounded,
          title: "You're offline",
          message:
              'Check your connection. The app picks up where you left off '
              'as soon as it is back.',
          // Reads the connection again, for a change the platform was slow
          // to report.
          onRetry: () => ref.invalidate(hasInternetProvider),
        ),
      ),
    );
  }
}
''';
}
