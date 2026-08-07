import 'dart:convert';

import 'package:moarch/src/templates/misc/dev_templates.dart';
import 'package:test/test.dart';

/// Both files are JSON-with-comments, which VS Code accepts and `jsonDecode`
/// does not. Dropping the comment lines is enough to check the rest is valid
/// JSON — no string in either template contains `//`.
Map<String, dynamic> _decodeJsonc(String source) {
  final stripped = source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
  return jsonDecode(stripped) as Map<String, dynamic>;
}

void main() {
  group('vscodeSettings', () {
    test('points the extension at the fvm SDK the .fvmrc pins', () {
      final settings = _decodeJsonc(DevTemplates.vscodeSettings());

      expect(settings['dart.flutterSdkPath'], '.fvm/flutter_sdk');
    });

    test('keeps the SDK copy out of search and the file watcher', () {
      final settings = _decodeJsonc(DevTemplates.vscodeSettings());

      expect(settings['search.exclude'], {'**/.fvm': true});
      expect(settings['files.watcherExclude'], {'**/.fvm': true});
    });
  });

  group('vscodeLaunch', () {
    List<Map<String, dynamic>> configurations() =>
        (_decodeJsonc(DevTemplates.vscodeLaunch())['configurations'] as List)
            .cast<Map<String, dynamic>>();

    test(
        'every configuration is a dart launch — the extension defaults to '
        'the scaffold entry point', () {
      for (final config in configurations()) {
        expect(config['type'], 'dart', reason: '${config['name']}');
        expect(config['request'], 'launch', reason: '${config['name']}');
      }
    });

    test('names are unique — the picker addresses them by name', () {
      final names = configurations().map((config) => config['name']).toList();

      expect(names.toSet(), hasLength(names.length));
    });

    test('the unflavored entries cover all three build modes', () {
      final modes = {
        for (final config in configurations())
          if (config['args'] == null) config['name']: config['flutterMode'],
      };

      expect(modes, {
        'debug': 'debug',
        'profile': 'profile',
        'release': 'release',
      });
    });

    test('each flavor is passed to the tool', () {
      for (final flavor in ['dev', 'staging', 'prod']) {
        final flavored = configurations()
            .where((config) =>
                (config['args'] as List?)?.contains(flavor) ?? false)
            .toList();

        expect(flavored, isNotEmpty, reason: flavor);
        for (final config in flavored) {
          expect(
            config['args'],
            ['--flavor', flavor],
            reason: '${config['name']}',
          );
        }
      }
    });

    test('every flavor can be run in debug and in release', () {
      for (final flavor in ['dev', 'staging', 'prod']) {
        final modes = configurations()
            .where((config) =>
                (config['args'] as List?)?.contains(flavor) ?? false)
            .map((config) => config['flutterMode'])
            .toSet();

        expect(
          modes,
          containsAll(<Object?>['debug', 'release']),
          reason: flavor,
        );
      }
    });
  });
}
