import 'package:moarch/src/utils/swift_utils.dart';
import 'package:test/test.dart';

/// `flutter create` before 3.41: plugins registered on launch.
const _legacyAppDelegate = '''
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
''';

/// `flutter create` from 3.41 on: the UIScene lifecycle, plugins registered
/// once the engine is up — after launch has finished.
const _sceneAppDelegate = '''
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
''';

void main() {
  group('ensureNotificationDelegate', () {
    test('lands before launch finishes on the UIScene template', () {
      final output = SwiftUtils.ensureNotificationDelegate(_sceneAppDelegate);

      expect(output, contains('UNUserNotificationCenter.current().delegate'));
      // Inside didFinishLaunchingWithOptions, not in the engine callback that
      // runs after launch: iOS hands over the opening notification at launch.
      expect(
        output.indexOf('UNUserNotificationCenter'),
        lessThan(output.indexOf('return super.application(')),
      );
      expect(
        output.indexOf('UNUserNotificationCenter'),
        lessThan(output.indexOf('didInitializeImplicitFlutterEngine')),
      );
      expect(output, contains('    if #available(iOS 10.0, *) {'));
      // Warning against re-adding a tap-blocking override travels with the code.
      expect(
        output,
        contains('userNotificationCenter(_:didReceive:) override'),
      );
    });

    test('lands inside didFinishLaunchingWithOptions on the old one too', () {
      final output = SwiftUtils.ensureNotificationDelegate(_legacyAppDelegate);

      expect(
        output.indexOf('UNUserNotificationCenter'),
        lessThan(output.indexOf('return super.application(')),
      );
    });

    test('falls back to the registrant call without a return line', () {
      const trimmed = '''
class AppDelegate: FlutterAppDelegate {
  override func application(_ application: UIApplication) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
  }
}
''';
      final output = SwiftUtils.ensureNotificationDelegate(trimmed);

      expect(
        output.indexOf('UNUserNotificationCenter'),
        lessThan(output.indexOf('GeneratedPluginRegistrant.register')),
      );
    });

    test('is idempotent', () {
      final once = SwiftUtils.ensureNotificationDelegate(_sceneAppDelegate);

      expect(SwiftUtils.ensureNotificationDelegate(once), equals(once));
    });

    test('leaves a customized delegate alone', () {
      const custom = '''
class AppDelegate: FlutterAppDelegate {
  // user wired it manually
  // UNUserNotificationCenter.current().delegate = self
}
''';

      expect(SwiftUtils.ensureNotificationDelegate(custom), equals(custom));
    });

    test('skips files without an anchor', () {
      const noAnchor = 'class AppDelegate {}\n';

      expect(SwiftUtils.ensureNotificationDelegate(noAnchor), equals(noAnchor));
    });
  });

  group('migrateToUIScene', () {
    test('moves plugin registration to the engine callback', () {
      final output = SwiftUtils.migrateToUIScene(_legacyAppDelegate);

      expect(output, equals(_sceneAppDelegate));
    });

    test('keeps what moarch added to didFinishLaunchingWithOptions', () {
      final patched = SwiftUtils.ensureNotificationDelegate(_legacyAppDelegate);
      final output = SwiftUtils.migrateToUIScene(patched)!;

      expect(
        output,
        contains('FlutterAppDelegate, FlutterImplicitEngineDelegate'),
      );
      expect(output, isNot(contains('register(with: self)')));
      expect(
        output,
        contains(
          'GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)',
        ),
      );
      // The delegate line stayed in the launch method, above the return.
      expect(
        output.indexOf('UNUserNotificationCenter'),
        lessThan(output.indexOf('return super.application(')),
      );
      expect(SwiftUtils.usesUIScene(output), isTrue);
    });

    test('returns a migrated file unchanged', () {
      expect(
        SwiftUtils.migrateToUIScene(_sceneAppDelegate),
        equals(_sceneAppDelegate),
      );
    });

    test('refuses a shape it does not recognise', () {
      const custom = '''
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterPluginRegistrant {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    pluginRegistrant = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
''';

      expect(SwiftUtils.migrateToUIScene(custom), isNull);
    });
  });
}
