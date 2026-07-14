import 'package:equatable/equatable.dart';

enum CamporeeSectionRegistrationStatus {
  notEnrolled,
  registered,
  pendingApproval,
  approved,
  rejected,
  cancelled,
  unknown,
}

enum CamporeeSectionRegistrationDisposition {
  notOpenYet,
  open,
  lateApprovalRequired,
  manuallyFrozen,
  unknown,
}

class CamporeeSectionRegistrationActor extends Equatable {
  final String userId;
  final String displayName;

  const CamporeeSectionRegistrationActor({
    required this.userId,
    required this.displayName,
  });

  @override
  List<Object?> get props => [userId, displayName];
}

class CamporeeSectionRegistration extends Equatable {
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
  final CamporeeSectionRegistrationActor? registeredBy;

  const CamporeeSectionRegistration({
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

  bool get enablesParticipants =>
      status == CamporeeSectionRegistrationStatus.registered ||
      status == CamporeeSectionRegistrationStatus.approved;

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
