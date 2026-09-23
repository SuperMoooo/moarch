import 'dart:io';

import 'testgen_conventions.dart';

/// What one generator run did, for `moarch create tests` to report.
///
/// The orchestrators collect rather than print: output belongs to the
/// command's `Logger`, and a test can assert on these lists directly.
class TestGenResult {
  /// Features that had something to generate from.
  int featuresScanned = 0;

  /// Files written, as absolute paths.
  final List<String> written = [];

  /// Files a dry run would have written.
  final List<String> planned = [];

  /// Existing files left alone because they no longer carry the generated
  /// marker — someone edited them. `--force` overwrites them.
  final List<String> handMaintained = [];

  /// Something the generator had to skip or guess, worth a look.
  final List<String> warnings = [];

  /// Files that could not be parsed or generated.
  final List<String> errors = [];

  /// Whether anything went wrong.
  bool get hasErrors => errors.isNotEmpty;

  /// Writes [content] to [path] — or, for a dry run, only records it — unless
  /// an existing file there is hand-maintained and [force] is off.
  void emit(
    String path,
    String content, {
    required bool dryRun,
    required bool force,
  }) {
    if (dryRun) {
      planned.add(path);
      return;
    }
    final file = File(path);
    if (!force && file.existsSync()) {
      final String existing;
      try {
        existing = file.readAsStringSync();
      } catch (_) {
        handMaintained.add(path);
        return;
      }
      if (!TestGenConventions.isGenerated(existing)) {
        handMaintained.add(path);
        return;
      }
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    written.add(path);
  }
}
