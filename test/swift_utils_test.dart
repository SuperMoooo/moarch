import 'package:moarch/src/utils/swift_utils.dart';
import 'package:test/test.dart';

const _defaultAppDelegate = '''
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

void main() {
  test('ensureNotificationDelegate inserts before the registrant call', () {
    final output = SwiftUtils.ensureNotificationDelegate(_defaultAppDelegate);

    expect(output, contains('UNUserNotificationCenter.current().delegate'));
    expect(output, contains('if #available(iOS 10.0, *) {'));
    // Inserted before plugin registration, matching its indentation.
    expect(
      output.indexOf('UNUserNotificationCenter'),
      lessThan(output.indexOf('GeneratedPluginRegistrant.register')),
    );
    expect(output, contains('    if #available(iOS 10.0, *) {'));
  });

  test('ensureNotificationDelegate is idempotent', () {
    final once = SwiftUtils.ensureNotificationDelegate(_defaultAppDelegate);

    expect(SwiftUtils.ensureNotificationDelegate(once), equals(once));
  });

  test('ensureNotificationDelegate leaves a customized delegate alone', () {
    const custom = '''
class AppDelegate: FlutterAppDelegate {
  // user wired it manually
  // UNUserNotificationCenter.current().delegate = self
}
''';

    expect(SwiftUtils.ensureNotificationDelegate(custom), equals(custom));
  });

  test('ensureNotificationDelegate skips files without the anchor', () {
    const noAnchor = 'class AppDelegate {}\n';

    expect(SwiftUtils.ensureNotificationDelegate(noAnchor), equals(noAnchor));
  });
}
