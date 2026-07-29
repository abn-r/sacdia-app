import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/rankings/presentation/utils/ranking_tier_medal_assets.dart';

void main() {
  group('rankingTierLocalSvgAsset', () {
    test('maps spanish and english slugs', () {
      expect(
        rankingTierLocalSvgAsset('bronce'),
        'assets/svg/fiel_bronce.svg',
      );
      expect(
        rankingTierLocalSvgAsset('Bronze'),
        'assets/svg/fiel_bronce.svg',
      );
      expect(
        rankingTierLocalSvgAsset('plata'),
        'assets/svg/fiel_plata.svg',
      );
      expect(
        rankingTierLocalSvgAsset('oro'),
        'assets/svg/fiel_oro.svg',
      );
      expect(
        rankingTierLocalSvgAsset('diamante'),
        'assets/svg/fiel_diamante.svg',
      );
    });

    test('returns null for unknown or empty', () {
      expect(rankingTierLocalSvgAsset(null), isNull);
      expect(rankingTierLocalSvgAsset(''), isNull);
      expect(rankingTierLocalSvgAsset('unknown'), isNull);
    });
  });
}
