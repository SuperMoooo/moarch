/// Utility helpers for editing the iOS `Podfile`.
class PodfileUtils {
  PodfileUtils._();

  /// Ensures the permission_handler `GCC_PREPROCESSOR_DEFINITIONS` block is
  /// present inside the `post_install` target loop.
  ///
  /// permission_handler gates each permission group's native code on whether
  /// its macro is *defined at all*, not on its value — `PERMISSION_CAMERA=0`
  /// still compiles the camera handler and demands a usage description.
  /// Disabling a group means commenting the whole array entry out, which is
  /// what happens here for every group except [camera] and [photos]: the
  /// only `Permission.*` values MediaService ever requests.
  ///
  /// Only a project that still has a Podfile — one a plugin forces back onto
  /// CocoaPods — is patched; since Flutter 3.44 the plugins come through Swift
  /// Package Manager, where permission_handler reads `Info.plist` instead.
  ///
  /// Returns [content] unchanged when the block is already present (the user
  /// wired it up themselves) or when the
  /// `flutter_additional_ios_build_settings(target)` anchor line can't be
  /// found (a customized Podfile is left alone rather than risk breaking it).
  static String ensurePermissionHandlerDefinitions(
    String content, {
    required bool camera,
    required bool photos,
  }) {
    if (content.contains('PERMISSION_CAMERA')) return content;

    final lines = content.split('\n');
    final anchor = lines.indexWhere(
      (line) => line.contains('flutter_additional_ios_build_settings(target)'),
    );
    if (anchor == -1) return content;

    final indent = RegExp(r'^\s*').firstMatch(lines[anchor])!.group(0)!;

    lines.insertAll(anchor + 1, [
      '',
      '${indent}target.build_configurations.each do |config|',
      "$indent  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['\$(inherited)']",
      "$indent  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] += [",
      ..._definitionLines('$indent    ', camera: camera, photos: photos),
      '$indent  ]',
      '${indent}end',
    ]);
    return lines.join('\n');
  }

  /// One `## dart: PermissionGroup.x` comment + array entry per
  /// permission_handler group, indented by [indent]. Disabled groups are
  /// commented out entirely (see [ensurePermissionHandlerDefinitions] for
  /// why `=0` isn't good enough).
  static List<String> _definitionLines(
    String indent, {
    required bool camera,
    required bool photos,
  }) {
    String entry(String comment, String group, bool enabled) {
      final line = "'PERMISSION_$group=1',";
      return [
        '$indent## dart: $comment',
        enabled ? '$indent$line' : '$indent# $line',
        '',
      ].join('\n');
    }

    final lines = [
      entry('PermissionGroup.calendar', 'EVENTS', false),
      entry('PermissionGroup.reminders', 'REMINDERS', false),
      entry('PermissionGroup.contacts', 'CONTACTS', false),
      entry('PermissionGroup.camera', 'CAMERA', camera),
      entry('PermissionGroup.microphone', 'MICROPHONE', false),
      entry('PermissionGroup.speech', 'SPEECH_RECOGNIZER', false),
      entry('PermissionGroup.photos', 'PHOTOS', photos),
      entry(
        '[PermissionGroup.location, PermissionGroup.locationAlways, PermissionGroup.locationWhenInUse]',
        'LOCATION',
        false,
      ),
      entry('PermissionGroup.notification', 'NOTIFICATIONS', false),
      entry(
        'PermissionGroup.appTrackingTransparency',
        'APP_TRACKING_TRANSPARENCY',
        false,
      ),
      entry('PermissionGroup.mediaLibrary', 'MEDIA_LIBRARY', false),
      entry('PermissionGroup.sensors', 'SENSORS', false),
    ].join('\n').split('\n');
    // Drop the trailing blank line the last entry() leaves behind.
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return lines;
  }
}
