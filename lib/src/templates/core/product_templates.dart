/// Templates for the optional services the checklist's *Security* and
/// *Product features* lists add under `lib/core/` — one file each, listed in
/// `utils/service_options.dart`.
class ProductTemplates {
  ProductTemplates._();

  // ── On-device AI ──────────────────────────────────────────────────────────

  /// `core/services/edge_ai.dart`: the one `FlutterEdgeAi.initialize` call.
  ///
  /// flutter_edge_ai is initialized once per process, with every engine the
  /// app uses, so the services that use it share this rather than each
  /// calling it with only their own.
  static String edgeAiRuntime({
    bool withSpeech = false,
    bool withSearch = false,
  }) =>
      '''
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
${withSpeech ? "import 'package:flutter_edge_ai_speech/flutter_edge_ai_speech.dart';\n" : ''}
Future<void>? _ready;

/// Registers every on-device engine this app uses, once. Each service calls
/// it before its first model call; later calls return the same future.
Future<void> ensureEdgeAi() => _ready ??= FlutterEdgeAi.initialize(
  inferenceEngines: const [LiteRtLmEngine()],${withSearch ? '\n  embeddingBackends: const [LiteRtEmbeddingBackend()],' : ''}${withSpeech ? '\n  sttBackends: const [LiteRtSttBackend()],\n  ttsBackends: const [LiteRtTtsBackend()],' : ''}
);
''';

  /// `core/services/voice_service.dart`: on-device speech to text and text
  /// to speech (Whisper and Matcha, through flutter_edge_ai_speech).
  static String voiceService() => r'''
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_speech/flutter_edge_ai_speech.dart';
import 'package:record/record.dart';

import 'edge_ai.dart';

/// Speech to text and text to speech, both on the device.
///
/// [install] downloads the two models once. Then [startListening] and
/// [stopListening] turn the microphone into text, and [speak] turns text
/// into 16-bit PCM at the voice's sample rate — play it with an audio
/// player that takes raw PCM.
class VoiceService {
  /// The recognizer: Whisper tiny, which hears up to 30 s at a time. Longer
  /// audio is cut off, so stop listening before that.
  static final LiteRtSttVariant recognizer = LiteRtSpeechModels.whisperTiny.f32;

  /// The voice [speak] uses.
  static final voice = LiteRtSpeechModels.matchaTts.bundle;

  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _heard = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _mic;

  /// Downloads both models, reporting the recognizer's 0–100 to
  /// [onProgress]. Returns at once for a model already installed.
  Future<void> install({void Function(int percent)? onProgress}) async {
    await ensureEdgeAi();
    await FlutterEdgeAi.installStt()
        .fromCatalog(recognizer)
        .withProgress((percent) => onProgress?.call(percent))
        .install();
    await FlutterEdgeAi.installTts().fromCatalog(voice).install();
  }

  /// Starts recording. False when the microphone permission is refused.
  Future<bool> startListening() async {
    if (!await _recorder.hasPermission()) return false;
    // What the recognizer takes: 16 kHz mono 16-bit PCM.
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _heard.clear();
    _mic = stream.listen(_heard.add);
    return true;
  }

  /// Stops recording and returns what was said.
  Future<String> stopListening() async {
    await _recorder.stop();
    await _mic?.cancel();
    _mic = null;
    return transcribe(_heard.takeBytes());
  }

  /// [pcm] as text: 16 kHz mono 16-bit little-endian PCM, not a WAV file.
  Future<String> transcribe(Uint8List pcm) async {
    await ensureEdgeAi();
    final recognizer = await FlutterEdgeAi.getActiveStt();
    return recognizer.transcribe(pcm);
  }

  /// [text] as 16-bit PCM.
  Future<Uint8List> speak(String text) async {
    await ensureEdgeAi();
    final synthesizer = await FlutterEdgeAi.getActiveTts();
    return synthesizer.synthesize(text);
  }

  /// Releases the microphone.
  Future<void> dispose() => _recorder.dispose();
}
''';

  /// `core/services/knowledge_index.dart`: on-device semantic search over
  /// the app's own text, for grounding the model's answers (RAG).
  static String knowledgeIndex() => r'''
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_rag/flutter_edge_ai_rag.dart';
import 'package:flutter_edge_ai_sqlite/flutter_edge_ai_sqlite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'edge_ai.dart';

/// Search by meaning over the app's own text, on the device: [add] what the
/// model should know, then [search] for the passages that answer a
/// question and put them in the prompt.
///
/// Keep each passage under ~500 tokens: a longer one is refused, never
/// truncated.
class KnowledgeIndex {
  /// The embedding model: EmbeddingGemma 2, text only (270M).
  static final LiteRtEmbedderVariant embedder =
      LiteRtEmbedders.embeddinggemma2Text270m.generic;

  final FlutterEdgeAiRag _rag = FlutterEdgeAiRag(
    providers: [const SqliteVectorStoreProvider()],
  );
  RagIndex? _index;

  /// Downloads the embedding model once, reporting 0–100 to [onProgress].
  Future<void> install({void Function(int percent)? onProgress}) async {
    await ensureEdgeAi();
    await FlutterEdgeAi.installEmbedder()
        .fromCatalog(embedder)
        .withProgress((percent) => onProgress?.call(percent))
        .install();
  }

  Future<RagIndex> _open() async {
    if (_index case final index?) return index;
    await ensureEdgeAi();
    final dir = await getApplicationDocumentsDirectory();
    return _index = await _rag.open(
      spec: VectorStoreSpec(
        providerId: 'sqlite',
        location: p.join(dir.path, 'knowledge.db'),
      ),
      embedder: FlutterEdgeAiActiveEmbedder.forActiveModel(
        namespace: 'knowledge',
      ),
    );
  }

  /// Stores [text] under [id]; the same id replaces it.
  Future<void> add(String id, String text) async {
    final index = await _open();
    await index.add(id: id, document: EmbeddingInput.text(text));
    await index.flush();
  }

  /// The [topK] stored passages closest in meaning to [query].
  Future<List<String>> search(String query, {int topK = 4}) async {
    final index = await _open();
    final hits = await index.search(
      query: EmbeddingInput.text(query),
      topK: topK,
    );
    return [for (final hit in hits) hit.content];
  }

  /// Closes the index file.
  Future<void> dispose() async {
    await _index?.dispose();
    _index = null;
  }
}
''';

  // ── Device ────────────────────────────────────────────────────────────────

  /// `core/services/share_service.dart`: the system share sheet.
  static String shareService() => r'''
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// The system share sheet.
///
/// On iPad the sheet is a popover and needs something to point at: pass the
/// tapped widget's context as `origin`.
class ShareService {
  /// Shares [text] and [link]. True when the user picked a target.
  Future<bool> share({
    String? text,
    Uri? link,
    String? subject,
    BuildContext? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: [?text, ?link?.toString()].join('\n'),
        subject: subject,
        sharePositionOrigin: _originOf(origin),
      ),
    );
    return result.status == ShareResultStatus.success;
  }

  /// Shares the files at [paths], with an optional [text].
  Future<bool> shareFiles(
    List<String> paths, {
    String? text,
    BuildContext? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [for (final path in paths) XFile(path)],
        text: text,
        sharePositionOrigin: _originOf(origin),
      ),
    );
    return result.status == ShareResultStatus.success;
  }

  Rect? _originOf(BuildContext? context) {
    final box = context?.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }
}
''';

  /// `core/services/review_service.dart`: the store's in-app rating prompt.
  static String reviewService() => r'''
import 'package:in_app_review/in_app_review.dart';

/// The store's own rating prompt, without leaving the app.
///
/// Ask after a moment that went well (an order placed, a goal reached),
/// never on launch or after an error. The stores decide whether the prompt
/// actually shows — iOS at most three times a year — so a call is a request,
/// and nothing here needs to count them.
class ReviewService {
  final InAppReview _review = InAppReview.instance;

  /// Asks for a rating when the store can show the prompt.
  Future<void> requestReview() async {
    if (await _review.isAvailable()) await _review.requestReview();
  }

  /// Opens the app's store page, for a "Rate us" button. [appStoreId] is
  /// the numeric App Store id, which iOS needs.
  Future<void> openStoreListing({String? appStoreId}) =>
      _review.openStoreListing(appStoreId: appStoreId);
}
''';

  /// `core/services/location_service.dart`: the device's position.
  static String locationService() => r'''
import 'package:geolocator/geolocator.dart';

/// The device's position, asking for permission when it is needed.
///
/// Ask from a screen that says why (a "Use my location" button), not on
/// launch: a refused request on iOS is not asked again.
class LocationService {
  /// Where the device is now, or null without permission or with location
  /// services off.
  Future<Position?> current() async {
    if (!await _ensurePermission()) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// The position every time it moves [distanceFilter] metres. Check
  /// [current] first: the stream does not ask for permission.
  Stream<Position> watch({int distanceFilter = 10}) =>
      Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
        ),
      );

  /// Metres between two points.
  double distanceBetween(Position from, Position to) =>
      Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );

  /// The app's settings page, for a permission refused for good.
  Future<bool> openSettings() => Geolocator.openAppSettings();

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
''';

  /// `core/services/scanner_service.dart`: a full-screen barcode and QR
  /// scanner that returns the first code it reads.
  static String scannerService() => r'''
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Barcodes and QR codes through the camera.
///
/// `final code = await getIt<ScannerService>().scan(context);` opens a
/// full-screen scanner and returns the first code it reads, or null when
/// the user goes back. The camera permission is asked by the scanner itself.
class ScannerService {
  /// Opens the scanner; [title] is its app bar.
  Future<String?> scan(BuildContext context, {String title = 'Scan'}) =>
      Navigator.of(context).push(
        MaterialPageRoute<String>(builder: (_) => _ScannerPage(title: title)),
      );
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage({required this.title});

  final String title;

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  // The camera reports the same code many times a second; pop once.
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: MobileScanner(
      onDetect: (capture) {
        final value = capture.barcodes.firstOrNull?.rawValue;
        if (value == null || _done) return;
        _done = true;
        Navigator.of(context).pop(value);
      },
    ),
  );
}
''';

  /// `core/services/health_service.dart`: Apple Health and Health Connect.
  static String healthService() => r'''
import 'dart:io';

import 'package:health/health.dart';

/// Apple Health on iOS, Health Connect on Android.
///
/// Starts with step counts. Add a type to [types], and on Android its
/// `android.permission.health.READ_…` permission to `AndroidManifest.xml`:
/// Health Connect never offers a type the manifest does not declare.
class HealthService {
  /// What [requestAccess] asks to read.
  static const types = [HealthDataType.STEPS];

  final Health _health = Health();
  Future<void>? _configured;

  Future<void> _configure() => _configured ??= _health.configure();

  /// Whether health data can be read here. On Android 13 and lower that
  /// takes the Health Connect app from Google Play; hide the integration
  /// when this is false.
  Future<bool> isAvailable() async {
    await _configure();
    if (!Platform.isAndroid) return true;
    final status = await _health.getHealthConnectSdkStatus();
    return status == HealthConnectSdkStatus.sdkAvailable;
  }

  /// Asks to read [types]. Explain why first: iOS asks only once.
  Future<bool> requestAccess() async {
    await _configure();
    return _health.requestAuthorization(types);
  }

  /// Steps since midnight, from every app that records them.
  Future<int?> stepsToday() async {
    await _configure();
    final now = DateTime.now();
    return _health.getTotalStepsInInterval(
      DateTime(now.year, now.month, now.day),
      now,
    );
  }
}
''';

  // ── Commerce ──────────────────────────────────────────────────────────────

  /// `core/services/purchase_service.dart`: App Store and Google Play
  /// purchases through in_app_purchase. [withDio] verifies each one on the
  /// backend; without it the check is a TODO that delivers nothing.
  static String purchaseService({bool withDio = false}) {
    final imports = withDio ? "import 'package:dio/dio.dart';\n" : '';
    final localImports = withDio
        ? "\nimport '../constants/api_constants.dart';"
        : '';
    final constructor = withDio
        ? '''
  PurchaseService(this._dio);

  final Dio _dio;
'''
        : '';
    final verify = withDio
        ? r'''
  // The store's receipt goes to the backend, which asks the store whether it
  // is genuine and records the entitlement. The app never decides that.
  Future<bool> _verify(PurchaseDetails purchase) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.purchasesVerify,
        data: {
          'productId': purchase.productID,
          'source': purchase.verificationData.source,
          'receipt': purchase.verificationData.serverVerificationData,
        },
      );
      return response.data?['valid'] == true;
    } on DioException catch (e) {
      _log.e('Verifying ${purchase.productID} failed', error: e);
      return false;
    }
  }'''
        : r'''
  // TODO: send `purchase.verificationData.serverVerificationData` to your
  // backend, which asks the store whether it is genuine. Until then nothing
  // is delivered: a receipt checked on the device can be forged.
  Future<bool> _verify(PurchaseDetails purchase) async {
    _log.w('No receipt check yet — ${purchase.productID} not delivered');
    return false;
  }''';
    return '''
import 'dart:async';

${imports}import 'package:in_app_purchase/in_app_purchase.dart';
$localImports
import '../utils/app_logger.dart';

final _log = appLogger.scoped('Purchases');

/// App Store and Google Play purchases.
///
/// The store reports purchases on a stream that also replays the ones not
/// finished last time, so resolve this from the locator early (in `main`)
/// and [delivered] is where the app grants what was bought — only after the
/// backend has verified it.
class PurchaseService {
$constructor  final InAppPurchase _store = InAppPurchase.instance;
  final _delivered = StreamController<PurchaseDetails>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Purchases that passed verification: grant them here.
  Stream<PurchaseDetails> get delivered => _delivered.stream;

  /// Starts listening to the store. The locator calls it on first use.
  void start() {
    _subscription ??= _store.purchaseStream.listen(_onPurchases);
  }

  /// The store's listing of [ids] (the ids in App Store Connect and Play
  /// Console). Empty when the store cannot be reached.
  Future<List<ProductDetails>> products(Set<String> ids) async {
    if (!await _store.isAvailable()) return const [];
    final response = await _store.queryProductDetails(ids);
    return response.productDetails;
  }

  /// Opens the store's purchase sheet. The result arrives on [delivered].
  Future<bool> buy(ProductDetails product, {bool consumable = false}) {
    final param = PurchaseParam(productDetails: product);
    return consumable
        ? _store.buyConsumable(purchaseParam: param)
        : _store.buyNonConsumable(purchaseParam: param);
  }

  /// Replays past non-consumable purchases and subscriptions on
  /// [delivered]. Apple requires a visible "Restore purchases" button.
  Future<void> restore() => _store.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (await _verify(purchase)) _delivered.add(purchase);
        case PurchaseStatus.error:
          _log.w('Purchase failed: \${purchase.error?.message}');
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
      // Unfinished purchases are refunded by Google after three days.
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
  }

$verify

  /// Stops listening.
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _delivered.close();
  }
}
''';
  }

  // ── Social ────────────────────────────────────────────────────────────────

  /// `core/services/realtime_service.dart`: one WebSocket to the backend,
  /// reconnecting with backoff.
  static String realtimeService() => r'''
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/env/app_env.dart';
import '../constants/api_constants.dart';
import '../utils/app_logger.dart';

final _log = appLogger.scoped('Realtime');

/// One WebSocket to the backend, for chat, presence or live updates.
///
/// [connect] once (after sign-in, if the socket needs the session), listen
/// to [messages], and [send] text — JSON is the usual shape. A dropped
/// connection is retried with backoff until [close].
class RealtimeService {
  RealtimeService({Uri? url}) : _url = url ?? _defaultUrl();

  // BASE_URL with ws:// or wss:// and the realtime path.
  static Uri _defaultUrl() {
    final base = Uri.parse(AppEnv.baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: ApiConstants.realtime,
    );
  }

  final Uri _url;
  final _messages = StreamController<String>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  int _attempt = 0;
  bool _closed = true;

  /// Every message the backend sends, as text.
  Stream<String> get messages => _messages.stream;

  /// Opens the socket. Safe to call again after [close].
  Future<void> connect() async {
    _closed = false;
    // TODO: pass the session token if the socket needs one — as a query
    // parameter or a first message, since browsers cannot set headers.
    final channel = WebSocketChannel.connect(_url);
    _channel = channel;
    try {
      await channel.ready;
      _attempt = 0;
    } on Object catch (e) {
      _log.w('Could not connect: $e');
      _reconnect();
      return;
    }
    _subscription = channel.stream.listen(
      (data) => _messages.add(
        data is String ? data : utf8.decode(data as List<int>),
      ),
      onDone: _reconnect,
      onError: (Object _) => _reconnect(),
    );
  }

  /// Sends [message]; dropped while disconnected.
  void send(String message) => _channel?.sink.add(message);

  // 1, 2, 4 … 30 s between attempts.
  void _reconnect() {
    if (_closed) return;
    _subscription?.cancel();
    final delay = Duration(seconds: min(30, 1 << min(_attempt++, 5)));
    _retry = Timer(delay, connect);
  }

  /// Closes the socket and stops retrying.
  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
  }

  /// Closes the socket and the [messages] stream.
  Future<void> dispose() async {
    await close();
    await _messages.close();
  }
}
''';

  /// `core/services/moderation_service.dart`: report and block, which both
  /// stores require of any app where users see each other's content.
  /// Firestore when [withFirestore], the REST API otherwise.
  static String moderationService({bool withFirestore = false}) =>
      withFirestore ? _moderationFirestore : _moderationDio;

  static const _moderationHeader = r'''
/// Why something was reported. The stores ask for a way to report
/// objectionable content and abusive users; the review itself happens on
/// the backend, which must act on reports in a timely way.
enum ReportReason { spam, harassment, hate, nudity, violence, other }
''';

  static const String _moderationDio = '''
import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../network/safe_api_call.dart';

$_moderationHeader$_moderationDioBody''';

  static const String _moderationDioBody = r'''
/// Report and block, over the REST API.
///
/// Blocking hides the blocked user's content from this user, and must also
/// stop them contacting this user: filter both on the backend, since the
/// app only hides what it is sent.
class ModerationService {
  ModerationService(this._dio);

  final Dio _dio;

  /// Reports another user.
  Future<void> reportUser(
    String userId, {
    required ReportReason reason,
    String? details,
  }) => _report('user', userId, reason, details);

  /// Reports a post, comment, message or anything else users publish.
  Future<void> reportContent(
    String contentId, {
    required ReportReason reason,
    String? details,
  }) => _report('content', contentId, reason, details);

  Future<void> _report(
    String type,
    String targetId,
    ReportReason reason,
    String? details,
  ) => safeApiCall(
    apiCall: () => _dio.post<void>(
      ApiConstants.moderationReports,
      data: {
        'type': type,
        'targetId': targetId,
        'reason': reason.name,
        'details': ?details,
      },
    ),
  );

  /// Blocks [userId] for the signed-in user.
  Future<void> block(String userId) => safeApiCall(
    apiCall: () => _dio.post<void>(
      ApiConstants.moderationBlocks,
      data: {'userId': userId},
    ),
  );

  /// Lifts a block.
  Future<void> unblock(String userId) => safeApiCall(
    apiCall: () =>
        _dio.delete<void>('${ApiConstants.moderationBlocks}/$userId'),
  );

  /// The users the signed-in user blocked, for hiding their content.
  Future<Set<String>> blockedUserIds() => safeApiCall(
    apiCall: () async {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.moderationBlocks,
      );
      return {...?response.data?.cast<String>()};
    },
  );
}
''';

  static const String _moderationFirestore = '''
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../network/safe_firebase_call.dart';

$_moderationHeader$_moderationFirestoreBody''';

  static const String _moderationFirestoreBody = r'''
/// Report and block, in Firestore: reports go to `reports`, and the users a
/// user blocked to `users/{uid}/blocked/{blockedUid}`.
///
/// Lock both down in your security rules: anyone signed in may create a
/// report but never read one, and only the owner may touch their `blocked`
/// collection. Hide blocked users' content in the queries that read it.
class ModerationService {
  ModerationService(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Reporting needs a signed-in user');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _blocked =>
      _firestore.collection('users').doc(_uid).collection('blocked');

  /// Reports another user.
  Future<void> reportUser(
    String userId, {
    required ReportReason reason,
    String? details,
  }) => _report('user', userId, reason, details);

  /// Reports a post, comment, message or anything else users publish.
  Future<void> reportContent(
    String contentId, {
    required ReportReason reason,
    String? details,
  }) => _report('content', contentId, reason, details);

  Future<void> _report(
    String type,
    String targetId,
    ReportReason reason,
    String? details,
  ) => safeFirebaseCall(
    call: () => _firestore.collection('reports').add({
      'type': type,
      'targetId': targetId,
      'reason': reason.name,
      'details': ?details,
      'reporterId': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );

  /// Blocks [userId] for the signed-in user.
  Future<void> block(String userId) => safeFirebaseCall(
    call: () => _blocked.doc(userId).set({
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );

  /// Lifts a block.
  Future<void> unblock(String userId) =>
      safeFirebaseCall(call: () => _blocked.doc(userId).delete());

  /// The users the signed-in user blocked, as they change.
  Stream<Set<String>> watchBlockedUserIds() => _blocked.snapshots().map(
    (snapshot) => {for (final doc in snapshot.docs) doc.id},
  );
}
''';

  // ── Security ──────────────────────────────────────────────────────────────

  /// `core/security/device_integrity_service.dart`: root and jailbreak
  /// checks on the device, and Play Integrity / App Attest verified by the
  /// backend.
  static String deviceIntegrityService() => r'''
import 'dart:io';

import 'package:app_device_integrity/app_device_integrity.dart';
import 'package:dio/dio.dart';
import 'package:safe_device/safe_device.dart';

import '../constants/api_constants.dart';

/// Whether the app is running on a device and a build it can trust.
///
/// Two checks, for two jobs:
/// - [isCompromised] is on-device and instant: root or jailbreak, or an
///   emulator. A determined attacker can hide both, so treat it as a signal
///   — warn, or turn off the riskiest actions — never as the only gate.
/// - [attest] asks Google (Play Integrity) or Apple (App Attest) to vouch
///   for the app and the device, and the backend checks the answer. Run it
///   before the actions that move money or data, and let the backend refuse.
class DeviceIntegrityService {
  DeviceIntegrityService(this._dio);

  final Dio _dio;

  /// The Google Cloud project number linked to the app in Play Console
  /// (Release → App integrity). Play Integrity needs it on Android.
  // TODO: your project number.
  static const int googleCloudProjectNumber = 0;

  /// Rooted or jailbroken, or not a real device.
  Future<bool> isCompromised() async =>
      await SafeDevice.isJailBroken || !await SafeDevice.isRealDevice;

  /// Gets a one-time challenge from the backend, has the platform sign it,
  /// and returns whether the backend accepted the token.
  Future<bool> attest() async {
    final challenge = await _dio.get<Map<String, dynamic>>(
      ApiConstants.integrityChallenge,
    );
    final nonce = challenge.data?['challenge'] as String?;
    if (nonce == null) return false;
    final token = await AppDeviceIntegrity().getAttestationServiceSupport(
      challengeString: nonce,
      gcp: googleCloudProjectNumber,
    );
    if (token == null) return false;
    final verdict = await _dio.post<Map<String, dynamic>>(
      ApiConstants.integrityVerify,
      data: {'token': token, 'platform': Platform.operatingSystem},
    );
    return verdict.data?['valid'] == true;
  }
}
''';

  /// `core/security/screen_security_service.dart`: no screenshots or screen
  /// recording, and a blurred app-switcher snapshot.
  static String screenSecurityService() => r'''
import 'package:no_screenshot/no_screenshot.dart';

/// Keeps what is on screen off screenshots, screen recordings and the
/// app-switcher snapshot.
///
/// Call [protect] for the whole app in `main`, or in the `initState` of the
/// screens that show balances, codes or health data and [release] in their
/// `dispose`. On Android this is `FLAG_SECURE`: captures come out black.
class ScreenSecurityService {
  final NoScreenshot _plugin = NoScreenshot.instance;

  /// Blocks captures and blurs the app in the app switcher.
  Future<void> protect() async {
    await _plugin.screenshotOff();
    await _plugin.screenshotWithBlur();
  }

  /// Allows captures again.
  Future<void> release() async {
    await _plugin.screenshotOn();
    await _plugin.overlayOff();
  }
}
''';

  /// `core/security/session_lock_service.dart`: asks for the lock again
  /// after the app was away longer than a timeout. [withBiometric] unlocks
  /// with Face ID / fingerprint.
  static String sessionLockService({bool withBiometric = false}) {
    final biometricImport = withBiometric
        ? "import 'biometric_service.dart';\n"
        : '';
    final constructor = withBiometric
        ? '''
  SessionLockService(
    this._lifecycle,
    this._biometric, {
    this.timeout = const Duration(minutes: 5),
  }) {'''
        : '''
  SessionLockService(
    this._lifecycle, {
    this.timeout = const Duration(minutes: 5),
  }) {''';
    final biometricField = withBiometric
        ? '  final BiometricService _biometric;\n'
        : '';
    final unlock = withBiometric
        ? '''

  /// Face ID / fingerprint, or the device PIN.
  Future<bool> unlock() => _biometric.authenticate();'''
        : '''

  // TODO: unlock with the app's PIN or by signing in again.''';
    return '''
import 'dart:async';

import '../services/app_lifecycle_service.dart';
$biometricImport
/// Locks the session again once the app was in the background longer than
/// [timeout] — the banking-app rule that a phone left unlocked on a table
/// does not stay signed in.
///
/// Listen to [lockRequired] at the top of the app (or in the router's
/// redirect) and cover the app with the lock screen until the user unlocks.
class SessionLockService {
$constructor
    _subscription = _lifecycle.resumed.listen((away) {
      if (away >= timeout) _locks.add(null);
    });
  }

  final AppLifecycleService _lifecycle;
$biometricField
  /// How long the app may sit in the background before it locks.
  final Duration timeout;

  final _locks = StreamController<void>.broadcast();
  late final StreamSubscription<Duration> _subscription;

  /// Fires each time the app comes back after more than [timeout].
  Stream<void> get lockRequired => _locks.stream;$unlock

  /// Stops listening.
  Future<void> dispose() async {
    await _subscription.cancel();
    await _locks.close();
  }
}
''';
  }

  /// `core/network/certificate_pins.dart`: the SHA-256 fingerprints of the
  /// server certificates the Dio client accepts.
  static String certificatePins() => r'''
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// The server certificates the Dio client trusts, by the SHA-256
/// fingerprint of their DER bytes. Empty pins nothing.
///
/// Pin at least two: the current certificate and the one that replaces it.
/// A pin that no longer matches takes the whole app offline until an update
/// ships, so pin the certificate you control and rotate on a schedule.
///
/// Read a fingerprint with:
/// `openssl s_client -connect api.example.com:443 < /dev/null | openssl x509 -outform DER | openssl dgst -sha256`
abstract final class CertificatePins {
  // TODO: your fingerprints, lowercase hex without colons.
  static const Set<String> fingerprints = {};

  /// Whether [certificate] is one of the pinned ones. Everything passes in
  /// debug builds and while [fingerprints] is empty.
  static bool allows(X509Certificate? certificate) {
    if (kDebugMode || fingerprints.isEmpty) return true;
    if (certificate == null) return false;
    return fingerprints.contains(fingerprintOf(certificate.der));
  }

  /// The fingerprint [allows] compares.
  static String fingerprintOf(List<int> der) => '${sha256.convert(der)}';
}
''';
}
