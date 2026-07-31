import 'package:moarch/src/templates/ui/drag_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  final output = DragTemplates.appDragSection();

  group('appDragSection', () {
    test('corrects the off-by-one so callers never have to', () {
      // ReorderableListView reports the destination against the list before
      // the dragged item is removed from it.
      expect(
        output,
        contains(
            'final corrected = newIndex > oldIndex ? newIndex - 1 : newIndex;'),
      );
    });

    test('a pinned item is a wall, not merely un-draggable', () {
      expect(
          output, contains('int _clampToPinned(int oldIndex, int newIndex)'));
      expect(output,
          contains('if (!items[i].draggable) {\n        lower = i + 1;'));
      expect(output,
          contains('if (!items[i].draggable) {\n        upper = i - 1;'));
      expect(output, contains('if (newIndex < lower) return lower;'));
      expect(output, contains('if (newIndex > upper) return upper;'));
    });

    test('a pinned item carries no drag listener at all', () {
      expect(output, contains('buildDefaultDragHandles: false,'));
      expect(
        output,
        contains(
            'if (!item.draggable) return KeyedSubtree(key: key, child: content);'),
      );
    });

    test('a move that lands where it started reports nothing', () {
      expect(output, contains('if (target == oldIndex) return;'));
    });

    test('items are keyed on their own id, never on the index', () {
      expect(output, contains('final key = ValueKey<String>(item.id);'));
      expect(output, contains('required this.id,'));
      // Duplicates would animate the wrong child, so they fail loudly.
      expect(
          output,
          contains(
              "items.map((item) => item.id).toSet().length == items.length"));
    });

    test('a long press starts the drag, not a touch', () {
      // An immediate listener over the whole item swallows the scroll.
      expect(
          output,
          contains(
              'AppDragTrigger.longPress => ReorderableDelayedDragStartListener('));
      expect(
          output,
          contains(
              'AppDragTrigger.handle => KeyedSubtree(key: key, child: content),'));
      expect(output, contains('ReorderableDragStartListener('));
    });

    test('an item can be sized by name or by an exact extent', () {
      expect(output,
          contains('final extent = item.extent ?? sizes.resolve(item.size);'));
      expect(output, contains('AppDragSize.fit => null,'));
      expect(output, contains('class AppDragSizes {'));
    });

    test('size means height going down and width going across', () {
      expect(
        output,
        contains('content = orientation == Axis.vertical\n'
            '          ? SizedBox(height: extent, child: content)\n'
            '          : SizedBox(width: extent, child: content);'),
      );
    });

    test('the gap travels with the item rather than leaving a hole', () {
      expect(output, contains('if (!isLast && spacing > 0) {'));
      expect(output, contains('? EdgeInsets.only(bottom: spacing)'));
      expect(output, contains(': EdgeInsets.only(right: spacing),'));
    });

    test('scrolling follows the orientation', () {
      // A vertical section sits in a page that scrolls; a horizontal one has
      // nothing else to scroll it sideways.
      expect(output,
          contains('shrinkWrap: shrinkWrap ?? orientation == Axis.vertical,'));
      expect(
        output,
        contains('physics: physics ??\n'
            '          (orientation == Axis.vertical\n'
            '              ? const NeverScrollableScrollPhysics()\n'
            '              : null),'),
      );
    });

    test('it reports the move rather than owning the list', () {
      expect(
        output,
        contains('final void Function(int oldIndex, int newIndex) onReorder;'),
      );
      expect(
        output,
        contains(
            'static List<T> reorder<T>(List<T> items, int oldIndex, int newIndex)'),
      );
      // No storage, no key, no second copy of the truth.
      expect(output, isNot(contains('storageKey')));
    });

    test('reorder survives an index that is no longer there', () {
      expect(
          output,
          contains(
              'if (oldIndex < 0 || oldIndex >= copy.length) return copy;'));
      expect(output,
          contains('copy.insert(newIndex.clamp(0, copy.length), item);'));
    });

    test('picking an item up is felt, and so is dropping it', () {
      expect(output, contains('HapticFeedback.mediumImpact();'));
      expect(output, contains('HapticFeedback.selectionClick();'));
    });

    test('is in the catalog under Layout & content, needing no package', () {
      final spec =
          WidgetCatalog.all.firstWhere((s) => s.name == 'drag-section');
      expect(spec.file, 'drag/app_drag_section.dart');
      expect(spec.category, 'Layout & content');
      expect(spec.packages, isEmpty);
      expect(spec.deps, ['input-style']);
    });
  });
}
