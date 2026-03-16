class ConfigTemplates {
  ConfigTemplates._();

  static String appTheme() => r'''
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        // TODO: add your theme
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        // TODO: add your dark theme
      );
}
''';
}
