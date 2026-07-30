import 'package:moarch/src/templates/ui/content_templates.dart';
import 'package:moarch/src/templates/ui/navigation_templates.dart';
import 'package:moarch/src/templates/ui/shared_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('appTabs', () {
    final output = NavigationTemplates.appTabs();

    test('the bar can sit in an app bar', () {
      expect(
        output,
        contains(
            'class AppTabBar extends StatelessWidget implements PreferredSizeWidget'),
      );
      expect(
          output,
          contains(
              'Size get preferredSize => TabBar(tabs: _tabWidgets).preferredSize;'));
    });

    test('measures itself by asking a TabBar with the same tabs', () {
      // A row with icons is taller, and Flutter owns that number — building the
      // tab list once means the bar and its height cannot disagree.
      expect(output, contains('List<Widget> get _tabWidgets => ['));
    });

    test('offers a filled indicator as well as an underline', () {
      expect(output, contains('enum AppTabsStyle { underline, pill }'));
      expect(
          output,
          contains(
              'indicatorSize: pill ? TabBarIndicatorSize.tab : TabBarIndicatorSize.label,'));
      expect(
          output, contains('dividerColor: pill ? Colors.transparent : null,'));
    });

    test('never hands TabBar a zero indicator weight', () {
      // It is ignored once `indicator` is set, but TabBar asserts on it anyway.
      expect(
          output,
          contains(
              'indicatorWeight: AppInputStyle.config.focusedBorderWidth * 2,'));
    });

    test('AppTabs owns the controller, and replaces it when the count changes',
        () {
      expect(
          output,
          contains(
              'class _AppTabsState extends State<AppTabs> with TickerProviderStateMixin'));
      expect(output,
          contains('if (widget.tabs.length != oldWidget.tabs.length) {'));
      expect(
          output,
          contains(
              'previous\n        ..removeListener(_onControllerChanged)\n        ..dispose();'));
    });

    test('reports a settled move once, from a tap or a swipe', () {
      expect(output, contains('if (_controller.indexIsChanging) return;'));
      expect(
          output, contains('if (_controller.index == _reportedIndex) return;'));
    });

    test('a tab list and a view list have to match', () {
      expect(output, contains('widget.tabs.length == widget.children.length,'));
      expect(
          output,
          contains(
              "assert(widget.tabs.isNotEmpty, 'AppTabs: needs at least one tab.');"));
    });

    test('disposes what it made', () {
      expect(
          output,
          contains(
              'void dispose() {\n    _controller\n      ..removeListener(_onControllerChanged)\n      ..dispose();'));
    });
  });

  group('appBottomNav', () {
    final output = SharedTemplates.appBottomNav();

    test('offers four looks, and floating as a separate question', () {
      expect(
        output,
        contains('enum AppBottomNavStyle { material, classic, pill, dot }'),
      );
      // Two knobs rather than one enum naming every combination — so every
      // style can float, including ones added later.
      expect(output, contains('final AppBottomNavStyle style;'));
      expect(output, contains('final bool floating;'));
      expect(
          output, contains('return floating ? _floated(context, bar) : bar;'));
    });

    test('still answers with Material\'s own bar by default', () {
      // Projects generated before the styles existed keep the bar they had.
      expect(output, contains('this.style = AppBottomNavStyle.material,'));
      expect(output, contains('this.floating = false,'));
      expect(
        output,
        contains('final bar = style == AppBottomNavStyle.material\n'
            '        ? _material(context)\n'
            '        : _drawn(context);'),
      );
      expect(output, contains('return NavigationBar('));
    });

    test('a floating bar leaves the surface and the shadow to its card', () {
      // Two edges inside one rounded corner is what painting both would give.
      expect(
        output,
        contains("backgroundColor:\n"
            "          floating ? Colors.transparent : context.colorScheme.surface,"),
      );
      expect(output, contains('elevation: floating ? 0 : null,'));
      expect(output, contains('if (floating) return row;'));
    });

    test('the inset is spent once, by whichever layer owns the edge', () {
      // Attached, the bar insets itself; floating, the card's margin is the
      // inset and NavigationBar's own SafeArea has to be taken back off.
      expect(output, contains('child: SafeArea(top: false, child: row),'));
      expect(output, contains('MediaQuery.removePadding('));
      expect(output, contains('removeBottom: true,'));
      expect(output,
          contains('bottom: inset > 0 ? inset : AppConstants.space16,'));
    });

    test('only the pill is sized by what is in it', () {
      // The other two divide the width; a pill that stretched to an even share
      // would not be a pill.
      expect(
          output,
          contains('if (style != AppBottomNavStyle.pill)\n'
              '              Expanded(child: _item(i))'));
      expect(
          output,
          contains('else if (i == index)\n'
              '              Flexible(child: _item(i))'));
      expect(output, contains('widthFactor: 1,'));
    });

    test('the open pill draws its icon on the accent, not in it', () {
      expect(
        output,
        contains('final selectedColor =\n'
            '        pill ? AppInputStyle.onAccentOf(context, variant) : accent;'),
      );
    });

    test('an icon-only destination is still named, and named once', () {
      // Two of the four styles never draw the label.
      expect(output, contains('label: destination.label,'));
      expect(output, contains('child: ExcludeSemantics(child: content),'));
      expect(output, contains('return MergeSemantics('));
      expect(output, contains('Widget _tooltipped({required Widget child}) {'));
      expect(output, contains('if (labelled) return child;'));
    });

    test('reduce motion reaches the same layouts', () {
      expect(
        output,
        contains('final duration = MediaQuery.disableAnimationsOf(context)\n'
            '        ? Duration.zero\n'
            '        : AppConstants.duration200;'),
      );
    });

    test('the dot keeps its room whether or not it is drawn', () {
      // Otherwise the icons hop as the selection moves.
      expect(output,
          contains('width: _dotSize,\n              height: _dotSize,'));
      expect(output, contains('opacity: selected ? 1 : 0,'));
    });

    test('a bar that cannot navigate is caught, not drawn', () {
      expect(output, contains('destinations.length >= 2,'));
      expect(output, contains('index >= 0 && index < destinations.length,'));
    });

    test('reads the kit\'s accent rather than reaching for primary', () {
      expect(output, contains("import '../inputs/app_input_style.dart';"));
      expect(output, contains('AppInputStyle.accentOf(context, variant)'));
      expect(output, isNot(contains('colorScheme.primary.withValues')));
    });
  });

  group('appDrawer', () {
    final output = NavigationTemplates.appDrawer();

    test('reads the bottom bar\'s destinations', () {
      expect(output, contains("import './app_bottom_nav.dart';"));
      expect(output, contains('final List<AppNavDestination> destinations;'));
    });

    test('closes itself after a pick', () {
      expect(output, contains('void _dismiss(BuildContext context) {'));
      expect(output, contains('if (scaffold.isDrawerOpen) {'));
      expect(output, contains('} else if (scaffold.isEndDrawerOpen) {'));
      expect(output, contains('_dismiss(context);'));
    });

    test('does nothing when it is pinned beside the content instead', () {
      expect(output, contains('final scaffold = Scaffold.maybeOf(context);'));
      expect(output, contains('if (scaffold == null) return;'));
    });

    test('a header does not shift the selected index', () {
      expect(output, contains('header ?? const SizedBox.shrink(),'));
      expect(output, contains('selectedIndex: selectedIndex,'));
    });

    test('a header without a leading widget starts with no gap', () {
      expect(output, contains('if (leading != null) ...['));
      expect(output, contains('const SizedBox(width: AppConstants.space12),'));
    });

    test('ships the common header rather than only a slot for one', () {
      expect(output, contains('class AppDrawerHeader extends StatelessWidget'));
      expect(output, contains('MediaQuery.paddingOf(context).top'));
    });
  });

  group('appNavRail', () {
    final output = NavigationTemplates.appNavRail();

    test('reads the same destinations as the bottom bar', () {
      expect(output, contains("import './app_bottom_nav.dart';"));
      expect(output, contains('NavigationRailDestination('));
    });

    test('does not ask an extended rail for labels as well', () {
      // NavigationRail asserts on exactly that combination.
      expect(
          output,
          contains(
              'labelType: extended ? null : NavigationRailLabelType.all,'));
    });

    test('AppAdaptiveNav switches on the short-side breakpoint', () {
      expect(output, contains('class AppAdaptiveNav extends StatelessWidget'));
      expect(output, contains('final wide = context.isTablet;'));
      expect(output, contains('body: wide'));
      expect(output, contains('bottomNavigationBar: wide\n          ? null'));
      expect(output, contains('AppBottomNav('));
    });

    test('AppAdaptiveNav hands the phone layout its bar\'s looks', () {
      expect(output,
          contains('this.bottomNavStyle = AppBottomNavStyle.material,'));
      expect(output, contains('this.floatingBottomNav = false,'));
      expect(output, contains('style: bottomNavStyle,'));
      expect(output, contains('floating: floatingBottomNav,'));
      // The bar took a variant before the rail did not pass it one.
      expect(output, contains('variant: variant,'));
    });

    test('a floating bar gets a body that runs under it', () {
      // Without this the body stops at the top of the card's margin.
      expect(output, contains('extendBody: !wide && floatingBottomNav,'));
    });
  });

  group('appFab', () {
    final output = SharedTemplates.appFab();

    test('wears AppButton\'s vocabulary rather than one of its own', () {
      expect(output, contains("import './app_button.dart';"));
      expect(output, contains('final AppButtonVariant variant;'));
      expect(output, contains('final AppButtonType type;'));
      expect(output, isNot(contains('enum AppFabVariant')));
    });

    test('is circular or extended off one parameter', () {
      expect(output, contains('final resolvedLabel = label;'));
      expect(output, contains('if (resolvedLabel == null) {'));
      expect(output, contains('return FloatingActionButton.extended('));
    });

    test('a loading FAB keeps its size and stops its taps', () {
      expect(
          output, contains('final enabled = !isLoading && onPressed != null;'));
      expect(output, contains('CircularProgressIndicator('));
      expect(output, contains('onPressed: enabled ? handlePress : null,'));
    });

    test('exposes the hero tag two FABs on one screen need', () {
      expect(output, contains('final Object? heroTag;'));
      expect(output, contains('heroTag: heroTag,'));
    });
  });

  group('appTimeline', () {
    final output = ContentTemplates.appTimeline();

    test('draws where an entry stands, not just that it exists', () {
      expect(
        output,
        contains('enum AppTimelineStatus { done, current, pending, failed }'),
      );
      expect(output,
          contains('AppTimelineStatus.failed => context.colorScheme.error,'));
      expect(
          output,
          contains(
              'final hollow = entry.status == AppTimelineStatus.pending;'));
      expect(
          output,
          contains(
              'final ringed = entry.status == AppTimelineStatus.current;'));
    });

    test('the connector reaches the next node', () {
      expect(output, contains('return IntrinsicHeight('));
      expect(
          output, contains('crossAxisAlignment: CrossAxisAlignment.stretch,'));
      expect(output, contains('if (!isLast)'));
      expect(output, contains('Expanded('));
    });

    test('the last node has nothing to join', () {
      expect(output, contains('isLast: i == entries.length - 1,'));
    });

    test('offers one row for a caller with its own lazy list', () {
      expect(output, contains('static Widget entryBuilder('));
      expect(output, contains('required bool isLast,'));
    });

    test('takes the timestamp already formatted', () {
      // The timeline does not decide how an app writes its times.
      expect(output, contains('final String? timestamp;'));
      expect(output, isNot(contains('DateTime')));
    });
  });

  group('appCarousel', () {
    final output = ContentTemplates.appCarousel();

    test('stops auto-advancing for good once the user swipes', () {
      expect(output, contains('bool _userTookOver = false;'));
      expect(output,
          contains('if (notification.dragDetails != null) _onUserScroll();'));
      expect(
          output, contains('if (interval == null || _userTookOver) return;'));
    });

    test('never starts under reduce-motion', () {
      expect(output,
          contains('if (MediaQuery.disableAnimationsOf(context)) return;'));
      expect(output, contains('void didChangeDependencies() {'));
    });

    test('does not animate a single page', () {
      expect(output, contains('if (widget.children.length < 2) return;'));
    });

    test('wraps by animating back rather than jumping', () {
      expect(output, contains('if (next >= widget.children.length) {'));
      expect(output, contains('_controller.animateToPage('));
    });

    test('cancels its timer and controller', () {
      expect(output, contains('_timer?.cancel();\n    _controller.dispose();'));
    });

    test('the dots are usable on their own', () {
      expect(output, contains('class AppCarouselDots extends StatelessWidget'));
      expect(
          output,
          contains(
              'width: i == index ? AppConstants.space24 : AppConstants.space8,'));
    });
  });

  group('the catalog', () {
    test('files the three navigation widgets under Navigation', () {
      for (final name in ['tabs', 'drawer', 'nav-rail']) {
        final spec = WidgetCatalog.byName(name);
        expect(spec, isNotNull, reason: '$name is missing from the catalog');
        expect(spec!.category, 'Navigation');
        expect(spec.file, startsWith('navigation/'));
      }
    });

    test('the drawer and the rail pull in the destination type they share', () {
      for (final name in ['drawer', 'nav-rail']) {
        expect(WidgetCatalog.byName(name)!.deps, contains('bottom-nav'));
      }
    });

    test('the bar pulls in the accent it now reads', () {
      expect(WidgetCatalog.byName('bottom-nav')!.deps, contains('input-style'));
    });

    test('the fab sits with the buttons and pulls in their vocabulary', () {
      final spec = WidgetCatalog.byName('fab')!;
      expect(spec.category, 'Buttons & icons');
      expect(spec.file, 'buttons/app_fab.dart');
      expect(spec.deps, contains('button'));
    });

    test('the timeline and the carousel are catalogued where they belong', () {
      expect(WidgetCatalog.byName('timeline')!.category, 'Layout & content');
      expect(WidgetCatalog.byName('timeline')!.file, 'lists/app_timeline.dart');
      expect(WidgetCatalog.byName('carousel')!.category, 'Media');
      expect(WidgetCatalog.byName('carousel')!.file, 'media/app_carousel.dart');
    });

    test('none of them cost a pub package', () {
      for (final name in [
        'tabs',
        'drawer',
        'nav-rail',
        'fab',
        'timeline',
        'carousel',
      ]) {
        expect(WidgetCatalog.byName(name)!.packages, isEmpty, reason: name);
      }
    });
  });
}
