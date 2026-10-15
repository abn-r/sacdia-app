import 'package:equatable/equatable.dart';
import 'activity_instance.dart';

/// Clase incluida cuando la actividad es solo para algunas clases.
class ActivityAudienceClass extends Equatable {
  final int classId;
  final String name;
  final String? assetCode;
  final int clubTypeId;

  const ActivityAudienceClass({
    required this.classId,
    required this.name,
    this.assetCode,
    required this.clubTypeId,
  });

  @override
  List<Object?> get props => [classId, name, assetCode, clubTypeId];
}

/// Datos para mostrar a un participante (nombre y foto) en el detalle.
class ActivityAttendee extends Equatable {
  final String userId;
  final String name;
  final String? paternalLastName;
  final String? imageUrl;

  const ActivityAttendee({
    required this.userId,
    required this.name,
    this.paternalLastName,
    this.imageUrl,
  });

  /// Up to two initials from the first name and paternal last name.
  String get initials {
    String first(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase();
    }

    return '${first(name)}${first(paternalLastName)}';
  }

  @override
  List<Object?> get props => [userId, name, paternalLastName, imageUrl];
}

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

  /// Name/photo for entries of [attendees], in the same order. Ids without a
  /// profile (deleted users, older backends) are simply missing here.
  final List<ActivityAttendee> attendeeProfiles;
  final List<int>? classes;
  final String? additionalData;
  final String? creatorName;
  final String? creatorImage;

  /// Whether this activity spans multiple club sections (actividad conjunta).
  final bool isJoint;

  /// Participating section instances (populated when [isJoint] is true).
  final List<ActivityInstance>? instances;

  /// Series this session belongs to, if it was created from a recurrence.
  final int? activitySeriesId;

  /// `all`, `board`, or `classes`.
  final String audience;

  /// Classes that can see the activity when [audience] is `classes`.
  final List<ActivityAudienceClass> audienceClasses;

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
    this.attendeeProfiles = const [],
    this.classes,
    this.additionalData,
    this.creatorName,
    this.creatorImage,
    this.isJoint = false,
    this.instances,
    this.activitySeriesId,
    this.audience = 'all',
    this.audienceClasses = const [],
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
        attendeeProfiles,
        classes,
        additionalData,
        creatorName,
        creatorImage,
        isJoint,
        instances,
        activitySeriesId,
        audience,
        audienceClasses,
      ];
}
