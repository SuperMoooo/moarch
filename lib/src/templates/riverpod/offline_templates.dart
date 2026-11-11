import '../core/sync_templates.dart';

/// Generates the offline gate for the Riverpod stack.
///
/// The mirror of `templates/bloc/offline_templates.dart`: the same screen,
/// the same "cover, never replace" rule, read from `hasInternetProvider`
/// instead of a `ConnectivityCubit`.
class OfflineTemplates {
  OfflineTemplates._();

  /// Returns the `shared/widgets/offline_gate.dart` source.
  static String offlineGate() => r'''
import 'package:material_ui/material_ui.dart';
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

  /// Returns the `shared/widgets/sync_status.dart` source: the toast for
  /// refused writes (the same in both stacks) and the pending-count banner,
  /// which reads `pendingSyncCountProvider`.
  static String syncStatus() =>
      '''
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/di/injector.dart';
import '../../core/sync/sync_service.dart';
import 'feedback/app_banner.dart';
import 'overlays/app_toast.dart';

${SyncTemplates.syncStatusListener}
$_syncBanner''';

  static const String _syncBanner = r'''
/// How many changes have not reached the server yet, with a button to send
/// them now. Takes no space while there are none. Put it where the user should
/// know: above a list, under an app bar.
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSyncCountProvider).value ?? 0;
    if (pending == 0) return const SizedBox.shrink();
    return AppBanner(
      icon: Icons.cloud_upload_outlined,
      message: pending == 1
          ? '1 change waiting to sync'
          : '$pending changes waiting to sync',
      actionLabel: 'Sync now',
      onAction: () => unawaited(getIt<SyncService>().drain()),
    );
  }
}
''';
}
