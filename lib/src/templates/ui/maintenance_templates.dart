/// Generates the maintenance gate — the backend flag that empties the app.
class MaintenanceTemplates {
  MaintenanceTemplates._();

  /// Returns the `shared/widgets/maintenance_gate.dart` source.
  ///
  /// The status provider is generated against whichever backend the project
  /// has: [withFirestore] watches a document live, [withDio] polls a config
  /// endpoint. With neither, the provider is a stub that always reports "up"
  /// and carries a note on where to point it — the gate itself is identical
  /// in all three, so swapping the source later touches one provider.
  static String maintenanceGate({
    bool withFirestore = false,
    bool withDio = false,
  }) {
    final imports = withFirestore
        ? "import 'package:flutter/material.dart';\n"
            "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
            '\n'
            "import '../../config/firebase/firebase_providers.dart';\n"
            "import 'error_view.dart';\n"
        : withDio
            ? "import 'dart:async';\n"
                '\n'
                "import 'package:dio/dio.dart';\n"
                "import 'package:flutter/material.dart';\n"
                "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
                '\n'
                "import '../../core/network/dio_client.dart';\n"
                "import 'error_view.dart';\n"
            : "import 'package:flutter/material.dart';\n"
                "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
                '\n'
                "import 'error_view.dart';\n";

    final provider = withFirestore
        ? _firestoreProvider
        : withDio
            ? _dioProvider
            : _stubProvider;

    return '$imports$_status\n$provider\n$_gate';
  }

  static const _status = r'''

/// What the backend says about availability.
///
/// The wording lives on the backend on purpose: whoever turns the app off can
/// say why, and change their mind, without waiting for a release. The copy in
/// [MaintenanceView] is only what shows when they send none.
///
/// ```json
/// { "active": true, "title": "Back at 14:00", "message": "Upgrading the database." }
/// ```
@immutable
class MaintenanceStatus {
  const MaintenanceStatus({required this.isActive, this.title, this.message});

  /// The app is available. Also what an unreadable flag resolves to — see
  /// [MaintenanceGate] on why this fails open.
  const MaintenanceStatus.up()
      : isActive = false,
        title = null,
        message = null;

  /// Reads the flag, defaulting every field. A malformed payload must not be
  /// able to gate the app, so anything unparseable reads as `active: false`.
  factory MaintenanceStatus.fromMap(Map<String, dynamic> map) =>
      MaintenanceStatus(
        isActive: map['active'] as bool? ?? false,
        title: map['title'] as String?,
        message: map['message'] as String?,
      );

  /// Whether the app should be blocked.
  final bool isActive;

  /// Heading shown in place of the app, or null for the default.
  final String? title;

  /// Body text shown in place of the app, or null for the default.
  final String? message;
}
''';

  static const _firestoreProvider = r'''
/// Watches the one `config/maintenance` document.
///
/// A live listener, so flipping the flag empties every open app within a
/// second — no restart, no polling, one document read per change per device.
///
/// The rule for it has to allow **unauthenticated** reads:
///
/// ```
/// match /config/maintenance {
///   allow read: if true;
///   allow write: if false;   // console or admin SDK only
/// }
/// ```
///
/// A rule requiring sign-in would hide the flag from signed-out users, who are
/// exactly the ones you cannot afford to let through during an outage — and
/// the denial fails open.
final maintenanceStatusProvider = StreamProvider<MaintenanceStatus>((ref) {
  return ref
      .watch(firebaseDbProvider)
      .collection('config')
      .doc('maintenance')
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        if (data == null) return const MaintenanceStatus.up();
        return MaintenanceStatus.fromMap(data);
      });
});
''';

  static const _dioProvider = r'''
/// How often the flag is re-read while the app stays in the foreground.
const _pollInterval = Duration(minutes: 5);

/// Polls the availability endpoint, and again whenever the app returns to the
/// foreground — the moment that matters most, since someone coming back after
/// an hour away is the likeliest to meet a deploy.
///
/// The endpoint must be reachable **without a token**: a signed-out user, or
/// one whose session expired during the outage, still has to be told the app
/// is down. Add it to `_kPublicEndpoints` in `dio_client.dart`.
final maintenanceStatusProvider = StreamProvider<MaintenanceStatus>((ref) {
  final dio = ref.watch(dioClientProvider);
  final controller = StreamController<MaintenanceStatus>();

  Future<void> poll() async {
    final status = await _fetchStatus(dio);
    if (!controller.isClosed) controller.add(status);
  }

  final timer = Timer.periodic(_pollInterval, (_) => poll());
  final lifecycle = AppLifecycleListener(onResume: poll);

  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
    controller.close();
  });

  poll();
  return controller.stream;
});

/// Never throws. A status that cannot be read is reported as "up" — see
/// [MaintenanceGate] on why this fails open.
Future<MaintenanceStatus> _fetchStatus(Dio dio) async {
  try {
    final response = await dio.get<Map<String, dynamic>>('/config/maintenance');
    final data = response.data;
    if (data == null) return const MaintenanceStatus.up();
    return MaintenanceStatus.fromMap(data);
  } catch (_) {
    return const MaintenanceStatus.up();
  }
}
''';

  static const _stubProvider = r'''
/// Where the flag comes from. Point this at whatever your backend already has
/// — a config endpoint, a document, Remote Config — and the rest of the file
/// needs no changes.
///
/// It is a `Stream` rather than a `Future` on purpose: the gate is meant to
/// close on an app that is already running, not only at launch. If your source
/// can only be polled, emit on a `Timer.periodic` and on
/// `AppLifecycleListener(onResume:)`.
///
/// Whatever you put here, make it readable **without a token**: a signed-out
/// user still has to be told the app is down.
final maintenanceStatusProvider = StreamProvider<MaintenanceStatus>((ref) {
  return Stream.value(const MaintenanceStatus.up());
});
''';

  static const _gate = r'''
/// Replaces the whole app while the backend reports maintenance.
///
/// Mount it in `MaterialApp.builder`, not inside a route — `builder` wraps the
/// Navigator, so the gate sits above every screen the router can reach,
/// including anything pushed after the flag flips:
///
/// ```dart
/// MaterialApp.router(
///   builder: (context, child) => MaintenanceGate(child: child!),
///   routerConfig: router,
/// )
/// ```
///
/// **It fails open.** While the first status is in flight, and if it cannot be
/// read at all — offline, endpoint down, rules denied — the app runs normally.
/// A fault in the check must not be able to lock out every user at once. The
/// trade-off is the other direction: a backend that is completely unreachable
/// shows your usual error states rather than this screen.
class MaintenanceGate extends ConsumerWidget {
  /// Wraps [child], which is the app.
  const MaintenanceGate({required this.child, super.key});

  /// The app being gated.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` rather than `when`: loading and error both read as null, and
    // null reads as "up". That single `??` is the fail-open rule.
    final status = ref.watch(maintenanceStatusProvider).value ??
        const MaintenanceStatus.up();

    if (!status.isActive) return child;

    // Replaced, not covered. With no Navigator mounted there is nothing left
    // to tap, nothing for the back button to pop, and no route that can push
    // itself on top of the gate. In-memory state goes with it, which is the
    // point — everyone is meant to be out.
    return MaintenanceView(status: status);
  }
}

/// The screen shown in place of the app.
///
/// Public so your own route can reuse it, and so the gate stays one `if`. It
/// is [ErrorView] in a [Scaffold] — restyle it here rather than teaching the
/// gate about layout.
class MaintenanceView extends ConsumerWidget {
  /// Renders [status] full-screen.
  const MaintenanceView({required this.status, super.key});

  /// The status that closed the gate, for its title and message.
  final MaintenanceStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ErrorView(
          icon: Icons.construction_outlined,
          title: status.title ?? 'Under maintenance',
          message: status.message ??
              'The app is unavailable for a moment while we finish some work. '
              'Please try again shortly.',
          // Re-reads the flag. Harmless on a live listener, and the only way
          // out for a source that is polled.
          onRetry: () => ref.invalidate(maintenanceStatusProvider),
        ),
      ),
    );
  }
}
''';
}
