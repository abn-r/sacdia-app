import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/rankings/data/models/member_ranking_dto.dart';
import 'package:sacdia_app/features/rankings/domain/entities/award_tier.dart';

void main() {
  group('AwardedCategoryDto.fromJson — tier parsing', () {
    Map<String, dynamic> baseJson({String? tier}) => {
          'id': 'cat-uuid-123',
          'name': 'Oro',
          'icon': null,
          'min_pct': 80.0,
          'max_pct': 100.0,
          if (tier != null) 'tier': tier,
        };

    test('tier = "GOLD" parses to AwardTier.gold', () {
      final dto = AwardedCategoryDto.fromJson(baseJson(tier: 'GOLD'));
      expect(dto.tier, AwardTier.gold);
      expect(dto.toEntity().tier, AwardTier.gold);
    });

    test('tier = "BRONZE" parses to AwardTier.bronze', () {
      final dto = AwardedCategoryDto.fromJson(baseJson(tier: 'BRONZE'));
      expect(dto.tier, AwardTier.bronze);
      expect(dto.toEntity().tier, AwardTier.bronze);
    });

    test('tier = "SILVER" parses to AwardTier.silver', () {
      final dto = AwardedCategoryDto.fromJson(baseJson(tier: 'SILVER'));
      expect(dto.tier, AwardTier.silver);
      expect(dto.toEntity().tier, AwardTier.silver);
    });

    test('tier = "DIAMOND" parses to AwardTier.diamond', () {
      final dto = AwardedCategoryDto.fromJson(baseJson(tier: 'DIAMOND'));
      expect(dto.tier, AwardTier.diamond);
      expect(dto.toEntity().tier, AwardTier.diamond);
    });

    test('tier = null (field absent) parses to AwardTier.unknown', () {
      // Field entirely absent from JSON.
      final dto = AwardedCategoryDto.fromJson(baseJson());
      expect(dto.tier, AwardTier.unknown);
      expect(dto.toEntity().tier, AwardTier.unknown);
    });

    test('tier = "INVALID" parses to AwardTier.unknown', () {
      final dto = AwardedCategoryDto.fromJson(baseJson(tier: 'INVALID'));
      expect(dto.tier, AwardTier.unknown);
      expect(dto.toEntity().tier, AwardTier.unknown);
    });

    test('tier = lowercase "gold" still parses correctly (toUpperCase)', () {
      final dto = AwardedCategoryDto.fromJson(baseJson(tier: 'gold'));
      expect(dto.tier, AwardTier.gold);
    });
  });

  group('AwardTier.fromString — static parser', () {
    test('null returns unknown', () {
      expect(AwardTier.fromString(null), AwardTier.unknown);
    });

    test('empty string returns unknown', () {
      expect(AwardTier.fromString(''), AwardTier.unknown);
    });

    test('mixed case is normalized', () {
      expect(AwardTier.fromString('Bronze'), AwardTier.bronze);
      expect(AwardTier.fromString('SILVER'), AwardTier.silver);
    });
  });
}
