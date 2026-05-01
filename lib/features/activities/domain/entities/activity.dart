import 'package:equatable/equatable.dart';
import 'activity_instance.dart';

/// Entidad de actividad del club del dominio
class Activity extends Equatable {
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
  final String? clubTypeName;
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

  /// Whether this activity spans multiple club sections (actividad conjunta).
  final bool isJoint;

  /// Participating section instances (populated when [isJoint] is true).
  final List<ActivityInstance>? instances;

  const Activity({
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
    this.clubTypeName,
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

  /// Returns true if the activity is in the past (based on activityDate or createdAt).
  bool get isPast {
    final reference = activityDate ?? activityEndDate;
    if (reference == null) return false;
    return reference.isBefore(DateTime.now());
  }

  /// Returns true if the activity has a virtual component.
  bool get hasVirtualLink =>
      (platform == 1 || platform == 2) && linkMeet != null;

  /// Returns true if the activity has coordinates.
  bool get hasLocation => lat != null && longitude != null;

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
        clubTypeName,
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
