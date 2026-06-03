/// Dev Template
class DevTemplate {
  DevTemplate._();

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
          linter:
              rules:
                  prefer_const_constructors: true
                  prefer_const_declarations: true
                  avoid_print: true',
                ''';
}
