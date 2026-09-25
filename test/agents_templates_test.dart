import 'package:moarch/src/templates/misc/agents_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

void main() {
  String agents(
    StateManagement stateManagement, {
    bool withDio = false,
    bool withFirebase = false,
    bool withRouter = false,
    bool withStatusColors = false,
    bool withLocalization = false,
    bool withEasyLocalization = false,
  }) => AgentsTemplates.agentsMd(
    projectName: 'demo',
    stateManagement: stateManagement,
    withDio: withDio,
    withFirebase: withFirebase,
    withRouter: withRouter,
    withStatusColors: withStatusColors,
    withLocalization: withLocalization,
    withEasyLocalization: withEasyLocalization,
  );

  group('AGENTS.md', () {
    test('names the project and runs everything through fvm', () {
      final source = agents(StateManagement.riverpod);
      expect(source, startsWith('# AGENTS.md — demo'));
      expect(source, contains('fvm flutter analyze'));
      expect(source, contains('fvm dart run build_runner build'));
    });

    test('names the saved theme-mode switch, per stack, when there is one', () {
      String themed(StateManagement stack, {required bool withThemeMode}) =>
          AgentsTemplates.agentsMd(
            projectName: 'demo',
            stateManagement: stack,
            withDarkTheme: true,
            withThemeMode: withThemeMode,
          );

      expect(
        themed(StateManagement.riverpod, withThemeMode: true),
        contains('ref.read(themeModeProvider.notifier).setMode(mode)'),
      );
      expect(
        themed(StateManagement.bloc, withThemeMode: true),
        contains('context.read<ThemeModeCubit>().setMode(mode)'),
      );
      // A dark theme from before 9.2.0 has no switch to point at.
      expect(
        themed(StateManagement.bloc, withThemeMode: false),
        isNot(contains('ThemeModeCubit')),
      );
      expect(agents(StateManagement.riverpod), isNot(contains('themeMode')));
    });

    test('states the architecture the templates generate', () {
      final source = agents(StateManagement.riverpod);
      // The two rules an agent trained on other Clean Architecture apps is
      // likeliest to break.
      expect(source, contains('**No entity layer.**'));
      expect(source, contains('**No use-case classes.**'));
      expect(source, contains('// moarch:registrations'));
    });

    test('puts every widget in its own file, on both stacks', () {
      for (final stack in StateManagement.values) {
        final source = agents(stack);
        expect(source, contains('**Every widget gets its own file.**'));
        expect(source, contains("widgets/      # the screens' pieces"));
        expect(source, isNot(contains('split into private widget')));
      }
    });

    test('describes the Riverpod stack on a Riverpod project', () {
      final source = agents(StateManagement.riverpod);
      expect(source, contains('## State — Riverpod'));
      expect(source, contains('ref.listenAction'));
      expect(source, contains('notifiers/'));
      expect(source, isNot(contains('BlocConsumer')));
      expect(source, isNot(contains('presentation_module.dart')));
    });

    test('describes the bloc stack on a bloc project', () {
      final source = agents(StateManagement.bloc);
      expect(source, contains('## State — Bloc'));
      expect(source, contains('BlocConsumer'));
      expect(source, contains('presentation_module.dart'));
      expect(source, contains('pages/'));
      expect(source, contains('bloc lint .'));
      expect(source, isNot(contains('ref.listenAction')));
    });

    test('names only the boundary wrappers the project has', () {
      expect(
        agents(StateManagement.riverpod, withDio: true),
        contains('safeApiCall'),
      );
      expect(
        agents(StateManagement.riverpod, withDio: true),
        isNot(contains('safeFirebaseCall')),
      );
      expect(
        agents(StateManagement.riverpod, withFirebase: true),
        contains('safeFirebaseCall'),
      );
      expect(
        agents(StateManagement.riverpod),
        contains('The datasource translates'),
      );
    });

    test('mentions the router only when the project has one', () {
      expect(
        agents(StateManagement.riverpod, withRouter: true),
        contains('app_routes.dart'),
      );
      expect(
        agents(StateManagement.riverpod),
        isNot(contains('app_routes.dart')),
      );
    });

    test('points status colors at the theme extension when it exists', () {
      expect(
        agents(StateManagement.riverpod, withStatusColors: true),
        contains('context.statusColors'),
      );
      expect(
        agents(StateManagement.riverpod),
        isNot(contains('context.statusColors')),
      );
    });

    test('adds the localization rule for whichever approach is installed', () {
      expect(agents(StateManagement.riverpod), isNot(contains('Localization')));
      expect(
        agents(StateManagement.riverpod, withLocalization: true),
        contains('.arb'),
      );
      expect(
        agents(StateManagement.riverpod, withEasyLocalization: true),
        contains("'key'.tr()"),
      );
    });
  });

  group('CLAUDE.md', () {
    test('imports AGENTS.md rather than repeating it', () {
      final source = AgentsTemplates.claudeMd();
      expect(source, contains('@AGENTS.md'));
      expect(source, isNot(contains('No entity layer')));
    });
  });

  group('catalog', () {
    test('both files are refreshable Docs entries', () {
      expect(ScaffoldCatalog.byName('agents')?.path, 'AGENTS.md');
      expect(ScaffoldCatalog.byName('claude-md')?.path, 'CLAUDE.md');
      expect(
        ScaffoldCatalog.byGroup('docs').map((s) => s.name),
        containsAll(['agents', 'claude-md']),
      );
    });
  });
}
