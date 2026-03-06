import 'package:equatable/equatable.dart';
import '../../domain/entities/activity.dart';

/// Modelo de actividad para la capa de datos
class ActivityModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final String? activityTime;
  final String activityPlace;
  final String? image;
  final int activityType;
  final String? activityTypeName;
  final int platform;
  final bool active;
  final int clubAdvId;
  final int clubPathfId;
  final int clubMgId;
  final int clubTypeId;
  final String? linkMeet;
  final DateTime? createdAt;

  const ActivityModel({
    required this.id,
    required this.name,
    this.description,
    this.activityTime,
    required this.activityPlace,
    this.image,
    required this.activityType,
    this.activityTypeName,
    required this.platform,
    required this.active,
    required this.clubAdvId,
    required this.clubPathfId,
    required this.clubMgId,
    required this.clubTypeId,
    this.linkMeet,
    this.createdAt,
  });

  /// Crea una instancia desde JSON
  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    final activityTypeNested = json['activity_types'] as Map<String, dynamic>?;
    final activityTypeId = (json['activity_type_id'] as int?) ??
        (json['activity_type'] as int?) ??
        (activityTypeNested?['activity_type_id'] as int?) ??
        1;

    return ActivityModel(
      id: json['activity_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      activityTime: json['activity_time'] as String?,
      activityPlace: (json['activity_place'] as String?) ?? '',
      image: json['image'] as String?,
      activityType: activityTypeId,
      activityTypeName: activityTypeNested?['name'] as String?,
      platform: (json['platform'] as int?) ?? 0,
      active: (json['active'] as bool?) ?? false,
      clubAdvId: (json['club_adv_id'] as int?) ?? 0,
      clubPathfId: (json['club_pathf_id'] as int?) ?? 0,
      clubMgId: (json['club_mg_id'] as int?) ?? 0,
      clubTypeId: (json['club_type_id'] as int?) ?? 0,
      linkMeet: json['link_meet'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'activity_id': id,
      'name': name,
      'description': description,
      'activity_time': activityTime,
      'activity_place': activityPlace,
      'image': image,
      'activity_type_id': activityType,
      'activity_type_name': activityTypeName,
      'platform': platform,
      'active': active,
      'club_adv_id': clubAdvId,
      'club_pathf_id': clubPathfId,
      'club_mg_id': clubMgId,
      'club_type_id': clubTypeId,
      'link_meet': linkMeet,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  Activity toEntity() {
    return Activity(
      id: id,
      name: name,
      description: description,
      activityTime: activityTime,
      activityPlace: activityPlace,
      image: image,
      activityType: activityType,
      activityTypeName: activityTypeName,
      platform: platform,
      active: active,
      clubAdvId: clubAdvId,
      clubPathfId: clubPathfId,
      clubMgId: clubMgId,
      clubTypeId: clubTypeId,
      linkMeet: linkMeet,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        activityTime,
        activityPlace,
        image,
        activityType,
        activityTypeName,
        platform,
        active,
        clubAdvId,
        clubPathfId,
        clubMgId,
        clubTypeId,
        linkMeet,
        createdAt,
      ];
}
