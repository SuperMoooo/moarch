import '../ui/update_policy_templates.dart';

/// Generates the update gate for the flutter_bloc stack.
///
/// The mirror of `templates/riverpod/update_gate_templates.dart`: the same
/// `UpdatePolicy` and `UpdateRequiredView`, the same fail-open rule, the same
/// `MaterialApp.builder` mounting. The two providers become an
/// `UpdateGateCubit` the gate creates and owns, so nothing has to be
/// registered for it to work.
class UpdateGateTemplates {
  UpdateGateTemplates._();

  /// Returns the `shared/widgets/update_gate.dart` source.
  ///
  /// The cubit is generated against whichever backend the project has:
  /// [withFirestore] watches a document live, [withDio] fetches a config
  /// endpoint at launch and on every return to the foreground. With neither,
  /// it reports no minimum — the gate is identical in all three.
  static String updateGate({bool withFirestore = false, bool withDio = false}) {
    final imports = [
      if (withFirestore || withDio) "import 'dart:async';\n",
      if (withFirestore)
        "import 'package:cloud_firestore/cloud_firestore.dart';",
      if (withDio && !withFirestore) "import 'package:dio/dio.dart';",
      // defaultTargetPlatform, which picks the policy's platform object.
      "import 'package:flutter/foundation.dart';",
      "import 'package:flutter/material.dart';",
      "import 'package:flutter_bloc/flutter_bloc.dart';",
      "import 'package:package_info_plus/package_info_plus.dart';",
      "import 'package:url_launcher/url_launcher.dart';",
      '',
      if (withFirestore || withDio) "import '../../config/di/injector.dart';",
      "import '../../core/constants/app_constants.dart';",
    ].join('\n');

    final cubit = withFirestore
        ? _firestoreCubit
        : withDio
        ? _dioCubit
        : _stubCubit;

    return '$imports\n${UpdatePolicyTemplates.policy}\n'
        '$_installedVersion\n$cubit\n$_gate'
        '${UpdatePolicyTemplates.view}';
  }

  static const _installedVersion = r'''
/// The version the device is running (`version` in pubspec.yaml, as built),
/// or null when the platform cannot say — which lets the app through.
Future<String?> _installedVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return null;
  }
}
''';

  static const _firestoreCubit = r'''
/// Watches the one `config/app_version` document, and emits the policy only
/// while the installed version is below its minimum — null means the app may
/// run.
///
/// Live, so raising the floor reaches apps that are already open. The rule
/// for it has to allow **unauthenticated** reads, like the maintenance flag's:
///
/// ```
/// match /config/app_version {
///   allow read: if true;
///   allow write: if false;   // console or admin SDK only
/// }
/// ```
///
/// A Cubit, not a Bloc: it holds one value and has no events. It lives beside
/// the gate that owns it rather than in an `update_gate_cubit.dart` of its
/// own — which is the naming rule waived below.
// ignore: prefer_file_naming_conventions
class UpdateGateCubit extends Cubit<UpdatePolicy?> {
  UpdateGateCubit(this._firestore) : super(null) {
    _start();
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  Future<void> _start() async {
    final installed = await _installedVersion();
    if (installed == null || isClosed) return;
    _subscription = _firestore
        .collection('config')
        .doc('app_version')
        .snapshots()
        .listen(
      (snapshot) {
        final data = snapshot.data();
        _apply(
          installed,
          data == null ? const UpdatePolicy.none() : UpdatePolicy.fromMap(data),
        );
      },
      // Rules denied, offline, no such collection — every one of them leaves
      // the app running. See [UpdateGate] on why this fails open.
      onError: (Object _) => _apply(installed, const UpdatePolicy.none()),
    );
  }

  void _apply(String installed, UpdatePolicy policy) {
    if (isClosed) return;
    emit(policy.requiresUpdate(installed) ? policy : null);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

UpdateGateCubit _createUpdateGateCubit() =>
    UpdateGateCubit(getIt<FirebaseFirestore>());
''';

  static const _dioCubit = r'''
/// Fetches the version policy at launch and whenever the app comes back to
/// the foreground, and emits it only while the installed version is below its
/// minimum — null means the app may run.
///
/// No timer: a minimum version changes with a release, not by the minute. The
/// endpoint must be reachable **without a token** — add it to
/// `_kPublicEndpoints` in `dio_client.dart`.
///
/// A Cubit, not a Bloc: it holds one value and has no events. It lives beside
/// the gate that owns it rather than in an `update_gate_cubit.dart` of its
/// own — which is the naming rule waived below.
// ignore: prefer_file_naming_conventions
class UpdateGateCubit extends Cubit<UpdatePolicy?> {
  UpdateGateCubit(this._dio) : super(null) {
    _lifecycle = AppLifecycleListener(onResume: check);
    check();
  }

  final Dio _dio;
  late final AppLifecycleListener _lifecycle;
  String? _installed;

  /// Never throws. A policy that cannot be read is "no minimum" — see
  /// [UpdateGate] on why this fails open.
  Future<void> check() async {
    final installed = _installed ??= await _installedVersion();
    if (installed == null || isClosed) return;

    UpdatePolicy policy;
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/config/app-version');
      final data = response.data;
      policy =
          data == null ? const UpdatePolicy.none() : UpdatePolicy.fromMap(data);
    } catch (_) {
      policy = const UpdatePolicy.none();
    }

    if (!isClosed) emit(policy.requiresUpdate(installed) ? policy : null);
  }

  @override
  Future<void> close() {
    _lifecycle.dispose();
    return super.close();
  }
}

UpdateGateCubit _createUpdateGateCubit() => UpdateGateCubit(getIt<Dio>());
''';

  static const _stubCubit = r'''
/// Where the policy comes from. Point this at whatever your backend already
/// has — a config endpoint, a document, Remote Config — and emit
/// `policy.requiresUpdate(installed) ? policy : null` with the installed
/// version from `_installedVersion()`. The gate needs no changes.
///
/// Re-read at least on `AppLifecycleListener(onResume:)`, so a floor raised
/// while the app is open still closes the gate, and make the source readable
/// **without a token**.
///
/// A Cubit, not a Bloc: it holds one value and has no events. It lives beside
/// the gate that owns it rather than in an `update_gate_cubit.dart` of its
/// own — which is the naming rule waived below.
// ignore: prefer_file_naming_conventions
class UpdateGateCubit extends Cubit<UpdatePolicy?> {
  UpdateGateCubit() : super(null);

  /// Re-reads the policy.
  Future<void> check() async {
    // TODO: fetch the policy, compare it with `await _installedVersion()`,
    // and emit the result.
  }
}

UpdateGateCubit _createUpdateGateCubit() => UpdateGateCubit();
''';

  static const _gate = r'''
/// Replaces the whole app while the installed version is below the backend's
/// minimum.
///
/// Mount it in `MaterialApp.builder`, beside the maintenance gate if the
/// project has one — `builder` wraps the Navigator, so nothing the router can
/// push lands on top of it:
///
/// ```dart
/// MaterialApp.router(
///   builder: (context, child) => UpdateGate(child: child!),
///   routerConfig: appRouter,
/// )
/// ```
///
/// It creates its own [UpdateGateCubit] and closes it with itself.
///
/// **It fails open.** The cubit starts at null — "may run" — and only leaves
/// it on a policy it read and a version it parsed. Offline, endpoint down, a
/// malformed version: the app runs normally. A fault in the check must not
/// lock out every user at once.
class UpdateGate extends StatelessWidget {
  /// Wraps [child], which is the app.
  const UpdateGate({required this.child, super.key});

  /// The app being gated.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _createUpdateGateCubit(),
      child: BlocBuilder<UpdateGateCubit, UpdatePolicy?>(
        builder: (context, policy) =>
            policy == null ? child : UpdateRequiredView(policy: policy),
      ),
    );
  }
}
''';
}
