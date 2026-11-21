import '../templates/core/product_templates.dart';
import 'platform_requirements.dart';

/// What a [ServiceOption]'s template and registration vary with, read off
/// the checklist in `init` and off disk everywhere else.
class ServiceVariant {
  /// Creates a variant.
  const ServiceVariant({
    this.withDio = false,
    this.withFirestore = false,
    this.withFirebaseAuth = false,
    this.withBiometric = false,
  });

  /// The project has the Dio client.
  final bool withDio;

  /// The project has Cloud Firestore.
  final bool withFirestore;

  /// The project has Firebase Auth.
  final bool withFirebaseAuth;

  /// The project has `BiometricService`.
  final bool withBiometric;

  /// Moderation goes to Firestore when it can name the signed-in user there,
  /// and to the REST API otherwise.
  bool get moderationOverFirestore => withFirestore && withFirebaseAuth;
}

/// Which `init` checklist a [ServiceOption] is listed in.
enum ServiceList {
  /// "Security".
  security,

  /// "Product features".
  features,
}

/// One optional service under `lib/core/`: a checklist entry in `init`, the
/// file it writes, its packages, its locator registration, what it needs
/// declared on each platform, and its row in `docs/SERVICES.md`.
///
/// Every command reads [ServiceOptions.all], so a new service is one entry
/// there and one template — `init` writes it, `update` refreshes it,
/// `doctor` checks its platform declarations.
class ServiceOption {
  /// Creates an option.
  const ServiceOption({
    required this.name,
    required this.title,
    required this.label,
    required this.description,
    required this.path,
    required this.template,
    this.registration,
    required this.docs,
    required this.list,
    this.packages = const [],
    this.packageImports = _none,
    this.requirement,
    this.endpoints = _noEndpoints,
    this.disposes = false,
  });

  static List<String> _none(ServiceVariant _) => const [];
  static Map<String, String> _noEndpoints(ServiceVariant _) => const {};

  /// The catalog name (`moarch update <name>`).
  final String name;

  /// The class the file declares.
  final String title;

  /// The checklist label. The manifest records it, so it stays stable.
  final String label;

  /// The checklist's one-line description.
  final String description;

  /// Where the file goes, from the project root.
  final String path;

  /// The file's source.
  final String Function(ServiceVariant variant) template;

  /// The get_it factory, as source: what goes inside
  /// `registerLazySingleton<Title>(…)`.
  final String Function(ServiceVariant variant)? registration;

  /// Whether the registration disposes the service (`dispose()`).
  final bool disposes;

  /// Package imports the registration needs (a `Dio`, a Firestore handle).
  final List<String> Function(ServiceVariant variant) packageImports;

  /// The packages it adds, as `PackageVersions` names.
  final List<String> packages;

  /// What it needs in `AndroidManifest.xml` and `Info.plist`.
  final PlatformRequirement? requirement;

  /// The `ApiConstants` paths it reads, by constant name.
  final Map<String, String> Function(ServiceVariant variant) endpoints;

  /// The `docs/SERVICES.md` row: what it does and how to call it.
  final String docs;

  /// The checklist it is listed in.
  final ServiceList list;

  /// The core module's import of the file.
  String get import => "import '../../${path.substring('lib/'.length)}';";

  /// The core module's registration entry.
  String entry(ServiceVariant variant) {
    final factory = registration?.call(variant) ?? '$title.new';
    return disposes
        ? '    ..registerLazySingleton<$title>(\n'
              '        $factory,\n'
              '        dispose: (service) => service.dispose())'
        : '    ..registerLazySingleton<$title>($factory)';
  }
}

/// Every optional service, in checklist order.
abstract final class ServiceOptions {
  /// Device integrity: root/jailbreak and platform attestation.
  static const integrity = ServiceOption(
    name: 'device-integrity',
    title: 'DeviceIntegrityService',
    label: 'Device integrity (root/jailbreak + attestation)',
    description:
        'Flags rooted or jailbroken devices and emulators, and has Play '
        'Integrity / App Attest vouch for the app to your backend (needs Dio).',
    path: 'lib/core/security/device_integrity_service.dart',
    template: _integrity,
    registration: _integrityFactory,
    packageImports: _dioImport,
    packages: ['safe_device', 'app_device_integrity'],
    endpoints: _integrityEndpoints,
    list: ServiceList.security,
    docs:
        '`isCompromised()` (root, jailbreak, emulator — a signal, not a '
        'gate), and `attest()` before money or data moves: the backend gets '
        'a Play Integrity / App Attest token for a challenge it issued. Set '
        '`googleCloudProjectNumber`.',
  );

  /// Screenshot and screen-recording block.
  static const screenSecurity = ServiceOption(
    name: 'screen-security',
    title: 'ScreenSecurityService',
    label: 'Screenshot & screen-recording block',
    description:
        'Keeps sensitive screens off screenshots, recordings and the '
        'app-switcher snapshot (FLAG_SECURE on Android).',
    path: 'lib/core/security/screen_security_service.dart',
    template: _screenSecurity,
    packages: ['no_screenshot'],
    list: ServiceList.security,
    docs:
        '`protect()` / `release()`: app-wide from `main`, or per screen in '
        '`initState` / `dispose`. Captures come out black on Android; the '
        'app-switcher snapshot is blurred.',
  );

  /// Locking the session again after time away.
  static const sessionLock = ServiceOption(
    name: 'session-lock',
    title: 'SessionLockService',
    label: 'Session lock after inactivity',
    description:
        'Asks to unlock again once the app was in the background longer '
        'than a timeout (adds the app lifecycle service; biometric unlock '
        'when that is ticked).',
    path: 'lib/core/security/session_lock_service.dart',
    template: _sessionLock,
    registration: _sessionLockFactory,
    disposes: true,
    list: ServiceList.security,
    docs:
        '`lockRequired` fires when the app returns after more than `timeout` '
        '(5 min): cover the app with the lock screen, then `unlock()`.',
  );

  /// Report and block.
  static const moderation = ServiceOption(
    name: 'moderation',
    title: 'ModerationService',
    label: 'Report & block (user-generated content)',
    description:
        'Report users and content, and block users — what both stores '
        'require when users see each other\'s posts (Firestore or Dio).',
    path: 'lib/core/services/moderation_service.dart',
    template: _moderation,
    registration: _moderationFactory,
    packageImports: _moderationImports,
    endpoints: _moderationEndpoints,
    list: ServiceList.features,
    docs:
        '`reportUser` / `reportContent` with a `ReportReason`, `block` / '
        '`unblock`. Filter blocked users\' content on the backend, and act on '
        'reports promptly: the stores check.',
  );

  /// The system share sheet.
  static const share = ServiceOption(
    name: 'share-service',
    title: 'ShareService',
    label: 'Share sheet',
    description: 'Share text, links and files through the system sheet.',
    path: 'lib/core/services/share_service.dart',
    template: _share,
    packages: ['share_plus'],
    list: ServiceList.features,
    docs:
        '`share(text:, link:, origin: context)` and `shareFiles(paths)`. Pass '
        'the tapped widget\'s context as `origin`: iPad needs it.',
  );

  /// The store rating prompt.
  static const review = ServiceOption(
    name: 'review-service',
    title: 'ReviewService',
    label: 'In-app review prompt',
    description:
        'The store\'s rating prompt, inside the app, after a moment that '
        'went well.',
    path: 'lib/core/services/review_service.dart',
    template: _review,
    packages: ['in_app_review'],
    list: ServiceList.features,
    docs:
        '`requestReview()` after a success (never on launch); '
        '`openStoreListing(appStoreId:)` for a "Rate us" button.',
  );

  /// Location.
  static const location = ServiceOption(
    name: 'location-service',
    title: 'LocationService',
    label: 'Location (GPS)',
    description:
        'The device\'s position and a stream of it, asking for permission '
        'when needed.',
    path: 'lib/core/services/location_service.dart',
    template: _location,
    packages: ['geolocator'],
    requirement: PlatformRequirement.location,
    list: ServiceList.features,
    docs:
        '`current()` (null without permission), `watch(distanceFilter:)`, '
        '`distanceBetween`. Ask from a screen that says why.',
  );

  /// Barcode and QR scanning.
  static const scanner = ServiceOption(
    name: 'scanner-service',
    title: 'ScannerService',
    label: 'Barcode / QR scanner',
    description: 'A full-screen camera scanner that returns the first code.',
    path: 'lib/core/services/scanner_service.dart',
    template: _scanner,
    packages: ['mobile_scanner'],
    requirement: PlatformRequirement.scanner,
    list: ServiceList.features,
    docs:
        '`await scan(context)` opens the scanner and returns the code, or '
        'null when the user goes back.',
  );

  /// Health data.
  static const health = ServiceOption(
    name: 'health-service',
    title: 'HealthService',
    label: 'Health data (HealthKit / Health Connect)',
    description:
        'Reads steps from Apple Health and Health Connect; add types as you '
        'need them.',
    path: 'lib/core/services/health_service.dart',
    template: _health,
    packages: ['health'],
    requirement: PlatformRequirement.health,
    list: ServiceList.features,
    docs:
        '`isAvailable()`, `requestAccess()`, `stepsToday()`. A new type also '
        'needs its `android.permission.health.READ_…` permission. iOS needs '
        'the HealthKit capability (`ios/Runner/Runner.entitlements`); Health '
        'Connect\'s privacy-policy link opens `MainActivity` — route it to '
        'your policy.',
  );

  /// In-app purchases and subscriptions.
  static const purchases = ServiceOption(
    name: 'purchase-service',
    title: 'PurchaseService',
    label: 'In-app purchases & subscriptions',
    description:
        'App Store and Google Play purchases, delivered once your backend '
        'verifies the receipt.',
    path: 'lib/core/services/purchase_service.dart',
    template: _purchases,
    registration: _purchaseFactory,
    packageImports: _dioImportWhenDio,
    disposes: true,
    packages: ['in_app_purchase'],
    endpoints: _purchaseEndpoints,
    list: ServiceList.features,
    docs:
        'Resolve it in `main` so unfinished purchases are replayed; '
        '`products(ids)`, `buy(product)`, `restore()` (Apple requires the '
        'button), and grant what arrives on `delivered`.',
  );

  /// A WebSocket.
  static const realtime = ServiceOption(
    name: 'realtime-service',
    title: 'RealtimeService',
    label: 'Realtime connection (WebSocket)',
    description:
        'One socket to the backend for chat or live updates, reconnecting '
        'with backoff.',
    path: 'lib/core/services/realtime_service.dart',
    template: _realtime,
    disposes: true,
    packages: ['web_socket_channel'],
    requirement: PlatformRequirement.realtime,
    endpoints: _realtimeEndpoints,
    list: ServiceList.features,
    docs:
        '`connect()`, `messages`, `send(text)`, `close()`. The URL is '
        '`BASE_URL` on ws(s):// at `ApiConstants.realtime`.',
  );

  /// On-device speech.
  static const voice = ServiceOption(
    name: 'voice-service',
    title: 'VoiceService',
    label: 'On-device voice (speech to text, text to speech)',
    description:
        'Whisper and a Matcha voice on the device (needs on-device AI).',
    path: 'lib/core/services/voice_service.dart',
    template: _voice,
    disposes: true,
    packages: ['flutter_edge_ai_speech', 'record'],
    requirement: PlatformRequirement.voice,
    list: ServiceList.features,
    docs:
        '`install()` once, then `startListening()` / `stopListening()` → '
        'text, and `speak(text)` → 16-bit PCM.',
  );

  /// On-device semantic search.
  static const knowledge = ServiceOption(
    name: 'knowledge-index',
    title: 'KnowledgeIndex',
    label: 'On-device search over your content (RAG)',
    description:
        'EmbeddingGemma and a SQLite vector store, to ground the model in '
        'the app\'s own text (needs on-device AI).',
    path: 'lib/core/services/knowledge_index.dart',
    template: _knowledge,
    disposes: true,
    packages: [
      'flutter_edge_ai_rag',
      'flutter_edge_ai_sqlite',
      'path',
      'path_provider',
    ],
    list: ServiceList.features,
    docs:
        '`install()` once, `add(id, text)`, then `search(question)` and put '
        'the passages in the `LlmService` prompt.',
  );

  /// Every option, in checklist order.
  static const all = [
    integrity,
    screenSecurity,
    sessionLock,
    moderation,
    share,
    review,
    location,
    scanner,
    health,
    purchases,
    realtime,
    voice,
    knowledge,
  ];

  /// The option [label] names, or null.
  static ServiceOption? byLabel(String label) {
    for (final option in all) {
      if (option.label == label) return option;
    }
    return null;
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  static String _integrity(ServiceVariant _) =>
      ProductTemplates.deviceIntegrityService();
  static String _screenSecurity(ServiceVariant _) =>
      ProductTemplates.screenSecurityService();
  static String _sessionLock(ServiceVariant v) =>
      ProductTemplates.sessionLockService(withBiometric: v.withBiometric);
  static String _moderation(ServiceVariant v) =>
      ProductTemplates.moderationService(
        withFirestore: v.moderationOverFirestore,
      );
  static String _share(ServiceVariant _) => ProductTemplates.shareService();
  static String _review(ServiceVariant _) => ProductTemplates.reviewService();
  static String _location(ServiceVariant _) =>
      ProductTemplates.locationService();
  static String _scanner(ServiceVariant _) => ProductTemplates.scannerService();
  static String _health(ServiceVariant _) => ProductTemplates.healthService();
  static String _purchases(ServiceVariant v) =>
      ProductTemplates.purchaseService(withDio: v.withDio);
  static String _realtime(ServiceVariant _) =>
      ProductTemplates.realtimeService();
  static String _voice(ServiceVariant _) => ProductTemplates.voiceService();
  static String _knowledge(ServiceVariant _) =>
      ProductTemplates.knowledgeIndex();

  // ── Registrations ─────────────────────────────────────────────────────────

  static String _integrityFactory(ServiceVariant _) =>
      '() => DeviceIntegrityService(getIt<Dio>())';
  static String _sessionLockFactory(ServiceVariant v) => v.withBiometric
      ? '() => SessionLockService(\n'
            '            getIt<AppLifecycleService>(), getIt<BiometricService>())'
      : '() => SessionLockService(getIt<AppLifecycleService>())';
  static String _moderationFactory(ServiceVariant v) =>
      v.moderationOverFirestore
      ? '() => ModerationService(\n'
            '            getIt<FirebaseFirestore>(), getIt<FirebaseAuth>())'
      : '() => ModerationService(getIt<Dio>())';
  static String _purchaseFactory(ServiceVariant v) => v.withDio
      ? '() => PurchaseService(getIt<Dio>())..start()'
      : '() => PurchaseService()..start()';

  static List<String> _dioImport(ServiceVariant _) => const [
    "import 'package:dio/dio.dart';",
  ];
  static List<String> _dioImportWhenDio(ServiceVariant v) =>
      v.withDio ? const ["import 'package:dio/dio.dart';"] : const [];
  static List<String> _moderationImports(ServiceVariant v) =>
      v.moderationOverFirestore
      ? const [
          "import 'package:cloud_firestore/cloud_firestore.dart';",
          "import 'package:firebase_auth/firebase_auth.dart';",
        ]
      : const ["import 'package:dio/dio.dart';"];

  // ── Endpoints ─────────────────────────────────────────────────────────────

  static Map<String, String> _integrityEndpoints(ServiceVariant _) => const {
    'integrityChallenge': '/integrity/challenge',
    'integrityVerify': '/integrity/verify',
  };
  static Map<String, String> _moderationEndpoints(ServiceVariant v) =>
      v.moderationOverFirestore
      ? const {}
      : const {
          'moderationReports': '/moderation/reports',
          'moderationBlocks': '/moderation/blocks',
        };
  static Map<String, String> _purchaseEndpoints(ServiceVariant v) =>
      v.withDio ? const {'purchasesVerify': '/purchases/verify'} : const {};
  static Map<String, String> _realtimeEndpoints(ServiceVariant _) => const {
    'realtime': '/ws',
  };
}
