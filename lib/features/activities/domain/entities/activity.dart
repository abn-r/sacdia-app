import 'package:equatable/equatable.dart';

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
  final String? linkMeet;
  final DateTime? createdAt;

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
    this.linkMeet,
    this.createdAt,
  });

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
      ];
}
