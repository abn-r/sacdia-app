import 'package:equatable/equatable.dart';

enum SupervisionEnrollmentStatus {
  pendingValidation('pending_validation'),
  active('active'),
  rejected('rejected'),
  unknown('unknown');

  const SupervisionEnrollmentStatus(this.apiValue);

  final String apiValue;

  static SupervisionEnrollmentStatus parse(String? value) {
    switch (value) {
      case 'pending_validation':
        return SupervisionEnrollmentStatus.pendingValidation;
      case 'active':
        return SupervisionEnrollmentStatus.active;
      case 'rejected':
        return SupervisionEnrollmentStatus.rejected;
      default:
        return SupervisionEnrollmentStatus.unknown;
    }
  }
}

class SupervisionPersonRef extends Equatable {
  final String userId;
  final String name;

  const SupervisionPersonRef({required this.userId, required this.name});

  @override
  List<Object?> get props => [userId, name];
}

class SupervisionEnrollmentBoard extends Equatable {
  final SupervisionPersonRef? director;
  final List<SupervisionPersonRef> deputies;
  final SupervisionPersonRef? secretary;
  final SupervisionPersonRef? treasurer;
  final SupervisionPersonRef? secretaryTreasurer;

  const SupervisionEnrollmentBoard({
    this.director,
    this.deputies = const [],
    this.secretary,
    this.treasurer,
    this.secretaryTreasurer,
  });

  @override
  List<Object?> get props =>
      [director, deputies, secretary, treasurer, secretaryTreasurer];
}

class SupervisionEnrollment extends Equatable {
  final String id;
  final SupervisionEnrollmentStatus status;
  final String yearName;
  final String clubName;
  final String clubTypeName;
  final String localFieldName;
  final String? address;
  final String? meetingDays;
  final int? soulsTarget;
  final bool hasFee;
  final double? feeAmount;
  final SupervisionEnrollmentBoard board;
  final SupervisionPersonRef? submittedBy;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final SupervisionPersonRef? reviewedBy;
  final String? reviewerRole;
  final DateTime? reviewedAt;
  final String? decisionReason;

  const SupervisionEnrollment({
    required this.id,
    required this.status,
    this.yearName = '',
    this.clubName = '',
    this.clubTypeName = '',
    this.localFieldName = '',
    this.address,
    this.meetingDays,
    this.soulsTarget,
    this.hasFee = false,
    this.feeAmount,
    this.board = const SupervisionEnrollmentBoard(),
    this.submittedBy,
    this.submittedAt,
    this.createdAt,
    this.reviewedBy,
    this.reviewerRole,
    this.reviewedAt,
    this.decisionReason,
  });

  @override
  List<Object?> get props => [
        id,
        status,
        yearName,
        clubName,
        clubTypeName,
        localFieldName,
        address,
        meetingDays,
        soulsTarget,
        hasFee,
        feeAmount,
        board,
        submittedBy,
        submittedAt,
        createdAt,
        reviewedBy,
        reviewerRole,
        reviewedAt,
        decisionReason,
      ];
}

class SupervisionEnrollmentCounts extends Equatable {
  final int pending;
  final int approved;
  final int rejected;

  const SupervisionEnrollmentCounts({
    this.pending = 0,
    this.approved = 0,
    this.rejected = 0,
  });

  @override
  List<Object?> get props => [pending, approved, rejected];
}

class SupervisionEnrollmentPage extends Equatable {
  final List<SupervisionEnrollment> items;
  final int page;
  final int limit;
  final int total;
  final SupervisionEnrollmentCounts counts;

  const SupervisionEnrollmentPage({
    this.items = const [],
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.counts = const SupervisionEnrollmentCounts(),
  });

  @override
  List<Object?> get props => [items, page, limit, total, counts];
}
