/// Utility helpers for editing iOS `Info.plist` files.
class PlistUtils {
  PlistUtils._();

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
