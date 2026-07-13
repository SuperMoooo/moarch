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

  /// Returns a generic `ios/Podfile`, written only when the target project
  /// doesn't already have one. Mirrors what `flutter create` + `pod install`
  /// produce, with the permission_handler block pre-wired the same way
  /// [ensurePermissionHandlerDefinitions] would patch it.
  static String defaultPodfile({required bool camera, required bool photos}) {
    final definitions =
        _definitionLines('        ', camera: camera, photos: photos)
            .join('\n');

    return '''
# Uncomment this line to define a global platform for your project
# platform :ios, '13.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '\$(inherited)',

$definitions
      ]
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['CODE_SIGN_IDENTITY'] = ''
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ''
    end
  end
end
''';
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
      entry('PermissionGroup.appTrackingTransparency',
          'APP_TRACKING_TRANSPARENCY', false),
      entry('PermissionGroup.mediaLibrary', 'MEDIA_LIBRARY', false),
      entry('PermissionGroup.sensors', 'SENSORS', false),
    ].join('\n').split('\n');
    // Drop the trailing blank line the last entry() leaves behind.
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return lines;
  }
}
