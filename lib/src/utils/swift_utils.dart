/// Utility helpers for editing the iOS `AppDelegate.swift` file.
class SwiftUtils {
  SwiftUtils._();

  /// The conformance the UIScene-era `AppDelegate` declares (Flutter 3.41+):
  /// plugins register from its `didInitializeImplicitFlutterEngine`, after
  /// launch has finished.
  static const String implicitEngineDelegate = 'FlutterImplicitEngineDelegate';

  /// Ensures the `UNUserNotificationCenter` delegate assignment
  /// flutter_local_notifications needs is present, inside
  /// `application(_:didFinishLaunchingWithOptions:)` so it runs before launch
  /// finishes — which is when iOS hands over the notification that opened
  /// the app.
  ///
  /// Anchored on the `return super.application(...)` that closes that method
  /// in every Flutter template. The pre-UIScene template also registered the
  /// plugins there, so a project that lost the return line still gets the
  /// delegate above `GeneratedPluginRegistrant.register`. On the UIScene
  /// template that call moved to `didInitializeImplicitFlutterEngine`, which
  /// runs after launch — too late for the delegate — so the return line is
  /// tried first.
  ///
  /// Returns the content unchanged when `UNUserNotificationCenter` is already
  /// mentioned anywhere (the user wired it up themselves) or when neither
  /// anchor can be found (a customized AppDelegate is left alone rather than
  /// risk breaking it).
  static String ensureNotificationDelegate(String content) {
    if (content.contains('UNUserNotificationCenter')) return content;

    final lines = content.split('\n');
    var anchor = lines.indexWhere(
      (line) => line.contains('return super.application('),
    );
    if (anchor == -1) {
      anchor = lines.indexWhere(
        (line) => line.contains('GeneratedPluginRegistrant.register'),
      );
    }
    if (anchor == -1) return content;

    final indent = RegExp(r'^\s*').firstMatch(lines[anchor])!.group(0)!;
    lines.insertAll(anchor, [
      '$indent// Do not add a userNotificationCenter(_:didReceive:) override here',
      '$indent// without calling super: FlutterAppDelegate forwards notification taps',
      '$indent// to the plugins (flutter_local_notifications / firebase_messaging),',
      '$indent// and an override that skips super blocks them.',
      '${indent}if #available(iOS 10.0, *) {',
      '$indent  UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate',
      '$indent}',
    ]);
    return lines.join('\n');
  }

  /// Whether [content] already registers its plugins the UIScene way.
  static bool usesUIScene(String content) =>
      content.contains(implicitEngineDelegate);

  /// [content] moved to the UIScene lifecycle Xcode 27 requires: the class
  /// conforms to `FlutterImplicitEngineDelegate` and registers the plugins
  /// from `didInitializeImplicitFlutterEngine` instead of from
  /// `application(_:didFinishLaunchingWithOptions:)`.
  ///
  /// The Flutter CLI does this itself, but only for an `AppDelegate` that is
  /// byte-for-byte a stock template — and one `moarch init` has patched is
  /// not. This handles the shape that leaves: the stock class with lines
  /// added inside `didFinishLaunchingWithOptions`, which stay where they are.
  /// Returns [content] unchanged when it is already migrated, and null when
  /// it is not recognisably that shape, so the caller can hand over the
  /// manual steps instead of guessing at someone's Swift.
  static String? migrateToUIScene(String content) {
    if (usesUIScene(content)) return content;

    final declaration = RegExp(
      r'class AppDelegate\s*:\s*FlutterAppDelegate\s*\{',
    );
    final lines = content.split('\n');
    final classLine = lines.indexWhere(declaration.hasMatch);
    final registrant = lines.indexWhere(
      (line) => line.trim() == 'GeneratedPluginRegistrant.register(with: self)',
    );
    // The class's own closing brace: the last line holding only `}`.
    final classEnd = lines.lastIndexWhere((line) => line.trim() == '}');
    if (classLine == -1 || registrant == -1 || classEnd <= registrant) {
      return null;
    }

    final indent = RegExp(r'^\s*').firstMatch(lines[registrant])!.group(0)!;
    final method = indent.length >= 2
        ? indent.substring(0, indent.length - 2)
        : '';
    lines[classLine] = lines[classLine].replaceFirst(
      declaration,
      'class AppDelegate: FlutterAppDelegate, $implicitEngineDelegate {',
    );
    lines.removeAt(registrant);
    lines.insertAll(classEnd - 1, [
      '',
      '${method}func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {',
      '${indent}GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)',
      '$method}',
    ]);
    return lines.join('\n');
  }
}
