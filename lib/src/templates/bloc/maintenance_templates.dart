/// Generates the maintenance gate — the backend flag that empties the app —
/// for the flutter_bloc stack.
///
/// The mirror of `templates/riverpod/maintenance_templates.dart`: the same
/// `MaintenanceStatus`, the same fail-open rule, the same
/// `MaterialApp.builder` mounting. Riverpod's `StreamProvider` becomes a
/// `MaintenanceCubit` the gate creates and owns, so the gate needs nothing
/// registered anywhere to work.
class MaintenanceTemplates {
  MaintenanceTemplates._();

  /// Returns the `shared/widgets/maintenance_gate.dart` source.
  ///
  /// The cubit's source is generated against whichever backend the project
  /// has: [withFirestore] watches a document live, [withDio] polls a config
  /// endpoint. With neither, it always reports "up" and carries a note on
  /// where to point it — the gate itself is identical in all three, so
  /// swapping the source later touches one class.
  static String maintenanceGate({
    bool withFirestore = false,
    bool withDio = false,
  }) {
    final imports = withFirestore
        ? "import 'dart:async';\n"
            '\n'
            "import 'package:cloud_firestore/cloud_firestore.dart';\n"
            "import 'package:flutter/material.dart';\n"
            "import 'package:flutter_bloc/flutter_bloc.dart';\n"
            '\n'
            "import '../../config/di/injector.dart';\n"
            "import 'error_view.dart';\n"
        : withDio
            ? "import 'dart:async';\n"
                '\n'
                "import 'package:dio/dio.dart';\n"
                "import 'package:flutter/material.dart';\n"
                "import 'package:flutter_bloc/flutter_bloc.dart';\n"
                '\n'
                "import '../../config/di/injector.dart';\n"
                "import 'error_view.dart';\n"
            : "import 'package:flutter/material.dart';\n"
                "import 'package:flutter_bloc/flutter_bloc.dart';\n"
                '\n'
                "import 'error_view.dart';\n";

    final cubit = withFirestore
        ? _firestoreCubit
        : withDio
            ? _dioCubit
            : _stubCubit;

    return '$imports$_status\n$cubit\n$_gate';
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
  ///
  /// Blank copy is read as absent rather than as text: a document seeded with
  /// `"title": ""` is the normal starting state, and it has to fall back to
  /// [MaintenanceView]'s defaults instead of rendering an empty heading.
  factory MaintenanceStatus.fromMap(Map<String, dynamic> map) =>
      MaintenanceStatus(
        isActive: map['active'] as bool? ?? false,
        title: _text(map['title']),
        message: _text(map['message']),
      );

  /// The value as copy, or null if it is missing, not a string, or blank.
  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Whether the app should be blocked.
  final bool isActive;

  /// Heading shown in place of the app, or null for the default.
  final String? title;

  /// Body text shown in place of the app, or null for the default.
  final String? message;
}
''';

  static const _firestoreCubit = r'''
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
///
/// A Cubit, not a Bloc: it holds one flag and has no events. It lives beside
/// the gate that owns it rather than in a `maintenance_cubit.dart` of its
/// own — which is the naming rule waived below.
// ignore: prefer_file_naming_conventions
class MaintenanceCubit extends Cubit<MaintenanceStatus> {
  MaintenanceCubit(this._firestore) : super(const MaintenanceStatus.up()) {
    _subscription = _firestore
        .collection('config')
        .doc('maintenance')
        .snapshots()
        .listen(
      (snapshot) {
        final data = snapshot.data();
        emit(
          data == null
              ? const MaintenanceStatus.up()
              : MaintenanceStatus.fromMap(data),
        );
      },
      // Rules denied, offline, no such collection — every one of them leaves
      // the app running. See [MaintenanceGate] on why this fails open.
      onError: (Object _) => emit(const MaintenanceStatus.up()),
    );
  }

  final FirebaseFirestore _firestore;
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
      _subscription;

  /// Re-reads the flag. A no-op on a live listener — it is already current —
  /// and here so the retry button has something to call in every variant.
  Future<void> refresh() async {}

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}

MaintenanceCubit _createMaintenanceCubit() =>
    MaintenanceCubit(getIt<FirebaseFirestore>());
''';

  static const _dioCubit = r'''
/// How often the flag is re-read while the app stays in the foreground.
const _pollInterval = Duration(minutes: 5);

/// Polls the availability endpoint, and again whenever the app returns to the
/// foreground — the moment that matters most, since someone coming back after
/// an hour away is the likeliest to meet a deploy.
///
/// The endpoint must be reachable **without a token**: a signed-out user, or
/// one whose session expired during the outage, still has to be told the app
/// is down. Add it to `_kPublicEndpoints` in `dio_client.dart`.
///
/// A Cubit, not a Bloc: it holds one flag and has no events. It lives beside
/// the gate that owns it rather than in a `maintenance_cubit.dart` of its
/// own — which is the naming rule waived below.
// ignore: prefer_file_naming_conventions
class MaintenanceCubit extends Cubit<MaintenanceStatus> {
  MaintenanceCubit(this._dio) : super(const MaintenanceStatus.up()) {
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
    _lifecycle = AppLifecycleListener(onResume: refresh);
    refresh();
  }

  final Dio _dio;
  late final Timer _timer;
  late final AppLifecycleListener _lifecycle;

  /// Never throws. A status that cannot be read is reported as "up" — see
  /// [MaintenanceGate] on why this fails open.
  Future<void> refresh() async {
    if (isClosed) return;
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/config/maintenance');
      final data = response.data;
      if (isClosed) return;
      emit(
        data == null
            ? const MaintenanceStatus.up()
            : MaintenanceStatus.fromMap(data),
      );
    } catch (_) {
      if (!isClosed) emit(const MaintenanceStatus.up());
    }
  }

  @override
  Future<void> close() {
    _timer.cancel();
    _lifecycle.dispose();
    return super.close();
  }
}

MaintenanceCubit _createMaintenanceCubit() => MaintenanceCubit(getIt<Dio>());
''';

  static const _stubCubit = r'''
/// Where the flag comes from. Point this at whatever your backend already has
/// — a config endpoint, a document, Remote Config — and the rest of the file
/// needs no changes.
///
/// Emit on more than launch: the gate is meant to close on an app that is
/// already running. Subscribe to a stream in the constructor, or poll on a
/// `Timer.periodic` and on `AppLifecycleListener(onResume:)` — and cancel
/// whichever you use in `close()`.
///
/// Whatever you put here, make it readable **without a token**: a signed-out
/// user still has to be told the app is down.
///
/// A Cubit, not a Bloc: it holds one flag and has no events. It lives beside
/// the gate that owns it rather than in a `maintenance_cubit.dart` of its
/// own — which is the naming rule waived below.
// ignore: prefer_file_naming_conventions
class MaintenanceCubit extends Cubit<MaintenanceStatus> {
  MaintenanceCubit() : super(const MaintenanceStatus.up());

  /// What the gate's retry button calls.
  Future<void> refresh() async {
    // TODO: re-read the flag and emit the result.
  }
}

MaintenanceCubit _createMaintenanceCubit() => MaintenanceCubit();
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
///   routerConfig: appRouter,
/// )
/// ```
///
/// It creates its own [MaintenanceCubit] and closes it with itself, so
/// nothing has to be registered for the gate to work.
///
/// **It fails open.** While the first status is in flight, and if it cannot be
/// read at all — offline, endpoint down, rules denied — the app runs normally.
/// A fault in the check must not be able to lock out every user at once. The
/// trade-off is the other direction: a backend that is completely unreachable
/// shows your usual error states rather than this screen.
class MaintenanceGate extends StatelessWidget {
  /// Wraps [child], which is the app.
  const MaintenanceGate({required this.child, super.key});

  /// The app being gated.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _createMaintenanceCubit(),
      child: BlocBuilder<MaintenanceCubit, MaintenanceStatus>(
        builder: (context, status) {
          // The cubit starts at `up` and only ever leaves it on a flag it
          // actually read. That default is the fail-open rule.
          if (!status.isActive) return child;

          // Replaced, not covered. With no Navigator mounted there is nothing
          // left to tap, nothing for the back button to pop, and no route
          // that can push itself on top of the gate. In-memory state goes
          // with it, which is the point — everyone is meant to be out.
          return MaintenanceView(status: status);
        },
      ),
    );
  }
}

/// The screen shown in place of the app.
///
/// Public so your own route can reuse it, and so the gate stays one `if`. It
/// is [ErrorView] in a [Scaffold] — restyle it here rather than teaching the
/// gate about layout.
class MaintenanceView extends StatelessWidget {
  /// Renders [status] full-screen.
  const MaintenanceView({required this.status, super.key});

  /// The status that closed the gate, for its title and message.
  final MaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
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
          onRetry: () => context.read<MaintenanceCubit>().refresh(),
        ),
      ),
    );
  }
}
''';
}
