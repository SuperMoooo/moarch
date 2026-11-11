import 'package:moarch/src/utils/dart_source.dart';
import 'package:test/test.dart';

void main() {
  group('addImports', () {
    test('inserts after the last import, prefixed or combinated', () {
      const source = '''
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' show loadYaml;

void main() {}
''';
      final out = DartSource.addImports(source, ["import 'a.dart';"]);

      expect(out, '''
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' show loadYaml;
import 'a.dart';

void main() {}
''');
    });

    test('accepts double quotes and deferred imports', () {
      const source = 'import "x.dart" deferred as x;\n\nvoid main() {}\n';
      final out = DartSource.addImports(source, ["import 'a.dart';"]);

      expect(
        out,
        startsWith('import "x.dart" deferred as x;\nimport \'a.dart\';\n'),
      );
    });

    test('prepends when there is no import, and skips what is there', () {
      expect(
        DartSource.addImports('void main() {}\n', ["import 'a.dart';"]),
        "import 'a.dart';\nvoid main() {}\n",
      );
      const source = "import 'a.dart';\n";
      expect(DartSource.addImports(source, ["import 'a.dart';"]), source);
    });
  });

  group('insertAbove', () {
    test('lands on the anchor line, above its indentation', () {
      const source = '  a\n    // anchor\n';
      expect(
        DartSource.insertAbove(source, '// anchor', '    b'),
        '  a\n    b\n    // anchor\n',
      );
      expect(DartSource.insertAbove(source, 'nope', 'b'), isNull);
    });
  });
}
