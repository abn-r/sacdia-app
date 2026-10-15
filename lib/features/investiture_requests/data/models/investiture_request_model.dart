import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/person_status.dart';
import 'json_parsing.dart';

class RequestPersonModel extends RequestPerson {
  const RequestPersonModel({
    required super.personId,
    required super.userId,
    super.userName,
    required super.classId,
    super.className,
    super.sectionName,
    required super.enrollmentId,
    required super.investitureDate,
    required super.status,
    super.canAuthorize,
    super.authorizationComment,
    super.rejectionReason,
    super.systemReason,
    super.resolutionCode,
    super.resolvedByName,
  });

  factory RequestPersonModel.fromJson(Map<String, dynamic> json) {
    return RequestPersonModel(
      personId: json['person_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: asStringOrNull(json['user_name']),
      classId: asInt(json['class_id']),
      className: asStringOrNull(json['class_name']),
      sectionName: asStringOrNull(json['section_name']),
      enrollmentId: asInt(json['enrollment_id']),
      investitureDate: parseCivilDate(json['investiture_date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: PersonStatus.fromString(json['status']?.toString()),
      canAuthorize: json['can_authorize'] == true,
      authorizationComment: asStringOrNull(json['authorization_comment']),
      rejectionReason: asStringOrNull(json['rejection_reason']),
      systemReason: asStringOrNull(json['system_reason']),
      resolutionCode: asStringOrNull(json['resolution_code']),
      resolvedByName: asStringOrNull(json['resolved_by_name']),
    );
  }
}

class InvestitureRequestModel extends InvestitureRequest {
  const InvestitureRequestModel({
    required super.requestId,
    required super.clubSectionId,
    required super.ecclesiasticalYearId,
    super.clubId,
    super.clubName,
    super.sectionName,
    super.districtName,
    super.pendingCount,
    super.earliestInvestitureDate,
    super.createdAt,
    required super.people,
  });

  factory InvestitureRequestModel.fromJson(Map<String, dynamic> json) {
    return InvestitureRequestModel(
      requestId: json['request_id']?.toString() ?? '',
      clubSectionId: asInt(json['club_section_id']),
      ecclesiasticalYearId: asInt(json['ecclesiastical_year_id']),
      clubId: asIntOrNull(json['club_id']),
      clubName: asStringOrNull(json['club_name']),
      sectionName: asStringOrNull(json['section_name']),
      districtName: asStringOrNull(json['district_name']),
      pendingCount: asIntOrNull(json['pending_count']),
      earliestInvestitureDate:
          parseCivilDate(json['earliest_investiture_date']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      people: asJsonMapList(json['people'])
          .map(RequestPersonModel.fromJson)
          .toList(growable: false),
    );
  }
}
