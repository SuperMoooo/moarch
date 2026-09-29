/// Utility helpers for editing the Android `AndroidManifest.xml`.
class ManifestUtils {
  ManifestUtils._();

  /// Ensures a `<uses-permission android:name="..."/>` tag exists for each
  /// entry in [permissions], inserted right after the opening `<manifest>`
  /// tag. Permissions already present are left untouched.
  ///
  /// Returns [content] unchanged when the `<manifest` tag can't be found (a
  /// customized manifest is left alone rather than risk breaking it).
  ///
  /// A permission in [maxSdkVersions] is declared only up to that API level —
  /// how a permission Android replaced (`READ_EXTERNAL_STORAGE`, by
  /// `READ_MEDIA_IMAGES` from 33) is kept for the devices that still ask it.
  static String ensurePermissions(
    String content,
    List<String> permissions, {
    Map<String, int> maxSdkVersions = const {},
  }) {
    final eol = _lineEnding(content);
    var result = content;
    for (final permission in permissions) {
      if (result.contains('android:name="$permission"')) continue;

      final manifestStart = result.indexOf('<manifest');
      if (manifestStart == -1) return result;
      final manifestTagEnd = result.indexOf('>', manifestStart);
      if (manifestTagEnd == -1) return result;

      final maxSdk = maxSdkVersions[permission];
      final attributes = maxSdk == null
          ? ''
          : ' android:maxSdkVersion="$maxSdk"';
      result = result.replaceRange(
        manifestTagEnd + 1,
        manifestTagEnd + 1,
        '$eol    <uses-permission android:name="$permission"$attributes/>',
      );
    }
    return result;
  }

  /// Inserts [block] as the last child of `<application>` — where receivers
  /// and services a plugin needs declared go.
  ///
  /// Returns [content] unchanged when it already contains [marker], or when
  /// there is no `</application>` to put it before.
  static String ensureApplicationChild(
    String content, {
    required String block,
    required String marker,
  }) {
    if (content.contains(marker)) return content;
    return _insertBeforeLineOf(content, '</application>', block) ?? content;
  }

  /// Adds [intents] (`<intent>` elements) to the manifest's `<queries>` — the
  /// apps this one may ask about, which Android 11 on hides otherwise.
  ///
  /// Goes into the `<queries>` element `flutter create` writes when there is
  /// one, or a new one above `<application>`, so [intents] carry the
  /// indentation of that element's children. Returns [content] unchanged
  /// when it already contains [marker].
  static String ensureQueries(
    String content, {
    required String intents,
    required String marker,
  }) {
    if (content.contains(marker)) return content;
    final intoExisting = _insertBeforeLineOf(content, '</queries>', intents);
    if (intoExisting != null) return intoExisting;
    return _insertBeforeLineOf(
          content,
          '<application',
          '    <queries>\n$intents\n    </queries>',
        ) ??
        content;
  }

  /// [content] with [block] on its own lines directly above the line holding
  /// [tag], in [content]'s line endings — or null when there is no [tag].
  static String? _insertBeforeLineOf(String content, String tag, String block) {
    final index = content.indexOf(tag);
    if (index == -1) return null;
    final lineStart = content.lastIndexOf('\n', index) + 1;
    final eol = _lineEnding(content);
    final normalized = block.replaceAll('\r\n', '\n').replaceAll('\n', eol);
    return content.replaceRange(lineStart, lineStart, '$normalized$eol');
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
