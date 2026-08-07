import 'dart:io';

import 'package:path/path.dart' as p;

import 'project_manifest.dart';

/// Utility helpers for creating and writing scaffold files.
///
/// Tracks files it creates during a session so a failed scaffold can be
/// rolled back, and supports a dry-run mode that reports what would be
/// written without touching disk.
class FileUtils {
  FileUtils._();

  static bool _dryRun = false;
  static ProjectManifest? _manifest;
  static String? _manifestRoot;
  static final List<String> _createdFiles = <String>[];
  static final List<String> _createdDirs = <String>[];
  static final List<String> _plannedWrites = <String>[];

  /// Starts a new tracking session. Call before a command begins writing
  /// files so [rollback] and [plannedWrites] reflect only this run.
  ///
  /// Pass [manifest] and [projectRoot] to have every file actually written
  /// recorded as moarch's own output — that record is the only thing letting
  /// `moarch update` tell an untouched generated file from an edited one.
  /// Files left in place because they already existed are deliberately not
  /// recorded: their content is the user's, not ours to vouch for.
  static void beginSession({
    bool dryRun = false,
    ProjectManifest? manifest,
    String? projectRoot,
  }) {
    _dryRun = dryRun;
    _manifest = manifest;
    _manifestRoot = projectRoot;
    _createdFiles.clear();
    _createdDirs.clear();
    _plannedWrites.clear();
  }

  /// Paths that would be written in the current dry-run session.
  static List<String> get plannedWrites => List.unmodifiable(_plannedWrites);

  /// Deletes every file created since [beginSession] was called, then the
  /// directories that were created for them, deepest first, so a failed
  /// scaffold doesn't leave an empty folder tree behind (best-effort).
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

    final dirs = _createdDirs.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final path in dirs) {
      try {
        final dir = Directory(path);
        // Only ever remove a directory this session created *and* that is
        // empty — one holding anything else holds someone's work.
        if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
      } catch (_) {
        // Best-effort cleanup — leave it for the user if deletion fails.
      }
    }
    _createdDirs.clear();
  }

  /// Creates [dirPath] (and any missing parents), tracking what was actually
  /// created so [rollback] can remove the whole chain again.
  static Future<void> createDir(String dirPath) async {
    if (_dryRun) return;
    final dir = Directory(dirPath);
    if (dir.existsSync()) return;

    // Walk up to find every ancestor that doesn't exist yet — those are ours
    // to remove on rollback; the ones already there are not.
    var current = dir;
    while (!current.existsSync()) {
      _createdDirs.add(current.path);
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
    await dir.create(recursive: true);
  }

  /// Writes [content] to [filePath], creating parent directories as needed.
  ///
  /// Existing files are never clobbered — a hand-edited widget or feature
  /// survives a re-run of the generator. `analysis_options.yaml` is the one
  /// blanket exception: it is the scaffold's own lint contract, so it is
  /// refreshed.
  ///
  /// [overwriteWhen] is the narrow exception: it is handed the file already on
  /// disk and decides whether that particular content may be replaced. It is
  /// for the files another tool put there — `flutter create`'s `main.dart` —
  /// where "already exists" does not mean "the developer wrote it". An
  /// overwrite is not tracked for [rollback]: only use it where what is being
  /// replaced is nobody's work.
  ///
  /// Returns true when the file was written, false when an existing file was
  /// left untouched, so callers can report "created" and "skipped" honestly.
  /// A dry run makes the same decision against the same disk — it records the
  /// path instead of writing, so the preview never lists a file a real run
  /// would have skipped.
  static Future<bool> writeFile(
    String filePath,
    String content, {
    bool Function(String existing)? overwriteWhen,
  }) async {
    final file = File(filePath);
    final exists = file.existsSync();
    final wouldWrite = !exists ||
        p.basename(filePath) == 'analysis_options.yaml' ||
        (overwriteWhen != null && overwriteWhen(await file.readAsString()));
    if (!wouldWrite) return false;

    if (_dryRun) {
      _plannedWrites.add(filePath);
      return true;
    }
    await createDir(p.dirname(filePath));
    await file.writeAsString(content);
    // Overwrites are deliberately not tracked for rollback: what was replaced
    // was another tool's output, and deleting the file wouldn't restore it.
    if (!exists) _createdFiles.add(filePath);
    _record(filePath, content);
    return true;
  }

  /// Notes [content] as what moarch wrote to [filePath], when the session was
  /// given a manifest to record into.
  static void _record(String filePath, String content) {
    final manifest = _manifest;
    final root = _manifestRoot;
    if (manifest == null || root == null) return;
    manifest.record(root, filePath, content);
  }
}
