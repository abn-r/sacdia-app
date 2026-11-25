import 'package:equatable/equatable.dart';

/// Pending work counts for the supervision hub.
///
/// A `null` count means the actor lacks that function; it is never 0.
class SupervisionPendingCounts extends Equatable {
  final String territoryLevel;
  final int? clubEnrollments;
  final int? annualFolders;
  final int? unionCamporeeRegistrations;
  final int? transfers;
  final int? roleAssignments;

  const SupervisionPendingCounts({
    required this.territoryLevel,
    this.clubEnrollments,
    this.annualFolders,
    this.unionCamporeeRegistrations,
    this.transfers,
    this.roleAssignments,
  });

  /// transfers + roleAssignments; null only when both are null.
  int? get requests {
    if (transfers == null && roleAssignments == null) return null;
    return (transfers ?? 0) + (roleAssignments ?? 0);
  }

  /// Sum of the non-null counts (0 when all are null).
  int get total =>
      (clubEnrollments ?? 0) +
      (annualFolders ?? 0) +
      (unionCamporeeRegistrations ?? 0) +
      (transfers ?? 0) +
      (roleAssignments ?? 0);

  @override
  List<Object?> get props => [
        territoryLevel,
        clubEnrollments,
        annualFolders,
        unionCamporeeRegistrations,
        transfers,
        roleAssignments,
      ];
}
