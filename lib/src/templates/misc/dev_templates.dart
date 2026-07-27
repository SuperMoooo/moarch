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
}
