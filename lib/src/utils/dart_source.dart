/// Small edits to Dart source that moarch patches rather than rewrites.
abstract final class DartSource {
  /// Adds any of [imports] (whole `import '…';` lines) that [source] does not
  /// already have, after its last existing import line.
  static String addImports(String source, List<String> imports) {
    final missing = imports.where((line) => !source.contains(line)).toList()
      ..sort();
    if (missing.isEmpty) return source;

    final importPattern = RegExp(r"^import\s+'[^']+';$", multiLine: true);
    final matches = importPattern.allMatches(source).toList();
    if (matches.isEmpty) return '${missing.join('\n')}\n$source';

    final last = matches.last.end;
    return '${source.substring(0, last)}\n${missing.join('\n')}'
        '${source.substring(last)}';
  }

  /// Inserts [block] on its own lines directly above the line holding
  /// [anchor], or returns null when [source] has no [anchor].
  static String? insertAbove(String source, String anchor, String block) {
    final anchorIndex = source.indexOf(anchor);
    if (anchorIndex < 0) return null;
    // Back up to the start of the anchor's line so the insert lands above its
    // indentation rather than in the middle of it.
    final lineStart = source.lastIndexOf('\n', anchorIndex) + 1;
    return '${source.substring(0, lineStart)}$block\n'
        '${source.substring(lineStart)}';
  }
}
