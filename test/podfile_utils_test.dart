import 'package:moarch/src/utils/podfile_utils.dart';
import 'package:test/test.dart';

const _defaultPodfile = '''
platform :ios, '13.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
''';

void main() {
  group('ensurePermissionHandlerDefinitions', () {
    test('inserts after the anchor line, camera/photos uncommented', () {
      final output = PodfileUtils.ensurePermissionHandlerDefinitions(
        _defaultPodfile,
        camera: true,
        photos: true,
      );

      expect(output, contains("\n        'PERMISSION_CAMERA=1',"));
      expect(output, contains("\n        'PERMISSION_PHOTOS=1',"));
      expect(
        output.indexOf('flutter_additional_ios_build_settings(target)'),
        lessThan(output.indexOf('GCC_PREPROCESSOR_DEFINITIONS')),
      );
      // The inserted `end` closes target.build_configurations.each at the
      // same indentation it was opened with.
      expect(output, contains('    target.build_configurations.each do'));
      expect(output, contains('\n    end\n'));
    });

    test('comments disabled groups out entirely, not `=0`', () {
      final output = PodfileUtils.ensurePermissionHandlerDefinitions(
        _defaultPodfile,
        camera: false,
        photos: false,
      );

      // permission_handler gates on whether the macro is *defined*, so
      // disabling means the whole array entry is commented out.
      expect(output, contains("# 'PERMISSION_CAMERA=1',"));
      expect(output, contains("# 'PERMISSION_PHOTOS=1',"));
      expect(output, isNot(contains("'PERMISSION_CAMERA=0'")));
      expect(output, isNot(contains("'PERMISSION_PHOTOS=0'")));
      expect(output, contains("# 'PERMISSION_EVENTS=1',"));
    });

    test('is idempotent', () {
      final once = PodfileUtils.ensurePermissionHandlerDefinitions(
        _defaultPodfile,
        camera: true,
        photos: true,
      );

      expect(
        PodfileUtils.ensurePermissionHandlerDefinitions(
          once,
          camera: true,
          photos: true,
        ),
        equals(once),
      );
    });

    test('leaves a customized Podfile alone', () {
      const custom = '''
post_install do |installer|
  # user wired PERMISSION_CAMERA manually elsewhere
end
''';

      expect(
        PodfileUtils.ensurePermissionHandlerDefinitions(custom,
            camera: true, photos: true),
        equals(custom),
      );
    });

    test('skips files without the anchor', () {
      const noAnchor = "target 'Runner' do\nend\n";

      expect(
        PodfileUtils.ensurePermissionHandlerDefinitions(noAnchor,
            camera: true, photos: true),
        equals(noAnchor),
      );
    });
  });

  group('defaultPodfile', () {
    test('produces a Podfile with camera/photos uncommented', () {
      final output = PodfileUtils.defaultPodfile(camera: true, photos: true);

      expect(output, contains("target 'Runner' do"));
      expect(output, contains("target 'RunnerTests' do"));
      expect(output, contains("        'PERMISSION_CAMERA=1',"));
      expect(output, contains("        'PERMISSION_PHOTOS=1',"));
      expect(output, contains("# 'PERMISSION_EVENTS=1',"));
      expect(output, contains("CODE_SIGNING_ALLOWED"));
    });

    test('comments camera/photos out when MediaService is not selected', () {
      final output =
          PodfileUtils.defaultPodfile(camera: false, photos: false);

      expect(output, contains("# 'PERMISSION_CAMERA=1',"));
      expect(output, contains("# 'PERMISSION_PHOTOS=1',"));
      expect(output, isNot(contains("\n        'PERMISSION_CAMERA=1',")));
    });
  });
}
