/// Templates for the content widgets that lay several things out in sequence:
/// a vertical timeline, and a horizontal carousel.
class ContentTemplates {
  /// Returns the generated appTimeline template.
  static String appTimeline() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';

/// Where one [AppTimelineEntry] stands in the sequence — which is what its node
/// is drawn from.
///
/// - [done]: behind us. A filled node.
/// - [current]: where the thing is now. A ringed node, drawing the eye.
/// - [pending]: still to come. A hollow, dimmed node.
/// - [failed]: went wrong here. Error-colored, whatever the variant.
enum AppTimelineStatus { done, current, pending, failed }

/// One event on an [AppTimeline].
class AppTimelineEntry {
  const AppTimelineEntry({
    required this.title,
    this.subtitle,
    this.timestamp,
    this.status = AppTimelineStatus.done,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// Shown under the subtitle, dimmed — "2 hours ago", "14:32", a date. Already
  /// formatted: the timeline does not decide how an app writes its times.
  final String? timestamp;

  final AppTimelineStatus status;

  /// Drawn inside the node instead of a dot — a check, a truck, a warning.
  final IconData? icon;

  final Widget? trailing;
  final VoidCallback? onTap;
}

/// A vertical sequence of events, each on a node joined to the next by a line —
/// an order's progress, an audit trail, a delivery status.
///
/// ```dart
/// AppTimeline(
///   entries: [
///     AppTimelineEntry(title: 'Ordered', timestamp: 'Mon 09:12'),
///     AppTimelineEntry(title: 'Shipped', timestamp: 'Tue 11:40'),
///     AppTimelineEntry(
///       title: 'Out for delivery',
///       status: AppTimelineStatus.current,
///     ),
///     AppTimelineEntry(title: 'Delivered', status: AppTimelineStatus.pending),
///   ],
/// )
/// ```
///
/// It sizes to its content, so it needs no height. For a list long enough to
/// need lazy rows, [entryBuilder] gives you one row for a `ListView.builder`.
class AppTimeline extends StatelessWidget {
  const AppTimeline({
    super.key,
    required this.entries,
    this.variant,
    this.nodeSize = 16,
    this.padding,
  });

  final List<AppTimelineEntry> entries;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  /// Diameter of a node. The connector's width and the gap to the text follow
  /// it, so one number scales the rail.
  final double nodeSize;

  final EdgeInsetsGeometry? padding;

  /// One row, for a caller building its own lazy list:
  ///
  /// ```dart
  /// ListView.builder(
  ///   itemCount: entries.length,
  ///   itemBuilder: (context, i) => AppTimeline.entryBuilder(
  ///     entries[i],
  ///     isLast: i == entries.length - 1,
  ///   ),
  /// )
  /// ```
  static Widget entryBuilder(
    AppTimelineEntry entry, {
    required bool isLast,
    AppInputVariant? variant,
    double nodeSize = 16,
  }) => _TimelineRow(
    entry: entry,
    isLast: isLast,
    variant: variant,
    nodeSize: nodeSize,
  );

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            // The last node has nothing to join, and a line running off the
            // bottom of a finished sequence reads as a missing step.
            isLast: i == entries.length - 1,
            variant: variant,
            nodeSize: nodeSize,
          ),
      ],
    );

    return padding == null ? column : Padding(padding: padding!, child: column);
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isLast,
    required this.nodeSize,
    this.variant,
  });

  final AppTimelineEntry entry;
  final bool isLast;
  final double nodeSize;
  final AppInputVariant? variant;

  /// The node's color: the variant for everything that has happened or is
  /// happening, the theme's error for a step that failed, and a faded variant
  /// for one that has not been reached.
  Color _colorOf(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);
    return switch (entry.status) {
      AppTimelineStatus.failed => context.colorScheme.error,
      AppTimelineStatus.pending => accent.withValues(
        alpha: AppInputStyle.config.idleBorderOpacity,
      ),
      _ => accent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(context);
    final content = _content(context);

    return IntrinsicHeight(
      child: Row(
        // Stretch is what lets the connector fill the row: without it the rail
        // column is only as tall as its dot, and the line never reaches the
        // next node.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: nodeSize * 2,
            child: Column(
              children: [
                _node(color),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: nodeSize / 8,
                      margin: const EdgeInsets.symmetric(
                        vertical: AppConstants.space4,
                      ),
                      color: color.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppConstants.space4,
                bottom: isLast ? 0 : AppConstants.space16,
              ),
              child: entry.onTap == null
                  ? content
                  : InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        entry.onTap!();
                      },
                      borderRadius: AppConstants.borderRadius8,
                      child: content,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _node(Color color) {
    final hollow = entry.status == AppTimelineStatus.pending;
    final ringed = entry.status == AppTimelineStatus.current;
    final icon = entry.icon;

    return Container(
      // Centers the dot on the first line of the title rather than on the row,
      // which is what makes a two-line entry still look joined up.
      margin: const EdgeInsets.only(top: AppConstants.space4),
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hollow ? Colors.transparent : color,
        border: Border.all(
          color: color,
          width: ringed ? nodeSize / 4 : nodeSize / 8,
        ),
      ),
      child: icon == null
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Icon(icon, color: hollow ? color : Colors.white),
            ),
    );
  }

  Widget _content(BuildContext context) {
    final subtitle = entry.subtitle;
    final timestamp = entry.timestamp;
    final trailing = entry.trailing;
    final dimmed = entry.status == AppTimelineStatus.pending;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: context.textTheme.bodyLarge?.copyWith(
                  fontWeight: entry.status == AppTimelineStatus.current
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: dimmed ? context.colorScheme.onSurfaceVariant : null,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (timestamp != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppConstants.space4),
                  child: Text(
                    timestamp,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // An empty box rather than a null-aware element: this file has to
        // compile in a project whose pubspec still asks for an older Dart.
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}
''';

  /// Returns the generated appCarousel template.
  static String appCarousel() => r'''
import 'dart:async';

import 'package:flutter/material.dart';

import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';

/// A swipeable row of pages with dots underneath — a product gallery, an
/// onboarding sequence, a set of promo cards.
///
/// ```dart
/// AppCarousel(
///   aspectRatio: 16 / 9,
///   autoPlay: const Duration(seconds: 5),
///   children: [for (final url in photos) AppImage(url: url)],
/// )
/// ```
///
/// [autoPlay] advances on a timer and stops for good on the first user swipe.
/// It never starts when the platform asks to reduce motion.
class AppCarousel extends StatefulWidget {
  const AppCarousel({
    super.key,
    required this.children,
    this.aspectRatio = 16 / 9,
    this.height,
    this.autoPlay,
    this.viewportFraction = 1,
    this.showIndicator = true,
    this.indicatorInside = false,
    this.onPageChanged,
    this.initialPage = 0,
    this.padEnds = true,
    this.variant,
  });

  final List<Widget> children;

  /// Shape of a page when no [height] is given.
  final double aspectRatio;

  /// A fixed height instead of an [aspectRatio] — for a carousel in a layout
  /// that decides its own size.
  final double? height;

  /// Null leaves the carousel still until it is swiped.
  final Duration? autoPlay;

  /// Below 1 the neighbouring pages peek in at the edges, which is what tells
  /// the user there is more to swipe to.
  final double viewportFraction;

  final bool showIndicator;

  /// Whether the dots sit over the last of the page or under it. Over reads
  /// better on photos, under on cards and text.
  final bool indicatorInside;

  final ValueChanged<int>? onPageChanged;
  final int initialPage;

  /// Whether a peeking carousel insets its first and last page so they can
  /// still be centered.
  final bool padEnds;

  /// Null follows [AppInputConfig.defaults].
  final AppInputVariant? variant;

  @override
  State<AppCarousel> createState() => _AppCarouselState();
}

class _AppCarouselState extends State<AppCarousel> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage,
    viewportFraction: widget.viewportFraction,
  );

  Timer? _timer;
  int _page = 0;

  /// Set once the user swipes, and never unset: an auto-advance that resumes
  /// after a moment is the version people complain about.
  bool _userTookOver = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is not readable in initState, and "reduce motion" can change
    // while the app is open — so the timer is decided here, where a change in
    // the setting reaches it.
    _syncTimer();
  }

  @override
  void didUpdateWidget(AppCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay != oldWidget.autoPlay ||
        widget.children.length != oldWidget.children.length) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;

    final interval = widget.autoPlay;
    if (interval == null || _userTookOver) return;
    if (widget.children.length < 2) return;
    if (MediaQuery.disableAnimationsOf(context)) return;

    _timer = Timer.periodic(interval, (_) => _advance());
  }

  void _advance() {
    if (!_controller.hasClients) return;
    final next = _page + 1;
    // Wrapping by animating all the way back reads as the sequence restarting,
    // which is what it is — a jump would look like a glitch.
    if (next >= widget.children.length) {
      _controller.animateToPage(
        0,
        duration: AppConstants.duration500,
        curve: Curves.easeInOut,
      );
      return;
    }
    _controller.nextPage(
      duration: AppConstants.duration300,
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    widget.onPageChanged?.call(page);
  }

  void _onUserScroll() {
    if (_userTookOver) return;
    _userTookOver = true;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = NotificationListener<ScrollStartNotification>(
      // A drag is the user taking the wheel; a programmatic animation is not.
      onNotification: (notification) {
        if (notification.dragDetails != null) _onUserScroll();
        return false;
      },
      child: PageView(
        controller: _controller,
        onPageChanged: _onPageChanged,
        padEnds: widget.padEnds,
        children: widget.children,
      ),
    );

    final sized = widget.height != null
        ? SizedBox(height: widget.height, child: pages)
        : AspectRatio(aspectRatio: widget.aspectRatio, child: pages);

    if (!widget.showIndicator || widget.children.length < 2) return sized;

    final dots = AppCarouselDots(
      count: widget.children.length,
      index: _page,
      variant: widget.variant,
    );

    if (!widget.indicatorInside) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          sized,
          const SizedBox(height: AppConstants.space8),
          dots,
        ],
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        sized,
        Padding(padding: AppConstants.padding12, child: dots),
      ],
    );
  }
}

/// The page dots on their own, so a caller driving its own [PageView] — or a
/// paged onboarding flow — can still wear the kit's indicator.
class AppCarouselDots extends StatelessWidget {
  const AppCarouselDots({
    super.key,
    required this.count,
    required this.index,
    this.variant,
  });

  final int count;
  final int index;
  final AppInputVariant? variant;

  @override
  Widget build(BuildContext context) {
    final accent = AppInputStyle.accentOf(context, variant);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: AppConstants.space4,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppConstants.duration200,
            height: AppConstants.space8,
            // The current page's dot stretches instead of only changing color,
            // so the position reads at a glance and in a screenshot.
            width: i == index ? AppConstants.space24 : AppConstants.space8,
            decoration: BoxDecoration(
              color: i == index
                  ? accent
                  : accent.withValues(
                      alpha: AppInputStyle.config.idleBorderOpacity,
                    ),
              borderRadius: AppConstants.borderRadiusFull,
            ),
          ),
      ],
    );
  }
}
''';
}
