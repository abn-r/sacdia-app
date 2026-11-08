import 'package:equatable/equatable.dart';

import 'camporee_official_score.dart';

/// Per-event score detail of every section the user may see.
class CamporeeScoreBreakdown extends Equatable {
  final String scopeType;
  final int camporeeId;

  /// `full` (admins/field), `district` (pastor) or `own` (club roles).
  final String visibility;
  final List<CamporeeScoreBreakdownSection> sections;

  const CamporeeScoreBreakdown({
    required this.scopeType,
    required this.camporeeId,
    required this.visibility,
    required this.sections,
  });

  /// Club roles only get their own sections.
  bool get isOwn => visibility == 'own';

  /// Every section's result for [eventId], best score first.
  List<CamporeeScoreBreakdownEntry> entriesForEvent(int eventId) {
    final entries = <CamporeeScoreBreakdownEntry>[
      for (final section in sections)
        for (final result in section.results)
          if (result.camporeeEventId == eventId)
            CamporeeScoreBreakdownEntry(section: section, result: result),
    ];
    entries.sort(
      (a, b) => b.result.score.totalAwarded.compareTo(
        a.result.score.totalAwarded,
      ),
    );
    return entries;
  }

  @override
  List<Object?> get props => [scopeType, camporeeId, visibility, sections];
}

class CamporeeScoreBreakdownSection extends Equatable {
  final int? rank;
  final int? camporeeClubId;
  final int clubSectionId;
  final String? clubName;
  final String? sectionName;
  final double totalAwardedPoints;
  final double totalMaxPoints;
  final List<CamporeeScoreBreakdownResult> results;

  const CamporeeScoreBreakdownSection({
    this.rank,
    this.camporeeClubId,
    required this.clubSectionId,
    this.clubName,
    this.sectionName,
    required this.totalAwardedPoints,
    required this.totalMaxPoints,
    required this.results,
  });

  @override
  List<Object?> get props => [
        rank,
        camporeeClubId,
        clubSectionId,
        clubName,
        sectionName,
        totalAwardedPoints,
        totalMaxPoints,
        results,
      ];
}

/// A section's official score in one event.
class CamporeeScoreBreakdownResult extends Equatable {
  final int camporeeEventId;
  final CamporeeOfficialScore score;

  const CamporeeScoreBreakdownResult({
    required this.camporeeEventId,
    required this.score,
  });

  @override
  List<Object?> get props => [camporeeEventId, score];
}

/// One section + its result for a given event.
class CamporeeScoreBreakdownEntry extends Equatable {
  final CamporeeScoreBreakdownSection section;
  final CamporeeScoreBreakdownResult result;

  const CamporeeScoreBreakdownEntry({
    required this.section,
    required this.result,
  });

  @override
  List<Object?> get props => [section, result];
}
