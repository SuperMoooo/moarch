/// Templates for the bloc stack's status → loading/error/empty/body mapping.
///
/// The counterpart to `templates/riverpod/async_templates.dart`: the same four
/// screens, reached from a status field on the state rather than from an
/// `AsyncValue`. Riverpod's version has to be generic because `AsyncValue<T>`
/// carries the data; this one does not, because the caller already holds the
/// state and closes over it.
class AsyncTemplates {
  AsyncTemplates._();

  /// Returns the generated appStatus template — `core/utils/app_status.dart`.
  ///
  /// One enum for every screen rather than one per feature. That is what lets
  /// [appStatusView] exist at all: a widget cannot switch over an enum it does
  /// not know the type of.
  ///
  /// It also carries `StatusState` and `ActionBlocMixin` — bloc's `runAction`,
  /// the counterpart to Riverpod's `ActionNotifierMixin`. They sit beside the
  /// enum because the helper's whole job is choosing which [AppStatus] a
  /// failure lands on.
  static String appStatus() => r'''
import 'package:bloc/bloc.dart';

import '../errors/app_exception.dart';

/// Where a screen's load is. Shared by every screen so `AppStatusView` can
/// draw it; a phase one screen alone has (submitting…) is a field on its state.
enum AppStatus {
  /// Nothing asked for yet.
  initial,

  /// A first load is in flight. A refresh over shown data stays on [success].
  loading,

  /// The screen has what it needs.
  success,

  /// The load failed; the state's `errorMessage` says why.
  failure;

  /// Whether nothing has been asked for yet.
  bool get isInitial => this == AppStatus.initial;

  /// Whether a first load is in flight.
  bool get isLoading => this == AppStatus.loading;

  /// Whether the screen has what it needs.
  bool get isSuccess => this == AppStatus.success;

  /// Whether the last load failed.
  bool get isFailure => this == AppStatus.failure;
}

/// A state [ActionBlocMixin.runAction] can move between statuses.
abstract interface class StatusState<S> {
  AppStatus get status;
  S withStatus(AppStatus status, {String? errorMessage});
}

/// Shared loading/error handling for bloc event handlers.
///
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState>
///     with ActionBlocMixin<MyEvent, MyState> {
///   Future<void> _onSaved(MySaved event, Emitter<MyState> emit) =>
///       runAction(emit, (current) async {
///         await _repo.save(event.item);
///         return current.copyWith(successMessage: 'Saved');
///       });
/// }
/// ```
mixin ActionBlocMixin<E, S extends StatusState<S>> on Bloc<E, S> {
  /// Runs [action], which gets the current state and returns the next one.
  ///
  /// - Nothing on screen yet: emits [AppStatus.loading] first, and a failure
  ///   lands on [AppStatus.failure]. A first load returns `status: success`.
  /// - Data on screen: no loading is emitted, and a failure stays on
  ///   [AppStatus.success] with only `errorMessage` set (a toast).
  ///
  /// Errors that are not an [AppException] show a generic message and go to
  /// [addError].
  Future<void> runAction(
    Emitter<S> emit,
    Future<S> Function(S current) action,
  ) async {
    final current = state;
    final loaded = current.status.isSuccess;
    if (!loaded) emit(current.withStatus(AppStatus.loading));
    final failed = loaded ? AppStatus.success : AppStatus.failure;
    try {
      emit(await action(current));
    } on AppException catch (e) {
      emit(current.withStatus(failed, errorMessage: e.message));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(current.withStatus(failed, errorMessage: 'Unknown error'));
    }
  }
}
''';

  /// Returns the generated appStatusView template.
  ///
  /// The whole point of it: a generated view's `builder` becomes one call
  /// instead of a `switch` whose arms are the same three shells in every
  /// feature anyone will ever scaffold.
  static String appStatusView() => r'''
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import './empty_view.dart';
import './error_view.dart';
import '../../core/utils/app_status.dart';

/// Draws a screen's [AppStatus] as a skeleton, a failure, an empty state or
/// the body.
///
/// ```dart
/// AppStatusView(
///   status: state.status,
///   message: state.errorMessage,
///   onRetry: () => context.read<HomeBloc>().add(const HomeStarted()),
///   isEmpty: state.items.isEmpty,
///   skeleton: (context) => const HomeSkeleton(),
///   builder: (context) => _body(context, state),
/// )
/// ```
///
/// A refresh should stay on [AppStatus.success], or the body flickers to the
/// skeleton.
class AppStatusView extends StatelessWidget {
  /// Creates the shell around a screen's [builder].
  const AppStatusView({
    super.key,
    required this.status,
    required this.builder,
    this.skeleton,
    this.isEmpty = false,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.errorTitle,
    this.message,
    this.onRetry,
  });

  /// Which screen to draw. Usually `state.status`.
  final AppStatus status;

  /// The body, drawn on [AppStatus.success].
  final WidgetBuilder builder;

  /// Shimmered while the first load runs. Null shows a spinner.
  final WidgetBuilder? skeleton;

  /// Whether a loaded screen has nothing to draw, e.g. `state.items.isEmpty`.
  final bool isEmpty;

  /// Copy for the empty state. Null keeps [EmptyView]'s own wording.
  final String? emptyTitle;
  final String? emptyMessage;
  final IconData? emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Copy for the failed state. [message] is the state's `errorMessage`.
  final String? errorTitle;
  final String? message;

  /// Shows a retry button on failure. Usually re-dispatches the load event.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      AppStatus.initial || AppStatus.loading => _loading(context),
      AppStatus.failure => ErrorView(
          title: errorTitle ?? 'Something went wrong',
          message: message,
          onRetry: onRetry,
        ),
      AppStatus.success when isEmpty => EmptyView(
          title: emptyTitle ?? 'Nothing here yet',
          message: emptyMessage ?? 'No items are available right now.',
          icon: emptyIcon ?? Icons.inbox_outlined,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
        ),
      AppStatus.success => builder(context),
    };
  }

  Widget _loading(BuildContext context) {
    final shape = skeleton;
    if (shape == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    return Skeletonizer(child: shape(context));
  }
}
''';
}
