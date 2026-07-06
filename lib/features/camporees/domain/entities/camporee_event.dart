import 'package:equatable/equatable.dart';

/// Bloque opcional de agenda para segmentar un evento por horario/grupo.
class CamporeeEventScheduleBlock extends Equatable {
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

  const CamporeeEventScheduleBlock({
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

  bool get hasTime => startsAt != null && startsAt!.trim().isNotEmpty;

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

/// Evento/actividad registrada dentro de un camporí.
class CamporeeEvent extends Equatable {
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
  final List<CamporeeEventScheduleBlock> scheduleBlocks;

  const CamporeeEvent({
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
    this.sections = const [],
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

  bool get hasTime =>
      agendaVisible && startsAt != null && startsAt!.trim().isNotEmpty;

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
