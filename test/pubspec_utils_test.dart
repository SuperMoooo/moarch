import 'dart:io';

import 'package:moarch/src/utils/pubspec_utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('ensureAssets inserts assets under the root flutter section', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('moarch_pubspec_test');
    addTearDown(() async => tempDir.delete(recursive: true));

    await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: testing

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''');

    await PubspecUtils.ensureAssets(tempDir.path, assets: ['assets/i18n/']);

    final content =
        await File(p.join(tempDir.path, 'pubspec.yaml')).readAsString();

    expect(
      content,
      contains(
          '''flutter:\n  assets:\n    - assets/i18n/\n  uses-material-design: true'''),
    );
    expect(content,
        isNot(contains('dependencies:\n  flutter:\n    - assets/i18n/')));
  });
}
