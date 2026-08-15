import 'dart:io';

import 'package:path/path.dart' as p;

/// Which state-management stack a project is generated against.
///
/// Every state-bearing template exists in two flavors — one under
/// `lib/src/templates/riverpod/`, one under `lib/src/templates/bloc/` — and
/// this is the switch that picks between them. `moarch init` asks; every
/// other command reads it back off the project with [detect], the only record
/// that stays true once the checklist is forgotten.
///
/// It picks the *state* half only. Dependency injection is get_it in both:
/// see `lib/src/templates/config/injector_templates.dart`.
enum StateManagement {
  /// Riverpod `AsyncNotifier` + the `runAction` mixin — the original moarch
  /// stack.
  riverpod,

  /// flutter_bloc: an event-driven `Bloc` per feature.
  bloc;

  /// Matched as a whole pubspec entry rather than a substring, so `bloc` is
  /// not reported by `bloc_lint` and `flutter_bloc` not by a comment.
  static bool _hasPackage(String pubspec, String package) =>
      RegExp('^\\s+${RegExp.escape(package)}:', multiLine: true)
          .hasMatch(pubspec);

  /// Reads the stack off [pubspec] content: `flutter_bloc` says bloc,
  /// anything else — including no pubspec at all — says riverpod, which is
  /// what every project scaffolded before this option existed uses.
  static StateManagement fromPubspec(String pubspec) =>
      _hasPackage(pubspec, 'flutter_bloc')
          ? StateManagement.bloc
          : StateManagement.riverpod;

  /// Reads the stack off the project owning [libPath] (its parent's
  /// `pubspec.yaml`).
  static StateManagement detect(String libPath) {
    final pubspecFile =
        File(p.join(p.dirname(p.absolute(libPath)), 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return StateManagement.riverpod;
    return fromPubspec(pubspecFile.readAsStringSync());
  }

  /// Whether this is the bloc stack — the flag templates branch on.
  bool get isBloc => this == StateManagement.bloc;
}
