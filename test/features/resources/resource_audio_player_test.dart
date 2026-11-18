import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/resources/presentation/widgets/resource_audio_player.dart';

import '../../support/l10n_test_support.dart';

const _channel = MethodChannel('sacdia/audio_player');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSpanishTranslations);

  late List<int> seeks;
  var positionMs = 64000;
  const durationMs = 192000;

  setUp(() {
    seeks = [];
    positionMs = 64000;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'seekTo':
          positionMs = (call.arguments as Map)['positionMs'] as int;
          seeks.add(positionMs);
          return null;
        case 'position':
          return {
            'positionMs': positionMs,
            'durationMs': durationMs,
            'isPlaying': true,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> pumpPlayer(WidgetTester tester,
      {bool reduceMotion = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: ResourceAudioPlayer(
              resolveSignedUrl: () async => 'https://files.example/a.mp3',
              onError: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  Future<void> startPlaying(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Reproducir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  // Cancels the position timer so the test ends clean.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('skip and scrub are disabled until the track is loaded',
      (tester) async {
    await pumpPlayer(tester);

    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    for (final tooltip in ['Retroceder 15 segundos', 'Adelantar 15 segundos']) {
      final button = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(button.onPressed, isNull);
    }
    await dispose(tester);
  });

  testWidgets('shows elapsed and remaining time while playing', (tester) async {
    await pumpPlayer(tester);
    await startPlaying(tester);

    expect(find.text('1:04'), findsOneWidget);
    expect(find.text('−2:08'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('play button announces its state', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPlayer(tester);

    expect(find.bySemanticsLabel('Reproducir'), findsOneWidget);
    await startPlaying(tester);
    expect(find.bySemanticsLabel('Pausar'), findsOneWidget);

    await dispose(tester);
    handle.dispose();
  });

  testWidgets('skip buttons are labelled and jump 15 seconds', (tester) async {
    await pumpPlayer(tester);
    expect(find.byTooltip('Retroceder 15 segundos'), findsOneWidget);
    expect(find.byTooltip('Adelantar 15 segundos'), findsOneWidget);

    await startPlaying(tester);
    await tester.tap(find.byTooltip('Adelantar 15 segundos'));
    await tester.pump();
    await tester.tap(find.byTooltip('Retroceder 15 segundos'));
    await tester.pump();

    expect(seeks, [79000, 64000]);
    await dispose(tester);
  });

  testWidgets('the scrubber is a labelled slider that seeks on release',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPlayer(tester);
    await startPlaying(tester);

    expect(find.bySemanticsLabel(RegExp('Posición de reproducción')),
        findsOneWidget);
    final semantics = tester.getSemantics(find.byType(Slider));
    final data = semantics.getSemanticsData();
    expect(data.label, 'Posición de reproducción');
    expect(data.value, '1:04 de 3:12');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);

    await tester.tap(find.byType(Slider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(seeks, hasLength(1));
    // A tap near the middle of a 3:12 track lands near 1:36.
    expect(seeks.single, closeTo(96000, 12000));

    await dispose(tester);
    handle.dispose();
  });

  testWidgets('reduce motion removes the play/pause icon transition',
      (tester) async {
    await pumpPlayer(tester, reduceMotion: true);
    await startPlaying(tester);

    final switcher =
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
    expect(switcher.duration, Duration.zero);
    await dispose(tester);
  });
}
