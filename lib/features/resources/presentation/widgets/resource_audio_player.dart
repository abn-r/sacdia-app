import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/media/sac_audio_player_controller.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import '../utils/resource_format.dart';

enum _AudioStatus { idle, loading, playing, paused, error }

/// In-sheet audio player: draggable scrubber, elapsed / remaining time, back
/// and forward 15 s around one large play/pause button.
class ResourceAudioPlayer extends StatefulWidget {
  const ResourceAudioPlayer({
    super.key,
    required this.resolveSignedUrl,
    required this.onError,
  });

  /// Signed URL of the audio file (cached or fetched on demand).
  final Future<String?> Function() resolveSignedUrl;
  final ValueChanged<String> onError;

  /// Distance of the skip buttons.
  static const Duration skip = Duration(seconds: 15);

  @override
  State<ResourceAudioPlayer> createState() => _ResourceAudioPlayerState();
}

class _ResourceAudioPlayerState extends State<ResourceAudioPlayer> {
  final SacAudioPlayerController _player = SacAudioPlayerController();
  _AudioStatus _status = _AudioStatus.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _scrubTo;
  Timer? _positionTimer;

  bool get _isBusy => _status == _AudioStatus.loading;
  bool get _isPlaying => _status == _AudioStatus.playing;
  bool get _hasStarted =>
      _status == _AudioStatus.playing || _status == _AudioStatus.paused;
  bool get _canSeek => _hasStarted && _duration > Duration.zero;

  @override
  void dispose() {
    _positionTimer?.cancel();
    _player.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isBusy) return;
    if (_isPlaying) return _pause();
    if (_hasStarted) return _resume();
    return _start();
  }

  Future<void> _start() async {
    setState(() => _status = _AudioStatus.loading);
    try {
      final url = await widget.resolveSignedUrl();
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        _fail('resources.error.media_url'.tr());
        return;
      }
      await _player.playUrl(url);
      if (!mounted) return;
      setState(() => _status = _AudioStatus.playing);
      _startPositionTimer();
    } catch (_) {
      _fail('resources.error.audio_playback'.tr());
    }
  }

  Future<void> _pause() async {
    try {
      await _player.pause();
      if (mounted) setState(() => _status = _AudioStatus.paused);
      _positionTimer?.cancel();
      await _refreshPosition();
    } catch (_) {
      _fail('resources.error.audio_playback'.tr());
    }
  }

  Future<void> _resume() async {
    try {
      // Finished tracks do not restart on their own.
      if (_duration > Duration.zero && _position >= _duration) {
        await _player.seekTo(Duration.zero);
        _position = Duration.zero;
      }
      await _player.resume();
      if (mounted) setState(() => _status = _AudioStatus.playing);
      _startPositionTimer();
    } catch (_) {
      _fail('resources.error.audio_playback'.tr());
    }
  }

  Future<void> _seek(Duration target) async {
    final clamped = _clamp(target);
    if (mounted) setState(() => _position = clamped);
    try {
      await _player.seekTo(clamped);
    } catch (_) {
      // Seeking is best-effort; the next poll shows the real position.
    }
    await _refreshPosition();
  }

  Future<void> _skip(Duration delta) => _seek(_position + delta);

  Duration _clamp(Duration value) {
    if (value < Duration.zero) return Duration.zero;
    if (_duration > Duration.zero && value > _duration) return _duration;
    return value;
  }

  void _fail(String message) {
    if (mounted) setState(() => _status = _AudioStatus.error);
    _positionTimer?.cancel();
    widget.onError(message);
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _refreshPosition(),
    );
    _refreshPosition();
  }

  Future<void> _refreshPosition() async {
    try {
      final playback = await _player.position();
      if (!mounted) return;
      setState(() {
        // The thumb belongs to the finger while it is down.
        if (_scrubTo == null) _position = playback.position;
        if (playback.duration > Duration.zero) _duration = playback.duration;
        if (_status == _AudioStatus.playing && hasAudioReachedEnd(playback)) {
          _status = _AudioStatus.paused;
          _positionTimer?.cancel();
        }
      });
    } catch (_) {
      // Position polling is best-effort; do not interrupt playback UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final shown = _scrubTo ?? _position;
    final remaining = _duration > shown ? _duration - shown : Duration.zero;
    final totalMs = _duration.inMilliseconds;
    final valueMs = shown.inMilliseconds.clamp(0, totalMs <= 0 ? 1 : totalMs);
    final timeStyle = TextStyle(
      fontSize: SacFontSize.bodySmall,
      color: c.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      children: [
        MergeSemantics(
          child: Semantics(
            label: 'resources.audio.scrubber'.tr(),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                activeTrackColor: accent.color,
                inactiveTrackColor: c.border,
                thumbColor: accent.color,
                overlayColor: accent.color.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 1,
                ),
              ),
              child: Slider(
                value: valueMs.toDouble(),
                min: 0,
                max: totalMs <= 0 ? 1 : totalMs.toDouble(),
                semanticFormatterCallback: (_) =>
                    'resources.audio.position_of'.tr(namedArgs: {
                  'position': formatResourceDuration(shown),
                  'total': _duration == Duration.zero
                      ? '--:--'
                      : formatResourceDuration(_duration),
                }),
                onChangeStart: _canSeek
                    ? (v) => setState(
                          () => _scrubTo = Duration(milliseconds: v.round()),
                        )
                    : null,
                onChanged: _canSeek
                    ? (v) => setState(
                          () => _scrubTo = Duration(milliseconds: v.round()),
                        )
                    : null,
                onChangeEnd: _canSeek
                    ? (v) async {
                        final target = Duration(milliseconds: v.round());
                        await _seek(target);
                        if (mounted) setState(() => _scrubTo = null);
                      }
                    : null,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Text(formatResourceDuration(shown), style: timeStyle),
                const Spacer(),
                Text(
                  _duration == Duration.zero
                      ? '--:--'
                      : '−${formatResourceDuration(remaining)}',
                  style: timeStyle,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SkipButton(
              icon: HugeIcons.strokeRoundedGoBackward15Sec,
              tooltip: 'resources.audio.back_15'.tr(),
              onPressed:
                  _canSeek ? () => _skip(-ResourceAudioPlayer.skip) : null,
            ),
            const SizedBox(width: 20),
            _PlayButton(
              isBusy: _isBusy,
              isPlaying: _isPlaying,
              hasStarted: _hasStarted,
              onPressed: _isBusy ? null : _toggle,
            ),
            const SizedBox(width: 20),
            _SkipButton(
              icon: HugeIcons.strokeRoundedGoForward15Sec,
              tooltip: 'resources.audio.forward_15'.tr(),
              onPressed:
                  _canSeek ? () => _skip(ResourceAudioPlayer.skip) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final HugeIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: HugeIcon(
        icon: icon,
        size: 28,
        color: onPressed == null ? c.textTertiary : c.ink700,
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isBusy,
    required this.isPlaying,
    required this.hasStarted,
    required this.onPressed,
  });

  final bool isBusy;
  final bool isPlaying;
  final bool hasStarted;
  final VoidCallback? onPressed;

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    final reduce = SacMotion.reduceMotionOf(context);
    final label = isBusy
        ? 'resources.audio.loading'.tr()
        : isPlaying
            ? 'resources.audio.pause'.tr()
            : hasStarted
                ? 'resources.audio.resume'.tr()
                : 'resources.audio.play'.tr();

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: accent.color,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: isBusy
                  ? SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: accent.onColor,
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: reduce ? Duration.zero : SacMotion.press,
                      child: HugeIcon(
                        key: ValueKey(isPlaying),
                        icon: isPlaying
                            ? HugeIcons.strokeRoundedPause
                            : HugeIcons.strokeRoundedPlay,
                        size: 28,
                        color: accent.onColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
