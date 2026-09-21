/// Templates for the navigation shells: the bottom bar, tabs, the drawer, and
/// the rail a wide screen shows instead of a bottom bar.
class NavigationTemplates {
  /// Returns the generated appBottomNav template.
  static String appBottomNav() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../indicators/app_badge.dart';
import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// A single destination for [AppBottomNav] — and for the rail and the drawer,
/// which read the same list so an app describes its navigation once.
///
/// A destination can carry a badge. The count is state, so a list that uses one
/// is built where that state is read instead of held `const`:
///
/// ```dart
/// final destinations = [
///   for (var i = 0; i < _tabs.length; i++)
///     AppNavDestination(
///       icon: _tabs[i].icon,
///       selectedIcon: _tabs[i].selectedIcon,
///       label: _tabs[i].label,
///       badgeCount: i == 0 ? unseenMessagesNumber : null,
///     ),
/// ];
/// ```
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount,
    this.showBadgeDot = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// The number on this destination's icon — unseen messages, items in a cart.
  /// Null or 0 shows none, and past 99 it reads "99+".
  final int? badgeCount;

  /// A plain presence dot instead of a number, for "something is new" with
  /// nothing to count. Only read when [badgeCount] is null — a count wins.
  final bool showBadgeDot;

  /// Whether [badged] draws anything, by the same rule [AppBadge] follows.
  bool get hasBadge => badgeCount == null ? showBadgeDot : badgeCount! > 0;

  /// [icon] wearing this destination's badge, or bare when it has none. The
  /// bar, the rail and the drawer all draw their icons through this so the
  /// badge looks the same on each.
  Widget badged(Widget icon) =>
      AppBadge(count: badgeCount, showDot: showBadgeDot, child: icon);
}

/// How [AppBottomNav] marks the selected destination.
///
/// - [material]: Material 3's own bar — a label under every icon and a pill
///   indicator that slides behind the selected one.
/// - [classic]: the pre-M3 bar — icon over label, the selected pair tinted
///   with the accent and nothing drawn behind it.
/// - [pill]: icons only until selected; the selected one opens into an accent
///   pill with its label beside the icon.
/// - [dot]: icons only, with a dot under the selected one. The quietest of the
///   four, for a bar whose icons speak for themselves.
enum AppBottomNavStyle { material, classic, pill, dot }

/// Where [AppBottomNav] writes its labels, on top of what the
/// [AppBottomNavStyle] says by itself.
///
/// - [auto]: whatever the style does on its own — [AppBottomNavStyle.material]
///   and [AppBottomNavStyle.classic] write the label under every icon,
///   [AppBottomNavStyle.pill] beside the selected one, [AppBottomNavStyle.dot]
///   nowhere.
/// - [below]: every destination carries its label under its icon, whichever
///   style is drawing. The pill then fills behind the icon *and* the label
///   instead of opening sideways; the dot keeps its mark under both.
/// - [none]: icons only. The label still reaches a screen reader, and a long
///   press still names the icon.
enum AppBottomNavLabels { auto, below, none }

/// A corner [AppBottomNav] cuts something with — the floating card it rides in
/// ([AppBottomNav.floatingShape]) and the fill behind the selected destination
/// ([AppBottomNav.pillShape]) are each asked this separately.
///
/// - [full]: a stadium, as round at the ends as the thing is tall.
/// - [rounded]: the corner an elevated card wears.
/// - [square]: sharp corners.
///
/// [AppBottomNav.floatingBorderRadius] and [AppBottomNav.pillBorderRadius]
/// override the three where a project wants a number of its own.
enum AppBottomNavShape { full, rounded, square }

/// How wide the card a floating [AppBottomNav] rides in is. A docked bar spans
/// the bottom edge by definition, so this is only read when
/// [AppBottomNav.floating].
///
/// - [fill]: the width of the screen less the margin around it — the band a
///   bottom bar has always been.
/// - [hug]: only as wide as its destinations need, centered. Two or three
///   destinations spread across a whole phone is mostly empty card; this is the
///   answer to that.
///
/// [AppBottomNav.floatingMaxWidth] caps either of them, which is how a [fill]
/// bar stops short of the edges on a tablet.
enum AppBottomNavWidth { fill, hug }

/// The app's bottom navigation. Feed it the current [index], the
/// [destinations], and an [onDestinationSelected] callback. For go_router,
/// drive [index] from a `StatefulShellRoute` and switch branch in the callback:
///
/// ```dart
/// AppBottomNav(
///   index: shell.currentIndex,
///   destinations: destinations,
///   onDestinationSelected: shell.goBranch,
///   style: AppBottomNavStyle.pill,
///   labels: AppBottomNavLabels.below,
///   floating: true,
///   floatingShape: AppBottomNavShape.rounded,
///   floatingWidth: AppBottomNavWidth.hug,
/// )
/// ```
///
/// Each knob answers one question and combines freely with the rest: [style] is
/// how the selected destination is marked, [labels] is where the names are
/// written, [floating] is whether the bar is a band across the bottom edge or a
/// card riding above it, [floatingShape] is the corner that card is cut with,
/// [floatingWidth] is how wide it is, [borderColor] is the line drawn around
/// it, and [pillShape] the corner of the fill behind the selection. A floating
/// [pill] is the look most modern apps wear, but every style floats and every
/// style can carry labels.
///
/// A floating bar wants `Scaffold(extendBody: true)` under it, so the content
/// runs through the gap instead of stopping at it. [AppAdaptiveNav] sets that
/// for you.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.destinations,
    required this.onDestinationSelected,
    this.style = AppBottomNavStyle.material,
    this.labels = AppBottomNavLabels.auto,
    this.floating = false,
    this.floatingShape = AppBottomNavShape.full,
    this.floatingBorderRadius,
    this.floatingWidth = AppBottomNavWidth.fill,
    this.floatingMaxWidth,
    this.borderColor,
    this.pillShape,
    this.pillBorderRadius,
    this.variant,
  });

  final int index;
  final List<AppNavDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  final AppBottomNavStyle style;

  /// Where the destination names are written. Defaults to whatever [style]
  /// does on its own.
  final AppBottomNavLabels labels;

  /// Detaches the bar from the bottom edge: a card with a margin around it and
  /// a shadow under it. Works with every [style].
  final bool floating;

  /// The corner that card is cut with. Only read when [floating].
  final AppBottomNavShape floatingShape;

  /// A corner of the project's own, overriding [floatingShape]. Only read when
  /// [floating].
  final BorderRadius? floatingBorderRadius;

  /// Whether that card spans the width or shrinks to its destinations. Only
  /// read when [floating] — a docked bar is the width of the screen.
  final AppBottomNavWidth floatingWidth;

  /// A ceiling on that card's width, in logical pixels, whichever
  /// [floatingWidth] it wears. A capped card is centered. Null is uncapped —
  /// which for [AppBottomNavWidth.fill] means the screen less its margin. Only
  /// read when [floating].
  final double? floatingMaxWidth;

  /// The bar's hairline border: around the whole card when [floating], along
  /// the top edge when docked.
  ///
  /// Null leaves each layout as it was — a docked bar keeps the
  /// [ColorScheme.outlineVariant] line it draws between itself and the content,
  /// Material's own bar keeps the none it draws, and a floating card is held up
  /// by its shadow alone. Naming a color is how a flat theme gets an edge in a
  /// dark scheme, where that shadow is invisible.
  final Color? borderColor;

  /// The corner of the fill behind the selected destination: the pill an
  /// [AppBottomNavStyle.pill] draws, and the indicator Material's own bar
  /// slides behind its selection.
  ///
  /// Null leaves each of them the corner it wears by itself — a stadium for a
  /// pill that opens sideways, a card's corner for one stacked over its label,
  /// and the theme's for Material's indicator.
  final AppBottomNavShape? pillShape;

  /// A corner of the project's own for that fill, overriding [pillShape].
  final BorderRadius? pillBorderRadius;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  /// The height of the three styles this widget draws itself, before any
  /// safe-area inset: a row of touch targets with a little air around it.
  /// Material's own bar measures itself and is left alone.
  static const double _height = 64;

  static BorderRadius _radiusOf(AppBottomNavShape shape) => switch (shape) {
        AppBottomNavShape.full => AppConstants.borderRadiusFull,
        AppBottomNavShape.rounded => AppConstants.borderRadius16,
        AppBottomNavShape.square => BorderRadius.zero,
      };

  /// The corner the floating card is cut with: the project's own where it named
  /// one, the shape's otherwise.
  BorderRadius get _radius => floatingBorderRadius ?? _radiusOf(floatingShape);

  /// The corner asked for behind the selected destination, or null where none
  /// was and every style keeps the one it draws by itself.
  BorderRadius? get _pillRadius {
    final shape = pillShape;
    return pillBorderRadius ?? (shape == null ? null : _radiusOf(shape));
  }

  /// Whether the selected destination opens sideways into a labelled pill. That
  /// is the pill style's own layout, and it is the one thing asking for labels
  /// [AppBottomNavLabels.below] — or for none — takes away.
  bool get _opens =>
      style == AppBottomNavStyle.pill && labels == AppBottomNavLabels.auto;

  /// Whether the bar is sized by its destinations rather than by the screen.
  /// Only a floating bar can be: a docked one is the bottom edge.
  bool get _hug => floating && floatingWidth == AppBottomNavWidth.hug;

  void _select(int i) {
    HapticFeedback.selectionClick();
    onDestinationSelected(i);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      destinations.length >= 2,
      'AppBottomNav: needs at least two destinations — a bar with one of them '
      'is not navigation.',
    );
    assert(
      index >= 0 && index < destinations.length,
      'AppBottomNav: index $index is outside the ${destinations.length} '
      'destinations it was given.',
    );

    final bar = style == AppBottomNavStyle.material
        ? _material(context)
        : _drawn(context);

    return floating ? _floated(context, bar) : bar;
  }

  /// Material's own [NavigationBar] — still the right answer when you want the
  /// platform look, and the only style whose indicator animates between
  /// destinations for free.
  Widget _material(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    final pillRadius = _pillRadius;

    final bar = NavigationBar(
      selectedIndex: index,
      // Floating, the card behind it owns the surface and the shadow — a bar
      // painting its own would draw a second edge inside the rounded one.
      backgroundColor: floating ? Colors.transparent : null,
      elevation: floating ? 0 : null,
      // Null without a variant, so the bar's fill and its indicator both come
      // from `navigationBarTheme`. The pill style below still needs a colour
      // it can count on — it paints a surface the theme cannot describe.
      indicatorColor: AppInputStyle.accentOrNull(
        context,
        variant,
      )?.withValues(alpha: AppInputStyle.config.fillOpacity * 2),
      // Material's indicator is the same fill the pill style draws by hand, so
      // a project that named a corner for one means it for both. Null leaves
      // NavigationBarTheme's own.
      indicatorShape: pillRadius == null
          ? null
          : RoundedRectangleBorder(borderRadius: pillRadius),
      // Material's bar writes a label under every icon on its own, so `auto`
      // and `below` are the same answer here — and null is the one that lets a
      // NavigationBarTheme still have its say.
      labelBehavior: switch (labels) {
        AppBottomNavLabels.auto => null,
        AppBottomNavLabels.below =>
          NavigationDestinationLabelBehavior.alwaysShow,
        AppBottomNavLabels.none =>
          NavigationDestinationLabelBehavior.alwaysHide,
      },
      onDestinationSelected: _select,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: destination.badged(Icon(destination.icon)),
            selectedIcon: destination.badged(
              Icon(destination.selectedIcon, color: accent),
            ),
            label: destination.label,
          ),
      ],
    );

    // NavigationBar divides whatever width it is handed between its
    // destinations, so it is the one style that cannot shrink to them by
    // itself. IntrinsicWidth measures what they would take and hands that back
    // as the width — one extra layout pass over a handful of icons.
    final sized = _hug ? IntrinsicWidth(child: bar) : bar;

    final border = borderColor;
    if (floating || border == null) return sized;

    // The bar paints its own surface, so the line has to land on top of it —
    // a decoration behind it would be covered by the color it draws.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: sized,
    );
  }

  /// The three styles Material does not ship: one row of items over the bar's
  /// own surface.
  Widget _drawn(BuildContext context) {
    final row = SizedBox(
      height: _height,
      child: Row(
        // Hugging, the row is as wide as its items and the card around it
        // shrinks to match; filling, it takes the width and spreads them.
        mainAxisSize: _hug ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        // Nothing separates the items once the row stops spreading them, so a
        // hugging bar spaces them by hand.
        spacing: _hug ? AppConstants.space4 : 0.0,
        children: [
          for (var i = 0; i < destinations.length; i++)
            // Only a pill that opens sideways grows with its label, so only
            // that one is sized by its content — every other layout divides the
            // width evenly. A stacked pill still hugs its own content inside
            // its even share, which is what keeps it a pill. Hugging, there is
            // no width to divide: every item is its own size.
            if (!_hug && !_opens)
              Expanded(child: _item(i))
            // The open pill is the one item that can want more room than it is
            // given: Flexible lets its label ellipsize on a narrow screen
            // instead of overflowing the row.
            else if (_opens && i == index)
              Flexible(child: _item(i))
            else
              _item(i),
        ],
      ),
    );

    // Floating, the shell around it is the Material, and it has already spent
    // the safe area on the margin under the card.
    if (floating) return row;

    return Material(
      color: context.colorScheme.surface,
      child: DecoratedBox(
        // What separates the bar from the content above it, since this one
        // carries no elevation. Drawn outside the SafeArea so it spans the
        // full width on a notched phone held sideways.
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: borderColor ?? context.colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(top: false, child: row),
      ),
    );
  }

  Widget _item(int i) => _AppNavItem(
        destination: destinations[i],
        selected: i == index,
        style: style,
        labels: labels,
        // A pill that opens sideways is a stadium, which is what it has always
        // been. Stacked over a label it is taller than it is wide, and a
        // stadium there is a lozenge — so that one defaults to a card's corner,
        // the same one Material's stacked indicator wears.
        pillRadius: _pillRadius ??
            (_opens
                ? AppConstants.borderRadiusFull
                : AppConstants.borderRadius16),
        variant: variant,
        onTap: () => _select(i),
      );

  /// The card a floating bar rides in: the margin off the edges, the corner it
  /// is cut with, the width it takes of what is left, and the shadow that lifts
  /// it off the content passing underneath.
  Widget _floated(BuildContext context, Widget bar) {
    // What the system took at the bottom edge: the gesture pill, or Android's
    // three buttons — which are tall enough that a card sitting at exactly the
    // inset reads as a second bar stacked on the first.
    final inset = MediaQuery.paddingOf(context).bottom;
    // So the margin is spent on top of the inset rather than instead of it —
    // a short one where the system already holds the card off the edge, the
    // full one where it does not.
    final bottomMargin =
        inset + (inset > 0 ? AppConstants.space8 : AppConstants.space16);
    final radius = _radius;
    final border = borderColor;

    // A rounded end curves in over the outermost destination, and this is the
    // room that keeps it clear of the curve — so it tracks the corner rather
    // than being spent on a square card that has no curve to clear.
    final clearance = switch (radius.topLeft.x) {
      >= AppConstants.radius24 => AppConstants.space8,
      > 0 => AppConstants.space4,
      _ => 0.0,
    };

    Widget card = DecoratedBox(
      // The same shadow an elevated AppCard casts, so the two read as
      // siblings rather than as two ideas of what "raised" looks like.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        // A step off `surface`, which is what keeps the card visible in a
        // dark theme, where the shadow under it is not.
        color: context.colorScheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        // The corner and the line around it are one shape to Material, and
        // asking it for both a borderRadius and a shape is what it asserts
        // against. `BorderSide.none` is the card that was never given a color.
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        // The bar inside must not inset itself as well — NavigationBar wraps
        // itself in a SafeArea, which here would pad the inside of the card.
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: clearance),
            child: bar,
          ),
        ),
      ),
    );

    final maxWidth = floatingMaxWidth;
    if (maxWidth != null) {
      card = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: card,
      );
    }

    // A card narrower than the room it was given would otherwise sit against
    // the left margin. Filling and uncapped there is nothing to center — the
    // card is already the width of the row.
    //
    // `heightFactor` is what keeps this to the bar's own height: the slot a
    // bottom bar is laid out in is loose, and an Align without it would answer
    // with the whole screen.
    final placed = _hug || maxWidth != null
        ? Align(heightFactor: 1, child: card)
        : card;

    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.space16,
        right: AppConstants.space16,
        top: AppConstants.space8,
        bottom: bottomMargin,
      ),
      child: placed,
    );
  }
}

/// One destination in the styles [AppBottomNav] draws itself.
class _AppNavItem extends StatelessWidget {
  const _AppNavItem({
    required this.destination,
    required this.selected,
    required this.style,
    required this.labels,
    required this.pillRadius,
    required this.variant,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final AppBottomNavStyle style;
  final AppBottomNavLabels labels;

  /// The corner of the fill behind a selected [AppBottomNavStyle.pill].
  final BorderRadius pillRadius;

  final AppInputVariant? variant;
  final VoidCallback onTap;

  /// The mark under a selected [AppBottomNavStyle.dot] icon. Small enough to
  /// read as a mark rather than as a second icon.
  static const double _dotSize = 6;

  /// How far Material's [Badge] reaches past the top and end of the icon it is
  /// drawn on.
  static const double _badgeOverhang = 4;

  /// Whether this destination's name is written on screen — which decides both
  /// whether the layouts below make room for it and whether a tooltip naming
  /// the icon would be repeating what is already there.
  bool get _labelled => switch (labels) {
        AppBottomNavLabels.none => false,
        AppBottomNavLabels.below => true,
        AppBottomNavLabels.auto => switch (style) {
            AppBottomNavStyle.material || AppBottomNavStyle.classic => true,
            // The pill writes its label only once it has opened to hold it.
            AppBottomNavStyle.pill => selected,
            AppBottomNavStyle.dot => false,
          },
      };

  /// Whether this item is a pill that opens sideways on selection, as opposed
  /// to one stacked over its label or holding an icon alone.
  bool get _opens =>
      style == AppBottomNavStyle.pill && labels == AppBottomNavLabels.auto;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    final idle = context.colorScheme.onSurfaceVariant;
    final pill = style == AppBottomNavStyle.pill;

    // The pill is the one style that fills a surface behind its icon, so it is
    // the one style whose selected icon is drawn *on* the accent.
    final selectedColor =
        pill ? AppInputStyle.onAccentOf(context, variant) : accent;

    // Reduce-motion reaches the same layouts, just instantly.
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppConstants.duration200;

    final icon = destination.badged(
      Icon(
        selected ? destination.selectedIcon : destination.icon,
        size: AppConstants.iconMedium,
        color: selected ? selectedColor : idle,
      ),
    );

    // A badge hangs `_badgeOverhang` past its icon's top and end edges, and the
    // opening pill's AnimatedSize clips to its own box. A badged destination
    // moves that much of the pill's padding inside the box, so the badge is
    // drawn and the pill still lands exactly where it would have.
    final overhang = destination.hasBadge ? _badgeOverhang : 0.0;
    final pillHorizontal =
        _opens && selected ? AppConstants.space16 : AppConstants.space12;
    final pillVertical =
        _labelled && !_opens ? AppConstants.space4 : AppConstants.space8;

    final label = Text(
      destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.labelMedium?.copyWith(
        color: selected ? selectedColor : idle,
        fontWeight: selected ? FontWeight.bold : null,
      ),
    );

    // Icon over name, or the icon alone where the name is not written. What
    // every layout here but the opening pill is built from.
    // The label is not Flexible here the way it is inside an open pill: down
    // the column, flex would hand it the leftover height instead of letting it
    // ellipsize, and the width it has to fit is the item's own either way.
    final stacked = <Widget>[
      icon,
      if (_labelled) ...[
        const SizedBox(height: AppConstants.space4),
        label,
      ],
    ];

    final Widget content = switch (style) {
      // The material style is a NavigationBar, not a row of these, so it never
      // arrives here — answering with the nearest layout beats an empty box if
      // that ever stops being true.
      AppBottomNavStyle.classic || AppBottomNavStyle.material => Column(
          mainAxisSize: MainAxisSize.min,
          children: stacked,
        ),
      AppBottomNavStyle.dot => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...stacked,
            // Closer under a label than under a bare icon, so the dot reads as
            // this destination's mark either way.
            SizedBox(
              height: _labelled ? AppConstants.space4 : AppConstants.space8,
            ),
            // The dot's room is held whether or not it is drawn, so the icons
            // do not hop as the selection moves.
            SizedBox(
              width: _dotSize,
              height: _dotSize,
              child: AnimatedOpacity(
                duration: duration,
                opacity: selected ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      AppBottomNavStyle.pill => AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          // Stacked, the label is inside the fill, and the air an open pill
          // wears above and below it would push the whole thing past the
          // height of the bar.
          padding: _opens
              ? EdgeInsetsDirectional.fromSTEB(
                  pillHorizontal,
                  pillVertical - overhang,
                  pillHorizontal - overhang,
                  pillVertical,
                )
              : EdgeInsets.symmetric(
                  horizontal: pillHorizontal,
                  vertical: pillVertical,
                ),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: pillRadius,
          ),
          child: _opens
              // The label is only in the tree while selected; AnimatedSize is
              // what turns its arrival into the pill opening rather than a
              // jump.
              ? AnimatedSize(
                  duration: duration,
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      top: overhang,
                      end: overhang,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        if (selected) ...[
                          const SizedBox(width: AppConstants.space8),
                          Flexible(child: label),
                        ],
                      ],
                    ),
                  ),
                )
              // Stacked, every item holds the same layout whether or not it is
              // selected, so there is nothing to animate but the fill.
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: stacked,
                ),
        ),
    };

    final target = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppConstants.touchTarget,
        minHeight: AppConstants.touchTarget,
      ),
      // Shrink-wraps where the item is sized by its content — a pill that
      // stretched to the free space beside it would not be a pill. Ignored
      // where the row hands down a tight width.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        // The label below carries the same string as the Semantics above, and
        // reading a destination out twice is what excluding it here avoids.
        child: ExcludeSemantics(child: content),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        selected: selected,
        // Some of these layouts never draw the label, and a row of unnamed
        // icons is unusable with a screen reader.
        label: destination.label,
        // The badge is inside the excluded content, so its count is said here.
        value: (destination.badgeCount ?? 0) > 0
            ? '${destination.badgeCount}'
            : null,
        child: _tooltipped(
          // The ripple follows the fill it lands on where there is one, so a
          // squared-off pill is not tapped with a round splash.
          child: InkWell(
            onTap: onTap,
            borderRadius: style == AppBottomNavStyle.pill
                ? pillRadius
                : AppConstants.borderRadiusFull,
            child: target,
          ),
        ),
      ),
    );
  }

  /// Names the icon on a long press — but only where the label is not already
  /// written beside it, so a tooltip never repeats what is on screen.
  Widget _tooltipped({required Widget child}) {
    if (_labelled) return child;
    return Tooltip(message: destination.label, child: child);
  }
}
''';

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

/// A [TabBar] wearing the kit's vocabulary. Being a [PreferredSizeWidget] is
/// the point — it drops straight into [AppAppBar]'s `bottom` slot.
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
/// With no [controller] it reads the [DefaultTabController] above it. [AppTabs]
/// is the version that owns a controller and puts the views underneath.
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
    final accent = AppInputStyle.accentOrNull(context, variant);
    // The pill is a shape `tabBarTheme` has no way to describe, so it needs a
    // colour whether or not a variant named one — an indicator painted null
    // would simply not be drawn.
    final pillFill = AppInputStyle.accentOf(context, variant);
    final onPill = AppInputStyle.onAccentOf(context, variant);
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
              color: pillFill,
              borderRadius: AppConstants.borderRadiusFull,
            )
          : null,
      // Null on either half leaves that half to `tabBarTheme`.
      indicatorColor: pill ? null : accent,
      // Ignored once `indicator` is set, but TabBar asserts it is positive
      // either way — so the pill branch cannot answer 0.
      indicatorWeight: AppInputStyle.config.focusedBorderWidth * 2,
      labelColor: pill ? onPill : accent,
      unselectedLabelColor: accent == null
          ? null
          : context.colorScheme.onSurfaceVariant,
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

/// An [AppTabBar] with its views under it, owning the [TabController] — the
/// [StatefulWidget], ticker and `dispose` you would otherwise write.
///
/// ```dart
/// AppTabs(
///   tabs: const [AppTab(label: 'Open'), AppTab(label: 'Closed')],
///   children: [OpenOrders(), ClosedOrders()],
/// )
/// ```
///
/// It fills the height it is given, so put it under an [Expanded] or hand it a
/// body's worth of space. For a bar in the app bar, use [AppTabBar].
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
/// It closes itself after a pick — a modal drawer should never survive its own
/// selection.
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
        // children, so a header or divider never shifts the selected index.
        // An empty box rather than a null-aware element, to stay compatible
        // with older Dart SDKs.
        header ?? const SizedBox.shrink(),
        for (final destination in destinations)
          NavigationDrawerDestination(
            icon: destination.badged(Icon(destination.icon)),
            selectedIcon: destination.badged(
              Icon(destination.selectedIcon, color: accent),
            ),
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
/// Material asks for a rail past 600dp; [AppAdaptiveNav] makes that switch.
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
            icon: destination.badged(Icon(destination.icon)),
            selectedIcon: destination.badged(
              Icon(destination.selectedIcon, color: accent),
            ),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

/// A [Scaffold] that navigates the way the window is shaped: an [AppNavRail]
/// beside the content on a tablet, an [AppBottomNav] under it on a phone.
///
/// This is the shell a `StatefulShellRoute` builds.
///
/// ```dart
/// AppAdaptiveNav(
///   destinations: destinations,
///   index: shell.currentIndex,
///   onDestinationSelected: shell.goBranch,
///   body: shell,
/// )
/// ```
///
/// The phone half of it is an [AppBottomNav], so [bottomNavStyle],
/// [bottomNavLabels], [floatingBottomNav], [bottomNavShape], [bottomNavWidth]
/// and [bottomNavBorderColor] pick which of its looks that half wears.
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
    this.bottomNavStyle = AppBottomNavStyle.material,
    this.bottomNavLabels = AppBottomNavLabels.auto,
    this.floatingBottomNav = false,
    this.bottomNavShape = AppBottomNavShape.full,
    this.bottomNavBorderRadius,
    this.bottomNavWidth = AppBottomNavWidth.fill,
    this.bottomNavMaxWidth,
    this.bottomNavBorderColor,
    this.bottomNavPillShape,
    this.bottomNavPillBorderRadius,
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

  /// How the bar marks the selected destination. Only read on the phone
  /// layout — the rail draws its own indicator either way.
  final AppBottomNavStyle bottomNavStyle;

  /// Where the bar writes its destination names. Only read on the phone
  /// layout — the rail writes its own beside or under its icons.
  final AppBottomNavLabels bottomNavLabels;

  /// Whether the bar floats above the content instead of sitting on the bottom
  /// edge. Only read on the phone layout, where it also turns on
  /// [Scaffold.extendBody] so the body runs under the card.
  final bool floatingBottomNav;

  /// The corner that floating card is cut with. Only read on the phone layout,
  /// and only when [floatingBottomNav] is on.
  final AppBottomNavShape bottomNavShape;

  /// A corner of the project's own, overriding [bottomNavShape].
  final BorderRadius? bottomNavBorderRadius;

  /// Whether that floating card spans the width or shrinks to its
  /// destinations — [AppBottomNavWidth.hug] is what keeps a two-tab bar from
  /// being mostly empty card. Only read on the phone layout, and only when
  /// [floatingBottomNav].
  final AppBottomNavWidth bottomNavWidth;

  /// A ceiling on that card's width. A capped card is centered. Only read on
  /// the phone layout, and only when [floatingBottomNav].
  final double? bottomNavMaxWidth;

  /// The bar's hairline border: around the card when [floatingBottomNav],
  /// along its top edge when docked. Null leaves each layout as it is.
  final Color? bottomNavBorderColor;

  /// The corner of the fill behind the bar's selected destination. Null leaves
  /// each style the one it draws by itself.
  final AppBottomNavShape? bottomNavPillShape;

  /// A corner of the project's own, overriding [bottomNavPillShape].
  final BorderRadius? bottomNavPillBorderRadius;

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
      // A floating bar leaves a gap under and beside itself. Without this the
      // body stops at the top of that gap and the card looks pasted on.
      extendBody: !wide && floatingBottomNav,
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
              style: bottomNavStyle,
              labels: bottomNavLabels,
              floating: floatingBottomNav,
              floatingShape: bottomNavShape,
              floatingBorderRadius: bottomNavBorderRadius,
              floatingWidth: bottomNavWidth,
              floatingMaxWidth: bottomNavMaxWidth,
              borderColor: bottomNavBorderColor,
              pillShape: bottomNavPillShape,
              pillBorderRadius: bottomNavPillBorderRadius,
              variant: variant,
            ),
    );
  }
}
''';
}
