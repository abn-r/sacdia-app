import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/camporee_event.dart';

class CamporeeEventScheduleBlockModel extends Equatable {
  final String? scheduleBlockId;
  final String? title;
  final String? description;
  final int dayNumber;
  final String? startsAt;
  final String? endsAt;
  final String? venueName;
  final int? capacity;
  final String? notes;
  final List<String> assignedSectionNames;

  const CamporeeEventScheduleBlockModel({
    this.scheduleBlockId,
    this.title,
    this.description,
    required this.dayNumber,
    this.startsAt,
    this.endsAt,
    this.venueName,
    this.capacity,
    this.notes,
    this.assignedSectionNames = const [],
  });

  factory CamporeeEventScheduleBlockModel.fromJson(Map<String, dynamic> json) {
    final venue = json['venue'] is Map<String, dynamic>
        ? json['venue'] as Map<String, dynamic>
        : null;
    final assignments = json['assignments'];

    return CamporeeEventScheduleBlockModel(
      scheduleBlockId:
          safeStringOrNull(json['camporee_event_schedule_block_id']),
      title: safeStringOrNull(json['title']),
      description: safeStringOrNull(json['description']),
      dayNumber: safeInt(json['day_number'], 1),
      startsAt: safeStringOrNull(json['starts_at']),
      endsAt: safeStringOrNull(json['ends_at']),
      venueName: safeStringOrNull(venue?['name']),
      capacity: safeIntOrNull(json['capacity']),
      notes: safeStringOrNull(json['notes']),
      assignedSectionNames: assignments is List
          ? assignments
              .whereType<Map>()
              .map((item) => _assignmentLabel(Map<String, dynamic>.from(item)))
              .whereType<String>()
              .toList()
          : const [],
    );
  }

  static String? _assignmentLabel(Map<String, dynamic> json) {
    final section = json['club_section'] is Map<String, dynamic>
        ? json['club_section'] as Map<String, dynamic>
        : null;
    final sectionName = safeStringOrNull(section?['name']);
    final club = section?['clubs'] is Map<String, dynamic>
        ? section!['clubs'] as Map<String, dynamic>
        : null;
    final clubName = safeStringOrNull(club?['name']);
    if (clubName != null && sectionName != null) {
      return '$clubName · $sectionName';
    }
    return sectionName ?? clubName;
  }

  CamporeeEventScheduleBlock toEntity() {
    return CamporeeEventScheduleBlock(
      scheduleBlockId: scheduleBlockId,
      title: title,
      description: description,
      dayNumber: dayNumber,
      startsAt: startsAt,
      endsAt: endsAt,
      venueName: venueName,
      capacity: capacity,
      notes: notes,
      assignedSectionNames: assignedSectionNames,
    );
  }

  @override
  List<Object?> get props => [
        scheduleBlockId,
        title,
        description,
        dayNumber,
        startsAt,
        endsAt,
        venueName,
        capacity,
        notes,
        assignedSectionNames,
      ];
}

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
  final bool agendaVisible;
  final String? eventTypeCode;
  final String? eventTypeName;
  final List<CamporeeEventScheduleBlockModel> scheduleBlocks;

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
    this.agendaVisible = true,
    this.eventTypeCode,
    this.eventTypeName,
    this.scheduleBlocks = const [],
  });

  factory CamporeeEventModel.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    final venue = json['venue'] is Map<String, dynamic>
        ? json['venue'] as Map<String, dynamic>
        : null;
    final leader = json['leader'] is Map<String, dynamic>
        ? json['leader'] as Map<String, dynamic>
        : null;
    final eventType = json['event_type'] is Map<String, dynamic>
        ? json['event_type'] as Map<String, dynamic>
        : null;
    final rawBlocks = json['schedule_blocks'];

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
      agendaVisible: json['agenda_visible'] != false,
      eventTypeCode: safeStringOrNull(eventType?['code']),
      eventTypeName: safeStringOrNull(eventType?['name']),
      scheduleBlocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map(
                (item) => CamporeeEventScheduleBlockModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
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
      agendaVisible: agendaVisible,
      eventTypeCode: eventTypeCode,
      eventTypeName: eventTypeName,
      scheduleBlocks: scheduleBlocks.map((block) => block.toEntity()).toList(),
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
        agendaVisible,
        eventTypeCode,
        eventTypeName,
        scheduleBlocks,
      ];
}
