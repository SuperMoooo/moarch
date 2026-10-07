import 'dart:convert';
import 'dart:io';

import 'package:moarch/src/templates/misc/claude_mod_templates.dart';
import 'package:moarch/src/utils/project_manifest.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The mod is TypeScript, which `dart test` cannot run: these check what can
/// be checked from Dart — that the files fit together and that the hash the
/// mod re-implements is moarch's. `claude plugin validate` and
/// `claude plugin test` on a generated project check the rest.
void main() {
  ClaudeModFile file(String path) =>
      ClaudeModTemplates.all.singleWhere((file) => file.path.endsWith(path));

  test('every file lives in the mod folder, once', () {
    final paths = ClaudeModTemplates.all.map((file) => file.path).toList();
    expect(paths.toSet(), hasLength(paths.length));
    for (final path in paths) {
      expect(path, startsWith('${ClaudeModTemplates.dir}/'));
      expect(p.posix.normalize(path), path);
    }
    expect(paths, contains(ClaudeModTemplates.markerPath));
  });

  test('is a catalog entry in the ai group, so update refreshes it', () {
    final ai = ScaffoldCatalog.byGroup('ai').map((spec) => spec.name);
    for (final file in ClaudeModTemplates.all) {
      expect(ai, contains(file.slug));
      final spec = ScaffoldCatalog.byName(file.slug)!;
      expect(spec.path, file.path);
      expect(spec.template(ScaffoldContext.detect('.')), file.content);
    }
  });

  test('the manifest and hooks list are JSON that point at real files', () {
    final manifest =
        jsonDecode(file('.claude-plugin/plugin.json').content) as Map;
    expect(manifest['name'], 'moarch-mod');
    expect(manifest['types'], './types/index.d.ts');
    file('types/index.d.ts');

    final hooks = jsonDecode(file('hooks/hooks.json').content) as Map;
    expect(hooks['modules'], ['./register.tsx']);
    file('hooks/register.tsx');
  });

  test('every relative import resolves to a file of the mod', () {
    final import = RegExp(r"""from '(\.{1,2}/[^']+)'""");
    for (final source in ClaudeModTemplates.all.where(
      (file) => file.path.endsWith('.ts') || file.path.endsWith('.tsx'),
    )) {
      for (final match in import.allMatches(source.content)) {
        final target = p.posix.normalize(
          p.posix.join(p.posix.dirname(source.path), match.group(1)!),
        );
        final candidates = [
          for (final ext in ['.ts', '.tsx', '.d.ts', '/index.d.ts'])
            '$target$ext',
        ];
        expect(
          ClaudeModTemplates.all.map((file) => file.path),
          contains(anyOf(candidates)),
          reason: '${source.path} imports ${match.group(1)}',
        );
      }
    }
  });

  test('the runner agent is a haiku agent that cannot edit', () {
    final source = file('agents/runner.md').content;
    expect(source, startsWith('---\n'));
    final front =
        loadYaml(source.substring(4, source.indexOf('\n---\n', 4))) as YamlMap;
    expect(front['name'], 'runner');
    expect(front['model'], 'haiku');
    expect(front['tools'], isNot(contains('Edit')));
    expect(front['tools'], isNot(contains('Write')));
  });

  test("the mod's hash test vectors are moarch's own hashes", () {
    final tests = file('tests/rules.test.ts').content;
    final vector = RegExp(
      r"""hashContent\(('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")\)\)\.toBe\('([0-9a-f]{16})'\)""",
    );
    final matches = vector.allMatches(tests).toList();
    expect(matches, isNotEmpty);
    for (final match in matches) {
      final literal = match.group(1)!;
      final input =
          jsonDecode(
                '"${literal.substring(1, literal.length - 1).replaceAll('"', r'\"')}"',
              )
              as String;
      expect(
        ProjectManifest.hashContent(input),
        match.group(2),
        reason: literal,
      );
    }
  });

  test('guards every anchor the templates write', () {
    // The mod's own pattern, read back out of rules.ts.
    expect(file('hooks/rules.ts').content, contains(r'/\/\/ moarch:[a-z_]+/g'));
    final guarded = RegExp(r'^// moarch:[a-z_]+$');

    final anchors = <String>{
      for (final source
          in Directory(p.join('lib', 'src'))
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart')))
        for (final match in RegExp(
          r'// moarch:[\w-]+',
        ).allMatches(source.readAsStringSync()))
          match.group(0)!,
    };
    expect(anchors, isNotEmpty);
    for (final anchor in anchors) {
      expect(guarded.hasMatch(anchor), isTrue, reason: anchor);
    }
  });

  test('has no carriage returns, whatever the checkout', () {
    for (final file in ClaudeModTemplates.all) {
      expect(file.content, isNot(contains('\r')), reason: file.path);
      expect(file.content, endsWith('\n'), reason: file.path);
    }
  });
}
