import 'package:moarch/src/templates/misc/ios_templates.dart';
import 'package:moarch/src/templates/misc/workflow_templates.dart';
import 'package:test/test.dart';

void main() {
  test('buildIOS registers Firebase files in Xcode when requested', () {
    final output = WorkflowTemplates.buildIOS(withFirebase: true);

    expect(output, contains('run: gem install xcodeproj'));
    expect(output, contains('run: ruby add_files_to_xcode.rb'));
    // The registration must happen before the compile step.
    expect(
      output.indexOf('ruby add_files_to_xcode.rb'),
      lessThan(output.indexOf('flutter build ios --release --no-codesign')),
    );
  });

  test('buildIOS signs with push entitlements when requested', () {
    final output = WorkflowTemplates.buildIOS(withPushEntitlements: true);

    expect(
      output,
      contains('CODE_SIGN_ENTITLEMENTS="Runner/Runner.entitlements" \\'),
    );
    // Inside the archive invocation, before the signing identity.
    expect(
      output.indexOf('CODE_SIGN_ENTITLEMENTS'),
      lessThan(output.indexOf('CODE_SIGN_IDENTITY="Apple Development"')),
    );
  });

  test('buildIOS omits Firebase and entitlements by default', () {
    final output = WorkflowTemplates.buildIOS();

    expect(output, isNot(contains('xcodeproj')));
    expect(output, isNot(contains('CODE_SIGN_ENTITLEMENTS')));
  });

  test('entitlements templates declare the APNs environment', () {
    expect(IosTemplates.runnerEntitlements(),
        contains('<key>aps-environment</key>'));
    expect(IosTemplates.runnerEntitlements(), contains('</plist>'));
    expect(IosTemplates.runnerProfileEntitlements(),
        contains('<key>aps-environment</key>'));
  });

  test('xcode ruby script targets the Runner project and plist', () {
    final script = IosTemplates.addFilesToXcodeScript();

    expect(script, contains("project_path = 'ios/Runner.xcodeproj'"));
    expect(script, contains("files_to_add = ['GoogleService-Info.plist']"));
    expect(script, contains('project.save'));
  });
}
