/// Generates what deep links need beyond the router: the Android intent
/// filter and `docs/DEEP_LINKS.md`, which walks through the iOS capability
/// and the two files the domain has to host.
///
/// GoRouter handles the link itself: Flutter hands the platform's URL to the
/// router (on by default since Flutter 3.27), so a link to
/// `https://<host>/orders` opens `AppRoutes.orders` with no package and no
/// code.
class DeepLinksTemplates {
  DeepLinksTemplates._();

  /// The domain written until the project's own replaces it. `doctor` notes
  /// it while it is still there.
  static const String placeholderHost = 'example.com';

  /// The `<intent-filter>` that makes Android open `https://[host]` links in
  /// the app, indented to sit inside `MainActivity`'s `<activity>`.
  ///
  /// `autoVerify` is what makes it an App Link — opened without the "open
  /// with" chooser — once the domain serves `assetlinks.json`.
  static String androidIntentFilter(String host) =>
      '''
            <!-- App Links: https://$host/... opens the app at that route.
                 Change the host to your domain, and serve
                 /.well-known/assetlinks.json from it (docs/DEEP_LINKS.md). -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="$host"/>
            </intent-filter>''';

  /// `docs/DEEP_LINKS.md`: the steps no file in the repository can take —
  /// the domain's two files, the Apple capability, the signing fingerprint.
  ///
  /// [androidApplicationId] and [iosBundleId] fill in the JSON when the
  /// project has them; otherwise the placeholders say what goes there.
  static String doc({
    String? androidApplicationId,
    String? iosBundleId,
    bool withAuthFeature = false,
  }) {
    final androidId = androidApplicationId ?? '<your.application.id>';
    final bundleId = iosBundleId ?? '<your.bundle.id>';
    const host = placeholderHost;

    final authNote = withAuthFeature
        ? '''

## Signed-out users

A link to a route that needs a session sends a signed-out user to login and
then on to where the link pointed (`?from=` in the router's redirect). The
same holds on a cold start, while the session is still being restored on the
splash route. Only in-app paths are followed, so `from` cannot send anyone
off the app.
'''
        : '';

    return '''
# Deep links

`https://$host/orders` opens the app on `AppRoutes.orders` — Android App Links
and iOS Universal Links, handled by GoRouter. Nothing in Dart needs changing:
Flutter hands the link's path to the router, and every route in
`lib/config/router/` is reachable.

What is left is proving to each platform that the domain is yours.

## 1. Your domain

Replace `$host` with your domain in:

- `android/app/src/main/AndroidManifest.xml` — the `<intent-filter
  android:autoVerify="true">` in `MainActivity`.
- The iOS capability below.

## 2. Android — `assetlinks.json`

Serve this at `https://$host/.well-known/assetlinks.json`, as
`application/json`, with no redirect:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "$androidId",
      "sha256_cert_fingerprints": ["<SHA-256 of your signing certificate>"]
    }
  }
]
```

The fingerprint is the **release** signing key's
(`keytool -list -v -keystore <your.jks> -alias <alias>`, see
`docs/GENERATE_JKS_FILE.md`). With Play App Signing, use the one Play Console
shows under *Setup → App signing* instead — or both. A debug build is signed
with the debug key, so add its fingerprint too while testing:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

Check it with:

```bash
adb shell pm verify-app-links --re-verify $androidId
adb shell pm get-app-links $androidId
```

## 3. iOS — Associated Domains

1. In the Apple Developer portal, enable **Associated Domains** on the App ID
   `$bundleId`, and regenerate its provisioning profiles.
2. In Xcode, *Runner → Signing & Capabilities → + Capability → Associated
   Domains*, and add `applinks:$host`.
3. Serve this at `https://$host/.well-known/apple-app-site-association` (no
   extension, `application/json`, no redirect):

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["<TEAM_ID>.$bundleId"],
        "components": [{ "/": "/*" }]
      }
    ]
  }
}
```

`<TEAM_ID>` is on the portal's *Membership* page. Apple's CDN caches the file,
so a change can take a while to reach devices.

## Try it

```bash
# Android
adb shell am start -a android.intent.action.VIEW -d "https://$host/orders"
# iOS simulator
xcrun simctl openurl booted "https://$host/orders"
```

## Writing routes that links can open
$authNote
A link carries only its URL. A route opened from one has no `extra` and no
state from the screen that would normally push it, so everything a screen
needs to load has to be in the path or the query: `/orders/42`, not
`extra: order`. Load the rest from the id.
''';
  }
}
