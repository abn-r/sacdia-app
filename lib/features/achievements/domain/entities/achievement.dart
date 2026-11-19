import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

/// Default badge image shown for locked achievements or when the admin has not
/// yet uploaded a custom badge for an achievement.
///
/// Hosted in the public R2 bucket under achievements/achievements_default.png.
const String kDefaultLockedAchievementBadgeUrl =
    'https://pub-c8aa231ae66c46ff96fc5e811994d9d2.r2.dev/achievements/achievements_default.png';

/// Tipos de logro
enum AchievementType {
  threshold,
  streak,
  compound,
  milestone,
  collection,
  unknown;

  static AchievementType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'THRESHOLD':
        return AchievementType.threshold;
      case 'STREAK':
        return AchievementType.streak;
      case 'COMPOUND':
        return AchievementType.compound;
      case 'MILESTONE':
        return AchievementType.milestone;
      case 'COLLECTION':
        return AchievementType.collection;
      default:
        return AchievementType.unknown;
    }
  }
}

/// Tiers de logro
enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  unknown;

  static AchievementTier fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'BRONZE':
        return AchievementTier.bronze;
      case 'SILVER':
        return AchievementTier.silver;
      case 'GOLD':
        return AchievementTier.gold;
      case 'PLATINUM':
        return AchievementTier.platinum;
      case 'DIAMOND':
        return AchievementTier.diamond;
      default:
        return AchievementTier.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case AchievementTier.bronze:
        return tr('achievements.tiers.bronze');
      case AchievementTier.silver:
        return tr('achievements.tiers.silver');
      case AchievementTier.gold:
        return tr('achievements.tiers.gold');
      case AchievementTier.platinum:
        return tr('achievements.tiers.platinum');
      case AchievementTier.diamond:
        return tr('achievements.tiers.diamond');
      case AchievementTier.unknown:
        return '';
    }
  }
}

/// Entidad de logro del dominio
class Achievement extends Equatable {
  final int achievementId;
  final int categoryId;
  final String name;
  final String? description;

  /// URL pública de la insignia, ya resuelta por el backend
  /// (`badge_image_url`). El storage puede cambiar de host sin tocar la app.
  final String? badgeImageUrl;
  final AchievementType type;
  final String? scope;
  final AchievementTier tier;
  final int points;
  final Map<String, dynamic> criteria;
  final bool secret;
  final bool repeatable;
  final int? prerequisiteId;
  final bool active;

  const Achievement({
    required this.achievementId,
    required this.categoryId,
    required this.name,
    this.description,
    this.badgeImageUrl,
    this.type = AchievementType.milestone,
    this.scope,
    this.tier = AchievementTier.bronze,
    this.points = 0,
    this.criteria = const {},
    this.secret = false,
    this.repeatable = false,
    this.prerequisiteId,
    this.active = true,
  });

  @override
  List<Object?> get props => [
        achievementId,
        categoryId,
        name,
        description,
        badgeImageUrl,
        type,
        scope,
        tier,
        points,
        criteria,
        secret,
        repeatable,
        prerequisiteId,
        active,
      ];
}
