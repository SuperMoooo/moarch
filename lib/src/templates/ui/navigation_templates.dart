/// Templates for the navigation shells: tabs, the drawer, and the rail a wide
/// screen shows instead of a bottom bar.
class NavigationTemplates {
  /// Returns the generated appTabs template.
  static String appTabs() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// One tab in an [AppTabBar].
class AppTab {
  const AppTab({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// How the current tab is marked.
///
/// - [underline]: a line under the selected label (Material's own).
/// - [pill]: the selected tab is filled with the accent, like [AppSegmented].
enum AppTabsStyle { underline, pill }

/// A [TabBar] wearing the kit's vocabulary, sized to sit in an app bar.
///
/// Being a [PreferredSizeWidget] is the point — it drops straight into the
/// `bottom` slot of [AppAppBar], which is where a tab bar belongs:
///
/// ```dart
/// DefaultTabController(
///   length: 2,
///   child: Scaffold(
///     appBar: AppAppBar(
///       title: 'Orders',
///       bottom: const AppTabBar(
///         tabs: [AppTab(label: 'Open'), AppTab(label: 'Closed')],
///       ),
///     ),
///     body: const TabBarView(children: [...]),
///   ),
/// )
/// ```
///
/// With no [controller] it reads the [DefaultTabController] above it, as
/// [TabBar] does. [AppTabs] is the version that owns a controller for you and
/// puts the views underneath.
class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.onTap,
    this.style = AppTabsStyle.underline,
    this.isScrollable = false,
    this.variant,
  });

  final List<AppTab> tabs;

  /// Null falls back to the [DefaultTabController] above this widget.
  final TabController? controller;

  /// Fires on a tap, not on a swipe between views — listen to the controller
  /// if you need both.
  final ValueChanged<int>? onTap;

  final AppTabsStyle style;

  /// Lets the row scroll instead of dividing the width evenly. What more than
  /// about four tabs needs, and what any tab with a long label needs.
  final bool isScrollable;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  /// The [Tab] widgets, built once so the bar and [preferredSize] can never
  /// disagree about what is in it.
  List<Widget> get _tabWidgets => [
    for (final tab in tabs)
      Tab(text: tab.label, icon: tab.icon == null ? null : Icon(tab.icon)),
  ];

  /// Measured by asking a bare [TabBar] holding the same tabs, so a row with
  /// icons gets the taller bar Material specifies — and keeps getting the right
  /// answer if those metrics ever change.
  @override
  Size get preferredSize => TabBar(tabs: _tabWidgets).preferredSize;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    final onAccent = AppInputStyle.onAccentOf(context, variant);
    final pill = style == AppTabsStyle.pill;

    return TabBar(
      controller: controller,
      isScrollable: isScrollable,
      tabs: _tabWidgets,
      onTap: onTap == null
          ? null
          : (index) {
              HapticFeedback.selectionClick();
              onTap!(index);
            },
      // A filled indicator has to cover the whole tab for the label to read on
      // top of it; an underline is drawn under the label only.
      indicatorSize: pill ? TabBarIndicatorSize.tab : TabBarIndicatorSize.label,
      indicator: pill
          ? BoxDecoration(
              color: accent,
              borderRadius: AppConstants.borderRadiusFull,
            )
          : null,
      indicatorColor: pill ? null : accent,
      // Ignored once `indicator` is set, but TabBar asserts it is positive
      // either way — so the pill branch cannot answer 0.
      indicatorWeight: AppInputStyle.config.focusedBorderWidth * 2,
      labelColor: pill ? onAccent : accent,
      unselectedLabelColor: context.colorScheme.onSurfaceVariant,
      labelStyle: context.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: context.textTheme.titleSmall,
      // The pill carries its own edge; Material's divider under the row only
      // makes sense beneath an underline.
      dividerColor: pill ? Colors.transparent : null,
      splashBorderRadius: AppConstants.borderRadiusFull,
    );
  }
}

/// An [AppTabBar] with its views under it, owning the [TabController].
///
/// The bar-plus-views pairing is most of what a tab bar is used for, and doing
/// it by hand means a [StatefulWidget], a ticker and a `dispose` every time:
///
/// ```dart
/// AppTabs(
///   tabs: const [AppTab(label: 'Open'), AppTab(label: 'Closed')],
///   children: [OpenOrders(), ClosedOrders()],
/// )
/// ```
///
/// It fills the height it is given, so put it in a [Column] under an
/// [Expanded], or hand it a body's worth of space directly. When the tab bar
/// belongs in the app bar instead, use [AppTabBar] with a
/// [DefaultTabController].
class AppTabs extends StatefulWidget {
  const AppTabs({
    super.key,
    required this.tabs,
    required this.children,
    this.initialIndex = 0,
    this.onChanged,
    this.style = AppTabsStyle.underline,
    this.isScrollable = false,
    this.variant,
    this.padding,
  });

  final List<AppTab> tabs;

  /// One view per tab — a different count is a bug, not a layout to guess at.
  final List<Widget> children;

  final int initialIndex;

  /// Fires for a tap *and* for a swipe, once the move has settled.
  final ValueChanged<int>? onChanged;

  final AppTabsStyle style;
  final bool isScrollable;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  /// Inset around the bar. Null is none — the bar spans the full width, as it
  /// does in an app bar.
  final EdgeInsetsGeometry? padding;

  @override
  State<AppTabs> createState() => _AppTabsState();
}

class _AppTabsState extends State<AppTabs> with TickerProviderStateMixin {
  late TabController _controller;

  /// What [AppTabs.onChanged] last reported, so a settled swipe fires once
  /// rather than on every frame of the animation.
  late int _reportedIndex;

  @override
  void initState() {
    super.initState();
    assert(widget.tabs.isNotEmpty, 'AppTabs: needs at least one tab.');
    _reportedIndex = widget.initialIndex;
    _controller = _createController();
  }

  @override
  void didUpdateWidget(AppTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A TabController's length is fixed, so a tab list that grew or shrank
    // needs a new one — otherwise the bar asserts on the next build.
    if (widget.tabs.length != oldWidget.tabs.length) {
      final previous = _controller;
      _controller = _createController(
        index: previous.index.clamp(0, widget.tabs.length - 1),
      );
      previous
        ..removeListener(_onControllerChanged)
        ..dispose();
    }
  }

  TabController _createController({int? index}) {
    return TabController(
      length: widget.tabs.length,
      initialIndex: index ?? widget.initialIndex.clamp(0, widget.tabs.length - 1),
      vsync: this,
    )..addListener(_onControllerChanged);
  }

  /// Reports the tab the user landed on. `indexIsChanging` is still true while
  /// a tap animates, and the index is already the destination — so waiting for
  /// it to clear reports the move once, whether it came from a tap or a swipe.
  void _onControllerChanged() {
    if (_controller.indexIsChanging) return;
    if (_controller.index == _reportedIndex) return;
    _reportedIndex = _controller.index;
    widget.onChanged?.call(_controller.index);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.tabs.length == widget.children.length,
      'AppTabs: ${widget.tabs.length} tabs but ${widget.children.length} '
      'children — every tab needs exactly one view.',
    );

    final bar = AppTabBar(
      tabs: widget.tabs,
      controller: _controller,
      style: widget.style,
      isScrollable: widget.isScrollable,
      variant: widget.variant,
    );

    return Column(
      children: [
        widget.padding == null
            ? bar
            : Padding(padding: widget.padding!, child: bar),
        Expanded(
          child: TabBarView(controller: _controller, children: widget.children),
        ),
      ],
    );
  }
}
''';

  /// Returns the generated appDrawer template.
  static String appDrawer() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_bottom_nav.dart';
import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// The side menu, reading the same [AppNavDestination] list as [AppBottomNav]
/// so a phone and a tablet describe their navigation once.
///
/// ```dart
/// Scaffold(
///   drawer: AppDrawer(
///     destinations: destinations,
///     selectedIndex: index,
///     onDestinationSelected: _go,
///     header: const AppDrawerHeader(title: 'Acme', subtitle: 'Signed in'),
///   ),
///   ...
/// )
/// ```
///
/// It closes itself after a pick. A drawer that stays open over the screen it
/// just navigated to is the most common way this widget is got wrong, and there
/// is no case where a modal drawer should survive its own selection.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.header,
    this.footer,
    this.variant,
  });

  final List<AppNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Shown above the destinations — an [AppDrawerHeader], a logo, an account
  /// row. It is not a destination and does not shift the selected index.
  final Widget? header;

  /// Shown under the destinations — a sign-out row, a version string.
  final Widget? footer;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  /// Closes the drawer if this one is open as a drawer at all — on a wide
  /// layout the same widget may be pinned beside the content, where there is
  /// nothing to close.
  void _dismiss(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold == null) return;
    if (scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    } else if (scaffold.isEndDrawerOpen) {
      scaffold.closeEndDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      backgroundColor: context.colorScheme.surface,
      indicatorColor: accent.withValues(alpha: AppInputStyle.config.fillOpacity * 2),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: AppConstants.borderRadiusFull,
      ),
      onDestinationSelected: (index) {
        HapticFeedback.selectionClick();
        _dismiss(context);
        onDestinationSelected(index);
      },
      children: [
        // NavigationDrawer counts only its NavigationDrawerDestination
        // children, so a header, a divider or a footer can sit among them
        // without throwing the selected index off.
        //
        // An empty box rather than a null-aware element: this file has to
        // compile in a project whose pubspec still asks for an older Dart.
        header ?? const SizedBox.shrink(),
        for (final destination in destinations)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon, color: accent),
            label: Text(destination.label),
          ),
        if (footer != null) ...[
          const Padding(
            padding: AppConstants.paddingV8,
            child: Divider(height: 1),
          ),
          footer!,
        ],
      ],
    );
  }
}

/// A title-and-subtitle block for the top of an [AppDrawer]. Pass anything else
/// you like as [AppDrawer.header] — this is only the common case.
class AppDrawerHeader extends StatelessWidget {
  const AppDrawerHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Clears the status bar without a SafeArea: the drawer starts at the top
      // of the screen, and NavigationDrawer does not inset its children.
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + AppConstants.space16,
        left: AppConstants.space24,
        right: AppConstants.space16,
        bottom: AppConstants.space16,
      ),
      child: Row(
        children: [
          // The gap travels with the leading widget, so a header without one
          // does not start with 12px of nothing.
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppConstants.space12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
''';

  /// Returns the generated appNavRail template.
  static String appNavRail() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_bottom_nav.dart';
import '../inputs/app_input_style.dart';
import '../../../core/utils/extensions.dart';

/// The vertical navigation a wide screen shows instead of a bottom bar, reading
/// the same [AppNavDestination] list as [AppBottomNav].
///
/// A bottom bar on a tablet puts the app's navigation as far from the hand as
/// the layout allows, which is why Material asks for a rail past 600dp.
/// [AppAdaptiveNav] makes that switch for you.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    super.key,
    required this.destinations,
    required this.index,
    required this.onDestinationSelected,
    this.extended = false,
    this.leading,
    this.trailing,
    this.variant,
  });

  final List<AppNavDestination> destinations;
  final int index;
  final ValueChanged<int> onDestinationSelected;

  /// Shows the labels beside the icons rather than under them — for a window
  /// wide enough that a narrow rail would be wasting the space.
  final bool extended;

  /// Above the destinations: a logo, or the [FloatingActionButton] a rail is
  /// expected to host.
  final Widget? leading;

  /// Below the destinations, pushed to the bottom of the rail.
  final Widget? trailing;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);

    return NavigationRail(
      selectedIndex: index,
      extended: extended,
      backgroundColor: context.colorScheme.surface,
      indicatorColor: accent.withValues(
        alpha: AppInputStyle.config.fillOpacity * 2,
      ),
      // An extended rail already writes every label beside its icon; asking for
      // labels as well is what NavigationRail asserts against.
      labelType: extended ? null : NavigationRailLabelType.all,
      leading: leading,
      trailing: trailing == null
          ? null
          : Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: trailing,
              ),
            ),
      onDestinationSelected: (i) {
        HapticFeedback.selectionClick();
        onDestinationSelected(i);
      },
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon, color: accent),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

/// A [Scaffold] that navigates the way the window is shaped: an [AppNavRail]
/// beside the content on a tablet, an [AppBottomNav] under it on a phone.
///
/// This is the shell a `StatefulShellRoute` builds, and the reason the two nav
/// widgets share one destination type:
///
/// ```dart
/// AppAdaptiveNav(
///   destinations: destinations,
///   index: shell.currentIndex,
///   onDestinationSelected: shell.goBranch,
///   body: shell,
/// )
/// ```
class AppAdaptiveNav extends StatelessWidget {
  const AppAdaptiveNav({
    super.key,
    required this.destinations,
    required this.index,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.drawer,
    this.extendedRail = false,
    this.variant,
  });

  final List<AppNavDestination> destinations;
  final int index;
  final ValueChanged<int> onDestinationSelected;

  /// The screen itself — on a phone the whole body, on a tablet everything
  /// right of the rail.
  final Widget body;

  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? drawer;

  /// Whether the rail shows its labels beside the icons. Only read on the wide
  /// layout.
  final bool extendedRail;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  @override
  Widget build(BuildContext context) {
    // The 600dp short-side breakpoint, so the layout survives a rotation
    // instead of following whichever edge happens to be longer.
    final wide = context.isTablet;

    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      body: wide
          ? Row(
              children: [
                AppNavRail(
                  destinations: destinations,
                  index: index,
                  onDestinationSelected: onDestinationSelected,
                  extended: extendedRail,
                  variant: variant,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : AppBottomNav(
              index: index,
              destinations: destinations,
              onDestinationSelected: onDestinationSelected,
            ),
    );
  }
}
''';
}
