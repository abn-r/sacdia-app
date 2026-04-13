import 'package:equatable/equatable.dart';

/// Base URL for achievement badge images stored in Cloudflare R2 via backend.
///
/// The backend stores only the key (e.g. "badges/achievement-42.webp").
/// This prefix is prepended when the key doesn't already start with "http".
const String _achievementBadgeBase =
    'https://sacdia-files.r2.dev/achievements/';

String? _buildBadgeImageUrl(String? key) {
  if (key == null || key.isEmpty) return null;
  if (key.startsWith('http')) return key;
  return '$_achievementBadgeBase$key';
}

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
        return 'Bronce';
      case AchievementTier.silver:
        return 'Plata';
      case AchievementTier.gold:
        return 'Oro';
      case AchievementTier.platinum:
        return 'Platino';
      case AchievementTier.diamond:
        return 'Diamante';
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
  final String? badgeImageKey;
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
    this.badgeImageKey,
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

  /// Computed getter: full URL of the badge image.
  /// Returns null when [badgeImageKey] is null or empty.
  String? get badgeImageUrl => _buildBadgeImageUrl(badgeImageKey);

  @override
  List<Object?> get props => [
        achievementId,
        categoryId,
        name,
        description,
        badgeImageKey,
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
