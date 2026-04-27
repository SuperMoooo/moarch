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

  static String securityChecklist() => r'''

# Flutter App Store Security Checklist
> Based on [OWASP Mobile Top 10 (2024)](https://owasp.org/www-project-mobile-top-10/)

Use this checklist before publishing a Flutter app to the Google Play Store or Apple App Store. Each section maps to an OWASP Mobile risk.

---

## M1 — Improper Credential Usage

Secrets and credentials must never be hardcoded or bundled in the binary.

- [ ] No API keys, tokens, or secrets hardcoded in Dart source files
- [ ] No secrets committed to version control (check `.env`, `google-services.json`, `GoogleService-Info.plist`)
- [ ] `.env` file is in `.gitignore`; only `.env.example` (with dummy values) is committed
- [ ] Environment variables injected at CI/CD time (e.g. GitHub Actions secrets → `.env` file generated before build)
- [ ] Credentials retrieved at runtime from a secure backend or secret manager where possible

**Example — compile-time safe secrets with `envied`:**

`envied` reads your `.env` at code-generation time and bakes obfuscated values into the binary — no `.env` file is bundled or shipped.

```
# .env  (gitignored)
API_KEY=super_secret_key_123
BASE_URL=https://api.example.com
```

```dart
// lib/core/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true) // obfuscate: true splits the value in the binary
abstract class Env {
  @EnviedField(varName: 'API_KEY')
  static final String apiKey = _Env.apiKey;

  @EnviedField(varName: 'BASE_URL')
  static final String baseUrl = _Env.baseUrl;
}
```

```bash
# Generate env.g.dart (run before every build)
dart run build_runner build --delete-conflicting-outputs
```

```dart
// Usage anywhere in the app
import 'core/env/env.dart';

final apiKey = Env.apiKey;
```

> ⚠️ `env.g.dart` must also be in `.gitignore` — it contains the compiled secrets.

```
# .gitignore
.env
lib/core/env/env.g.dart
```

**Packages:** [`envied`](https://pub.dev/packages/envied), [`envied_generator`](https://pub.dev/packages/envied_generator), [`build_runner`](https://pub.dev/packages/build_runner)

---

## M2 — Inadequate Supply Chain Security

Third-party packages can introduce vulnerabilities into your app.

- [ ] All dependencies are reviewed before adding (`pub.dev` score, publisher, last update)
- [ ] `pubspec.lock` is committed to version control to lock dependency versions
- [ ] No unused or abandoned packages in `pubspec.yaml`
- [ ] Run `flutter pub outdated` and update packages before each release
- [ ] Native dependencies (CocoaPods, Gradle) are also reviewed

**Example — audit dependencies:**
```bash
flutter pub outdated
flutter pub upgrade --major-versions  # review breaking changes manually
```

---

## M3 — Insecure Authentication & Authorization

Authentication logic must be robust and not bypassable on the client side.

- [ ] Authentication is enforced server-side, never only on the client
- [ ] Biometric authentication uses the OS-level API, not a custom implementation
- [ ] Session tokens are short-lived and refreshed securely
- [ ] Logout invalidates the session token on the server
- [ ] Role/permission checks happen on the backend, not in the Flutter UI

**Example — biometric auth:**
```dart
// local_auth: ^2.3.0
import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();
final didAuthenticate = await auth.authenticate(
  localizedReason: 'Confirma a tua identidade',
  options: const AuthenticationOptions(biometricOnly: true),
);
```

**Packages:** [`local_auth`](https://pub.dev/packages/local_auth), [`firebase_auth`](https://pub.dev/packages/firebase_auth)

---

## M4 — Insufficient Input & Output Validation

All input entering or leaving the app must be validated and sanitised.

- [ ] Form fields validate input on both client (UX) and server (security)
- [ ] No user input is ever interpolated directly into SQL queries or shell commands
- [ ] Deep link / URL parameters are validated before use
- [ ] Data from external sources (APIs, QR codes, NFC) is sanitised before rendering
- [ ] Output rendered in WebViews is escaped to prevent XSS

**Example — basic form validation:**
```dart
TextFormField(
  validator: (value) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
    if (value.length > 200) return 'Máximo 200 caracteres';
    return null;
  },
)
```

---

## M5 — Insecure Communication

All network traffic must be encrypted and verified.

- [ ] All API calls use HTTPS; HTTP is disabled
- [ ] SSL certificate pinning is implemented for sensitive endpoints
- [ ] `android:usesCleartextTraffic="false"` in `AndroidManifest.xml`
- [ ] iOS `NSAppTransportSecurity` does not allow arbitrary loads
- [ ] Self-signed certificates are not accepted in production builds

**Example — certificate pinning:**
```dart
// http: ^1.x or dio: ^5.x
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

// With dio + custom SecurityContext:
final context = SecurityContext(withTrustedRoots: false);
context.setTrustedCertificatesBytes(certBytes);
```

**Packages:** [`dio`](https://pub.dev/packages/dio), [`http_certificate_pinning`](https://pub.dev/packages/http_certificate_pinning)

**Android — `android/app/src/main/res/xml/network_security_config.xml`:**
```xml
<network-security-config>
  <base-config cleartextTrafficPermitted="false" />
</network-security-config>
```

---

## M6 — Inadequate Privacy Controls

Apps must handle personal data with care and comply with GDPR / App Store privacy requirements.

- [ ] Only necessary permissions are requested (`INTERNET`, `CAMERA`, etc.)
- [ ] Permissions are requested at runtime, with clear justification shown to the user
- [ ] Personal data is not logged in production builds
- [ ] Analytics/crash reporting SDKs are configured to not collect PII
- [ ] Privacy policy is linked in the store listing and within the app
- [ ] Data deletion flow is available (required by both stores)

**Example — disable debug logging in release:**
```dart
// In your logger setup
if (kDebugMode) {
  logger.level = Level.verbose;
} else {
  logger.level = Level.off; // or Level.error only
}
```

**Packages:** [`permission_handler`](https://pub.dev/packages/permission_handler), [`logger`](https://pub.dev/packages/logger)

---

## M7 — Insufficient Binary Protections

The compiled binary should be hardened against reverse engineering.

- [ ] Code obfuscation is enabled for release builds
- [ ] ProGuard/R8 rules are configured for Android
- [ ] Debug symbols are not included in the production binary
- [ ] Debug symbols (`split-debug-info`) are archived securely for crash de-obfuscation
- [ ] App integrity / tamper detection is implemented for high-risk apps

### Obfuscation

**Enable obfuscation at build time:**
```bash
# Android
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info/android

# iOS
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/debug-info/ios
```

> ⚠️ Store the `build/debug-info/` folder. Without it you cannot read crash stack traces from Firebase Crashlytics or the stores.

**`android/app/build.gradle` — enable R8:**
```groovy
buildTypes {
  release {
    minifyEnabled true      // enables R8 (shrink + obfuscate)
    shrinkResources true    // removes unused resources
    proguardFiles(
      getDefaultProguardFile('proguard-android-optimize.txt'),
      'proguard-rules.pro'
    )
    signingConfig signingConfigs.release
    debuggable false
  }
}
```

---

### ProGuard Rules — `android/app/proguard-rules.pro`

```proguard
##──── Flutter engine ────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

##──── Dart / Flutter generated code ─────────────────────────────────────────
# Keep classes referenced via reflection or generated JSON serialisers
-keep class * extends io.flutter.plugin.common.PluginRegistry { *; }

##──── Google Play Core / In-App Updates & Integrity ────────────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

##──── Firebase ───────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

##──── OkHttp / Dio (networking) ─────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

##──── Kotlin coroutines ──────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory { *; }
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler { *; }
-dontwarn kotlinx.coroutines.**

##──── Serialisation — keep model classes from being stripped ────────────────
# If you use json_serializable or freezed, keep your data package:
# -keep class com.yourcompany.yourapp.data.models.** { *; }

##──── Prevent stripping enums ───────────────────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

##──── Native methods ─────────────────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

##──── Debugging: preserve line numbers in stack traces ──────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
```

> Add rules incrementally — only suppress warnings (`-dontwarn`) for libraries you actually use. Run `./gradlew assembleRelease` and check the output for new warnings after each addition.

---

### App Integrity Verification

App integrity detects if your app has been tampered with, repackaged, or is running on an untrusted device. Use the **Play Integrity API** on Android and **DeviceCheck / App Attest** on iOS.

#### Android — Play Integrity API

```yaml
# pubspec.yaml
dependencies:
  play_integrity: ^2.0.0   # or use google_play_integrity
```

```dart
import 'package:play_integrity/play_integrity.dart';

Future<void> checkIntegrity() async {
  try {
    // 1. Get a nonce from YOUR backend (single-use, server-generated)
    final nonce = await myBackend.fetchIntegrityNonce();

    // 2. Request an integrity token from Google
    final token = await PlayIntegrity().requestIntegrityToken(nonce: nonce);

    // 3. Send the token to YOUR backend for verification
    //    Never verify the token on the client side
    final result = await myBackend.verifyIntegrityToken(token);

    if (!result.isValid) {
      // Block access, show error, or log for review
      throw AppException.integrityCheckFailed();
    }
  } on PlayIntegrityException catch (e) {
    // Handle errors: device not supported, Google Play not available, etc.
    logger.e('Integrity check error: ${e.message}');
  }
}
```

**What the backend verdict contains:**
```json
{
  "requestDetails": { "nonce": "...", "packageName": "com.example.app" },
  "appIntegrity": {
    "appRecognitionVerdict": "PLAY_RECOGNIZED", // or UNRECOGNIZED_VERSION / UNEVALUATED
    "certificateSha256Digest": ["..."]
  },
  "deviceIntegrity": {
    "deviceRecognitionVerdict": ["MEETS_DEVICE_INTEGRITY"] // or MEETS_STRONG_INTEGRITY
  },
  "accountDetails": {
    "appLicensingVerdict": "LICENSED" // verifies user purchased the app
  }
}
```

> ⚠️ Always verify the token server-side using the [Play Integrity API](https://developer.android.com/google/play/integrity/verdict). A client-side check can be bypassed.

**Packages:** [`play_integrity`](https://pub.dev/packages/play_integrity)

---

#### iOS — App Attest (DeviceCheck)

Apple's **App Attest** verifies the app binary and device before sensitive operations. It requires iOS 14+.

```dart
// Use a method channel or the app_attest package
// There is no first-party Flutter package — use a native Swift method channel

// ios/Runner/AppAttestService.swift
import DeviceCheck

func attestKey(challenge: Data) async throws -> Data {
    let service = DCAppAttestService.shared
    guard service.isSupported else { throw AttestError.notSupported }

    // 1. Generate a key (store the keyId for future assertions)
    let keyId = try await service.generateKey()

    // 2. Attest the key using a server-provided challenge hash
    let clientDataHash = Data(SHA256.hash(data: challenge))
    let attestationObject = try await service.attestKey(keyId, clientDataHash: clientDataHash)

    // 3. Send attestationObject + keyId to your backend for verification
    return attestationObject
}
```

**Flow summary:**
1. Backend generates a one-time challenge
2. App calls `DCAppAttestService.attestKey()` with a hash of the challenge
3. Apple's servers return a signed attestation object
4. Your backend verifies the attestation with Apple and stores the `keyId`
5. On subsequent requests, use `generateAssertion()` with the stored `keyId`

> ℹ️ App Attest has a rate limit in development — use the `DCAppAttestService.shared.isSupported` check and degrade gracefully on simulators.

**References:** [Apple App Attest docs](https://developer.apple.com/documentation/devicecheck/establishing_your_app_s_integrity), [Human-readable guide](https://nshipster.com/app-attest/)

---

## M8 — Security Misconfiguration

Build configuration and platform settings must be reviewed before release.

- [ ] `debuggable` is `false` in the Android release build
- [ ] `kDebugMode` / `kReleaseMode` guards are used where relevant
- [ ] Firebase Remote Config / feature flags do not expose sensitive logic client-side
- [ ] Error messages shown to the user do not expose stack traces or internal details
- [ ] App runs on the minimum required OS version (avoid supporting EOL platforms)
- [ ] `flutter run --release` or `flutter build` used for store builds, never debug mode

**Example — guard debug-only code:**
```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  // only runs in debug builds
  print('Debug info: $sensitiveData');
}
```

---

## M9 — Insecure Data Storage

Sensitive data at rest must be protected appropriately.

- [ ] Sensitive data (tokens, user data) is stored in the platform keychain/keystore, not `SharedPreferences`
- [ ] No sensitive data written to plain-text files or the application cache
- [ ] Database contents are encrypted if they contain personal or financial data
- [ ] `flutter_secure_storage` is used for credentials and tokens
- [ ] Clipboard is cleared after copying sensitive data (or copying is disabled)
- [ ] Screenshots are disabled on sensitive screens (e.g. payment screens)

**Example — secure token storage:**
```dart
// flutter_secure_storage: ^9.x
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage();

// Write
await storage.write(key: 'auth_token', value: token);

// Read
final token = await storage.read(key: 'auth_token');

// Delete on logout
await storage.delete(key: 'auth_token');
```

**Example — disable screenshots on Android:**
```kotlin
// MainActivity.kt
window.setFlags(
  WindowManager.LayoutParams.FLAG_SECURE,
  WindowManager.LayoutParams.FLAG_SECURE
)
```

**Packages:** [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage), [`sqflite_sqlcipher`](https://pub.dev/packages/sqflite_sqlcipher) (encrypted DB)

---

## M10 — Insufficient Cryptography

Cryptographic implementations must follow current best practices.

- [ ] No custom/homebrew cryptographic algorithms
- [ ] Weak algorithms (MD5, SHA-1, DES) are not used for sensitive operations
- [ ] Encryption keys are not hardcoded in the source
- [ ] IVs (Initialization Vectors) are random and unique per encryption operation
- [ ] TLS version is 1.2 or higher (1.3 preferred)

**Example — AES-GCM encryption:**
```dart
// encrypt: ^5.x
import 'package:encrypt/encrypt.dart';

final key = Key.fromSecureRandom(32); // 256-bit key — store in secure storage
final iv = IV.fromSecureRandom(16);   // random IV per operation

final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
final encrypted = encrypter.encrypt(plainText, iv: iv);
final decrypted = encrypter.decrypt(encrypted, iv: iv);
```

**Packages:** [`encrypt`](https://pub.dev/packages/encrypt), [`pointycastle`](https://pub.dev/packages/pointycastle)

---

## Pre-Release Final Checks

- [ ] Run `flutter analyze` with zero errors/warnings
- [ ] Run `flutter test` — all tests pass
- [ ] Verified the release build on a physical device (not just an emulator)
- [ ] Reviewed all requested permissions in the final binary
- [ ] Checked store listing for privacy policy URL
- [ ] Verified GDPR / LGPD compliance if handling EU/BR user data
- [ ] ProGuard / obfuscation verified — crash reports are de-obfuscatable
- [ ] CI/CD pipeline uses secrets manager, not hardcoded credentials

---

## References

- [OWASP Mobile Top 10 2024](https://owasp.org/www-project-mobile-top-10/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)
- [Android Security Checklist](https://developer.android.com/topic/security/best-practices)
- [Apple App Store Review Guidelines — Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Google Play Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469)

''';
}
