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
