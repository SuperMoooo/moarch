import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// This repository's own agent guide: the same layout moarch generates, kept
/// honest the same way.
void main() {
  YamlMap frontmatter(File file) {
    final source = file.readAsStringSync().replaceAll('\r\n', '\n');
    expect(source, startsWith('---\n'), reason: file.path);
    final end = source.indexOf('\n---\n', 4);
    expect(end, greaterThan(0), reason: file.path);
    return loadYaml(source.substring(4, end)) as YamlMap;
  }

  final skills = Directory(p.join('.agents', 'skills'))
      .listSync()
      .whereType<Directory>()
      .map((dir) => p.basename(dir.path))
      .toList();

  test('CLAUDE.md imports AGENTS.md', () {
    expect(File('CLAUDE.md').readAsStringSync(), contains('@AGENTS.md'));
  });

  test('every skill parses, and Claude Code has a pointer to it', () {
    expect(skills, isNotEmpty);
    for (final name in skills) {
      final body = File(p.join('.agents', 'skills', name, 'SKILL.md'));
      final pointer = File(p.join('.claude', 'skills', name, 'SKILL.md'));
      expect(frontmatter(body)['name'], name);
      expect(pointer.existsSync(), isTrue, reason: name);
      expect(frontmatter(pointer), frontmatter(body), reason: name);
      expect(
        pointer.readAsStringSync(),
        contains('.agents/skills/$name/SKILL.md'),
      );
    }
  });

  test('AGENTS.md lists every skill', () {
    final agents = File('AGENTS.md').readAsStringSync();
    for (final name in skills) {
      expect(agents, contains('(.agents/skills/$name/SKILL.md)'));
    }
  });
}
