/// Services Template
class ServicesTemplates {
  ServicesTemplates._();

  /// Returns a language service scaffold.
  static String languageService() => '''
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final languageProvider = StateNotifierProvider<LanguageService, LanguageState>(
  (ref) => LanguageService(const LanguageState(locale: Locale('en'))),
);

class LanguageState {
  final Locale locale;
  const LanguageState({required this.locale});
}

class LanguageService extends StateNotifier<LanguageState> {
  LanguageService(super._state) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {}

  Future<void> changeLanguage(String languageCode) async {
    state = LanguageState(locale: Locale(languageCode));
  }
}

  ''';

  /// Returns a notification service scaffold.
  static String notificationsService() => r'''

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../core/utils/app_logger.dart';
import 'dart:io';

/// Android: add to android/app/src/main/AndroidManifest.xml inside <manifest>:
///   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
///   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
///   <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
///   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
///


/// iOS: add to ios/Runner/AppDelegate.swift:
///   UNUserNotificationCenter.current().delegate = self



// ─── Background handler (must be top-level) ──────────────────────────────────
@pragma('vm:entry-point')
void _backgroundHandler(NotificationResponse response) {
  appLogger.i(
    '[Notification] Background tap | id: ${response.id} | payload: ${response.payload}',
  );
}
 
// ─── Priority enum ────────────────────────────────────────────────────────────
enum NotificationPriority { defaultPriority, high }


class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  bool _initialized = false;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

        // ─── Notification Channel IDs ────────────────────────────────────────────
  static const String _defaultChannelId = 'default_channel';
  static const String _defaultChannelName = 'Default Notifications';
  static const String _defaultChannelDesc = 'General app notifications';
 
  static const String _scheduledChannelId = 'scheduled_channel';
  static const String _scheduledChannelName = 'Scheduled Notifications';
  static const String _scheduledChannelDesc = 'Reminders and scheduled alerts';
 
  static const String _highPriorityChannelId = 'high_priority_channel';
  static const String _highPriorityChannelName = 'High Priority';
  static const String _highPriorityChannelDesc = 'Urgent notifications';
 
  // ─── Notification IDs ────────────────────────────────────────────────────
  static const int defaultId = 0;
  static const int scheduledId = 1;
  static const int periodicId = 2;
 


  Future<void> init() async {
      if (_initialized) return;
 
 
    // Initialize timezone data
    tz.initializeTimeZones();
 
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher', // Make sure this icon exists
    );
 
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Request manually via requestPermissions()
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
        appLogger.i(
          '[Notification] Tapped | id: ${response.id} | payload: ${response.payload}',
        );
        // onTap
      },
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );
 
    await _createNotificationChannels();
 
    _initialized = true;
    appLogger.i('[NotificationService] Initialized');

    await requestPermissions();
  }

    /// Creates Android notification channels.
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

    /// Request notification permissions from the user.
  /// Returns true if granted, false otherwise.
  /// Call this at an appropriate moment (e.g. after onboarding).
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
    appLogger.i('[NotificationService] Shown (id: $id)');
  }
 
  // ===========================================================================
  // SCHEDULE
  // ===========================================================================
 
  /// Schedule a notification at an exact [scheduledDate].
  ///
  /// [timeZoneName] — IANA timezone name, e.g. 'Europe/Lisbon'.
  /// Defaults to the device's local timezone.
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

    appLogger.i('[NotificationService] Scheduled at $tzDate (id: $id)');
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
 
  /// Schedule a daily notification at a fixed [time].
 
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
  appLogger.i('[NotificationService] Daily scheduled at $hour:$minute (id: $id)');
}
 
  /// Schedule a weekly notification on a specific [day] and [time].
  ///

 
 
  // ===========================================================================
  // PERIODIC
  // ===========================================================================
 
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

    appLogger.i('[NotificationService] Periodic ($interval) started (id: $id)');
  }
 
  // ===========================================================================
  // CANCEL
  // ===========================================================================
 
  /// Cancel a specific notification by [id].
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
    appLogger.i('[NotificationService] Cancelled (id: $id)');
  }
 
  /// Cancel all pending and shown notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    appLogger.i('[NotificationService] Cancelled all');
  }
 
  // ===========================================================================
  // QUERY
  // ===========================================================================
 
  /// Returns all notifications that are pending (scheduled but not yet shown).
  Future<List<PendingNotificationRequest>> getPending() =>
      _plugin.pendingNotificationRequests();
 
  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================
 

 
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
 
 
 
  void _ensureInit() {
    if (!_initialized) {
      throw StateError(
        'NotificationService not initialized. '
        'Call NotificationService.instance.init() first.',
      );
    }
  }
}

''';

  /// Returns the generated mediaService template.
  static String mediaService() => r'''
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_service.dart';

/// A service to handle media selection (images, videos, files).

final mediaServiceProvider = Provider.autoDispose<MediaService>((ref) {
  final permissionService = ref.watch(permissionProvider);
  return MediaService(permissionService);
});

class MediaService {
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

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
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
  static String launchUrlService() => r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/security/validation_service.dart';

/// A service to handle URL launching operations.

final urlLauncherProvider = Provider.autoDispose<UrlLauncherService>((ref) {
  return UrlLauncherService();
});

class UrlLauncherService {
  UrlLauncherService();

  /// Launch a URL string.
  Future<void> launch(String url, {LaunchMode? mode}) async {
    final urlSanitized = ValidationService.validate(
      url,
      inputType: InputType.text,
    ).sanitizedValue;

    final uri = Uri.parse(urlSanitized);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: mode ?? LaunchMode.externalApplication);
      } else {
        // Fallback: try opening with a web view inside the app
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      }
    } catch (e) {
      // error feedback
    }
  }
}

  ''';

  /// Returns the generated connectivityService template.
  static String connectivityService() => r'''
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_logger.dart';

final connectivityProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final hasInternetProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityProvider);
  return connectivityService.hasInternetStream;
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get hasInternetStream =>
      _connectivity.onConnectivityChanged.map((results) {
        appLogger.d('[Connectivity] $results');
        return !results.contains(ConnectivityResult.none);
      });
  Future<bool> hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}

''';

  /// Returns the generated connectivityService template.
  static String debouncerService() => r'''
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final debouncerProvider = Provider<DebouncerService>((ref) {
  return DebouncerService();
});

class DebouncerService {
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

  /// Returns the generated connectivityService template.
  static String permissionService() => r'''
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final permissionProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class PermissionService {

  /// Request a specific permission.
  Future<bool> request({required Permission permission}) async {
    final status = await permission.status;

    switch (status) {
      case PermissionStatus.granted:
        return true;

      case PermissionStatus.denied:
        final response = await permission.request();
        return response.isGranted;

      case PermissionStatus.permanentlyDenied:
        await openAppSettings();
        // User navigated away and came back — re-check
        final updated = await permission.status;
        return updated.isGranted;

      default:
        return false;
    }
  }
}
''';
}
