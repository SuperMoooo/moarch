/// Templates for the drag family: a section whose children can be reordered.
abstract final class DragTemplates {
  /// Returns the generated appDragSection template.
  static String appDragSection() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';

/// How big an item is along the section's own axis — its height in a vertical
/// section, its width in a horizontal one.
///
/// [fit] lets the child size itself, which is what most rows want. The three
/// named sizes come from [AppDragSizes], so one section can hold a tall card
/// and a short one without either hard-coding a number.
enum AppDragSize { fit, small, medium, large }

/// What the three named [AppDragSize]s measure, in logical pixels.
///
/// Pass one to [AppDragSection.sizes] to retune a whole section at once
/// instead of an extent per item.
class AppDragSizes {
  const AppDragSizes({
    this.small = 88,
    this.medium = 140,
    this.large = 220,
  });

  final double small;
  final double medium;
  final double large;

  /// The extent for [size], or null when the child sizes itself.
  double? resolve(AppDragSize size) => switch (size) {
        AppDragSize.fit => null,
        AppDragSize.small => small,
        AppDragSize.medium => medium,
        AppDragSize.large => large,
      };
}

/// What starts a drag.
enum AppDragTrigger {
  /// Press and hold anywhere on the item. The right default on a phone: an
  /// immediate drag on the item's whole surface would fight the scroll.
  longPress,

  /// A grip on the item's trailing edge, which drags the moment it is
  /// touched. Choose it when the item is itself tappable and a long press
  /// already means something else.
  handle,
}

/// One child of an [AppDragSection].
class AppDragItem {
  const AppDragItem({
    required this.id,
    required this.child,
    this.draggable = true,
    this.size = AppDragSize.fit,
    this.extent,
  });

  /// Stable across rebuilds and unique within the section — it becomes the
  /// child's key, which is what lets the list animate the *item* rather than
  /// the position. An index would move the animation to whatever now sits
  /// there.
  final String id;

  final Widget child;

  /// A pinned item: it cannot be picked up, and nothing can be dragged past
  /// it. A header, a total, an "add" tile at the end.
  final bool draggable;

  final AppDragSize size;

  /// An exact extent, overriding [size]. For the one item that does not fit
  /// the section's three sizes.
  final double? extent;
}

/// A section whose children can be dragged into a new order.
///
/// ```dart
/// AppDragSection(
///   items: [
///     for (final card in _cards)
///       AppDragItem(id: card.id, child: DashboardCard(card)),
///   ],
///   onReorder: (from, to) => setState(
///     () => _cards = AppDragSection.reorder(_cards, from, to),
///   ),
/// )
/// ```
///
/// It reports the move and nothing else — the list stays yours, so it can
/// come from a notifier, be saved to storage, or be sent to a server without
/// this widget holding a second copy of the truth. [reorder] does the
/// remove-and-insert for you.
///
/// Items declare their own size and whether they can be moved:
///
/// ```dart
/// AppDragSection(
///   orientation: Axis.horizontal,
///   items: [
///     AppDragItem(id: 'a', size: AppDragSize.large, child: ChartCard()),
///     AppDragItem(id: 'b', size: AppDragSize.small, child: TotalCard()),
///     AppDragItem(id: 'new', draggable: false, child: AddTile()),
///   ],
///   onReorder: _move,
/// )
/// ```
///
/// A pinned item is not merely un-draggable: **nothing can be dropped past
/// it**. It keeps its index, so the "add" tile above stays at the end however
/// the rest are shuffled.
///
/// A **vertical** section shrink-wraps and does not scroll, so it drops into a
/// page that already scrolls; give it [physics] to make it the scrolling thing
/// itself. A **horizontal** one scrolls sideways on its own — nothing else is
/// going to — and needs a bounded height from its parent, so put it in a
/// `SizedBox` or give its items an extent.
class AppDragSection extends StatelessWidget {
  const AppDragSection({
    super.key,
    required this.items,
    required this.onReorder,
    this.orientation = Axis.vertical,
    this.trigger = AppDragTrigger.longPress,
    this.sizes = const AppDragSizes(),
    this.spacing = AppConstants.space8,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap,
    this.physics,
    this.scrollController,
    this.onReorderStart,
    this.onReorderEnd,
    this.handleIcon = Icons.drag_indicator,
    this.variant,
  });

  final List<AppDragItem> items;

  /// Called with the item's old and new index, already corrected for the
  /// pinned items in the way. Apply it with [reorder].
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Vertical stacks the items; horizontal lays them in a row that scrolls
  /// sideways.
  final Axis orientation;

  final AppDragTrigger trigger;
  final AppDragSizes sizes;

  /// The gap between items. It travels inside each item, so it moves with the
  /// one being dragged rather than leaving a hole behind.
  final double spacing;

  final EdgeInsetsGeometry padding;

  /// Null follows the orientation: a vertical section shrink-wraps so it can
  /// sit in a page, a horizontal one does not so it can fill the width it is
  /// given.
  final bool? shrinkWrap;

  /// Null follows the orientation too — a vertical section does not scroll
  /// (the page it is in does), a horizontal one scrolls itself, because
  /// nothing else is going to scroll it sideways.
  final ScrollPhysics? physics;

  final ScrollController? scrollController;

  final VoidCallback? onReorderStart;
  final VoidCallback? onReorderEnd;

  /// Only drawn for [AppDragTrigger.handle].
  final IconData handleIcon;

  /// Tints the drag handle. Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  static const double _liftScale = 0.04;
  static const double _liftElevation = 8;

  /// Moves the item at [oldIndex] to [newIndex], returning a new list.
  ///
  /// The remove-and-insert every caller of [onReorder] would otherwise write
  /// out, and the place the off-by-one lives if it is written out wrong.
  static List<T> reorder<T>(List<T> items, int oldIndex, int newIndex) {
    final copy = List<T>.of(items);
    if (oldIndex < 0 || oldIndex >= copy.length) return copy;
    final item = copy.removeAt(oldIndex);
    copy.insert(newIndex.clamp(0, copy.length), item);
    return copy;
  }

  /// How far the item at [oldIndex] is allowed to travel.
  ///
  /// A pinned item keeps its index, so it is a wall: an item may move freely
  /// within the run of movable slots it sits in, and no further. Without this
  /// a drop past a pinned item would silently push it along.
  int _clampToPinned(int oldIndex, int newIndex) {
    var lower = 0;
    for (var i = oldIndex - 1; i >= 0; i--) {
      if (!items[i].draggable) {
        lower = i + 1;
        break;
      }
    }

    var upper = items.length - 1;
    for (var i = oldIndex + 1; i < items.length; i++) {
      if (!items[i].draggable) {
        upper = i - 1;
        break;
      }
    }

    if (newIndex < lower) return lower;
    if (newIndex > upper) return upper;
    return newIndex;
  }

  void _handleReorder(int oldIndex, int newIndex) {
    // ReorderableListView reports the destination against the list *before*
    // the dragged item is taken out of it, so a downward move arrives one too
    // high. Every caller would otherwise have to know that.
    final corrected = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final target = _clampToPinned(oldIndex, corrected);
    if (target == oldIndex) return;
    HapticFeedback.selectionClick();
    onReorder(oldIndex, target);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      items.map((item) => item.id).toSet().length == items.length,
      'AppDragSection needs a unique id per item — duplicates make the list '
      'animate the wrong child.',
    );

    return ReorderableListView.builder(
      itemCount: items.length,
      scrollDirection: orientation,
      shrinkWrap: shrinkWrap ?? orientation == Axis.vertical,
      physics: physics ??
          (orientation == Axis.vertical
              ? const NeverScrollableScrollPhysics()
              : null),
      scrollController: scrollController,
      padding: padding,
      // The listeners are attached per item instead, so a pinned one has none
      // and cannot be picked up at all.
      buildDefaultDragHandles: false,
      onReorder: _handleReorder,
      onReorderStart: (_) {
        HapticFeedback.mediumImpact();
        onReorderStart?.call();
      },
      onReorderEnd: (_) => onReorderEnd?.call(),
      proxyDecorator: _lifted,
      itemBuilder: (context, index) => _item(context, index),
    );
  }

  Widget _item(BuildContext context, int index) {
    final item = items[index];
    final extent = item.extent ?? sizes.resolve(item.size);
    final isLast = index == items.length - 1;

    Widget content = item.child;

    if (trigger == AppDragTrigger.handle && item.draggable) {
      content = Row(
        children: [
          Expanded(child: content),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.space8),
              child: Icon(
                handleIcon,
                color: AppInputStyle.accentOf(context, variant),
              ),
            ),
          ),
        ],
      );
    }

    if (extent != null) {
      content = orientation == Axis.vertical
          ? SizedBox(height: extent, child: content)
          : SizedBox(width: extent, child: content);
    }

    // Inside the keyed child, so the gap travels with the item rather than
    // staying behind as a hole in the list.
    if (!isLast && spacing > 0) {
      content = Padding(
        padding: orientation == Axis.vertical
            ? EdgeInsets.only(bottom: spacing)
            : EdgeInsets.only(right: spacing),
        child: content,
      );
    }

    final key = ValueKey<String>(item.id);

    if (!item.draggable) return KeyedSubtree(key: key, child: content);

    return switch (trigger) {
      // The whole surface drags, after a hold — an immediate listener here
      // would swallow the scroll.
      AppDragTrigger.longPress => ReorderableDelayedDragStartListener(
          key: key,
          index: index,
          child: content,
        ),
      // The grip is already wrapped above; this keeps the rest of the item
      // tappable.
      AppDragTrigger.handle => KeyedSubtree(key: key, child: content),
    };
  }

  /// The lifted look while an item is in flight: a touch bigger, with a
  /// shadow under it.
  Widget _lifted(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(animation.value);
        return Transform.scale(
          scale: 1 + _liftScale * t,
          child: Material(
            color: Colors.transparent,
            elevation: _liftElevation * t,
            borderRadius: AppConstants.borderRadius12,
            child: child,
          ),
        );
      },
    );
  }
}
''';
}
