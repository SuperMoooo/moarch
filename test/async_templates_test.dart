import 'package:moarch/src/templates/ui/async_templates.dart';
import 'package:moarch/src/templates/ui/feature_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('appAsyncView', () {
    final output = AsyncTemplates.appAsyncView();

    test('draws the four states one AsyncValue can be in', () {
      expect(output, contains('return ErrorView('));
      expect(output, contains('return EmptyView('));
      expect(output, contains('Skeletonizer(child: shape(context))'));
      expect(output, contains('CircularProgressIndicator.adaptive()'));
      expect(output, contains('return builder(context, data);'));
    });

    test('a refresh keeps the data that is already on screen', () {
      // `hasValue` is the whole mechanism: a reload over existing data must not
      // replace a list the user is reading with a spinner.
      expect(output, contains('if (!value.hasValue) {'));
      expect(output, contains('if (error != null && !value.isLoading) {'));
    });

    test('a spinner is the fallback, not the default', () {
      expect(output, contains('final shape = skeleton;'));
      expect(output, contains('if (shape == null) {'));
    });

    test('the placeholder is built only when there is nothing to draw', () {
      // A widget would be built on every rebuild, including the ones where the
      // data is already on screen and the skeleton is thrown away.
      expect(output, contains('final WidgetBuilder? skeleton;'));
    });

    test('empty is the caller\'s question, and unasked by default', () {
      expect(output, contains('final bool Function(T data)? isEmpty;'));
      expect(output, contains('if (isEmpty?.call(data) ?? false) {'));
    });

    test('shows the failure\'s own message, and nothing it cannot vouch for',
        () {
      expect(output, contains('AppException(:final message) => message,'));
      expect(output, contains('_ => null,'));
      expect(
        output,
        contains("import '../../core/errors/app_exception.dart';"),
      );
    });

    test('renders inline, so a Scaffold keeps its app bar while loading', () {
      // The doc comment shows one around the widget, which is the opposite of
      // building one — so the check is on the code.
      final code = output
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('///'))
          .join('\n');
      expect(code, isNot(contains('Scaffold(')));
    });

    test('a nullable T can still hold null as its value', () {
      expect(output, contains('final data = value.value as T;'));
    });

    test('takes a raw Stream or Future, not only a provider\'s AsyncValue', () {
      expect(output, contains('const AppAsyncView.stream({'));
      expect(output, contains('required Stream<T> stream,'));
      expect(output, contains('const AppAsyncView.future({'));
      expect(output, contains('required Future<T> future,'));
    });

    test('all three sources land in the same four-state mapping', () {
      // The constructors differ in where the value comes from and in nothing
      // else: the copy, the skeleton and the empty test are declared once.
      expect(
        output,
        contains('Widget _render(BuildContext context, AsyncValue<T> value) {'),
      );
      expect(
        output,
        contains('if (value != null) return _render(context, value);'),
      );
      expect(output, contains('builder: _render,'));
    });

    test('a raw source keeps what it has already emitted', () {
      // `copyWithPrevious` is what makes an error mid-stream, or a stream
      // swapped for another, leave the loaded data on screen.
      expect(
        output,
        contains('_value = AsyncValue<T>.loading().copyWithPrevious(_value);'),
      );
      expect(
        output,
        contains('setState(() => _value = next.copyWithPrevious(_value));'),
      );
    });

    test('the subscription lives and dies with the element', () {
      expect(output, contains('_subscription = stream.listen('));
      expect(
        output,
        contains('void didUpdateWidget(covariant _AsyncSource<T> oldWidget) {'),
      );
      expect(output, contains('void dispose() {\n    _unsubscribe();'));
      expect(output, contains('_subscription?.cancel();'));
    });

    test('a late result is not drawn over the source that replaced it', () {
      // A Future keeps running after the widget stopped waiting for it.
      expect(output, contains('if (!mounted) return;'));
      expect(
        output,
        contains('if (from != null && !identical(from, _pending)) return;'),
      );
    });
  });

  group('actionListener', () {
    final output = AsyncTemplates.actionListener();

    test('extends WidgetRef, so it reads like any other ref.listen', () {
      expect(output, contains('extension ActionListener on WidgetRef {'));
      expect(output, contains('void listenAction<S>('));
      expect(output, contains('ProviderListenable<AsyncValue<S>> provider,'));
    });

    test('reports nothing while a load is in flight', () {
      expect(output, contains('if (next.isLoading) return;'));
      expect(output, contains('if (state == null) return;'));
    });

    test('one action reports one outcome', () {
      // Falling through after an error would toast a success left over from the
      // call before it.
      expect(output, contains('if (error != null && error.isNotEmpty) {'));
      expect(output, contains('        return;\n      }'));
    });

    test('a toast needs a mounted context to find its messenger', () {
      expect(output, contains('if (!context.mounted) return;'));
    });

    test(
        'a caller-supplied handler replaces the toast rather than adding to it',
        () {
      expect(output,
          contains('if (onError != null) {\n          onError(error);'));
      expect(output, contains('AppToast.error(context, error);'));
      expect(output, contains('AppToast.success(context, success);'));
    });

    test('an unset extractor means nothing looks for that message', () {
      expect(output, contains('String? Function(S state)? errorOf,'));
      expect(output, contains('String? Function(S state)? successOf,'));
      expect(output, contains('final error = errorOf?.call(state);'));
      expect(output, contains('final success = successOf?.call(state);'));
    });
  });

  group('the generated view', () {
    final output = FeatureTemplates.view(
      'orders',
      'Orders',
      'orders',
      hasNotifier: true,
    );

    test('is built on the two widgets rather than on its own mapping', () {
      expect(output, contains('AppAsyncView<OrdersState>('));
      expect(output, contains('ref.listenAction<OrdersState>('));
      expect(
        output,
        contains("import '../../../../shared/widgets/app_async_view.dart';"),
      );
      expect(
        output,
        contains(
          "import '../../../../shared/widgets/feedback/action_listener.dart';",
        ),
      );
    });

    test('no longer leaves the error and success cases as comments', () {
      expect(output, isNot(contains('SHOW UI ERROR')));
      expect(output, isNot(contains('SHOW UI SUCCESS')));
      expect(output, contains('errorOf: (state) => state.error,'));
      expect(output, contains('successOf: (state) => state.success,'));
    });

    test('traces its skeleton from the body it already builds', () {
      // From fake data, not from an empty state: Skeletonizer shimmers the
      // tree it is handed, and a body drawn from nothing traces to nothing.
      expect(
        output,
        contains('skeleton: (context) => _body(context, OrdersState.placeholder),'),
      );
      expect(output, contains('builder: _body,'));
      expect(
        output,
        contains('Widget _body(BuildContext context, OrdersState state) {'),
      );
    });

    test('offers the retry that ErrorView draws a button for', () {
      expect(
        output,
        contains('onRetry: () => ref.invalidate(ordersNotifierProvider),'),
      );
    });

    test('drops the direct skeletonizer import it used to carry', () {
      // The shimmer is AppAsyncView's business now, and the package belongs to
      // the widget that declares it.
      expect(output, isNot(contains('package:skeletonizer/skeletonizer.dart')));
    });

    test('a view without a notifier stays a plain screen', () {
      final plain = FeatureTemplates.view(
        'orders',
        'Orders',
        'orders',
        hasNotifier: false,
      );
      expect(plain, isNot(contains('AppAsyncView')));
      expect(plain, isNot(contains('listenAction')));
      expect(plain, contains('class OrdersView extends StatelessWidget {'));
    });
  });

  group('the catalog', () {
    test('generates both on init, so a fresh feature view compiles', () {
      // `create feature` writes a view that imports them; init has to have put
      // them there.
      final common = WidgetCatalog.common.map((spec) => spec.name).toSet();
      expect(common, contains('async-view'));
      expect(common, contains('action-listener'));
    });

    test('async-view declares the package it shimmers with', () {
      final spec = WidgetCatalog.byName('async-view')!;
      expect(spec.packages, contains('skeletonizer: '));
      expect(spec.deps, containsAll(['error-view', 'empty-view']));
      expect(spec.file, 'app_async_view.dart');
    });

    test('the listener sits with the toast it reaches for', () {
      final spec = WidgetCatalog.byName('action-listener')!;
      expect(spec.deps, contains('toast'));
      expect(spec.file, 'feedback/action_listener.dart');
    });
  });
}
