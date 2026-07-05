import 'dart:io';

import 'package:path/path.dart' as p;

/// Utility helpers for creating and writing scaffold files.
///
/// Tracks files it creates during a session so a failed scaffold can be
/// rolled back, and supports a dry-run mode that reports what would be
/// written without touching disk.
class FileUtils {
  FileUtils._();

  static bool _dryRun = false;
  static final List<String> _createdFiles = <String>[];
  static final List<String> _plannedWrites = <String>[];

  /// Starts a new tracking session. Call before a command begins writing
  /// files so [rollback] and [plannedWrites] reflect only this run.
  static void beginSession({bool dryRun = false}) {
    _dryRun = dryRun;
    _createdFiles.clear();
    _plannedWrites.clear();
  }

  /// Paths that would be written in the current dry-run session.
  static List<String> get plannedWrites => List.unmodifiable(_plannedWrites);

  /// Deletes every file created since [beginSession] was called (best-effort).
  static void rollback() {
    for (final path in _createdFiles.reversed) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // Best-effort cleanup — leave it for the user if deletion fails.
      }
    }
    _createdFiles.clear();
  }

  /// Returns the generated createDir template.
  static Future<void> createDir(String dirPath) async {
    if (_dryRun) return;
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  /// Returns the generated writeFile template.
  static Future<void> writeFile(String filePath, String content) async {
    if (_dryRun) {
      _plannedWrites.add(filePath);
      return;
    }
    await createDir(p.dirname(filePath));
    final file = File(filePath);
    if (!file.existsSync()) {
      await file.writeAsString(content);
      _createdFiles.add(filePath);
    } else if (file.path.contains("analysis_options")) {
      await file.writeAsString(content);
    }
  }
}
