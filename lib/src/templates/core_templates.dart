class CoreTemplates {
  CoreTemplates._();

  static String mainDart({bool withRouter = true}) {
    if (withRouter) {
      return r'''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
 import '../../core/utils/logger.dart';
import 'config/theme/app_theme.dart';


import 'config/router/app_router.dart';
 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  
  //::::::::::ERROR MANAGEMENT::::::::::
  PlatformDispatcher.instance.onError = (error, st) {
    log.e('[Uncaught error]', error: error, stackTrace: st);
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    log.e('[Flutter error]', error: details.exception, stackTrace: details.stack);
    if (kDebugMode) {
      // default behaviour — shows red screen in dev
      FlutterError.presentError(details);
    }
    // in prod: logged but no red screen, app continues
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception); // red screen in dev
    return const ErrorView(); // your nice screen in prod
  };

    //::::::::::ERROR MANAGEMENT::::::::::
  runApp(const ProviderScope(child: App()));


  runApp(const ProviderScope(child: App()));
}
 
class App extends ConsumerWidget {
  const App({super.key});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
 
    return MaterialApp.router(
      title: 'App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
  }
}
''';
    }

    return r'''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import 'config/theme/app_theme.dart';


 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  //::::::::::ERROR MANAGEMENT::::::::::
  PlatformDispatcher.instance.onError = (error, st) {
    log.e('[Uncaught error]', error: error, stackTrace: st);
    if (kDebugMode) return false; // false = let Flutter crash normally in dev
    return true; // true = swallow in prod, app stays alive
  };

  FlutterError.onError = (details) {
    log.e('[Flutter error]', error: details.exception, stackTrace: details.stack);
    if (kDebugMode) {
      // default behaviour — shows red screen in dev
      FlutterError.presentError(details);
    }
    // in prod: logged but no red screen, app continues
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception); // red screen in dev
    return const ErrorView(); // your nice screen in prod
  };

    //::::::::::ERROR MANAGEMENT::::::::::
  runApp(const ProviderScope(child: App()));

  runApp(const ProviderScope(child: App()));
}
 
class App extends StatelessWidget {
  const App({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
      // TODO: set your home widget
    );
  }
}
''';
  }

  static String appException({bool hasDio = true}) {
    final import = hasDio
        ? "import 'package:dio/dio.dart';"
        : "import 'package:cloud_firestore/cloud_firestore.dart';";
    final factory = hasDio
        ? r'''
  factory AppException.fromDioError(DioException dioError) {
    final message =
        dioError.response?.data?['message'] as String? ??
        dioError.message ??
        'Unknown error';
    final statusCode = dioError.response?.statusCode;
    log.e('[AppException] — $message', error: dioError);
    return AppException._(message: message, statusCode: statusCode);
  }'''
        : r'''
  factory AppException.fromFirebaseError(FirebaseException error) {
    log.e('[AppException] — $message', error: error.message);
    switch (error.code) {
      case "user-not-found":
        return const AppException(message: "Usuário não encontrado");
      case "wrong-password":
        return const AppException(message: "Senha incorreta");
      case "invalid-email":
        return const AppException(message: "Email inválido");
      case "email-already-in-use":
        return const AppException(message: "Email já cadastrado");
      case "weak-password":
        return const AppException(message: "Senha fraca");
      default:
        return AppException(message: error.message ?? "Erro desconhecido");
    }
  }''';

    return '''
$import
import '../../core/utils/logger.dart';

class AppException implements Exception {
  const AppException._({required this.message, this.statusCode});
  final String message;
  final int? statusCode;
  
  @override
  String toString() =>
      'AppException(message: \$message, statusCode: \$statusCode)';
  
  factory AppException.test() {
    return const AppException._(message: "Test exception", statusCode: 400);
  }

  factory AppException.fromMessage(String message) {
    return AppException._(message: message);
  }

$factory
}
''';
  }

  static String logger() => r'''
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // no stack trace on normal logs
    errorMethodCount: 8, // stack trace on errors
    colors: true,
    printEmojis: true,
  ),
  // automatically silent in release mode
  level: kReleaseMode ? Level.off : Level.trace,
);

''';

  static String extensions() => r'''
import 'package:flutter/material.dart';


extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
}

extension StringX on String {
  bool get isValidEmail =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);

  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  dynamic toColor() {
    var hexColor = replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    if (hexColor.length == 8) {
      return int.parse('0x$hexColor');
    }
    return null;
  }
}

extension DateTimeX on DateTime {
  String get formattedDate => '$day/$month/$year';
  String get formattedTime => '$hour:$minute';
  String get formattedDateTime => '$formattedDate $formattedTime';

  bool get isToday {
    final now = DateTime.now();
    return day == now.day && month == now.month && year == now.year;
  }

   bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

   String timeAgo() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'just now';
    }
  }
}

extension TimeOfDayX on TimeOfDay {
  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
''';

  // Material & Cupertino guidelines:
  // Spacing: 4pt grid (4, 8, 12, 16, 24, 32, 48)
  // Text: iOS SF / Material type scale — body 17, callout 16, subhead 15, footnote 13, caption 12
  // Touch targets: min 44pt (iOS HIG) / 48dp (Material)
  // Border radius: iOS uses 10-13 for cards, Material uses 12 (medium)
  static String appConstants() => r'''
import 'package:flutter/material.dart';

abstract final class AppConstants {
 // ── Palette ─────────────────────────────────────────────────
static const Color primary   = Color(0xFF000000);
static const Color secondary = Color(0xFF000000);
static const Color tertiary  = Color(0xFF000000);
static const Color surface   = Color(0xFF000000);
static const Color onSurface = Color(0xFF000000);
static const Color outline   = Color(0xFF000000);

// ── Accent tokens ────────────────────────────────────────────
static const Color accentActive      = Color(0xFF000000);
static const Color accentRestorative = Color(0xFF000000);
static const Color accentEnergetic   = Color(0xFF000000);

// ── Surface layers (tonal depth — no borders) ───────────────
static const Color surfaceContainerLowest  = Color(0xFF000000);
static const Color surfaceContainerLow     = Color(0xFF000000);
static const Color surfaceContainerHighest = Color(0xFF000000);


  // ── Spacing — 4pt grid ────────────────────────────────────────────────────
  static const double space4  = 4;
  static const double space8  = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ── Padding helpers ───────────────────────────────────────────────────────
  static const padding4  = EdgeInsets.all(space4);
  static const padding8  = EdgeInsets.all(space8);
  static const padding12 = EdgeInsets.all(space12);
  static const padding16 = EdgeInsets.all(space16);
  static const padding24 = EdgeInsets.all(space24);

  static const paddingH16 = EdgeInsets.symmetric(horizontal: space16);
  static const paddingH24 = EdgeInsets.symmetric(horizontal: space24);
  static const paddingV8  = EdgeInsets.symmetric(vertical: space8);
  static const paddingV16 = EdgeInsets.symmetric(vertical: space16);

  // common page inset (Material: 16dp sides, iOS: 16-20pt sides)
  static const paddingPage = EdgeInsets.symmetric(
    horizontal: space16,
    vertical: space16,
  );

  // ── Text sizes — Material type scale / iOS HIG ────────────────────────────
  // iOS: largeTitle 34, title1 28, title2 22, title3 20, headline 17,
  //      body 17, callout 16, subheadline 15, footnote 13, caption1/2 12/11
  // Material: displayL 57, displayM 45, displayS 36, headlineL 32,
  //           headlineM 28, headlineS 24, titleL 22, titleM 16, titleS 14,
  //           bodyL 16, bodyM 14, bodyS 12, labelL 14, labelM 12, labelS 11
  static const double fontSize11 = 11; // caption2 / label small
  static const double fontSize12 = 12; // caption1 / body small
  static const double fontSize13 = 13; // footnote
  static const double fontSize14 = 14; // label / body medium (Material)
  static const double fontSize15 = 15; // subheadline
  static const double fontSize16 = 16; // callout / body large
  static const double fontSize17 = 17; // body / headline (iOS default)
  static const double fontSize20 = 20; // title3
  static const double fontSize22 = 22; // title2 / titleL
  static const double fontSize28 = 28; // title1 / headlineM
  static const double fontSize34 = 34; // largeTitle (iOS)

  // ── Touch targets ─────────────────────────────────────────────────────────
  // iOS HIG: 44pt minimum, Material: 48dp minimum
  static const double touchTarget = 48;

  // ── Border radius — Material medium = 12, iOS cards ≈ 10–13 ──────────────
  static const double radius4  = 4;
  static const double radius8  = 8;
  static const double radius12 = 12; // Material medium / iOS card
  static const double radius16 = 16; // Material large
  static const double radius24 = 24; // bottom sheets, large cards
  static const double radiusFull = 999; // pills / chips

  static final borderRadius4    = BorderRadius.circular(radius4);
  static final borderRadius8    = BorderRadius.circular(radius8);
  static final borderRadius12   = BorderRadius.circular(radius12);
  static final borderRadius16   = BorderRadius.circular(radius16);
  static final borderRadius24   = BorderRadius.circular(radius24);
  static final borderRadiusFull = BorderRadius.circular(radiusFull);

  // ── Animation durations ───────────────────────────────────────────────────
  // Material motion: 100ms micro, 200ms simple, 300ms complex, 500ms dramatic
  static const Duration duration100 = Duration(milliseconds: 100);
  static const Duration duration200 = Duration(milliseconds: 200);
  static const Duration duration300 = Duration(milliseconds: 300);
  static const Duration duration500 = Duration(milliseconds: 500);
}
''';

  static String apiConstants() => r'''
abstract final class ApiConstants {
  // BASE_URL comes from envied
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
''';

  static String dioClient() => r'''
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env/app_env.dart';
import '../constants/api_constants.dart';
import '../security/secure_storage.dart';
import '../utils/logger.dart';

final dioClientProvider = Provider<Dio>((ref) => buildDioClient(ref));

// ─────────────────────────────────────────────────────────────────────────────

Dio buildDioClient(Ref ref) {
  final storage = ref.watch(secureStorageProvider);

  final dio =
      Dio(
          BaseOptions(
            baseUrl: AppEnv.baseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            // Status that pass: 200-299, all the other will be caught in DioException
            validateStatus: (status) {
              return status != null && status >= 200 && status < 300;
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await storage.read(key: 'token');
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
          ),
        )
        ..interceptors.add(
          LogInterceptor(requestBody: true,
           responseBody: true, 
          logPrint: (o) => log.d(o.toString()),
          ),
        );

  return dio;
}

''';

  static String secureStorage() => r'''
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => FlutterSecureStorage());



''';

  static String mediaService() => r'''
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A service to handle media selection (images, videos, files).

final mediaServiceProvider = Provider.autoDispose<MediaService>((ref) {
  return MediaService.instance;
});

class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  final ImagePicker _imagePicker = ImagePicker();

  /// Pick an image from gallery or camera.
  Future<File?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    // Check permissions
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw AppException.fromMessage('Camera permission denied');
      }
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted && !status.isLimited) {
          throw AppException.fromMessage('Photos permission denied');
        }
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
  Future<List<File>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.photos.request();
      if (!status.isGranted && !status.isLimited) {
        throw AppException.fromMessage('Photos permission denied');
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
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw AppException.fromMessage('Camera permission denied');
      }
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted && !status.isLimited) {
          throw AppException.fromMessage('Photos permission denied');
        }
      }
    }

    final XFile? file = await _imagePicker.pickVideo(
      source: source,
      maxDuration: maxDuration,
    );

    return file != null ? File(file.path) : null;
  }

  /// Pick one or more files from the device.
  Future<List<File>> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // Note: On Android 13+, storage permission might be handled differently (media-specific)
        // but permission_handler usually handles the abstraction.
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

  static String launchUrlService() => r'''
  
  import 'dart:io';
import '../../../../core/errors/app_exception.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A service to handle URL launching operations.

final urlLauncherProvider = Provider.autoDispose<UrlLauncherService>((ref) {
  return UrlLauncherService.instance;
});

class UrlLauncherService {
  UrlLauncherService._();
  static final UrlLauncherService instance = UrlLauncherService._();

  /// Launch a URL string.
  Future<void> launch(String url, {LaunchMode? mode}) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: mode ?? LaunchMode.externalApplication);
    } else {
      throw AppException.fromMessage('Could not launch url');
    }
  }
}
  ''';

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

  static String validationService() => r'''
import '../../core/errors/app_exception.dart';
  
  /// Enum com tipos de input para validação
enum InputType {
  email,
  url,
  phone,
  password,
  username,
  text, // generic text
  number,
  creditCard,
}


/// Resultado da validação
class ValidationResult {
  final bool isValid;
  final String? error;
  final String sanitizedValue;

  ValidationResult({
    required this.isValid,
    this.error,
    required this.sanitizedValue,
  });

  factory ValidationResult.valid(String sanitized) =>
      ValidationResult(isValid: true, sanitizedValue: sanitized);

  factory ValidationResult.invalid(String error, String original) {
    throw AppException.fromMessage(error);
  }
      
}

/// Validador principal
class ValidationService {
  // Regex patterns
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&\'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );

  static final _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  static final _phoneRegex = RegExp(r'^[+]?[(]?[0-9]{3}[)]?[-\s.]?[0-9]{3}[-\s.]?[0-9]{4,6}$');
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_-]{3,20}$');
  static final _numberRegex = RegExp(r'^-?\d+\.?\d*$');

  // SQL Injection Patterns
  static final _sqlInjectionPatterns = [
    RegExp(r"('|(\\x27))+|(--)|;|(\*|union|select|insert|update|delete|drop|create|alter)", caseSensitive: false),
  ];

  static final _xssPatterns = [
    RegExp(r'<script|javascript:|onerror=|onload=|onclick=|<iframe', caseSensitive: false),
  ];

  static final _pathTraversalPatterns = [
    RegExp(r'\.\./|\.\.\\|%2e%2e'),
  ];

  static ValidationResult validate(
    String value, {
    required InputType inputType,
    int minLength = 1,
    int maxLength = 1000,
    bool trimWhitespace = true,
    bool toLowerCase = false,
  }) {
    // Trim 
    var processed = trimWhitespace ? value.trim() : value;

    if (toLowerCase) {
      processed = processed.toLowerCase();
    }

    // length
    if (processed.isEmpty && minLength > 0) {
      return ValidationResult.invalid(
        '${inputType.name} não pode estar vazio',
        value,
      );
    }

    if (processed.length < minLength) {
      return ValidationResult.invalid(
        '${inputType.name} deve ter no mínimo $minLength caracteres',
        value,
      );
    }

    if (processed.length > maxLength) {
      return ValidationResult.invalid(
        '${inputType.name} pode ter no máximo $maxLength caracteres',
        value,
      );
    }

    // type validation
    if (inputType != InputType.text) {
      final typeValidation = _validateByType(processed, inputType);
      if (!typeValidation.isValid) {
        return typeValidation;
      }
    }

    // security validation. all types
    final securityCheck = _validateSecurity(processed, inputType);
    if (!securityCheck.isValid) {
      return securityCheck;
    }

    // final sanitization
    final sanitized = _sanitize(processed, inputType);

    return ValidationResult.valid(sanitized);
  }

  /// Validation by type
  static ValidationResult _validateByType(String value, InputType type) {
    switch (type) {
      case InputType.email:
        if (!_emailRegex.hasMatch(value)) {
          return ValidationResult.invalid('Invalid email', value);
        }
        break;

      case InputType.url:
        if (!_urlRegex.hasMatch(value)) {
          return ValidationResult.invalid('Invalid URL', value);
        }
        break;

      case InputType.phone:
        final cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');
        if (!_phoneRegex.hasMatch(cleaned)) {
          return ValidationResult.invalid('Invalid phone number', value);
        }
        break;

      case InputType.username:
        if (!_usernameRegex.hasMatch(value)) {
          return ValidationResult.invalid(
            'Invalid username (3-20 characters, only letters, numbers, -, _)',
            value,
          );
        }
        break;

      case InputType.password:
        if (value.length < 6) {
          return ValidationResult.invalid('Password must have at least 6 characters', value);
        }
        // Força da password
        bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
        bool hasLowercase = value.contains(RegExp(r'[a-z]'));
        bool hasNumbers = value.contains(RegExp(r'[0-9]'));
        bool hasSpecial = value.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:\'",.<>?]'));

        int strength = [hasUppercase, hasLowercase, hasNumbers, hasSpecial]
            .where((e) => e)
            .length;

        if (strength < 3) {
          return ValidationResult.invalid(
            'Password too weak: needs uppercase, lowercase, numbers and special characters',
            value,
          );
        }
        break;

      case InputType.number:
        if (!_numberRegex.hasMatch(value)) {
          return ValidationResult.invalid('Invalid number', value);
        }
        break;

      case InputType.creditCard:
        final cleaned = value.replaceAll(RegExp(r'\s'), '');
        if (!RegExp(r'^\d{13,19}$').hasMatch(cleaned)) {
          return ValidationResult.invalid('Invalid credit card number', value);
        }
        // Luhn algorithm
        if (!_luhnCheck(cleaned)) {
          return ValidationResult.invalid('Invalid credit card number (Luhn)', value);
        }
        break;

      case InputType.text:
        // no validation
        break;
    }

    return ValidationResult.valid(value);
  }

  /// Security validation (XSS, SQL Injection, Path Traversal)
  static ValidationResult _validateSecurity(String value, InputType type) {
    // SQL Injection 
    if (type == InputType.text || type == InputType.username) {
      for (var pattern in _sqlInjectionPatterns) {
        if (pattern.hasMatch(value)) {
          return ValidationResult.invalid('Input contains suspicious characters (SQL)', value);
        }
      }
    }

    // XSS 
    if (type == InputType.text) {
      for (var pattern in _xssPatterns) {
        if (pattern.hasMatch(value)) {
          return ValidationResult.invalid('Input contains suspicious scripts (XSS)', value);
        }
      }
    }

    // Path Traversal (paths/filenames)
    for (var pattern in _pathTraversalPatterns) {
      if (pattern.hasMatch(value)) {
        return ValidationResult.invalid('Input contains suspicious path traversal', value);
      }
    }

    // null chars
    if (value.contains('\x00')) {
      return ValidationResult.invalid('Input contains null characters', value);
    }

    return ValidationResult.valid(value);
  }

  /// Sanitization: remove/escape dangerous characters
  static String _sanitize(String value, InputType type) {
    var sanitized = value;

    // Remove dangerous control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // For email and URL, remove extra whitespace
    if (type == InputType.email || type == InputType.url) {
      sanitized = sanitized.replaceAll(RegExp(r'\s'), '');
    }

    // For phone, remove everything except digits, +, -, (, ), space
    if (type == InputType.phone) {
      sanitized = sanitized.replaceAll(RegExp(r'[^\d+\-() ]'), '');
    }

    // For username, only allow a-z, 0-9, -, _
    if (type == InputType.username) {
      sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    }

    // For number, only allow digits, -, .
    if (type == InputType.number) {
      sanitized = sanitized.replaceAll(RegExp(r'[^\d\-.]'), '');
    }

    // HTML encode for generic text
    if (type == InputType.text) {
      sanitized = _htmlEncode(sanitized);
    }

    return sanitized;
  }

  /// Luhn algorithm for validating credit card numbers
  static bool _luhnCheck(String cardNumber) {
    int sum = 0;
    bool isEven = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);

      if (isEven) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      isEven = !isEven;
    }

    return sum % 10 == 0;
  }

  /// Basic HTML encoding
  static String _htmlEncode(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// Validate multiple inputs at once
  static Map<String, ValidationResult> validateMultiple(
    Map<String, String> inputs,
    Map<String, InputType> types, {
    Map<String, int> minLengths = const {},
    Map<String, int> maxLengths = const {},
  }) {
    final results = <String, ValidationResult>{};

    for (final entry in inputs.entries) {
      final key = entry.key;
      final value = entry.value;
      final type = types[key];

      if (type == null) {
        results[key] = ValidationResult.invalid('Tipo de validação não definido', value);
        continue;
      }

      results[key] = validate(
        value,
        inputType: type,
        minLength: minLengths[key] ?? 1,
        maxLength: maxLengths[key] ?? 1000,
      );
    }

    return results;
  }
}''';
}
