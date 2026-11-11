import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/package_name_command.dart';
import 'package:moarch/src/utils/app_id_utils.dart';
import 'package:moarch/src/utils/project_inspector.dart';
import 'package:moarch/src/utils/project_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _mainActivity =
    'android/app/src/main/kotlin/com/example/my_app/'
    'MainActivity.kt';

/// What `flutter create my_app` writes where the id appears, plus the moarch
/// and third-party files around it that a rename must or must not touch.
const _project = <String, String>{
  'pubspec.yaml': 'name: my_app\n',
  'android/app/build.gradle.kts': '''
android {
    namespace = "com.example.my_app"
    defaultConfig {
        applicationId = "com.example.my_app"
    }
    productFlavors {
        create("dev") { applicationId = "com.example.my_app.dev" }
    }
}
''',
  _mainActivity: '''
package com.example.my_app

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
''',
  'android/app/src/main/kotlin/com/example/my_app/widgets/Glance.kt':
      'package com.example.my_app.widgets\n',
  'android/app/src/debug/kotlin/com/example/my_app/DebugTools.kt':
      'package com.example.my_app\n',
  'android/app/src/main/AndroidManifest.xml':
      '<activity android:name=".MainActivity" />\n',
  'ios/Runner.xcodeproj/project.pbxproj': '''
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.myApp.RunnerTests;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.myApp;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "\$(BUNDLE_ID)";
''',
  'ios/Runner/Runner.entitlements':
      '<string>\$(AppIdentifierPrefix)com.example.myApp</string>\n',
  'macos/Runner/Configs/AppInfo.xcconfig': '''
PRODUCT_NAME = my_app
PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp
PRODUCT_COPYRIGHT = Copyright © 2026 com.example. All rights reserved.
''',
  'windows/runner/Runner.rc': '''
            VALUE "CompanyName", "com.example" "\\0"
            VALUE "LegalCopyright", "Copyright (C) 2026 com.example. All rights reserved." "\\0"
''',
  'linux/CMakeLists.txt': 'set(APPLICATION_ID "com.example.my_app")\n',
  'flavorizr.yaml': '''
flavors:
  dev:
    android:
      applicationId: "com.example.my_app.dev"
    ios:
      bundleId: "com.example.myApp.dev"
''',
  'docs/DEEP_LINKS.md': '''
"package_name": "com.example.my_app"
"appIDs": ["<TEAM_ID>.com.example.myApp"]
''',
  // Not this app: a longer last segment is another id.
  'lib/other.dart': "const other = 'com.example.my_app2';\n",
  // Firebase's, per registered app: reported, not rewritten.
  'android/app/google-services.json': '"package_name": "com.example.my_app"\n',
  // The SDK checkout `.fvm/flutter_sdk` links to, and build output.
  '.fvm/flutter_sdk/template.kt': 'package com.example.my_app\n',
  'build/app/intermediates/x.xml': 'com.example.my_app\n',
};

void main() {
  late Directory dir;

  File file(String relative) => File(p.join(dir.path, relative));
  String read(String relative) => file(relative).readAsStringSync();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('moarch_package_name_test');
    _project.forEach((path, content) {
      file(path)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    });
  });

  tearDown(() async => dir.delete(recursive: true));

  group('AppIdUtils.rename', () {
    const ids = {'com.example.my_app': 'com.acme.shop'};

    test('keeps a suffix, refuses a longer segment', () {
      expect(
        AppIdUtils.rename(
          'com.example.my_app com.example.my_app.dev com.example.my_app2 '
          'xcom.example.my_app',
          ids,
        ),
        'com.acme.shop com.acme.shop.dev com.example.my_app2 '
        'xcom.example.my_app',
      );
    });

    test('renames in one pass, so a new id holding the old is not doubled', () {
      expect(
        AppIdUtils.rename('com.acme.shop', {
          'com.acme.shop': 'com.acme.shop.pro',
        }),
        'com.acme.shop.pro',
      );
    });

    test('an organization only where it stands alone', () {
      expect(
        AppIdUtils.rename(
          '"com.example" © com.example. All rights. com.example.other',
          const {},
          orgs: {'com.example': 'com.acme'},
        ),
        '"com.acme" © com.acme. All rights. com.example.other',
      );
    });

    test('backquotes a Kotlin keyword in package and import lines only', () {
      expect(
        AppIdUtils.rename(
          'package com.example.my_app\n'
          'import com.example.my_app.R\n'
          'val id = "com.example.my_app"\n',
          {'com.example.my_app': 'in.acme.shop'},
          kotlin: true,
        ),
        'package `in`.acme.shop\n'
        'import `in`.acme.shop.R\n'
        'val id = "in.acme.shop"\n',
      );
    });
  });

  group('AppIdUtils ids', () {
    test('refuses what Android cannot build', () {
      expect(AppIdUtils.androidIdProblem('com.acme.shop'), isNull);
      expect(AppIdUtils.androidIdProblem('in.acme.my_shop'), isNull);
      expect(AppIdUtils.androidIdProblem('shop'), contains('one segment'));
      expect(AppIdUtils.androidIdProblem('com.1acme.shop'), contains('1acme'));
      expect(AppIdUtils.androidIdProblem('com.acme-co.shop'), isNotNull);
      expect(AppIdUtils.androidIdProblem('com.new.shop'), contains('keyword'));
    });

    test('the bundle id camel-cases what Apple cannot hold', () {
      expect(AppIdUtils.appleIdFor('com.acme.shop'), 'com.acme.shop');
      expect(AppIdUtils.appleIdFor('com.acme_co.my_shop'), 'com.acmeCo.myShop');
      expect(AppIdUtils.appleIdProblem('com.acme.my-shop'), isNull);
      expect(AppIdUtils.appleIdProblem('com.acme.my_shop'), isNotNull);
    });

    test('reads the base ids, not the flavors or the test bundle', () {
      final ids = AppIdUtils.detect(dir.path);
      expect(ids.applicationId, 'com.example.my_app');
      expect(ids.namespace, 'com.example.my_app');
      expect(ids.kotlinPackage, 'com.example.my_app');
      expect(ids.iosBundleId, 'com.example.myApp');
      expect(ids.macosBundleId, 'com.example.myApp');
    });
  });

  group('package-name', () {
    late CommandRunner<int> runner;

    setUp(() {
      runner = CommandRunner<int>('moarch', 'test')
        ..addCommand(PackageNameCommand(logger: Logger(level: Level.quiet)));
    });

    Future<int?> run(List<String> args) =>
        runner.run(['package-name', ...args, '--path', dir.path]);

    test('renames every mention on every platform', () async {
      expect(await run(['com.acme.shop']), 0);

      expect(read('android/app/build.gradle.kts'), '''
android {
    namespace = "com.acme.shop"
    defaultConfig {
        applicationId = "com.acme.shop"
    }
    productFlavors {
        create("dev") { applicationId = "com.acme.shop.dev" }
    }
}
''');
      expect(
        read('ios/Runner.xcodeproj/project.pbxproj'),
        allOf(
          contains('= com.acme.shop.RunnerTests;'),
          contains('= com.acme.shop;'),
          contains(r'"$(BUNDLE_ID)"'),
        ),
      );
      expect(
        read('ios/Runner/Runner.entitlements'),
        contains(r'$(AppIdentifierPrefix)com.acme.shop<'),
      );
      expect(
        read('macos/Runner/Configs/AppInfo.xcconfig'),
        allOf(
          contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.shop\n'),
          contains('© 2026 com.acme. All rights'),
        ),
      );
      expect(
        read('windows/runner/Runner.rc'),
        allOf(contains('"com.acme" "'), contains('2026 com.acme. All')),
      );
      expect(read('linux/CMakeLists.txt'), contains('"com.acme.shop"'));
      expect(
        read('flavorizr.yaml'),
        allOf(contains('"com.acme.shop.dev"'), isNot(contains('example'))),
      );
      expect(
        read('docs/DEEP_LINKS.md'),
        allOf(
          contains('"package_name": "com.acme.shop"'),
          contains('"<TEAM_ID>.com.acme.shop"'),
        ),
      );
      expect(read('lib/other.dart'), contains('com.example.my_app2'));
    });

    test(
      'moves MainActivity and every source set to the new package',
      () async {
        expect(await run(['com.acme.shop']), 0);

        const kotlin = 'android/app/src/main/kotlin';
        expect(file(_mainActivity).existsSync(), isFalse);
        expect(
          read('$kotlin/com/acme/shop/MainActivity.kt'),
          startsWith('package com.acme.shop\n'),
        );
        expect(
          read('$kotlin/com/acme/shop/widgets/Glance.kt'),
          'package com.acme.shop.widgets\n',
        );
        expect(
          read('android/app/src/debug/kotlin/com/acme/shop/DebugTools.kt'),
          'package com.acme.shop\n',
        );
        // The emptied folders go, up to the source root.
        expect(
          Directory(p.join(dir.path, kotlin, 'com', 'example')).existsSync(),
          isFalse,
        );
        expect(Directory(p.join(dir.path, kotlin, 'com')).existsSync(), isTrue);
      },
    );

    test('leaves Firebase configs, the SDK and build output alone', () async {
      expect(await run(['com.acme.shop']), 0);
      expect(
        read('android/app/google-services.json'),
        contains('com.example.my_app'),
      );
      expect(read('.fvm/flutter_sdk/template.kt'), contains('com.example'));
      expect(read('build/app/intermediates/x.xml'), contains('com.example'));
    });

    test('a separate iOS id goes only to the Apple side', () async {
      expect(
        await run(['com.acme.shop', '--ios-bundle-id', 'com.acme.Shop']),
        0,
      );
      expect(
        read('ios/Runner.xcodeproj/project.pbxproj'),
        contains('= com.acme.Shop;'),
      );
      expect(read('linux/CMakeLists.txt'), contains('"com.acme.shop"'));
      expect(
        read('docs/DEEP_LINKS.md'),
        allOf(contains('"com.acme.shop"'), contains('.com.acme.Shop"')),
      );
    });

    test('a file the manifest vouched for stays moarch\'s own', () async {
      final manifest = ProjectManifest.loadOrCreate(dir.path)
        ..record(
          dir.path,
          p.join(dir.path, 'docs/DEEP_LINKS.md'),
          read('docs/DEEP_LINKS.md'),
        )
        ..record(dir.path, p.join(dir.path, 'flavorizr.yaml'), 'edited since');
      await manifest.save(dir.path);

      expect(await run(['com.acme.shop']), 0);

      final after = ProjectManifest.load(dir.path)!;
      expect(
        after.recordedHash(dir.path, file('docs/DEEP_LINKS.md').path),
        ProjectManifest.hashContent(read('docs/DEEP_LINKS.md')),
      );
      // An edited file stays edited: its record is not moved to new content.
      expect(
        after.recordedHash(dir.path, file('flavorizr.yaml').path),
        ProjectManifest.hashContent('edited since'),
      );
    });

    test('a dry run writes nothing', () async {
      expect(await run(['com.acme.shop', '--dry-run']), 0);
      expect(file(_mainActivity).existsSync(), isTrue);
      expect(read('android/app/build.gradle.kts'), contains('com.example'));
    });

    test('refuses an invalid id before touching anything', () async {
      expect(await run(['com.new.shop']), 64);
      expect(await run(['shop']), 64);
      expect(await run([]), 64);
      expect(read('android/app/build.gradle.kts'), contains('com.example'));
    });

    test('a second run has nothing to do', () async {
      expect(await run(['com.acme.shop']), 0);
      final plan = AppIdUtils.plan(
        dir.path,
        androidId: 'com.acme.shop',
        appleId: 'com.acme.shop',
      );
      expect(plan.isEmpty, isTrue);
      expect(await run(['com.acme.shop']), 0);
    });

    test('a file already in the new package stops the run', () async {
      file('android/app/src/main/kotlin/com/acme/shop/MainActivity.kt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('package com.acme.shop\n');
      expect(await run(['com.acme.shop']), 1);
      expect(read('android/app/build.gradle.kts'), contains('com.example'));
      expect(file(_mainActivity).existsSync(), isTrue);
    });
  });

  group('doctor', () {
    test('notes the placeholder id, and stops once it is gone', () async {
      bool notes(List<Diagnostic> findings) => findings.any(
        (f) =>
            f.severity == DiagnosticSeverity.info &&
            f.message.contains('com.example'),
      );

      expect(notes(await ProjectInspector.inspect(dir.path)), isTrue);
      await AppIdUtils.apply(
        dir.path,
        AppIdUtils.plan(
          dir.path,
          androidId: 'com.acme.shop',
          appleId: 'com.acme.shop',
        ),
      );
      expect(notes(await ProjectInspector.inspect(dir.path)), isFalse);
    });
  });
}
