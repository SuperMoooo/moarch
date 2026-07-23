/// Utility helpers for editing the Android `AndroidManifest.xml`.
class ManifestUtils {
  ManifestUtils._();

  /// Ensures a `<uses-permission android:name="..."/>` tag exists for each
  /// entry in [permissions], inserted right after the opening `<manifest>`
  /// tag. Permissions already present are left untouched.
  ///
  /// Returns [content] unchanged when the `<manifest` tag can't be found (a
  /// customized manifest is left alone rather than risk breaking it).
  static String ensurePermissions(String content, List<String> permissions) {
    var result = content;
    for (final permission in permissions) {
      if (result.contains('android:name="$permission"')) continue;

      final manifestStart = result.indexOf('<manifest');
      if (manifestStart == -1) return result;
      final manifestTagEnd = result.indexOf('>', manifestStart);
      if (manifestTagEnd == -1) return result;

      result = result.replaceRange(
        manifestTagEnd + 1,
        manifestTagEnd + 1,
        '\n    <uses-permission android:name="$permission"/>',
      );
    }
    return result;
  }
}
