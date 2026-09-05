import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_badge_image.dart';

void main() {
  group('HonorBadgeImage', () {
    testWidgets('should render honor image with natural shape and contain fit',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HonorBadgeImage(
              imageUrl: 'https://example.com/adventurer-badge.png',
              width: 80,
              height: 68,
              fallbackColor: Colors.black,
            ),
          ),
        ),
      );

      final image = tester.widget<SacNetworkImage>(
        find.byType(SacNetworkImage),
      );

      expect(image.fit, BoxFit.contain);
      expect(find.byType(ClipOval), findsNothing);
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('should use Medal05 fallback when image is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HonorBadgeImage(
              imageUrl: null,
              width: 80,
              height: 68,
              fallbackColor: Colors.black,
            ),
          ),
        ),
      );

      final fallback = tester.widget<Container>(find.byType(Container));
      final decoration = fallback.decoration as BoxDecoration;

      expect(decoration.shape, BoxShape.rectangle);
      expect(decoration.borderRadius, isNotNull);
      expect(find.byType(ClipOval), findsNothing);

      final fallbackIcon = tester.widget<HugeIcon>(find.byType(HugeIcon));
      expect(fallbackIcon.icon, HugeIcons.strokeRoundedMedal05);
    });
  });
}
