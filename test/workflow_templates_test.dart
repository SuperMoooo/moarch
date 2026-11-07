import 'package:moarch/src/templates/misc/ios_templates.dart';
import 'package:moarch/src/templates/misc/workflow_templates.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('buildIOS registers Firebase files in Xcode when requested', () {
    final output = WorkflowTemplates.buildIOS(withFirebase: true);

    expect(output, contains('run: gem install xcodeproj'));
    expect(output, contains('run: ruby add_files_to_xcode.rb'));
    // The registration must happen before the compile step.
    expect(
      output.indexOf('ruby add_files_to_xcode.rb'),
      lessThan(output.indexOf('flutter build ios --config-only')),
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
      lessThan(output.indexOf(r'CODE_SIGN_IDENTITY="$IDENTITY"')),
    );
  });

  test('buildIOS omits Firebase and entitlements by default', () {
    final output = WorkflowTemplates.buildIOS();

    expect(output, isNot(contains('xcodeproj')));
    expect(output, isNot(contains('CODE_SIGN_ENTITLEMENTS')));
  });

  test('buildIOS compiles once, on the macOS runner', () {
    final output = WorkflowTemplates.buildIOS();

    // Configure only, then the archive is the one build.
    expect(output, contains('flutter build ios --config-only --release'));
    expect(output, isNot(contains('--no-codesign')));
    expect('xcodebuild -workspace'.allMatches(output), hasLength(1));
    // The secrets check runs on Linux, so a fork without them pays nothing.
    expect(
      output.indexOf('runs-on: ubuntu-latest'),
      lessThan(output.indexOf('runs-on: macos-latest')),
    );
    expect(output, contains('timeout-minutes: 45'));
  });

  test('buildIOS obfuscates and keeps the symbols of the build', () {
    final output = WorkflowTemplates.buildIOS();

    expect(output, contains('--obfuscate --split-debug-info='));
    expect(output, contains('name: Upload debug symbols'));
    // The build number is pubspec.yaml's, raised by `moarch release bump`.
    expect(output, isNot(contains('--build-number')));
  });

  test('buildIOS signs for the export method picked at dispatch', () {
    final output = WorkflowTemplates.buildIOS();

    expect(output, contains('options: [development, ad-hoc, app-store]'));
    expect(output, contains('EXPORT_METHOD=debugging'));
    expect(output, contains('EXPORT_METHOD=release-testing'));
    expect(output, contains('EXPORT_METHOD=app-store-connect'));
    expect(output, contains(r'<string>$EXPORT_METHOD</string>'));
  });

  test('buildIOS uploads to TestFlight only with app-store and a key', () {
    final output = WorkflowTemplates.buildIOS();

    expect(
      output,
      contains(
        "if: inputs.export_method == 'app-store' && "
        "needs.check-ios-secrets.outputs.has_app_store_key == 'true'",
      ),
    );
    expect(output, contains('xcrun altool --upload-app --type ios'));
    // The key is removed with the keychain, whatever happened.
    expect(output, contains('rm -rf ~/.appstoreconnect/private_keys'));
  });

  test('every workflow parses as YAML, in every variant', () {
    for (final output in [
      WorkflowTemplates.unifiedWorkflow(),
      WorkflowTemplates.csaWorkflow(),
      WorkflowTemplates.buildIOS(),
      WorkflowTemplates.buildIOS(
        withFirebase: true,
        withPushEntitlements: true,
      ),
    ]) {
      final doc = loadYaml(output) as YamlMap;
      expect(doc['jobs'], isA<YamlMap>());
    }
  });

  test('no workflow runs on a schedule', () {
    for (final output in [
      WorkflowTemplates.unifiedWorkflow(),
      WorkflowTemplates.csaWorkflow(),
      WorkflowTemplates.buildIOS(),
    ]) {
      expect(output, isNot(contains('schedule:')));
      expect(output, isNot(contains('cron:')));
    }
  });

  test('CI analyzes and checks formatting once, and cancels stale runs', () {
    final output = WorkflowTemplates.unifiedWorkflow();

    expect('flutter analyze'.allMatches(output), hasLength(1));
    expect(
      output,
      contains('dart format --output=none --set-exit-if-changed .'),
    );
    expect(output, isNot(contains('sast')));
    expect(output, isNot(contains('osv')));
    expect(output, contains('cancel-in-progress: true'));
  });

  test('entitlements templates declare the APNs environment', () {
    expect(
      IosTemplates.runnerEntitlements(),
      contains('<key>aps-environment</key>'),
    );
    expect(IosTemplates.runnerEntitlements(), contains('</plist>'));
    expect(
      IosTemplates.runnerProfileEntitlements(),
      contains('<key>aps-environment</key>'),
    );
  });

  test('xcode ruby script targets the Runner project and plist', () {
    final script = IosTemplates.addFilesToXcodeScript();

    expect(script, contains("project_path = 'ios/Runner.xcodeproj'"));
    expect(script, contains("files_to_add = ['GoogleService-Info.plist']"));
    expect(script, contains('project.save'));
  });
}
