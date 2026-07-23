/// Utility helpers for editing the Android `MainActivity.kt`.
class KotlinUtils {
  KotlinUtils._();

  /// Switches `MainActivity` from `FlutterActivity` to
  /// `FlutterFragmentActivity`, which local_auth (and other plugins that show
  /// a native dialog, like biometric prompts) requires as the activity host.
  ///
  /// Returns [content] unchanged when it already extends
  /// `FlutterFragmentActivity`, or when `FlutterActivity` isn't mentioned at
  /// all (a customized MainActivity is left alone rather than risk breaking
  /// it).
  static String ensureFragmentActivity(String content) {
    if (content.contains('FlutterFragmentActivity')) return content;
    if (!content.contains('FlutterActivity')) return content;
    return content.replaceAll('FlutterActivity', 'FlutterFragmentActivity');
  }
}
