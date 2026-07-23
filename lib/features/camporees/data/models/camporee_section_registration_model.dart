import 'package:equatable/equatable.dart';
import '../../domain/entities/camporee_section_registration.dart';

class CamporeeSectionRegistrationActorModel extends Equatable {
  final String userId;
  final String displayName;

  const CamporeeSectionRegistrationActorModel({
    required this.userId,
    required this.displayName,
  });

  factory CamporeeSectionRegistrationActorModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CamporeeSectionRegistrationActorModel(
      userId: _requiredString(json, 'userId'),
      displayName: _requiredString(json, 'displayName'),
    );
  }

  CamporeeSectionRegistrationActor toEntity() {
    return CamporeeSectionRegistrationActor(
      userId: userId,
      displayName: displayName,
    );
  }

  @override
  List<Object?> get props => [userId, displayName];
}

class CamporeeSectionRegistrationModel extends Equatable {
  final int camporeeId;
  final int clubId;
  final String clubName;
  final int clubSectionId;
  final String sectionName;
  final int clubTypeId;
  final String clubTypeName;
  final CamporeeSectionRegistrationStatus status;
  final CamporeeSectionRegistrationDisposition disposition;
  final bool canEnroll;
  final String? blockingReason;
  final int? enrollmentId;
  final DateTime? registeredAt;
  final CamporeeSectionRegistrationActorModel? registeredBy;

  const CamporeeSectionRegistrationModel({
    required this.camporeeId,
    required this.clubId,
    required this.clubName,
    required this.clubSectionId,
    required this.sectionName,
    required this.clubTypeId,
    required this.clubTypeName,
    required this.status,
    required this.disposition,
    required this.canEnroll,
    this.blockingReason,
    this.enrollmentId,
    this.registeredAt,
    this.registeredBy,
  });

  factory CamporeeSectionRegistrationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CamporeeSectionRegistrationModel(
      camporeeId: _requiredInt(json, 'camporeeId'),
      clubId: _requiredInt(json, 'clubId'),
      clubName: _requiredString(json, 'clubName'),
      clubSectionId: _requiredInt(json, 'clubSectionId'),
      sectionName: _requiredString(json, 'sectionName'),
      clubTypeId: _requiredInt(json, 'clubTypeId'),
      clubTypeName: _requiredString(json, 'clubTypeName'),
      status: _parseStatus(_requiredString(json, 'status')),
      disposition: _parseDisposition(_requiredString(json, 'disposition')),
      canEnroll: _requiredBool(json, 'canEnroll'),
      blockingReason: _nullableString(json, 'blockingReason'),
      enrollmentId: _nullableInt(json, 'enrollmentId'),
      registeredAt: _nullableDateTime(json, 'registeredAt'),
      registeredBy: _nullableActor(json, 'registeredBy'),
    );
  }

  CamporeeSectionRegistration toEntity() {
    return CamporeeSectionRegistration(
      camporeeId: camporeeId,
      clubId: clubId,
      clubName: clubName,
      clubSectionId: clubSectionId,
      sectionName: sectionName,
      clubTypeId: clubTypeId,
      clubTypeName: clubTypeName,
      status: status,
      disposition: disposition,
      canEnroll: canEnroll,
      blockingReason: blockingReason,
      enrollmentId: enrollmentId,
      registeredAt: registeredAt,
      registeredBy: registeredBy?.toEntity(),
    );
  }

  @override
  List<Object?> get props => [
        camporeeId,
        clubId,
        clubName,
        clubSectionId,
        sectionName,
        clubTypeId,
        clubTypeName,
        status,
        disposition,
        canEnroll,
        blockingReason,
        enrollmentId,
        registeredAt,
        registeredBy,
      ];
}

CamporeeSectionRegistrationStatus _parseStatus(String value) {
  return switch (value) {
    'not_enrolled' => CamporeeSectionRegistrationStatus.notEnrolled,
    'registered' => CamporeeSectionRegistrationStatus.registered,
    'pending_approval' => CamporeeSectionRegistrationStatus.pendingApproval,
    'approved' => CamporeeSectionRegistrationStatus.approved,
    'rejected' => CamporeeSectionRegistrationStatus.rejected,
    'cancelled' => CamporeeSectionRegistrationStatus.cancelled,
    _ => CamporeeSectionRegistrationStatus.unknown,
  };
}

CamporeeSectionRegistrationDisposition _parseDisposition(String value) {
  return switch (value) {
    'not_open_yet' => CamporeeSectionRegistrationDisposition.notOpenYet,
    'open' => CamporeeSectionRegistrationDisposition.open,
    'late_approval_required' =>
      CamporeeSectionRegistrationDisposition.lateApprovalRequired,
    'manually_frozen' => CamporeeSectionRegistrationDisposition.manuallyFrozen,
    _ => CamporeeSectionRegistrationDisposition.unknown,
  };
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key must be an int');
}

int? _nullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('$key must be an int or null');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('$key must be a string');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('$key must be a string or null');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a bool');
}

DateTime? _nullableDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key must be an ISO-8601 string or null');
  }
  return DateTime.parse(value).toUtc();
}

CamporeeSectionRegistrationActorModel? _nullableActor(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is Map) {
    return CamporeeSectionRegistrationActorModel.fromJson(
      Map<String, dynamic>.from(value),
    );
  }
  throw FormatException('$key must be an object or null');
}
