import 'package:equatable/equatable.dart';

/// Asignación de juez a una sección/evento de camporí.
class CamporeeJudgeAssignment extends Equatable {
  final String assignmentId;
  final int eventId;
  final String judgeId;
  final int? camporeeClubId;
  final int clubSectionId;
  final String judgeRole;
  final bool active;
  final String? eventTitle;
  final bool canSubmitScore;

  const CamporeeJudgeAssignment({
    required this.assignmentId,
    required this.eventId,
    required this.judgeId,
    this.camporeeClubId,
    required this.clubSectionId,
    required this.judgeRole,
    required this.active,
    this.eventTitle,
    required this.canSubmitScore,
  });

  bool get isPrimary => judgeRole == 'primary';

  /// Official capture is only for an active primary assignment that can submit.
  bool get canCaptureOfficialScore =>
      active && isPrimary && canSubmitScore;

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
        canSubmitScore,
      ];
}
