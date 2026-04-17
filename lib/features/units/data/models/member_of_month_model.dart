import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/member_of_month.dart';

/// Modelo de un ganador individual del Miembro del Mes.
///
/// ```json
/// {
///   "user_id": "uuid-string",
///   "name": "Juan Perez",
///   "photo_url": "https://...",
///   "total_points": 87
/// }
/// ```
class MemberOfMonthEntryModel extends MemberOfMonthEntry {
  const MemberOfMonthEntryModel({
    required super.userId,
    required super.name,
    super.photoUrl,
    required super.totalPoints,
  });

  factory MemberOfMonthEntryModel.fromJson(Map<String, dynamic> json) {
    return MemberOfMonthEntryModel(
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      totalPoints: parseInt(json['total_points']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'photo_url': photoUrl,
        'total_points': totalPoints,
      };

  MemberOfMonthEntry toEntity() => MemberOfMonthEntry(
        userId: userId,
        name: name,
        photoUrl: photoUrl,
        totalPoints: totalPoints,
      );
}

/// Modelo del Miembro del Mes para un mes/año dado.
///
/// ```json
/// {
///   "month": 4,
///   "year": 2026,
///   "members": [
///     { "user_id": "...", "name": "Juan Perez", "photo_url": "...", "total_points": 87 }
///   ]
/// }
/// ```
class MemberOfMonthModel extends MemberOfMonth {
  const MemberOfMonthModel({
    required super.month,
    required super.year,
    required super.members,
  });

  factory MemberOfMonthModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? [];
    final members = rawMembers
        .whereType<Map<String, dynamic>>()
        .map((m) => MemberOfMonthEntryModel.fromJson(m))
        .cast<MemberOfMonthEntry>()
        .toList();

    return MemberOfMonthModel(
      month: parseInt(json['month']) ?? 0,
      year: parseInt(json['year']) ?? 0,
      members: members,
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'year': year,
        'members': members
            .map((m) => MemberOfMonthEntryModel(
                  userId: m.userId,
                  name: m.name,
                  photoUrl: m.photoUrl,
                  totalPoints: m.totalPoints,
                ).toJson())
            .toList(),
      };

  MemberOfMonth toEntity() => MemberOfMonth(
        month: month,
        year: year,
        members: members
            .map((m) => MemberOfMonthEntry(
                  userId: m.userId,
                  name: m.name,
                  photoUrl: m.photoUrl,
                  totalPoints: m.totalPoints,
                ))
            .toList(),
      );
}
