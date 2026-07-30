import 'dart:io';

import 'package:moarch/src/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('moarch_file_utils_');
    FileUtils.beginSession();
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String path(String name) => p.join(temp.path, name);

  group('writeFile', () {
    test('writes a file that is not there', () async {
      expect(await FileUtils.writeFile(path('a.dart'), 'one'), isTrue);
      expect(File(path('a.dart')).readAsStringSync(), 'one');
    });

    test('never clobbers what is already there', () async {
      File(path('a.dart')).writeAsStringSync('mine');
      expect(await FileUtils.writeFile(path('a.dart'), 'theirs'), isFalse);
      expect(File(path('a.dart')).readAsStringSync(), 'mine');
    });

    test('refreshes analysis_options.yaml, which is the scaffold\'s own',
        () async {
      File(path('analysis_options.yaml')).writeAsStringSync('old');
      expect(
        await FileUtils.writeFile(path('analysis_options.yaml'), 'new'),
        isTrue,
      );
      expect(File(path('analysis_options.yaml')).readAsStringSync(), 'new');
    });

    test('overwriteWhen decides on the content, not the name', () async {
      File(path('main.dart')).writeAsStringSync('_incrementCounter');
      final wrote = await FileUtils.writeFile(
        path('main.dart'),
        'scaffold',
        overwriteWhen: (existing) => existing.contains('_incrementCounter'),
      );
      expect(wrote, isTrue);
      expect(File(path('main.dart')).readAsStringSync(), 'scaffold');
    });

    test('overwriteWhen saying no leaves the file alone', () async {
      File(path('main.dart')).writeAsStringSync('my own app');
      final wrote = await FileUtils.writeFile(
        path('main.dart'),
        'scaffold',
        overwriteWhen: (existing) => existing.contains('_incrementCounter'),
      );
      expect(wrote, isFalse);
      expect(File(path('main.dart')).readAsStringSync(), 'my own app');
    });

    test('rollback removes what the session created', () async {
      await FileUtils.writeFile(path('a.dart'), 'one');
      FileUtils.rollback();
      expect(File(path('a.dart')).existsSync(), isFalse);
    });

    test('rollback leaves a file the session only found', () async {
      File(path('a.dart')).writeAsStringSync('mine');
      await FileUtils.writeFile(path('a.dart'), 'theirs');
      FileUtils.rollback();
      expect(File(path('a.dart')).readAsStringSync(), 'mine');
    });

    test('a dry run reports the write without making it', () async {
      FileUtils.beginSession(dryRun: true);
      expect(await FileUtils.writeFile(path('a.dart'), 'one'), isTrue);
      expect(File(path('a.dart')).existsSync(), isFalse);
      expect(FileUtils.plannedWrites, contains(path('a.dart')));
    });
  });
}
