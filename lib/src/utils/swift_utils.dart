/// Utility helpers for editing the iOS `AppDelegate.swift` file.
class SwiftUtils {
  SwiftUtils._();

  /// Ensures the `UNUserNotificationCenter` delegate assignment
  /// flutter_local_notifications needs is present, inserted right before the
  /// `GeneratedPluginRegistrant.register` call so it runs during app launch.
  ///
  /// Returns the content unchanged when `UNUserNotificationCenter` is already
  /// mentioned anywhere (the user wired it up themselves) or when the
  /// registrant anchor line can't be found (a customized AppDelegate is left
  /// alone rather than risk breaking it).
  static String ensureNotificationDelegate(String content) {
    if (content.contains('UNUserNotificationCenter')) return content;

    final lines = content.split('\n');
    final anchor = lines.indexWhere(
      (line) => line.contains('GeneratedPluginRegistrant.register'),
    );
    if (anchor == -1) return content;

    final indent = RegExp(r'^\s*').firstMatch(lines[anchor])!.group(0)!;
    lines.insertAll(anchor, [
      '$indent// Do not add a userNotificationCenter(_:didReceive:) override here',
      '$indent// without calling super: FlutterAppDelegate forwards notification taps',
      '$indent// to the plugins (flutter_local_notifications / firebase_messaging),',
      '$indent// and an override that skips super blocks them.',
      '${indent}if #available(iOS 10.0, *) {',
      '$indent  UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate',
      '$indent}',
    ]);
    return lines.join('\n');
  }
}
