import 'package:moarch/src/utils/manifest_utils.dart';
import 'package:moarch/src/utils/platform_requirements.dart';
import 'package:test/test.dart';

/// The manifest `flutter create` writes, cut to what the patches touch.
const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="demo">
        <activity
            android:name=".MainActivity">
        </activity>
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
''';

const _plist = '''
<plist version="1.0">
<dict>
\t<key>CFBundleName</key>
\t<string>demo</string>
</dict>
</plist>
''';

void main() {
  test('media declares what permission_handler asks for', () {
    final out = PlatformRequirement.media.patchManifest(_manifest);

    expect(
      out,
      contains('<uses-permission android:name="android.permission.CAMERA"/>'),
    );
    expect(
      out,
      contains(
        '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>',
      ),
    );
    // Replaced by READ_MEDIA_IMAGES from API 33 on.
    expect(
      out,
      contains(
        '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" '
        'android:maxSdkVersion="32"/>',
      ),
    );
    expect(
      PlatformRequirement.media.patchPlist(_plist),
      contains('<key>NSCameraUsageDescription</key>'),
    );
  });

  test('local notifications get their receivers inside <application>', () {
    final out = PlatformRequirement.localNotifications.patchManifest(_manifest);

    final receiver = out.indexOf('ScheduledNotificationBootReceiver');
    expect(receiver, greaterThan(out.indexOf('<application')));
    expect(receiver, lessThan(out.indexOf('</application>')));
    expect(out, contains('android.permission.SCHEDULE_EXACT_ALARM'));
    expect(out, contains('android.permission.POST_NOTIFICATIONS'));
    // Google Play reserves it for alarm and calendar apps.
    expect(out, isNot(contains('USE_EXACT_ALARM')));
  });

  test('url_launcher intents join the queries flutter create wrote', () {
    final out = PlatformRequirement.urlLauncher.patchManifest(_manifest);

    expect('<queries>'.allMatches(out), hasLength(1));
    final mailto = out.indexOf('android:scheme="mailto"');
    expect(mailto, greaterThan(out.indexOf('PROCESS_TEXT')));
    expect(mailto, lessThan(out.indexOf('</queries>')));
  });

  test('a manifest without <queries> gets one above <application>', () {
    const bare =
        '<manifest>\n    <application>\n    </application>\n</manifest>\n';
    final out = ManifestUtils.ensureQueries(
      bare,
      intents: '        <intent/>',
      marker: '<intent/>',
    );

    expect(
      out,
      contains(
        '    <queries>\n        <intent/>\n    </queries>\n    <application>',
      ),
    );
  });

  test('every patch is idempotent, and reports itself declared after', () {
    for (final requirement in [
      PlatformRequirement.internet,
      PlatformRequirement.media,
      PlatformRequirement.localNotifications,
      PlatformRequirement.pushNotifications,
      PlatformRequirement.urlLauncher,
      PlatformRequirement.biometric,
    ]) {
      final once = requirement.patchManifest(_manifest);
      expect(
        requirement.patchManifest(once),
        once,
        reason: requirement.service,
      );
      expect(requirement.isDeclaredIn(once), isTrue);
      expect(requirement.isDeclaredIn(_manifest), isFalse);

      final plist = requirement.patchPlist(_plist);
      expect(requirement.isDescribedIn(plist), isTrue);
    }
  });

  test('a CRLF manifest keeps its line endings', () {
    final crlf = _manifest.replaceAll('\n', '\r\n');
    for (final requirement in [
      PlatformRequirement.media,
      PlatformRequirement.localNotifications,
      PlatformRequirement.urlLauncher,
    ]) {
      final out = requirement.patchManifest(crlf);
      expect(out.replaceAll('\r\n', ''), isNot(contains('\n')));
    }
  });
}
