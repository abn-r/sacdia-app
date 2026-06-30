import 'package:equatable/equatable.dart';

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
  });

  bool get hasTime => startsAt != null && startsAt!.trim().isNotEmpty;

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
