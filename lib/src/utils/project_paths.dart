import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves a `--path` value to the `lib/` directory the `create` commands
/// generate into.
///
/// `moarch init --path` takes a project root; every `moarch create` subcommand
/// takes a `lib/`. Nothing in the flag says which, so pointing `create` at a
/// project root is an easy mistake to make — and one that used to generate a
/// feature into `<root>/features/` instead of `<root>/lib/features/`.
///
/// A [path] that looks like a project root — it has a `pubspec.yaml` and a
/// `lib/` beside it — resolves to that `lib/`. Anything else is returned as
/// given, so `-p lib` and `-p packages/app/lib` keep working exactly as before.
String resolveLibPath(String path) {
  final root = p.absolute(path);
  final looksLikeProjectRoot =
      File(p.join(root, 'pubspec.yaml')).existsSync() &&
          Directory(p.join(root, 'lib')).existsSync();
  return looksLikeProjectRoot ? p.join(path, 'lib') : path;
}
