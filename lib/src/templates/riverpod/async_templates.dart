/// Templates for the `AsyncValue` → loading/error/empty/data mapping and the
/// one-shot `error` / `success` feedback wiring.
class AsyncTemplates {
  /// Returns the generated appAsyncView template.
  static String appAsyncView() => r'''
// Private named parameters need a newer Dart than this project may run on.
// ignore_for_file: prefer_initializing_formals

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
///   skeleton: (context) => const HomeSkeleton(),
///   builder: _body,
/// )
/// ```
///
/// [AppAsyncView.stream] and [AppAsyncView.future] take a raw source instead.
/// A reload keeps what is already on screen.
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

  /// Subscribes to [stream] for as long as this widget lives.
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

  // Exactly one of these is set.
  final AsyncValue<T>? _value;
  final Stream<T>? _stream;
  final Future<T>? _future;

  /// Builds the loaded state.
  final Widget Function(BuildContext context, T data) builder;

  /// Shimmered while the first load runs. Null shows a spinner.
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

  /// Shows a retry button on failure. Usually `ref.invalidate(provider)`.
  final VoidCallback? onRetry;

  /// Only an [AppException]'s message is shown; anything else leaks internals.
  String? _messageFor(Object error) =>
      errorMessage ??
      switch (error) {
        AppException(:final message) => message,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value != null) {
      return _render(
        context,
        _AsyncState<T>(
          hasValue: value.hasValue,
          value: value.hasValue ? value.value as T : null,
          error: value.error,
          isLoading: value.isLoading,
        ),
      );
    }

    return _AsyncSource<T>(
      stream: _stream,
      future: _future,
      builder: _render,
    );
  }

  Widget _render(BuildContext context, _AsyncState<T> state) {
    // `hasValue`, not `when`: a reload over shown data keeps the data.
    if (!state.hasValue) {
      final error = state.error;
      if (error != null && !state.isLoading) {
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

    // For a nullable T, null can be the loaded value.
    final data = state.value as T;

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

/// What [AppAsyncView] draws. [hasValue] is its own field because null can be
/// a loaded value.
class _AsyncState<T> {
  const _AsyncState({
    required this.hasValue,
    required this.isLoading,
    this.value,
    this.error,
  });

  final bool hasValue;
  final bool isLoading;
  final T? value;
  final Object? error;
}

/// Follows a [Stream] or a [Future], keeping the last data on screen.
class _AsyncSource<T> extends StatefulWidget {
  const _AsyncSource({
    required this.builder,
    this.stream,
    this.future,
  });

  final Stream<T>? stream;
  final Future<T>? future;
  final Widget Function(BuildContext context, _AsyncState<T> state) builder;

  @override
  State<_AsyncSource<T>> createState() => _AsyncSourceState<T>();
}

class _AsyncSourceState<T> extends State<_AsyncSource<T>> {
  bool _hasValue = false;
  T? _value;
  Object? _error;
  bool _isLoading = true;

  StreamSubscription<T>? _subscription;

  /// The future being awaited; a superseded one's result is ignored.
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
    // The last value stays on screen until the new source answers.
    _isLoading = true;
    _error = null;

    final stream = widget.stream;
    if (stream != null) {
      _subscription = stream.listen(
        _emitData,
        onError: (Object error, StackTrace stackTrace) => _emitError(error),
      );
      return;
    }

    final future = widget.future;
    if (future == null) return;
    _pending = future;
    unawaited(
      future.then(
        (data) => _emitData(data, from: future),
        onError: (Object error, StackTrace stackTrace) =>
            _emitError(error, from: future),
      ),
    );
  }

  void _emitData(T data, {Future<T>? from}) {
    if (!mounted) return;
    if (from != null && !identical(from, _pending)) return;
    setState(() {
      _hasValue = true;
      _value = data;
      _error = null;
      _isLoading = false;
    });
  }

  /// Keeps the last data: a failed refresh does not wipe the screen.
  void _emitError(Object error, {Future<T>? from}) {
    if (!mounted) return;
    if (from != null && !identical(from, _pending)) return;
    setState(() {
      _error = error;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        _AsyncState<T>(
          hasValue: _hasValue,
          value: _value,
          error: _error,
          isLoading: _isLoading,
        ),
      );
}
''';

  /// Returns the generated actionListener template.
  static String actionListener() => r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// For `ProviderListenable` (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';

import '../overlays/app_toast.dart';

/// Reacts to a notifier's one-shot results. Call from `build`.
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
/// [onError] / [onSuccess] replace the toast for that outcome.
extension ActionListener on WidgetRef {
  /// Toasts whichever message the new state carries.
  void listenAction<S>(
    BuildContext context,
    ProviderListenable<AsyncValue<S>> provider, {
    String? Function(S state)? errorOf,
    String? Function(S state)? successOf,
    void Function(String message)? onError,
    void Function(String message)? onSuccess,
  }) {
    listen<AsyncValue<S>>(provider, (previous, next) {
      // A failed load is the view's error screen, not a toast.
      if (next.isLoading) return;
      final state = next.value;
      if (state == null) return;
      if (!context.mounted) return;

      final error = errorOf?.call(state);
      if (error != null && error.isNotEmpty) {
        if (onError != null) {
          onError(error);
        } else {
          AppToast.error(context, error);
        }
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

  /// Calls [onChange] once for each new non-null value [select] reads — for
  /// one-shot results that are not a message (a created id, a done flag).
  ///
  /// ```dart
  /// ref.listenChange<CreateOrderState, String>(
  ///   context,
  ///   createOrderNotifierProvider,
  ///   select: (state) => state.createdOrderId,
  ///   onChange: (id) =>
  ///       ref.read(routerProvider).push(AppRoutes.featureDetailOf(id)),
  /// );
  /// ```
  ///
  /// Register it after [listenAction] so the toast shows before navigating.
  /// For a flag, select `(state) => state.isDone ? true : null`.
  void listenChange<S, T extends Object>(
    BuildContext context,
    ProviderListenable<AsyncValue<S>> provider, {
    required T? Function(S state) select,
    required void Function(T value) onChange,
  }) {
    listen<AsyncValue<S>>(provider, (previous, next) {
      if (next.isLoading) return;
      final state = next.value;
      if (state == null) return;

      final value = select(state);
      if (value == null) return;

      // Fire only when the value appears or changes.
      final before = previous?.value;
      if (before != null && select(before) == value) return;

      if (!context.mounted) return;
      onChange(value);
    });
  }
}
''';
}
