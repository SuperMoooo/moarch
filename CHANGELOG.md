# [1.7.9]

## Features

- easy_localization option (mutually exclusive with flutter_localizations)
- ios/Runner/Info.plist auto-patched: CFBundleLocalizations for localization
  options, camera/photo library/microphone usage descriptions for the media
  service, LSApplicationQueriesSchemes for the URL launcher, and
  UIBackgroundModes (fetch, remote-notification) for Firebase push
  (existing keys are never overwritten; rolled back on failure)
- ios/Runner/AppDelegate.swift auto-patched: UNUserNotificationCenter
  delegate wiring for the local notifications service (skipped when already
  present or customized; rolled back on failure)
- Firebase push generates Runner.entitlements + RunnerProfile.entitlements
  (aps-environment), and the build_ipa workflow signs the archive with them
- any Firebase option generates add_files_to_xcode.rb at the project root;
  build_ipa registers GoogleService-Info.plist in the Xcode project before
  compiling
- docs templates rewritten/corrected: GENERATE_JKS_FILE and
  STEPS_FOR_WORKFLOW are proper markdown (kts imports, secrets table, FCM
  push steps); security checklist pinning + logger examples fixed
