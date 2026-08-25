import 'dart:io';

import 'package:path/path.dart' as p;

/// A generated feature's registrations, split by the module file each part
/// belongs in.
///
/// The data layer and the state holders live in different files under
/// `lib/config/di/` — see [InjectorUtils.register], which also knows how to
/// fold them back together for a project still on the pre-split single
/// `injector.dart`.
class InjectorRegistrations {
  /// Creates a split registration block.
  const InjectorRegistrations({
    required this.heading,
    this.data = '',
    this.dataImports = const [],
    this.holders = '',
    this.holderImports = const [],
  });

  /// The `// ── Orders ───────` comment naming what these registrations are
  /// for.
  ///
  /// Held apart from the two halves because how many of it a file wants
  /// depends on how many halves land in it: one per block on the split
  /// layout, one for both blocks on the pre-split one. It is also what
  /// [InjectorUtils.insert] reads as "already registered", so it has to be
  /// present exactly once wherever a block is written.
  final String heading;

  /// Datasource and repository registrations, for `data_module.dart`. Empty
  /// when the feature was scaffolded without a data layer.
  final String data;

  /// The imports [data] needs.
  final List<String> dataImports;

  /// Bloc registrations, for `presentation_module.dart`. Always empty on
  /// Riverpod, where the state holder is a notifier behind its provider.
  final String holders;

  /// The imports [holders] needs.
  final List<String> holderImports;

  /// [data] under its heading, ready to insert into `data_module.dart`.
  String get dataBlock => data.isEmpty ? '' : '$heading\n$data';

  /// [holders] under its heading, ready to insert into
  /// `presentation_module.dart`.
  String get holderBlock => holders.isEmpty ? '' : '$heading\n$holders';

  /// Both halves as one block under one heading, for the pre-split
  /// single-file locator.
  String get combined {
    final body = [data, holders].where((s) => s.isNotEmpty).join('\n');
    return body.isEmpty ? '' : '$heading\n$body';
  }

  /// Every import either half needs, for the pre-split single-file locator.
  List<String> get combinedImports =>
      {...dataImports, ...holderImports}.toList();

  /// Whether there is nothing to register at all.
  bool get isEmpty => data.isEmpty && holders.isEmpty;
}

/// What [InjectorUtils.register] did.
class InjectorPatchResult {
  /// Creates a result.
  const InjectorPatchResult({required this.written, required this.targets});

  /// Nothing was expected of the locator, so nothing was asked of it.
  static const InjectorPatchResult none =
      InjectorPatchResult(written: [], targets: []);

  /// Project-relative paths that were patched.
  final List<String> written;

  /// Project-relative paths that should have been patched.
  ///
  /// The two differ when a file is missing, when its anchor was removed, or
  /// when the feature was already registered — all cases the caller reports,
  /// since only it knows whether that matters.
  final List<String> targets;

  /// Whether every file that should have been patched was.
  bool get complete => targets.isNotEmpty && written.length == targets.length;

  /// The files that should have been patched and were not.
  ///
  /// A feature can land half-registered — the bloc written, the data layer
  /// refused because its module lost the anchor — and the caller has to be
  /// able to name the half that is missing rather than all of it.
  List<String> get missing =>
      targets.where((path) => !written.contains(path)).toList();

  /// The targets as one human-facing string, e.g. for a log line.
  String get describeTargets =>
      targets.isEmpty ? InjectorUtils.path : targets.join(' and ');

  /// The files actually patched as one human-facing string.
  String get describeWritten =>
      written.isEmpty ? InjectorUtils.path : written.join(' and ');

  /// The files that were meant to be patched and were not, as one string.
  String get describeMissing =>
      missing.isEmpty ? describeTargets : missing.join(' and ');
}

/// Adds a generated feature's `get_it` registrations to the service locator
/// under `lib/config/di/`.
///
/// Both stacks: the data layer is wired in one central place, so
/// `moarch create feature` patches it the same way `init` patches gradle,
/// plist and the manifest. The state holder is the only difference — a bloc
/// goes in `presentation_module.dart`, a Riverpod notifier stays behind its
/// provider and is not registered anywhere.
///
/// Two layouts are supported, and which one a project has is read off disk
/// rather than remembered: the current one splits the registrations one file
/// per layer, and projects scaffolded before that split have everything in a
/// single `injector.dart`. Both carry the same [anchor].
abstract final class InjectorUtils {
  /// The line new registrations are inserted above.
  ///
  /// Load-bearing, and said so in the generated file: without it there is
  /// nowhere unambiguous to write, and the alternative — parsing the
  /// cascade — breaks the moment someone reformats it.
  ///
  /// The same comment marks the spot in every module file; which file a
  /// registration belongs in is decided by the layer it is, not by the
  /// anchor.
  static const String anchor = '// moarch:registrations';

  /// Project-relative path of the locator's root, and of the whole locator in
  /// a project on the pre-split layout.
  static const String path = 'lib/config/di/injector.dart';

  /// Project-relative path of the data layer's registrations.
  static const String dataPath = 'lib/config/di/data_module.dart';

  /// Project-relative path of the state holders' registrations.
  static const String presentationPath =
      'lib/config/di/presentation_module.dart';

  /// The absolute path of the locator root for the project owning [libPath].
  static String fileFor(String libPath) =>
      p.join(libPath, 'config', 'di', 'injector.dart');

  /// The absolute path of the data module for the project owning [libPath].
  static String dataFileFor(String libPath) =>
      p.join(libPath, 'config', 'di', 'data_module.dart');

  /// The absolute path of the presentation module for the project owning
  /// [libPath].
  static String presentationFileFor(String libPath) =>
      p.join(libPath, 'config', 'di', 'presentation_module.dart');

  /// Whether the project owning [libPath] has the registrations split one
  /// file per layer.
  ///
  /// Detected, not remembered: the project outlives the run that made it, and
  /// a project generated before the split keeps the single file until someone
  /// migrates it by hand.
  static bool isSplit(String libPath) =>
      File(dataFileFor(libPath)).existsSync();

  /// The registration block for a feature, ready to insert.
  ///
  /// A bloc is a **factory**, not a singleton: each screen gets its own and
  /// closing the route closes it. The datasources and repository are lazy
  /// singletons — one connection's worth of state, shared.
  ///
  /// [blocRepositoryClass] names the repository the bloc is constructed with,
  /// for the case where that is not the feature's own — `moarch create bloc`
  /// adds a second bloc to an existing feature and hands it that feature's.
  /// Left null it follows [hasRepository]: the feature's repository, or a
  /// bloc that takes nothing because no data layer was generated.
  ///
  /// [blocFileName] is the bloc's own file stem, for the same case: a second
  /// bloc in a feature is `<blocFileName>_bloc.dart` under the feature the
  /// registrations are otherwise named for. Left null it is [featureName].
  static InjectorRegistrations registrationsFor({
    required String featureName,
    required String className,
    required bool hasRemote,
    required bool hasLocal,
    required bool hasRepository,
    required bool hasBloc,
    required bool useFirestore,
    String? blocRepositoryClass,
    String? blocFileName,
  }) {
    final blocRepo = blocRepositoryClass ?? (hasRepository ? className : null);

    final data = <String>[
      if (hasRemote)
        '''  getIt.registerLazySingleton<${className}RemoteDataSource>(
    () => ${className}RemoteDataSource(getIt<${useFirestore ? 'FirebaseFirestore' : 'Dio'}>()),
  );''',
      if (hasLocal)
        '''  getIt.registerLazySingleton<${className}LocalDataSource>(
    ${className}LocalDataSource.new,
  );''',
      if (hasRepository)
        '''  getIt.registerLazySingleton<${className}Repository>(
    () => ${className}RepositoryImpl(
${[
          if (hasRemote) '      getIt<${className}RemoteDataSource>(),',
          if (hasLocal) '      getIt<${className}LocalDataSource>(),',
        ].join('\n')}
    ),
  );''',
    ];

    final holders = <String>[
      if (hasBloc)
        '''  // A factory, not a singleton: the screen's BlocProvider creates it and
  // closing the route closes it.
${blocRepo == null ? '  getIt.registerFactory<${className}Bloc>(${className}Bloc.new);' : '''  getIt.registerFactory<${className}Bloc>(
    () => ${className}Bloc(getIt<${blocRepo}Repository>()),
  );'''}''',
    ];

    return InjectorRegistrations(
      heading: _heading(className),
      data: data.join('\n'),
      dataImports: _dataImportsFor(
        featureName: featureName,
        hasRemote: hasRemote,
        hasLocal: hasLocal,
        hasRepository: hasRepository,
        useFirestore: useFirestore,
      ),
      holders: holders.join('\n'),
      holderImports: hasBloc
          ? _holderImportsFor(
              featureName: featureName,
              // Whichever repository the bloc takes, it is this feature's —
              // `create bloc` hands a second bloc the one already there.
              withRepository: blocRepo != null,
              blocFileName: blocFileName ?? featureName,
            )
          : const [],
    );
  }

  /// The heading comment that both carries the class name and is the cheapest
  /// honest test for "already registered".
  static String _heading(String className) =>
      '  // ── $className ${'─' * (56 - className.length).clamp(3, 56)}';

  static List<String> _dataImportsFor({
    required String featureName,
    required bool hasRemote,
    required bool hasLocal,
    required bool hasRepository,
    required bool useFirestore,
  }) =>
      <String>[
        if (hasRemote && useFirestore)
          "import 'package:cloud_firestore/cloud_firestore.dart';",
        if (hasRemote && !useFirestore) "import 'package:dio/dio.dart';",
        if (hasRemote)
          "import '../../features/$featureName/data/datasources/${featureName}_remote_datasource.dart';",
        if (hasLocal)
          "import '../../features/$featureName/data/datasources/${featureName}_local_datasource.dart';",
        if (hasRepository) ...[
          "import '../../features/$featureName/data/repositories/${featureName}_repository_impl.dart';",
          "import '../../features/$featureName/domain/repositories/${featureName}_repository.dart';",
        ],
      ];

  static List<String> _holderImportsFor({
    required String featureName,
    required bool withRepository,
    required String blocFileName,
  }) =>
      <String>[
        if (withRepository)
          "import '../../features/$featureName/domain/repositories/${featureName}_repository.dart';",
        "import '../../features/$featureName/presentation/blocs/${blocFileName}_bloc.dart';",
      ];

  /// Inserts [registrations] above the anchor in [source], with [imports]
  /// added after the last existing import.
  ///
  /// Returns [source] unchanged when the anchor is missing, or when the
  /// registrations are already there — re-running `create feature` on a
  /// feature that exists must not register it twice.
  static String insert(
    String source, {
    required String registrations,
    required List<String> imports,
    required String className,
  }) {
    if (!source.contains(anchor)) return source;
    // The heading comment carries the class name, so this is the cheapest
    // honest test for "already registered".
    if (source.contains('// ── $className ')) return source;

    var patched = _withImports(source, imports);

    final anchorIndex = patched.indexOf(anchor);
    // Back up to the start of the anchor's line so the insert lands above its
    // indentation rather than in the middle of it.
    final lineStart = patched.lastIndexOf('\n', anchorIndex) + 1;

    return '${patched.substring(0, lineStart)}$registrations\n\n'
        '${patched.substring(lineStart)}';
  }

  /// Adds any of [imports] the file does not already have, after the last
  /// existing import line.
  static String _withImports(String source, List<String> imports) {
    final missing = imports.where((line) => !source.contains(line)).toList()
      ..sort();
    if (missing.isEmpty) return source;

    final importPattern = RegExp(r"^import\s+'[^']+';$", multiLine: true);
    final matches = importPattern.allMatches(source).toList();
    if (matches.isEmpty) return '${missing.join('\n')}\n$source';

    final last = matches.last.end;
    return '${source.substring(0, last)}\n${missing.join('\n')}'
        '${source.substring(last)}';
  }

  /// Patches the locator for the project owning [libPath], reporting which
  /// files it wrote and which it meant to.
  ///
  /// On the split layout the data layer and the state holder go into their
  /// own module files; on the pre-split layout both go into `injector.dart`.
  /// Either way a file that is not there, or has lost its anchor, is left
  /// alone and reported — the caller decides whether that is worth saying,
  /// since only it knows what was asked for.
  static Future<InjectorPatchResult> register(
    String libPath, {
    required InjectorRegistrations registrations,
    required String className,
  }) async {
    if (registrations.isEmpty) return InjectorPatchResult.none;

    if (!isSplit(libPath)) {
      final wrote = await _patch(
        fileFor(libPath),
        registrations: registrations.combined,
        imports: registrations.combinedImports,
        className: className,
      );
      return InjectorPatchResult(
        written: wrote ? const [path] : const [],
        targets: const [path],
      );
    }

    final targets = <String>[];
    final written = <String>[];

    if (registrations.data.isNotEmpty) {
      targets.add(dataPath);
      final wrote = await _patch(
        dataFileFor(libPath),
        registrations: registrations.dataBlock,
        imports: registrations.dataImports,
        className: className,
      );
      if (wrote) written.add(dataPath);
    }
    if (registrations.holders.isNotEmpty) {
      targets.add(presentationPath);
      final wrote = await _patch(
        presentationFileFor(libPath),
        registrations: registrations.holderBlock,
        imports: registrations.holderImports,
        className: className,
      );
      if (wrote) written.add(presentationPath);
    }

    return InjectorPatchResult(written: written, targets: targets);
  }

  /// Patches one module file, returning whether anything was written.
  static Future<bool> _patch(
    String filePath, {
    required String registrations,
    required List<String> imports,
    required String className,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final source = await file.readAsString();
    final patched = insert(
      source,
      registrations: registrations,
      imports: imports,
      className: className,
    );
    if (patched == source) return false;

    await file.writeAsString(patched);
    return true;
  }
}
