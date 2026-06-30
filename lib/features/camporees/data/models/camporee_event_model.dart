import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/camporee_event.dart';

/// Modelo de evento de camporí para la capa de datos.
class CamporeeEventModel extends Equatable {
  final int camporeeEventId;
  final String title;
  final String? description;
  final int maxPoints;
  final int minPoints;
  final int dayNumber;
  final String? startsAt;
  final String? endsAt;
  final String displayCategory;
  final String status;
  final List<String> sections;
  final String? venueName;
  final String? leaderName;
  final int? durationSeconds;
  final String participantsMode;
  final int? participantsCount;

  const CamporeeEventModel({
    required this.camporeeEventId,
    required this.title,
    this.description,
    required this.maxPoints,
    required this.minPoints,
    required this.dayNumber,
    this.startsAt,
    this.endsAt,
    required this.displayCategory,
    required this.status,
    required this.sections,
    this.venueName,
    this.leaderName,
    this.durationSeconds,
    required this.participantsMode,
    this.participantsCount,
  });

  factory CamporeeEventModel.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    final venue = json['venue'] as Map<String, dynamic>?;
    final leader = json['leader'] as Map<String, dynamic>?;

    return CamporeeEventModel(
      camporeeEventId: safeInt(json['camporee_event_id'] ?? json['id']),
      title: safeString(json['title']),
      description: safeStringOrNull(json['description']),
      maxPoints: safeInt(json['max_points']),
      minPoints: safeInt(json['min_points']),
      dayNumber: safeInt(json['day_number'], 1),
      startsAt: safeStringOrNull(json['starts_at']),
      endsAt: safeStringOrNull(json['ends_at']),
      displayCategory: safeString(json['display_category'], 'logistico'),
      status: safeString(json['status'], 'programado'),
      sections: rawSections is List
          ? rawSections.map((value) => value.toString()).toList()
          : const [],
      venueName: safeStringOrNull(venue?['name']),
      leaderName: _resolveLeaderName(json, leader),
      durationSeconds: safeIntOrNull(json['duration_seconds']),
      participantsMode: safeString(json['participants_mode'], 'count'),
      participantsCount: safeIntOrNull(json['participants_count']),
    );
  }

  static String? _resolveLeaderName(
    Map<String, dynamic> json,
    Map<String, dynamic>? leader,
  ) {
    final override = safeStringOrNull(json['leader_name_override']);
    final firstName = safeStringOrNull(leader?['name']);
    if (firstName != null && firstName.trim().isNotEmpty) {
      final paternal = safeStringOrNull(leader?['paternal_last_name']);
      final fullName = '${firstName.trim()} ${paternal ?? ''}'.trim();
      return fullName.isEmpty ? null : fullName;
    }
    return override;
  }

  CamporeeEvent toEntity() {
    return CamporeeEvent(
      camporeeEventId: camporeeEventId,
      title: title,
      description: description,
      maxPoints: maxPoints,
      minPoints: minPoints,
      dayNumber: dayNumber,
      startsAt: startsAt,
      endsAt: endsAt,
      displayCategory: displayCategory,
      status: status,
      sections: sections,
      venueName: venueName,
      leaderName: leaderName,
      durationSeconds: durationSeconds,
      participantsMode: participantsMode,
      participantsCount: participantsCount,
    );
  }

  @override
  List<Object?> get props => [
        camporeeEventId,
        title,
        description,
        maxPoints,
        minPoints,
        dayNumber,
        startsAt,
        endsAt,
        displayCategory,
        status,
        sections,
        venueName,
        leaderName,
        durationSeconds,
        participantsMode,
        participantsCount,
      ];
}
