/// Generates iOS project support files (entitlements, Xcode scripts).
class IosTemplates {
  IosTemplates._();

  /// Returns the Runner.entitlements file used by Debug/Release builds.
  ///
  /// `aps-environment` is the APNs entitlement remote push needs; Xcode's
  /// "Push Notifications" capability writes exactly this. The signing step
  /// upgrades `development` to `production` automatically when exporting
  /// with an App Store profile.
  static String runnerEntitlements() => r'''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>

    <!--
    <key>com.apple.developer.voip</key>
    <true/>

    <key>com.apple.developer.pushkit.unrestricted-voip</key>
    <true/>
    -->
</dict>
</plist>
''';

  /// Returns the RunnerProfile.entitlements file used by Profile builds.
  static String runnerProfileEntitlements() => '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>aps-environment</key>
\t<string>development</string>
</dict>
</plist>
''';

  /// Returns the Ruby script that links GoogleService-Info.plist into the
  /// Xcode project. flutterfire configure drops the file on disk, but CI
  /// checkouts (where the plist is gitignored and recreated from a secret)
  /// need it (re)registered in the Runner target's resources build phase.
  static String addFilesToXcodeScript() => r'''
require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

files_to_add = ['GoogleService-Info.plist']
target_group = project.main_group.find_subpath('Runner', false)

files_to_add.each do |file_name|
  # 1. Safe Clean up
  target.resources_build_phase.files.each do |build_file|
    # Only check path if file_ref and path are present
    if build_file.file_ref && build_file.file_ref.path && build_file.file_ref.path.end_with?(file_name)
      target.resources_build_phase.remove_build_file(build_file)
      puts "Removed existing reference to #{file_name}"
    end
  end

  # 2. Add fresh reference
  # We check if the file exists on disk first to avoid adding a missing reference
  if File.exist?("ios/Runner/#{file_name}")
    file_ref = target_group.new_file(file_name)
    target.add_resources([file_ref])
    puts "Successfully linked #{file_name} to Xcode project."
  else
    puts "Warning: #{file_name} not found on disk at ios/Runner/#{file_name}"
  end
end

project.save
puts "Project updated successfully."
''';
}
