import 'package:moarch/src/templates/bloc/paging_templates.dart' as bloc;
import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/riverpod/paging_templates.dart'
    as riverpod;
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

void main() {
  group('paged_list.dart', () {
    final riverpodOutput = riverpod.PagingTemplates.pagedList();
    final blocOutput = bloc.PagingTemplates.pagedList();

    test('both stacks share one PagedList', () {
      expect(riverpodOutput, contains(CoreTemplates.pagedListState));
      expect(blocOutput, contains(CoreTemplates.pagedListState));
      for (final output in [riverpodOutput, blocOutput]) {
        expect(output, contains("import '../errors/app_exception.dart';"));
        expect(output, contains("import '../network/paginated.dart';"));
      }
    });

    test('the facade resolves the stack', () {
      expect(
        const StackTemplates(StateManagement.riverpod).pagedList(),
        riverpodOutput,
      );
      expect(
        const StackTemplates(StateManagement.bloc).pagedList(),
        blocOutput,
      );
    });

    test('Riverpod pages through a mixin on AsyncNotifier', () {
      expect(
        riverpodOutput,
        contains('mixin PagedNotifierMixin<S, T> on AsyncNotifier<S> {'),
      );
      expect(riverpodOutput, contains('Future<void> loadMore() async {'));
      // Nothing about Flutter or bloc leaks into the notifier side.
      expect(riverpodOutput, isNot(contains('package:bloc')));
    });

    test('bloc pages through a mixin on Bloc', () {
      expect(
        blocOutput,
        contains('mixin PagedBlocMixin<E, S, T> on Bloc<E, S> {'),
      );
      expect(
        blocOutput,
        contains('Future<void> loadMore(Emitter<S> emit) async {'),
      );
      // Unexpected failures reach the observer, as runAction's do.
      expect(blocOutput, contains('addError(error, stackTrace);'));
      expect(blocOutput, isNot(contains('flutter_riverpod')));
    });

    test('one page at a time, and a stale page is dropped', () {
      for (final output in [riverpodOutput, blocOutput]) {
        expect(
          output,
          contains('if (!paged.hasMore || paged.isLoadingMore) return;'),
        );
        // A refresh builds a new PagedList, so identity tells a page loaded
        // for the list on screen from one loaded for a list since replaced.
        expect(output, contains('identical(pagedOf('));
        expect(output, contains('loading.failed(e.message)'));
      }
      expect(riverpodOutput, contains('if (!ref.mounted || state.isLoading)'));
      expect(blocOutput, contains('if (emit.isDone ||'));
    });
  });
}
