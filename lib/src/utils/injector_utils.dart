import 'dart:io';

import 'package:path/path.dart' as p;

/// Adds a generated feature's `get_it` registrations to
/// `lib/config/di/injector.dart`.
///
/// Both stacks: the data layer is wired in one central file, so
/// `moarch create feature` patches it the same way `init` patches gradle,
/// plist and the manifest. The state holder is the only difference — a bloc is
/// registered here, a Riverpod notifier stays behind its provider.
abstract final class InjectorUtils {
  /// The line new registrations are inserted above.
  ///
  /// Load-bearing, and said so in the generated file: without it there is
  /// nowhere unambiguous to write, and the alternative — parsing the
  /// cascade — breaks the moment someone reformats it.
  static const String anchor = '// moarch:registrations';

  /// Project-relative path of the locator.
  static const String path = 'lib/config/di/injector.dart';

  /// The absolute path of the locator for the project owning [libPath].
  static String fileFor(String libPath) =>
      p.join(libPath, 'config', 'di', 'injector.dart');

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
  static String registrationsFor({
    required String featureName,
    required String className,
    required bool hasRemote,
    required bool hasLocal,
    required bool hasRepository,
    required bool hasBloc,
    required bool useFirestore,
    String? blocRepositoryClass,
  }) {
    final blocRepo = blocRepositoryClass ?? (hasRepository ? className : null);

    final lines = <String>[
      '  // ── $className ${'─' * (56 - className.length).clamp(3, 56)}',
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
      if (hasBloc)
        '''  // A factory, not a singleton: the screen's BlocProvider creates it and
  // closing the route closes it.
${blocRepo == null ? '  getIt.registerFactory<${className}Bloc>(${className}Bloc.new);' : '''  getIt.registerFactory<${className}Bloc>(
    () => ${className}Bloc(getIt<${blocRepo}Repository>()),
  );'''}''',
    ];

    return lines.join('\n');
  }

  /// The import lines a feature's registrations need.
  static List<String> importsFor({
    required String featureName,
    required bool hasRemote,
    required bool hasLocal,
    required bool hasRepository,
    required bool hasBloc,
    required bool useFirestore,
  }) {
    return <String>[
      if (hasRemote && useFirestore)
        "import 'package:cloud_firestore/cloud_firestore.dart';",
      if (hasRemote && !useFirestore) "import 'package:dio/dio.dart';",
      if (hasRemote)
        "import '../../features/$featureName/data/datasources/${featureName}_remote_datasource.dart';",
      if (hasLocal)
        "import '../../features/$featureName/data/datasources/${featureName}_local_datasource.dart';",
      if (hasRepository)
        "import '../../features/$featureName/data/repositories/${featureName}_repository_impl.dart';",
      if (hasRepository)
        "import '../../features/$featureName/domain/repositories/${featureName}_repository.dart';",
      if (hasBloc)
        "import '../../features/$featureName/presentation/blocs/${featureName}_bloc.dart';",
    ];
  }

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

  /// Patches the locator for the project owning [libPath], returning whether
  /// anything was written.
  ///
  /// Silently does nothing when the project has no locator (a Riverpod
  /// project, or a bloc project scaffolded before this existed) — the caller
  /// reports that, since only it knows whether it matters.
  static Future<bool> register(
    String libPath, {
    required String registrations,
    required List<String> imports,
    required String className,
  }) async {
    final file = File(fileFor(libPath));
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
