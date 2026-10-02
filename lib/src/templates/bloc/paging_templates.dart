import '../core/core_templates.dart';

/// Templates for loading a list page by page from a bloc.
///
/// The counterpart to `templates/riverpod/paging_templates.dart`: the same
/// `PagedList` state value, written by a mixin on `Bloc` instead of one on
/// `AsyncNotifier`.
class PagingTemplates {
  PagingTemplates._();

  /// Returns the generated pagedList template — `core/utils/paged_list.dart`.
  ///
  /// The first page is the screen's load event, run through `runAction` like
  /// any other, so a refresh re-dispatches it and the four first-load screens
  /// stay `AppStatusView`'s. The mixin owns only "load more", with the same
  /// one-page-at-a-time and stale-page rules as Riverpod's. It needs no
  /// `bloc_concurrency` transformer: the loading flag is emitted before the
  /// first `await`, so a second event arriving meanwhile already sees it.
  static String pagedList() =>
      r'''
import 'package:bloc/bloc.dart';

import '../errors/app_exception.dart';
import '../network/paginated.dart';
''' +
      CoreTemplates.pagedListState +
      r'''

/// "Load more" for a [Bloc] whose state holds a [PagedList].
///
/// ```dart
/// class OrdersBloc extends Bloc<OrdersEvent, OrdersState>
///     with
///         ActionBlocMixin<OrdersEvent, OrdersState>,
///         PagedBlocMixin<OrdersEvent, OrdersState, OrderModel> {
///   OrdersBloc(this._repo) : super(const OrdersState()) {
///     on<OrdersStarted>(
///       (event, emit) => runAction(emit, (current) async {
///         final page = await _repo.fetchOrders();
///         return current.copyWith(
///           status: AppStatus.success,
///           orders: PagedList.first(page),
///         );
///       }),
///     );
///     on<OrdersMoreRequested>((event, emit) => loadMore(emit));
///   }
///
///   final OrdersRepository _repo;
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
/// The view's `AppPagedList.onLoadMore` adds `OrdersMoreRequested`, and its
/// `onRefresh` adds `OrdersStarted` and returns `bloc.stream.first`.
mixin PagedBlocMixin<E, S, T> on Bloc<E, S> {
  /// Loads the page after the one keyed [next]. Usually the repository call.
  Future<Paginated<T>> fetchPage(Object? next);

  /// The paged list inside [state].
  PagedList<T> pagedOf(S state);

  /// [state] holding [paged] instead.
  S withPaged(S state, PagedList<T> paged);

  /// Appends the next page. Also the retry after a failed one.
  ///
  /// Does nothing while a page is loading or after the last page — so the
  /// list can dispatch it on every scroll without guarding.
  Future<void> loadMore(Emitter<S> emit) async {
    final paged = pagedOf(state);
    if (!paged.hasMore || paged.isLoadingMore) return;

    final loading = paged.loading();
    emit(withPaged(state, loading));

    PagedList<T> settled;
    try {
      settled = loading.append(await fetchPage(paged.next));
    } on AppException catch (e) {
      settled = loading.failed(e.message);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      settled = loading.failed('Unknown error');
    }

    // Refreshed or closed while the page loaded: it belongs to a list that
    // is gone.
    if (emit.isDone || !identical(pagedOf(state), loading)) return;
    emit(withPaged(state, settled));
  }
}
''';
}
