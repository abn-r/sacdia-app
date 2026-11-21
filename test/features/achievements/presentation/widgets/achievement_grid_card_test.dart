import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_card.dart';
import 'package:sacdia_app/features/achievements/domain/entities/achievement.dart';
import 'package:sacdia_app/features/achievements/domain/entities/user_achievement.dart';
import 'package:sacdia_app/features/achievements/domain/repositories/achievements_repository.dart';
import 'package:sacdia_app/features/achievements/presentation/utils/achievement_dates.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_art.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_grid_card.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_shine.dart';

import '../../../../support/l10n_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Object imageCacheKey;

  setUpAll(() async {
    loadSpanishTranslations();
    final codec = await ui.instantiateImageCodec(base64Decode(_transparentPng));
    final frame = await codec.getNextFrame();
    codec.dispose();

    final provider = ResizeImage.resizeIfNeeded(
      null,
      _artCacheHeight,
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

  Future<void> pumpCard(
    WidgetTester tester,
    AchievementWithProgress item, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: SacBadgeCard.heightFor(TextScaler.linear(textScale)),
                child: AchievementGridCard(achievementWithProgress: item),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'decodes the badge by height only so a square badge is not flattened',
    (tester) async {
      await pumpCard(
        tester,
        const AchievementWithProgress(
          achievement: Achievement(
            achievementId: 1,
            categoryId: 1,
            name: 'Primer Paso',
            badgeImageUrl: _badgeImageUrl,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );

      expect(image.memCacheWidth, isNull);
      expect(image.memCacheHeight, _artCacheHeight);
      expect(image.fit, BoxFit.contain);
    },
  );

  group('states', () {
    final completedAt = DateTime.now().subtract(const Duration(days: 1));

    testWidgets('obtained: full name, date with a check, no counter pill',
        (tester) async {
      await pumpCard(
        tester,
        AchievementWithProgress(
          achievement: _achievement(name: 'Conquistador Avanzado Completo'),
          userAchievement: UserAchievement(
            userAchievementId: 1,
            achievementId: 1,
            progressValue: 1,
            completed: true,
            completedAt: completedAt,
            timesCompleted: 1,
          ),
        ),
      );

      expect(find.text('Conquistador Avanzado Completo'), findsOneWidget);
      expect(find.text(achievementShortDate(completedAt)), findsOneWidget);
      // The "1" pill above the name is gone.
      expect(find.text('1'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // Full colour: nothing greys the badge.
      expect(
        find.descendant(
          of: find.byType(AchievementGridCard),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
      // The obtained badge catches the light every 10 seconds.
      final shine = tester.widget<AchievementShine>(
        find.byType(AchievementShine),
      );
      expect(shine.period, kAchievementGridShinePeriod);
      expect(kAchievementGridShinePeriod, const Duration(seconds: 10));
    });

    testWidgets('a badge not obtained yet never catches the light',
        (tester) async {
      await pumpCard(
        tester,
        AchievementWithProgress(achievement: _achievement()),
      );

      expect(find.byType(AchievementShine), findsNothing);
    });

    testWidgets('a repeatable achievement obtained twice still shows no pill',
        (tester) async {
      await pumpCard(
        tester,
        AchievementWithProgress(
          achievement: _achievement(repeatable: true),
          userAchievement: UserAchievement(
            userAchievementId: 1,
            achievementId: 1,
            progressValue: 1,
            completed: true,
            completedAt: completedAt,
            timesCompleted: 2,
          ),
        ),
      );

      expect(find.text('2'), findsNothing);
    });

    testWidgets('in progress: grey badge, accent bar and "6 de 10"',
        (tester) async {
      await pumpCard(
        tester,
        AchievementWithProgress(
          achievement: _achievement(),
          userAchievement: const UserAchievement(
            userAchievementId: 1,
            achievementId: 1,
            progressValue: 6,
            progressTarget: 10,
          ),
        ),
      );

      expect(find.text('6 de 10'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.6, 0.001));
      expect(
        find.descendant(
          of: find.byType(AchievementGridCard),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
        reason: 'the badge stays grey until it is obtained',
      );
    });

    testWidgets('not started: grey badge and no meta', (tester) async {
      await pumpCard(
        tester,
        AchievementWithProgress(achievement: _achievement()),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      // Only the name and the initials mark: no date, no count.
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.data),
        unorderedEquals(['Primer Paso', 'PP']),
      );
      expect(
        find.descendant(
          of: find.byType(AchievementGridCard),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
    });

    testWidgets('secret: own drawing and "Logro secreto", never "???"',
        (tester) async {
      await pumpCard(
        tester,
        AchievementWithProgress(
          achievement: _achievement(name: 'Leyenda Viviente', secret: true),
        ),
      );

      expect(find.text('Logro secreto'), findsOneWidget);
      expect(find.text('???'), findsNothing);
      expect(find.text('Leyenda Viviente'), findsNothing);
      expect(find.byType(SecretBadgeArt), findsOneWidget);
    });

    testWidgets('a secret that is obtained shows its real name',
        (tester) async {
      await pumpCard(
        tester,
        AchievementWithProgress(
          achievement: _achievement(name: 'Leyenda Viviente', secret: true),
          userAchievement: UserAchievement(
            userAchievementId: 1,
            achievementId: 1,
            progressValue: 1,
            completed: true,
            completedAt: completedAt,
          ),
        ),
      );

      expect(find.text('Leyenda Viviente'), findsOneWidget);
      expect(find.byType(SecretBadgeArt), findsNothing);
    });

    testWidgets('a long name fits at text scale 1.3 without overflow',
        (tester) async {
      await pumpCard(
        tester,
        AchievementWithProgress(
          achievement: _achievement(
            name: 'Conquistador Completo de las Grandes Montañas Doradas',
          ),
          userAchievement: const UserAchievement(
            userAchievementId: 1,
            achievementId: 1,
            progressValue: 10,
            progressTarget: 15,
          ),
        ),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('10 de 15'), findsOneWidget);
    });
  });
}

Achievement _achievement({
  String name = 'Primer Paso',
  bool secret = false,
  bool repeatable = false,
}) {
  return Achievement(
    achievementId: 1,
    categoryId: 1,
    name: name,
    secret: secret,
    repeatable: repeatable,
  );
}

const _transparentPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=';

const _badgeImageUrl = 'https://example.com/achievement-grid.png';

/// Alto del arte de la tarjeta (72) a 3x.
const _artCacheHeight = 216;
