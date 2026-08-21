import 'package:flutter/services.dart';

class SacAudioPlayerPosition {
  final Duration position;
  final Duration duration;
  final bool isPlaying;

  const SacAudioPlayerPosition({
    required this.position,
    required this.duration,
    required this.isPlaying,
  });

  factory SacAudioPlayerPosition.fromMap(Map<dynamic, dynamic> map) {
    final rawPosition = map['positionMs'];
    final rawDuration = map['durationMs'];
    return SacAudioPlayerPosition(
      position: Duration(milliseconds: _toInt(rawPosition)),
      duration: Duration(milliseconds: _toInt(rawDuration)),
      isPlaying: map['isPlaying'] == true,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value < 0 ? 0 : value.round();
    return 0;
  }
}

/// AVPlayer reports `isPlaying: false` while buffering. Only treat that as
/// finished when duration is known and the playhead reached the end.
bool hasAudioReachedEnd(SacAudioPlayerPosition playback) {
  if (playback.isPlaying) return false;
  if (playback.duration <= Duration.zero) return false;
  return playback.position >= playback.duration;
}

/// Minimal native audio bridge for signed resource URLs.
///
/// This intentionally avoids adding a package dependency while still keeping
/// playback inside the app via AVPlayer (iOS) and MediaPlayer (Android).
class SacAudioPlayerController {
  static const MethodChannel _channel = MethodChannel('sacdia/audio_player');

  Future<void> playUrl(String url) async {
    await _channel.invokeMethod<void>('playUrl', {'url': url});
  }

  Future<void> pause() async {
    await _channel.invokeMethod<void>('pause');
  }

  Future<void> resume() async {
    await _channel.invokeMethod<void>('resume');
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Hot reload / engine not ready. Closing the sheet must not crash.
    }
  }

  Future<SacAudioPlayerPosition> position() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('position');
      return SacAudioPlayerPosition.fromMap(result ?? const {});
    } on MissingPluginException {
      return const SacAudioPlayerPosition(
        position: Duration.zero,
        duration: Duration.zero,
        isPlaying: false,
      );
    }
  }
}
