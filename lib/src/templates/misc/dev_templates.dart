import '../../utils/state_management.dart';

/// Dev Template
class DevTemplates {
  DevTemplates._();

  /// Analysis options for better performance and security.
  ///
  /// `strong-mode: implicit-dynamic` is absent on purpose — the analyzer
  /// dropped it; `strict-raw-types` covers the same ground.
  ///
  /// A bloc project also carries the `bloc:` section. That one is **not** read
  /// by `dart analyze` — the rules are the bloc analysis server's, run with
  /// `bloc lint .` or through the Bloc VS Code extension. Keeping it in the
  /// same file is what the bloc docs prescribe, and it means one place to
  /// tune lint rules whichever tool is reading them.
  static String analysisOptions({
    StateManagement stateManagement = StateManagement.riverpod,
  }) {
    final blocRules = stateManagement.isBloc
        ? '''

# Read by the bloc analysis server (`bloc lint .`), not by `dart analyze`.
# Install the CLI once with: dart pub global activate bloc_tools
#
# The recommended set. `prefer_bloc` and `prefer_cubit` are deliberately left
# out: moarch scaffolds features as event-driven Blocs, but a holder with one
# value and no vocabulary of events — the locale, the maintenance flag — is a
# Cubit on purpose, and neither rule can tell the two cases apart.
bloc:
    rules:
        - avoid_flutter_imports
        - avoid_public_bloc_methods
        - avoid_public_fields
        - prefer_file_naming_conventions
        - prefer_void_public_cubit_methods
'''
        : '';

    return '$_analysisOptionsBody$blocRules';
  }

  static const String _analysisOptionsBody = '''
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

  /// The workspace settings written to `.vscode/settings.json`, pointing the
  /// Dart/Flutter extension at the SDK [fvmrc] pins.
  static String vscodeSettings() => '''
{
    // The symlink `fvm use` creates. `.fvm/` is gitignored, so every fresh
    // clone must run `fvm use` once before this path exists.
    //
    // Nothing errors when it does not: the Dart extension falls back to the
    // first Flutter on PATH, silently, so F5 / hot reload / the analyzer all
    // run the SDK the pin exists to avoid. If a deprecation or an analyzer
    // error shows up that `fvm flutter analyze` does not report, this is why —
    // run `fvm use` and reload the window.
    //
    // Kept version-agnostic on purpose: `flutter_sdk` follows .fvmrc, so
    // switching SDKs never touches this file. Re-running `fvm use` rewrites
    // this file with a versioned path and strips these comments — put them
    // back, or run `moarch doctor`, which flags the versioned form.
    "dart.flutterSdkPath": ".fvm/flutter_sdk",

    // Without these, search and the file watcher index the whole SDK.
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
  /// Three unflavored entries that work on the scaffold as generated, plus a
  /// debug/release pair per flavor for once the native side declares them.
  static String vscodeLaunch() => '''
{
    // The flavored entries are ready for flavors, not proof the project has
    // them: until the native side declares a matching flavor they fail with
    // "The Xcode project does not define custom schemes" / "Could not find
    // product flavor". Declare them in android/app/build.gradle.kts
    // (productFlavors) and as an Xcode scheme + build configuration.
    "version": "0.2.0",
    "configurations": [
        {
            "name": "debug",
            "request": "launch",
            "type": "dart",
            "flutterMode": "debug"
        },
        {
            // Where you measure jank — never in debug.
            "name": "profile",
            "request": "launch",
            "type": "dart",
            "flutterMode": "profile"
        },
        {
            "name": "release",
            "request": "launch",
            "type": "dart",
            "flutterMode": "release"
        },
        {
            "name": "dev (debug)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "debug",
            "args": ["--flavor", "dev"]
        },
        {
            "name": "dev (release)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "release",
            "args": ["--flavor", "dev"]
        },
        {
            "name": "staging (debug)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "debug",
            "args": ["--flavor", "staging"]
        },
        {
            "name": "staging (release)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "release",
            "args": ["--flavor", "staging"]
        },
        {
            "name": "prod (debug)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "debug",
            "args": ["--flavor", "prod"]
        },
        {
            "name": "prod (profile)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "profile",
            "args": ["--flavor", "prod"]
        },
        {
            "name": "prod (release)",
            "request": "launch",
            "type": "dart",
            "flutterMode": "release",
            "args": ["--flavor", "prod"]
        }
    ]
}
''';

  /// The splash configuration `flutter_native_splash` reads.
  static String nativeSplash() => '''
        # dart run flutter_native_splash:create --path=flutter_native_splash.yaml
        # No icon set — it falls back to the app icon in each platform folder.
        flutter_native_splash:
          color: '#FFFFFF' # BG COLOR (light mode)
          color_dark: '#000000' # BG COLOR (dark mode)

          android_12:
              color: '#FFFFFF' # BG COLOR (light mode)
              color_dark: '#000000' # BG COLOR (dark mode)
    ''';

  /// Replaces the counter test `flutter create` writes, which pumps the demo
  /// app the scaffold removes and would fail on a fresh project.
  static String widgetTest() => '''
// Put your widget tests here; `test/unit/` and `test/integration/` are
// scaffolded for the rest.
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
