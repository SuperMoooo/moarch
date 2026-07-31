import 'package:moarch/src/templates/ui/audio_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  final output = AudioTemplates.appAudioPlayer();

  group('appAudioPlayer', () {
    test('owns the player and gives it back', () {
      expect(output, contains('final AudioPlayer _player = AudioPlayer();'));
      expect(output, contains('_player.dispose();'));
      expect(output, contains('_stateSubscription?.cancel();'));
    });

    test('loads whichever of the three source kinds it was given', () {
      expect(output, contains('_AppAudioKind.url => await _player.setUrl('));
      expect(
          output, contains('_AppAudioKind.asset => await _player.setAsset('));
      expect(
        output,
        contains('_AppAudioKind.file => await _player.setFilePath('),
      );
    });

    test('reloads when the source changes, not on every rebuild', () {
      expect(output, contains('if (widget.source != oldWidget.source)'));
      // Which needs value equality — two identical const sources are the same
      // source, and identity would reload on every parent rebuild.
      expect(output, contains('other is AppAudioSource && other.path == path'));
    });

    test('does not await play(), which completes at the end of the clip', () {
      expect(output, contains('unawaited(_player.play())'));
      expect(output, contains("import 'dart:async';"));
    });

    test('survives a source that resolves after the widget is gone', () {
      expect(output, contains('if (!mounted) return;'));
    });

    test('onCompleted fires once per play-through, not once per frame', () {
      // `completed` is a state the player sits in, so it arrives repeatedly.
      expect(output, contains('bool _reportedCompletion = false;'));
      expect(output, contains('if (finished && !_reportedCompletion)'));
      expect(output, contains('} else if (!finished) {'));
    });

    test('a finished clip restarts rather than sitting at the end', () {
      expect(
        output,
        contains('if (state.processingState == ProcessingState.completed)'),
      );
      expect(output, contains('_player.seek(Duration.zero);'));
    });

    test('a scrub is not dragged back by the position stream', () {
      expect(output, contains('double? _scrubbing;'));
      expect(output, contains('final value = _scrubbing ?? '));
      expect(output, contains('onChangeEnd: widget.allowScrub && maxMs > 0'));
    });

    test('seeking is clamped to the clip', () {
      expect(output, contains('if (target < Duration.zero)'));
      expect(output,
          contains('_player.seek(target > _duration ? _duration : target);'));
    });

    test('the bar sits at zero until a duration is known', () {
      // Otherwise the slider divides by a zero maximum and asserts.
      expect(output, contains('max: maxMs <= 0 ? 1 : maxMs,'));
      expect(output, contains('maxMs <= 0 ? 0.0 : positionMs'));
    });

    test('buffered progress rides in the secondary track', () {
      expect(output, contains('secondaryTrackValue:'));
      expect(output, contains('secondaryActiveTrackColor:'));
      expect(output, contains('_player.bufferedPositionStream'));
    });

    test('every part of it can be switched off', () {
      for (final flag in [
        'this.showControls = true,',
        'this.showSkip = true,',
        'this.showProgress = true,',
        'this.allowScrub = true,',
        'this.showTimes = true,',
        'this.showRemaining = false,',
        'this.showSpeed = false,',
      ]) {
        expect(output, contains(flag), reason: '$flag is not a parameter');
      }
    });

    test('the skip amounts are durations, not a fixed 15/30', () {
      expect(
          output, contains('this.skipBackward = const Duration(seconds: 15),'));
      expect(
          output, contains('this.skipForward = const Duration(seconds: 30),'));
      expect(output, contains('onTap: () => _skip(-widget.skipBackward),'));
      expect(output, contains('onTap: () => _skip(widget.skipForward),'));
      // The number is drawn inside the arrow, so any interval works without
      // needing an icon per value.
      expect(output, contains("label: '\$seconds seconds',"));
    });

    test('a read-only bar loses its thumb rather than just ignoring drags', () {
      expect(output, contains('thumbShape: widget.allowScrub'));
      expect(output, contains('SliderComponentShape.noThumb'));
      expect(output, contains('SliderComponentShape.noOverlay'));
    });

    test('the speed button cycles and wraps', () {
      expect(output, contains('(speed) => speed > _speed,'));
      expect(output, contains('orElse: () => widget.speeds.first,'));
      expect(output, contains('_player.setSpeed(next);'));
    });

    test('a failed load says so and offers a retry', () {
      expect(output, contains('widget.onError?.call(error);'));
      expect(output, contains('This audio could not be played.'));
      expect(output, contains('TextButton(onPressed: _load'));
    });

    test('formats an hour only once there is one', () {
      expect(output, contains('if (hours > 0) {'));
      expect(output, contains("return '\$minutes:\$paddedSeconds';"));
      expect(
          output, contains('duration.isNegative ? Duration.zero : duration'));
    });

    test('is in the catalog with just_audio', () {
      final spec =
          WidgetCatalog.all.firstWhere((s) => s.name == 'audio-player');
      expect(spec.file, 'audio/app_audio_player.dart');
      expect(spec.category, 'Media');
      expect(spec.packages, ['just_audio: ']);
      expect(spec.deps, ['input-style']);
      expect(spec.common, isFalse);
    });
  });
}
