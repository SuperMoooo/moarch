import 'package:moarch/src/templates/misc/project_docs_templates.dart';
import 'package:moarch/src/templates/misc/readme_templates.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

DocsOptions options({
  StateManagement stack = StateManagement.riverpod,
  List<String> flavors = const [],
  bool withDio = true,
  bool withRouter = true,
  bool withFirebase = false,
  bool withWorkflows = true,
  bool withDarkTheme = false,
  bool withAuthFeature = false,
  bool withLocalCache = false,
  bool withLocalization = false,
  bool withNotifications = false,
}) => DocsOptions(
  projectName: 'acme_app',
  stateManagement: stack,
  flavors: flavors,
  withDio: withDio,
  withRouter: withRouter,
  withFirebase: withFirebase,
  withFirestore: withFirebase,
  withCrashlytics: withFirebase,
  withWorkflows: withWorkflows,
  withDarkTheme: withDarkTheme,
  withAuthFeature: withAuthFeature,
  withLocalCache: withLocalCache,
  withLocalization: withLocalization,
  withNotifications: withNotifications,
);

String readme({
  StateManagement stack = StateManagement.riverpod,
  List<String> flavors = const [],
  bool withDio = true,
  bool withRouter = true,
  bool withFirebase = false,
  bool withWorkflows = true,
  bool withDarkTheme = false,
}) => ReadmeTemplates.projectReadme(
  options(
    stack: stack,
    flavors: flavors,
    withDio: withDio,
    withRouter: withRouter,
    withFirebase: withFirebase,
    withWorkflows: withWorkflows,
    withDarkTheme: withDarkTheme,
  ),
);

String guide(String file, DocsOptions o) => ProjectDocsTemplates.written
    .firstWhere((doc) => doc.file == file)
    .render!(o);

/// Every `## ` heading, in order — the table of contents links to these, so a
/// heading that changes without its anchor is a broken link in the shipped
/// file.
List<String> headings(String source) => source
    .split('\n')
    .where((line) => line.startsWith('## '))
    .map((line) => line.substring(3))
    .toList();

/// GitHub's heading-anchor slug: lowercased, punctuation dropped, whitespace
/// hyphenated. `2. Getting started` becomes `2-getting-started`.
String slug(String heading) => heading
    .toLowerCase()
    .replaceAll(RegExp(r'[^\w\s-]'), '')
    .trim()
    .replaceAll(RegExp(r'\s'), '-');

/// Every option on, for the checks that must hold whatever the project has.
DocsOptions everything(StateManagement stack) => DocsOptions(
  projectName: 'acme_app',
  stateManagement: stack,
  flavors: const ['dev', 'prod'],
  withDio: true,
  withRouter: true,
  withAuthFeature: true,
  withFirebase: true,
  withFirestore: true,
  withCrashlytics: true,
  withFirebaseNotifications: true,
  withNotifications: true,
  withLocalization: true,
  withBiometric: true,
  withDarkTheme: true,
  withThemeMode: true,
  withStatusColors: true,
  withMoAdapt: true,
  withWorkflows: true,
  withLocalCache: true,
  withSync: true,
  withOfflineGate: true,
  withDeepLinks: true,
  withMaintenanceGate: true,
  withUpdateGate: true,
  withMediaService: true,
  withUrlService: true,
  withDebouncer: true,
  withAppLifecycle: true,
  withPreferences: true,
);

void main() {
  group('projectReadme', () {
    test('names the project it was generated for', () {
      expect(readme(), contains('# 📱 acme_app'));
    });

    test('every table-of-contents anchor points at a heading in the file', () {
      for (final stack in StateManagement.values) {
        final source = readme(stack: stack);
        final anchors = RegExp(
          r'^\d+\. \[[^\]]+\]\(#([^)]+)\)$',
          multiLine: true,
        ).allMatches(source).map((match) => match.group(1)!).toList();
        final slugs = headings(source).map(slug).toSet();

        expect(anchors, isNotEmpty, reason: '$stack has no table of contents');
        for (final anchor in anchors) {
          expect(slugs, contains(anchor), reason: '$stack: broken anchor');
        }
      }
    });

    test('the commands it gives are fvm-prefixed, since the SDK is pinned', () {
      for (final stack in StateManagement.values) {
        final sources = [
          readme(stack: stack),
          for (final doc in ProjectDocsTemplates.written)
            doc.render!(everything(stack)),
        ];
        for (final source in sources) {
          // Everything that builds, runs or generates against the project has
          // to go through the pinned SDK. `dart run flutter_flavorizr` is
          // quoted as `moarch create flavors` prints it, so it is left out.
          expect(
            RegExp(
              r'^(flutter (run|build|test|clean|devices|analyze|pub|gen-l10n)'
              r'|dart run (build_runner|drift_dev))',
              multiLine: true,
            ).allMatches(source),
            isEmpty,
            reason: '$stack: an unprefixed project command',
          );
        }
        expect(readme(stack: stack), contains('fvm flutter pub get'));
        expect(
          readme(stack: stack),
          contains('fvm dart run build_runner build'),
        );
      }
    });

    test('is the front page: the topics are guides of their own', () {
      final source = readme();
      expect(source, contains('## 5. Guides'));
      expect(source, isNot(contains('## How the architecture works')));
      expect(source, isNot(contains('BlocBuilder')));
      expect(source, isNot(contains('IOS_P12_BASE64')));
    });

    test('the guides table links exactly the guides the project has', () {
      final source = readme();
      expect(source, contains('| [Architecture](docs/ARCHITECTURE.md) |'));
      expect(source, contains('| [Networking](docs/NETWORKING.md) |'));
      expect(source, contains('| [UI kit](docs/UI_KIT.md) |'));
      expect(readme(withDio: false), isNot(contains('docs/NETWORKING.md')));
      expect(readme(), isNot(contains('docs/AUTH.md')));
      expect(readme(), isNot(contains('docs/OFFLINE_FIRST.md')));
    });

    test('the Firebase guide is linked only when Firebase is installed', () {
      expect(readme(withFirebase: true), contains('docs/FIREBASE_SETUP.md'));
      expect(readme(), isNot(contains('docs/FIREBASE_SETUP.md')));
    });

    test('a project without Dio is not told it has an HTTP client', () {
      final source = readme(withDio: false);

      expect(source, isNot(contains('[Dio](https://pub.dev/packages/dio)')));
      expect(source, isNot(contains('dio_smart_retry')));
    });
  });

  group('the guides', () {
    test('each one has a title and a link back to the README', () {
      for (final stack in StateManagement.values) {
        for (final doc in ProjectDocsTemplates.written) {
          final source = doc.render!(everything(stack));
          expect(source, startsWith('# '), reason: doc.file);
          expect(
            source,
            contains('> Part of the [project guide](../README.md).'),
            reason: doc.file,
          );
          // A README section moved over whole would keep its number.
          expect(
            source,
            isNot(contains(RegExp(r'^## \d+\.', multiLine: true))),
            reason: doc.file,
          );
          expect(
            source,
            isNot(contains(RegExp(r'\bsection \d+\b'))),
            reason: '${doc.file} still points at a README section number',
          );
        }
      }
    });

    test('every docs/ path they name is a guide the project gets', () {
      final known = {for (final doc in ProjectDocsTemplates.all) doc.path};
      for (final stack in StateManagement.values) {
        final o = everything(stack);
        for (final source in [
          readme(stack: stack),
          for (final doc in ProjectDocsTemplates.written) doc.render!(o),
        ]) {
          for (final match in RegExp(r'docs/[A-Z_]+\.md').allMatches(source)) {
            expect(known, contains(match[0]), reason: match[0]);
          }
        }
      }
    });

    test(
      'the slugs are unique and never collide with another catalog name',
      () {
        final slugs = [for (final doc in ProjectDocsTemplates.all) doc.slug];
        expect(slugs.toSet(), hasLength(slugs.length));
      },
    );

    test('each one appears only when the project has what it describes', () {
      bool has(String file, DocsOptions o) => ProjectDocsTemplates.all
          .firstWhere((doc) => doc.file == file)
          .applies(o);
      expect(has('NETWORKING.md', options(withDio: false)), isFalse);
      expect(has('AUTH.md', options()), isFalse);
      expect(has('AUTH.md', options(withAuthFeature: true)), isTrue);
      expect(has('ROUTING.md', options(withRouter: false)), isFalse);
      expect(has('LOCALIZATION.md', options()), isFalse);
      expect(has('LOCALIZATION.md', options(withLocalization: true)), isTrue);
      expect(has('NOTIFICATIONS.md', options()), isFalse);
      expect(has('ARCHITECTURE.md', options(withDio: false)), isTrue);
    });
  });

  group('state management guide', () {
    test('riverpod gets the notifier stack and no bloc vocabulary', () {
      final source = guide('STATE_MANAGEMENT.md', options());

      expect(source, contains('# State management — Riverpod'));
      expect(source, contains('AsyncNotifierProvider'));
      expect(source, contains('runAction'));
      expect(source, contains('presentation/notifiers/'));
      expect(source, isNot(contains('BlocBuilder')));
      expect(source, isNot(contains('flutter_bloc')));
    });

    test('bloc gets the event/state stack and no riverpod vocabulary', () {
      final source = guide(
        'STATE_MANAGEMENT.md',
        options(stack: StateManagement.bloc),
      );

      expect(source, contains('# State management — Bloc'));
      expect(source, contains('BlocBuilder'));
      expect(source, contains('sealed class ProfileEvent'));
      expect(source, contains('presentation/blocs/'));
      expect(source, isNot(contains('AsyncNotifier')));
      expect(source, isNot(contains('ref.watch')));
    });

    test('both stacks read their repository out of get_it', () {
      for (final stack in StateManagement.values) {
        expect(
          guide('ARCHITECTURE.md', options(stack: stack)),
          contains('getIt<ProfileRepository>()'),
        );
      }
    });
  });

  group('flavors guide', () {
    test('a project without flavors gets the setup walkthrough', () {
      final source = guide('FLAVORS.md', options());

      expect(source, contains('does **not** have flavors yet'));
      expect(source, contains('moarch create flavors dev staging prod'));
      expect(source, isNot(contains('fvm flutter run --flavor')));
    });

    test('a project with flavors gets its own names and commands', () {
      final o = options(flavors: const ['dev', 'staging', 'prod']);

      expect(guide('FLAVORS.md', o), contains('`dev`, `staging`, `prod`'));
      expect(guide('FLAVORS.md', o), contains('fvm flutter run --flavor dev'));
      expect(
        guide('BUILD_AND_RELEASE.md', o),
        contains('fvm flutter build apk --flavor prod --release'),
      );
      expect(
        guide('BUILD_AND_RELEASE.md', o),
        contains('app-prod-release.apk'),
      );
    });

    test('the single entry point is called out', () {
      expect(
        guide('FLAVORS.md', options(flavors: const ['dev', 'prod'])),
        contains('There is only one `main.dart`.'),
      );
    });
  });

  group('build & release guide', () {
    test('names every secret the generated workflows read', () {
      final source = guide('BUILD_AND_RELEASE.md', options());

      for (final secret in [
        'BASE_URL',
        'IOS_P12_BASE64',
        'IOS_P12_PASSWORD',
        'IOS_PROVISIONING_PROFILE_BASE64',
        'IOS_TEAM_ID',
        'APP_STORE_CONNECT_KEY_ID',
        'APP_STORE_CONNECT_ISSUER_ID',
        'APP_STORE_CONNECT_KEY_BASE64',
      ]) {
        expect(source, contains(secret));
      }
    });

    test('points at the documents that produce them', () {
      final source = guide('BUILD_AND_RELEASE.md', options());

      expect(source, contains('docs/STEPS_FOR_WORKFLOW.md'));
      expect(source, contains('docs/GENERATE_JKS_FILE.md'));
      expect(source, isNot(contains('openssl')));
    });

    test('a project without workflows gets no secrets table', () {
      final source = guide(
        'BUILD_AND_RELEASE.md',
        options(withWorkflows: false),
      );

      expect(source, isNot(contains('IOS_P12_BASE64')));
      expect(source, contains('has no GitHub Actions workflows'));
      expect(source, contains('docs/STEPS_FOR_WORKFLOW.md'));
    });
  });

  group('the topic guides', () {
    test("widgets get their own file in the feature's widgets/ folder", () {
      for (final stack in StateManagement.values) {
        expect(
          guide('CODE_STANDARDS.md', options(stack: stack)),
          contains('**Split a screen by section, not by widget.**'),
        );
        expect(readme(stack: stack), contains('└── widgets/'));
      }
    });

    test('the hard-coded-colour rule appears only with a dark palette', () {
      expect(
        guide('CODE_STANDARDS.md', options(withDarkTheme: true)),
        contains('Never hard-code a `Color`'),
      );
      expect(
        guide('CODE_STANDARDS.md', options()),
        isNot(contains('Never hard-code a `Color`')),
      );
    });

    test('a project without a router is not told to add routes', () {
      expect(
        guide('ARCHITECTURE.md', options(withRouter: false)),
        isNot(contains('app_router.dart')),
      );
    });

    test('networking describes the token refresh only with REST auth', () {
      expect(
        guide('NETWORKING.md', options(withAuthFeature: true)),
        contains('## The token refresh'),
      );
      expect(
        guide('NETWORKING.md', options()),
        isNot(contains('## The token refresh')),
      );
    });

    test('auth names the stack-specific entry point', () {
      expect(
        guide('AUTH.md', options(withAuthFeature: true)),
        contains('ref.read(authNotifierProvider.notifier).login('),
      );
      expect(
        guide(
          'AUTH.md',
          options(stack: StateManagement.bloc, withAuthFeature: true),
        ),
        contains('context.read<AuthBloc>().add(AuthLoginRequested('),
      );
    });

    test('services lists only the services the project has', () {
      final bare = guide('SERVICES.md', options(withDio: false));
      expect(bare, contains('`PermissionService`'));
      expect(bare, isNot(contains('`MediaService`')));
      expect(
        guide('SERVICES.md', everything(StateManagement.riverpod)),
        contains('`MediaService`'),
      );
    });

    test('the architecture guide offers create table only with the cache', () {
      expect(
        guide('ARCHITECTURE.md', options(withLocalCache: true)),
        contains('moarch create table <feature>'),
      );
      expect(
        guide('ARCHITECTURE.md', options()),
        isNot(contains('moarch create table')),
      );
    });
  });

  group('markdown shape', () {
    Iterable<(String, String)> everyFile() sync* {
      for (final stack in StateManagement.values) {
        yield ('$stack README', readme(stack: stack));
        for (final doc in ProjectDocsTemplates.written) {
          yield ('$stack ${doc.file}', doc.render!(everything(stack)));
          yield (
            '$stack ${doc.file} (bare)',
            doc.render!(
              options(stack: stack, withDio: false, withRouter: false),
            ),
          );
        }
      }
    }

    test('every horizontal rule is followed by a blank line', () {
      for (final (name, source) in everyFile()) {
        final lines = source.split('\n');
        for (var i = 0; i < lines.length - 1; i++) {
          if (lines[i] == '---') {
            expect(lines[i + 1], isEmpty, reason: '$name: line ${i + 2}');
          }
        }
      }
    });

    test("every table row has its header's column count", () {
      for (final (name, source) in everyFile()) {
        final lines = source.split('\n');
        var columns = 0;
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!line.startsWith('|')) {
            columns = 0;
            continue;
          }
          final count = '|'.allMatches(line).length;
          if (columns == 0) {
            columns = count;
          } else {
            expect(
              count,
              columns,
              reason: '$name: ragged row ${i + 1}:\n$line',
            );
          }
        }
      }
    });

    test('no conditional chunk leaked a run of blank lines', () {
      for (final (name, source) in everyFile()) {
        expect(source, isNot(contains('\n\n\n')), reason: name);
      }
    });

    test('code fences are balanced', () {
      for (final (name, source) in everyFile()) {
        final fences = RegExp(r'^\s*```', multiLine: true).allMatches(source);
        expect(fences.length.isEven, isTrue, reason: name);
      }
    });
  });
}
