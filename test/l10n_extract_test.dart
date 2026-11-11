import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/l10n_command.dart';
import 'package:moarch/src/l10n/string_extractor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _view = r'''
import 'package:material_ui/material_ui.dart';

class OrdersView extends StatelessWidget {
  const OrdersView({super.key, this.subtitle = 'Default value'});

  final String subtitle;

  static const routeName = 'Orders route';

  @override
  Widget build(BuildContext context) {
    final name = 'Ana';
    debugPrint('Built the orders screen');
    return Scaffold(
      appBar: AppBar(title: const Text('Your orders')),
      body: const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No orders yet'),
      ),
      floatingActionButton: TextField(
        decoration: InputDecoration(hintText: 'Search orders'),
      ),
      bottomNavigationBar: Column(
        children: [
          Text('Hello $name'),
          Text('order_id'),
          Text('Use {count}'),
          _footer(),
        ],
      ),
    );
  }

  Widget _footer() => const Text('Thanks for shopping');
}
''';

void main() {
  group('StringExtractor.find', () {
    final found = StringExtractor.find(_view);
    FoundString? of(String text) {
      for (final f in found) {
        if (f.text == text) return f;
      }
      return null;
    }

    test('finds Text, titles and hints shown to the user', () {
      expect(of('Your orders')?.contextName, 'context');
      expect(of('No orders yet')?.rewritable, isTrue);
      expect(of('Search orders')?.contextName, 'context');
    });

    test('leaves logs, keys and plain constants alone', () {
      expect(of('Built the orders screen'), isNull);
      expect(of('order_id'), isNull);
      expect(of('Orders route'), isNull);
      expect(of('Ana'), isNull);
    });

    test('reports what it cannot rewrite safely', () {
      expect(of('Use {count}')?.rewritable, isFalse);
      expect(
        found.where((f) => f.text.contains(r'$name')).single.skipReason,
        contains('interpolates'),
      );
      // A widget method without a BuildContext of its own.
      expect(of('Thanks for shopping')?.contextName, isNull);
    });
  });

  group('StringExtractor.rewrite', () {
    test('reads the key back and takes off the const around it', () {
      final found = StringExtractor.find(_view);
      final keys = {
        for (final f in found)
          if (f.text == 'No orders yet') f.offset: 'noOrdersYet',
        for (final f in found)
          if (f.text == 'Your orders') f.offset: 'yourOrders',
      };
      final out = StringExtractor.rewrite(
        _view,
        keys,
        accessor: L10nAccessor.generated,
        import: '../../../../l10n/app_localizations.dart',
      );
      expect(out, contains('Text(AppLocalizations.of(context)!.yourOrders)'));
      expect(out, contains('body: Padding('));
      expect(
        out,
        contains('child: Text(AppLocalizations.of(context)!.noOrdersYet)'),
      );
      expect(out, isNot(contains('const Padding')));
      expect(
        out,
        contains("import '../../../../l10n/app_localizations.dart';"),
      );
      // Untouched elsewhere: the EdgeInsets inside keeps nothing to lose.
      expect(out, contains("hintText: 'Search orders'"));
    });

    test('easy_localization reads a key with .tr()', () {
      final found = StringExtractor.find(_view);
      final f = found.firstWhere((f) => f.text == 'Search orders');
      final out = StringExtractor.rewrite(
        _view,
        {f.offset: 'searchOrders'},
        accessor: L10nAccessor.easyLocalization,
        import: 'package:easy_localization/easy_localization.dart',
      );
      expect(out, contains("hintText: 'searchOrders'.tr()"));
      expect(
        out,
        contains("import 'package:easy_localization/easy_localization.dart';"),
      );
    });
  });

  group('L10nKeys', () {
    test('camelCase from the first words', () {
      expect(L10nKeys.fromText('Forgot password?'), 'forgotPassword');
      expect(L10nKeys.fromText('Olá, mundo!'), 'olaMundo');
      expect(L10nKeys.fromText('2 items left'), 'text2ItemsLeft');
      expect(L10nKeys.fromText('?!'), 'text');
    });

    test('reuses a key with the same text and never collides', () {
      final existing = {'signIn': 'Sign in', 'save': 'Store it'};
      expect(L10nKeys.assign('Sign in', existing), 'signIn');
      expect(L10nKeys.assign('Save', existing), 'save2');
    });
  });

  group('l10n extract', () {
    late Directory root;
    late CommandRunner<int> runner;

    File file(String relative) =>
        File(p.joinAll([root.path, ...relative.split('/')]));
    void write(String relative, String content) => (file(
      relative,
    )..createSync(recursive: true)).writeAsStringSync(content);

    setUp(() async {
      root = await Directory.systemTemp.createTemp('moarch_l10n_test');
      write('pubspec.yaml', 'name: demo\n');
      write('lib/features/orders/presentation/views/orders_view.dart', _view);
      runner = CommandRunner<int>('moarch', 'test')
        ..addCommand(L10nCommand(logger: Logger(level: Level.quiet)));
    });

    tearDown(() async => root.delete(recursive: true));

    test(
      'flutter_localizations: keys in every .arb, screens rewritten',
      () async {
        write(
          'l10n.yaml',
          'arb-dir: lib/l10n\ntemplate-arb-file: app_en.arb\n'
              'output-localization-file: app_localizations.dart\n',
        );
        write(
          'lib/l10n/app_en.arb',
          '{\n  "@@locale": "en",\n  "welcome": "Welcome"\n}\n',
        );
        write(
          'lib/l10n/app_pt.arb',
          '{\n  "@@locale": "pt",\n  "welcome": "Bem-vindo"\n}\n',
        );

        expect(await runner.run(['l10n', 'extract', '--path', root.path]), 0);

        final en =
            jsonDecode(file('lib/l10n/app_en.arb').readAsStringSync())
                as Map<String, dynamic>;
        expect(en['yourOrders'], 'Your orders');
        expect(en['searchOrders'], 'Search orders');
        expect(en['welcome'], 'Welcome');
        final pt =
            jsonDecode(file('lib/l10n/app_pt.arb').readAsStringSync())
                as Map<String, dynamic>;
        expect(pt['yourOrders'], 'Your orders');
        expect(pt['welcome'], 'Bem-vindo');

        final view = file(
          'lib/features/orders/presentation/views/orders_view.dart',
        ).readAsStringSync();
        expect(
          view,
          contains("import '../../../../l10n/app_localizations.dart';"),
        );
        expect(view, contains('AppLocalizations.of(context)!.searchOrders'));
        // No context in _footer: left for the developer.
        expect(view, contains("const Text('Thanks for shopping')"));
      },
    );

    test('a dry run writes nothing', () async {
      write('l10n.yaml', 'arb-dir: lib/l10n\ntemplate-arb-file: app_en.arb\n');
      write('lib/l10n/app_en.arb', '{"@@locale": "en"}\n');
      expect(
        await runner.run(['l10n', 'extract', '--dry-run', '--path', root.path]),
        0,
      );
      expect(
        file('lib/l10n/app_en.arb').readAsStringSync(),
        '{"@@locale": "en"}\n',
      );
    });

    test(
      'easy_localization: keys in every JSON file, read with .tr()',
      () async {
        write('assets/translations/en.json', '{"hello": "Hello"}\n');
        write('assets/translations/pt.json', '{"hello": "Olá"}\n');

        expect(await runner.run(['l10n', 'extract', '--path', root.path]), 0);

        final en =
            jsonDecode(file('assets/translations/en.json').readAsStringSync())
                as Map<String, dynamic>;
        expect(en['thanksForShopping'], 'Thanks for shopping');
        final view = file(
          'lib/features/orders/presentation/views/orders_view.dart',
        ).readAsStringSync();
        // .tr() needs no BuildContext, so the footer moves too.
        expect(view, contains("Text('thanksForShopping'.tr())"));
      },
    );

    test('refuses a project without localization', () async {
      expect(await runner.run(['l10n', 'extract', '--path', root.path]), 1);
    });
  });
}
