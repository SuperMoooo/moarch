import 'package:moarch/src/utils/text_diff.dart';
import 'package:test/test.dart';

void main() {
  group('differ', () {
    test('is false for identical text', () {
      expect(TextDiff.differ('a\nb', 'a\nb'), isFalse);
    });

    test('ignores line-ending style', () {
      expect(TextDiff.differ('a\r\nb', 'a\nb'), isFalse);
    });

    test('is true for a real change', () {
      expect(TextDiff.differ('a\nb', 'a\nc'), isTrue);
    });
  });

  group('stat', () {
    test('counts an added line', () {
      final stat = TextDiff.stat('a\nb', 'a\nb\nc');
      expect(stat.added, 1);
      expect(stat.removed, 0);
    });

    test('counts a removed line', () {
      final stat = TextDiff.stat('a\nb\nc', 'a\nc');
      expect(stat.added, 0);
      expect(stat.removed, 1);
    });

    test('counts a modified line as one added and one removed', () {
      final stat = TextDiff.stat('a\nb\nc', 'a\nX\nc');
      expect(stat.added, 1);
      expect(stat.removed, 1);
    });

    test('is zero for identical text', () {
      final stat = TextDiff.stat('a\nb\nc', 'a\nb\nc');
      expect(stat.added, 0);
      expect(stat.removed, 0);
    });
  });

  group('unified', () {
    test('marks added and removed lines', () {
      final diff = TextDiff.unified('a\nb\nc', 'a\nX\nc');
      expect(
        diff.map((l) => l.toString()),
        containsAll(['-b', '+X']),
      );
    });

    test('keeps context lines around a change', () {
      final diff = TextDiff.unified('a\nb\nc', 'a\nX\nc', context: 1);
      final rendered = diff.map((l) => l.toString()).toList();
      expect(rendered, contains(' a'));
      expect(rendered, contains(' c'));
    });

    test('collapses long unchanged runs into an ellipsis', () {
      final before = ['change me', ...List.generate(40, (i) => 'line $i')];
      final after = ['changed', ...List.generate(40, (i) => 'line $i')];

      final diff = TextDiff.unified(before.join('\n'), after.join('\n'));
      final rendered = diff.map((l) => l.toString()).toList();

      expect(rendered, contains(' ...'));
      // The collapsed middle keeps the output far shorter than the file.
      expect(diff.length, lessThan(10));
    });

    test('is empty of changes for identical text', () {
      final diff = TextDiff.unified('a\nb\nc', 'a\nb\nc');
      expect(diff.where((l) => l.kind != ' '), isEmpty);
    });

    test('handles an entirely new file', () {
      final diff = TextDiff.unified('', 'a\nb');
      expect(diff.where((l) => l.kind == '+'), isNotEmpty);
    });
  });
}
