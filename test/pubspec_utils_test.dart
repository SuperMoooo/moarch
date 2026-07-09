import 'dart:io';

import 'package:moarch/src/utils/pubspec_utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory tempDir;

  Future<File> writePubspec(String content) async {
    final file = File(p.join(tempDir.path, 'pubspec.yaml'));
    await file.writeAsString(content);
    return file;
  }

  Future<YamlMap> readPubspec() async {
    final content =
        await File(p.join(tempDir.path, 'pubspec.yaml')).readAsString();
    return loadYaml(content) as YamlMap;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_pubspec_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  test('ensureAssets inserts assets under the root flutter section', () async {
    await writePubspec('''
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

    final doc = await readPubspec();
    final flutterSection = doc['flutter'] as YamlMap;
    expect(flutterSection['uses-material-design'], isTrue);
    expect(flutterSection['assets'], contains('assets/i18n/'));
    // The flutter *dependency* must not be confused with the flutter section.
    expect(
      (doc['dependencies'] as YamlMap)['flutter'],
      equals({'sdk': 'flutter'}),
    );
  });

  test('ensureDependencies adds missing entries and keeps existing pins',
      () async {
    await writePubspec('''
name: testing

dependencies:
  flutter:
    sdk: flutter
  dio: ^5.0.0
''');

    await PubspecUtils.ensureDependencies(
      tempDir.path,
      dependencies: ['dio: ^5.10.0', 'logger: ^2.7.0'],
      devDependencies: ['build_runner: ^2.15.1'],
    );

    final doc = await readPubspec();
    final deps = doc['dependencies'] as YamlMap;
    expect(deps['dio'], '^5.0.0', reason: 'existing pin must be untouched');
    expect(deps['logger'], '^2.7.0');
    expect((doc['dev_dependencies'] as YamlMap)['build_runner'], '^2.15.1');
  });

  test('ensureFlutterFlags adds missing keys under the flutter section',
      () async {
    await writePubspec('''
name: testing

flutter:
  uses-material-design: true
''');

    await PubspecUtils.ensureFlutterFlags(
      tempDir.path,
      flags: ['generate: true', 'uses-material-design: true'],
    );

    final doc = await readPubspec();
    final flutterSection = doc['flutter'] as YamlMap;
    expect(flutterSection['generate'], isTrue);
    expect(flutterSection['uses-material-design'], isTrue);
  });

  test('ensureDependencies creates a valid pubspec when none exists', () async {
    await PubspecUtils.ensureDependencies(
      tempDir.path,
      dependencies: ['flutter:\n    sdk: flutter', 'dio: ^5.10.0'],
      devDependencies: ['flutter_lints: ^6.0.0'],
    );

    final doc = await readPubspec();
    expect(doc['name'], 'app');
    expect((doc['dependencies'] as YamlMap)['dio'], '^5.10.0');
    expect(
      (doc['dependencies'] as YamlMap)['flutter'],
      equals({'sdk': 'flutter'}),
    );
    expect((doc['dev_dependencies'] as YamlMap)['flutter_lints'], '^6.0.0');
  });
}
