/// Generates MoAdapt — the wrapper that scales the whole UI proportionally
/// to the screen from a single reference design size.
abstract final class AdaptTemplates {
  /// Returns the `shared/widgets/mo_adapt.dart` source.
  static String moAdapt() => r'''
/// Proportional UI scaling for a whole app from one wrapper widget.
///
/// Wrap the root widget in a [MoAdapt] and every logical dimension in the
/// subtree scales to the screen, relative to a reference design size. No
/// `.w`/`.h`/`.sp` accessors needed.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// How [MoAdapt] derives its scale factor from the screen size and
/// [MoAdapt.designSize].
enum MoAdaptScaleMode {
  /// `screenWidth / designWidth`. The default; suits portrait phone apps.
  width,

  /// `screenHeight / designHeight`.
  height,

  /// The smaller of the width and height ratios, so the whole design fits.
  /// Suits landscape and tablets.
  min,

  /// The larger of the width and height ratios.
  max,
}

/// The scaling applied by a [MoAdapt] ancestor. See [MoAdapt.of].
@immutable
class MoAdaptData {
  /// Creates scaling information. Used internally by [MoAdapt].
  const MoAdaptData({
    required this.scale,
    required this.designSize,
    required this.screenSize,
    required this.adaptedSize,
  });

  /// How much every logical pixel in the subtree is magnified.
  final double scale;

  /// The reference design size this scaling is based on.
  final Size designSize;

  /// The real logical size of the screen (what `MediaQuery` would report
  /// outside of [MoAdapt]).
  final Size screenSize;

  /// The logical size the subtree is laid out at ([screenSize] divided by
  /// [scale]). This is what `MediaQuery.sizeOf` reports inside [MoAdapt].
  final Size adaptedSize;

  /// Converts [value] so it occupies `value` real logical pixels despite the
  /// scaling, for a widget that should not scale.
  double unscale(double value) => value / scale;

  @override
  bool operator ==(Object other) {
    return other is MoAdaptData &&
        other.scale == scale &&
        other.designSize == designSize &&
        other.screenSize == screenSize &&
        other.adaptedSize == adaptedSize;
  }

  @override
  int get hashCode => Object.hash(scale, designSize, screenSize, adaptedSize);

  @override
  String toString() =>
      'MoAdaptData(scale: $scale, designSize: $designSize, '
      'screenSize: $screenSize, adaptedSize: $adaptedSize)';
}

/// Scales an entire widget subtree proportionally to the screen size, based
/// on a reference [designSize].
///
/// Place it once, as the parent of your app:
///
/// ```dart
/// void main() {
///   runApp(
///     const MoAdapt(
///       designSize: Size(412, 924),
///       child: MyApp(), // your existing MaterialApp, unchanged
///     ),
///   );
/// }
/// ```
///
/// Everything below is laid out in design-space coordinates and rendered
/// through a single uniform transform, so all fixed logical dimensions —
/// `fontSize: 16`, `EdgeInsets.all(12)`, `SizedBox(height: 24)`, icon sizes,
/// border radii — grow and shrink together with the screen. The transform is
/// applied at paint time as a vector operation, so text and shapes stay
/// pixel-crisp at any scale.
///
/// [MoAdapt] also rewrites the ambient [MediaQuery] (size, device pixel
/// ratio, safe-area padding, view insets) into design-space units, so
/// `SafeArea`, dialogs, bottom sheets, and keyboard avoidance keep working
/// consistently, and pointer events are mapped through the transform for
/// correct hit testing.
///
/// The system text scale factor (accessibility setting) still applies on top
/// of the proportional scaling. To opt out of that, clamp the text scaler in
/// your app's `builder` as usual.
class MoAdapt extends StatelessWidget {
  /// Creates a proportional scaling wrapper around [child].
  const MoAdapt({
    super.key,
    required this.designSize,
    required this.child,
    this.scaleMode = MoAdaptScaleMode.width,
    this.minScale,
    this.maxScale,
    this.enabled = true,
  });

  /// The logical size of the reference design, e.g. `Size(412, 924)` for an
  /// iPhone-14-sized Figma frame.
  final Size designSize;

  /// The widget subtree to scale — typically your `MaterialApp`.
  final Widget child;

  /// How the scale factor is computed. Defaults to [MoAdaptScaleMode.width].
  final MoAdaptScaleMode scaleMode;

  /// If non-null, the scale factor never goes below this value.
  final double? minScale;

  /// Caps the scale factor, e.g. `maxScale: 1.3` for tablets.
  final double? maxScale;

  /// Whether scaling is applied. Toggling it keeps the subtree's state.
  final bool enabled;

  /// The [MoAdaptData] of the closest [MoAdapt]. See [maybeOf].
  static MoAdaptData of(BuildContext context) {
    final MoAdaptData? data = maybeOf(context);
    assert(data != null,
        'MoAdapt.of() was called with a context that has no MoAdapt ancestor.');
    return data!;
  }

  /// The [MoAdaptData] from the closest [MoAdapt] ancestor, or null if there
  /// is none.
  static MoAdaptData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_MoAdaptScope>()
        ?.data;
  }

  double _scaleFor(Size screenSize) {
    if (!enabled || screenSize.isEmpty) {
      return 1.0;
    }
    final double widthScale = screenSize.width / designSize.width;
    final double heightScale = screenSize.height / designSize.height;
    double scale = switch (scaleMode) {
      MoAdaptScaleMode.width => widthScale,
      MoAdaptScaleMode.height => heightScale,
      MoAdaptScaleMode.min => math.min(widthScale, heightScale),
      MoAdaptScaleMode.max => math.max(widthScale, heightScale),
    };
    if (minScale != null) {
      scale = math.max(scale, minScale!);
    }
    if (maxScale != null) {
      scale = math.min(scale, maxScale!);
    }
    return scale;
  }

  @override
  Widget build(BuildContext context) {
    assert(designSize.width > 0 && designSize.height > 0,
        'designSize must have positive width and height.');
    assert(minScale == null || minScale! > 0,
        'minScale must be greater than zero.');
    assert(maxScale == null || maxScale! > 0,
        'maxScale must be greater than zero.');
    assert(minScale == null || maxScale == null || minScale! <= maxScale!,
        'minScale must not exceed maxScale.');
    // Metrics from the FlutterView, so this works without a MediaQuery and
    // rebuilds on resize, rotation and keyboard.
    return MediaQuery.fromView(
      view: View.of(context),
      child: Builder(builder: _buildScaled),
    );
  }

  Widget _buildScaled(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final double scale = _scaleFor(screenSize);
    final Size adaptedSize =
        Size(screenSize.width / scale, screenSize.height / scale);

    return MediaQuery(
      // Metrics in design-space units, so SafeArea, dialogs and keyboard avoidance
      // agree with the scaled coordinates.
      data: mediaQuery.copyWith(
        size: adaptedSize,
        devicePixelRatio: mediaQuery.devicePixelRatio * scale,
        padding: mediaQuery.padding / scale,
        viewPadding: mediaQuery.viewPadding / scale,
        viewInsets: mediaQuery.viewInsets / scale,
        systemGestureInsets: mediaQuery.systemGestureInsets / scale,
        displayFeatures: <ui.DisplayFeature>[
          for (final ui.DisplayFeature feature in mediaQuery.displayFeatures)
            ui.DisplayFeature(
              bounds: Rect.fromLTRB(
                feature.bounds.left / scale,
                feature.bounds.top / scale,
                feature.bounds.right / scale,
                feature.bounds.bottom / scale,
              ),
              type: feature.type,
              state: feature.state,
            ),
        ],
      ),
      child: _MoAdaptScope(
        data: MoAdaptData(
          scale: scale,
          designSize: designSize,
          screenSize: screenSize,
          adaptedSize: adaptedSize,
        ),
        // Lay out at the design size, then scale uniformly to fill the screen.
        // FittedBox also maps pointer events.
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: adaptedSize,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MoAdaptScope extends InheritedWidget {
  const _MoAdaptScope({required this.data, required super.child});

  final MoAdaptData data;

  @override
  bool updateShouldNotify(_MoAdaptScope oldWidget) => data != oldWidget.data;
}
''';
}
