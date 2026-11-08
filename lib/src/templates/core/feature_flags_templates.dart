import '../../utils/state_management.dart';

/// Feature flags: switches the backend flips without a release, read from
/// where the gates read theirs — a `config/flags` Firestore document, or a
/// `GET /config/flags` endpoint over Dio.
///
/// One file, `lib/core/services/feature_flags.dart`. Only the state holder
/// differs between the stacks, as with the sync's pending count: a provider
/// on Riverpod, a cubit on bloc.
abstract final class FeatureFlagsTemplates {
  /// The file. [withFirestore] watches the document; otherwise the endpoint
  /// is polled.
  static String featureFlags({
    StateManagement stateManagement = StateManagement.riverpod,
    bool withFirestore = false,
  }) {
    final isBloc = stateManagement.isBloc;
    final imports = [
      "import 'dart:async';",
      '',
      if (isBloc) "import 'package:bloc/bloc.dart';",
      if (withFirestore)
        "import 'package:cloud_firestore/cloud_firestore.dart';"
      else
        "import 'package:dio/dio.dart';",
      "import 'package:flutter/widgets.dart';",
      if (!isBloc) "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      '',
      if (!isBloc) "import '../../config/di/injector.dart';",
      if (!withFirestore) "import '../constants/api_constants.dart';",
      "import '../utils/app_logger.dart';",
    ].join('\n');
    return '''
$imports

final _log = appLogger.scoped('FeatureFlags');
$_flags
${withFirestore ? _firestoreService : _dioService}
${isBloc ? _cubit : _provider}''';
  }

  /// The registration `core_module.dart` gets: started as soon as something
  /// first reads it.
  static String registration({bool withFirestore = false}) =>
      '    ..registerLazySingleton<FeatureFlagsService>(\n'
      '        () => FeatureFlagsService(getIt<${withFirestore ? 'FirebaseFirestore' : 'Dio'}>())..start(),\n'
      '        dispose: (service) => service.dispose())';

  static const String _flags = r'''
/// The backend's switches, typed. Each flag is a getter with the value it
/// takes when the backend has not answered (yet, or at all), so an unreachable
/// backend leaves the app as it shipped.
///
/// ```json
/// { "new_checkout": true, "max_upload_mb": 20, "support_email": "help@…" }
/// ```
@immutable
class FeatureFlags {
  const FeatureFlags([this._values = const {}]);

  final Map<String, Object?> _values;

  // TODO: one getter per flag, with the value it has until the backend says:
  // bool get newCheckout => flag('new_checkout', fallback: false);
  // int get maxUploadMb => number('max_upload_mb', fallback: 10);

  /// The flag [key], or [fallback] while it is missing or not a bool.
  bool flag(String key, {required bool fallback}) {
    final value = _values[key];
    return value is bool ? value : fallback;
  }

  /// The number [key], or [fallback] while it is missing or not an int.
  int number(String key, {required int fallback}) {
    final value = _values[key];
    return value is int ? value : fallback;
  }

  /// The text [key], or [fallback] while it is missing or not a string.
  String text(String key, {required String fallback}) {
    final value = _values[key];
    return value is String ? value : fallback;
  }
}
''';

  static const String _dioService = r'''
/// Reads the flags from `GET /config/flags`: when first used, every
/// [pollInterval], and each time the app returns to the foreground.
///
/// The endpoint is read signed in or not: add `ApiConstants.configFlags` to
/// `_kPublicEndpoints` in `dio_client.dart`. A read that fails keeps the
/// flags already there.
class FeatureFlagsService {
  FeatureFlagsService(this._dio);

  final Dio _dio;

  static const pollInterval = Duration(minutes: 15);

  final _changes = StreamController<FeatureFlags>.broadcast();
  FeatureFlags _current = const FeatureFlags();
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  /// The flags as last read.
  FeatureFlags get current => _current;

  /// [current] now, and again every time a read changes them.
  Stream<FeatureFlags> get changes async* {
    yield _current;
    yield* _changes.stream;
  }

  /// Reads now, then on the timer and on resume. Called by the locator.
  void start() {
    _timer ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(refresh()));
    unawaited(refresh());
  }

  /// Reads the flags again. Never throws.
  Future<void> refresh() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.configFlags,
      );
      final data = response.data;
      if (data == null) return;
      _current = FeatureFlags(data);
      _changes.add(_current);
    } catch (error, stackTrace) {
      _log.w('Not read, keeping the last flags', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _lifecycle?.dispose();
    await _changes.close();
  }
}
''';

  static const String _firestoreService = r'''
/// Watches the one `config/flags` document: a flag flipped in the console
/// reaches every open app within a second.
///
/// The rule for it has to allow **unauthenticated** reads, so a signed-out
/// user gets the flags too:
///
/// ```
/// match /config/flags {
///   allow read: if true;
///   allow write: if false;   // console or admin SDK only
/// }
/// ```
///
/// A document that cannot be read keeps the flags already there.
class FeatureFlagsService {
  FeatureFlagsService(this._firestore);

  final FirebaseFirestore _firestore;

  final _changes = StreamController<FeatureFlags>.broadcast();
  FeatureFlags _current = const FeatureFlags();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _document;

  /// The flags as last read.
  FeatureFlags get current => _current;

  /// [current] now, and again every time the document changes.
  Stream<FeatureFlags> get changes async* {
    yield _current;
    yield* _changes.stream;
  }

  /// Starts watching the document. Called by the locator.
  void start() {
    _document ??= _firestore
        .collection('config')
        .doc('flags')
        .snapshots()
        .listen(
          (snapshot) {
            _current = FeatureFlags(snapshot.data() ?? const {});
            _changes.add(_current);
          },
          onError: (Object error, StackTrace stackTrace) {
            _log.w('Not read, keeping the last flags', error: error, stackTrace: stackTrace);
          },
        );
  }

  Future<void> dispose() async {
    await _document?.cancel();
    await _changes.close();
  }
}
''';

  static const String _provider = r'''
/// The flags as state, for a screen to follow:
/// `final flags = ref.watch(featureFlagsProvider).value ?? const FeatureFlags();`
final featureFlagsProvider = StreamProvider<FeatureFlags>((ref) {
  return getIt<FeatureFlagsService>().changes;
});
''';

  static const String _cubit = r'''
/// The flags as bloc state. Provide it where screens read flags:
/// `BlocProvider(create: (_) => FeatureFlagsCubit(getIt<FeatureFlagsService>()))`.
// ignore: prefer_file_naming_conventions
class FeatureFlagsCubit extends Cubit<FeatureFlags> {
  FeatureFlagsCubit(FeatureFlagsService service) : super(service.current) {
    _subscription = service.changes.listen(emit);
  }

  late final StreamSubscription<FeatureFlags> _subscription;

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
''';
}
