/// Utility helpers for editing the Android `app/build.gradle.kts`.
class GradleUtils {
  GradleUtils._();

  static const _desugarDependency = 'com.android.tools:desugar_jdk_libs:2.1.5';

  /// The `compileSdk` the plugins `init` adds build against: permission_handler
  /// 13 and flutter_local_notifications 23 compile against API 37, one above
  /// what the Flutter 3.47 template sets through `flutter.compileSdkVersion`.
  static const int requiredCompileSdk = 37;

  /// Ensures `compileSdk` in [content] is at least [minimum].
  ///
  /// The template's `compileSdk = flutter.compileSdkVersion` becomes
  /// `maxOf(flutter.compileSdkVersion, 37)`, so the project follows the
  /// Flutter default again the day it catches up rather than staying pinned.
  /// A literal below the minimum is raised the same way; one at or above it,
  /// an existing `maxOf`, and a file with no recognisable `compileSdk` line
  /// are left alone.
  static String ensureCompileSdk(
    String content, {
    int minimum = requiredCompileSdk,
  }) {
    final line = RegExp(r'^(\s*)compileSdk\s*=\s*(.+?)\s*$', multiLine: true);
    final match = line.firstMatch(content);
    if (match == null) return content;
    final value = match.group(2)!;
    final literal = int.tryParse(value);
    if (literal != null && literal >= minimum) return content;
    final floor = RegExp(r'maxOf\(\s*(.+?)\s*,\s*(\d+)\s*\)').firstMatch(value);
    if (floor != null && int.parse(floor.group(2)!) >= minimum) return content;
    final base =
        floor?.group(1) ??
        (literal == null ? value : 'flutter.compileSdkVersion');
    return content.replaceRange(
      match.start,
      match.end,
      '${match.group(1)}// At least $minimum: what permission_handler and\n'
      '${match.group(1)}// flutter_local_notifications compile against.\n'
      '${match.group(1)}compileSdk = maxOf($base, $minimum)',
    );
  }

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

    final compileOptionsAnchor = lines.indexWhere(
      (line) => line.contains('compileOptions {'),
    );
    if (compileOptionsAnchor != -1) {
      final indent = RegExp(
        r'^\s*',
      ).firstMatch(lines[compileOptionsAnchor])!.group(0)!;
      lines.insert(
        compileOptionsAnchor + 1,
        '$indent    isCoreLibraryDesugaringEnabled = true',
      );
    } else {
      final androidAnchor = lines.indexWhere(
        (line) => line.trim() == 'android {',
      );
      if (androidAnchor == -1) return content;
      final indent = RegExp(
        r'^\s*',
      ).firstMatch(lines[androidAnchor])!.group(0)!;
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
