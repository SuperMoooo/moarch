/// Services Template
class ServicesTemplates {
  ServicesTemplates._();

  /// Returns a simple notification service scaffold.
  static String notificationsService() => r'''
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService();
});

class NotificationsService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(settings);
  }

  Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'default_channel',
        'Notifications',
        importance: Importance.defaultImportance,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(0, title, body, details);
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
  static String launchUrlService() => r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_exception.dart';
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
import '../../core/utils/logger.dart';

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
        log(results.toString());
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
