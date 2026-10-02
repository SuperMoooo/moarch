import 'package:moarch/src/templates/ui/paged_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('appPagedList', () {
    final output = PagedTemplates.appPagedList();

    test('declares the list, the grid and the sliver', () {
      expect(output, contains('class AppPagedList<T> extends StatelessWidget'));
      expect(output, contains('class AppPagedGrid<T> extends StatelessWidget'));
      expect(
        output,
        contains('class AppPagedSliver<T> extends StatefulWidget'),
      );
      expect(output, contains('const AppPagedSliver.grid({'));
    });

    test('holds no pages: state comes in, a callback goes out', () {
      // mo_infinite_scroll's controller and fetcher are what put a screen's
      // data outside its notifier or bloc.
      expect(output, isNot(contains('ChangeNotifier')));
      expect(output, isNot(contains('fetcher')));
      expect(output, contains('final List<T> items;'));
      expect(output, contains('final VoidCallback onLoadMore;'));
      expect(output, contains('final String? error;'));
    });

    test('pre-fetches after the frame, once, and not past a failure', () {
      expect(
        output,
        contains(
          'if (index < widget.items.length - widget.prefetchOffset) return;',
        ),
      );
      expect(
        output,
        contains(
          'if (!widget.hasMore || widget.isLoadingMore || widget.error != null)',
        ),
      );
      expect(output, contains('addPostFrameCallback'));
      expect(output, contains('if (mounted) widget.onLoadMore();'));
    });

    test('retrying a failed page is loading it again', () {
      expect(
        output,
        contains('_LoadMoreError(message: error, onRetry: widget.onLoadMore)'),
      );
    });

    test('pulls to refresh only on a vertical axis', () {
      expect(
        output,
        contains(
          'final refreshable = onRefresh != null && scrollDirection == Axis.vertical;',
        ),
      );
      expect(output, contains('RefreshIndicator.adaptive('));
      expect(output, contains('const AlwaysScrollableScrollPhysics()'));
    });

    test('reads its spacing from AppConstants', () {
      expect(
        output,
        contains("import '../../../core/constants/app_constants.dart';"),
      );
      expect(output, contains('AppConstants.padding16'));
    });

    test('is in the catalog under lists/', () {
      final spec = WidgetCatalog.all.singleWhere((s) => s.name == 'paged-list');
      expect(spec.title, 'AppPagedList');
      expect(spec.libFile, 'shared/widgets/lists/app_paged_list.dart');
      expect(spec.stacks, isEmpty);
    });
  });
}
