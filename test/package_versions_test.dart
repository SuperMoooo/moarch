import 'dart:io';

import 'package:moarch/src/utils/package_versions.dart';
import 'package:test/test.dart';

void main() {
  group('PackageVersions', () {
    test('every package moarch adds carries a constraint', () {
      // The table is the reason `init` no longer writes `any`. A package added
      // to init without an entry here would silently fall back to it, so this
      // reads the command's source and holds the two in step.
      final source =
          File('lib/src/commands/init_command.dart').readAsStringSync();
      final asked = RegExp(r"PackageVersions\.entry\('([a-z_0-9]+)'\)")
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();

      expect(asked, isNotEmpty,
          reason: 'init should resolve through the table');
      for (final package in asked) {
        expect(
          PackageVersions.packages,
          contains(package),
          reason: '$package is added by init but has no constraint',
        );
      }
    });

    test('constraints are carets, so no major lands unasked', () {
      for (final package in PackageVersions.packages) {
        final constraint = PackageVersions.constraintFor(package);
        if (package == 'intl') {
          // The one exception, and it has a reason: flutter_localizations
          // pins intl exactly, so any caret here eventually fails to resolve.
          expect(constraint, 'any');
          continue;
        }
        expect(
          constraint,
          startsWith('^'),
          reason: '$package should be capped at its major version',
        );
      }
    });

    test('an unknown package degrades to any rather than throwing', () {
      expect(PackageVersions.constraintFor('not_a_real_package'), 'any');
    });

    test('entry writes a pubspec line', () {
      expect(PackageVersions.entry('dio'), startsWith('dio: ^'));
    });
  });
}
