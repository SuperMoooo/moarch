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
    final eol = _lineEnding(content);
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
        '$eol    <uses-permission android:name="$permission"/>',
      );
    }
    return result;
  }

  /// Inserts [intentFilter] as the last child of `MainActivity`'s
  /// `<activity>` element.
  ///
  /// Returns [content] unchanged when it already declares [marker] (a filter
  /// added before — or edited since, which is the user's), or when there is
  /// no `.MainActivity` element to put it in.
  static String ensureActivityIntentFilter(
    String content, {
    required String intentFilter,
    required String marker,
  }) {
    if (content.contains(marker)) return content;

    final activity = content.indexOf('android:name=".MainActivity"');
    if (activity == -1) return content;
    final close = content.indexOf('</activity>', activity);
    if (close == -1) return content;
    // Back up to the start of the closing tag's line, so the filter lands
    // above its indentation.
    final lineStart = content.lastIndexOf('\n', close) + 1;

    final eol = _lineEnding(content);
    final block = intentFilter.replaceAll('\r\n', '\n').replaceAll('\n', eol);
    return content.replaceRange(lineStart, lineStart, '$block$eol');
  }

  /// The line ending [content] already uses, so an insertion does not leave
  /// a CRLF manifest with mixed endings.
  static String _lineEnding(String content) =>
      content.contains('\r\n') ? '\r\n' : '\n';
}
