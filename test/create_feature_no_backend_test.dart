import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/create/create_feature_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String libPath;

  Future<int?> createFeature(List<String> extra) {
    final runner = CommandRunner<int>('moarch', 'test')
      ..addCommand(CreateFeatureCommand(logger: Logger(level: Level.quiet)));
    return runner.run(['feature', '--path', libPath, ...extra, 'notes']);
  }

  bool exists(String rel) =>
      File(p.join(libPath, 'features', 'notes', rel)).existsSync();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('moarch_no_backend');
    libPath = p.join(tempDir.path, 'lib');
    Directory(libPath).createSync();
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: demo
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.0.0
''');
  });

  tearDown(() => tempDir.delete(recursive: true));

  // A remote datasource names a Dio client or a Firestore handle; with
  // neither installed it would not compile.
  test('--all writes no remote datasource without a backend', () async {
    expect(await createFeature(['--all']), 0);
    expect(exists('data/datasources/notes_remote_datasource.dart'), isFalse);
    expect(exists('data/datasources/notes_local_datasource.dart'), isTrue);
    final repository = File(
      p.join(
        libPath,
        'features',
        'notes',
        'data',
        'repositories',
        'notes_repository.dart',
      ),
    ).readAsStringSync();
    expect(repository, isNot(contains('RemoteDataSource')));
  });

  test('a project with Dio still gets one', () async {
    File(
      p.join(tempDir.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: demo\ndependencies:\n  dio: ^5.0.0\n');
    expect(await createFeature(['--all']), 0);
    expect(exists('data/datasources/notes_remote_datasource.dart'), isTrue);
  });
}
