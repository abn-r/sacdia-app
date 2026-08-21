import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/media/sac_audio_player_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sacdia/audio_player');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('stop does not throw when the native plugin is missing', () async {
    final player = SacAudioPlayerController();

    await expectLater(player.stop(), completes);
  });

  test('position returns a zero state when the native plugin is missing',
      () async {
    final player = SacAudioPlayerController();
    final playback = await player.position();

    expect(playback.isPlaying, isFalse);
    expect(playback.position, Duration.zero);
    expect(playback.duration, Duration.zero);
  });

  test('stop invokes the native channel when it is registered', () async {
    var stopped = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'stop') {
        stopped = true;
      }
      return null;
    });

    await SacAudioPlayerController().stop();

    expect(stopped, isTrue);
  });

  group('hasAudioReachedEnd', () {
    SacAudioPlayerPosition playback({
      int positionMs = 0,
      int durationMs = 0,
      bool isPlaying = false,
    }) {
      return SacAudioPlayerPosition(
        position: Duration(milliseconds: positionMs),
        duration: Duration(milliseconds: durationMs),
        isPlaying: isPlaying,
      );
    }

    test('stays playing while native reports buffering with no duration', () {
      expect(hasAudioReachedEnd(playback()), isFalse);
    });

    test('stays playing while native reports buffering mid-track', () {
      expect(
        hasAudioReachedEnd(
          playback(positionMs: 10 * 1000, durationMs: 160 * 1000),
        ),
        isFalse,
      );
    });

    test('detects the natural end of a track', () {
      expect(
        hasAudioReachedEnd(
          playback(positionMs: 160 * 1000, durationMs: 160 * 1000),
        ),
        isTrue,
      );
    });

    test('does not end while the native player still reports playing', () {
      expect(
        hasAudioReachedEnd(
          playback(
            positionMs: 160 * 1000,
            durationMs: 160 * 1000,
            isPlaying: true,
          ),
        ),
        isFalse,
      );
    });
  });
}
