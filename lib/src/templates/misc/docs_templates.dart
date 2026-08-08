import 'android_templates.dart';

/// Generates release-checklist markdown templates.
class DocsTemplates {
  DocsTemplates._();

  /// Returns the generated prodChecklist template.
  static String prodChecklist() => r'''
# Production Checklist

What still needs doing before a release.

Anything already ticked is what `moarch init` put in place — it is listed
rather than dropped so you can see it was considered, not so you can do it
again. Everything unticked is yours. Items that depend on an option you may not
have selected say so.

---

## Flavors

`moarch create flavors` sets `dev` / `staging` / `prod` up for both platforms
through **flutter_flavorizr**, and keeps one `main.dart` — yours, untouched. It
runs the native-side processors only, generates `lib/flavors.dart`, and gives
non-production flavors suffixed ids so the builds install side by side. The
flavored entries `init` wrote into `.vscode/launch.json` start working as soon
as it has run.

- [ ] Flavors set up, if this project needs them (`moarch create flavors`)
- [ ] With Firebase: each suffixed application id registered in the console,
      then `flutterfire configure` re-run

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

- [x] `android/app/proguard-rules.pro` written, covering the Flutter engine,
      Firebase, OkHttp and coroutines
- [x] `android/key.properties`, `*.jks` and `*.keystore` are in `.gitignore` —
      the keystore cannot be committed by accident
- [ ] R8 actually turned on for the release build type — the rules above do
      nothing until it is. The gradle block is in
      `SECURITY_BEFORE_DEPLOYMENT.md`
- [ ] Correct `applicationId` in `android/app/build.gradle.kts`
- [ ] Correct `versionName` / `versionCode` (or a `version:` in `pubspec.yaml`
      that produces them)
- [ ] `targetSdk` meets the current Play requirement
- [ ] Release keystore created, and stored where you will not lose it — losing
      it means never updating the app on Play again. `GENERATE_JKS_FILE.md`
- [ ] Signing config reading `key.properties` — `GENERATE_JKS_FILE.md`
- [ ] `android:debuggable` not set in the manifest
- [ ] Built as an **app bundle** for Play (`flutter build appbundle`) — the
      generated `build_apk.yml` produces an APK, which is for testing and
      direct distribution, not for the store
- [ ] Tested on a physical device

## iOS

- [x] Usage descriptions in `Info.plist` for the options you selected — camera,
      photo library, microphone, Face ID, the push background mode
- [x] `Runner.entitlements` / `RunnerProfile.entitlements`, if you selected
      Firebase push
- [ ] Usage descriptions for any permission you added yourself (location,
      contacts, …) — `init` only writes the ones for its own options
- [ ] Correct Bundle ID in Xcode, and `PRODUCT_BUNDLE_IDENTIFIER` right per
      scheme
- [ ] Signing certificate and provisioning profile configured
- [ ] Icons and launch screen generated — the generated
      `flutter_native_splash.yaml` is the config, `dart run
      flutter_native_splash:create` is the step
- [ ] Push: capability on the App ID, APNs key uploaded to Firebase, and the
      provisioning profile regenerated **after** enabling the capability
- [ ] Tested on a physical device

## General

- [x] `debugShowCheckedModeBanner: false` in the generated app
- [x] Failures reach the UI as an `AppException` through `AppAsyncView` — no
      raw exception or stack trace is shown to a user
- [x] `flutter analyze` and `flutter test` gate every push, if you took the
      workflows
- [ ] The wording of those error messages reviewed — the generated defaults are
      deliberately generic
- [ ] `.env` filled in for production (`BASE_URL`, …), and the matching GitHub
      secrets set for CI
- [ ] `dart run build_runner build --delete-conflicting-outputs` run wherever
      you build — `config/env/app_env.g.dart` is gitignored by design, so it
      does not travel with a clone
- [ ] All `TODO` comments resolved — the REST datasources ship with them where
      your endpoints go
- [ ] Unused dependencies removed from `pubspec.yaml`
- [ ] App version and build number bumped
- [ ] `flutter build` runs without warnings
- [ ] Tested on both Android and iOS
- [ ] Crash reporting configured — the Crashlytics option wires it into the
      error handlers and the logger; without it nothing reports
- [ ] `.moarch.yaml` committed, so `moarch update` can still tell your edits
      from untouched generated files
- [ ] If you took the maintenance gate: the flag exists on the backend and
      reads `false`, and you have tried it once against a real build. A gate
      nobody has tested is one you will not trust on the day you need it
''';

  /// Returns the generated securityChecklist template.
  ///
  /// The ProGuard block is rendered from [AndroidTemplates.proguardRules] —
  /// the same string `init` writes to `android/app/proguard-rules.pro`, so the
  /// doc can never drift from the file the project actually builds with.
  static String securityChecklist() => '$_securityChecklistHead'
      '${AndroidTemplates.proguardRules()}'
      '$_securityChecklistTail';

  static const _securityChecklistHead = r'''

# Flutter App Store Security Checklist
> Based on [OWASP Mobile Top 10 (2024)](https://owasp.org/www-project-mobile-top-10/)

Use this checklist before publishing a Flutter app to the Google Play Store or Apple App Store. Each section maps to an OWASP Mobile risk.

Anything already ticked is what `moarch init` generated. Those lines are kept
rather than dropped so the mapping to OWASP stays complete and you can tell
"handled" from "never considered" — everything unticked is yours. Items that
depend on an option you may not have selected say so.

---

## M1 — Improper Credential Usage

Secrets and credentials must never be hardcoded or bundled in the binary.

- [x] Secrets are read through `envied`, not hardcoded — `config/env/app_env.dart`
- [x] `.env` and the generated `config/env/app_env.g.dart` are both in
      `.gitignore`
- [x] The environment is injected at CI time — every generated workflow writes
      `.env` from `secrets.BASE_URL` and runs `build_runner` before it builds
- [x] Leaked secrets are scanned for on every push — the `secrets` job in
      `unified_workflow.yml`
- [ ] `.env.example` committed with dummy values, so a fresh clone can see
      which keys it needs. `init` writes `.env`, not the example — copy it and
      blank the values
- [ ] `google-services.json` / `GoogleService-Info.plist` handled on purpose.
      They are deliberately *not* in the generated `.gitignore`: they hold
      client identifiers rather than server secrets, and most projects commit
      them. Decide, rather than defaulting
- [ ] Anything genuinely sensitive fetched from your backend at runtime instead
      of being compiled in at all — `obfuscate: true` raises the cost of
      pulling a value out of the binary, it does not make it impossible

**What the scaffold generates — `lib/config/env/app_env.dart`:**

`envied` reads `.env` at code-generation time and bakes obfuscated values into
the binary, so no `.env` file is bundled or shipped.

```dart
import 'package:envied/envied.dart';

part 'app_env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract final class AppEnv {
  @EnviedField(varName: 'BASE_URL', obfuscate: true)
  static final String baseUrl = _AppEnv.baseUrl;

  // Copy this pattern for additional environment values.
}
```

```bash
# Regenerate app_env.g.dart after every .env change
dart run build_runner build --delete-conflicting-outputs
```

> ⚠️ `app_env.g.dart` holds the compiled values and is gitignored, so it does
> not travel with a clone. That is why every generated workflow recreates `.env`
> from GitHub secrets and re-runs `build_runner` before `flutter build`.

**Packages:** [`envied`](https://pub.dev/packages/envied), [`envied_generator`](https://pub.dev/packages/envied_generator), [`build_runner`](https://pub.dev/packages/build_runner)

---

## M2 — Inadequate Supply Chain Security

Third-party packages can introduce vulnerabilities into your app.

- [x] CVEs gate the build — `osv-scan` runs on every push and
      `dependency-review` on every PR (`unified_workflow.yml`)
- [x] An SBOM (CycloneDX) and a `pana` license/health report are produced
      weekly and on every `v*` tag (`csa.yml`)
- [ ] `pubspec.lock` committed, so every machine and every CI run resolves the
      same versions
- [ ] New dependencies reviewed before adding — pub.dev score, publisher, last
      publish date
- [ ] `flutter pub outdated` run **and acted on** before each release; the CI
      jobs report, they do not upgrade
- [ ] No unused or abandoned packages left in `pubspec.yaml`
- [ ] Native dependencies (CocoaPods, Gradle) reviewed too — the scanners above
      only see the Dart graph

**Example — audit dependencies:**
```bash
flutter pub outdated
flutter pub upgrade --major-versions  # review breaking changes manually
```

---

## M3 — Insecure Authentication & Authorization

Authentication logic must be robust and not bypassable on the client side.

- [x] Biometrics go through the OS API — `core/security/biometric_service.dart`
      wraps `local_auth`, and `AppButton` gates a press on it through
      `beforePressed` (biometric option)
- [x] Tokens are refreshed rather than re-prompted — the Dio interceptor
      refreshes on a 401, replays the original request once, and signs the user
      out if the refresh itself fails (REST auth feature)
- [x] Logout clears the stored session — `TokenStorage.clearSession()` drops the
      access token, refresh token and user id
- [ ] The **server** invalidates the refresh token on logout too — clearing it
      on the device only stops that device from using it
- [ ] Authentication enforced server-side, never only on the client
- [ ] Access tokens genuinely short-lived; no client can make a long-lived
      token safe
- [ ] Role/permission checks on the backend, not in the Flutter UI — a hidden
      widget is not a permission check

**Example — the generated biometric gate:**
```dart
// Returns false and shows a snackbar on failure, so callers only need the bool.
final ok = await ref.read(biometricServiceProvider).verifyUserLocalAuth(context);
if (!ok) return;
```

**Packages:** [`local_auth`](https://pub.dev/packages/local_auth), [`firebase_auth`](https://pub.dev/packages/firebase_auth)

---

## M4 — Insufficient Input & Output Validation

All input entering or leaving the app must be validated and sanitised.

- [x] Form fields are validated client-side — `ValidationService` checks a
      value against an `InputType` and returns the cleaned form; `AppInput`
      calls it for you
- [x] Control characters, markup in free text, path traversal in file paths and
      non-http(s) URLs are rejected by that service rather than by each form
- [ ] The same rules enforced server-side. Client validation is UX; the server
      is the boundary
- [ ] No user input interpolated into SQL or shell commands — use parameterised
      queries. `ValidationService` deliberately does **not** blocklist SQL
      keywords: `O'Brien` is a name
- [ ] Deep link / URL parameters validated before use — routes are entry points
      an attacker controls
- [ ] Data from APIs, QR codes and NFC sanitised before it is rendered
- [ ] Anything rendered into a WebView escaped with
      `ValidationService.escapeHtml` — at the point you build the HTML, never
      on the way into storage

**Example — validating outside a form:**
```dart
final result = ValidationService.validate(raw, inputType: InputType.email);
if (!result.isValid) return showError(result.error!);
final email = result.sanitizedValue;
```

---

## M5 — Insecure Communication

All network traffic must be encrypted and verified.

- [x] Self-signed certificates are not accepted in production — the generated
      `dio_client.dart` installs its `badCertificateCallback` override inside an
      `if (kDebugMode)`, so a release build keeps full chain verification
- [ ] `BASE_URL` is `https://` in the production `.env` — nothing in the
      scaffold enforces the scheme for you
- [ ] Certificate pinning for sensitive endpoints — `_configureHttpClient` in
      `dio_client.dart` is the hook; see below
- [ ] Cleartext traffic disabled on Android (not generated — two steps below)
- [ ] iOS `NSAppTransportSecurity` does not allow arbitrary loads. `init` does
      not add the key, and ATS is on by default — only check this if you or a
      plugin added `NSAllowsArbitraryLoads`

**Example — certificate pinning, in the generated client:**
```dart
// core/network/dio_client.dart — replace the body of _configureHttpClient
import 'dart:io';

import 'package:dio/io.dart';

// Trust ONLY your server's certificate (bundle the .pem as an asset):
final context = SecurityContext(withTrustedRoots: false)
  ..setTrustedCertificatesBytes(certBytes);

dio.httpClientAdapter = IOHttpClientAdapter(
  createHttpClient: () => HttpClient(context: context),
);
```

> Pinning breaks the app the day the certificate rotates. Pin to the CA or to a
> backup key you control, and ship a way to turn it off.

**Packages:** [`dio`](https://pub.dev/packages/dio), [`http_certificate_pinning`](https://pub.dev/packages/http_certificate_pinning)

**Android — disabling cleartext traffic.** `init` does not write this; add both
halves or neither, since the attribute alone is ignored on newer API levels.

1. `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <base-config cleartextTrafficPermitted="false" />
</network-security-config>
```

2. Point the manifest at it, in `android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:usesCleartextTraffic="false"
    android:networkSecurityConfig="@xml/network_security_config"
    ... >
```

> Do this last. It also blocks a local `http://10.0.2.2` dev backend, so keep a
> debug-only override (`res/xml/network_security_config_debug.xml` referenced
> from a debug manifest) if you have one.

---

## M6 — Inadequate Privacy Controls

Apps must handle personal data with care and comply with GDPR / App Store privacy requirements.

- [x] Personal data is not logged in release builds — the generated logger
      drops debug/trace below `Level.warning` and redacts credentials at the
      sink
- [x] Permissions are requested at runtime, not assumed —
      `core/services/permission_service.dart`, with the media service asking
      only when it actually needs the camera or the library
- [x] Only the permissions your options need are compiled in — the generated
      `ios/Podfile` narrows `permission_handler` to camera and photos, instead
      of building every group and inheriting their usage-description
      requirements
- [ ] The manifest and `Info.plist` reviewed for permissions a *plugin* pulled
      in that you do not actually use
- [ ] Analytics and crash reporting configured not to collect PII — Crashlytics
      records what you pass it
- [ ] Privacy policy linked both in the store listing and inside the app
- [ ] Account deletion reachable from the UI (required by both stores). The
      generated auth feature has the call — REST `delete`, or Firebase account
      deletion — but no screen points at it
- [ ] Data Safety (Play) and the privacy nutrition label (App Store) filled in
      to match what the app really collects

**Example — what the generated `core/utils/app_logger.dart` already does:**
```dart
// Debug and trace records are stripped from release builds; warnings and
// errors survive so a crash report has context. Level.off silences release
// builds completely.
level: kReleaseMode ? Level.warning : Level.trace,
```

Credentials are redacted at the sink, so no call site has to remember to strip
them — `password`, `token`, `accessToken`, `refreshToken` and `Bearer …` values
are replaced with `***REDACTED***` on the way out. Add your own keys to
`_sensitiveKeyPattern` in that file when your API introduces them.

**Packages:** [`permission_handler`](https://pub.dev/packages/permission_handler), [`logger`](https://pub.dev/packages/logger)

---

## M7 — Insufficient Binary Protections

The compiled binary should be hardened against reverse engineering.

- [x] R8 keep rules configured for Android — `android/app/proguard-rules.pro`,
      written by `init` and reproduced below
- [x] The Android CI build obfuscates the Dart code — `build_apk.yml` passes
      `--obfuscate --split-debug-info=build/debug-info/android`
- [ ] R8 itself turned on. Writing the rules is not enabling them: without the
      gradle block below, the Java/Kotlin side is neither shrunk nor renamed
- [ ] Symbols kept. `build/debug-info/` is **not** uploaded by the generated
      workflow, so today it dies with the runner — see below
- [ ] The iOS CI build obfuscates too. `build_ipa.yml` compiles with
      `flutter build ios --release --no-codesign` and archives through
      `xcodebuild`, which does not carry the Dart obfuscation flags — see below
- [ ] App integrity / tamper detection, for high-risk apps

### Obfuscation

**Local release builds:**
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

> ⚠️ Store the `build/debug-info/` folder, one copy per released build. Without
> the symbols for *that exact build*, its crash stack traces stay unreadable in
> Crashlytics and in both store consoles — and you cannot regenerate them
> afterwards.

**Keeping the symbols in CI** — add to `build_apk.yml`, next to the APK upload:

```yaml
- name: Upload debug symbols
  uses: actions/upload-artifact@v4
  with:
      name: debug-info-android
      path: build/debug-info/
      retention-days: 90
```

> 90 days is an artifact retention limit, not a crash-report lifetime. For
> anything you actually shipped, move the folder somewhere permanent, or upload
> it to Crashlytics.

**Obfuscating the iOS build.** The `xcodebuild archive` step re-invokes the
Flutter tool through the Xcode build phase, so the flags on `flutter build ios`
do not reach it. Pass them to the archive instead:

```yaml
xcodebuild -workspace Runner.xcworkspace \
  ... \
  EXTRA_GEN_SNAPSHOT_OPTIONS="--obfuscate" \
  EXTRA_FRONT_END_OPTIONS="--obfuscate" \
  archive
```

Verify it worked before trusting it — build once with and once without, and
check that `flutter symbolize` is needed to read a stack trace from the
obfuscated one.

**`android/app/build.gradle.kts` — enable R8:**
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true      // enables R8 (shrink + obfuscate)
        isShrinkResources = true    // removes unused resources
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro",
        )
        signingConfig = signingConfigs.getByName("release")
        isDebuggable = false
    }
}
```

> Turn this on early in a release cycle, not the night before. R8 breaks
> reflective lookups the rules below do not cover, and it only shows up in a
> release build.

---

### ProGuard Rules — `android/app/proguard-rules.pro`

`moarch init` already writes this file — it sits there doing nothing until the
R8 block above turns minification on.

```proguard
''';

  static const _securityChecklistTail = r'''```

> Add rules incrementally — only suppress warnings (`-dontwarn`) for libraries you actually use. Run `./gradlew assembleRelease` and check the output for new warnings after each addition.

---

### App Integrity Verification

App integrity detects if your app has been tampered with, repackaged, or is running on an untrusted device. Use the **Play Integrity API** on Android and **DeviceCheck / App Attest** on iOS.

#### Android — Play Integrity API

```yaml
# pubspec.yaml — check pub.dev for the current package/version
# (e.g. play_integrity or play_integrity_flutter)
dependencies:
  play_integrity:
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

- [x] Debug-only behaviour is guarded by build mode, not by a flag someone can
      forget to flip — the logger's level and the Dio certificate override are
      both behind `kReleaseMode` / `kDebugMode`
- [x] Users never see a stack trace — every failure surfaces as an
      `AppException` with a message, rendered by `AppAsyncView`
- [ ] `isDebuggable = false` in the Android release build type
- [ ] The `AppException` messages reviewed. They are generic by design, but the
      ones you add per feature are where internal detail leaks back in
- [ ] Feature flags / Remote Config used for presentation only — a flag the
      client evaluates is a flag the client can flip
- [ ] `minSdk` and the iOS deployment target above the EOL versions
- [ ] Store builds produced by `flutter build`, never a debug binary

**Example — guard debug-only code:**
```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  // only runs in debug builds
  print('Debug info: $sensitiveData');
}
```

> The generated `app_logger.dart` is the better habit: it is already
> mode-aware, and it redacts credentials at the sink so no call site has to
> remember to.

---

## M9 — Insecure Data Storage

Sensitive data at rest must be protected appropriately.

- [x] Tokens live in the platform keychain/keystore, not `SharedPreferences` —
      `core/security/secure_storage.dart` wraps `flutter_secure_storage`
- [x] One owner for the session, so there is one place that clears it —
      `TokenStorage`, used by both the Dio client and the auth repository
- [ ] Nothing sensitive written to plain files, logs or the app cache by code
      you added
- [ ] Database contents encrypted if they hold personal or financial data —
      nothing in the scaffold encrypts a local DB
- [ ] Clipboard cleared after copying sensitive data, or copying disabled
- [ ] Screenshots disabled on sensitive screens (not generated — snippet below)

**Example — the generated session store:**
```dart
// core/security/secure_storage.dart
final storage = ref.read(tokenStorageProvider);

await storage.saveSession(accessToken: access, refreshToken: refresh);
final token = await storage.accessToken;
await storage.clearSession(); // on logout
```

**Example — disable screenshots on Android.** `init` does not add this; it
blocks the whole activity, including screens where a screenshot is legitimate,
so scope it to the routes that need it rather than setting it once at startup:

```kotlin
// MainActivity.kt — note moarch may already have made this a
// FlutterFragmentActivity for local_auth; keep whichever base class is there.
window.setFlags(
  WindowManager.LayoutParams.FLAG_SECURE,
  WindowManager.LayoutParams.FLAG_SECURE
)
```

> iOS has no equivalent flag. The usual approach is covering the window in
> `applicationWillResignActive` so the app-switcher snapshot shows a blank view.

**Packages:** [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage), [`sqflite_sqlcipher`](https://pub.dev/packages/sqflite_sqlcipher) (encrypted DB)

---

## M10 — Insufficient Cryptography

Cryptographic implementations must follow current best practices.

Nothing in the scaffold does its own cryptography — it stores tokens through
the platform keystore and talks TLS through the platform stack. Every item here
applies to code you add.

- [ ] No custom/homebrew cryptographic algorithms
- [ ] Weak algorithms (MD5, SHA-1, DES) are not used for sensitive operations
- [ ] Encryption keys are not hardcoded in the source, and not in `.env` either
      — `envied` obfuscates a value, it does not protect a key
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

- [x] `flutter analyze` and `flutter test` run on every push, if you took the
      workflows — the unit and integration suites are separate jobs
- [x] The CI pipeline reads credentials from GitHub secrets, never from the
      repository — `.env` is recreated per job and never committed
- [ ] Release build verified on a **physical** device, not only an emulator —
      obfuscation, R8 and signing all behave differently there
- [ ] The permissions in the final binary reviewed, not the ones you meant to
      request — check the merged manifest and the built `Info.plist`
- [ ] A crash from the release build symbolicated end to end, proving the
      archived symbols match what you shipped
- [ ] Privacy policy URL live and linked in both store listings
- [ ] GDPR / LGPD obligations met if you handle EU or BR user data
- [ ] `moarch doctor` clean, and `.moarch.yaml` committed

---

## References

- [OWASP Mobile Top 10 2024](https://owasp.org/www-project-mobile-top-10/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)
- [Android Security Checklist](https://developer.android.com/topic/security/best-practices)
- [Apple App Store Review Guidelines — Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Google Play Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469)

''';

  /// Returns the Android release-signing (JKS) guide.
  static String generateJKS() => r'''
# Android Release Signing (JKS)

## 1. Generate the keystore

```bash
keytool -genkeypair -v -keystore my-release-key.jks -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000
```

> ⚠️ Never commit the `.jks` file — the moarch-generated `.gitignore` rules
> already cover `*.jks` and `android/key.properties`. Store the keystore and
> its passwords in a password manager; losing it means you can never update
> the app on Google Play again.

Place the keystore in `android/app/` so `storeFile` can be a plain filename
(this matches what the build_apk workflow does in CI).

## 2. Create `android/key.properties`

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=my-key-alias
storeFile=my-release-key.jks
```

## 3. Wire it into `android/app/build.gradle.kts`

The `Properties`/`FileInputStream` imports at the top are required:

```kotlin
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // Only add this line if the project uses Firebase:
    // id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ...existing config...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as? String
            keyPassword = keystoreProperties["keyPassword"] as? String
            storeFile = (keystoreProperties["storeFile"] as? String)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as? String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

## 4. Get the certificate SHA fingerprints

Needed for Firebase, Google Sign-In, deep links, etc.:

```bash
keytool -list -v -keystore my-release-key.jks -alias my-key-alias
```
''';

  /// Returns the Firebase setup guide, with only the sections the project's
  /// selected options need.
  ///
  /// The generated Dart compiles immediately but nothing *runs* until the
  /// platform side is done, and each missed step fails without naming itself.
  static String firebaseSetup({
    bool withAuth = false,
    bool withGoogleSignIn = false,
    bool withFirestore = false,
    bool withCrashlytics = false,
    bool withMessaging = false,
  }) {
    final services = [
      if (withAuth) 'Authentication',
      if (withFirestore) 'Cloud Firestore',
      if (withCrashlytics) 'Crashlytics',
      if (withMessaging) 'Cloud Messaging',
    ].join(', ');

    final buffer = StringBuffer()
      ..writeln('# Firebase Setup')
      ..writeln()
      ..writeln('What this project needs on the Firebase and platform side '
          'before the generated')
      ..writeln('code runs. Services in use: $services.')
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln('## 1. Connect the project')
      ..writeln()
      ..writeln('```bash')
      ..writeln('dart pub global activate flutterfire_cli')
      ..writeln('flutterfire configure')
      ..writeln('```')
      ..writeln()
      ..writeln('This writes `lib/firebase_options.dart`, '
          '`android/app/google-services.json` and')
      ..writeln('`ios/Runner/GoogleService-Info.plist`, and adds the Gradle '
          'plugins Android needs.')
      ..writeln()
      ..writeln('Then pass the generated options in `lib/main.dart`:')
      ..writeln()
      ..writeln('```dart')
      ..writeln("import 'firebase_options.dart';")
      ..writeln()
      ..writeln('await Firebase.initializeApp(')
      ..writeln('  options: DefaultFirebaseOptions.currentPlatform,')
      ..writeln(');')
      ..writeln('```')
      ..writeln()
      ..writeln('> The config files carry no secret — the security boundary '
          'is your Firestore/Storage')
      ..writeln('> rules, not the file. Still, keep them out of a public repo '
          'to avoid quota abuse.')
      ..writeln();

    if (withAuth) {
      buffer
        ..writeln('---')
        ..writeln()
        ..writeln('## 2. Enable the sign-in methods')
        ..writeln()
        ..writeln('Firebase console → Authentication → Sign-in method:')
        ..writeln()
        ..writeln('- **Email/Password** — enable it.');
      if (withGoogleSignIn) {
        buffer
          ..writeln('- **Google** — enable it, and note the *Web SDK '
              'configuration* client id shown')
          ..writeln('  there. That is the `serverClientId` the Android and '
              'web flows exchange for an')
          ..writeln('  ID token.')
          ..writeln()
          ..writeln('Anything Firebase rejects arrives as an `AppException` '
              'with the message already')
          ..writeln('written for the user — see '
              '`AppException.fromFirebaseAuthError`.');
      }
      buffer.writeln();
    }

    if (withGoogleSignIn) {
      buffer
        ..writeln('---')
        ..writeln()
        ..writeln('## 3. Google sign-in — Android')
        ..writeln()
        ..writeln('Google checks the signing certificate of the APK, so every '
            'certificate that ever')
        ..writeln('signs a build needs its fingerprint registered: your debug '
            'keystore, your release')
        ..writeln('keystore, and Play App Signing if you use it (Play Console '
            '→ Setup → App signing).')
        ..writeln()
        ..writeln('```bash')
        ..writeln('# debug')
        ..writeln(r'keytool -list -v -alias androiddebugkey \')
        ..writeln(r'  -keystore ~/.android/debug.keystore \')
        ..writeln('  -storepass android -keypass android')
        ..writeln()
        ..writeln('# release')
        ..writeln('keytool -list -v -keystore my-release-key.jks '
            '-alias my-key-alias')
        ..writeln('```')
        ..writeln()
        ..writeln('Paste **SHA-1 and SHA-256** into Firebase console → '
            'Project settings → your Android')
        ..writeln('app, then **re-download `google-services.json`** — it '
            'changes when you add them.')
        ..writeln()
        ..writeln('Symptom of a missing fingerprint: the account picker '
            'opens, and sign-in fails')
        ..writeln('immediately afterwards with no visible reason.')
        ..writeln()
        ..writeln('---')
        ..writeln()
        ..writeln('## 4. Google sign-in — iOS')
        ..writeln()
        ..writeln('The plugin does **not** read `GoogleService-Info.plist`. '
            'Two values have to be')
        ..writeln('copied out of it into `ios/Runner/Info.plist` — '
            '`moarch init` puts them there when')
        ..writeln('the file already exists, and `moarch doctor --fix` fills '
            'them in afterwards.')
        ..writeln()
        ..writeln('| GoogleService-Info.plist | Info.plist |')
        ..writeln('|---|---|')
        ..writeln('| `CLIENT_ID` | `GIDClientID` |')
        ..writeln('| `REVERSED_CLIENT_ID` | a `CFBundleURLSchemes` entry |')
        ..writeln()
        ..writeln('```xml')
        ..writeln('<key>GIDClientID</key>')
        ..writeln('<string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>')
        ..writeln('<key>CFBundleURLTypes</key>')
        ..writeln('<array>')
        ..writeln('  <dict>')
        ..writeln('    <key>CFBundleTypeRole</key>')
        ..writeln('    <string>Editor</string>')
        ..writeln('    <key>CFBundleURLSchemes</key>')
        ..writeln('    <array>')
        ..writeln(
            '      <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>')
        ..writeln('    </array>')
        ..writeln('  </dict>')
        ..writeln('</array>')
        ..writeln('```')
        ..writeln()
        ..writeln('Symptom of a missing URL scheme: the sign-in sheet opens '
            'and never returns.')
        ..writeln()
        ..writeln('---')
        ..writeln()
        ..writeln('## 5. Google sign-in — web and desktop')
        ..writeln()
        ..writeln('There is no native config to read from, so set '
            '`kGoogleServerClientId` in')
        ..writeln(
            '`lib/features/auth/data/datasources/auth_remote_datasource.dart` '
            'to the web client')
        ..writeln('id from step 2. On the web there is also no interactive '
            '`authenticate()` — render')
        ..writeln("the package's own button and pass the credential you get "
            'back to')
        ..writeln('`FirebaseAuth.signInWithCredential`. The generated code '
            'raises a clear error')
        ..writeln('rather than failing silently there.')
        ..writeln();
    }

    if (withFirestore) {
      buffer
        ..writeln('---')
        ..writeln()
        ..writeln('## Firestore rules')
        ..writeln()
        ..writeln('A new database starts in test mode, which stops working '
            'after 30 days and lets')
        ..writeln('anyone read everything until it does. Start from the '
            'user-scoped shape instead:')
        ..writeln()
        ..writeln('```')
        ..writeln('rules_version = "2";')
        ..writeln('service cloud.firestore {')
        ..writeln('  match /databases/{database}/documents {')
        ..writeln('    match /users/{userId} {')
        ..writeln('      allow read, write: if request.auth != null')
        ..writeln('                         && request.auth.uid == userId;')
        ..writeln('    }')
        ..writeln('    // TODO: one rule per collection. Nothing is readable '
            'by default.')
        ..writeln('  }')
        ..writeln('}')
        ..writeln('```')
        ..writeln()
        ..writeln('A rejected read arrives as an `AppException` of type '
            '`auth` ("You don\'t have')
        ..writeln('access to this data") — if you see that in development, '
            'it is the rules.')
        ..writeln();
    }

    buffer
      ..writeln('---')
      ..writeln()
      ..writeln('## Check the wiring')
      ..writeln()
      ..writeln('```bash')
      ..writeln('moarch doctor        # reports what is missing')
      ..writeln('moarch doctor --fix  # applies what can be applied')
      ..writeln('```');

    return buffer.toString();
  }

  /// Returns the CI/CD secrets setup guide for the build workflows.
  static String stepsForWorkflow() => r'''
# CI/CD Workflow Setup

Steps to produce every GitHub secret the generated workflows need
(Settings → Secrets and variables → Actions).

## Secrets overview

| Secret | Used by | Value |
|---|---|---|
| `BASE_URL` | all workflows | your API base URL |
| `IOS_P12_BASE64` | build_ipa | base64 of your `.p12` (cert + key) |
| `IOS_P12_PASSWORD` | build_ipa | password you set when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | build_ipa | base64 of your `.mobileprovision` |
| `IOS_TEAM_ID` | build_ipa | Apple Developer Team ID |
| `ANDROID_KEYSTORE_BASE64` | build_apk | base64 of your `.jks` keystore |
| `KEYSTORE_STORE_PASSWORD` | build_apk | keystore store password |
| `KEYSTORE_KEY_PASSWORD` | build_apk | key password |
| `KEYSTORE_KEY_ALIAS` | build_apk | key alias (e.g. `my-key-alias`) |

---

## iOS — signing certificate (.p12) without a Mac

Requires OpenSSL (e.g. installed at `C:\openssl` on Windows).

```bash
cd C:\openssl\<temp folder to store the output>

# 1. Private key
openssl genrsa -out <name_key>.key 2048

# 2. Certificate signing request (upload the .certSigningRequest at
#    developer.apple.com → Certificates → +)
openssl req -new -key <name_key>.key -out <name_app>.certSigningRequest -subj "/emailAddress=YOUR_EMAIL/CN=YOUR_NAME/C=YOUR_COUNTRY_CODE" -config C:\openssl\openssl.cnf

# (verify the CSR)
openssl req -in <name_app>.certSigningRequest -noout -subject

# 3. Download the issued .cer from Apple, convert it to PEM
openssl x509 -in <name>.cer -inform DER -out <name>.pem -outform PEM

# 4. Bundle key + cert into a .p12
openssl pkcs12 -export -inkey <key_name>.key -in <name>.pem -out <name>.p12 -password pass:YOUR_CHOSEN_PASSWORD

# ...or, if the runner rejects the p12, use legacy encryption:
openssl pkcs12 -export -inkey <key_name>.key -in <name>.pem -out <name>.p12 -password pass:YOUR_CHOSEN_PASSWORD -legacy

# (verify the p12)
openssl pkcs12 -info -in <p12file>.p12 -noout -password pass:YourExactPassword
```

Create the provisioning profile at developer.apple.com → Profiles, using the
same certificate and your app's bundle ID, then download it.

Base64-encode both files (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\<name>.p12")) | Out-File p12_base64.txt -NoNewline
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\YourProfile.mobileprovision")) | Out-File profile_base64.txt -NoNewline
```

## iOS — extra steps for Firebase push (FCM)

Only needed when the project uses Firebase push notifications:

1. In developer.apple.com → Identifiers, enable the **Push Notifications**
   capability on the app's App ID, then regenerate the provisioning profile
   (a profile created before the capability was enabled won't include the
   `aps-environment` entitlement and codesigning will fail).
2. Upload your **APNs key** (.p8) in Firebase console → Project settings →
   Cloud Messaging.
3. `ios/Runner/Runner.entitlements` and `RunnerProfile.entitlements` are
   generated by moarch; the build_ipa workflow signs the archive with them.
4. Run `flutterfire configure` so `ios/Runner/GoogleService-Info.plist`
   exists — the workflow's "Register files in Xcode" step
   (`add_files_to_xcode.rb`) links it into the Xcode project.

---

## Android — release keystore

Generate the `.jks` first (see `GENERATE_JKS_FILE.md`), then base64-encode it
(PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("<name>.jks")) | Out-File release-key-base64.txt
```

Add the four `ANDROID_*`/`KEYSTORE_*` secrets from the table above.
''';
}
