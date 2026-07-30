/// Templates for the two pieces every Riverpod screen ends up rewriting: the
/// `AsyncValue` → loading/error/empty/data mapping, and the wiring that turns a
/// notifier's one-shot `error` / `success` fields into feedback on screen.
class AsyncTemplates {
  /// Returns the generated appAsyncView template.
  static String appAsyncView() => r'''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import './empty_view.dart';
import './error_view.dart';
import '../../core/errors/app_exception.dart';

/// Renders one [AsyncValue] as the four states it can actually be in —
/// loading, failed, empty, loaded — so a screen describes its content once
/// instead of re-deciding the mapping every time.
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
/// It builds *inline*, not as a route: the result is a body, so it can sit
/// inside a [Scaffold] that keeps its app bar while the content is still
/// loading. Wrap it yourself if you want a bare loading route instead.
///
/// **A reload does not blank the screen.** Riverpod keeps the previous data
/// through a refresh, and so does this: once there is something to show, a
/// later loading or error state leaves it on screen rather than replacing a
/// list the user is reading with a spinner. A failed refresh is reported by
/// `listenAction`, which is what one-shot feedback is for.
class AppAsyncView<T> extends StatelessWidget {
  const AppAsyncView({
    super.key,
    required this.value,
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
  });

  /// The state to render — normally `ref.watch(someNotifierProvider)`.
  final AsyncValue<T> value;

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
