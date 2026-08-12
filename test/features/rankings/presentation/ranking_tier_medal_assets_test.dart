import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/rankings/presentation/utils/ranking_tier_medal_assets.dart';

void main() {
  group('rankingTierRemoteMedalUrl', () {
    test('maps spanish and english slugs to english R2 filenames', () {
      expect(
        rankingTierRemoteMedalUrl('bronce'),
        'https://pub-c8aa231ae66c46ff96fc5e811994d9d2.r2.dev/ranges/bronze.png',
      );
      expect(
        rankingTierRemoteMedalUrl('cobre'),
        endsWith('/bronze.png'),
      );
      expect(
        rankingTierRemoteMedalUrl('plata'),
        endsWith('/silver.png'),
      );
      expect(
        rankingTierRemoteMedalUrl('oro'),
        endsWith('/gold.png'),
      );
      expect(
        rankingTierRemoteMedalUrl('platino'),
        endsWith('/platinum.png'),
      );
      expect(
        rankingTierRemoteMedalUrl('diamante'),
        endsWith('/diamond.png'),
      );
    });

    test('returns null for unknown slug', () {
      expect(rankingTierRemoteMedalUrl(null), isNull);
      expect(rankingTierRemoteMedalUrl(''), isNull);
      expect(rankingTierRemoteMedalUrl('unknown'), isNull);
    });

  });
}
