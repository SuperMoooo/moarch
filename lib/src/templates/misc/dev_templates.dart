/// Dev Template
class DevTemplates {
  DevTemplates._();

  /// Analysis options for better performance and security.
  ///
  /// Note: `strong-mode: implicit-dynamic` is deliberately absent — the option
  /// was removed from the analyzer and is now reported as an unsupported key.
  /// `strict-raw-types` covers the same ground and is still supported.
  static String analysisOptions() => '''
include: package:flutter_lints/flutter.yaml

analyzer:
    exclude:
        - build/**
        - .dart_tool/**
        - ios/Pods/**
        - android/.gradle/**
        - ios/Flutter/**
        - "**/*.g.dart"
        - "**/*.freezed.dart"
    language:
        strict-raw-types: true

linter:
    rules:
        prefer_const_constructors: true
        prefer_const_declarations: true
        prefer_const_literals_to_create_immutables: true
        use_build_context_synchronously: true
        use_key_in_widget_constructors: true
        valid_regexps: true
        void_checks: true
        use_super_parameters: true
        avoid_print: true
''';

  /// The FVM pin written at the project root.
  static String fvmrc() => '{\n  "flutter": "stable"\n}\n';

  /// The workspace settings written to `.vscode/settings.json`.
  ///
  /// Its whole job is pointing the Dart/Flutter extension at the SDK [fvmrc]
  /// pins, so the editor, the analyzer and F5 all resolve against the same
  /// Flutter as the command line.
  static String vscodeSettings() => '''
{
    // Point the Dart/Flutter extension at the fvm-managed SDK instead of the
    // one on PATH. This is what Run & Debug (F5), hot reload, the analyzer and
    // every Flutter command in the palette resolve against — launch.json does
    // not need to say anything about the SDK.
    //
    // Relative to the workspace root: it is the symlink `fvm use stable`
    // creates. `.fvm/` is gitignored, so a fresh clone must run `fvm use
    // stable` once before this path exists.
    "dart.flutterSdkPath": ".fvm/flutter_sdk",

    // .fvm/versions links to the whole SDK. Without these, search results fill
    // with framework source and the file watcher indexes thousands of files it
    // will never need.
    "search.exclude": {
        "**/.fvm": true
    },
    "files.watcherExclude": {
        "**/.fvm": true
    }
}
''';

  /// The Run & Debug configurations written to `.vscode/launch.json`.
  ///
  /// Three unflavored entries that work on the scaffold as generated, and a
  /// debug/release pair per flavor for once the native side declares them.
  /// Every entry runs `lib/main.dart` — the scaffold has one entry point, and
  /// the flavor is passed as a `--dart-define` rather than being baked into a
  /// `main_dev.dart`.
  static String vscodeLaunch() => '''
{
    // Run & Debug (F5). The Flutter SDK these resolve against is the fvm one
    // settings.json pins, so nothing here names an SDK path.
    //
    // The flavored entries are here ready for flavors, not because the project
    // has them: until the native side declares a matching flavor they fail
    // with "The Xcode project does not define custom schemes" / "Could not
    // find product flavor". To add one:
    //   android/app/build.gradle.kts → flavorDimensions + productFlavors { dev … }
    //   ios → a scheme and a build configuration per flavor in Xcode
    // Read the flavor in Dart with:
    //   const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    // Prefer a separate entry point per flavor? Point "program" at
    // lib/main_dev.dart and drop the --dart-define.
    "version": "0.2.0",
    "configurations": [
        {
            "name": "debug",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart"
        },
        {
            // Release-mode performance with the profiler and DevTools still
            // attached — where you measure jank, never in debug.
            "name": "profile",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "flutterMode": "profile"
        },
        {
            // No hot reload, no debugger: what the store build actually runs.
            "name": "release",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "flutterMode": "release"
        },
        {
            "name": "dev (debug)",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "args": ["--flavor", "dev", "--dart-define", "FLAVOR=dev"]
        },
        {
            "name": "dev (release)",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "flutterMode": "release",
            "args": ["--flavor", "dev", "--dart-define", "FLAVOR=dev"]
        },
        {
            "name": "staging (debug)",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "args": ["--flavor", "staging", "--dart-define", "FLAVOR=staging"]
        },
        {
            "name": "staging (release)",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "flutterMode": "release",
            "args": ["--flavor", "staging", "--dart-define", "FLAVOR=staging"]
        },
        {
            "name": "prod (debug)",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "args": ["--flavor", "prod", "--dart-define", "FLAVOR=prod"]
        },
        {
            "name": "prod (profile)",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "flutterMode": "profile",
            "args": ["--flavor", "prod", "--dart-define", "FLAVOR=prod"]
        },
        {
            "name": "prod (release)",
            "request": "launch",
            "type": "dart",
            "program": "lib/main.dart",
            "flutterMode": "release",
            "args": ["--flavor", "prod", "--dart-define", "FLAVOR=prod"]
        }
    ]
}
''';

  /// The splash configuration `flutter_native_splash` reads.
  static String nativeSplash() => '''
        # dart run flutter_native_splash:create --path=flutter_native_splash.yaml
        # No icon because it will use the app icon files in each platform folder
        flutter_native_splash:
          color: '#FFFFFF' # BG COLOR (light mode)
          color_dark: '#000000' # BG COLOR (dark mode)

          android_12:
              color: '#FFFFFF' # BG COLOR (light mode)
              color_dark: '#000000' # BG COLOR (dark mode)
    ''';

  /// Replaces the counter test `flutter create` writes.
  ///
  /// That test pumps the `MyApp` from the demo main.dart the scaffold replaces,
  /// so leaving it in place would break `flutter test` on a fresh project with
  /// an error about the app rather than about anything the developer did.
  static String widgetTest() => '''
// `flutter create`'s counter test pumped the demo app the moarch scaffold
// replaced, so it has been swapped for this. Put your widget tests here;
// `test/unit/` and `test/integration/` are scaffolded for the rest.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the test harness runs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    expect(find.byType(Placeholder), findsOneWidget);
  });
}
''';
}
