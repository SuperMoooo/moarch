/// Templates for the two pieces every Riverpod screen ends up rewriting: the
/// `AsyncValue` → loading/error/empty/data mapping, and the wiring that turns a
/// notifier's one-shot `error` / `success` fields into feedback on screen.
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

/// Renders one asynchronous source as the four states it can actually be in —
/// loading, failed, empty, loaded — so a screen describes its content once
/// instead of re-deciding the mapping every time.
///
/// The default constructor takes the [AsyncValue] a provider hands back, which
/// is what a notifier, a `FutureProvider` and a `StreamProvider` all give:
///
/// ```dart
/// final homeAsync = ref.watch(homeNotifierProvider);
///
/// return Scaffold(
///   body: AppAsyncView<HomeState>(
///     value: homeAsync,
///     onRetry: () => ref.invalidate(homeNotifierProvider),
///     isEmpty: (state) => state.items.isEmpty,
///     builder: (context, state) => ListView(...),
///   ),
/// );
/// ```
///
/// [AppAsyncView.stream] and [AppAsyncView.future] take the source itself, for
/// the ones that never became a provider — a Firestore query, a socket, a
/// one-off fetch. Everything else is the same widget, so a screen reads the
/// same whether or not its data went through Riverpod:
///
/// ```dart
/// AppAsyncView<List<Order>>.stream(
///   stream: repository.watchOrders(),
///   isEmpty: (orders) => orders.isEmpty,
///   builder: (context, orders) => ListView(...),
/// )
/// ```
///
/// It builds *inline*, not as a route: the result is a body, so it can sit
/// inside a [Scaffold] that keeps its app bar while the content is still
/// loading. Wrap it yourself if you want a bare loading route instead.
///
/// **A reload does not blank the screen.** Riverpod keeps the previous data
/// through a refresh, and so does this: once there is something to show, a
/// later loading or error state leaves it on screen rather than replacing a
/// list the user is reading with a spinner. A failed refresh is reported by
/// `listenAction`, which is what one-shot feedback is for. The raw sources
/// hold the same line — a stream that errors or is swapped for another keeps
/// what it had already emitted.
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

  /// Subscribes to [stream] and renders whatever it is currently saying.
  ///
  /// The subscription is this widget's: it starts with the element, is
  /// cancelled with it, and is replaced when a different stream is passed.
  ///
  /// [onRetry] stays the caller's business — a dead stream is re-opened by
  /// building this widget with a new one, which only the screen can do.
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

  /// Awaits [future] and renders the result.
  ///
  /// A [Future] runs once and cannot be re-awaited, so a retry means handing
  /// over a new one — `setState(() => _future = repository.load())` — and
  /// [onRetry] is where that goes.
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

  /// The shape to shimmer while the first load runs. A screen that knows what
  /// it is about to look like should pass its own body built from an empty
  /// state — `body(context, const HomeState())` — which reads as the real
  /// layout arriving rather than as a spinner interrupting.
  ///
  /// Null falls back to a centered spinner.
  final Widget? skeleton;

  /// Whether loaded data counts as nothing to show. Null means it never does —
  /// a state object is not a list, and only the screen knows which of its
  /// fields being empty makes the page empty.
  final bool Function(T data)? isEmpty;

  /// Copy for the empty state. Anything left null keeps [EmptyView]'s own
  /// wording, so a screen only says what is specific to it.
  final String? emptyTitle;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Copy for the failed state. [errorMessage] overrides the exception's own
  /// message, which is otherwise what the user is shown.
  final String? errorTitle;
  final String? errorMessage;

  /// Offering a retry is what puts the button in [ErrorView].
  /// `() => ref.invalidate(theProvider)` is the usual answer.
  final VoidCallback? onRetry;

  /// The message an error state shows: the caller's, else the one the failure
  /// was built to carry, else nothing — and [ErrorView] says something sane
  /// when it is handed nothing.
  ///
  /// Anything else deliberately shows no detail. `error.toString()` on an
  /// arbitrary throw is a class name and a stack-shaped sentence, which tells
  /// the user nothing and leaks how the app is put together.
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

    // A raw source needs somewhere to live: [_AsyncSource] holds the
    // subscription and turns it into the same [AsyncValue] the rest of this
    // widget already knows how to draw.
    return _AsyncSource<T>(
      stream: _stream,
      future: _future,
      builder: _render,
    );
  }

  Widget _render(BuildContext context, AsyncValue<T> value) {
    // `hasValue` rather than a `when`: it is what separates "still waiting for
    // the first result" from "already showing one and fetching again".
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
      return Skeletonizer(child: shape);
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

/// Turns a [Stream] or a [Future] into the [AsyncValue] [AppAsyncView] draws.
///
/// Riverpod does this for a provider; this is the same job for a source that
/// never became one, including the part that matters most — `copyWithPrevious`
/// carries the last data forward, so an error or a swapped-in stream does not
/// wipe what the user is already looking at.
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

  /// The future currently being awaited. A screen that rebuilds with a new one
  /// leaves the old still running, and its late result is not ours to show.
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
    // A new source is a load, but not a blank screen: what is already on it
    // stays until the replacement has something of its own to say.
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
///
/// The states generated by `moarch create feature` carry those two fields and
/// clear them on the next `copyWith`, precisely so a message is surfaced once.
/// This is the half that surfaces it:
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   ref.listenAction<HomeState>(
///     context,
///     homeNotifierProvider,
///     errorOf: (state) => state.error,
///     successOf: (state) => state.success,
///   );
///   ...
/// }
/// ```
///
/// Call it from `build`, like any other `ref.listen` — Riverpod keeps one
/// subscription per call site across rebuilds, and drops it with the widget.
///
/// Pass [onError] or [onSuccess] to do something other than toast: pop the
/// route on success, send the user somewhere, log it. Providing one replaces
/// the toast for that outcome rather than adding to it, so a screen that
/// navigates does not also flash a message on the way out.
extension ActionListener on WidgetRef {
  /// Listens to [provider] and reports whichever message the new state carries.
  ///
  /// [errorOf] and [successOf] pull the messages out of the state. Both are
  /// optional — a screen that only ever reports failures leaves [successOf]
  /// unset and nothing looks for a success message.
  void listenAction<S>(
    BuildContext context,
    ProviderListenable<AsyncValue<S>> provider, {
    String? Function(S state)? errorOf,
    String? Function(S state)? successOf,
    void Function(String message)? onError,
    void Function(String message)? onSuccess,
  }) {
    listen<AsyncValue<S>>(provider, (previous, next) {
      // A load in flight has no outcome to report yet, and a failure of the
      // provider itself is the view's error state to draw — not a toast on top
      // of it. What is left is a state that arrived carrying a message.
      if (next.isLoading) return;
      final state = next.value;
      if (state == null) return;

      // The listener outlives nothing here — Riverpod drops the subscription
      // with the widget — but an action can still land in the same frame the
      // route is popped, and a toast needs a mounted context to find its
      // messenger.
      if (!context.mounted) return;

      final error = errorOf?.call(state);
      if (error != null && error.isNotEmpty) {
        if (onError != null) {
          onError(error);
        } else {
          AppToast.error(context, error);
        }
        // A single action reports one outcome. Falling through would toast a
        // success left over from the call before it.
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
