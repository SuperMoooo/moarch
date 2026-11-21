/// The UI kit entries the *Product features* checklist adds: the signature
/// pad and the onboarding gate.
class ProductWidgetsTemplates {
  ProductWidgetsTemplates._();

  /// `shared/widgets/inputs/app_signature_pad.dart`: a finger signature,
  /// exported as a PNG — proof of delivery, a consent form.
  static String appSignaturePad() => r'''
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';

/// Holds the strokes of an [AppSignaturePad]: read [isEmpty], [clear] it,
/// and [toPng] the signature for upload.
class AppSignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  /// Nothing has been drawn.
  bool get isEmpty => _strokes.every((stroke) => stroke.isEmpty);

  /// Wipes the pad.
  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  void _start(Offset point) {
    _strokes.add([point]);
    notifyListeners();
  }

  void _extend(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(point);
    notifyListeners();
  }

  /// The signature as a PNG with a transparent background, in [color],
  /// at [pixelRatio] times the pad's size. Null while [isEmpty].
  Future<Uint8List?> toPng({
    Color color = const Color(0xFF000000),
    double pixelRatio = 3,
  }) async {
    if (isEmpty || _size.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    _SignaturePainter(_strokes, color).paint(canvas, _size);
    final image = await recorder.endRecording().toImage(
      (_size.width * pixelRatio).ceil(),
      (_size.height * pixelRatio).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List();
  }
}

/// A field to sign with a finger.
///
/// ```dart
/// final signature = AppSignatureController();
/// AppSignaturePad(controller: signature);
/// final png = await signature.toPng();   // null while empty
/// ```
class AppSignaturePad extends StatelessWidget {
  const AppSignaturePad({
    super.key,
    required this.controller,
    this.height = 180,
    this.hint = 'Sign here',
  });

  final AppSignatureController controller;
  final double height;

  /// Shown on the empty pad.
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: hint,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppConstants.radius12),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            controller._size = constraints.biggest;
            return GestureDetector(
              // Claims the drag before an enclosing scroll view does.
              onPanStart: (details) => controller._start(details.localPosition),
              onPanUpdate: (details) =>
                  controller._extend(details.localPosition),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => CustomPaint(
                  painter: _SignaturePainter(
                    controller._strokes,
                    scheme.onSurface,
                  ),
                  child: controller.isEmpty
                      ? Center(
                          child: Text(
                            hint,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, this.color);

  final List<List<Offset>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.25, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  // The strokes list is mutated in place, so always repaint on notify.
  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
''';

  /// `shared/widgets/onboarding_gate.dart`: the first-launch pages, shown
  /// over the app until the user finishes them once.
  static String onboardingGate() => r'''
import 'package:material_ui/material_ui.dart';

import '../../config/di/injector.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/preferences_service.dart';
import 'buttons/app_button.dart';
import 'navigation/app_step_indicator.dart';

/// One onboarding page.
class OnboardingPage {
  const OnboardingPage({required this.title, required this.body, this.icon});

  final String title;
  final String body;
  final IconData? icon;
}

/// Shows the onboarding pages until the user finishes them, then the app —
/// and only the app on every launch after. Mounted in `MaterialApp.builder`.
///
/// The pages are [pages]: write the app's own. Reset it with
/// `OnboardingGate.reset()` (a "Show the intro again" setting).
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  // TODO: the app's own pages — three is plenty.
  static const pages = [
    OnboardingPage(
      title: 'Welcome',
      body: 'What the app does, in one sentence.',
      icon: Icons.waving_hand_outlined,
    ),
    OnboardingPage(
      title: 'The one thing to know',
      body: 'The feature people miss without being told.',
      icon: Icons.lightbulb_outline,
    ),
    OnboardingPage(
      title: 'Ready',
      body: 'What happens next.',
      icon: Icons.check_circle_outline,
    ),
  ];

  static const _seenKey = 'onboarding_seen';

  /// Shows the pages again on the next launch.
  static Future<void> reset() =>
      getIt<PreferencesService>().remove(_seenKey);

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  final _prefs = getIt<PreferencesService>();
  final _controller = PageController();
  late bool _seen = _prefs.getBool(OnboardingGate._seenKey) ?? false;
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await _prefs.setBool(OnboardingGate._seenKey, true);
    if (mounted) setState(() => _seen = true);
  }

  void _next() {
    if (_page == OnboardingGate.pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: AppConstants.duration300,
      curve: AppConstants.curveStandard,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_seen) return widget.child;
    const pages = OnboardingGate.pages;
    final last = _page == pages.length - 1;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space24),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: last
                    ? const SizedBox(height: 48)
                    : TextButton(onPressed: _finish, child: const Text('Skip')),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (page.icon != null)
                          Icon(
                            page.icon,
                            size: 72,
                            color: theme.colorScheme.primary,
                          ),
                        const SizedBox(height: AppConstants.space24),
                        Text(
                          page.title,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppConstants.space12),
                        Text(
                          page.body,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
              AppStepIndicator(
                currentStep: _page,
                stepCount: pages.length,
                type: AppStepIndicatorType.dots,
              ),
              const SizedBox(height: AppConstants.space24),
              AppButton(
                variant: AppButtonVariant.primary,
                label: last ? 'Get started' : 'Next',
                width: double.infinity,
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
''';
}
