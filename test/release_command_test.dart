import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/release_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AppVersion', () {
    test('every bump raises the build number', () {
      final v = AppVersion.tryParse('1.4.2+37')!;
      expect('${v.bump('major')}', '2.0.0+38');
      expect('${v.bump('minor')}', '1.5.0+38');
      expect('${v.bump('patch')}', '1.4.3+38');
      expect('${v.bump('build')}', '1.4.2+38');
    });

    test('a version without a build number starts at build 1', () {
      expect('${AppVersion.tryParse('1.0.0')!.bump('patch')}', '1.0.1+1');
    });

    test('rejects what is not major.minor.patch+build', () {
      expect(AppVersion.tryParse('1.0'), isNull);
      expect(AppVersion.tryParse('v1.0.0'), isNull);
    });
  });

  group('release bump', () {
    late Directory dir;
    late CommandRunner<int> runner;

    File file(String name) => File(p.join(dir.path, name));

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('moarch_bump_test');
      file('pubspec.yaml').writeAsStringSync(
        'name: demo\r\ndescription: x\r\nversion: 1.2.0+14\r\n\r\nenvironment:\r\n',
      );
      runner = CommandRunner<int>('moarch', 'test')
        ..addCommand(ReleaseCommand(logger: Logger(level: Level.quiet)));
    });

    tearDown(() async => dir.delete(recursive: true));

    Future<int?> run(List<String> args) =>
        runner.run(['release', 'bump', ...args, '--path', dir.path]);

    test('rewrites only the version line, keeping CRLF', () async {
      expect(await run(['minor']), 0);
      expect(
        file('pubspec.yaml').readAsStringSync(),
        'name: demo\r\ndescription: x\r\nversion: 1.3.0+15\r\n\r\nenvironment:\r\n',
      );
    });

    test('a dry run writes nothing', () async {
      expect(await run(['patch', '--dry-run']), 0);
      expect(file('pubspec.yaml').readAsStringSync(), contains('1.2.0+14'));
    });

    test('--changelog adds the entry under the title, newest first', () async {
      file(
        'CHANGELOG.md',
      ).writeAsStringSync('# Changelog\n\n## 1.2.0\n\n- old\n');
      expect(await run(['patch', '--changelog']), 0);
      expect(
        file('CHANGELOG.md').readAsStringSync(),
        '# Changelog\n\n## 1.2.1\n\n- TODO: what changed for users.\n\n'
        '## 1.2.0\n\n- old\n',
      );
    });

    test(
      '--changelog creates the file, and a build bump adds no entry',
      () async {
        expect(await run(['build', '--changelog']), 0);
        expect(file('CHANGELOG.md').existsSync(), isFalse);
        expect(await run(['major', '--changelog']), 0);
        expect(file('CHANGELOG.md').readAsStringSync(), contains('## 2.0.0'));
      },
    );

    test('refuses an unknown part', () async {
      expect(await run(['huge']), 64);
    });
  });
}
