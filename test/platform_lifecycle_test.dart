import 'dart:io';

import 'package:moarch/src/utils/plist_utils.dart';
import 'package:moarch/src/utils/project_inspector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _plist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>demo</string>
</dict>
</plist>
''';

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

const _gradle = '''
android {
    namespace = "dev.example.demo"
    compileSdk = flutter.compileSdkVersion
}
''';

void main() {
  group('PlistUtils.ensureSceneManifest', () {
    test(
      'adds the manifest Flutter writes, pointing at FlutterSceneDelegate',
      () {
        final out = PlistUtils.ensureSceneManifest(_plist);

        expect(out, contains('<key>UIApplicationSceneManifest</key>'));
        expect(out, contains('<string>FlutterSceneDelegate</string>'));
        expect(out, contains('<string>flutter</string>'));
        expect(
          out,
          contains(
            '<key>UISceneStoryboardFile</key>\n\t\t\t\t\t<string>Main</string>',
          ),
        );
        // Still well-formed: inside the top-level dict.
        expect(out, endsWith('\t</dict>\n</dict>\n</plist>\n'));
      },
    );

    test('leaves a project with its own scene delegate alone', () {
      const own = '\t<key>UIApplicationSceneManifest</key>\n\t<dict/>\n';
      final plist = _plist.replaceFirst('</dict>', '$own</dict>');
      expect(PlistUtils.ensureSceneManifest(plist), plist);
    });
  });

  group('doctor platform checks', () {
    late Directory tempDir;
    late String root;

    Future<void> write(String relative, String content) async {
      final file = File(p.joinAll([root, ...p.posix.split(relative)]));
      await file.create(recursive: true);
      await file.writeAsString(content);
    }

    String read(String relative) =>
        File(p.joinAll([root, ...p.posix.split(relative)])).readAsStringSync();

    Future<List<Diagnostic>> findings(String needle) async =>
        (await ProjectInspector.inspect(
          root,
        )).where((d) => d.message.contains(needle)).toList();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_lifecycle');
      root = tempDir.path;
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('moves a stock-shaped iOS project to the UIScene lifecycle', () async {
      await write('ios/Runner/Info.plist', _plist);
      await write('ios/Runner/AppDelegate.swift', _legacyAppDelegate);

      final found = await findings('UIScene lifecycle');
      expect(found, hasLength(1));
      expect(found.single.isFixable, isTrue);

      await found.single.fix!();

      expect(
        read('ios/Runner/Info.plist'),
        contains('<key>UIApplicationSceneManifest</key>'),
      );
      expect(
        read('ios/Runner/AppDelegate.swift'),
        contains('FlutterImplicitEngineDelegate'),
      );
      expect(await findings('UIScene lifecycle'), isEmpty);
    });

    test('hands over the manual steps for a customized AppDelegate', () async {
      await write('ios/Runner/Info.plist', _plist);
      await write(
        'ios/Runner/AppDelegate.swift',
        'class AppDelegate: FlutterAppDelegate { /* custom */ }\n',
      );

      final found = await findings('UIScene lifecycle');
      expect(found, hasLength(1));
      expect(found.single.isFixable, isFalse);
      expect(found.single.hint, contains('uiscenedelegate'));
    });

    test('floors compileSdk once a plugin needs API 37', () async {
      await write('android/app/build.gradle.kts', _gradle);
      await write('pubspec.yaml', 'name: demo\ndependencies:\n  dio: ^5.0.0\n');
      expect(await findings('compiles against the Flutter default'), isEmpty);

      await write(
        'pubspec.yaml',
        'name: demo\ndependencies:\n  permission_handler: ^13.0.2\n',
      );
      final found = await findings('compiles against the Flutter default');
      expect(found, hasLength(1));
      await found.single.fix!();
      expect(
        read('android/app/build.gradle.kts'),
        contains('compileSdk = maxOf(flutter.compileSdkVersion, 37)'),
      );
      expect(await findings('compiles against the Flutter default'), isEmpty);
    });

    test('copies .env.example when .env is missing', () async {
      await write('.env.example', 'BASE_URL=\n');

      final found = await findings('.env is missing');
      expect(found, hasLength(1));
      expect(found.single.hint, contains('.env.example'));
      await found.single.fix!();
      expect(read('.env'), 'BASE_URL=\n');
      expect(await findings('.env is missing'), isEmpty);
    });
  });
}
