import '../../domain/entities/presentation_context.dart';
import 'json_parsing.dart';

class WindowStateModel extends WindowState {
  const WindowStateModel({
    super.startDate,
    super.endDate,
    required super.openToday,
    super.timeZoneInvalid,
  });

  factory WindowStateModel.fromJson(Map<String, dynamic> json) {
    return WindowStateModel(
      startDate: parseCivilDate(json['start_date']),
      endDate: parseCivilDate(json['end_date']),
      openToday: json['open_today'] == true,
      timeZoneInvalid: json['time_zone_invalid'] == true,
    );
  }
}

class PresentationCandidateModel extends PresentationCandidate {
  const PresentationCandidateModel({
    required super.enrollmentId,
    required super.userId,
    super.userName,
    required super.classId,
    super.className,
    required super.overallProgress,
    required super.eligible,
    super.blockedCode,
    super.pendingPersonId,
  });

  factory PresentationCandidateModel.fromJson(Map<String, dynamic> json) {
    return PresentationCandidateModel(
      enrollmentId: asInt(json['enrollment_id']),
      userId: json['user_id']?.toString() ?? '',
      userName: asStringOrNull(json['user_name']),
      classId: asInt(json['class_id']),
      className: asStringOrNull(json['class_name']),
      overallProgress: asNum(json['overall_progress']),
      eligible: json['eligible'] == true,
      blockedCode: asStringOrNull(json['blocked_code']),
      pendingPersonId: asStringOrNull(json['pending_person_id']),
    );
  }
}

class PresentationContextModel extends PresentationContext {
  const PresentationContextModel({
    required super.clubSectionId,
    required super.ecclesiasticalYearId,
    required super.window,
    required super.yearOpen,
    super.openRequestId,
    required super.candidates,
  });

  factory PresentationContextModel.fromJson(Map<String, dynamic> json) {
    return PresentationContextModel(
      clubSectionId: asInt(json['club_section_id']),
      ecclesiasticalYearId: asInt(json['ecclesiastical_year_id']),
      window: WindowStateModel.fromJson(asJsonMap(json['window'])),
      yearOpen: json['year_open'] == true,
      openRequestId: asStringOrNull(json['open_request_id']),
      candidates: asJsonMapList(json['candidates'])
          .map(PresentationCandidateModel.fromJson)
          .toList(growable: false),
    );
  }
}
