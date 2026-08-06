/// Templates for the `AsyncValue` → loading/error/empty/data mapping and the
/// one-shot `error` / `success` feedback wiring.
class AsyncTemplates {
  /// Returns the generated appAsyncView template.
  static String appAsyncView() => r'''
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import './empty_view.dart';
import './error_view.dart';
import '../../core/errors/app_exception.dart';

/// Renders one asynchronous source as loading, failed, empty or loaded.
///
/// ```dart
/// AppAsyncView<HomeState>(
///   value: ref.watch(homeNotifierProvider),
///   onRetry: () => ref.invalidate(homeNotifierProvider),
///   isEmpty: (state) => state.items.isEmpty,
///   skeleton: (context) => _body(context, HomeState.placeholder),
///   builder: _body,
/// )
/// ```
///
/// [AppAsyncView.stream] and [AppAsyncView.future] take a raw source instead,
/// for data that never became a provider. It builds inline, not as a route, so
/// a [Scaffold] keeps its app bar while the content loads. Once there is
/// something to show, a later reload leaves it on screen rather than swapping
/// it for a spinner.
class AppAsyncView<T> extends StatelessWidget {
  /// Renders the [AsyncValue] a provider handed back.
  const AppAsyncView({
    super.key,
    required AsyncValue<T> value,
    required this.builder,
    this.skeleton,
    this.isEmpty,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
  })  : _value = value,
        _stream = null,
        _future = null;

  /// Subscribes to [stream] for as long as this widget lives. Reopening a dead
  /// stream means rebuilding with a new one, so [onRetry] is the caller's job.
  const AppAsyncView.stream({
    super.key,
    required Stream<T> stream,
    required this.builder,
    this.skeleton,
    this.isEmpty,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
  })  : _stream = stream,
        _value = null,
        _future = null;

  /// Awaits [future] and renders the result. A future runs once, so a retry
  /// means handing over a new one from [onRetry].
  const AppAsyncView.future({
    super.key,
    required Future<T> future,
    required this.builder,
    this.skeleton,
    this.isEmpty,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
  })  : _future = future,
        _value = null,
        _stream = null;

  /// Exactly one of these is set, by the constructor that was used.
  final AsyncValue<T>? _value;
  final Stream<T>? _stream;
  final Future<T>? _future;

  /// Builds the loaded state.
  final Widget Function(BuildContext context, T data) builder;

  /// The shape to shimmer while the first load runs, e.g.
  /// `(context) => _body(context, HomeState.placeholder)`. Null shows a
  /// centered spinner instead.
  ///
  /// It must be built from *fake* data, not an empty state — Skeletonizer
  /// traces the tree it is handed, so a `ListView.builder` over nothing traces
  /// to a blank screen. States from `moarch create feature` carry a
  /// `placeholder` for this.
  final WidgetBuilder? skeleton;

  /// Whether loaded data counts as nothing to show. Null means it never does.
  final bool Function(T data)? isEmpty;

  /// Copy for the empty state. Null keeps [EmptyView]'s own wording.
  final String? emptyTitle;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Copy for the failed state. [errorMessage] overrides the exception's own.
  final String? errorTitle;
  final String? errorMessage;

  /// Passing this is what puts the retry button in [ErrorView]. Usually
  /// `() => ref.invalidate(theProvider)`.
  final VoidCallback? onRetry;

  /// Anything that is not an [AppException] shows no detail on purpose —
  /// `error.toString()` tells the user nothing and leaks internals.
  String? _messageFor(Object error) =>
      errorMessage ??
      switch (error) {
        AppException(:final message) => message,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value != null) return _render(context, value);

    return _AsyncSource<T>(
      stream: _stream,
      future: _future,
      builder: _render,
    );
  }

  Widget _render(BuildContext context, AsyncValue<T> value) {
    // `hasValue` rather than `when`: it separates "still waiting for the first
    // result" from "already showing one and fetching again".
    if (!value.hasValue) {
      final error = value.error;
      if (error != null && !value.isLoading) {
        return ErrorView(
          title: errorTitle ?? 'Something went wrong',
          message: _messageFor(error),
          onRetry: onRetry,
        );
      }
      final shape = skeleton;
      if (shape == null) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }
      return Skeletonizer(child: shape(context));
    }

    // Non-null by `hasValue`, and the cast keeps a nullable T honest: a
    // provider of `String?` can hold null *as its value*, and that is data.
    final data = value.value as T;

    if (isEmpty?.call(data) ?? false) {
      return EmptyView(
        title: emptyTitle ?? 'Nothing here yet',
        message: emptyMessage ?? 'No items are available right now.',
        icon: emptyIcon ?? Icons.inbox_outlined,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      );
    }

    return builder(context, data);
  }
}

/// Turns a [Stream] or a [Future] into the [AsyncValue] [AppAsyncView] draws,
/// carrying the last data forward so an error never wipes the screen.
class _AsyncSource<T> extends StatefulWidget {
  const _AsyncSource({
    required this.builder,
    this.stream,
    this.future,
  });

  final Stream<T>? stream;
  final Future<T>? future;
  final Widget Function(BuildContext context, AsyncValue<T> value) builder;

  @override
  State<_AsyncSource<T>> createState() => _AsyncSourceState<T>();
}

class _AsyncSourceState<T> extends State<_AsyncSource<T>> {
  // Not `const`: a constant cannot be built out of a type parameter.
  AsyncValue<T> _value = AsyncValue<T>.loading();
  StreamSubscription<T>? _subscription;

  /// The future currently being awaited — a superseded one still completes,
  /// and its late result is not ours to show.
  Future<T>? _pending;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _AsyncSource<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream || widget.future != oldWidget.future) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
    _pending = null;
  }

  void _subscribe() {
    // A new source is a load, not a blank screen.
    _value = AsyncValue<T>.loading().copyWithPrevious(_value);

    final stream = widget.stream;
    if (stream != null) {
      _subscription = stream.listen(
        (data) => _emit(AsyncValue<T>.data(data)),
        onError: (Object error, StackTrace stackTrace) =>
            _emit(AsyncValue<T>.error(error, stackTrace)),
      );
      return;
    }

    final future = widget.future;
    if (future == null) return;
    _pending = future;
    unawaited(
      future.then(
        (data) => _emit(AsyncValue<T>.data(data), from: future),
        onError: (Object error, StackTrace stackTrace) =>
            _emit(AsyncValue<T>.error(error, stackTrace), from: future),
      ),
    );
  }

  /// Records [next] over what came before. [from] is checked for futures,
  /// whose results arrive whether or not anyone is still waiting for them.
  void _emit(AsyncValue<T> next, {Future<T>? from}) {
    if (!mounted) return;
    if (from != null && !identical(from, _pending)) return;
    setState(() => _value = next.copyWithPrevious(_value));
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
''';

  /// Returns the generated actionListener template.
  static String actionListener() => r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../overlays/app_toast.dart';

/// Reports a notifier's one-shot `error` / `success` messages to the user.
/// Call it from `build`, like any other `ref.listen`.
///
/// ```dart
/// ref.listenAction<HomeState>(
///   context,
///   homeNotifierProvider,
///   errorOf: (state) => state.error,
///   successOf: (state) => state.success,
/// );
/// ```
///
/// [onError] / [onSuccess] replace the toast for that outcome rather than
/// adding to it, so a screen that navigates does not also flash a message.
extension ActionListener on WidgetRef {
  /// Listens to [provider] and reports whichever message the new state carries.
  /// [errorOf] and [successOf] are both optional.
  void listenAction<S>(
    BuildContext context,
    ProviderListenable<AsyncValue<S>> provider, {
    String? Function(S state)? errorOf,
    String? Function(S state)? successOf,
    void Function(String message)? onError,
    void Function(String message)? onSuccess,
  }) {
    listen<AsyncValue<S>>(provider, (previous, next) {
      // A load has no outcome yet, and a failed provider is the view's error
      // state to draw — not a toast on top of it.
      if (next.isLoading) return;
      final state = next.value;
      if (state == null) return;

      // An action can land in the same frame the route is popped.
      if (!context.mounted) return;

      final error = errorOf?.call(state);
      if (error != null && error.isNotEmpty) {
        if (onError != null) {
          onError(error);
        } else {
          AppToast.error(context, error);
        }
        // One outcome per action — falling through would toast a stale success.
        return;
      }

      final success = successOf?.call(state);
      if (success != null && success.isNotEmpty) {
        if (onSuccess != null) {
          onSuccess(success);
        } else {
          AppToast.success(context, success);
        }
      }
    });
  }
}
''';
}
