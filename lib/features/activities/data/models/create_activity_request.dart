/// Modelo de solicitud para crear una nueva actividad
///
/// Mapea exactamente los campos que acepta el endpoint
/// POST /api/v1/clubs/:clubId/activities
class CreateActivityRequest {
  final String name;
  final String? description;
  final int clubTypeId;
  final double lat;
  final double long;
  final String activityTime;
  final String activityPlace;
  final String image;
  final int platform;
  final int activityTypeId;
  final String? linkMeet;
  final String? additionalData;
  final List<int>? classes;
  final int clubAdvId;
  final int clubPathfId;
  final int clubMgId;

  const CreateActivityRequest({
    required this.name,
    this.description,
    required this.clubTypeId,
    required this.lat,
    required this.long,
    this.activityTime = '09:00',
    required this.activityPlace,
    required this.image,
    this.platform = 0,
    this.activityTypeId = 1,
    this.linkMeet,
    this.additionalData,
    this.classes,
    required this.clubAdvId,
    required this.clubPathfId,
    required this.clubMgId,
  });

  /// Convierte la solicitud a JSON para enviar al backend
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'club_type_id': clubTypeId,
      'lat': lat,
      'long': long,
      'activity_time': activityTime,
      'activity_place': activityPlace,
      'image': image,
      'platform': platform,
      'activity_type_id': activityTypeId,
      'club_adv_id': clubAdvId,
      'club_pathf_id': clubPathfId,
      'club_mg_id': clubMgId,
    };

    if (description != null) json['description'] = description;
    if (linkMeet != null) json['link_meet'] = linkMeet;
    if (additionalData != null) json['additional_data'] = additionalData;
    if (classes != null && classes!.isNotEmpty) json['classes'] = classes;

    return json;
  }
}
