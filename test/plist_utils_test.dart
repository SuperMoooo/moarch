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

    expect(PlistUtils.ensureLocalizations(withKey, ['en', 'pt']),
        equals(withKey));
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
}
