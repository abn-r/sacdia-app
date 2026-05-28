import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/annual_ranking_progress.dart';

class AnnualRankingProgressModel {
  final int sectionId;
  final int clubId;
  final String clubName;
  final RankingClubTypeModel clubType;
  final RankingYearModel year;
  final int currentPoints;
  final int maxPoints;
  final double progressPercentage;
  final RankingTierModel? currentTier;
  final RankingTierModel? nextTier;
  final List<RankingComponentProgressModel> components;
  final List<RankingPendingItemModel> pendingItems;

  const AnnualRankingProgressModel({
    required this.sectionId,
    required this.clubId,
    required this.clubName,
    required this.clubType,
    required this.year,
    required this.currentPoints,
    required this.maxPoints,
    required this.progressPercentage,
    required this.currentTier,
    required this.nextTier,
    required this.components,
    required this.pendingItems,
  });

  factory AnnualRankingProgressModel.fromJson(Map<String, dynamic> json) {
    return AnnualRankingProgressModel(
      sectionId: _requiredInt(json, 'section_id'),
      clubId: _requiredInt(json, 'club_id'),
      clubName: _requiredString(json, 'club_name'),
      clubType: RankingClubTypeModel.fromJson(_requiredMap(json, 'club_type')),
      year: RankingYearModel.fromJson(_requiredMap(json, 'year')),
      currentPoints: _requiredInt(json, 'current_points'),
      maxPoints: _requiredInt(json, 'max_points'),
      progressPercentage: _requiredDouble(json, 'progress_percentage'),
      currentTier: json['current_tier'] == null
          ? null
          : RankingTierModel.fromJson(_requiredMap(json, 'current_tier')),
      nextTier: json['next_tier'] == null
          ? null
          : RankingTierModel.fromJson(_requiredMap(json, 'next_tier')),
      components: _requiredList(json, 'components')
          .map(
            (item) => RankingComponentProgressModel.fromJson(
              _asMap(item, 'components[]'),
            ),
          )
          .toList(),
      pendingItems: _optionalList(json, 'pending_items')
          .map(
            (item) => RankingPendingItemModel.fromJson(
              _asMap(item, 'pending_items[]'),
            ),
          )
          .toList(),
    );
  }

  AnnualRankingProgress toEntity() {
    return AnnualRankingProgress(
      sectionId: sectionId,
      clubId: clubId,
      clubName: clubName,
      clubType: clubType.toEntity(),
      year: year.toEntity(),
      currentPoints: currentPoints,
      maxPoints: maxPoints,
      progressPercentage: progressPercentage,
      currentTier: currentTier?.toEntity(),
      nextTier: nextTier?.toEntity(),
      components: components.map((component) => component.toEntity()).toList(),
      pendingItems: pendingItems.map((item) => item.toEntity()).toList(),
    );
  }
}

class RankingClubTypeModel {
  final int clubTypeId;
  final String name;

  const RankingClubTypeModel({
    required this.clubTypeId,
    required this.name,
  });

  factory RankingClubTypeModel.fromJson(Map<String, dynamic> json) {
    return RankingClubTypeModel(
      clubTypeId: _requiredInt(json, 'club_type_id'),
      name: _requiredString(json, 'name'),
    );
  }

  RankingClubType toEntity() {
    return RankingClubType(
      clubTypeId: clubTypeId,
      name: name,
    );
  }
}

class RankingYearModel {
  final int ecclesiasticalYearId;

  const RankingYearModel({required this.ecclesiasticalYearId});

  factory RankingYearModel.fromJson(Map<String, dynamic> json) {
    return RankingYearModel(
      ecclesiasticalYearId: _requiredInt(json, 'ecclesiastical_year_id'),
    );
  }

  RankingYear toEntity() {
    return RankingYear(ecclesiasticalYearId: ecclesiasticalYearId);
  }
}

class RankingTierModel {
  final String name;
  final String slug;
  final int fromPoints;
  final int toPoints;
  final int? pointsToReach;

  const RankingTierModel({
    required this.name,
    required this.slug,
    required this.fromPoints,
    required this.toPoints,
    this.pointsToReach,
  });

  factory RankingTierModel.fromJson(Map<String, dynamic> json) {
    return RankingTierModel(
      name: _requiredString(json, 'name'),
      slug: _requiredString(json, 'slug'),
      fromPoints: _requiredInt(json, 'from_points'),
      toPoints: _requiredInt(json, 'to_points'),
      pointsToReach: safeIntOrNull(json['points_to_reach']),
    );
  }

  RankingTier toEntity() {
    return RankingTier(
      name: name,
      slug: slug,
      fromPoints: fromPoints,
      toPoints: toPoints,
      pointsToReach: pointsToReach,
    );
  }
}

class RankingComponentProgressModel {
  final String key;
  final String label;
  final int earnedPoints;
  final int maxPoints;
  final double progressPercentage;

  const RankingComponentProgressModel({
    required this.key,
    required this.label,
    required this.earnedPoints,
    required this.maxPoints,
    required this.progressPercentage,
  });

  factory RankingComponentProgressModel.fromJson(Map<String, dynamic> json) {
    return RankingComponentProgressModel(
      key: _requiredString(json, 'key'),
      label: _requiredString(json, 'label'),
      earnedPoints: _requiredInt(json, 'earned_points'),
      maxPoints: _requiredInt(json, 'max_points'),
      progressPercentage: _requiredDouble(json, 'progress_percentage'),
    );
  }

  RankingComponentProgress toEntity() {
    return RankingComponentProgress(
      key: key,
      label: label,
      earnedPoints: earnedPoints,
      maxPoints: maxPoints,
      progressPercentage: progressPercentage,
    );
  }
}

class RankingPendingItemModel {
  final String type;
  final String title;
  final String status;
  final String statusLabelKey;
  final DateTime? dueDate;
  final String actionLabel;

  const RankingPendingItemModel({
    required this.type,
    required this.title,
    required this.status,
    required this.statusLabelKey,
    required this.dueDate,
    required this.actionLabel,
  });

  factory RankingPendingItemModel.fromJson(Map<String, dynamic> json) {
    final status = _requiredString(json, 'status');

    return RankingPendingItemModel(
      type: _requiredString(json, 'type'),
      title: _requiredString(json, 'title'),
      status: status,
      statusLabelKey: annualRankingPendingStatusLabelKey(status),
      dueDate: json['due_date'] == null
          ? null
          : DateTime.tryParse(safeString(json['due_date'])),
      actionLabel: _requiredString(json, 'action_label'),
    );
  }

  RankingPendingItem toEntity() {
    return RankingPendingItem(
      type: type,
      title: title,
      status: status,
      statusLabelKey: statusLabelKey,
      dueDate: dueDate,
      actionLabel: actionLabel,
    );
  }
}

String annualRankingPendingStatusLabelKey(String status) {
  switch (status.trim().toLowerCase()) {
    case 'pending_delivery':
      return 'rankings.annual_progress.pending.status.pending_delivery';
    case 'pending_validation':
      return 'rankings.annual_progress.pending.status.pending_validation';
    case 'pending_union_validation':
      return 'rankings.annual_progress.pending.status.pending_union_validation';
    case 'pending_review':
      return 'rankings.annual_progress.pending.status.pending_review';
    default:
      return 'rankings.annual_progress.pending.status.pending_review';
  }
}

Map<String, dynamic> _requiredMap(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Missing required object field "$key"');
}

Map<String, dynamic> _asMap(Object? value, String fieldName) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected object for "$fieldName"');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException('Missing required list field "$key"');
}

List<dynamic> _optionalList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is List) return value;
  throw FormatException('Expected list field "$key"');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw FormatException('Missing required string field "$key"');
  }
  final parsed = safeString(value).trim();
  if (parsed.isEmpty) {
    throw FormatException('Empty required string field "$key"');
  }
  return parsed;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw FormatException('Missing required int field "$key"');
  }
  return safeInt(value);
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw FormatException('Missing required double field "$key"');
  }
  return safeDouble(value);
}
