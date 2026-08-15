import '../../utils/state_management.dart';

/// Services Template
///
/// These service bodies are identical in both stacks — only how the service
/// is *reached* differs — so each takes a [StateManagement] rather than being
/// copied into `templates/riverpod/` and `templates/bloc/`. Riverpod declares
/// a provider beside the class; a bloc project registers it in
/// `config/di/injector.dart` and pulls it out with `getIt<Thing>()`.
///
/// The genuinely different service — the language holder, a `Notifier` on one
/// side and a `Cubit` on the other — lives in each stack's own
/// `app_templates.dart` instead.
class ServicesTemplates {
  ServicesTemplates._();

  /// The `flutter_riverpod` import line, or nothing for a bloc project.
  /// Returns a notification service scaffold.
  ///
  /// It holds nothing of its own: the locator is global, so a tap handler
  /// calls `getIt<Thing>()` where it needs one.
  static String notificationsService() {
    const constructor = '''  NotificationService();

  // Reach other services from here with `getIt<Thing>()`, e.g. to navigate
  // on tap.
''';

    const ensureInitHint = 'Call getIt<NotificationService>().init() first.';

    return '''
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';
$_notificationsPreamble${_notificationsBody(constructor, ensureInitHint)}''';
  }

  /// Everything above the class: the platform notes, the logger and the
  /// top-level background handler.
  static const String _notificationsPreamble = r'''
// Android: AndroidManifest.xml needs RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM,
// USE_EXACT_ALARM and POST_NOTIFICATIONS.
// iOS: `moarch init` sets UNUserNotificationCenter.current().delegate in
// AppDelegate.swift. Never override userNotificationCenter(_:didReceive:)
// without calling super — that blocks the plugins from receiving taps.

final _log = appLogger.scoped('Notifications');

// Must stay top-level.
@pragma('vm:entry-point')
void _backgroundHandler(NotificationResponse response) {
  _log.i(
    'Background tap | id: ${response.id} | payload: ${response.payload}',
  );
}

enum NotificationPriority { defaultPriority, high }

''';

  /// The service class. Only its constructor and the init-failure hint vary
  /// with the stack, so the rest is written once.
  static String _notificationsBody(String constructor, String hint) => '''
class NotificationService {
$constructor
  bool _initialized = false;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _defaultChannelId = 'default_channel';
  static const String _defaultChannelName = 'Default Notifications';
  static const String _defaultChannelDesc = 'General app notifications';

  static const String _scheduledChannelId = 'scheduled_channel';
  static const String _scheduledChannelName = 'Scheduled Notifications';
  static const String _scheduledChannelDesc = 'Reminders and scheduled alerts';

  static const String _highPriorityChannelId = 'high_priority_channel';
  static const String _highPriorityChannelName = 'High Priority';
  static const String _highPriorityChannelDesc = 'Urgent notifications';

  static const int defaultId = 0;
  static const int scheduledId = 1;
  static const int periodicId = 2;
$_notificationsMethods
  void _ensureInit() {
    if (!_initialized) {
      throw StateError(
        'NotificationService not initialized. '
        '$hint',
      );
    }
  }
}
''';

  static const String _notificationsMethods = r'''
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Asked for in requestPermissions().
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        _log.i(
          'Tapped | id: ${response.id} | payload: ${response.payload}',
        );
      },
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );

    await _createNotificationChannels();

    _initialized = true;
    _log.i('Initialized');

    await requestPermissions();
  }

  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        _defaultChannelName,
        description: _defaultChannelDesc,
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _scheduledChannelId,
        _scheduledChannelName,
        description: _scheduledChannelDesc,
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _highPriorityChannelId,
        _highPriorityChannelName,
        description: _highPriorityChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableLights: true,
        enableVibration: true,
      ),
    );
  }

  /// Ask for notification permission — call it after onboarding, not on boot.
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }

    return false;
  }

  /// Show a notification right now.
  Future<void> show({
    int id = defaultId,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.defaultPriority,
  }) async {
    _ensureInit();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _buildDetails(priority),
      payload: payload,
    );
    _log.i('Shown (id: $id)');
  }

  /// Schedule at an exact [scheduledDate].
  ///
  /// [timeZoneName] is an IANA name like 'Europe/Lisbon'; defaults to local.
  Future<void> scheduleAt({
    int id = scheduledId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? timeZoneName,
  }) async {
    _ensureInit();

    final location =
        timeZoneName != null ? tz.getLocation(timeZoneName) : tz.local;
    final tzDate = tz.TZDateTime.from(scheduledDate, location);

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: _buildScheduledDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    _log.i('Scheduled at $tzDate (id: $id)');
  }

  /// Schedule a notification [delay] from now.
  Future<void> scheduleAfter({
    int id = scheduledId,
    required String title,
    required String body,
    Duration delay = const Duration(seconds: 5),
    String? payload,
  }) async {
    await scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledDate: DateTime.now().add(delay),
      payload: payload,
    );
  }

  /// Schedule a daily notification at [hour]:[minute].
  Future<void> scheduleDailyAt({
    int id = scheduledId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    _ensureInit();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: _buildScheduledDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
    _log.i('Daily scheduled at $hour:$minute (id: $id)');
  }

  /// Schedule a weekly notification on [day]
  /// (DateTime.monday..DateTime.sunday) at [hour]:[minute].
  Future<void> scheduleWeeklyAt({
    int id = scheduledId,
    required String title,
    required String body,
    required int day,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    _ensureInit();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfDay(day, hour, minute),
      notificationDetails: _buildScheduledDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
    _log.i(
      'Weekly scheduled (day $day at $hour:$minute, id: $id)',
    );
  }

  /// Show a repeating notification at a fixed [interval].
  Future<void> showPeriodic({
    int id = periodicId,
    required String title,
    required String body,
    RepeatInterval interval = RepeatInterval.hourly,
    String? payload,
  }) async {
    _ensureInit();

    await _plugin.periodicallyShow(
      id: id,
      title: title,
      body: body,
      repeatInterval: interval,
      notificationDetails: _buildDetails(NotificationPriority.defaultPriority),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    _log.i('Periodic ($interval) started (id: $id)');
  }

  /// Cancel a specific notification by [id].
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
    _log.i('Cancelled (id: $id)');
  }

  /// Cancel all pending and shown notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _log.i('Cancelled all');
  }

  /// Notifications that are scheduled but not yet shown.
  Future<List<PendingNotificationRequest>> getPending() =>
      _plugin.pendingNotificationRequests();

  NotificationDetails _buildDetails(NotificationPriority priority) {
    final isHigh = priority == NotificationPriority.high;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        isHigh ? _highPriorityChannelId : _defaultChannelId,
        isHigh ? _highPriorityChannelName : _defaultChannelName,
        channelDescription: isHigh ? _highPriorityChannelDesc : _defaultChannelDesc,
        importance: isHigh ? Importance.max : Importance.defaultImportance,
        priority: isHigh ? Priority.high : Priority.defaultPriority,
        ticker: 'ticker',
        color: AppConstants.primary,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: isHigh,
        interruptionLevel: isHigh
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );
  }

  NotificationDetails _buildScheduledDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _scheduledChannelId,
        _scheduledChannelName,
        channelDescription: _scheduledChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfDay(int day, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

''';

  /// Returns a Firebase Cloud Messaging (push notifications) service scaffold.
  static String firebaseNotificationsService() {
    const constructor = '''  FirebaseNotificationsService();

  // Reach other services from here with `getIt<Thing>()`, e.g. to navigate
  // on tap.
''';

    return '''
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/app_logger.dart';
$_firebaseNotificationsPreamble'''
        'class FirebaseNotificationsService {\n'
        '$constructor$_firebaseNotificationsBody';
  }

  static const String _firebaseNotificationsPreamble = r'''
// Setup:
// 1. Run `flutterfire configure`.
// 2. iOS: enable the Push Notifications and Background Modes (remote
//    notifications) capabilities in Xcode, and upload your APNs key to
//    Firebase console → Project settings → Cloud Messaging.
// 3. Android: google-services.json from flutterfire is enough.

final _log = appLogger.scoped('FCM');

// Must stay top-level.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Runs in its own isolate — call Firebase.initializeApp() before using any
  // other Firebase service here.
  _log.i('Background message | id: ${message.messageId}');
}

''';

  static const String _firebaseNotificationsBody = r'''
  static const int _tokenRetries = 5;
  static const Duration _tokenRetryDelay = Duration(seconds: 1);

  bool _initialized = false;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Shorthand for [getDeviceToken] with the default settings.
  Future<String?> get token => getDeviceToken();

  /// The FCM registration token for this device — send it to your backend.
  ///
  /// On Apple platforms FCM cannot mint a token until APNs has handed the app
  /// its own, so that one is awaited first. Returns null after [retries].
  Future<String?> getDeviceToken({
    int retries = _tokenRetries,
    Duration retryDelay = _tokenRetryDelay,
  }) async {
    if (_isApplePlatform) {
      final apnsToken = await getApnsToken(
        retries: retries,
        retryDelay: retryDelay,
      );
      if (apnsToken == null) {
        _log.e('No FCM token: APNs token never arrived');
        return null;
      }
    }

    for (var attempt = 1; attempt <= retries; attempt++) {
      try {
        // On web, pass your VAPID key here: getToken(vapidKey: '...').
        final fcmToken = await _messaging.getToken();
        if (fcmToken != null) {
          _log.i('FCM token acquired');
          return fcmToken;
        }
        _log.w('FCM token null (attempt $attempt/$retries)');
      } catch (error, stackTrace) {
        _log.w(
          'FCM token failed (attempt $attempt/$retries)',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (attempt < retries) {
        await Future<void>.delayed(retryDelay * attempt);
      }
    }

    _log.e('No FCM token after $retries attempts');
    return null;
  }

  /// The raw APNs token — iOS and macOS only, null everywhere else.
  ///
  /// Polled, because registration is still in flight for a moment after the
  /// permission prompt. [getDeviceToken] already waits for it.
  Future<String?> getApnsToken({
    int retries = _tokenRetries,
    Duration retryDelay = _tokenRetryDelay,
  }) async {
    if (!_isApplePlatform) return null;

    for (var attempt = 1; attempt <= retries; attempt++) {
      try {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          _log.i('APNs token acquired');
          return apnsToken;
        }
        _log.w('APNs token not ready (attempt $attempt/$retries)');
      } catch (error, stackTrace) {
        _log.w(
          'APNs token failed (attempt $attempt/$retries)',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (attempt < retries) {
        await Future<void>.delayed(retryDelay * attempt);
      }
    }

    _log.w(
      'No APNs token after $retries attempts. Check the Push Notifications '
      'capability in Xcode and the APNs key in the Firebase console.',
    );
    return null;
  }

  Future<void> init() async {
    if (_initialized) return;

    // Safe if Firebase was already initialized elsewhere (e.g. Crashlytics).
    // Pass DefaultFirebaseOptions.currentPlatform after `flutterfire configure`.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // iOS: show the system banner while the app is in the foreground.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set when a notification opened the app from a terminated state.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _onMessageOpened(initialMessage);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    _messaging.onTokenRefresh.listen((token) {
      _log.i('Token refreshed');
      // TODO: send the new token to your backend.
    });

    _initialized = true;
    _log.i('Initialized');

    await requestPermissions();
  }

  /// True when granted, or provisionally granted on iOS.
  Future<bool> requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Receive messages sent to a topic (server side: send to /topics/topic).
  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  void _onForegroundMessage(RemoteMessage message) {
    _log.i(
      'Foreground message | title: ${message.notification?.title}',
    );
    // Android shows no system notification for foreground messages — show one
    // yourself with the local NotificationService if you generated it.
  }

  void _onMessageOpened(RemoteMessage message) {
    _log.i('Opened from notification | data: ${message.data}');
    // TODO: navigate based on message.data.
  }
}
''';

  /// Returns the generated mediaService template.
  static String mediaService() => '''
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_service.dart';

$_mediaServiceBody''';

  static const String _mediaServiceBody = r'''class MediaService {
  MediaService(this._permissionService);

  final PermissionService _permissionService;
  final ImagePicker _imagePicker = ImagePicker();

  /// Pick an image from gallery or camera.
  Future<File?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    if (source == ImageSource.camera) {
      final granted = await _permissionService.request(
        permission: Permission.camera,
      );
      if (!granted) {
        return null;
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      final granted = await _permissionService.request(
        permission: Permission.photos,
      );
      if (!granted) {
        return null;
      }
    }

    final XFile? file = await _imagePicker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    return file != null ? File(file.path) : null;
  }

  /// Pick multiple images from gallery.
  Future<List<File>?> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final granted = await _permissionService.request(
        permission: Permission.photos,
      );
      if (!granted) {
        return null;
      }
    }

    final List<XFile> files = await _imagePicker.pickMultiImage(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    return files.map((file) => File(file.path)).toList();
  }

  /// Pick a video from gallery or camera.
  Future<File?> pickVideo({
    required ImageSource source,
    Duration? maxDuration,
  }) async {
    if (source == ImageSource.camera) {
      final granted = await _permissionService.request(
        permission: Permission.camera,
      );
      if (!granted) {
        return null;
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      final granted = await _permissionService.request(
        permission: Permission.photos,
      );
      if (!granted) {
        return null;
      }
    }

    final XFile? file = await _imagePicker.pickVideo(
      source: source,
      maxDuration: maxDuration,
    );

    return file != null ? File(file.path) : null;
  }

  /// Pick one or more files from the device.
  Future<List<File>?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    if (Platform.isAndroid) {
      final granted = await _permissionService.request(
        permission: Permission.photos,
      );
      if (!granted) {
        return null;
      }
    }

    // Static since file_picker 11 — `FilePicker.platform` was the entry point
    // up to 10.x.
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );

    if (result == null || result.files.isEmpty) return [];

    return result.paths
        .where((path) => path != null)
        .map((path) => File(path!))
        .toList();
  }
}
''';

  /// Returns the generated launchUrlService template.
  static String launchUrlService() => '''
import 'package:url_launcher/url_launcher.dart';

import '../../core/security/validation_service.dart';

$_launchUrlServiceBody''';

  static const String _launchUrlServiceBody = r'''class UrlLauncherService {
  UrlLauncherService();

  /// Launch a URL string.
  Future<void> launch(String url, {LaunchMode? mode}) async {
    // InputType.url holds the scheme to http/https, so a `javascript:` or
    // `file:` link can never reach the platform launcher.
    final ValidationResult res = ValidationService.validate(
      url,
      inputType: InputType.url,
    );

    if (!res.isValid) return;

    final uri = Uri.parse(res.sanitizedValue);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: mode ?? LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      }
    } catch (e) {
      // error feedback
    }
  }
}
''';

  /// Returns the generated connectivityService template.
  ///
  /// The service itself is registered in the locator in both stacks. Riverpod
  /// additionally gets `hasInternetProvider` over it — connectivity *is*
  /// state, and a widget wants to watch it rather than resolve it once.
  static String connectivityService({
    StateManagement stateManagement = StateManagement.riverpod,
  }) {
    final isBloc = stateManagement.isBloc;

    final imports = isBloc
        ? ''
        : "import 'package:flutter_riverpod/flutter_riverpod.dart';\n";

    final providers = isBloc
        ? ''
        : '''

/// The connection, as something a widget can watch. The service behind it
/// comes out of the locator like every other dependency.
final hasInternetProvider = StreamProvider<bool>((ref) {
  return getIt<ConnectivityService>().hasInternetStream;
});
''';

    final locatorImport =
        isBloc ? '' : "import '../../config/di/injector.dart';\n";

    return '''
import 'package:connectivity_plus/connectivity_plus.dart';
$imports
${locatorImport}import '../utils/app_logger.dart';

final _log = appLogger.scoped('Connectivity');
$providers
$_connectivityServiceBody''';
  }

  static const String _connectivityServiceBody = r'''class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get hasInternetStream =>
      _connectivity.onConnectivityChanged.map((results) {
        _log.d('$results');
        return !results.contains(ConnectivityResult.none);
      });
  Future<bool> hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}
''';

  /// Returns the generated debouncerService template.
  static String debouncerService() => '''
import 'dart:async';

$_debouncerServiceBody''';

  static const String _debouncerServiceBody = r'''class DebouncerService {
  final Duration delay;
  Timer? _timer;

  DebouncerService({this.delay = const Duration(milliseconds: 500)});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
''';

  /// Returns the generated permissionService template.
  static String permissionService() => '''
import 'package:permission_handler/permission_handler.dart';

$_permissionServiceBody''';

  static const String _permissionServiceBody = r'''class PermissionService {
  /// Request a specific permission.
  Future<bool> request({required Permission permission}) async {
    final status = await permission.status;

    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return true;

      case PermissionStatus.denied:
        final response = await permission.request();
        return response.isGranted || response.isLimited;

      case PermissionStatus.permanentlyDenied:
        await openAppSettings();
        final updated = await permission.status;
        return updated.isGranted || updated.isLimited;

      default:
        return false;
    }
  }
}
''';
}
