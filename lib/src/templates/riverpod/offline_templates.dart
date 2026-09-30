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

/// Covers the app with [OfflineView] while there is no connection. The app
/// stays mounted underneath, so nothing is lost.
///
/// For screens that work offline, remove the gate from `main.dart` and watch
/// `hasInternetProvider` instead.
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

/// The screen shown over the app while offline. Restyle it here.
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
