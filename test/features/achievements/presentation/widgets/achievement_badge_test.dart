import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/features/achievements/domain/entities/achievement.dart';
import 'package:sacdia_app/features/achievements/domain/entities/user_achievement.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Object imageCacheKey;

  setUpAll(() async {
    final codec = await ui.instantiateImageCodec(
      base64Decode(_transparentPng),
      targetWidth: _badgeCacheSize,
      targetHeight: _badgeCacheSize,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();

    final provider = ResizeImage.resizeIfNeeded(
      _badgeCacheSize,
      _badgeCacheSize,
      const CachedNetworkImageProvider(_badgeImageUrl),
    );
    imageCacheKey = await provider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
      imageCacheKey,
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: frame.image)),
      ),
    );
  });

  tearDownAll(() {
    PaintingBinding.instance.imageCache.evict(imageCacheKey);
  });

  group('AchievementBadge motion accessibility', () {
    testWidgets(
      'keeps an unlocked diamond badge and star stable under reduced motion',
      (tester) async {
        await tester.pumpWidget(
          _badgeApp(
            reduceMotion: true,
            tier: AchievementTier.diamond,
          ),
        );
        await _finishImageDecode(tester);

        await tester.pumpAndSettle();

        expect(find.byType(AchievementBadge), findsOneWidget);
        expect(find.byType(ClipOval), findsOneWidget);
        expect(_starFinder, findsOneWidget);
        expect(_starScale(tester), 1.0);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets(
      'stops and resumes eligible loops when reduced motion toggles',
      (tester) async {
        var reduceMotion = false;
        late StateSetter setHarnessState;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (_, setState) {
              setHarnessState = setState;
              return _badgeApp(
                reduceMotion: reduceMotion,
                tier: AchievementTier.diamond,
              );
            },
          ),
        );
        await _finishImageDecode(tester);

        await tester.pump(const Duration(milliseconds: 300));
        expect(_starScale(tester), greaterThan(1.0));
        expect(tester.binding.hasScheduledFrame, isTrue);

        await tester.pump(const Duration(milliseconds: 900));
        final peakScale = _starScale(tester);
        expect(peakScale, closeTo(1.3, 0.001));

        await tester.pump(const Duration(milliseconds: 600));
        expect(
            _starScale(tester), allOf(greaterThan(1.0), lessThan(peakScale)));

        setHarnessState(() => reduceMotion = true);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(_starScale(tester), 1.0);
        expect(tester.binding.hasScheduledFrame, isFalse);

        setHarnessState(() => reduceMotion = false);
        await tester.pump();

        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pump(const Duration(milliseconds: 300));
        expect(_starScale(tester), greaterThan(1.0));
      },
    );

    testWidgets('stops loops across state and tier eligibility changes', (
      tester,
    ) async {
      var reduceMotion = false;
      var tier = AchievementTier.diamond;
      var visualState = AchievementVisualState.unlocked;
      late StateSetter setHarnessState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) {
            setHarnessState = setState;
            return _badgeApp(
              reduceMotion: reduceMotion,
              tier: tier,
              visualState: visualState,
            );
          },
        ),
      );
      await _finishImageDecode(tester);

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isTrue);

      setHarnessState(() => visualState = AchievementVisualState.locked);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      setHarnessState(() {
        visualState = AchievementVisualState.unlocked;
        tier = AchievementTier.platinum;
      });
      await tester.pump();

      expect(find.byType(ShaderMask), findsOneWidget);
      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isTrue);

      setHarnessState(() => tier = AchievementTier.gold);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      setHarnessState(() {
        reduceMotion = true;
        tier = AchievementTier.diamond;
      });
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsOneWidget);
      expect(_starScale(tester), 1.0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      setHarnessState(() => tier = AchievementTier.gold);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      setHarnessState(() => reduceMotion = false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_starFinder, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}

Widget _badgeApp({
  required bool reduceMotion,
  required AchievementTier tier,
  AchievementVisualState visualState = AchievementVisualState.unlocked,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: AchievementBadge(
            badgeImageUrl: _badgeImageUrl,
            tier: tier,
            visualState: visualState,
            isSecret: true,
          ),
        ),
      ),
    ),
  );
}

Finder get _starFinder => find.byWidgetPredicate(
      (widget) =>
          widget is HugeIcon && widget.icon == HugeIcons.strokeRoundedStar,
    );

double _starScale(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: _starFinder, matching: find.byType(Transform)),
  );
  return transform.transform.getMaxScaleOnAxis();
}

Future<void> _finishImageDecode(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

const _transparentPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=';

const _badgeImageUrl = 'https://example.com/achievement.png';
const _badgeCacheSize = 192;
