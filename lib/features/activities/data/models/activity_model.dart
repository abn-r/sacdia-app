import 'package:equatable/equatable.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_instance.dart';

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
  final int clubSectionId;
  final int clubTypeId;
  final String? linkMeet;
  final DateTime? createdAt;

  // Extended fields
  final double? lat;
  final double? longitude;
  final DateTime? activityDate;
  final DateTime? activityEndDate;
  final List<String>? attendees;
  final List<int>? classes;
  final String? additionalData;
  final String? creatorName;
  final String? creatorImage;

  /// Whether this is a joint activity (spans multiple club sections).
  final bool isJoint;

  /// Participating section instances for joint activities.
  final List<ActivityInstance>? instances;

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
    required this.clubSectionId,
    required this.clubTypeId,
    this.linkMeet,
    this.createdAt,
    this.lat,
    this.longitude,
    this.activityDate,
    this.activityEndDate,
    this.attendees,
    this.classes,
    this.additionalData,
    this.creatorName,
    this.creatorImage,
    this.isJoint = false,
    this.instances,
  });

  /// Crea una instancia desde JSON
  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    final activityTypeNested = json['activity_types'] as Map<String, dynamic>?;
    final activityTypeId = (json['activity_type_id'] as int?) ??
        (json['activity_type'] as int?) ??
        (activityTypeNested?['activity_type_id'] as int?) ??
        1;

    // Creator info from nested users object
    final usersNested = json['users'] as Map<String, dynamic>?;
    String? creatorName;
    if (usersNested != null) {
      final firstName = usersNested['name'] as String? ?? '';
      final lastName = usersNested['paternal_last_name'] as String? ?? '';
      final fullName = '$firstName $lastName'.trim();
      creatorName = fullName.isNotEmpty ? fullName : null;
    }

    // Parse attendees list
    List<String>? attendees;
    final rawAttendees = json['attendees'];
    if (rawAttendees is List) {
      attendees = rawAttendees.map((e) => e.toString()).toList();
    }

    // Parse classes list
    List<int>? classes;
    final rawClasses = json['classes'];
    if (rawClasses is List) {
      classes = rawClasses
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList();
    }

    // Parse activity_instances for joint activities
    List<ActivityInstance>? instances;
    final rawInstances = json['activity_instances'];
    if (rawInstances is List && rawInstances.isNotEmpty) {
      instances = rawInstances
          .whereType<Map<String, dynamic>>()
          .map((inst) {
            final clubTypesNested =
                inst['club_types'] as Map<String, dynamic>?;
            return ActivityInstance(
              clubSectionId: (inst['club_section_id'] as int?) ?? 0,
              clubTypeId: (inst['club_type_id'] as int?) ?? 0,
              clubTypeName: clubTypesNested?['name'] as String?,
            );
          })
          .toList();
    }

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
      clubSectionId: (json['club_section_id'] as int?) ?? 0,
      clubTypeId: (json['club_type_id'] as int?) ?? 0,
      linkMeet: json['link_meet'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      lat: (json['lat'] as num?)?.toDouble(),
      longitude: (json['long'] as num?)?.toDouble(),
      activityDate: json['activity_date'] != null
          ? DateTime.tryParse(json['activity_date'] as String)
          : null,
      activityEndDate: json['activity_end_date'] != null
          ? DateTime.tryParse(json['activity_end_date'] as String)
          : null,
      attendees: attendees,
      classes: classes,
      additionalData: json['additional_data'] as String?,
      creatorName: creatorName,
      creatorImage: usersNested?['user_image'] as String?,
      isJoint: (json['is_joint'] as bool?) ?? false,
      instances: instances,
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
      'club_section_id': clubSectionId,
      'club_type_id': clubTypeId,
      'link_meet': linkMeet,
      'created_at': createdAt?.toIso8601String(),
      'lat': lat,
      'long': longitude,
      'activity_date': activityDate?.toIso8601String(),
      'activity_end_date': activityEndDate?.toIso8601String(),
      'attendees': attendees,
      'classes': classes,
      'additional_data': additionalData,
      'is_joint': isJoint,
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
      clubSectionId: clubSectionId,
      clubTypeId: clubTypeId,
      linkMeet: linkMeet,
      createdAt: createdAt,
      lat: lat,
      longitude: longitude,
      activityDate: activityDate,
      activityEndDate: activityEndDate,
      attendees: attendees,
      classes: classes,
      additionalData: additionalData,
      creatorName: creatorName,
      creatorImage: creatorImage,
      isJoint: isJoint,
      instances: instances,
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
        clubSectionId,
        clubTypeId,
        linkMeet,
        createdAt,
        lat,
        longitude,
        activityDate,
        activityEndDate,
        attendees,
        classes,
        additionalData,
        creatorName,
        creatorImage,
        isJoint,
        instances,
      ];
}
