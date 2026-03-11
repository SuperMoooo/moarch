import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  FileUtils._();

  static Future<void> createDir(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  static Future<void> writeFile(String filePath, String content) async {
    await createDir(p.dirname(filePath));
    final file = File(filePath);
    if (!file.existsSync()) {
      await file.writeAsString(content);
    }
  }
}
