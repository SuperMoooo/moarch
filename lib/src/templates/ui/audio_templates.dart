/// Templates for the audio family: a player built on `just_audio` that a
/// screen configures rather than wires.
abstract final class AudioTemplates {
  /// Returns the generated appAudioPlayer template.
  static String appAudioPlayer() => r'''
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../inputs/app_input_style.dart';
import '../../../core/constants/app_constants.dart';

/// Where an [AppAudioPlayer] reads its audio from — one type for the three
/// things `just_audio` loads differently.
class AppAudioSource {
  /// A remote file, streamed. Progressive download — the player reports
  /// buffered progress under the playhead.
  const AppAudioSource.url(this.path) : _kind = _AppAudioKind.url;

  /// A file in the app bundle, e.g. `assets/audio/intro.mp3`. Remember the
  /// `assets:` entry in pubspec.yaml.
  const AppAudioSource.asset(this.path) : _kind = _AppAudioKind.asset;

  /// A file on the device, by absolute path — a recording, a download.
  const AppAudioSource.file(this.path) : _kind = _AppAudioKind.file;

  final String path;
  final _AppAudioKind _kind;

  @override
  bool operator ==(Object other) =>
      other is AppAudioSource && other.path == path && other._kind == _kind;

  @override
  int get hashCode => Object.hash(path, _kind);
}

enum _AppAudioKind { url, asset, file }

/// How much of the player is drawn.
///
/// - [full]: artwork and titles above, progress, then a centered transport row
///   — a screen's main player.
/// - [compact]: one row — play/pause, progress, remaining. Drops into a list
///   tile or a chat bubble.
enum AppAudioPlayerStyle { full, compact }

/// What repeats when the clip ends.
enum AppAudioRepeat { off, one }

/// An audio player built on
/// [just_audio](https://pub.dev/packages/just_audio), configured rather than
/// wired: it owns the `AudioPlayer`, loads the source, and disposes both.
///
/// ```dart
/// AppAudioPlayer(
///   source: const AppAudioSource.url('https://example.com/episode.mp3'),
///   title: 'Episode 12',
///   subtitle: 'The one about Flutter',
/// )
/// ```
///
/// Every part is switchable, so the same widget is a voice-note bubble:
///
/// ```dart
/// AppAudioPlayer(
///   source: AppAudioSource.file(recording.path),
///   style: AppAudioPlayerStyle.compact,
///   showSkip: false,       // a 6-second voice note has nothing to skip
///   showSpeed: false,
///   showTimes: true,
/// )
/// ```
///
/// It plays audio and nothing else. Lock-screen controls and audio-session
/// handling are `just_audio_background`'s job.
class AppAudioPlayer extends StatefulWidget {
  const AppAudioPlayer({
    super.key,
    required this.source,
    this.title,
    this.subtitle,
    this.artwork,
    this.style = AppAudioPlayerStyle.full,
    this.showControls = true,
    this.showSkip = true,
    this.skipBackward = const Duration(seconds: 15),
    this.skipForward = const Duration(seconds: 30),
    this.showProgress = true,
    this.allowScrub = true,
    this.showTimes = true,
    this.showRemaining = false,
    this.showSpeed = false,
    this.speeds = const [0.75, 1.0, 1.25, 1.5, 2.0],
    this.initialSpeed = 1.0,
    this.repeat = AppAudioRepeat.off,
    this.autoPlay = false,
    this.onCompleted,
    this.onError,
    this.variant,
    this.padding = AppConstants.padding16,
  });

  final AppAudioSource source;

  final String? title;
  final String? subtitle;

  /// Drawn beside the titles in [AppAudioPlayerStyle.full] — an `AppImage`,
  /// an `AppAvatar`, an icon. Sized by whatever you pass.
  final Widget? artwork;

  final AppAudioPlayerStyle style;

  /// The transport row. Off leaves a progress bar that still scrubs — a
  /// waveform-style read-only clip with a draggable playhead.
  final bool showControls;

  /// The two skip buttons either side of play/pause.
  final bool showSkip;

  /// How far the back and forward buttons jump. Podcasts conventionally go
  /// back further than they go forward, which is why these differ by default;
  /// set them equal for a symmetric transport.
  final Duration skipBackward;
  final Duration skipForward;

  /// The progress bar.
  final bool showProgress;

  /// Whether dragging the progress bar seeks. Off makes it a read-only
  /// indicator that still shows position.
  final bool allowScrub;

  /// The `0:12 / 3:40` line under the bar.
  final bool showTimes;

  /// Shows time left (`-3:28`) rather than total on the right. Position on
  /// the left is unaffected.
  final bool showRemaining;

  /// The speed button. Off is right for a voice note; on for anything long.
  final bool showSpeed;

  /// What the speed button cycles through, in order.
  final List<double> speeds;

  /// Where the cycle starts. Need not be in [speeds] — the button moves to
  /// the next value above it.
  final double initialSpeed;

  final AppAudioRepeat repeat;

  /// Starts as soon as the source is loaded. Consider whether the screen has
  /// earned that before turning it on.
  final bool autoPlay;

  /// Called once each time playback reaches the end.
  final VoidCallback? onCompleted;

  /// Called when the source fails to load or play. Without it the widget
  /// shows its own inline error line.
  final void Function(Object error)? onError;

  /// Colors the playhead, the buffered track and the transport. Null follows
  /// [AppInputConfig.defaults], like the rest of the kit.
  final AppInputVariant? variant;

  final EdgeInsetsGeometry padding;

  /// `1:05`, or `1:02:03` once there is an hour to show. Exposed because a
  /// screen showing its own duration next to a player should format it the
  /// same way.
  static String formatDuration(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    final paddedSeconds = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
    }
    return '$minutes:$paddedSeconds';
  }

  @override
  State<AppAudioPlayer> createState() => _AppAudioPlayerState();
}

class _AppAudioPlayerState extends State<AppAudioPlayer> {
  static const double _artworkSize = 56;
  static const double _bufferedOpacity = 0.24;
  static const double _trackOpacity = 0.12;
  static const double _trackHeight = 4;
  static const double _playDimension = 56;
  static const double _skipDimension = 44;

  final AudioPlayer _player = AudioPlayer();

  /// Held rather than streamed: the slider needs a maximum on every frame,
  /// and nesting a second StreamBuilder for it would rebuild the whole
  /// transport on each position tick.
  Duration _duration = Duration.zero;

  /// Where the thumb is while a drag is in flight. Position keeps arriving
  /// from the player during a scrub, and letting it win would drag the thumb
  /// back out from under the finger.
  double? _scrubbing;

  double _speed = 1;
  Object? _error;

  StreamSubscription<PlayerState>? _stateSubscription;

  /// `completed` is a state the player *stays* in, not an event, so it
  /// arrives on every rebuild until something seeks away from the end.
  /// Without this latch [AppAudioPlayer.onCompleted] fires repeatedly.
  bool _reportedCompletion = false;

  @override
  void initState() {
    super.initState();
    _speed = widget.initialSpeed;
    _stateSubscription = _player.playerStateStream.listen((state) {
      final finished = state.processingState == ProcessingState.completed;
      if (finished && !_reportedCompletion) {
        _reportedCompletion = true;
        widget.onCompleted?.call();
      } else if (!finished) {
        _reportedCompletion = false;
      }
    });
    _load();
  }

  @override
  void didUpdateWidget(AppAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) {
      _duration = Duration.zero;
      _scrubbing = null;
      _load();
    }
    if (widget.repeat != oldWidget.repeat) {
      _player.setLoopMode(
        widget.repeat == AppAudioRepeat.one ? LoopMode.one : LoopMode.off,
      );
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await _player.setLoopMode(
        widget.repeat == AppAudioRepeat.one ? LoopMode.one : LoopMode.off,
      );
      await _player.setSpeed(_speed);

      final duration = switch (widget.source._kind) {
        _AppAudioKind.url => await _player.setUrl(widget.source.path),
        _AppAudioKind.asset => await _player.setAsset(widget.source.path),
        _AppAudioKind.file => await _player.setFilePath(widget.source.path),
      };

      // The widget can be gone by the time a remote source resolves.
      if (!mounted) return;
      setState(() => _duration = duration ?? Duration.zero);
      // `play()` completes when playback *finishes*, not when it starts, so
      // awaiting it here would hold `_load` open for the length of the clip.
      if (widget.autoPlay) unawaited(_player.play());
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      widget.onError?.call(error);
    }
  }

  Duration get _position {
    final scrubbing = _scrubbing;
    if (scrubbing == null) return _player.position;
    return Duration(milliseconds: scrubbing.round());
  }

  void _togglePlay(PlayerState state) {
    HapticFeedback.selectionClick();
    if (state.processingState == ProcessingState.completed) {
      // A finished clip resumes from the start rather than sitting at the end
      // doing nothing, which is what a second tap on play otherwise does.
      _player.seek(Duration.zero);
      _player.play();
      return;
    }
    state.playing ? _player.pause() : _player.play();
  }

  void _skip(Duration by) {
    HapticFeedback.selectionClick();
    final target = _player.position + by;
    if (target < Duration.zero) {
      _player.seek(Duration.zero);
      return;
    }
    _player.seek(target > _duration ? _duration : target);
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    if (widget.speeds.isEmpty) return;
    final next = widget.speeds.firstWhere(
      (speed) => speed > _speed,
      orElse: () => widget.speeds.first,
    );
    setState(() => _speed = next);
    _player.setSpeed(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppInputStyle.accentOf(context, widget.variant);
    final error = _error;

    if (error != null) {
      return Padding(
        padding: widget.padding,
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: AppConstants.iconMedium,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: AppConstants.space12),
            Expanded(
              child: Text(
                'This audio could not be played.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Padding(
      padding: widget.padding,
      child: widget.style == AppAudioPlayerStyle.compact
          ? _buildCompact(context, theme, accent)
          : _buildFull(context, theme, accent),
    );
  }

  // ── Layouts ────────────────────────────────────────────────────────────────

  Widget _buildFull(BuildContext context, ThemeData theme, Color accent) {
    final heading = widget.title;
    final note = widget.subtitle;
    final art = widget.artwork;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null || note != null || art != null) ...[
          Row(
            children: [
              if (art != null) ...[
                SizedBox.square(dimension: _artworkSize, child: art),
                const SizedBox(width: AppConstants.space12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (heading != null)
                      Text(
                        heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    if (note != null)
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.showSpeed) _speedButton(theme, accent),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
        ],
        if (widget.showProgress) _progress(accent),
        if (widget.showTimes) _times(theme),
        if (widget.showControls) ...[
          const SizedBox(height: AppConstants.space8),
          _transport(theme, accent),
        ],
      ],
    );
  }

  Widget _buildCompact(BuildContext context, ThemeData theme, Color accent) {
    return Row(
      children: [
        if (widget.showControls) ...[
          _playButton(theme, accent, dimension: _skipDimension),
          const SizedBox(width: AppConstants.space8),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showProgress) _progress(accent),
              if (widget.showTimes) _times(theme),
            ],
          ),
        ),
        if (widget.showSpeed) ...[
          const SizedBox(width: AppConstants.space8),
          _speedButton(theme, accent),
        ],
      ],
    );
  }

  // ── Pieces ─────────────────────────────────────────────────────────────────

  Widget _progress(Color accent) {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        final maxMs = _duration.inMilliseconds.toDouble();
        final positionMs = (snapshot.data ?? Duration.zero).inMilliseconds
            .toDouble();
        // Before the duration is known there is nothing to be a fraction of,
        // so the bar sits at zero rather than jumping when it arrives.
        final value = _scrubbing ?? (maxMs <= 0 ? 0.0 : positionMs);

        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: _trackHeight,
            activeTrackColor: accent,
            inactiveTrackColor: accent.withValues(alpha: _trackOpacity),
            // The buffered position rides in the secondary track, which is
            // what it is for.
            secondaryActiveTrackColor: accent.withValues(
              alpha: _bufferedOpacity,
            ),
            thumbColor: accent,
            overlayColor: accent.withValues(alpha: _trackOpacity),
            thumbShape: widget.allowScrub
                ? null
                : SliderComponentShape.noThumb,
            overlayShape: widget.allowScrub
                ? null
                : SliderComponentShape.noOverlay,
          ),
          child: StreamBuilder<Duration>(
            stream: _player.bufferedPositionStream,
            builder: (context, buffered) {
              return Slider(
                value: value.clamp(0, maxMs <= 0 ? 1 : maxMs),
                max: maxMs <= 0 ? 1 : maxMs,
                secondaryTrackValue: (buffered.data ?? Duration.zero)
                    .inMilliseconds
                    .toDouble()
                    .clamp(0, maxMs <= 0 ? 1 : maxMs),
                onChanged: widget.allowScrub && maxMs > 0
                    ? (v) => setState(() => _scrubbing = v)
                    : null,
                onChangeEnd: widget.allowScrub && maxMs > 0
                    ? (v) {
                        _player.seek(Duration(milliseconds: v.round()));
                        setState(() => _scrubbing = null);
                      }
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  Widget _times(ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        final position = _scrubbing != null
            ? _position
            : (snapshot.data ?? Duration.zero);
        final trailing = widget.showRemaining
            ? '-${AppAudioPlayer.formatDuration(_duration - position)}'
            : AppAudioPlayer.formatDuration(_duration);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.space4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppAudioPlayer.formatDuration(position), style: style),
              Text(trailing, style: style),
            ],
          ),
        );
      },
    );
  }

  Widget _transport(ThemeData theme, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.showSkip) ...[
          _skipButton(
            theme,
            accent,
            icon: Icons.replay,
            seconds: widget.skipBackward.inSeconds,
            onTap: () => _skip(-widget.skipBackward),
          ),
          const SizedBox(width: AppConstants.space16),
        ],
        _playButton(theme, accent, dimension: _playDimension),
        if (widget.showSkip) ...[
          const SizedBox(width: AppConstants.space16),
          _skipButton(
            theme,
            accent,
            icon: Icons.refresh,
            seconds: widget.skipForward.inSeconds,
            onTap: () => _skip(widget.skipForward),
          ),
        ],
      ],
    );
  }

  Widget _playButton(
    ThemeData theme,
    Color accent, {
    required double dimension,
  }) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final state =
            snapshot.data ?? PlayerState(false, ProcessingState.idle);
        final waiting = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;

        return Material(
          color: accent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          // The glyph flips between two actions, so the name has to flip with
          // it — the skip and speed buttons beside this one name themselves
          // the same way.
          child: Semantics(
            button: true,
            label: state.playing ? 'Pause' : 'Play',
            child: InkWell(
              // Waiting is not disabled: a buffering clip is still pausable,
              // and greying the only control out mid-stall reads as broken.
              onTap: () => _togglePlay(state),
              child: SizedBox.square(
                dimension: dimension,
                child: waiting
                    ? Padding(
                        padding: const EdgeInsets.all(AppConstants.space16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppInputStyle.onAccentOf(
                            context,
                            widget.variant,
                          ),
                        ),
                      )
                    : Icon(
                        state.playing ? Icons.pause : Icons.play_arrow,
                        color:
                            AppInputStyle.onAccentOf(context, widget.variant),
                        size: AppConstants.iconMedium,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _skipButton(
    ThemeData theme,
    Color accent, {
    required IconData icon,
    required int seconds,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$seconds seconds',
      child: InkResponse(
        onTap: onTap,
        radius: _skipDimension / 2,
        child: SizedBox.square(
          dimension: _skipDimension,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: AppConstants.iconMedium,
                color: theme.colorScheme.onSurface,
              ),
              // The number rides inside the arrow, so one glyph serves any
              // skip amount rather than needing an icon per interval.
              Text(
                '$seconds',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: AppConstants.fontSize11 - 2,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedButton(ThemeData theme, Color accent) {
    final label = _speed == _speed.roundToDouble()
        ? '${_speed.toInt()}x'
        : '${_speed}x';

    return Semantics(
      button: true,
      label: 'Playback speed $label',
      child: InkWell(
        onTap: _cycleSpeed,
        borderRadius: AppConstants.borderRadiusFull,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.space12,
            vertical: AppConstants.space8,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
''';
}
