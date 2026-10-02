import '../core/core_templates.dart';

/// Templates for loading a list page by page from a notifier.
///
/// The counterpart to `templates/bloc/paging_templates.dart`: the same
/// `PagedList` state value, written by a mixin on `AsyncNotifier` instead of
/// one on `Bloc`.
class PagingTemplates {
  PagingTemplates._();

  /// Returns the generated pagedList template — `core/utils/paged_list.dart`.
  ///
  /// The first page is `build()`'s, so a refresh is `ref.invalidate` and the
  /// four first-load screens stay `AppAsyncView`'s. The mixin owns only "load
  /// more": one page at a time, and a page that lands after the list it
  /// belonged to was refreshed away is dropped rather than appended to the new
  /// one — the race mo_infinite_scroll's generation counter guarded, here
  /// guarded by identity, since a refresh always builds a new `PagedList`.
  static String pagedList() =>
      r'''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import '../network/paginated.dart';
''' +
      CoreTemplates.pagedListState +
      r'''

/// "Load more" for an [AsyncNotifier] whose state holds a [PagedList].
///
/// ```dart
/// class OrdersNotifier extends AsyncNotifier<OrdersState>
///     with PagedNotifierMixin<OrdersState, OrderModel> {
///   final _repo = getIt<OrdersRepository>();
///
///   @override
///   Future<OrdersState> build() async =>
///       OrdersState(orders: PagedList.first(await _repo.fetchOrders()));
///
///   @override
///   Future<Paginated<OrderModel>> fetchPage(Object? next) =>
///       _repo.fetchOrders(next: next);
///
///   @override
///   PagedList<OrderModel> pagedOf(OrdersState state) => state.orders;
///
///   @override
///   OrdersState withPaged(OrdersState state, PagedList<OrderModel> paged) =>
///       state.copyWith(orders: paged);
/// }
/// ```
///
/// The view passes [loadMore] to `AppPagedList.onLoadMore`, and
/// `() => ref.refresh(ordersNotifierProvider.future)` to its `onRefresh`.
mixin PagedNotifierMixin<S, T> on AsyncNotifier<S> {
  /// Loads the page after the one keyed [next]. Usually the repository call.
  Future<Paginated<T>> fetchPage(Object? next);

  /// The paged list inside [state].
  PagedList<T> pagedOf(S state);

  /// [state] holding [paged] instead.
  S withPaged(S state, PagedList<T> paged);

  /// Appends the next page. Also the retry after a failed one.
  ///
  /// Does nothing while a page or a refresh is loading, or after the last
  /// page — so the list can call it on every scroll without guarding.
  Future<void> loadMore() async {
    if (state.isLoading) return;
    final current = state.value;
    if (current == null) return;
    final paged = pagedOf(current);
    if (!paged.hasMore || paged.isLoadingMore) return;

    final loading = paged.loading();
    state = AsyncData(withPaged(current, loading));

    PagedList<T> settled;
    try {
      settled = loading.append(await fetchPage(paged.next));
    } on AppException catch (e) {
      settled = loading.failed(e.message);
    } catch (_) {
      settled = loading.failed('Unknown error');
    }

    // Refreshed or disposed while the page loaded: it belongs to a list that
    // is gone.
    if (!ref.mounted || state.isLoading) return;
    final latest = state.value;
    if (latest == null || !identical(pagedOf(latest), loading)) return;
    state = AsyncData(withPaged(latest, settled));
  }
}
''';
}
