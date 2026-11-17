import 'package:equatable/equatable.dart';

/// Requirements of a class (or of one member) counted by backend status.
///
/// `submitted` is "sent, waiting for the local field"; `pending` is "not sent
/// yet". Older servers do not send the counts, so everything defaults to zero.
class RequirementStatusCounts extends Equatable {
  final int validated;
  final int submitted;
  final int rejected;
  final int pending;

  const RequirementStatusCounts({
    this.validated = 0,
    this.submitted = 0,
    this.rejected = 0,
    this.pending = 0,
  });

  static const zero = RequirementStatusCounts();

  int get total => validated + submitted + rejected + pending;

  RequirementStatusCounts operator +(RequirementStatusCounts other) =>
      RequirementStatusCounts(
        validated: validated + other.validated,
        submitted: submitted + other.submitted,
        rejected: rejected + other.rejected,
        pending: pending + other.pending,
      );

  @override
  List<Object?> get props => [validated, submitted, rejected, pending];
}

/// Person in charge of a class (counselor or sub-counselor).
class ClassResponsible extends Equatable {
  final String userId;
  final String name;

  const ClassResponsible({required this.userId, required this.name});

  @override
  List<Object?> get props => [userId, name];
}

/// Class-wide summary of the members-progress response.
class ClassProgressSummary extends Equatable {
  final int avgProgress;
  final RequirementStatusCounts statusCounts;

  const ClassProgressSummary({
    this.avgProgress = 0,
    this.statusCounts = RequirementStatusCounts.zero,
  });

  @override
  List<Object?> get props => [avgProgress, statusCounts];
}
