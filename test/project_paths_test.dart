import 'dart:io';

import 'package:moarch/src/utils/project_paths.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('moarch_paths'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// A project root with [pubspec] as its pubspec.yaml.
  String project(String pubspec) {
    Directory(p.join(temp.path, 'lib')).createSync(recursive: true);
    File(p.join(temp.path, 'pubspec.yaml')).writeAsStringSync(pubspec);
    return temp.path;
  }

  group('resolveLibPath', () {
    test('a project root resolves to its lib/', () {
      final root = project('name: app\n');

      expect(resolveLibPath(root), p.join(root, 'lib'));
    });

    test('a lib/ is returned as given', () {
      final root = project('name: app\n');
      final lib = p.join(root, 'lib');

      expect(resolveLibPath(lib), lib);
    });

    test('a path that is neither is left alone', () {
      expect(resolveLibPath('lib'), 'lib');
    });
  });

  group('StateManagement.detect', () {
    const blocPubspec = '''
name: app
dependencies:
  flutter_bloc: ^9.1.1
''';

    test('reads the stack from the parent of lib/', () {
      final root = project(blocPubspec);

      expect(
        StateManagement.detect(p.join(root, 'lib')),
        StateManagement.bloc,
      );
    });

    test('reads it from the project root too', () {
      // `--path` means a root for `init` and a lib/ for `create`, so pointing
      // create at a root used to find no pubspec one level up and quietly
      // generate Riverpod into a bloc project.
      final root = project(blocPubspec);

      expect(StateManagement.detect(root), StateManagement.bloc);
    });

    test('walks up from a nested directory', () {
      final root = project(blocPubspec);
      final nested = p.join(root, 'lib', 'features', 'orders');
      Directory(nested).createSync(recursive: true);

      expect(StateManagement.detect(nested), StateManagement.bloc);
    });

    test('falls back to riverpod only when there is no pubspec at all', () {
      final orphan = Directory(p.join(temp.path, 'orphan'))
        ..createSync(recursive: true);

      expect(
        StateManagement.detect(orphan.path),
        StateManagement.riverpod,
      );
    });
  });
}
