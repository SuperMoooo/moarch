/// Utility helpers for editing iOS `Info.plist` files.
class PlistUtils {
  PlistUtils._();

  /// Stands in for `GIDClientID` until `GoogleService-Info.plist` exists.
  ///
  /// Written by `moarch init` and replaced by `moarch doctor --fix` once
  /// `flutterfire configure` has produced the real value. It is deliberately
  /// not a plausible client id: it must fail loudly rather than half-work.
  static const String googleClientIdPlaceholder =
      'REPLACE_WITH_CLIENT_ID.apps.googleusercontent.com';

  /// The [googleClientIdPlaceholder] counterpart for the URL scheme.
  static const String googleReversedClientIdPlaceholder =
      'com.googleusercontent.apps.REPLACE_WITH_REVERSED_CLIENT_ID';

  /// Ensures a `CFBundleLocalizations` array with [locales] exists in the
  /// plist [content].
  ///
  /// Without this key, iOS never activates non-default locales, so both
  /// flutter_localizations and easy_localization silently fall back to
  /// English on iOS.
  static String ensureLocalizations(String content, List<String> locales) =>
      ensureArray(content, 'CFBundleLocalizations', locales);

  /// Ensures a `<key>[key]</key><array>…</array>` block with [values] exists
  /// in the plist [content]. Returns the content unchanged when the key is
  /// already present (whatever its value) or when no closing `</dict>` is
  /// found.
  static String ensureArray(String content, String key, List<String> values) {
    if (content.contains('<key>$key</key>')) return content;

    final insertAt = content.lastIndexOf('</dict>');
    if (insertAt == -1) return content;

    final strings = values.map((v) => '\t\t<string>$v</string>').join('\n');
    final block = '\t<key>$key</key>\n'
        '\t<array>\n'
        '$strings\n'
        '\t</array>\n';
    return content.replaceRange(insertAt, insertAt, block);
  }

  /// Ensures [scheme] is registered as a `CFBundleURLSchemes` entry in the
  /// plist [content].
  ///
  /// Google sign-in on iOS is only reachable through the URL scheme built
  /// from the project's `REVERSED_CLIENT_ID`: without it the sign-in sheet
  /// opens and never comes back. Unlike the other helpers here, an existing
  /// `CFBundleURLTypes` is added to rather than left alone — a project with a
  /// deep-link scheme still needs this one.
  ///
  /// [comment] is written into the entry as an XML comment, which is where a
  /// placeholder explains itself.
  static String ensureUrlScheme(
    String content,
    String scheme, {
    String? comment,
  }) {
    if (content.contains('<string>$scheme</string>')) return content;

    final commentLine = comment == null ? '' : '\t\t\t<!-- $comment -->\n';
    final entry = '\t\t<dict>\n'
        '$commentLine'
        '\t\t\t<key>CFBundleTypeRole</key>\n'
        '\t\t\t<string>Editor</string>\n'
        '\t\t\t<key>CFBundleURLSchemes</key>\n'
        '\t\t\t<array>\n'
        '\t\t\t\t<string>$scheme</string>\n'
        '\t\t\t</array>\n'
        '\t\t</dict>\n';

    final keyIndex = content.indexOf('<key>CFBundleURLTypes</key>');
    if (keyIndex == -1) {
      final insertAt = content.lastIndexOf('</dict>');
      if (insertAt == -1) return content;
      final block = '\t<key>CFBundleURLTypes</key>\n'
          '\t<array>\n'
          '$entry'
          '\t</array>\n';
      return content.replaceRange(insertAt, insertAt, block);
    }

    final arrayStart = content.indexOf('<array>', keyIndex);
    if (arrayStart == -1) return content;
    final insertAt = arrayStart + '<array>'.length;
    return content.replaceRange(insertAt, insertAt, '\n${entry.trimRight()}');
  }

  /// The `<string>` value following `<key>[key]</key>` in [content], or null.
  ///
  /// Enough plist reading to lift `CLIENT_ID` and `REVERSED_CLIENT_ID` out of
  /// a `GoogleService-Info.plist` — not a general parser.
  static String? readString(String content, String key) {
    final keyIndex = content.indexOf('<key>$key</key>');
    if (keyIndex == -1) return null;
    final match = RegExp(r'<string>(.*?)</string>', dotAll: true)
        .firstMatch(content.substring(keyIndex));
    return match?.group(1)?.trim();
  }

  /// Ensures each `<key>…</key><string>…</string>` pair in [entries] exists
  /// in the plist [content]. Keys already present are left untouched
  /// (whatever their value), so user-written descriptions are never
  /// overwritten. Used for the NS*UsageDescription permission strings iOS
  /// requires before the corresponding runtime permission prompt can appear.
  static String ensureEntries(String content, Map<String, String> entries) {
    var result = content;
    for (final entry in entries.entries) {
      if (result.contains('<key>${entry.key}</key>')) continue;
      final insertAt = result.lastIndexOf('</dict>');
      if (insertAt == -1) return result;
      final block = '\t<key>${entry.key}</key>\n'
          '\t<string>${entry.value}</string>\n';
      result = result.replaceRange(insertAt, insertAt, block);
    }
    return result;
  }
}
