import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/import_catalog_images.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_badge_image.dart';

import '../../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  group('ImportClassLogo', () {
    testWidgets('keeps the logo\'s own proportions, one side in the cache',
        (tester) async {
      await tester.pumpWidget(wrapTestApp(
        const Scaffold(
          body: ImportClassLogo(assetCode: 'CQ-02', size: 40),
        ),
      ));
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      // Only ONE side is limited in memory, so the logo is never squashed.
      final resize = image.image as ResizeImage;
      expect(resize.width, isNotNull);
      expect(resize.height, isNull);
      expect((resize.imageProvider as AssetImage).assetName,
          'assets/img/logos-clases/CQ-02.png');
    });

    testWidgets('falls back to the class name, then to a gray placeholder',
        (tester) async {
      await tester.pumpWidget(wrapTestApp(
        const Scaffold(body: ImportClassLogo(name: 'Amigo')),
      ));
      await tester.pumpAndSettle();
      expect(
        ((tester.widget<Image>(find.byType(Image)).image as ResizeImage)
                .imageProvider as AssetImage)
            .assetName,
        'assets/img/logos-clases/CQ-01.png',
      );

      await tester.pumpWidget(wrapTestApp(
        const Scaffold(body: ImportClassLogo(name: 'Desconocida')),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
    });
  });

  group('ImportHonorBadge', () {
    testWidgets('without an image it is the gray placeholder', (tester) async {
      await tester.pumpWidget(wrapTestApp(
        const Scaffold(body: ImportHonorBadge()),
      ));
      await tester.pumpAndSettle();

      final badge =
          tester.widget<HonorBadgeImage>(find.byType(HonorBadgeImage));
      expect(badge.imageUrl, isNull);
      expect(badge.memCacheHeight, isNull);
    });

    testWidgets('loads the row image with one side in the cache',
        (tester) async {
      const url = 'https://cdn.test/Especialidades/natacion.png';
      await tester.pumpWidget(wrapTestApp(
        const Scaffold(body: ImportHonorBadge(imageUrl: url, size: 40)),
      ));
      await tester.pump();

      final badge =
          tester.widget<HonorBadgeImage>(find.byType(HonorBadgeImage));
      expect(badge.imageUrl, url);
      expect(badge.memCacheWidth, 120);
      expect(badge.memCacheHeight, isNull);
    });
  });
}
