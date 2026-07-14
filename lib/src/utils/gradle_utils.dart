/// Utility helpers for editing the Android `app/build.gradle.kts`.
class GradleUtils {
  GradleUtils._();

  static const _desugarDependency = 'com.android.tools:desugar_jdk_libs:2.1.4';

  /// Ensures Java 8+ core library desugaring is enabled.
  ///
  /// flutter_local_notifications relies on `java.time` APIs under the hood,
  /// which the Android toolchain only supports below API 26 via desugaring —
  /// omitting this makes `flutter build apk`/`appbundle` fail the first time
  /// with an error pointing at `coreLibraryDesugaring`.
  ///
  /// Returns [content] unchanged when desugaring is already enabled (the
  /// user wired it up themselves) or when the `android {` anchor can't be
  /// found (a customized build.gradle.kts is left alone rather than risk
  /// breaking it).
  static String ensureCoreLibraryDesugaring(String content) {
    if (content.contains('isCoreLibraryDesugaringEnabled')) return content;

    var lines = content.split('\n');

    final compileOptionsAnchor =
        lines.indexWhere((line) => line.contains('compileOptions {'));
    if (compileOptionsAnchor != -1) {
      final indent =
          RegExp(r'^\s*').firstMatch(lines[compileOptionsAnchor])!.group(0)!;
      lines.insert(
        compileOptionsAnchor + 1,
        '$indent    isCoreLibraryDesugaringEnabled = true',
      );
    } else {
      final androidAnchor =
          lines.indexWhere((line) => line.trim() == 'android {');
      if (androidAnchor == -1) return content;
      final indent =
          RegExp(r'^\s*').firstMatch(lines[androidAnchor])!.group(0)!;
      lines.insertAll(androidAnchor + 1, [
        '$indent    compileOptions {',
        '$indent        isCoreLibraryDesugaringEnabled = true',
        '$indent    }',
        '',
      ]);
    }

    content = lines.join('\n');
    lines = content.split('\n');

    final dependenciesAnchor = lines.indexWhere(
      (line) => RegExp(r'^dependencies\s*\{').hasMatch(line),
    );
    if (dependenciesAnchor != -1) {
      lines.insert(
        dependenciesAnchor + 1,
        '    coreLibraryDesugaring("$_desugarDependency")',
      );
      return lines.join('\n');
    }

    final trimmed = content.trimRight();
    return '$trimmed\n\ndependencies {\n'
        '    coreLibraryDesugaring("$_desugarDependency")\n'
        '}\n';
  }
}
