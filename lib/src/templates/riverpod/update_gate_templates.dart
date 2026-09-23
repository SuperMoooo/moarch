import '../ui/update_policy_templates.dart';

/// Generates the update gate — the backend's minimum version, below which the
/// app is replaced by a screen pointing at the store.
class UpdateGateTemplates {
  UpdateGateTemplates._();

  /// Returns the `shared/widgets/update_gate.dart` source.
  ///
  /// The policy provider is generated against whichever backend the project
  /// has: [withFirestore] watches a document live, [withDio] fetches a config
  /// endpoint at launch and on every return to the foreground. With neither,
  /// the provider is a stub that reports no minimum — the gate is identical in
  /// all three, so swapping the source later touches one provider.
  static String updateGate({bool withFirestore = false, bool withDio = false}) {
    // `dart:async` only for the polled variant: its StreamController is the
    // one async type the Firestore and stub providers do not need.
    final imports = [
      if (withDio && !withFirestore) "import 'dart:async';\n",
      if (withFirestore)
        "import 'package:cloud_firestore/cloud_firestore.dart';",
      if (withDio && !withFirestore) "import 'package:dio/dio.dart';",
      // defaultTargetPlatform, which picks the policy's platform object.
      "import 'package:flutter/foundation.dart';",
      "import 'package:flutter/material.dart';",
      "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      "import 'package:package_info_plus/package_info_plus.dart';",
      "import 'package:url_launcher/url_launcher.dart';",
      '',
      if (withFirestore || withDio) "import '../../config/di/injector.dart';",
      "import '../../core/constants/app_constants.dart';",
    ].join('\n');

    final provider = withFirestore
        ? _firestoreProvider
        : withDio
        ? _dioProvider
        : _stubProvider;

    return '$imports\n${UpdatePolicyTemplates.policy}\n'
        '$_installedProvider\n$provider\n$_gate'
        '${UpdatePolicyTemplates.view}';
  }

  static const _installedProvider = r'''
/// The version the device is running, from the platform's own record of it
/// (`version` in pubspec.yaml, as built).
final installedVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
''';

  static const _firestoreProvider = r'''
/// Watches the one `config/app_version` document.
///
/// Live, so raising the floor reaches apps that are already open — within a
/// second, for one document read per change per device.
///
/// The rule for it has to allow **unauthenticated** reads, like the
/// maintenance flag's: a user who is signed out still has to be told to
/// update.
///
/// ```
/// match /config/app_version {
///   allow read: if true;
///   allow write: if false;   // console or admin SDK only
/// }
/// ```
final updatePolicyProvider = StreamProvider<UpdatePolicy>((ref) {
  return getIt<FirebaseFirestore>()
      .collection('config')
      .doc('app_version')
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        if (data == null) return const UpdatePolicy.none();
        return UpdatePolicy.fromMap(data);
      });
});
''';

  static const _dioProvider = r'''
/// Fetches the version policy at launch and whenever the app comes back to
/// the foreground — no timer: a minimum version changes with a release, not
/// by the minute, and someone returning to the app is who meets it.
///
/// The endpoint must be reachable **without a token**: a signed-out user
/// still has to be told to update. Add it to `_kPublicEndpoints` in
/// `dio_client.dart`.
final updatePolicyProvider = StreamProvider<UpdatePolicy>((ref) {
  final dio = getIt<Dio>();
  final controller = StreamController<UpdatePolicy>();

  Future<void> check() async {
    final policy = await _fetchPolicy(dio);
    if (!controller.isClosed) controller.add(policy);
  }

  final lifecycle = AppLifecycleListener(onResume: check);

  ref.onDispose(() {
    lifecycle.dispose();
    controller.close();
  });

  check();
  return controller.stream;
});

/// Never throws. A policy that cannot be read is "no minimum" — see
/// [UpdateGate] on why this fails open.
Future<UpdatePolicy> _fetchPolicy(Dio dio) async {
  try {
    final response = await dio.get<Map<String, dynamic>>('/config/app-version');
    final data = response.data;
    if (data == null) return const UpdatePolicy.none();
    return UpdatePolicy.fromMap(data);
  } catch (_) {
    return const UpdatePolicy.none();
  }
}
''';

  static const _stubProvider = r'''
/// Where the policy comes from. Point this at whatever your backend already
/// has — a config endpoint, a document, Remote Config — and the rest of the
/// file needs no changes.
///
/// A `Stream` so a floor raised while the app is open still closes the gate:
/// re-read at least on `AppLifecycleListener(onResume:)`. Make the source
/// readable **without a token** — a signed-out user still has to be told.
final updatePolicyProvider = StreamProvider<UpdatePolicy>((ref) {
  return Stream.value(const UpdatePolicy.none());
});
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
///   routerConfig: router,
/// )
/// ```
///
/// **It fails open.** Until both the installed version and the policy are
/// known, and whenever either cannot be read — offline, endpoint down, a
/// version string that does not parse — the app runs normally. A fault in the
/// check must not lock out every user at once; the cost is that an
/// unreachable backend lets an old version through until it can be read.
class UpdateGate extends ConsumerWidget {
  /// Wraps [child], which is the app.
  const UpdateGate({required this.child, super.key});

  /// The app being gated.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` rather than `when`: loading and error both read as null, and
    // null lets the app through. Those two nulls are the fail-open rule.
    final installed = ref.watch(installedVersionProvider).value;
    final policy = ref.watch(updatePolicyProvider).value;

    if (installed == null ||
        policy == null ||
        !policy.requiresUpdate(installed)) {
      return child;
    }

    return UpdateRequiredView(policy: policy);
  }
}
''';
}
