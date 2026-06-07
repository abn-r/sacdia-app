/// Modelo de solicitud para crear una nueva actividad
///
/// Mapea exactamente los campos que acepta el endpoint
/// POST /api/v1/clubs/:clubId/activities
class CreateActivityRequest {
  final String name;
  final String? description;

  // club_type_id is omitted from required fields — the backend derives it
  // from the authenticated user's club section. Only provided as a fallback
  // when the caller has no RBAC grant (should not happen in normal flows).
  final int? clubTypeId;

  final double lat;
  final double long;
  final String activityTime;
  final String activityPlace;
  final String? image;
  final int platform;
  final int activityTypeId;
  final String? linkMeet;
  final String? additionalData;
  final List<int>? classes;
  final int clubSectionId;
  final DateTime? activityDate;
  final DateTime? activityEndDate;

  /// IDs de las secciones participantes en una actividad conjunta.
  /// Cuando está presente con 2+ elementos el backend crea la actividad como
  /// conjunta (is_joint = true) y genera [activity_instances] para cada sección.
  /// La sección del creador debe estar incluida en esta lista.
  final List<int>? clubSectionIds;

  const CreateActivityRequest({
    required this.name,
    this.description,
    this.clubTypeId,
    required this.lat,
    required this.long,
    this.activityTime = '09:00',
    required this.activityPlace,
    this.image,
    this.platform = 0,
    this.activityTypeId = 1,
    this.linkMeet,
    this.additionalData,
    this.classes,
    required this.clubSectionId,
    this.activityDate,
    this.activityEndDate,
    this.clubSectionIds,
  });

  /// Convierte la solicitud a JSON para enviar al backend
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'lat': lat,
      'long': long,
      'activity_time': activityTime,
      'activity_place': activityPlace,
      'platform': platform,
      'activity_type_id': activityTypeId,
      'club_section_id': clubSectionId,
    };

    // Only include club_type_id when explicitly provided (legacy / fallback).
    // The backend derives it from the user's section in normal RBAC flows.
    if (clubTypeId != null) json['club_type_id'] = clubTypeId;

    if (image != null && image!.isNotEmpty) json['image'] = image;
    if (description != null) json['description'] = description;
    if (linkMeet != null) json['link_meet'] = linkMeet;
    if (additionalData != null) json['additional_data'] = additionalData;
    if (classes != null && classes!.isNotEmpty) json['classes'] = classes;
    if (activityDate != null) {
      json['activity_date'] = _formatDateOnly(activityDate!);
    }
    if (activityEndDate != null) {
      json['activity_end_date'] = _formatDateOnly(activityEndDate!);
    }
    // Joint activity: send participating section IDs
    if (clubSectionIds != null && clubSectionIds!.length >= 2) {
      json['club_section_ids'] = clubSectionIds;
    }

    return json;
  }

  static String _formatDateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
