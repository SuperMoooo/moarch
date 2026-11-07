import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

/// `moarch release` — the steps of shipping a build that are moarch's to do.
class ReleaseCommand extends Command<int> {
  /// Creates the release command and its subcommands.
  ReleaseCommand({required Logger logger}) : _logger = logger {
    addSubcommand(BumpCommand(logger: logger));
  }

  final Logger _logger;

  @override
  String get name => 'release';

  @override
  String get description => 'Prepare a release: bump the version.';

  @override
  Future<int> run() async {
    _logger.info(usage);
    return 0;
  }
}

/// A `version:` from `pubspec.yaml`: `1.4.2+37`.
class AppVersion {
  /// Creates a version.
  const AppVersion(this.major, this.minor, this.patch, this.build);

  /// Reads `1.4.2+37`, or `1.4.2` (build 0). Null when it is not one.
  static AppVersion? tryParse(String text) {
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$',
    ).firstMatch(text.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      int.parse(match[4] ?? '0'),
    );
  }

  /// The marketing version's parts.
  final int major, minor, patch;

  /// The build number: Android's `versionCode`, iOS's `CFBundleVersion`.
  final int build;

  /// The version after a [part] bump. Every bump raises the build number too,
  /// since both stores refuse an upload whose build number is not higher
  /// than the last one.
  AppVersion bump(String part) => switch (part) {
    'major' => AppVersion(major + 1, 0, 0, build + 1),
    'minor' => AppVersion(major, minor + 1, 0, build + 1),
    'patch' => AppVersion(major, minor, patch + 1, build + 1),
    'build' => AppVersion(major, minor, patch, build + 1),
    _ => throw ArgumentError.value(part, 'part'),
  };

  /// `1.4.2`, what the stores show.
  String get name => '$major.$minor.$patch';

  @override
  String toString() => '$name+$build';
}

/// `moarch release bump <major|minor|patch|build>`.
class BumpCommand extends Command<int> {
  /// Creates the bump command.
  BumpCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: '.',
        help: 'The project root, where pubspec.yaml is.',
      )
      ..addFlag(
        'changelog',
        abbr: 'c',
        negatable: false,
        help: 'Also add an entry for the new version to CHANGELOG.md.',
      )
      ..addFlag(
        'dry-run',
        abbr: 'd',
        negatable: false,
        help: 'Print the new version without writing anything.',
      );
  }

  final Logger _logger;

  static const _parts = ['major', 'minor', 'patch', 'build'];

  @override
  String get name => 'bump';

  @override
  String get description =>
      'Raise the version in pubspec.yaml — major, minor, patch or just the '
      'build number, which every bump raises.';

  @override
  String get invocation => 'moarch release bump <major|minor|patch|build>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.length != 1 || !_parts.contains(rest.single)) {
      _logger.err('Say what to bump: $invocation');
      return 64;
    }
    final part = rest.single;
    final root = argResults?['path'] as String? ?? '.';
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final withChangelog = argResults?['changelog'] as bool? ?? false;

    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      _logger.err('No pubspec.yaml at ${p.absolute(root)}.');
      return 1;
    }
    final source = pubspec.readAsStringSync();
    // No end anchor: on a CRLF checkout `$` would not match before the `\r`,
    // and `\S+` already stops at the line's end.
    final line = RegExp(r'^version:[ \t]*(\S+)', multiLine: true);
    final match = line.firstMatch(source);
    if (match == null) {
      _logger.err('pubspec.yaml has no `version:` line.');
      return 1;
    }
    final current = AppVersion.tryParse(match[1]!);
    if (current == null) {
      _logger.err(
        '`version: ${match[1]}` is not major.minor.patch+build '
        '(e.g. 1.4.2+37).',
      );
      return 1;
    }

    final next = current.bump(part);
    _logger.info('  $current → $next');
    if (dryRun) {
      _logger.info('  Dry run — nothing written.');
      return 0;
    }

    pubspec.writeAsStringSync(
      source.replaceRange(match.start, match.end, 'version: $next'),
    );
    if (withChangelog && part != 'build') _addChangelogEntry(root, next);

    _logger.success('  pubspec.yaml is at $next.');
    if (part == 'build') {
      _logger.info('  Same version, new build: a rebuild for the stores.');
    }
    return 0;
  }

  /// Puts a `## <version>` entry at the top of `CHANGELOG.md`, newest first,
  /// creating the file when there is none.
  void _addChangelogEntry(String root, AppVersion version) {
    final file = File(p.join(root, 'CHANGELOG.md'));
    final entry = '## ${version.name}\n\n- TODO: what changed for users.\n';
    if (!file.existsSync()) {
      file.writeAsStringSync('# Changelog\n\n$entry');
      _logger.info('  CHANGELOG.md created.');
      return;
    }
    final source = file.readAsStringSync();
    if (source.contains('## ${version.name}\n')) return;
    // Under the title (the first `# ` line) when there is one, else on top.
    final title = RegExp(r'^# .*\n+', multiLine: true).firstMatch(source);
    final at = title != null && title.start == 0 ? title.end : 0;
    file.writeAsStringSync(
      '${source.substring(0, at)}$entry\n${source.substring(at)}',
    );
    _logger.info('  CHANGELOG.md has a ${version.name} entry to fill in.');
  }
}
