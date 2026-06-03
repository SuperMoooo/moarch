import 'dart:io';

import 'package:path/path.dart' as p;

/// Utility helpers for creating and writing scaffold files.
class FileUtils {
  FileUtils._();

  /// Returns the generated createDir template.
  static Future<void> createDir(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  /// Returns the generated writeFile template.
  static Future<void> writeFile(String filePath, String content) async {
    await createDir(p.dirname(filePath));
    final file = File(filePath);
    if (!file.existsSync()) {
      await file.writeAsString(content);
    } else if (file.path.contains("analysis_options")) {
      await file.writeAsString(content);
    }
  }
}
