import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Utility helpers for keeping generated project dependencies in sync.
///
/// All edits go through [YamlEditor] so existing formatting and comments in
/// the target pubspec are preserved.
class PubspecUtils {
  PubspecUtils._();

  /// Ensures default dependency entries are present in a target pubspec file.
  ///
  /// Entries already present (matched by package name) are left untouched,
  /// including their version constraints.
  static Future<void> ensureDependencies(
    String projectPath, {
    required List<String> dependencies,
    List<String> devDependencies = const <String>[],
  }) async {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));

    if (!await pubspecFile.exists()) {
      await pubspecFile.writeAsString(_defaultPubspec(
        dependencies: dependencies,
        devDependencies: devDependencies,
      ));
      return;
    }

    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);
    final root = loadYaml(content);

    _ensureSection(editor, root, 'dependencies', dependencies);
    _ensureSection(editor, root, 'dev_dependencies', devDependencies);

    await pubspecFile.writeAsString(editor.toString());
  }

  /// Ensures asset entries are present under the Flutter section of a target pubspec file.
  static Future<void> ensureAssets(String projectPath,
      {required List<String> assets}) async {
    if (assets.isEmpty) return;

    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));

    if (!await pubspecFile.exists()) {
      await pubspecFile.writeAsString(_defaultPubspec(
        dependencies: const <String>[],
        devDependencies: const <String>[],
        assets: assets,
      ));
      return;
    }

    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);
    final root = loadYaml(content);
    final flutterSection = root is Map ? root['flutter'] : null;
    final existingAssets =
        flutterSection is Map ? flutterSection['assets'] : null;

    if (flutterSection is! Map) {
      editor.update(['flutter'], {'assets': assets});
    } else if (existingAssets is! List) {
      editor.update(['flutter', 'assets'], assets);
    } else {
      final current = existingAssets.map((e) => '$e').toSet();
      for (final asset in assets) {
        if (!current.contains(asset)) {
          editor.appendToList(['flutter', 'assets'], asset);
        }
      }
    }

    await pubspecFile.writeAsString(editor.toString());
  }

  /// Ensures key: value flag entries are present directly under the flutter: section.
  static Future<void> ensureFlutterFlags(
    String projectPath, {
    required List<String> flags,
  }) async {
    if (flags.isEmpty) return;

    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) return;

    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);
    final root = loadYaml(content);
    final flutterSection = root is Map ? root['flutter'] : null;
    final parsed = _parseEntries(flags);

    if (flutterSection is! Map) {
      editor.update(['flutter'], parsed);
    } else {
      for (final entry in parsed.entries) {
        if (!flutterSection.containsKey(entry.key)) {
          editor.update(['flutter', entry.key], entry.value);
        }
      }
    }

    await pubspecFile.writeAsString(editor.toString());
  }

  static void _ensureSection(
    YamlEditor editor,
    Object? root,
    String section,
    List<String> entries,
  ) {
    if (entries.isEmpty) return;

    final parsed = _parseEntries(entries);
    final existing = root is Map ? root[section] : null;

    if (existing is! Map) {
      // Section missing (or empty/null) — create it with every entry.
      editor.update([section], parsed);
      return;
    }

    for (final entry in parsed.entries) {
      if (!existing.containsKey(entry.key)) {
        editor.update([section, entry.key], entry.value);
      }
    }
  }

  /// Parses entry strings such as `dio: ^5.10.0`, `dio:` or
  /// `flutter:\n    sdk: flutter` into a name → constraint map.
  static Map<String, Object?> _parseEntries(List<String> entries) {
    final result = <String, Object?>{};
    for (final entry in entries) {
      final parsed = loadYaml(entry);
      if (parsed is Map) {
        for (final e in parsed.entries) {
          result['${e.key}'] = _toPlain(e.value);
        }
      }
    }
    return result;
  }

  static Object? _toPlain(Object? node) {
    if (node is YamlMap) {
      return {for (final e in node.entries) '${e.key}': _toPlain(e.value)};
    }
    if (node is YamlList) return [for (final v in node) _toPlain(v)];
    return node;
  }

  static String _defaultPubspec({
    required List<String> dependencies,
    required List<String> devDependencies,
    List<String> assets = const <String>[],
  }) {
    final editor = YamlEditor('');
    editor.update([], {
      'name': 'app',
      'description': 'Generated by moarch',
      'version': '1.0.0+1',
      'environment': {'sdk': '>=3.0.0 <4.0.0'},
      'dependencies': _parseEntries(dependencies),
      'dev_dependencies': _parseEntries(devDependencies),
      'flutter': {
        if (assets.isNotEmpty) 'assets': assets,
      },
    });
    return editor.toString();
  }
}
