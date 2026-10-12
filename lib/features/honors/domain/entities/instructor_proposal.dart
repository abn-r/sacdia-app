import 'package:equatable/equatable.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';

/// Where a proposal stands. `withdrawn` is the member's own cancel (the API
/// calls it `CANCELLED`); `unknown` is any value this app does not know.
enum InstructorProposalStatus {
  pending,
  approved,
  rejected,
  withdrawn,
  unknown
}

InstructorProposalStatus instructorProposalStatusFromApi(String? value) {
  switch (value?.trim().toUpperCase()) {
    case 'PENDING':
      return InstructorProposalStatus.pending;
    case 'APPROVED':
      return InstructorProposalStatus.approved;
    case 'REJECTED':
      return InstructorProposalStatus.rejected;
    case 'WITHDRAWN':
    case 'CANCELLED':
    case 'CANCELED':
      return InstructorProposalStatus.withdrawn;
    default:
      return InstructorProposalStatus.unknown;
  }
}

/// The member's proposal of an instructor on an already approved honor (D11).
/// The Local Field decides; until then the current instructor does not change.
class InstructorProposal extends Equatable {
  const InstructorProposal({
    this.proposalId,
    required this.status,
    this.instructor,
    this.rejectionReason,
    this.createdAt,
    this.reviewedAt,
  });

  final String? proposalId;
  final InstructorProposalStatus status;

  /// The proposed person. Null when the API sent nothing readable.
  final InstructorSelection? instructor;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  bool get isPending => status == InstructorProposalStatus.pending;
  bool get isRejected => status == InstructorProposalStatus.rejected;

  @override
  List<Object?> get props => [
        proposalId,
        status,
        instructor,
        rejectionReason,
        createdAt,
        reviewedAt,
      ];
}
