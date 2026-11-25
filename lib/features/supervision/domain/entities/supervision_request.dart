import 'package:equatable/equatable.dart';

enum SupervisionRequestStatus {
  pending,
  approved,
  rejected,
  unknown;

  static SupervisionRequestStatus parse(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'pending':
        return SupervisionRequestStatus.pending;
      case 'approved':
        return SupervisionRequestStatus.approved;
      case 'rejected':
        return SupervisionRequestStatus.rejected;
      default:
        return SupervisionRequestStatus.unknown;
    }
  }

  /// Value sent to the API; null for [unknown].
  String? get apiValue {
    switch (this) {
      case SupervisionRequestStatus.pending:
        return 'pending';
      case SupervisionRequestStatus.approved:
        return 'approved';
      case SupervisionRequestStatus.rejected:
        return 'rejected';
      case SupervisionRequestStatus.unknown:
        return null;
    }
  }
}

enum SupervisionRequestKind { transfer, assignment }

/// A transfer or role-assignment request seen by a territorial supervisor.
class SupervisionRequest extends Equatable {
  const SupervisionRequest({
    required this.kind,
    required this.id,
    required this.status,
    required this.personName,
    required this.personId,
    this.createdAt,
    this.reviewedAt,
    this.reviewerName,
    this.reviewComment,
    this.fromClubName,
    this.fromSectionLabel,
    this.toClubName,
    this.toSectionLabel,
    this.reason,
    this.roleName,
    this.clubName,
    this.sectionLabel,
    this.requestedByName,
  });

  final SupervisionRequestKind kind;
  final String id;
  final SupervisionRequestStatus status;
  final String personName;
  final String personId;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewerName;
  final String? reviewComment;

  // Transfer only.
  final String? fromClubName;
  final String? fromSectionLabel;
  final String? toClubName;
  final String? toSectionLabel;
  final String? reason;

  // Assignment only.
  final String? roleName;
  final String? clubName;
  final String? sectionLabel;
  final String? requestedByName;

  /// Keeps names this instance lacks from [previous] (review responses omit
  /// `clubs`, so a name the list already had must not be blanked).
  SupervisionRequest fillMissingFrom(SupervisionRequest previous) {
    return SupervisionRequest(
      kind: kind,
      id: id,
      status: status,
      personName: personName.isEmpty ? previous.personName : personName,
      personId: personId.isEmpty ? previous.personId : personId,
      createdAt: createdAt ?? previous.createdAt,
      reviewedAt: reviewedAt,
      reviewerName: reviewerName,
      reviewComment: reviewComment,
      fromClubName: fromClubName ?? previous.fromClubName,
      fromSectionLabel: fromSectionLabel ?? previous.fromSectionLabel,
      toClubName: toClubName ?? previous.toClubName,
      toSectionLabel: toSectionLabel ?? previous.toSectionLabel,
      reason: reason ?? previous.reason,
      roleName: roleName ?? previous.roleName,
      clubName: clubName ?? previous.clubName,
      sectionLabel: sectionLabel ?? previous.sectionLabel,
      requestedByName: requestedByName ?? previous.requestedByName,
    );
  }

  @override
  List<Object?> get props => [
        kind,
        id,
        status,
        personName,
        personId,
        createdAt,
        reviewedAt,
        reviewerName,
        reviewComment,
        fromClubName,
        fromSectionLabel,
        toClubName,
        toSectionLabel,
        reason,
        roleName,
        clubName,
        sectionLabel,
        requestedByName,
      ];
}
