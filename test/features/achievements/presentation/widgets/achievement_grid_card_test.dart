import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/achievements/domain/entities/achievement.dart';
import 'package:sacdia_app/features/achievements/domain/repositories/achievements_repository.dart';
import 'package:sacdia_app/features/achievements/presentation/widgets/achievement_grid_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Object imageCacheKey;

  setUpAll(() async {
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

  testWidgets(
    'decodes the badge by height only so a square badge is not flattened',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 120,
                  child: AchievementGridCard(
                    achievementWithProgress: AchievementWithProgress(
                      achievement: Achievement(
                        achievementId: 1,
                        categoryId: 1,
                        name: 'Primer Paso',
                        badgeImageUrl: _badgeImageUrl,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
}

const _transparentPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=';

const _badgeImageUrl = 'https://example.com/achievement-grid.png';

/// Alto del arte de la tarjeta (72) a 3x.
const _artCacheHeight = 216;
