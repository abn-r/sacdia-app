import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/camporee_judge_assignment.dart';

/// Modelo de asignación de juez para camporees.
class CamporeeJudgeAssignmentModel extends Equatable {
  final String assignmentId;
  final int eventId;
  final String judgeId;
  final int? camporeeClubId;
  final int clubSectionId;
  final String judgeRole;
  final bool active;
  final String? eventTitle;
  final String? clubName;
  final String? sectionName;
  final bool canSubmitScore;

  const CamporeeJudgeAssignmentModel({
    required this.assignmentId,
    required this.eventId,
    required this.judgeId,
    this.camporeeClubId,
    required this.clubSectionId,
    required this.judgeRole,
    required this.active,
    this.eventTitle,
    this.clubName,
    this.sectionName,
    required this.canSubmitScore,
  });

  factory CamporeeJudgeAssignmentModel.fromJson(Map<String, dynamic> json) {
    final role = safeString(json['judge_role'], 'assistant');
    return CamporeeJudgeAssignmentModel(
      assignmentId: safeString(json['camporee_event_judge_assignment_id']),
      eventId: safeInt(json['camporee_event_id']),
      judgeId: safeString(json['camporee_judge_id']),
      camporeeClubId: safeIntOrNull(json['camporee_club_id']),
      clubSectionId: safeInt(json['club_section_id']),
      judgeRole: role,
      active: safeBool(json['active'], true),
      eventTitle: safeStringOrNull(json['event_title']),
      clubName: safeStringOrNull(json['club_name']),
      sectionName: safeStringOrNull(json['section_name']),
      canSubmitScore: safeBool(json['can_submit_score'], role == 'primary'),
    );
  }

  CamporeeJudgeAssignment toEntity() {
    return CamporeeJudgeAssignment(
      assignmentId: assignmentId,
      eventId: eventId,
      judgeId: judgeId,
      camporeeClubId: camporeeClubId,
      clubSectionId: clubSectionId,
      judgeRole: judgeRole,
      active: active,
      eventTitle: eventTitle,
      clubName: clubName,
      sectionName: sectionName,
      canSubmitScore: canSubmitScore,
    );
  }

  @override
  List<Object?> get props => [
        assignmentId,
        eventId,
        judgeId,
        camporeeClubId,
        clubSectionId,
        judgeRole,
        active,
        eventTitle,
        clubName,
        sectionName,
        canSubmitScore,
      ];
}
