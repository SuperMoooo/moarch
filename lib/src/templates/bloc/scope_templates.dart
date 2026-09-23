/// One bloc a scope carries: its class, the field it is held in, and the
/// import that brings the class in.
class ScopeBloc {
  /// Creates a scope member.
  const ScopeBloc({
    required this.className,
    required this.field,
    required this.import,
  });

  /// The bloc or cubit class, e.g. `MatterInformationBloc`.
  final String className;

  /// The field it is held in, e.g. `matterInformation`.
  final String field;

  /// The import path, relative to the scope file.
  final String import;
}

/// The scope a scope nests inside — `LawfirmScope` for a `MatterScope` — whose
/// blocs travel along with its own.
class ScopeParent {
  /// Creates a parent reference.
  const ScopeParent({
    required this.className,
    required this.field,
    required this.import,
  });

  /// The parent scope class, e.g. `LawfirmScope`.
  final String className;

  /// The field it is held in, e.g. `lawfirm`.
  final String field;

  /// The import path, relative to the scope file.
  final String import;
}

/// Generates a bloc scope: the blocs a screen provides, carried to what it
/// opens on top of it and provided there again.
///
/// Bloc only. A Riverpod provider lives above the Navigator, so a pushed
/// route or a sheet already reads the same notifier — there is nothing to
/// carry.
abstract final class ScopeTemplates {
  /// Returns `presentation/scopes/<name>_scope.dart`.
  ///
  /// [name] is the scope's PascalCase stem (`Matter` → `MatterScope`), and
  /// [blocs] what it carries. [parent], when given, is carried too and
  /// provided around this scope's own blocs.
  static String scope({
    required String name,
    required List<ScopeBloc> blocs,
    ScopeParent? parent,
  }) {
    final cls = '${name}Scope';
    final imports = <String>{
      if (parent != null) parent.import,
      for (final bloc in blocs) bloc.import,
    }.toList()..sort();

    final ctorParams = [
      if (parent != null) 'required this.${parent.field}',
      for (final bloc in blocs) 'required this.${bloc.field}',
    ].map((param) => '    $param,').join('\n');

    final ofArgs = [
      if (parent != null) '${parent.field}: ${parent.className}.of(context)',
      for (final bloc in blocs)
        '${bloc.field}: context.read<${bloc.className}>()',
    ].map((arg) => '        $arg,').join('\n');

    final fields = [
      if (parent != null) ...[
        '  /// The blocs of the screen this one was opened from.',
        '  final ${parent.className} ${parent.field};',
        '',
      ],
      for (final bloc in blocs) '  final ${bloc.className} ${bloc.field};',
    ].join('\n');

    final ownProviders = blocs.length == 1
        ? 'BlocProvider.value(value: ${blocs.single.field}, child: child)'
        : 'MultiBlocProvider(\n'
              '      providers: [\n'
              '${blocs.map((b) => '        BlocProvider.value(value: ${b.field}),').join('\n')}\n'
              '      ],\n'
              '      child: child,\n'
              '    )';
    final provideBody = parent == null
        ? '    return $ownProviders;'
        : '    return ${parent.field}.provide(\n'
              '      child: ${ownProviders.replaceAll('\n', '\n  ')},\n'
              '    );';

    final parentDoc = parent == null
        ? ''
        : '\n///\n/// Nested in [${parent.className}]: that screen\'s blocs travel '
              'with these\n/// and are provided around them, so what opens from '
              'here reads both.';

    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

${imports.map((i) => "import '$i';").join('\n')}

/// The blocs the $name screen shares with what it opens on top of it — a
/// pushed route, a bottom sheet, a dialog.
///
/// Those are siblings of the screen in the Navigator, not children, so they
/// cannot `context.read` what it provides. Take the scope where the blocs are
/// ([$cls.of]) and provide the same instances again where they are needed
/// ([provide]): one state shared by every screen, and still closed by the
/// screen that created it — which always goes after the ones on top of it.$parentDoc
///
/// ```dart
/// // A sheet or a dialog — the extension below does the carrying:
/// context.show${name}Sheet((_) => const EditNoteSheet());
///
/// // A pushed route — hand it over, and provide it in the route's builder:
/// context.push(AppRoutes.x, extra: $cls.of(context));
/// GoRoute(
///   path: AppRoutes.x,
///   builder: (context, state) =>
///       (state.extra! as $cls).provide(child: const XPage()),
/// )
/// ```
///
/// For routes nested under the $name screen, prefer a GoRouter `ShellRoute`
/// whose builder provides these blocs above every child route: `extra` is not
/// part of the URL, so a deep link, a notification tap or a web refresh opens
/// the route with no scope at all. Keep the scope for sheets, dialogs and the
/// routes a shell cannot reach.
class $cls {
  const $cls({
$ctorParams
  });

  /// The blocs provided above [context] — call it from the $name screen, or
  /// from anything already inside its scope.
  factory $cls.of(BuildContext context) => $cls(
$ofArgs
      );

$fields

  /// Provides the same instances to [child].
  Widget provide({required Widget child}) {
$provideBody
  }
}

/// Sheets and dialogs that can read the $name screen's blocs.
extension ${cls}X on BuildContext {
  /// [showModalBottomSheet], with [$cls] provided to what [builder] builds.
  Future<T?> show${name}Sheet<T>(
    WidgetBuilder builder, {
    bool isScrollControlled = true,
  }) {
    final scope = $cls.of(this);
    return showModalBottomSheet<T>(
      context: this,
      isScrollControlled: isScrollControlled,
      builder: (_) => scope.provide(child: Builder(builder: builder)),
    );
  }

  /// [showDialog], with [$cls] provided to what [builder] builds.
  Future<T?> show${name}Dialog<T>(WidgetBuilder builder) {
    final scope = $cls.of(this);
    return showDialog<T>(
      context: this,
      builder: (_) => scope.provide(child: Builder(builder: builder)),
    );
  }
}
''';
  }

  /// A `ShellRoute` for routes nested under a screen — what the command
  /// prints rather than writes, since the router is the app's own file.
  static String shellRouteSnippet({
    required String name,
    required List<ScopeBloc> blocs,
  }) {
    final providers = blocs
        .map(
          (b) =>
              '        BlocProvider(create: (_) => getIt<${b.className}>()),',
        )
        .join('\n');
    return '''
ShellRoute(
  // Provided above every route below, so each reads the same blocs with
  // context.read — and a deep link straight to a child route still has them.
  builder: (context, state, child) => MultiBlocProvider(
    providers: [
$providers
    ],
    child: child,
  ),
  routes: [
    GoRoute(path: '/${_kebab(name)}/:id', builder: ...),        // the $name screen
    GoRoute(path: '/${_kebab(name)}/:id/edit', builder: ...),   // opened from it
  ],
),''';
  }

  static String _kebab(String pascal) => pascal
      .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}-${m[2]}')
      .toLowerCase();
}
