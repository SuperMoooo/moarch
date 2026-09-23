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

/// Where a screen is, as one value.
///
/// Every state from `moarch create feature` carries one of these, so the four
/// screens a load can be on are named the same way across the whole app and
/// `AppStatusView` can draw them without knowing which feature it is looking
/// at.
///
/// A phase that belongs to one screen alone — submitting, reordering,
/// uploading — is a field on that screen's state, not a value here. Adding one
/// here would ask every other feature to handle a case it will never emit.
enum AppStatus {
  /// Nothing has been asked for yet. The first frame, before the bloc's
  /// `Started` event is handled.
  initial,

  /// A load is in flight and there is nothing on screen to keep.
  ///
  /// A *refresh* over data already shown is not this: leave the status on
  /// [success] and the body stays put instead of collapsing to a skeleton.
  loading,

  /// The screen has what it needs and can draw.
  success,

  /// The load failed. The state's `errorMessage` says why.
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

/// Contract for states usable with [ActionBlocMixin.runAction].
///
/// Every state from `moarch create feature` implements it with one line:
/// `copyWith(status: status, errorMessage: errorMessage)`.
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
  /// Runs [action] with shared loading/error handling.
  ///
  /// Where the screen already is decides what a run looks like:
  ///
  /// - **Nothing on screen yet** (initial, or a retry after a failure): emits
  ///   [AppStatus.loading] first, and a failure lands on [AppStatus.failure] —
  ///   the error screen with its retry button.
  /// - **Data on screen** ([AppStatus.success]): no loading is emitted, so the
  ///   body stays put, and a failure keeps [AppStatus.success] with only
  ///   `errorMessage` set — a toast, not a blank screen. Show an action's
  ///   progress through a field of the screen's own, e.g. `isSubmitting`.
  ///
  /// [action] receives the pre-action state and returns the next one. A first
  /// load has to return it with `status: AppStatus.success`; an action over
  /// loaded data inherits that status from `current`.
  ///
  /// Anything that is not an [AppException] is still shown as a generic
  /// message, and handed to [addError] so `onError` and the `BlocObserver`
  /// see it rather than it vanishing.
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

/// Draws one screen's [AppStatus] as a skeleton, a failure, an empty state or
/// the body.
///
/// ```dart
/// BlocBuilder<HomeBloc, HomeState>(
///   builder: (context, state) => AppStatusView(
///     status: state.status,
///     message: state.errorMessage,
///     onRetry: () => context.read<HomeBloc>().add(const HomeStarted()),
///     isEmpty: state.items.isEmpty,
///     skeleton: (context) => _body(context, HomeState.placeholder),
///     builder: (context) => _body(context, state),
///   ),
/// )
/// ```
///
/// It takes no type parameter and no data: the caller has the state in hand
/// and closes over it, so both builders are plain [WidgetBuilder]s and there
/// is nothing to thread through. It builds inline rather than as a route, so a
/// [Scaffold] keeps its app bar while the content loads.
///
/// **A refresh should not pass [AppStatus.loading].** Doing so trades the body
/// for a skeleton and the screen flickers. Leave the status on
/// [AppStatus.success] and emit the new data when it lands — with one state
/// class per screen the old data is still there to draw, which is the reason
/// the state is shaped that way.
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

  /// Which of the four screens to draw. Usually `state.status`.
  final AppStatus status;

  /// The body, drawn on [AppStatus.success].
  final WidgetBuilder builder;

  /// The shape to shimmer while the first load runs, e.g.
  /// `(context) => _body(context, HomeState.placeholder)`. Null shows a
  /// centered spinner instead.
  ///
  /// It has to be built from *fake* data, not an empty state — Skeletonizer
  /// traces the tree it is handed, so a `ListView.builder` over nothing traces
  /// to a blank screen. States from `moarch create feature` carry a
  /// `placeholder` for exactly this.
  final WidgetBuilder? skeleton;

  /// Whether a loaded screen has nothing worth drawing, e.g.
  /// `state.items.isEmpty`. A plain bool rather than a callback: the caller
  /// already has the state.
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

  /// Passing this is what puts the retry button in [ErrorView]. Usually
  /// re-dispatching the event that loaded the screen.
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
