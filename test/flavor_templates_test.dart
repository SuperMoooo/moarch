import 'package:moarch/src/templates/config/flavor_templates.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  String render({List<String> flavors = const ['dev', 'staging', 'prod']}) =>
      FlavorTemplates.flavorizrYaml(
        appTitle: 'Cool Shop',
        androidId: 'com.acme.coolshop',
        iosId: 'com.acme.coolshop',
        flavors: flavors,
      );

  test('is valid YAML', () {
    expect(() => loadYaml(render()), returnsNormally);
  });

  test('prod ships under the bare id, the rest suffixed with their name', () {
    final doc = loadYaml(render()) as YamlMap;
    final flavors = doc['flavors'] as YamlMap;

    expect(flavors['prod']['android']['applicationId'], 'com.acme.coolshop');
    expect(flavors['prod']['ios']['bundleId'], 'com.acme.coolshop');
    expect(flavors['dev']['android']['applicationId'], 'com.acme.coolshop.dev');
    expect(flavors['staging']['ios']['bundleId'], 'com.acme.coolshop.staging');
  });

  test('prod keeps the plain app name, the rest are labelled', () {
    final doc = loadYaml(render()) as YamlMap;
    final flavors = doc['flavors'] as YamlMap;

    expect(flavors['prod']['app']['name'], 'Cool Shop');
    expect(flavors['dev']['app']['name'], 'Cool Shop Dev');
    expect(flavors['staging']['app']['name'], 'Cool Shop Staging');
  });

  test(
      'instructions run the native processors and flutter:flavors — '
      'never the processors that generate main_<flavor>.dart', () {
    final doc = loadYaml(render()) as YamlMap;
    final instructions = (doc['instructions'] as YamlList).cast<String>();

    expect(instructions, [
      'android:flavorizrGradle',
      'android:buildGradle',
      'android:androidManifest',
      'ios:xcconfig',
      'ios:plist',
      'flutter:flavors',
    ]);
    expect(instructions, isNot(contains('flutter:main')));
    expect(instructions, isNot(contains('flutter:app')));
    expect(instructions, isNot(contains('flutter:targets')));
  });

  test('follows a custom flavor list', () {
    final doc = loadYaml(render(flavors: ['qa', 'production'])) as YamlMap;
    final flavors = doc['flavors'] as YamlMap;

    expect(flavors.keys, ['qa', 'production']);
    // 'production' counts as the production flavor and keeps the bare id.
    expect(
        flavors['production']['android']['applicationId'], 'com.acme.coolshop');
    expect(flavors['qa']['android']['applicationId'], 'com.acme.coolshop.qa');
  });

  test('declares the flavor dimension Gradle requires', () {
    final doc = loadYaml(render()) as YamlMap;

    expect(doc['app']['android']['flavorDimensions'], 'flavor');
  });
}
