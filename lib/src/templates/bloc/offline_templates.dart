/// Generates the offline gate for the flutter_bloc stack.
///
/// The mirror of `templates/riverpod/offline_templates.dart`: the same
/// screen, the same "cover, never replace" rule. The gate provides the
/// `ConnectivityCubit` it reads, above the navigator, so every screen can
/// read it too.
class OfflineTemplates {
  OfflineTemplates._();

  /// Returns the `shared/widgets/offline_gate.dart` source.
  static String offlineGate() => r'''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/di/injector.dart';
import '../../core/services/connectivity_service.dart';
import 'error_view.dart';

/// Covers the app with [OfflineView] while the device has no connection, and
/// lifts it the moment the connection is back.
///
/// Mounted in `MaterialApp.builder`, around the Navigator, so it covers every
/// route — and provides the [ConnectivityCubit] it reads, so any screen can
/// `context.watch<ConnectivityCubit>()` as well. It covers rather than
/// replaces: the app underneath stays mounted, so the screen the user was
/// on — a half-filled form — is still there when the connection returns.
/// What runs on that return is `ConnectivityService.onReconnect`, in
/// `main.dart`.
///
/// It fails open: the cubit starts online, and only a reading says
/// otherwise. For an app whose screens work offline, drop the offline screen
/// below and keep the provider, so screens can show an `AppBanner` or
/// disable a send button instead.
class OfflineGate extends StatelessWidget {
  /// Wraps [child], which is the app.
  const OfflineGate({required this.child, super.key});

  /// The app being covered.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConnectivityCubit(getIt<ConnectivityService>()),
      child: BlocBuilder<ConnectivityCubit, bool>(
        builder: (context, online) => Stack(
          children: [
            // First and always there, so it keeps its state underneath.
            child,
            if (!online) const Positioned.fill(child: OfflineView()),
          ],
        ),
      ),
    );
  }
}

/// The screen shown over the app while offline.
///
/// Public so a route can reuse it. It is [ErrorView] in a [Scaffold] —
/// restyle it here rather than teaching the gate about layout.
class OfflineView extends StatelessWidget {
  const OfflineView({super.key});

  @override
  Widget build(BuildContext context) {
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
          onRetry: () => context.read<ConnectivityCubit>().recheck(),
        ),
      ),
    );
  }
}
''';
}
