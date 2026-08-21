import 'package:moarch/src/templates/misc/readme_templates.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

String readme({
  StateManagement stack = StateManagement.riverpod,
  List<String> flavors = const [],
  bool withDio = true,
  bool withRouter = true,
  bool withFirebase = false,
  bool withWorkflows = true,
  bool withDarkTheme = false,
}) =>
    ReadmeTemplates.projectReadme(
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
    );

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

void main() {
  group('projectReadme', () {
    test('names the project it was generated for', () {
      expect(readme(), contains('# 📱 acme_app'));
    });

    test('every table-of-contents anchor points at a heading in the file', () {
      for (final stack in StateManagement.values) {
        final source = readme(stack: stack);
        final anchors =
            RegExp(r'^\d+\. \[[^\]]+\]\(#([^)]+)\)$', multiLine: true)
                .allMatches(source)
                .map((match) => match.group(1)!)
                .toList();
        final slugs = headings(source).map(slug).toSet();

        expect(anchors, isNotEmpty, reason: '$stack has no table of contents');
        for (final anchor in anchors) {
          expect(slugs, contains(anchor), reason: '$stack: broken anchor');
        }
      }
    });

    test('the commands it gives are fvm-prefixed, since the SDK is pinned', () {
      for (final stack in StateManagement.values) {
        final source = readme(stack: stack);

        // Everything that builds, runs or generates against the project has
        // to go through the pinned SDK. Three commands deliberately do not
        // and are excluded by the verb list: `flutter --version`, shown to
        // contrast with the fvm one; `dart pub global activate`, which
        // installs fvm itself; and `dart run flutter_flavorizr`, quoted as
        // `moarch create flavors` prints it.
        expect(
          RegExp(
            r'^(flutter (run|build|test|clean|devices|analyze|pub|gen-l10n)'
            r'|dart run build_runner)',
            multiLine: true,
          ).allMatches(source),
          isEmpty,
          reason: '$stack: an unprefixed project command',
        );
        expect(source, contains('fvm flutter pub get'));
        expect(source, contains('fvm dart run build_runner build'));
      }
    });
  });

  group('state management section', () {
    test('riverpod gets the notifier stack and no bloc vocabulary', () {
      final source = readme();

      expect(source, contains('## 6. State management — Riverpod'));
      expect(source, contains('AsyncNotifierProvider'));
      expect(source, contains('runAction'));
      expect(source, contains('presentation/notifiers/'));
      expect(source, isNot(contains('BlocBuilder')));
      expect(source, isNot(contains('flutter_bloc')));
    });

    test('bloc gets the event/state stack and no riverpod vocabulary', () {
      final source = readme(stack: StateManagement.bloc);

      expect(source, contains('## 6. State management — Bloc'));
      expect(source, contains('BlocBuilder'));
      expect(source, contains('sealed class ProfileEvent'));
      expect(source, contains('presentation/blocs/'));
      expect(source, isNot(contains('AsyncNotifier')));
      expect(source, isNot(contains('ref.watch')));
    });

    test('both stacks read their repository out of get_it', () {
      for (final stack in StateManagement.values) {
        expect(readme(stack: stack), contains('getIt<ProfileRepository>()'));
      }
    });
  });

  group('flavors', () {
    test('a project without flavors gets the setup walkthrough', () {
      final source = readme();

      expect(source, contains('does **not** have flavors yet'));
      expect(source, contains('moarch create flavors dev staging prod'));
      expect(source, isNot(contains('fvm flutter run --flavor')));
    });

    test('a project with flavors gets its own names and commands', () {
      final source = readme(flavors: const ['dev', 'staging', 'prod']);

      expect(source, contains('`dev`, `staging`, `prod`'));
      expect(source, contains('fvm flutter run --flavor dev'));
      expect(source, contains('fvm flutter build apk --flavor prod --release'));
      expect(source, contains('app-prod-release.apk'));
      expect(source, isNot(contains('does **not** have flavors yet')));
    });

    test(
        'the single entry point is called out — flavorizr generates no '
        'per-flavor main here', () {
      expect(
        readme(flavors: const ['dev', 'prod']),
        contains('There is only one `main.dart`.'),
      );
    });
  });

  group('CI/CD', () {
    test('names every secret the generated workflows read', () {
      final source = readme();

      for (final secret in [
        'BASE_URL',
        'IOS_P12_BASE64',
        'IOS_P12_PASSWORD',
        'IOS_PROVISIONING_PROFILE_BASE64',
        'IOS_TEAM_ID',
        'ANDROID_KEYSTORE_BASE64',
        'KEYSTORE_STORE_PASSWORD',
        'KEYSTORE_KEY_PASSWORD',
        'KEYSTORE_KEY_ALIAS',
      ]) {
        expect(source, contains(secret));
      }
    });

    test(
        'points at the documents that produce them rather than repeating the '
        'recipe', () {
      final source = readme();

      expect(source, contains('docs/STEPS_FOR_WORKFLOW.md'));
      expect(source, contains('docs/GENERATE_JKS_FILE.md'));
      expect(source, isNot(contains('openssl')));
    });

    test('a project without workflows gets no secrets table', () {
      final source = readme(withWorkflows: false);

      expect(source, isNot(contains('IOS_P12_BASE64')));
      expect(source, contains('has no GitHub Actions workflows'));
      // The pointers survive: the secrets matter the day workflows are added.
      expect(source, contains('docs/STEPS_FOR_WORKFLOW.md'));
    });
  });

  group('detected options', () {
    test('the Firebase guide is referenced only when Firebase is installed',
        () {
      expect(readme(withFirebase: true), contains('docs/FIREBASE_SETUP.md'));
      expect(readme(), isNot(contains('docs/FIREBASE_SETUP.md')));
    });

    test('the hard-coded-colour rule appears only with a dark palette', () {
      expect(
        readme(withDarkTheme: true),
        contains('Never hard-code a `Color`'),
      );
      expect(readme(), isNot(contains('Never hard-code a `Color`')));
    });

    test('a project without Dio is not told it has an HTTP client', () {
      final source = readme(withDio: false);

      expect(source, isNot(contains('[Dio](https://pub.dev/packages/dio)')));
      expect(source, isNot(contains('dio_smart_retry')));
    });

    test('a project without a router is not told to add routes', () {
      expect(readme(withRouter: false), isNot(contains('app_router.dart')));
    });
  });

  group('markdown shape', () {
    test('every horizontal rule is followed by a blank line', () {
      for (final stack in StateManagement.values) {
        final lines = readme(stack: stack).split('\n');
        for (var i = 0; i < lines.length - 1; i++) {
          if (lines[i] == '---') {
            expect(lines[i + 1], isEmpty,
                reason: '$stack: line ${i + 2} follows a rule directly');
          }
        }
      }
    });

    test('every table row has its header\'s column count', () {
      for (final stack in StateManagement.values) {
        final lines = readme(stack: stack).split('\n');
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
            expect(count, columns,
                reason: '$stack: ragged table row at line ${i + 1}:\n$line');
          }
        }
      }
    });

    test('no conditional chunk leaked a run of blank lines', () {
      for (final stack in StateManagement.values) {
        expect(readme(stack: stack), isNot(contains('\n\n\n')),
            reason: '$stack has a triple newline');
      }
    });
  });
}
