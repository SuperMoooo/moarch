/// Dev Template
class DevTemplates {
  DevTemplates._();

  /// Analysis options for better performance and security
  static String analysisOptions() => '''
          include: package:flutter_lints/flutter.yaml
          analyzer:
              exclude:
                  - build/**
                  - .dart_tool/**
                  - ios/Pods/**
                  - android/.gradle/**
                  - ios/Flutter/**
              strong-mode:
                  implicit-dynamic: false
              language:
                  strict-inference: true
                  strict-raw-types: true
          linter:
              rules:
                  prefer_const_constructors: true
                  prefer_const_declarations: true
                  use_build_context_synchronously: true
                  use_key_in_widget_constructors: true
                  valid_regexps: true
                  void_checks: true
                  use_super_parameters: true
                  avoid_print: true
''';
}
