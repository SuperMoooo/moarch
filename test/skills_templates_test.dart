import 'dart:convert';

import 'package:moarch/src/templates/misc/agents_templates.dart';
import 'package:moarch/src/templates/misc/skills_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  SkillOptions options(
    StateManagement stateManagement, {
    bool withDio = false,
    bool withFirestore = false,
    bool withRouter = false,
    bool withWorkflows = false,
    bool withLocalization = false,
  }) => SkillOptions(
    stateManagement: stateManagement,
    withDio: withDio,
    withFirestore: withFirestore,
    withRouter: withRouter,
    withWorkflows: withWorkflows,
    withLocalization: withLocalization,
    blocConcurrency: stateManagement.isBloc,
  );

  String render(String slug, SkillOptions o) =>
      SkillsTemplates.skill(SkillsTemplates.bySlug(slug)!, o);

  /// The YAML between the opening and closing `---` of a SKILL.md.
  YamlMap frontmatter(String source) {
    expect(source, startsWith('---\n'));
    final end = source.indexOf('\n---\n', 4);
    expect(end, greaterThan(0));
    return loadYaml(source.substring(4, end)) as YamlMap;
  }

  final every = [
    for (final stack in StateManagement.values) ...[
      options(stack),
      options(
        stack,
        withDio: true,
        withFirestore: true,
        withRouter: true,
        withWorkflows: true,
        withLocalization: true,
      ),
    ],
  ];

  group('frontmatter', () {
    test('every skill parses, and its name is its directory', () {
      // An agent that cannot parse the frontmatter drops the skill silently;
      // a description holding `: ` is exactly what breaks a plain scalar.
      for (final skill in SkillsTemplates.all) {
        for (final source in [
          for (final o in every) SkillsTemplates.skill(skill, o),
          SkillsTemplates.claudeSkill(skill),
        ]) {
          final yaml = frontmatter(source);
          expect(yaml['name'], skill.name);
          expect(yaml['description'], skill.description);
        }
        expect(skill.agentsPath, '.agents/skills/${skill.name}/SKILL.md');
        expect(skill.claudePath, '.claude/skills/${skill.name}/SKILL.md');
      }
    });

    test('names and descriptions fit the Agent Skills limits', () {
      for (final skill in SkillsTemplates.all) {
        expect(skill.name, matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')));
        expect(skill.name.length, lessThanOrEqualTo(64));
        expect(skill.description.length, lessThanOrEqualTo(1024));
      }
    });

    test('slugs are unique', () {
      final slugs = SkillsTemplates.all.map((s) => s.slug).toList();
      expect(slugs.toSet(), hasLength(slugs.length));
    });
  });

  group('bodies', () {
    test('every skill a body names exists', () {
      final names = SkillsTemplates.all.map((s) => s.name).toSet();
      for (final skill in SkillsTemplates.all) {
        for (final o in every) {
          final body = SkillsTemplates.skill(skill, o);
          final referenced = RegExp(
            r'`(moarch-[a-z-]+)`',
          ).allMatches(body).map((m) => m.group(1)!).toSet();
          expect(names, containsAll(referenced), reason: skill.name);
        }
      }
    });

    test('everything runs through fvm', () {
      for (final skill in SkillsTemplates.all) {
        for (final o in every) {
          final body = SkillsTemplates.skill(skill, o);
          expect(
            body,
            isNot(
              matches(
                RegExp(
                  r'(?<!fvm )(flutter|dart) (analyze|test|run|pub)',
                  multiLine: true,
                ),
              ),
            ),
            reason: '${skill.name} runs a bare flutter/dart command',
          );
        }
      }
    });

    test('create feature is fed stdin, since it prompts', () {
      final body = render('add-feature', options(StateManagement.riverpod));
      expect(body, contains('echo | moarch create feature <name>'));
      expect(
        render(
          'add-feature',
          options(StateManagement.riverpod, withDio: true, withFirestore: true),
        ),
        contains("printf '2\\n\\n' | moarch create feature <name>"),
      );
    });

    test('add-action follows the stack', () {
      final riverpod = render('add-action', options(StateManagement.riverpod));
      expect(riverpod, contains('# Add an action (Riverpod)'));
      expect(riverpod, contains('ref.read(orderNotifierProvider.notifier)'));
      expect(riverpod, isNot(contains('BlocConsumer')));

      final bloc = render('add-action', options(StateManagement.bloc));
      expect(bloc, contains('# Add an action (Bloc)'));
      expect(bloc, contains('final class OrderDeleted extends OrderEvent'));
      expect(bloc, contains('runAction(emit,'));
      expect(bloc, contains('droppable()'));
      expect(bloc, contains('moarch create scope'));
      expect(bloc, isNot(contains('ref.read')));
    });

    test('the data layer names only the boundary wrappers it has', () {
      final dio = render(
        'add-endpoint',
        options(StateManagement.riverpod, withDio: true),
      );
      expect(dio, contains('safeApiCall'));
      expect(dio, isNot(contains('safeFirebaseCall')));

      final firestore = render(
        'add-endpoint',
        options(StateManagement.riverpod, withFirestore: true),
      );
      expect(firestore, contains('safeFirebaseCall'));
      expect(firestore, isNot(contains('safeApiCall')));
      // Integration tests are generated for Dio GETs only.
      expect(firestore, isNot(contains('integration test')));
    });

    test('build-screen puts every widget in its own file', () {
      for (final stack in StateManagement.values) {
        final source = render('build-screen', options(stack));
        expect(source, contains('**One widget per file.**'));
        expect(source, contains('presentation/widgets/'));
        expect(source, isNot(contains('Split a growing `build` into private')));
      }
    });

    test('the route section appears only with the router', () {
      expect(
        render('build-screen', options(StateManagement.bloc)),
        isNot(contains('## The route')),
      );
      final routed = render(
        'build-screen',
        options(StateManagement.bloc, withRouter: true),
      );
      expect(routed, contains('## The route'));
      expect(routed, contains('returns\n   the page'));
    });

    test('an env key reaches CI only when there are workflows', () {
      expect(
        render('add-env-key', options(StateManagement.riverpod)),
        isNot(contains('secrets.')),
      );
      expect(
        render(
          'add-env-key',
          options(StateManagement.riverpod, withWorkflows: true),
        ),
        contains(r'PAYMENTS_KEY=${{ secrets.PAYMENTS_KEY }}'),
      );
    });

    test('the review checks the stack the project has', () {
      expect(
        render('review', options(StateManagement.bloc)),
        contains('registerFactory'),
      );
      expect(
        render('review', options(StateManagement.riverpod)),
        contains('Notifiers are not registered in get_it'),
      );
    });
  });

  group('Claude Code', () {
    test('its skill points at the .agents body', () {
      for (final skill in SkillsTemplates.all) {
        expect(
          SkillsTemplates.claudeSkill(skill),
          contains('Read `${skill.agentsPath}` and follow it.'),
        );
      }
    });

    test('settings allow the checks and deny what the rules forbid', () {
      final riverpod =
          jsonDecode(SkillsTemplates.claudeSettings(bloc: false))
              as Map<String, dynamic>;
      final permissions = riverpod['permissions'] as Map<String, dynamic>;
      expect(permissions['allow'], contains('Bash(fvm flutter test *)'));
      expect(permissions['allow'], isNot(contains('Bash(bloc lint *)')));
      expect(
        permissions['deny'],
        containsAll(['Read(./.env)', 'Edit(**/*.g.dart)']),
      );

      final bloc =
          jsonDecode(SkillsTemplates.claudeSettings(bloc: true))
              as Map<String, dynamic>;
      expect(
        (bloc['permissions'] as Map<String, dynamic>)['allow'],
        contains('Bash(bloc lint *)'),
      );
    });
  });

  test('Gemini CLI is pointed at AGENTS.md', () {
    final settings =
        jsonDecode(SkillsTemplates.geminiSettings()) as Map<String, dynamic>;
    expect(
      (settings['context'] as Map<String, dynamic>)['fileName'],
      contains('AGENTS.md'),
    );
  });

  group('AGENTS.md', () {
    test('lists every skill when the project has them', () {
      final source = AgentsTemplates.agentsMd(
        projectName: 'demo',
        stateManagement: StateManagement.riverpod,
        withSkills: true,
      );
      expect(source, contains('## Skills'));
      for (final skill in SkillsTemplates.all) {
        expect(source, contains('(${skill.agentsPath})'));
      }
      expect(source, contains('this file wins'));
    });

    test('says nothing about skills a project does not have', () {
      final source = AgentsTemplates.agentsMd(
        projectName: 'demo',
        stateManagement: StateManagement.riverpod,
      );
      expect(source, isNot(contains('## Skills')));
      expect(source, isNot(contains('.agents/skills/')));
    });
  });

  group('catalog', () {
    test('the ai group holds both files of every skill and the settings', () {
      final paths = ScaffoldCatalog.byGroup('ai').map((s) => s.path).toSet();
      for (final skill in SkillsTemplates.all) {
        expect(paths, contains(skill.agentsPath));
        expect(paths, contains(skill.claudePath));
      }
      expect(
        paths,
        containsAll(['.claude/settings.json', '.gemini/settings.json']),
      );
      expect(paths, hasLength(SkillsTemplates.all.length * 2 + 2));
    });
  });
}
