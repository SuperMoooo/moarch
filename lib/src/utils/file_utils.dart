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

  /// Writes [content] to [filePath], creating parent directories as needed.
  ///
  /// Existing files are never clobbered — a hand-edited widget or feature
  /// survives a re-run of the generator. `analysis_options.yaml` is the one
  /// exception: it is the scaffold's own lint contract, so it is refreshed.
  ///
  /// Returns true when the file was written, false when an existing file was
  /// left untouched, so callers can report "created" and "skipped" honestly.
  /// In dry-run mode it records the path and reports true without touching disk.
  static Future<bool> writeFile(String filePath, String content) async {
    if (_dryRun) {
      _plannedWrites.add(filePath);
      return true;
    }
    await createDir(p.dirname(filePath));
    final file = File(filePath);
    if (!file.existsSync()) {
      await file.writeAsString(content);
      _createdFiles.add(filePath);
      return true;
    }
    if (p.basename(filePath) == 'analysis_options.yaml') {
      await file.writeAsString(content);
      return true;
    }
    return false;
  }
}
