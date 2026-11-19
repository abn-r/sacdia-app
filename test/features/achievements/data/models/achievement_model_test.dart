import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/achievements/data/models/achievement_model.dart';

void main() {
  Map<String, dynamic> payload({Object? key, Object? url}) => {
        'achievement_id': 7,
        'category_id': 2,
        'name': 'Primer campamento',
        'badge_image_key': key,
        'badge_image_url': url,
      };

  group('AchievementModel badge image', () {
    test('uses the URL the backend resolved, not one built from the key', () {
      const resolved =
          'https://pub-c8aa231ae66c46ff96fc5e811994d9d2.r2.dev/achievements/badges/7.png';

      final entity = AchievementModel.fromJson(
        payload(key: 'badges/7.png', url: resolved),
      ).toEntity();

      expect(entity.badgeImageUrl, resolved);
    });

    test('never invents a storage host when only the key arrives', () {
      final entity =
          AchievementModel.fromJson(payload(key: 'badges/7.png')).toEntity();

      expect(entity.badgeImageUrl, isNull);
    });

    test('accepts a key that is already an absolute URL', () {
      const absolute = 'https://cdn.example.com/badges/7.png';

      final entity =
          AchievementModel.fromJson(payload(key: absolute)).toEntity();

      expect(entity.badgeImageUrl, absolute);
    });

    test('treats a blank URL as missing', () {
      final entity = AchievementModel.fromJson(payload(url: '   ')).toEntity();

      expect(entity.badgeImageUrl, isNull);
    });

    test('keeps the resolved URL through a toJson round trip', () {
      const resolved = 'https://cdn.example.com/badges/7.png';
      final model = AchievementModel.fromJson(
        payload(key: 'badges/7.png', url: resolved),
      );

      final restored = AchievementModel.fromJson(model.toJson());

      expect(restored.badgeImageUrl, resolved);
      expect(restored, model);
    });
  });
}
