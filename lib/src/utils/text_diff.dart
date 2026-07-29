/// A single line in a [TextDiff].
class DiffLine {
  /// Creates a diff line.
  const DiffLine(this.kind, this.text);

  /// `' '` context, `'-'` removed, `'+'` added.
  final String kind;

  /// The line's content, without its trailing newline.
  final String text;

  @override
  String toString() => '$kind$text';
}

/// Line-level diffing used by `moarch update` to show what refreshing a
/// generated file would actually change.
abstract final class TextDiff {
  /// Diffs [before] against [after], returning only changed regions plus
  /// [context] unchanged lines around each one.
  ///
  /// Line endings are normalized first, so a CRLF checkout doesn't render as
  /// every line having changed.
  static List<DiffLine> unified(
    String before,
    String after, {
    int context = 2,
  }) {
    final a = _lines(before);
    final b = _lines(after);
    final full = _diffLines(a, b);

    // Keep only lines within `context` of a change; collapse the rest.
    final keep = List<bool>.filled(full.length, false);
    for (var i = 0; i < full.length; i++) {
      if (full[i].kind == ' ') continue;
      final from = (i - context).clamp(0, full.length - 1);
      final to = (i + context).clamp(0, full.length - 1);
      for (var j = from; j <= to; j++) {
        keep[j] = true;
      }
    }

    final result = <DiffLine>[];
    var skipping = false;
    for (var i = 0; i < full.length; i++) {
      if (keep[i]) {
        result.add(full[i]);
        skipping = false;
      } else if (!skipping) {
        result.add(const DiffLine(' ', '...'));
        skipping = true;
      }
    }
    return result;
  }

  /// Whether [before] and [after] differ once line endings are normalized.
  static bool differ(String before, String after) =>
      before.replaceAll('\r\n', '\n') != after.replaceAll('\r\n', '\n');

  /// The number of added and removed lines between [before] and [after].
  static ({int added, int removed}) stat(String before, String after) {
    final diff = _diffLines(_lines(before), _lines(after));
    var added = 0;
    var removed = 0;
    for (final line in diff) {
      if (line.kind == '+') added++;
      if (line.kind == '-') removed++;
    }
    return (added: added, removed: removed);
  }

  static List<String> _lines(String text) =>
      text.replaceAll('\r\n', '\n').split('\n');

  /// Classic LCS diff. Widget templates run to a few hundred lines, so the
  /// O(n·m) table is comfortably cheap here.
  static List<DiffLine> _diffLines(List<String> a, List<String> b) {
    final n = a.length;
    final m = b.length;

    // lcs[i][j] = length of the longest common subsequence of a[i:] and b[j:].
    final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        lcs[i][j] = a[i] == b[j]
            ? lcs[i + 1][j + 1] + 1
            : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
      }
    }

    final result = <DiffLine>[];
    var i = 0;
    var j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        result.add(DiffLine(' ', a[i]));
        i++;
        j++;
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        result.add(DiffLine('-', a[i]));
        i++;
      } else {
        result.add(DiffLine('+', b[j]));
        j++;
      }
    }
    while (i < n) {
      result.add(DiffLine('-', a[i]));
      i++;
    }
    while (j < m) {
      result.add(DiffLine('+', b[j]));
      j++;
    }
    return result;
  }
}
