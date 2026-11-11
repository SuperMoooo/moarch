import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'project_manifest.dart';

/// The ids a project declares today, read off its platform folders.
class DeclaredAppIds {
  /// Creates the set of ids found in a project.
  const DeclaredAppIds({
    this.applicationId,
    this.namespace,
    this.kotlinPackage,
    this.iosBundleId,
    this.macosBundleId,
  });

  /// `applicationId` in `android/app/build.gradle(.kts)` — the shortest one,
  /// since a flavored project also declares the suffixed ones.
  final String? applicationId;

  /// `namespace` in the same file: the package `R` and `BuildConfig` live in.
  final String? namespace;

  /// The `package` `MainActivity` declares, which is also the folder it sits
  /// in under `src/main/kotlin` (or `java`).
  final String? kotlinPackage;

  /// The iOS app's `PRODUCT_BUNDLE_IDENTIFIER` — the shortest, for the same
  /// reason as [applicationId], and never the `.RunnerTests` one.
  final String? iosBundleId;

  /// The macOS app's `PRODUCT_BUNDLE_IDENTIFIER`, from `AppInfo.xcconfig`.
  final String? macosBundleId;

  /// The Android-style ids: what `<id>` replaces.
  Set<String> get android => {?applicationId, ?namespace, ?kotlinPackage};

  /// The Apple-style ids: what the bundle id replaces.
  Set<String> get apple => {?iosBundleId, ?macosBundleId};

  /// Whether there is any platform folder to rename at all.
  bool get isEmpty => android.isEmpty && apple.isEmpty;
}

/// A file that moves with its package: a Kotlin or Java source under the old
/// package's folder, to the same place under the new one.
class AppIdMove {
  /// Creates a move from [from] to [to], both absolute.
  const AppIdMove(this.from, this.to);

  /// Where the file is now.
  final String from;

  /// Where it goes.
  final String to;
}

/// Everything `moarch package-name` would change, worked out before anything
/// is written — so a dry run reports exactly what a real run does, and a
/// conflict stops the run before the first file is touched.
class AppIdPlan {
  /// Creates a plan.
  const AppIdPlan({
    required this.declared,
    required this.android,
    required this.apple,
    required this.edits,
    required this.moves,
    required this.sourceRoots,
    required this.firebaseConfigs,
    required this.conflicts,
  });

  /// The ids the project declared before the rename.
  final DeclaredAppIds declared;

  /// Old Android-style id → the new one.
  final Map<String, String> android;

  /// Old Apple-style id → the new one.
  final Map<String, String> apple;

  /// Absolute path → its content after the rename, for every file that
  /// changes. Keyed by the path the file has now, moved or not.
  final Map<String, String> edits;

  /// The sources that move to the new package's folder.
  final List<AppIdMove> moves;

  /// Old package folder → the `kotlin`/`java` folder it is under: what is
  /// pruned once the moves have emptied it.
  final Map<String, String> sourceRoots;

  /// Project-relative Firebase configs that still name an old id. The
  /// Firebase console generates them for one registered app, so rewriting the
  /// id in them would describe an app Firebase does not know.
  final List<String> firebaseConfigs;

  /// Moves whose destination is already taken. A plan with any is not applied.
  final List<String> conflicts;

  /// Whether the project already uses the requested ids.
  bool get isEmpty => edits.isEmpty && moves.isEmpty;
}

/// Gives a Flutter project its own application id / bundle id in place of the
/// `com.example.<name>` that `flutter create` writes, everywhere it appears.
abstract final class AppIdUtils {
  /// Java's reserved words. A segment that is one cannot be part of the
  /// `namespace`, since Gradle generates `R` and `BuildConfig` in Java under it.
  static final _javaKeywords =
      ('abstract assert boolean break byte case catch char class const '
              'continue default do double else enum extends false final '
              'finally float for goto if implements import instanceof int '
              'interface long native new null package private protected '
              'public return short static strictfp super switch synchronized '
              'this throw throws transient true try void volatile while')
          .split(' ')
          .toSet();

  /// Kotlin's hard keywords that Java allows. `in.acme.shop` is a valid id
  /// (India's domain), but Kotlin reads `in` as a keyword unless it is
  /// backquoted in `package` and `import` lines.
  static final _kotlinOnlyKeywords =
      'as fun in is object typealias typeof val var when'.split(' ').toSet();

  /// Firebase configs, generated per registered app: reported, never edited.
  static const _firebaseConfigs = {
    'google-services.json',
    'GoogleService-Info.plist',
    'firebase_options.dart',
  };

  /// Folders that are build output, caches or someone else's checkout —
  /// `.fvm/flutter_sdk` is a link to the SDK, whose own templates say
  /// `com.example` and must never be rewritten.
  static final _skippedDirs =
      ('.dart_tool .fvm .git .gradle .idea .cxx .kotlin .pub .pub-cache '
              '.symlinks build DerivedData ephemeral node_modules Pods '
              'xcuserdata')
          .split(' ')
          .toSet();

  /// The text files an id can be written in, by extension.
  static final _textExtensions =
      ('.cmake .dart .entitlements .gradle .h .html .java .js .json .kt .kts '
              '.m .md .mm .pbxproj .plist .pro .properties .rb .rc .sh .swift '
              '.txt .xcconfig .xcscheme .xml .yaml .yml')
          .split(' ')
          .toSet();

  /// Text files with no extension that name the app: fastlane's and
  /// CocoaPods'.
  static final _textNames =
      'Appfile Deliverfile Fastfile Gymfile Matchfile Podfile'
          .split(' ')
          .toSet();

  /// The files `flutter create` writes the bare organization into — the
  /// Windows company name and the macOS copyright — where the id minus its
  /// last segment is replaced as well.
  static const _orgFiles = {
    'windows/runner/Runner.rc',
    'macos/Runner/Configs/AppInfo.xcconfig',
  };

  /// Why [id] cannot be an Android application id, or null when it can.
  static String? androidIdProblem(String id) {
    final segments = id.split('.');
    if (segments.length < 2) {
      return '`$id` has one segment — an app id needs at least two, like '
          'com.acme.shop.';
    }
    for (final segment in segments) {
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(segment)) {
        return '`$id`: each segment must start with a letter and use only '
            'letters, digits and `_` (`$segment` does not).';
      }
      if (_javaKeywords.contains(segment)) {
        return '`$id`: `$segment` is a Java keyword, which Android cannot '
            'use in a package name.';
      }
    }
    return null;
  }

  /// Why [id] cannot be an iOS bundle id, or null when it can.
  static String? appleIdProblem(String id) {
    if (!RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$').hasMatch(id)) {
      return '`$id`: a bundle id is two or more dot-separated segments of '
          'letters, digits and `-`.';
    }
    return null;
  }

  /// The bundle id that goes with [androidId]: the same id, with any
  /// snake_case segment in camelCase (`my_app` → `myApp`), since Apple ids
  /// cannot contain `_`. It is what `flutter create` does with the name.
  static String appleIdFor(String androidId) => androidId
      .split('.')
      .map((segment) {
        final words = segment.split('_').where((w) => w.isNotEmpty).toList();
        if (words.isEmpty) return segment;
        return words.first +
            words
                .skip(1)
                .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
                .join();
      })
      .join('.');

  /// [id] as Kotlin must spell it in a `package` or `import` line: any
  /// segment Kotlin reserves goes in backquotes.
  static String kotlinPackage(String id) => id
      .split('.')
      .map((s) => _kotlinOnlyKeywords.contains(s) ? '`$s`' : s)
      .join('.');

  /// Reads the ids the project at [root] declares now.
  static DeclaredAppIds detect(String root) {
    String? read(String relative) {
      final file = File(p.join(root, relative));
      return file.existsSync() ? file.readAsStringSync() : null;
    }

    String? shortest(Iterable<String> ids) {
      final list = ids.toList()..sort((a, b) => a.length.compareTo(b.length));
      return list.isEmpty ? null : list.first;
    }

    final gradle =
        read('android/app/build.gradle.kts') ??
        read('android/app/build.gradle');
    final applicationId = gradle == null
        ? null
        : shortest(
            RegExp(
              r'''applicationId\s*=?\s*["']([^"']+)["']''',
            ).allMatches(gradle).map((m) => m[1]!),
          );
    final namespace = gradle == null
        ? null
        : RegExp(
            r'''namespace\s*=?\s*["']([^"']+)["']''',
          ).firstMatch(gradle)?[1];

    // The manifest's `.MainActivity` is relative to the namespace, so the one
    // in that package is the app's — a second, stray copy is not.
    final mainActivity =
        [
          if (namespace != null)
            for (final base in ['kotlin', 'java'])
              for (final ext in ['kt', 'java'])
                File(
                  p.joinAll([
                    root,
                    'android/app/src/main',
                    base,
                    ...namespace.split('.'),
                    'MainActivity.$ext',
                  ]),
                ),
        ].where((f) => f.existsSync()).firstOrNull ??
        findMainActivity(root);
    final kotlinPackage = mainActivity == null
        ? null
        : RegExp(r'^\s*package\s+([\w.`]+)', multiLine: true)
              .firstMatch(mainActivity.readAsStringSync())?[1]
              ?.replaceAll('`', '');

    final pbxproj = read('ios/Runner.xcodeproj/project.pbxproj');
    final iosBundleId = pbxproj == null
        ? null
        : shortest(
            RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*"?([^";\s]+)"?;')
                .allMatches(pbxproj)
                .map((m) => m[1]!)
                // A build setting, not an id — nothing to rename in it.
                .where((id) => !id.contains(r'$'))
                .map(
                  (id) => id.endsWith('.RunnerTests')
                      ? id.substring(0, id.length - '.RunnerTests'.length)
                      : id,
                ),
          );

    final appInfo = read('macos/Runner/Configs/AppInfo.xcconfig');
    final macosBundleId = appInfo == null
        ? null
        : RegExp(
            r'^PRODUCT_BUNDLE_IDENTIFIER\s*=\s*(\S+)',
            multiLine: true,
          ).firstMatch(appInfo)?[1];

    return DeclaredAppIds(
      applicationId: applicationId,
      namespace: namespace,
      kotlinPackage: kotlinPackage,
      iosBundleId: iosBundleId,
      macosBundleId: macosBundleId,
    );
  }

  /// `MainActivity.kt` (or `.java`). It sits under a folder named after its
  /// package, which varies per project, so it is searched for.
  static File? findMainActivity(String root) {
    for (final base in ['kotlin', 'java']) {
      final dir = Directory(
        p.join(root, 'android', 'app', 'src', 'main', base),
      );
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File &&
            (entity.path.endsWith('MainActivity.kt') ||
                entity.path.endsWith('MainActivity.java'))) {
          return entity;
        }
      }
    }
    return null;
  }

  /// Replaces every whole mention of an [ids] key in [content] with its value,
  /// in one pass so a new id that contains an old one is never renamed twice.
  ///
  /// A mention may carry a suffix — `com.example.app.dev`,
  /// `com.example.app.RunnerTests` become `<new>.dev`, `<new>.RunnerTests` —
  /// but not a longer segment: `com.example.app2` is another id. [orgs] are
  /// replaced only where they stand alone, with no segment after them (the
  /// full stop in `© 2026 com.example. All rights reserved.` is not one). In a
  /// Kotlin file ([kotlin]), the id in a `package` or `import` line is written
  /// with its reserved segments backquoted.
  static String rename(
    String content,
    Map<String, String> ids, {
    Map<String, String> orgs = const {},
    bool kotlin = false,
  }) {
    if (ids.isEmpty && orgs.isEmpty) return content;
    String alternation(Iterable<String> keys) =>
        (keys.toList()..sort((a, b) => b.length.compareTo(a.length)))
            .map(RegExp.escape)
            .join('|');

    final pattern = RegExp(
      [
        if (ids.isNotEmpty) '(?<id>${alternation(ids.keys)})(?![\\w-])',
        if (orgs.isNotEmpty)
          '(?<org>${alternation(orgs.keys)})(?![\\w-]|\\.[\\w-])',
      ].map((branch) => '(?<![\\w-])$branch').join('|'),
    );
    final declaration = RegExp(r'^\s*(?:package|import)\s+$');

    return content.replaceAllMapped(pattern, (match) {
      final m = match as RegExpMatch;
      final id = ids.isEmpty ? null : m.namedGroup('id');
      if (id == null) return orgs[m.namedGroup('org')]!;
      final renamed = ids[id]!;
      if (!kotlin) return renamed;
      final lineStart = m.start == 0
          ? 0
          : content.lastIndexOf('\n', m.start - 1) + 1;
      return declaration.hasMatch(content.substring(lineStart, m.start))
          ? kotlinPackage(renamed)
          : renamed;
    });
  }

  /// Works out what giving the project at [root] the ids [androidId] and
  /// [appleId] changes, without writing anything.
  static AppIdPlan plan(
    String root, {
    required String androidId,
    required String appleId,
  }) {
    root = p.normalize(p.absolute(root));
    final declared = detect(root);
    final android = {
      for (final old in declared.android)
        if (old != androidId) old: androidId,
    };
    final apple = {
      for (final old in declared.apple)
        if (old != appleId) old: appleId,
    };
    // A Kotlin source that already backquotes a reserved segment says
    // `in`.acme.app, which the plain id would not match.
    final kotlinSpellings = {
      for (final MapEntry(:key, :value) in android.entries)
        if (kotlinPackage(key) != key) kotlinPackage(key): value,
    };
    final orgs = <String, String>{};
    final oldOrg = _org(declared.applicationId);
    final newOrg = _org(androidId);
    if (oldOrg != null && newOrg != null && oldOrg != newOrg) {
      orgs[oldOrg] = newOrg;
    }

    final edits = <String, String>{};
    final firebaseConfigs = <String>[];
    if (android.isNotEmpty || apple.isNotEmpty) {
      for (final file in _textFiles(root)) {
        final relative = ProjectManifest.relativeKey(root, file.path);
        final String source;
        try {
          source = file.readAsStringSync();
        } on FileSystemException {
          continue; // not UTF-8: not a file an id is written in
        }
        // The same old id can be both — `com.example.shop` on every platform
        // — while the new ones differ (`my_shop` / `myShop`): the folder
        // decides which it is.
        final isApple =
            relative.startsWith('ios/') || relative.startsWith('macos/');
        final kotlin = relative.endsWith('.kt');
        final ids = isApple
            ? {...android, if (kotlin) ...kotlinSpellings, ...apple}
            : {...apple, ...android, if (kotlin) ...kotlinSpellings};
        final renamed = rename(
          source,
          ids,
          orgs: _orgFiles.contains(relative) ? orgs : const {},
          kotlin: kotlin,
        );
        if (renamed == source) continue;
        if (_firebaseConfigs.contains(p.basename(file.path))) {
          firebaseConfigs.add(relative);
        } else {
          edits[file.path] = renamed;
        }
      }
    }

    final moves = <AppIdMove>[];
    final sourceRoots = <String, String>{};
    final conflicts = <String>[];
    final oldPackage = declared.kotlinPackage;
    if (oldPackage != null && oldPackage != androidId) {
      final srcDir = Directory(p.join(root, 'android', 'app', 'src'));
      final sourceSets = srcDir.existsSync()
          ? srcDir.listSync(followLinks: false).whereType<Directory>()
          : const <Directory>[];
      for (final sourceSet in sourceSets) {
        for (final base in ['kotlin', 'java']) {
          final baseDir = p.join(sourceSet.path, base);
          final from = p.joinAll([baseDir, ...oldPackage.split('.')]);
          final to = p.joinAll([baseDir, ...androidId.split('.')]);
          if (!Directory(from).existsSync()) continue;
          sourceRoots[from] = baseDir;
          final files = Directory(from)
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .map((f) => f.path)
              .toList();
          for (final file in files) {
            final target = p.join(to, p.relative(file, from: from));
            // On a case-insensitive disk `myapp` → `myApp` finds the file
            // itself at the target, which is not a clash.
            final clash =
                File(target).existsSync() &&
                !files.contains(target) &&
                target.toLowerCase() != file.toLowerCase();
            if (clash) {
              conflicts.add(ProjectManifest.relativeKey(root, target));
            }
            moves.add(AppIdMove(file, target));
          }
        }
      }
    }

    return AppIdPlan(
      declared: declared,
      android: android,
      apple: apple,
      edits: edits,
      moves: moves,
      sourceRoots: sourceRoots,
      firebaseConfigs: firebaseConfigs,
      conflicts: conflicts,
    );
  }

  /// Applies [plan] to the project at [root]: rewrites, then moves the
  /// sources, then prunes the emptied package folders. A failure part-way
  /// puts every file back as it was.
  ///
  /// A file `.moarch.yaml` vouched for as untouched is re-recorded with its
  /// new content (and path), so `moarch update` still sees it as moarch's own
  /// rather than as an edit.
  static Future<void> apply(String root, AppIdPlan plan) async {
    root = p.normalize(p.absolute(root));
    if (plan.conflicts.isNotEmpty) {
      throw StateError('Not applied: ${plan.conflicts.join(', ')} exist.');
    }
    // Path → its bytes before the run, or null when it did not exist.
    final before = <String, List<int>?>{};
    final moved = {for (final move in plan.moves) move.from: move.to};
    try {
      for (final MapEntry(key: path, value: content) in plan.edits.entries) {
        if (moved.containsKey(path)) continue;
        final file = File(path);
        before.putIfAbsent(path, file.readAsBytesSync);
        file.writeAsStringSync(content);
      }
      for (final move in plan.moves) {
        final from = File(move.from);
        final bytes = from.readAsBytesSync();
        before.putIfAbsent(move.from, () => bytes);
        before.putIfAbsent(move.to, () => null);
        final edited = plan.edits[move.from];
        Directory(p.dirname(move.to)).createSync(recursive: true);
        // Delete first: on a case-insensitive disk the target can be the
        // same file under another spelling.
        from.deleteSync();
        File(
          move.to,
        ).writeAsBytesSync(edited == null ? bytes : utf8.encode(edited));
      }
    } catch (_) {
      for (final MapEntry(key: path, value: bytes) in before.entries) {
        try {
          final file = File(path);
          if (bytes == null) {
            if (file.existsSync()) file.deleteSync();
          } else {
            file
              ..parent.createSync(recursive: true)
              ..writeAsBytesSync(bytes);
          }
        } catch (_) {
          // Best-effort: what cannot be restored is left for git to show.
        }
      }
      rethrow;
    }

    for (final MapEntry(key: dir, value: base) in plan.sourceRoots.entries) {
      _prune(Directory(dir), stopAt: base);
    }

    final manifest = ProjectManifest.load(root);
    if (manifest == null) return;
    var changed = false;
    for (final path in {...plan.edits.keys, ...moved.keys}) {
      final recorded = manifest.recordedHash(root, path);
      final original = before[path];
      if (recorded == null || original == null) continue;
      final String originalText;
      try {
        originalText = utf8.decode(original);
      } on FormatException {
        continue;
      }
      if (recorded != ProjectManifest.hashContent(originalText)) continue;
      final target = moved[path] ?? path;
      if (target != path) manifest.forget(root, path);
      manifest.record(root, target, plan.edits[path] ?? originalText);
      changed = true;
    }
    if (changed) await manifest.save(root);
  }

  /// `com.acme` for `com.acme.shop`; null for an id with nothing to drop.
  static String? _org(String? id) {
    if (id == null) return null;
    final at = id.lastIndexOf('.');
    return at <= 0 ? null : id.substring(0, at);
  }

  /// Every text file in the project an id could be written in, skipping
  /// build output, caches, links and the manifest (which `apply` keeps).
  static Iterable<File> _textFiles(String root) sync* {
    final pending = [Directory(root)];
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      for (final entity in dir.listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (entity is Directory) {
          if (!_skippedDirs.contains(name)) pending.add(entity);
        } else if (entity is File &&
            name != ProjectManifest.fileName &&
            (_textExtensions.contains(p.extension(name)) ||
                _textNames.contains(name))) {
          yield entity;
        }
      }
    }
  }

  /// Deletes [dir] and its subfolders when they hold no files, then each
  /// parent that is left empty, up to (not including) [stopAt].
  static void _prune(Directory dir, {required String stopAt}) {
    bool removeIfEmpty(Directory d) {
      if (!d.existsSync()) return true;
      var empty = true;
      for (final entity in d.listSync(followLinks: false)) {
        if (entity is Directory && removeIfEmpty(entity)) continue;
        empty = false;
      }
      if (empty) d.deleteSync();
      return empty;
    }

    if (!removeIfEmpty(dir)) return;
    var parent = dir.parent;
    while (p.isWithin(stopAt, parent.path) &&
        parent.existsSync() &&
        parent.listSync().isEmpty) {
      parent.deleteSync();
      parent = parent.parent;
    }
  }
}
