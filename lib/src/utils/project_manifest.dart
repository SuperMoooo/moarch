import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../version.dart';

/// The record `moarch` leaves in a project describing what it generated.
///
/// Written to `.moarch.yaml` at the project root by `moarch init` and updated
/// by `moarch create widget`. It exists so `moarch update` can answer the one
/// question a scaffolder otherwise can't: *is this generated file still the
/// one we wrote, or has the user edited it?* — by comparing the hash recorded
/// at generation time against the file on disk.
///
/// A project generated before manifests existed simply has no `.moarch.yaml`;
/// callers fall back to inspecting the filesystem and treat every file as
/// possibly-edited. Nothing here is required for a project to build.
class ProjectManifest {
  /// Creates a manifest.
  ProjectManifest({
    required this.version,
    required this.generatedAt,
    this.stack = const [],
    Map<String, String>? files,
  }) : files = files ?? <String, String>{};

  /// The name of the manifest file at the project root.
  static const String fileName = '.moarch.yaml';

  /// The moarch version that last wrote this manifest.
  final String version;

  /// When the manifest was last written.
  final DateTime generatedAt;

  /// The init checklist options this project was generated with.
  final List<String> stack;

  /// Project-relative path → [hashContent] of the file as moarch wrote it.
  ///
  /// Paths use forward slashes on every platform so a manifest committed on
  /// Windows still resolves on macOS/Linux.
  final Map<String, String> files;

  /// A stable content hash used to detect edits to a generated file.
  ///
  /// FNV-1a (64-bit) over the content with line endings normalized, so a
  /// CRLF checkout of an otherwise untouched file is not misread as an edit.
  /// This detects change, not tampering — no cryptographic claim is made.
  static String hashContent(String content) {
    final bytes = utf8.encode(content.replaceAll('\r\n', '\n'));
    // FNV-1a 64-bit. Carried in two 32-bit halves so the multiply never
    // relies on how wide an int happens to be.
    var hi = 0xcbf29ce4;
    var lo = 0x84222325;
    const prime = 0x1b3; // 0x100000001b3 == (1 << 32) + 0x1b3
    for (final byte in bytes) {
      lo ^= byte;
      // (hi:lo) * ((1 << 32) + prime), keeping the low 64 bits.
      final l = lo * prime;
      final h = hi * prime + lo + (l >> 32);
      lo = l & 0xffffffff;
      hi = h & 0xffffffff;
    }
    final hiHex = hi.toRadixString(16).padLeft(8, '0');
    final loHex = lo.toRadixString(16).padLeft(8, '0');
    return '$hiHex$loHex';
  }

  /// Normalizes [path] to the project-relative, forward-slash form used as a
  /// key in [files].
  static String relativeKey(String projectRoot, String path) {
    final relative =
        p.relative(p.absolute(path), from: p.absolute(projectRoot));
    return relative.replaceAll(r'\', '/');
  }

  /// Reads the manifest from [projectRoot], or null when absent or unreadable.
  ///
  /// A malformed manifest is treated as absent rather than fatal: it is a
  /// convenience record, and refusing to run `doctor` because of it would
  /// punish the user for a file they never asked for.
  static ProjectManifest? load(String projectRoot) {
    final file = File(p.join(projectRoot, fileName));
    if (!file.existsSync()) return null;

    try {
      final doc = loadYaml(file.readAsStringSync());
      if (doc is! Map) return null;

      final rawFiles = doc['files'];
      final files = <String, String>{};
      if (rawFiles is Map) {
        rawFiles.forEach((key, value) => files['$key'] = '$value');
      }

      final rawStack = doc['stack'];
      final stack = <String>[
        if (rawStack is List)
          for (final item in rawStack) '$item',
      ];

      return ProjectManifest(
        version: '${doc['version'] ?? 'unknown'}',
        generatedAt:
            DateTime.tryParse('${doc['generated_at']}') ?? DateTime.now(),
        stack: stack,
        files: files,
      );
    } catch (_) {
      return null;
    }
  }

  /// Records [content] as what moarch generated for [path].
  void record(String projectRoot, String path, String content) {
    files[relativeKey(projectRoot, path)] = hashContent(content);
  }

  /// The hash recorded for [path], or null when moarch never wrote it.
  String? recordedHash(String projectRoot, String path) =>
      files[relativeKey(projectRoot, path)];

  /// Writes the manifest to [projectRoot], stamped with the running version.
  Future<void> save(String projectRoot) async {
    final file = File(p.join(projectRoot, fileName));
    await file.writeAsString(_render());
  }

  /// Loads the existing manifest for [projectRoot] or creates an empty one.
  static ProjectManifest loadOrCreate(String projectRoot) =>
      load(projectRoot) ??
      ProjectManifest(
        version: packageVersion,
        generatedAt: DateTime.now(),
      );

  String _render() {
    final sortedKeys = files.keys.toList()..sort();
    final buffer = StringBuffer()
      ..writeln('# Written by moarch — it records what the CLI generated so')
      ..writeln(
          '# `moarch update` can tell an untouched file from one you edited.')
      ..writeln(
          '# Safe to commit. Deleting it only makes `moarch update` more cautious.')
      ..writeln("version: '$packageVersion'")
      ..writeln("generated_at: '${DateTime.now().toIso8601String()}'");

    if (stack.isEmpty) {
      buffer.writeln('stack: []');
    } else {
      buffer.writeln('stack:');
      for (final item in stack) {
        buffer.writeln("  - '${item.replaceAll("'", "''")}'");
      }
    }

    if (sortedKeys.isEmpty) {
      buffer.writeln('files: {}');
    } else {
      buffer.writeln('files:');
      for (final key in sortedKeys) {
        buffer.writeln("  '$key': '${files[key]}'");
      }
    }
    return buffer.toString();
  }
}
