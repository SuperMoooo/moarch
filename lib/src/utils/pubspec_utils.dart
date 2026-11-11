import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'package_versions.dart';

/// Utility helpers for keeping generated project dependencies in sync.
///
/// All edits go through [YamlEditor] so existing formatting and comments in
/// the target pubspec are preserved.
class PubspecUtils {
  PubspecUtils._();

  /// Ensures default dependency entries are present in a target pubspec file.
  ///
  /// Entries already present (matched by package name) are left untouched,
  /// including their version constraints — unless [raiseFloors] is set, when
  /// an existing caret constraint whose range holds moarch's but starts below
  /// it is raised to moarch's floor. That only narrows the range, so it never
  /// admits a version the old constraint refused. `init` sets it: since
  /// Flutter 3.50 `flutter create` writes its own `material_ui: ^1.1.0`,
  /// older than the API the templates are written against.
  static Future<void> ensureDependencies(
    String projectPath, {
    required List<String> dependencies,
    List<String> devDependencies = const <String>[],
    bool raiseFloors = false,
  }) async {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));

    if (!await pubspecFile.exists()) {
      await pubspecFile.writeAsString(
        _defaultPubspec(
          dependencies: dependencies,
          devDependencies: devDependencies,
        ),
      );
      return;
    }

    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);
    final root = loadYaml(content);

    _ensureSection(
      editor,
      root,
      'dependencies',
      dependencies,
      raiseFloors: raiseFloors,
    );
    _ensureSection(
      editor,
      root,
      'dev_dependencies',
      devDependencies,
      raiseFloors: raiseFloors,
    );

    await pubspecFile.writeAsString(editor.toString());
  }

  /// Ensures asset entries are present under the Flutter section of a target pubspec file.
  static Future<void> ensureAssets(
    String projectPath, {
    required List<String> assets,
  }) async {
    if (assets.isEmpty) return;

    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));

    if (!await pubspecFile.exists()) {
      await pubspecFile.writeAsString(
        _defaultPubspec(
          dependencies: const <String>[],
          devDependencies: const <String>[],
          assets: assets,
        ),
      );
      return;
    }

    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);
    final root = loadYaml(content);
    final flutterSection = root is Map ? root['flutter'] : null;
    final existingAssets = flutterSection is Map
        ? flutterSection['assets']
        : null;

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

  /// Sets `hooks.user_defines.<package>.<key>` to [value] — how a package
  /// with a build hook is configured (`sqlite3`'s `source`, for one).
  ///
  /// A value already there is left alone: it was chosen by someone.
  static Future<void> ensureHookUserDefine(
    String projectPath, {
    required String package,
    required String key,
    required String value,
  }) async {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) return;

    final content = await pubspecFile.readAsString();
    if (hookUserDefine(content, package, key) != null) return;
    final editor = YamlEditor(content);
    final root = loadYaml(content);
    final hooks = root is Map ? root['hooks'] : null;
    final defines = hooks is Map ? hooks['user_defines'] : null;
    final forPackage = defines is Map ? defines[package] : null;

    if (hooks is! Map) {
      editor.update(
        ['hooks'],
        {
          'user_defines': {
            package: {key: value},
          },
        },
      );
    } else if (defines is! Map) {
      editor.update(
        ['hooks', 'user_defines'],
        {
          package: {key: value},
        },
      );
    } else if (forPackage is! Map) {
      editor.update(['hooks', 'user_defines', package], {key: value});
    } else {
      editor.update(['hooks', 'user_defines', package, key], value);
    }

    await pubspecFile.writeAsString(editor.toString());
  }

  /// The value of `hooks.user_defines.<package>.<key>` in [pubspec], or null.
  static String? hookUserDefine(String pubspec, String package, String key) {
    try {
      final root = loadYaml(pubspec);
      final hooks = root is Map ? root['hooks'] : null;
      final defines = hooks is Map ? hooks['user_defines'] : null;
      final forPackage = defines is Map ? defines[package] : null;
      final value = forPackage is Map ? forPackage[key] : null;
      return value?.toString();
    } on YamlException {
      return null;
    }
  }

  static void _ensureSection(
    YamlEditor editor,
    Object? root,
    String section,
    List<String> entries, {
    bool raiseFloors = false,
  }) {
    if (entries.isEmpty) return;

    final parsed = _parseDependencies(entries);
    final existing = root is Map ? root[section] : null;

    if (existing is! Map) {
      // Section missing (or empty/null) — create it with every entry.
      editor.update([section], parsed);
      return;
    }

    for (final entry in parsed.entries) {
      if (!existing.containsKey(entry.key) ||
          (raiseFloors && _raisesFloor(existing[entry.key], entry.value))) {
        editor.update([section, entry.key], entry.value);
      }
    }
  }

  /// Whether [wanted] only narrows [current]: both are caret constraints and
  /// [wanted]'s floor is above [current]'s while still inside its range — the
  /// same major, or below 1.0.0 the same minor, where a caret stops.
  static bool _raisesFloor(Object? current, Object? wanted) {
    final from = _caretFloor(current);
    final to = _caretFloor(wanted);
    if (from == null || to == null) return false;
    // `^0.0.x` allows that one patch only: there is no range to narrow.
    if (from[0] == 0 && from[1] == 0) return false;
    final sameRange = from[0] == 0
        ? to[0] == 0 && to[1] == from[1]
        : to[0] == from[0];
    if (!sameRange) return false;
    for (var i = 0; i < 3; i++) {
      if (to[i] != from[i]) return to[i] > from[i];
    }
    return false;
  }

  /// The `[major, minor, patch]` of a `^x.y.z` constraint, or null for any
  /// other shape (a range, `any`, a pre-release, a path or git source).
  static List<int>? _caretFloor(Object? constraint) {
    if (constraint is! String) return null;
    final match = RegExp(
      r'^\^(\d+)\.(\d+)\.(\d+)$',
    ).firstMatch(constraint.trim());
    if (match == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
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

  /// Like [_parseEntries] but for dependency sections: an unversioned entry
  /// such as `dio:` parses to a null constraint, which would otherwise be
  /// written as `dio: null` and prevents pub from resolving anything. It gets
  /// the constraint [PackageVersions] keeps for the package — the widget kit
  /// and `doctor --fix` name their packages bare — and `any` only for a
  /// package the table does not know.
  static Map<String, Object?> _parseDependencies(List<String> entries) {
    final parsed = _parseEntries(entries);
    return {
      for (final e in parsed.entries)
        e.key: e.value ?? PackageVersions.constraintFor(e.key),
    };
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
      'dependencies': _parseDependencies(dependencies),
      'dev_dependencies': _parseDependencies(devDependencies),
      'flutter': {if (assets.isNotEmpty) 'assets': assets},
    });
    return editor.toString();
  }
}
