import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/create/create_scope_command.dart';
import 'package:moarch/src/templates/bloc/scope_templates.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ScopeTemplates', () {
    const orders = ScopeBloc(
      className: 'OrdersBloc',
      field: 'orders',
      import: '../blocs/orders_bloc.dart',
    );
    const filters = ScopeBloc(
      className: 'OrderFiltersCubit',
      field: 'orderFilters',
      import: '../blocs/order_filters_cubit.dart',
    );

    test('collects the blocs and provides the same instances', () {
      final source = ScopeTemplates.scope(name: 'Orders', blocs: [orders]);
      expect(source, contains('class OrdersScope {'));
      expect(source, contains('factory OrdersScope.of(BuildContext context)'));
      expect(source, contains('orders: context.read<OrdersBloc>(),'));
      expect(
        source,
        contains('BlocProvider.value(value: orders, child: child)'),
      );
      expect(source, isNot(contains('MultiBlocProvider')));
    });

    test('uses MultiBlocProvider for more than one bloc', () {
      final source = ScopeTemplates.scope(
        name: 'Orders',
        blocs: [orders, filters],
      );
      expect(source, contains('MultiBlocProvider('));
      expect(source, contains('BlocProvider.value(value: orderFilters),'));
    });

    test('nests inside a parent scope', () {
      final source = ScopeTemplates.scope(
        name: 'Orders',
        blocs: [orders],
        parent: const ScopeParent(
          className: 'SessionScope',
          field: 'session',
          import: '../../../auth/presentation/scopes/session_scope.dart',
        ),
      );
      expect(source, contains('session: SessionScope.of(context),'));
      expect(source, contains('return session.provide('));
      expect(
        source,
        contains(
          "import '../../../auth/presentation/scopes/session_scope.dart';",
        ),
      );
    });

    test('carries sheets and dialogs through an extension', () {
      final source = ScopeTemplates.scope(name: 'Orders', blocs: [orders]);
      expect(source, contains('extension OrdersScopeX on BuildContext'));
      expect(source, contains('Future<T?> showOrdersSheet<T>('));
      expect(source, contains('Future<T?> showOrdersDialog<T>('));
      expect(
        source,
        contains('scope.provide(child: Builder(builder: builder))'),
      );
    });

    test('points nested routes at a ShellRoute', () {
      final source = ScopeTemplates.scope(name: 'Orders', blocs: [orders]);
      expect(source, contains('prefer a GoRouter `ShellRoute`'));
      final snippet = ScopeTemplates.shellRouteSnippet(
        name: 'OrderHistory',
        blocs: [orders],
      );
      expect(
        snippet,
        contains('BlocProvider(create: (_) => getIt<OrdersBloc>())'),
      );
      expect(snippet, contains("'/order-history/:id'"));
    });
  });

  group('moarch create scope', () {
    late Directory tempDir;
    late String root;

    void write(String relative, String content) {
      File(p.joinAll([root, ...relative.split('/')]))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    Future<int?> run(List<String> args) {
      final runner = CommandRunner<int>('moarch', 'test')
        ..addCommand(CreateScopeCommand(logger: Logger(level: Level.quiet)));
      return runner.run(['scope', ...args, '--path', root]);
    }

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('moarch_scope');
      root = tempDir.path;
      write(
        'pubspec.yaml',
        'name: shop\ndependencies:\n  flutter_bloc: ^9.0.0\n',
      );
      write(
        'lib/features/orders/presentation/blocs/orders_bloc.dart',
        'class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {}\n',
      );
      write(
        'lib/features/auth/presentation/blocs/auth_bloc.dart',
        'class AuthBloc extends Bloc<AuthEvent, AuthState> {}\n',
      );
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    String scope(String feature, String name) => File(
      p.join(
        root,
        'lib',
        'features',
        feature,
        'presentation',
        'scopes',
        '${name}_scope.dart',
      ),
    ).readAsStringSync();

    test('carries the feature\'s own blocs by default', () async {
      expect(await run(['orders', 'orders']), 0);
      final source = scope('orders', 'orders');
      expect(source, contains('orders: context.read<OrdersBloc>(),'));
      expect(source, isNot(contains('AuthBloc')));
      expect(source, contains("import '../blocs/orders_bloc.dart';"));
    });

    test('takes blocs from other features by name, and a parent', () async {
      expect(await run(['auth', 'SessionScope']), 0);
      expect(
        await run([
          'orders',
          'orders',
          '--blocs',
          'OrdersBloc,AuthBloc',
          '--parent',
          'SessionScope',
        ]),
        0,
      );
      final source = scope('orders', 'orders');
      expect(source, contains('auth: context.read<AuthBloc>(),'));
      expect(source, contains('session: SessionScope.of(context),'));
      expect(
        source,
        contains("import '../../../auth/presentation/blocs/auth_bloc.dart';"),
      );
    });

    test('refuses an unknown bloc or parent, and an existing scope', () async {
      expect(await run(['orders', 'orders', '--blocs', 'NopeBloc']), 1);
      expect(await run(['orders', 'orders', '--parent', 'NopeScope']), 1);
      expect(await run(['orders', 'orders']), 0);
      expect(await run(['orders', 'orders']), 1);
    });

    test('has nothing to do on a Riverpod project', () async {
      write(
        'pubspec.yaml',
        'name: shop\ndependencies:\n  flutter_riverpod: ^3.0.0\n',
      );
      expect(await run(['orders', 'orders']), 1);
    });
  });
}
