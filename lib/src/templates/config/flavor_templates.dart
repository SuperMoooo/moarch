/// Templates for the flutter_flavorizr configuration `create flavors` writes.
class FlavorTemplates {
  FlavorTemplates._();

  /// The `flavorizr.yaml` written at the project root.
  ///
  /// The `instructions` list is the point of this file: it runs only the
  /// processors that patch the native side and generate `lib/flavors.dart`,
  /// so flavorizr never touches `lib/main.dart` and never generates the
  /// per-flavor `main_<flavor>.dart` entry points — the project keeps its
  /// single entry point and reads the flavor off `lib/flavors.dart`.
  ///
  /// [appTitle] is the display name flavors decorate (`MyApp Dev`), and
  /// [androidId] / [iosId] the base ids the non-production flavors suffix
  /// with their own name.
  static String flavorizrYaml({
    required String appTitle,
    required String androidId,
    required String iosId,
    required List<String> flavors,
  }) {
    final buffer = StringBuffer()
      ..writeln('# Written by moarch — flutter_flavorizr configuration.')
      ..writeln('# Docs: https://pub.dev/packages/flutter_flavorizr')
      ..writeln('#')
      ..writeln('# Apply it with:')
      ..writeln('#')
      ..writeln('#   dart run flutter_flavorizr')
      ..writeln('#')
      ..writeln(
          '# The `instructions` below keep flavorizr away from lib/main.dart:')
      ..writeln(
          '# it patches the native side and generates lib/flavors.dart, nothing')
      ..writeln(
          '# else — no per-flavor main_<flavor>.dart, no replaced entry point.')
      ..writeln('# The same processors, one part at a time:')
      ..writeln('#')
      ..writeln('#   dart run flutter_flavorizr -p '
          'android:flavorizrGradle,android:buildGradle,android:androidManifest')
      ..writeln('#   dart run flutter_flavorizr -p ios:xcconfig,ios:plist')
      ..writeln('#   dart run flutter_flavorizr -p flutter:flavors')
      ..writeln()
      ..writeln('app:')
      ..writeln('  android:')
      ..writeln('    flavorDimensions: "flavor"')
      ..writeln()
      ..writeln('flavors:');

    for (final flavor in flavors) {
      final isProd = flavor == 'prod' || flavor == 'production';
      // Production ships under the app's own name and id; every other
      // flavor is suffixed so the builds install side by side.
      final name = isProd ? appTitle : '$appTitle ${_capitalize(flavor)}';
      final androidFlavorId = isProd ? androidId : '$androidId.$flavor';
      final iosFlavorId = isProd ? iosId : '$iosId.$flavor';

      buffer
        ..writeln('  $flavor:')
        ..writeln('    app:')
        ..writeln('      name: "$name"')
        ..writeln('    android:')
        ..writeln('      applicationId: "$androidFlavorId"')
        ..writeln('    ios:')
        ..writeln('      bundleId: "$iosFlavorId"');
    }

    buffer
      ..writeln()
      ..writeln('instructions:')
      ..writeln('  - android:flavorizrGradle')
      ..writeln('  - android:buildGradle')
      ..writeln('  - android:androidManifest')
      ..writeln('  - ios:xcconfig')
      ..writeln('  - ios:plist')
      ..writeln('  - flutter:flavors');

    return buffer.toString();
  }

  static String _capitalize(String word) =>
      word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';
}
