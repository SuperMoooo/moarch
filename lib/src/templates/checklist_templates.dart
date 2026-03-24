class ChecklistTemplates {
  ChecklistTemplates._();

  static String prodChecklist() => r'''
# Production Checklist

A reminder of what to set up before releasing to production.
Check off each item as you complete it.

---

## Flavors

**flutter_flavorizr** — automates creating dev/staging/prod flavors for both Android and iOS from a single `pubspec.yaml` config. Handles app name, bundle ID, icons, and environment-specific configs per flavor.

- https://pub.dev/packages/flutter_flavorizr

---

## Over-the-Air Updates (Code Push)

**shorebird_code_push** — allows pushing Dart code changes directly to users without going through the stores. Ideal for bug fixes and small updates. Requires a Shorebird account and `shorebird init` in the project.

- https://pub.dev/packages/shorebird_code_push
- https://shorebird.dev

---

## Store Version Check

**upgrader** — compares the installed app version against the current version on the App Store / Play Store and prompts the user to update when a new version is available.

- https://pub.dev/packages/upgrader

---

## Android

- [ ] Set correct `applicationId` in `build.gradle`
- [ ] Set correct `versionName` and `versionCode`
- [ ] Release keystore created and stored securely
- [ ] `key.properties` added to `.gitignore`
- [ ] Signing config set in `build.gradle`
- [ ] `android:debuggable` not set to true in manifest
- [ ] Proguard / R8 rules reviewed if needed
- [ ] App tested on a physical device

## iOS

- [ ] Correct Bundle ID set in Xcode
- [ ] Signing certificate and provisioning profile configured
- [ ] `PRODUCT_BUNDLE_IDENTIFIER` correct per scheme
- [ ] Icons and launch screen set
- [ ] App tested on a physical device
- [ ] Privacy usage descriptions added to `Info.plist` for any sensitive permissions (camera, location, etc.)

## General

- [ ] `.env` values set for production (`BASE_URL`, etc.)
- [ ] `debugShowCheckedModeBanner: false`
- [ ] All `TODO` comments resolved
- [ ] Unused dependencies removed from `pubspec.yaml`
- [ ] App version and build number updated
- [ ] `flutter build` runs without warnings
- [ ] Tested on both Android and iOS
- [ ] Error handling reviewed — no raw exceptions shown to the user
- [ ] Analytics / crash reporting configured (e.g. Firebase Crashlytics)
''';
}
