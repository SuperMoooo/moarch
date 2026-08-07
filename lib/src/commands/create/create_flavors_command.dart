import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../templates/config/flavor_templates.dart';
import '../../utils/file_utils.dart';
import '../../utils/project_manifest.dart';
import '../../utils/pubspec_utils.dart';

/// Sets a project up for flavors via [flutter_flavorizr], without touching
/// `lib/main.dart`.
///
/// moarch's side is the configuration: a `flavorizr.yaml` whose
/// `instructions` run only the native-side processors plus `flutter:flavors`,
/// and the `flutter_flavorizr` dev dependency. The user then runs
/// `dart run flutter_flavorizr` — which patches Gradle, the Android manifest
/// and the iOS xcconfig/plist, and generates `lib/flavors.dart`. The project
/// keeps its single `main.dart`; no `main_<flavor>.dart` files are created.
///
/// [flutter_flavorizr]: https://pub.dev/packages/flutter_flavorizr
class CreateFlavorsCommand extends Command<int> {
  /// Creates the flavors command.
  CreateFlavorsCommand({required Logger logger}) : _logger = logger {
    argParser.addOption(
      'path',
      abbr: 'p',
      defaultsTo: '.',
      help: 'Target project path (defaults to current directory).',
    );
  }

  final Logger _logger;

  /// The flavor set generated when none is named — the same trio the
  /// `.vscode/launch.json` written by `moarch init` already has entries for.
  static const List<String> defaultFlavors = ['dev', 'staging', 'prod'];

  @override
  String get name => 'flavors';

  @override
  String get description =>
      'Set up flutter_flavorizr flavors (single main.dart, native side patched '
      'by the package).';

  @override
  String get invocation => 'moarch create flavors [<name>...]';

  @override
  Future<int> run() async {
    final root = p.absolute(argResults?['path'] as String? ?? '.');
    final rest = argResults?.rest ?? const <String>[];
    final flavors = rest.isEmpty ? defaultFlavors : rest;

    final invalid =
        flavors.where((f) => !RegExp(r'^[a-z][a-z0-9]*$').hasMatch(f)).toList();
    if (invalid.isNotEmpty) {
      _logger.err('Invalid flavor name(s): ${invalid.join(', ')}');
      _logger.info('  Flavor names must be lowercase letters/digits — they '
          'become Gradle flavor names and bundle id suffixes.');
      return 1;
    }

    final pubspecFile = File(p.join(root, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      _logger.err('No pubspec.yaml at $root — is this a Flutter project?');
      return 1;
    }

    final appTitle = _appTitle(pubspecFile);
    final androidId = _androidApplicationId(root);
    final iosId = _iosBundleId(root) ?? androidId;

    _logger.info('');
    _logger.info('🧱 moarch — flavors: ${flavors.join(', ')}');
    _logger.info('   app name: $appTitle');
    _logger.info('   android:  $androidId   ios: $iosId');
    _logger.info('');

    if (!Directory(p.join(root, 'android')).existsSync()) {
      _logger.warn('  android/ not found — flavorizr\'s Android processors '
          'will have nothing to patch.');
    }
    if (!Directory(p.join(root, 'ios')).existsSync()) {
      _logger.warn('  ios/ not found — flavorizr\'s iOS processors '
          'will have nothing to patch.');
    }

    final configPath = p.join(root, 'flavorizr.yaml');
    final content = FlavorTemplates.flavorizrYaml(
      appTitle: appTitle,
      androidId: androidId,
      iosId: iosId,
      flavors: flavors,
    );

    final progress = _logger.progress('Writing flavor configuration');
    FileUtils.beginSession();

    final manifest = ProjectManifest.loadOrCreate(root);
    bool wrote;
    try {
      wrote = await FileUtils.writeFile(configPath, content);
      if (wrote) {
        manifest.record(root, configPath, content);
        await manifest.save(root);
      }
      await PubspecUtils.ensureDependencies(
        root,
        dependencies: const [],
        devDependencies: ['flutter_flavorizr: '],
      );
      progress.complete('Done');
    } catch (e) {
      progress.fail('Failed: $e');
      FileUtils.rollback();
      return 1;
    }

    _logger.success('');
    if (wrote) {
      _logger.info('  + flavorizr.yaml');
    } else {
      _logger.info('  · flavorizr.yaml already exists — left untouched.');
      _logger.info('    Delete it and re-run to regenerate.');
    }
    _logger.info('  + flutter_flavorizr added to dev_dependencies');
    _logger.info('');
    _logger.info('  Review the app names and ids in flavorizr.yaml, then:');
    _logger.info('    1. flutter pub get');
    _logger.info('    2. dart run flutter_flavorizr');
    _logger.info('       (patches Gradle/manifest/xcconfig/plist and generates '
        'lib/flavors.dart');
    _logger.info('        — lib/main.dart is not touched)');
    _logger.info('    3. flutter run --flavor ${flavors.first}');
    _logger.info('');
    if (flavors.toSet().containsAll(defaultFlavors)) {
      _logger.info('  The flavored entries in .vscode/launch.json (dev, '
          'staging, prod) now work.');
    }
    // Each flavor is its own application id, and Firebase config is keyed by
    // application id — a suffixed flavor without its own entry fails at
    // Firebase.initializeApp.
    final pubspec = pubspecFile.readAsStringSync();
    if (pubspec.contains('firebase_core:')) {
      _logger.warn('  Firebase: each flavor\'s id needs its own app in the '
          'Firebase project');
      _logger.info('    (google-services.json carries all of them; re-run '
          '`flutterfire configure` and register the suffixed ids).');
    }
    _logger.info('');
    return 0;
  }

  /// The app's display name, title-cased from the pubspec `name` field
  /// (`my_app` → `My App`).
  String _appTitle(File pubspecFile) {
    try {
      final doc = loadYaml(pubspecFile.readAsStringSync());
      final name = doc is Map ? '${doc['name']}' : 'App';
      final words = name
          .split(RegExp(r'[_\-\s]+'))
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}');
      return words.isEmpty ? 'App' : words.join(' ');
    } catch (_) {
      return 'App';
    }
  }

  /// The `applicationId` declared in `android/app/build.gradle(.kts)`, or a
  /// placeholder the user is told to review.
  String _androidApplicationId(String root) {
    for (final file in [
      File(p.join(root, 'android', 'app', 'build.gradle.kts')),
      File(p.join(root, 'android', 'app', 'build.gradle')),
    ]) {
      if (!file.existsSync()) continue;
      final match = RegExp(r'''applicationId\s*=?\s*["']([^"']+)["']''')
          .firstMatch(file.readAsStringSync());
      if (match != null) return match.group(1)!;
    }
    return 'com.example.app';
  }

  /// The `PRODUCT_BUNDLE_IDENTIFIER` from the Xcode project, when the iOS
  /// folder exists — usually the Android id, but not guaranteed to be.
  String? _iosBundleId(String root) {
    final pbxproj =
        File(p.join(root, 'ios', 'Runner.xcodeproj', 'project.pbxproj'));
    if (!pbxproj.existsSync()) return null;
    final match =
        RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;\s]+);', multiLine: true)
            .firstMatch(pbxproj.readAsStringSync());
    // The RunnerTests target's id ends in .RunnerTests — strip that rather
    // than hand back the test bundle when it happens to match first.
    final id = match?.group(1)?.replaceAll('"', '');
    if (id == null) return null;
    return id.endsWith('.RunnerTests')
        ? id.substring(0, id.length - '.RunnerTests'.length)
        : id;
  }
}
