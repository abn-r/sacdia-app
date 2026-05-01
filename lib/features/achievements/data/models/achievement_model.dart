import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/achievement.dart';

/// Modelo de logro para la capa de datos
class AchievementModel extends Equatable {
  final int achievementId;
  final int categoryId;
  final String name;
  final String? description;
  final String? badgeImageKey;
  final String? typeRaw;
  final String? scope;
  final String? tierRaw;
  final int points;
  final Map<String, dynamic> criteria;
  final bool secret;
  final bool repeatable;
  final int? prerequisiteId;
  final bool active;

  const AchievementModel({
    required this.achievementId,
    required this.categoryId,
    required this.name,
    this.description,
    this.badgeImageKey,
    this.typeRaw,
    this.scope,
    this.tierRaw,
    this.points = 0,
    this.criteria = const {},
    this.secret = false,
    this.repeatable = false,
    this.prerequisiteId,
    this.active = true,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    // Parse criteria — can be a Map or a stringified JSON (fallback to empty)
    Map<String, dynamic> criteria = const {};
    final rawCriteria = json['criteria'];
    if (rawCriteria is Map<String, dynamic>) {
      criteria = rawCriteria;
    }

    return AchievementModel(
      achievementId: safeInt(
        json['achievement_id'] ?? json['id'],
      ),
      categoryId: safeInt(
        json['category_id'] ?? json['achievement_category_id'],
      ),
      name: safeString(json['name']),
      description: safeStringOrNull(json['description']),
      badgeImageKey: safeStringOrNull(json['badge_image_key'] ?? json['badge_image']),
      typeRaw: safeStringOrNull(json['type']),
      scope: safeStringOrNull(json['scope']),
      tierRaw: safeStringOrNull(json['tier']),
      points: safeInt(json['points']),
      criteria: criteria,
      secret: safeBool(json['secret']),
      repeatable: safeBool(json['repeatable']),
      prerequisiteId: safeIntOrNull(json['prerequisite_id']),
      active: safeBool(json['active'], true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievement_id': achievementId,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'badge_image_key': badgeImageKey,
      'type': typeRaw,
      'scope': scope,
      'tier': tierRaw,
      'points': points,
      'criteria': criteria,
      'secret': secret,
      'repeatable': repeatable,
      'prerequisite_id': prerequisiteId,
      'active': active,
    };
  }

  Achievement toEntity() {
    return Achievement(
      achievementId: achievementId,
      categoryId: categoryId,
      name: name,
      description: description,
      badgeImageKey: badgeImageKey,
      type: AchievementType.fromString(typeRaw),
      scope: scope,
      tier: AchievementTier.fromString(tierRaw),
      points: points,
      criteria: criteria,
      secret: secret,
      repeatable: repeatable,
      prerequisiteId: prerequisiteId,
      active: active,
    );
  }

  @override
  List<Object?> get props => [
        achievementId,
        categoryId,
        name,
        description,
        badgeImageKey,
        typeRaw,
        scope,
        tierRaw,
        points,
        criteria,
        secret,
        repeatable,
        prerequisiteId,
        active,
      ];
}
