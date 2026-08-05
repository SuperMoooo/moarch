import 'package:moarch/src/utils/plist_utils.dart';
import 'package:test/test.dart';

const _samplePlist = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>app</string>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
</dict>
</plist>
''';

void main() {
  test('ensureLocalizations inserts CFBundleLocalizations before </dict>', () {
    final output = PlistUtils.ensureLocalizations(_samplePlist, ['en', 'pt']);

    expect(output, contains('<key>CFBundleLocalizations</key>'));
    expect(output, contains('\t\t<string>en</string>'));
    expect(output, contains('\t\t<string>pt</string>'));
    // Inserted inside the dict, keeping the plist well-formed.
    expect(output.indexOf('CFBundleLocalizations'),
        lessThan(output.lastIndexOf('</dict>')));
    expect(output, contains('</dict>\n</plist>'));
  });

  test('ensureLocalizations leaves an existing key untouched', () {
    final withKey = PlistUtils.ensureLocalizations(_samplePlist, ['en']);

    expect(
        PlistUtils.ensureLocalizations(withKey, ['en', 'pt']), equals(withKey));
  });

  test('ensureLocalizations returns content unchanged without a dict', () {
    expect(PlistUtils.ensureLocalizations('not a plist', ['en']),
        equals('not a plist'));
  });

  test('ensureArray inserts any key and skips existing ones', () {
    final output = PlistUtils.ensureArray(
      _samplePlist,
      'LSApplicationQueriesSchemes',
      ['https', 'tel'],
    );

    expect(output, contains('<key>LSApplicationQueriesSchemes</key>'));
    expect(output, contains('\t\t<string>https</string>'));
    expect(output, contains('\t\t<string>tel</string>'));

    // An existing array (here UISupportedInterfaceOrientations) is untouched.
    final rerun = PlistUtils.ensureArray(
      output,
      'UISupportedInterfaceOrientations',
      ['UIInterfaceOrientationLandscapeLeft'],
    );
    expect(rerun, equals(output));
  });

  test('ensureEntries adds only the missing usage descriptions', () {
    final output = PlistUtils.ensureEntries(_samplePlist, {
      'NSCameraUsageDescription': 'Camera use.',
      'NSMicrophoneUsageDescription': 'Microphone use.',
    });

    expect(output, contains('<key>NSCameraUsageDescription</key>'));
    expect(output, contains('\t<string>Camera use.</string>'));
    expect(output, contains('<key>NSMicrophoneUsageDescription</key>'));

    // Re-running with a changed description must not overwrite the original.
    final rerun = PlistUtils.ensureEntries(output, {
      'NSCameraUsageDescription': 'Different text.',
    });
    expect(rerun, equals(output));
  });

  group('ensureUrlScheme', () {
    const scheme = 'com.googleusercontent.apps.123-abc';

    test('creates CFBundleURLTypes when the plist has none', () {
      final output = PlistUtils.ensureUrlScheme(_samplePlist, scheme);

      expect(output, contains('<key>CFBundleURLTypes</key>'));
      expect(output, contains('<key>CFBundleURLSchemes</key>'));
      expect(output, contains('<string>$scheme</string>'));
      expect(output, contains('</dict>\n</plist>'));
    });

    test('adds to an existing CFBundleURLTypes rather than skipping it', () {
      final withDeepLink = PlistUtils.ensureUrlScheme(_samplePlist, 'myapp');
      final output = PlistUtils.ensureUrlScheme(withDeepLink, scheme);

      // Both schemes survive, under a single CFBundleURLTypes key.
      expect(output, contains('<string>myapp</string>'));
      expect(output, contains('<string>$scheme</string>'));
      expect(
        '<key>CFBundleURLTypes</key>'.allMatches(output).length,
        equals(1),
      );
    });

    test('is a no-op when the scheme is already registered', () {
      final output = PlistUtils.ensureUrlScheme(_samplePlist, scheme);

      expect(PlistUtils.ensureUrlScheme(output, scheme), equals(output));
    });

    test('writes the comment into the entry', () {
      final output = PlistUtils.ensureUrlScheme(
        _samplePlist,
        scheme,
        comment: 'replace me',
      );

      expect(output, contains('<!-- replace me -->'));
    });
  });

  test('readString lifts the value that follows a key', () {
    const googleServices = '''
<plist version="1.0">
<dict>
\t<key>CLIENT_ID</key>
\t<string>123-abc.apps.googleusercontent.com</string>
\t<key>REVERSED_CLIENT_ID</key>
\t<string>com.googleusercontent.apps.123-abc</string>
</dict>
</plist>
''';

    expect(
      PlistUtils.readString(googleServices, 'CLIENT_ID'),
      equals('123-abc.apps.googleusercontent.com'),
    );
    expect(
      PlistUtils.readString(googleServices, 'REVERSED_CLIENT_ID'),
      equals('com.googleusercontent.apps.123-abc'),
    );
    expect(PlistUtils.readString(googleServices, 'API_KEY'), isNull);
  });
}
