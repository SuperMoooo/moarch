/// Templates for the paged lists — what mo_infinite_scroll became once it
/// joined the kit.
///
/// The package owned its pages in a `ChangeNotifier` controller fed by a
/// fetcher callback, which put a screen's data outside its notifier or bloc.
/// Here the widgets hold nothing: the state's `PagedList`
/// (`core/utils/paged_list.dart`) says what is loaded, whether more exists and
/// whether the next page is loading or failed, and `onLoadMore` asks the
/// notifier or bloc for it. What the package knew — pre-fetching a few items
/// before the end, one tail row for loading and for retry, pull-to-refresh
/// only on a vertical axis, a sliver form for a `CustomScrollView` — is kept.
class PagedTemplates {
  PagedTemplates._();

  /// Returns the generated appPagedList template.
  ///
  /// One file for the three widgets because they are one widget: the list and
  /// the grid are [AppPagedSliver] in a scroll view, and splitting them would
  /// make the sliver a dependency the other two pull in anyway. The first
  /// page's skeleton, error and empty screens are deliberately absent —
  /// `AppAsyncView` / `AppStatusView` draw those around it.
  static String appPagedList() => r'''
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// A list that asks for its next page as the user nears the end.
///
/// It holds no pages itself: pass the fields of the state's `PagedList` and a
/// way to ask the notifier or bloc for more. Draw it inside `AppAsyncView` /
/// `AppStatusView`, which own the first load's skeleton, error and empty
/// screens.
///
/// ```dart
/// // Riverpod — the notifier mixes in PagedNotifierMixin.
/// AppPagedList<OrderModel>(
///   items: state.orders.items,
///   hasMore: state.orders.hasMore,
///   isLoadingMore: state.orders.isLoadingMore,
///   error: state.orders.error,
///   onLoadMore: ref.read(ordersNotifierProvider.notifier).loadMore,
///   onRefresh: () => ref.refresh(ordersNotifierProvider.future),
///   itemBuilder: (context, order) => OrderTile(order: order),
/// )
///
/// // Bloc — the bloc mixes in PagedBlocMixin.
/// AppPagedList<OrderModel>(
///   items: state.orders.items,
///   hasMore: state.orders.hasMore,
///   isLoadingMore: state.orders.isLoadingMore,
///   error: state.orders.error,
///   onLoadMore: () => bloc.add(const OrdersMoreRequested()),
///   onRefresh: () {
///     bloc.add(const OrdersStarted());
///     return bloc.stream.first;
///   },
///   itemBuilder: (context, order) => OrderTile(order: order),
/// )
/// ```
///
/// Pull-to-refresh is on when [onRefresh] is set and the list is vertical.
class AppPagedList<T> extends StatelessWidget {
  const AppPagedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.hasMore,
    required this.onLoadMore,
    this.isLoadingMore = false,
    this.error,
    this.onRefresh,
    this.separatorBuilder,
    this.prefetchOffset = 3,
    this.loadingMoreIndicator,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.controller,
    this.padding,
    this.physics,
  });

  /// Every item loaded so far — `PagedList.items`.
  final List<T> items;

  /// Builds one item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Whether a page exists after the last one loaded.
  final bool hasMore;

  /// Asks for the next page — also the retry after a failed one. Called
  /// freely; the paging mixins ignore it while a page is already loading.
  final VoidCallback onLoadMore;

  /// Whether the next page is loading. Draws the spinner row.
  final bool isLoadingMore;

  /// Why the next page failed. Draws the retry row and stops pre-fetching.
  final String? error;

  /// Reloads from the first page. Null turns pull-to-refresh off.
  final RefreshCallback? onRefresh;

  /// Drawn between items, as in [ListView.separated].
  final IndexedWidgetBuilder? separatorBuilder;

  /// How many items before the end to ask for the next page.
  final int prefetchOffset;

  /// Replaces the spinner row.
  final Widget? loadingMoreIndicator;

  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return _PagedScrollView(
      onRefresh: onRefresh,
      scrollDirection: scrollDirection,
      reverse: reverse,
      shrinkWrap: shrinkWrap,
      controller: controller,
      padding: padding,
      physics: physics,
      sliver: AppPagedSliver<T>(
        items: items,
        itemBuilder: itemBuilder,
        hasMore: hasMore,
        onLoadMore: onLoadMore,
        isLoadingMore: isLoadingMore,
        error: error,
        separatorBuilder: separatorBuilder,
        prefetchOffset: prefetchOffset,
        loadingMoreIndicator: loadingMoreIndicator,
      ),
    );
  }
}

/// [AppPagedList] laid out as a grid.
///
/// ```dart
/// AppPagedGrid<ProductModel>(
///   items: state.products.items,
///   hasMore: state.products.hasMore,
///   isLoadingMore: state.products.isLoadingMore,
///   error: state.products.error,
///   onLoadMore: notifier.loadMore,
///   gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
///     maxCrossAxisExtent: 200,
///     mainAxisSpacing: AppConstants.space12,
///     crossAxisSpacing: AppConstants.space12,
///   ),
///   itemBuilder: (context, product) => ProductCard(product: product),
/// )
/// ```
///
/// The loading and retry rows span the full width below the grid.
class AppPagedGrid<T> extends StatelessWidget {
  const AppPagedGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.hasMore,
    required this.onLoadMore,
    required this.gridDelegate,
    this.isLoadingMore = false,
    this.error,
    this.onRefresh,
    this.prefetchOffset = 6,
    this.loadingMoreIndicator,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.controller,
    this.padding,
    this.physics,
  });

  /// See [AppPagedList.items].
  final List<T> items;

  /// Builds one cell.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// See [AppPagedList.hasMore].
  final bool hasMore;

  /// See [AppPagedList.onLoadMore].
  final VoidCallback onLoadMore;

  /// How the cells are laid out.
  final SliverGridDelegate gridDelegate;

  /// See [AppPagedList.isLoadingMore].
  final bool isLoadingMore;

  /// See [AppPagedList.error].
  final String? error;

  /// See [AppPagedList.onRefresh].
  final RefreshCallback? onRefresh;

  /// How many cells before the end to ask for the next page — a row or two,
  /// so higher than a list's.
  final int prefetchOffset;

  /// Replaces the spinner row.
  final Widget? loadingMoreIndicator;

  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return _PagedScrollView(
      onRefresh: onRefresh,
      scrollDirection: scrollDirection,
      reverse: reverse,
      shrinkWrap: shrinkWrap,
      controller: controller,
      padding: padding,
      physics: physics,
      sliver: AppPagedSliver<T>.grid(
        items: items,
        itemBuilder: itemBuilder,
        hasMore: hasMore,
        onLoadMore: onLoadMore,
        gridDelegate: gridDelegate,
        isLoadingMore: isLoadingMore,
        error: error,
        prefetchOffset: prefetchOffset,
        loadingMoreIndicator: loadingMoreIndicator,
      ),
    );
  }
}

/// The paged list as a sliver, for a [CustomScrollView] with other slivers —
/// a collapsing app bar, a header above the list.
///
/// ```dart
/// RefreshIndicator.adaptive(
///   onRefresh: () => ref.refresh(ordersNotifierProvider.future),
///   child: CustomScrollView(
///     physics: const AlwaysScrollableScrollPhysics(),
///     slivers: [
///       const SliverAppBar.medium(title: Text('Orders')),
///       AppPagedSliver<OrderModel>(
///         items: state.orders.items,
///         hasMore: state.orders.hasMore,
///         isLoadingMore: state.orders.isLoadingMore,
///         error: state.orders.error,
///         onLoadMore: ref.read(ordersNotifierProvider.notifier).loadMore,
///         itemBuilder: (context, order) => OrderTile(order: order),
///       ),
///     ],
///   ),
/// )
/// ```
///
/// Refreshing is the parent's, since the scroll view is.
class AppPagedSliver<T> extends StatefulWidget {
  /// The items one after another.
  const AppPagedSliver({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.hasMore,
    required this.onLoadMore,
    this.isLoadingMore = false,
    this.error,
    this.separatorBuilder,
    this.prefetchOffset = 3,
    this.loadingMoreIndicator,
  }) : gridDelegate = null;

  /// The items in a grid laid out by [gridDelegate].
  const AppPagedSliver.grid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.hasMore,
    required this.onLoadMore,
    required SliverGridDelegate this.gridDelegate,
    this.isLoadingMore = false,
    this.error,
    this.prefetchOffset = 6,
    this.loadingMoreIndicator,
  }) : separatorBuilder = null;

  /// See [AppPagedList.items].
  final List<T> items;

  /// Builds one item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// See [AppPagedList.hasMore].
  final bool hasMore;

  /// See [AppPagedList.onLoadMore].
  final VoidCallback onLoadMore;

  /// See [AppPagedList.isLoadingMore].
  final bool isLoadingMore;

  /// See [AppPagedList.error].
  final String? error;

  /// Drawn between items. Lists only.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Lays the items out as a grid. Null is a list.
  final SliverGridDelegate? gridDelegate;

  /// How many items before the end to ask for the next page.
  final int prefetchOffset;

  /// Replaces the spinner row.
  final Widget? loadingMoreIndicator;

  @override
  State<AppPagedSliver<T>> createState() => _AppPagedSliverState<T>();
}

class _AppPagedSliverState<T> extends State<AppPagedSliver<T>> {
  /// One request per frame, however many items near the end were built in it.
  bool _requested = false;

  /// Asks for the next page once [index] is within the pre-fetch distance.
  ///
  /// After the frame, because the notifier or bloc updates state at once and
  /// state must not change while this list is building.
  void _maybeLoadMore(int index) {
    if (index < widget.items.length - widget.prefetchOffset) return;
    if (!widget.hasMore || widget.isLoadingMore || widget.error != null) {
      return;
    }
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requested = false;
      if (mounted) widget.onLoadMore();
    });
  }

  Widget _item(BuildContext context, int index) {
    _maybeLoadMore(index);
    return widget.itemBuilder(context, widget.items[index]);
  }

  @override
  Widget build(BuildContext context) {
    final gridDelegate = widget.gridDelegate;
    final separatorBuilder = widget.separatorBuilder;
    final count = widget.items.length;

    final Widget body;
    if (gridDelegate != null) {
      body = SliverGrid.builder(
        gridDelegate: gridDelegate,
        itemCount: count,
        itemBuilder: _item,
      );
    } else if (separatorBuilder != null) {
      body = SliverList.separated(
        itemCount: count,
        itemBuilder: _item,
        separatorBuilder: separatorBuilder,
      );
    } else {
      body = SliverList.builder(itemCount: count, itemBuilder: _item);
    }

    final error = widget.error;
    final Widget? footer = error != null
        ? _LoadMoreError(message: error, onRetry: widget.onLoadMore)
        : widget.isLoadingMore
        ? widget.loadingMoreIndicator ?? const _LoadingMore()
        : null;

    if (footer == null) return body;
    return SliverMainAxisGroup(
      slivers: [body, SliverToBoxAdapter(child: footer)],
    );
  }
}

/// Wraps a paged sliver in a scroll view, with pull-to-refresh when it can
/// have it — a [RefreshIndicator] only answers a vertical drag.
class _PagedScrollView extends StatelessWidget {
  const _PagedScrollView({
    required this.sliver,
    required this.onRefresh,
    required this.scrollDirection,
    required this.reverse,
    required this.shrinkWrap,
    required this.controller,
    required this.padding,
    required this.physics,
  });

  final Widget sliver;
  final RefreshCallback? onRefresh;
  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final onRefresh = this.onRefresh;
    final refreshable = onRefresh != null && scrollDirection == Axis.vertical;
    final padding = this.padding;

    final view = CustomScrollView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      shrinkWrap: shrinkWrap,
      controller: controller,
      // A list shorter than the screen still has to be pullable.
      physics:
          physics ??
          (refreshable ? const AlwaysScrollableScrollPhysics() : null),
      slivers: [
        if (padding == null)
          sliver
        else
          SliverPadding(padding: padding, sliver: sliver),
      ],
    );

    if (!refreshable) return view;
    return RefreshIndicator.adaptive(onRefresh: onRefresh, child: view);
  }
}

/// The row at the end of the list while the next page loads.
class _LoadingMore extends StatelessWidget {
  const _LoadingMore();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: AppConstants.padding16,
      child: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

/// The row at the end of the list when the next page failed. The items above
/// it stay; retrying asks for the same page again.
class _LoadMoreError extends StatelessWidget {
  const _LoadMoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: AppConstants.padding12,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppConstants.space8,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: AppConstants.iconSmall),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
''';
}
